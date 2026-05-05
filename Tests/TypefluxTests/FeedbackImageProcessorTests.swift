@testable import Typeflux
import AppKit
import XCTest

final class FeedbackImageProcessorTests: XCTestCase {
    func testPrepareCompressesImageToJPEGWithinMaxDimension() throws {
        let imageURL = try makeTemporaryPNG(width: 2_400, height: 1_200)
        defer { try? FileManager.default.removeItem(at: imageURL.deletingLastPathComponent()) }

        let prepared = try FeedbackImageProcessor.prepare(url: imageURL)

        XCTAssertEqual(prepared.filename, "feedback-source.jpg")
        XCTAssertEqual(prepared.contentType, "image/jpeg")
        XCTAssertFalse(prepared.data.isEmpty)

        let rep = try XCTUnwrap(NSBitmapImageRep(data: prepared.data))
        XCTAssertLessThanOrEqual(max(rep.pixelsWide, rep.pixelsHigh), FeedbackImageProcessor.maxPixelDimension)
    }

    private func makeTemporaryPNG(width: Int, height: Int) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("typeflux-feedback-image-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()

        let rep = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let url = directory.appendingPathComponent("feedback-source.png")
        try data.write(to: url)
        return url
    }
}
