import Foundation

enum HotkeyPhysicalEventType: Equatable {
    case keyDown
    case keyUp
    case flagsChanged
}

enum HotkeyGestureEvent: Equatable {
    case activationTapped
    case begin(HotkeyAction)
    case end(HotkeyAction)
    case cancel(HotkeyAction)
    case personaRequested
}

struct HotkeyGestureArbiter {
    private static let doubleTapMaximumInterval: TimeInterval = 0.45

    enum Phase: Equatable {
        case idle
        case pendingModifierActivation
        case active(HotkeyAction)
    }

    private(set) var phase: Phase = .idle
    private var lastModifierTap: ModifierTap?

    var hasPendingModifierActivation: Bool {
        phase == .pendingModifierActivation
    }

    private struct ModifierTap: Equatable {
        let keyCode: Int
        let modifierFlags: UInt
        let timestamp: TimeInterval
    }

    func shouldConsume(
        eventType: HotkeyPhysicalEventType,
        keyCode: Int,
        modifierFlags: UInt,
        activationHotkey: HotkeyBinding?,
        askHotkey: HotkeyBinding?,
        personaHotkey: HotkeyBinding?,
    ) -> Bool {
        switch eventType {
        case .flagsChanged:
            if let activationHotkey,
               activationHotkey.isModifierOnlyTrigger,
               keyCode == activationHotkey.keyCode
            {
                return true
            }
            if let askHotkey,
               askHotkey.isModifierOnlyTrigger,
               keyCode == askHotkey.keyCode
            {
                return true
            }
            if let askHotkey,
               askHotkey.isModifierDoubleTapTrigger,
               keyCode == askHotkey.keyCode
            {
                return true
            }
            if let personaHotkey,
               personaHotkey.isModifierOnlyTrigger,
               keyCode == personaHotkey.keyCode
            {
                return true
            }
            return false
        case .keyDown:
            if let askHotkey, askHotkey.matches(keyCode: keyCode, modifierFlags: modifierFlags) {
                return true
            }
            if let activationHotkey,
               !activationHotkey.isModifierOnlyTrigger,
               activationHotkey.matches(keyCode: keyCode, modifierFlags: modifierFlags)
            {
                return true
            }
            if let personaHotkey, personaHotkey.matches(keyCode: keyCode, modifierFlags: modifierFlags) {
                return true
            }
            if case .active(.ask) = phase, let askHotkey, askHotkey.keyCode == keyCode {
                return true
            }
            if case .active(.activation) = phase,
               let activationHotkey,
               !activationHotkey.isModifierOnlyTrigger,
               activationHotkey.keyCode == keyCode
            {
                return true
            }
            return false
        case .keyUp:
            if case .active(.ask) = phase, let askHotkey, askHotkey.keyCode == keyCode {
                return true
            }
            if case .active(.activation) = phase,
               let activationHotkey,
               !activationHotkey.isModifierOnlyTrigger,
               activationHotkey.keyCode == keyCode
            {
                return true
            }
            return false
        }
    }

    mutating func handleKeyDown(
        keyCode: Int,
        modifierFlags: UInt,
        isRepeat: Bool,
        activationHotkey: HotkeyBinding?,
        askHotkey: HotkeyBinding?,
        personaHotkey: HotkeyBinding?,
    ) -> [HotkeyGestureEvent] {
        guard !isRepeat else { return [] }

        if let askHotkey, askHotkey.matches(keyCode: keyCode, modifierFlags: modifierFlags) {
            guard phase == .idle || phase == .pendingModifierActivation else { return [] }
            phase = .active(.ask)
            return [.begin(.ask)]
        }

        if let activationHotkey,
           !activationHotkey.isModifierOnlyTrigger,
           activationHotkey.matches(keyCode: keyCode, modifierFlags: modifierFlags),
           phase == .idle
        {
            phase = .active(.activation)
            return [.begin(.activation)]
        }

        if let personaHotkey, personaHotkey.matches(keyCode: keyCode, modifierFlags: modifierFlags) {
            guard phase == .idle || phase == .pendingModifierActivation else { return [] }
            let shouldCancelPendingActivation = phase == .pendingModifierActivation
            phase = .idle
            return shouldCancelPendingActivation
                ? [.cancel(.activation), .personaRequested]
                : [.personaRequested]
        }

        return []
    }

    mutating func handleKeyUp(
        keyCode: Int,
        activationHotkey: HotkeyBinding?,
        askHotkey: HotkeyBinding?,
    ) -> [HotkeyGestureEvent] {
        switch phase {
        case .active(.activation):
            guard let activationHotkey else { return [] }
            guard !activationHotkey.isModifierOnlyTrigger else { return [] }
            guard activationHotkey.keyCode == keyCode else { return [] }
            phase = .idle
            return [.end(.activation)]
        case .active(.ask):
            guard let askHotkey, askHotkey.keyCode == keyCode else { return [] }
            phase = .idle
            return [.end(.ask)]
        default:
            return []
        }
    }

