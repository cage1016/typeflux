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
    case personaRequested
}

struct HotkeyGestureArbiter {
    enum Phase: Equatable {
        case idle
        case pendingModifierActivation
        case active(HotkeyAction)
    }

    private(set) var phase: Phase = .idle

    var hasPendingModifierActivation: Bool {
        phase == .pendingModifierActivation
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
            guard let activationHotkey else { return false }
            return activationHotkey.isModifierOnlyTrigger && keyCode == activationHotkey.keyCode
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
            phase = .idle
            return [.personaRequested]
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
    ) -> [HotkeyGestureEvent] {
        guard let activationHotkey else { return [] }
        guard activationHotkey.isModifierOnlyTrigger else { return [] }

        let isActivationModifierEvent = keyCode == activationHotkey.keyCode
        let activationModifierDown = isActivationModifierEvent && modifierFlags == activationHotkey.modifierFlags

        if activationModifierDown, phase == .idle {
            if shouldDeferModifierActivation(
                activationHotkey: activationHotkey,
                askHotkey: askHotkey,
                personaHotkey: personaHotkey,
            ) {
                phase = .pendingModifierActivation
                return []
            }

            phase = .active(.activation)
            return [.begin(.activation)]
        }

        guard isActivationModifierEvent, !activationModifierDown else { return [] }

        switch phase {
        case .pendingModifierActivation:
            phase = .idle
            return [.activationTapped]
        case .active(.activation):
            phase = .idle
            return [.end(.activation)]
        default:
            return []
        }
    }

    mutating func handlePendingModifierActivationTimeout() -> [HotkeyGestureEvent] {
        guard phase == .pendingModifierActivation else { return [] }
        phase = .active(.activation)
        return [.begin(.activation)]
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
                && hotkey.keyCode != activationHotkey.keyCode
        }
    }
}
