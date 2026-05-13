import AVFoundation
import Foundation

extension WorkflowController {
    func startAudioRecorderWithStartupRetry(
        levelHandler: @escaping (Float) -> Void,
        audioBufferHandler: ((AVAudioPCMBuffer) -> Void)?
    ) async throws {
        for attempt in 1 ... Self.audioStartupMaxAttemptCount {
            do {
                try audioRecorder.start(levelHandler: levelHandler, audioBufferHandler: audioBufferHandler)
                return
            } catch {
                guard
                    Self.isAudioStartupTimeout(error),
                    isRecording,
                    attempt < Self.audioStartupMaxAttemptCount
                else {
                    throw error
                }

                NetworkDebugLogger.logMessage(
                    """
                    [Audio Recorder] Microphone input startup timed out; retrying with a fresh startup attempt.
                    attempt: \(attempt)
                    maxAttempts: \(Self.audioStartupMaxAttemptCount)
                    retryDelayMilliseconds: 250
                    """
                )
                await sleep(Self.audioStartupRetryDelay)
                guard isRecording else {
                    throw error
                }
            }
        }
    }

    private static func isAudioStartupTimeout(_ error: Error) -> Bool {
        guard let recorderError = error as? AVFoundationAudioRecorder.RecorderError else {
            return false
        }
        return recorderError == .inputStartupTimedOut
    }
}
