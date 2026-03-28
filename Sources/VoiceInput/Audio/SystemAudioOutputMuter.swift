import CoreAudio
import Foundation

final class SystemAudioOutputMuter {
    private struct State {
        let deviceID: AudioDeviceID
        let wasMuted: UInt32
    }

    private var capturedState: State?

    func beginMutedSession() {
        guard capturedState == nil else { return }
        guard let deviceID = defaultOutputDeviceID(), let currentMute = currentMuteState(for: deviceID) else {
            return
        }

        capturedState = State(deviceID: deviceID, wasMuted: currentMute)
        _ = setMute(true, for: deviceID)
    }

    func endMutedSession() {
        guard let capturedState else { return }
        _ = setMute(capturedState.wasMuted != 0, for: capturedState.deviceID)
        self.capturedState = nil
    }

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID()
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard getPropertyData(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: &address,
            value: &deviceID,
            dataSize: size
        ) == noErr else {
            return nil
        }

        return deviceID
    }

    private func currentMuteState(for deviceID: AudioDeviceID) -> UInt32? {
        var address = muteAddress
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var mute: UInt32 = 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        guard getPropertyData(objectID: deviceID, address: &address, value: &mute, dataSize: size) == noErr else {
            return nil
        }

        return mute
    }

    private func setMute(_ isMuted: Bool, for deviceID: AudioDeviceID) -> Bool {
        var address = muteAddress
        guard AudioObjectHasProperty(deviceID, &address) else { return false }

        var mute: UInt32 = isMuted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &mute) == noErr
    }

    private var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func getPropertyData<T>(
        objectID: AudioObjectID,
        address: inout AudioObjectPropertyAddress,
        value: inout T,
        dataSize: UInt32
    ) -> OSStatus {
        var size = dataSize
        return AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)
    }
}