    mutating func handleFlagsChanged(
        keyCode: Int,
        modifierFlags: UInt,
        activationHotkey: HotkeyBinding?,
        askHotkey: HotkeyBinding?,
        personaHotkey: HotkeyBinding? = nil,
        timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate,
    ) -> [HotkeyGestureEvent] {
        if isSecondTapForDoubleTapAsk(
            keyCode: keyCode,
            modifierFlags: modifierFlags,
            askHotkey: askHotkey,
            timestamp: timestamp,
        ) {
            lastModifierTap = nil
            guard phase == .idle || phase == .pendingModifierActivation else { return [] }
            let shouldCancelPendingActivation = phase == .pendingModifierActivation
            phase = .active(.ask)
            return shouldCancelPendingActivation
                ? [.cancel(.activation), .begin(.ask)]
                : [.begin(.ask)]
        }

        if let activationHotkey,
           activationHotkey.isModifierOnlyTrigger,
           activationHotkey.matches(keyCode: keyCode, modifierFlags: modifierFlags),
           phase == .idle
        {
            if shouldDeferModifierActivation(
                activationHotkey: activationHotkey,
                askHotkey: askHotkey,
                personaHotkey: personaHotkey,
            ) {
                phase = .pendingModifierActivation
                return [.begin(.activation)]
            }

            phase = .active(.activation)
            return [.begin(.activation)]
        }

        if let askHotkey,
           askHotkey.isModifierOnlyTrigger,
           askHotkey.matches(keyCode: keyCode, modifierFlags: modifierFlags)
        {
            guard phase == .idle || phase == .pendingModifierActivation else { return [] }
            let shouldCancelPendingActivation = phase == .pendingModifierActivation
            phase = .active(.ask)
            return shouldCancelPendingActivation
                ? [.cancel(.activation), .begin(.ask)]
                : [.begin(.ask)]
        }

        if let personaHotkey,
           personaHotkey.isModifierOnlyTrigger,
           personaHotkey.matches(keyCode: keyCode, modifierFlags: modifierFlags)
        {
            guard phase == .idle || phase == .pendingModifierActivation else { return [] }
            let shouldCancelPendingActivation = phase == .pendingModifierActivation
            phase = .idle
            return shouldCancelPendingActivation
                ? [.cancel(.activation), .personaRequested]
                : [.personaRequested]
        }

        if case .active(.ask) = phase,
           let askHotkey,
           askHotkey.isModifierOnlyTrigger,
           keyCode == askHotkey.keyCode,
           modifierFlags != askHotkey.modifierFlags
        {
            phase = .idle
            return [.end(.ask)]
        }
        if case .active(.ask) = phase,
           let askHotkey,
           askHotkey.isModifierDoubleTapTrigger,
           keyCode == askHotkey.keyCode,
           modifierFlags != askHotkey.modifierFlags
        {
            phase = .idle
            return [.end(.ask)]
        }

        guard let activationHotkey, activationHotkey.isModifierOnlyTrigger else { return [] }
        let isActivationModifierEvent = keyCode == activationHotkey.keyCode
        let activationModifierDown = isActivationModifierEvent && modifierFlags == activationHotkey.modifierFlags

        guard isActivationModifierEvent, !activationModifierDown else { return [] }

        switch phase {
        case .pendingModifierActivation:
            rememberModifierTap(
                keyCode: keyCode,
                modifierFlags: activationHotkey.modifierFlags,
                askHotkey: askHotkey,
                timestamp: timestamp,
            )
            phase = .idle
            return [.activationTapped]
        case .active(.activation):
            rememberModifierTap(
                keyCode: keyCode,
                modifierFlags: activationHotkey.modifierFlags,
                askHotkey: askHotkey,
                timestamp: timestamp,
            )
            phase = .idle
            return [.end(.activation)]
        default:
            return []
        }
    }

    mutating func handlePendingModifierActivationTimeout() -> [HotkeyGestureEvent] {
        guard phase == .pendingModifierActivation else { return [] }
        phase = .active(.activation)
        return []
    }

    private func shouldDeferModifierActivation(
        activationHotkey: HotkeyBinding,
        askHotkey: HotkeyBinding?,
        personaHotkey: HotkeyBinding?,
    ) -> Bool {
        guard activationHotkey.isModifierOnlyTrigger else { return false }
        let competingHotkeys = [askHotkey, personaHotkey].compactMap { $0 }
        return competingHotkeys.contains { hotkey in
            hotkey.modifierFlags == activationHotkey.modifierFlags
                && (hotkey.keyCode != activationHotkey.keyCode || hotkey.isModifierDoubleTapTrigger)
        }
    }

    private func isSecondTapForDoubleTapAsk(
        keyCode: Int,
        modifierFlags: UInt,
        askHotkey: HotkeyBinding?,
        timestamp: TimeInterval,
    ) -> Bool {
        guard let askHotkey, askHotkey.isModifierDoubleTapTrigger else { return false }
        guard askHotkey.keyCode == keyCode, askHotkey.modifierFlags == modifierFlags else { return false }
        guard let lastModifierTap else { return false }
        guard lastModifierTap.keyCode == keyCode, lastModifierTap.modifierFlags == modifierFlags else { return false }
        return timestamp - lastModifierTap.timestamp <= Self.doubleTapMaximumInterval
    }

    private mutating func rememberModifierTap(
        keyCode: Int,
        modifierFlags: UInt,
        askHotkey: HotkeyBinding?,
        timestamp: TimeInterval,
    ) {
        guard let askHotkey, askHotkey.isModifierDoubleTapTrigger else {
            lastModifierTap = nil
            return
        }
        guard askHotkey.keyCode == keyCode, askHotkey.modifierFlags == modifierFlags else {
            lastModifierTap = nil
            return
        }
        lastModifierTap = ModifierTap(keyCode: keyCode, modifierFlags: modifierFlags, timestamp: timestamp)
    }
}
