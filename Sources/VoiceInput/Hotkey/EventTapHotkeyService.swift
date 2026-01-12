import AppKit
import ApplicationServices
import Foundation

final class EventTapHotkeyService: HotkeyService {
    var onPressBegan: (() -> Void)?
    var onPressEnded: (() -> Void)?
    var onError: ((String) -> Void)?

    private let settingsStore: SettingsStore

    private let stateLock = NSLock()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var eventTapRunLoop: CFRunLoop?
    private var backgroundThread: Thread?

    private var isPressed = false
    private var activeCustomKeyCode: Int?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var nseventIsPressed = false

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func start() {
        stop()
        
        NSLog("[Hotkey] Starting event tap service...")
        ErrorLogStore.shared.log("Hotkey: starting")

        // Fallback: NSEvent global monitor (more reliable than CGEventTap in some environments)
        // Note: global monitor will not receive events while app is in secure input contexts, but works for most cases.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleNSEvent(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleNSEvent(event)
            return event
        }

        // Create and start a dedicated background thread for the event tap
        backgroundThread = Thread { [weak self] in
            self?.setupEventTap()
            // Keep the run loop running
            CFRunLoopRun()
        }
        backgroundThread?.name = "VoiceInput.EventTap"
        backgroundThread?.start()
    }
    
    private func setupEventTap() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let eventMask = CGEventMask(mask)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            let service = Unmanaged<EventTapHotkeyService>.fromOpaque(refcon!).takeUnretainedValue()
            return service.handleEvent(proxy: proxy, type: type, event: event)
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
 
        // Prefer HID-level tap for the most reliable global key events. Fallback to session tap.
        let createdTap =
            CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: eventMask,
                callback: callback,
                userInfo: userInfo
            )
            ?? CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: eventMask,
                callback: callback,
                userInfo: userInfo
            )
 
        stateLock.lock()
        eventTap = createdTap
        stateLock.unlock()

        guard let createdTap else {
            // Only show permission dialog if tap creation actually failed
            DispatchQueue.main.async { [weak self] in
                if !CGPreflightListenEventAccess() {
                    CGRequestListenEventAccess()
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                        NSWorkspace.shared.open(url)
                    }
                }
                let message = "Failed to create CGEventTap.\n\n1. Open System Settings > Privacy & Security > Input Monitoring\n2. Remove old VoiceInput entries\n3. Add .build/VoiceInput.app\n4. Restart the app"
                NSLog("[Hotkey] \(message)")
                ErrorLogStore.shared.log("Hotkey: failed to create event tap")
                self?.onError?(message)
            }
            return
        }

        let currentRunLoop = CFRunLoopGetCurrent()
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0)
        CFRunLoopAddSource(currentRunLoop, source, .commonModes)
 
        stateLock.lock()
        runLoopSource = source
        eventTapRunLoop = currentRunLoop
        stateLock.unlock()

        CGEvent.tapEnable(tap: createdTap, enable: true)
        NSLog("[Hotkey] CGEventTap started on background thread.")
        ErrorLogStore.shared.log("Hotkey: event tap started")
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
        nseventIsPressed = false

        stateLock.lock()
        let runLoop = eventTapRunLoop
        stateLock.unlock()
 
        if let runLoop {
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) { [weak self] in
                guard let self else { return }
                self.stateLock.lock()
                let tap = self.eventTap
                let source = self.runLoopSource
                self.stateLock.unlock()
 
                if let tap {
                    CGEvent.tapEnable(tap: tap, enable: false)
                }
                if let source {
                    CFRunLoopRemoveSource(runLoop, source, .commonModes)
                }
 
                self.stateLock.lock()
                self.runLoopSource = nil
                self.eventTap = nil
                self.eventTapRunLoop = nil
                self.stateLock.unlock()
 
                CFRunLoopStop(runLoop)
            }
            CFRunLoopWakeUp(runLoop)
        }
 
        backgroundThread?.cancel()
        backgroundThread = nil
 
        isPressed = false
        activeCustomKeyCode = nil
    }

     private func handleNSEvent(_ event: NSEvent) {
         switch event.type {
         case .keyDown, .keyUp:
             let keyCode = Int(event.keyCode)
             let flags = event.modifierFlags.intersection([.command, .shift, .control, .option])
             let flagsRaw = UInt(flags.rawValue)

             let bindings = settingsStore.customHotkeys
             let matched = bindings.contains(where: { $0.keyCode == keyCode && $0.modifierFlags == flagsRaw })
             guard matched else { return }

             if event.type == .keyDown {
                 if activeCustomKeyCode == nil {
                     activeCustomKeyCode = keyCode
                     ErrorLogStore.shared.log("Hotkey(NSEvent): custom down")
                     DispatchQueue.main.async { [weak self] in
                         self?.onPressBegan?()
                     }
                 }
             } else {
                 if activeCustomKeyCode == keyCode {
                     activeCustomKeyCode = nil
                     ErrorLogStore.shared.log("Hotkey(NSEvent): custom up")
                     DispatchQueue.main.async { [weak self] in
                         self?.onPressEnded?()
                     }
                 }
             }

         case .flagsChanged:
             guard settingsStore.enableFnHotkey else { return }
             let fnDown = event.modifierFlags.contains(.function)
             let hasOtherModifiers = event.modifierFlags.intersection([.command, .shift, .control, .option]).rawValue != 0

             if fnDown, !hasOtherModifiers, !nseventIsPressed {
                 nseventIsPressed = true
                 ErrorLogStore.shared.log("Hotkey(NSEvent): fn down")
                 DispatchQueue.main.async { [weak self] in
                     self?.onPressBegan?()
                 }
             } else if !fnDown, nseventIsPressed {
                 nseventIsPressed = false
                 ErrorLogStore.shared.log("Hotkey(NSEvent): fn up")
                 DispatchQueue.main.async { [weak self] in
                     self?.onPressEnded?()
                 }
             }

         default:
             return
         }
     }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            NSLog("[Hotkey] Event tap disabled; re-enabled.")
            return Unmanaged.passUnretained(event)
        }

        // Custom hotkeys (press-and-hold)
        if type == .keyDown || type == .keyUp {
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            let normalizedFlags = flags.intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])

            // Evaluate latest settings each time for immediate effect.
            let bindings = settingsStore.customHotkeys
            let matched = bindings.contains(where: {
                $0.keyCode == keyCode && UInt(normalizedFlags.rawValue) == $0.modifierFlags
            })
            if matched {
                if type == .keyDown {
                    if activeCustomKeyCode == nil {
                        activeCustomKeyCode = keyCode
                        NSLog("[Hotkey] Custom down: \(keyCode)")
                        ErrorLogStore.shared.log("Hotkey: custom down")
                        DispatchQueue.main.async { [weak self] in
                            self?.onPressBegan?()
                        }
                    }
                } else {
                    if activeCustomKeyCode == keyCode {
                        activeCustomKeyCode = nil
                        NSLog("[Hotkey] Custom up: \(keyCode)")
                        ErrorLogStore.shared.log("Hotkey: custom up")
                        DispatchQueue.main.async { [weak self] in
                            self?.onPressEnded?()
                        }
                    }
                }
            }

            return Unmanaged.passUnretained(event)
        }

        guard settingsStore.enableFnHotkey else {
            return Unmanaged.passUnretained(event)
        }

        // Note: Fn on macOS may not be reliably detectable via event tap on all machines.
        // Here we attempt a best-effort heuristic: treat flagsChanged with a function flag as press/release.
        if type == .flagsChanged {
            let flags = event.flags
            let fnDown = flags.contains(.maskSecondaryFn)
            
            // Only consider pure Fn press (no other modifiers like Command, Option, etc.)
            let hasOtherModifiers = flags.intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate]).rawValue != 0
            
            // Only trigger on pure Fn press without other modifiers
            if fnDown, !hasOtherModifiers, !isPressed {
                isPressed = true
                NSLog("[Hotkey] Fn down - starting recording")
                ErrorLogStore.shared.log("Hotkey: fn down")
                DispatchQueue.main.async { [weak self] in
                    self?.onPressBegan?()
                }
            } else if !fnDown, isPressed {
                isPressed = false
                NSLog("[Hotkey] Fn up - stopping recording")
                ErrorLogStore.shared.log("Hotkey: fn up")
                DispatchQueue.main.async { [weak self] in
                    self?.onPressEnded?()
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
