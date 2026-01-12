import AVFoundation
import Foundation

final class AVFoundationAudioRecorder: NSObject, AudioRecorder {
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var startedAt: Date?
    private var levelHandler: ((Float) -> Void)?

    func start(levelHandler: @escaping (Float) -> Void) throws {
        stopInternal()

        self.levelHandler = levelHandler

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("voice-input", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let url = dir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        recorder.record()

        self.recorder = recorder
        self.startedAt = Date()

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder else { return }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            let normalized = self.normalizePower(power)
            self.levelHandler?(normalized)
        }
    }

    func stop() throws -> AudioFile {
        guard let recorder else {
            throw NSError(domain: "AudioRecorder", code: 1)
        }

        recorder.stop()
        meterTimer?.invalidate()
        meterTimer = nil

        let duration = Date().timeIntervalSince(startedAt ?? Date())
        let fileURL = recorder.url

        self.recorder = nil
        self.startedAt = nil
        self.levelHandler = nil

        return AudioFile(fileURL: fileURL, duration: duration)
    }

    private func stopInternal() {
        recorder?.stop()
        recorder = nil
        meterTimer?.invalidate()
        meterTimer = nil
        startedAt = nil
        levelHandler = nil
    }

    private func normalizePower(_ power: Float) -> Float {
        let minDb: Float = -60
        let clamped = max(minDb, power)
        return (clamped - minDb) / -minDb
    }
}
