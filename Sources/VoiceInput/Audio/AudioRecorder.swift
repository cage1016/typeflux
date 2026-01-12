import Foundation

struct AudioFile {
    let fileURL: URL
    let duration: TimeInterval
}

protocol AudioRecorder {
    func start(levelHandler: @escaping (Float) -> Void) throws
    func stop() throws -> AudioFile
}
