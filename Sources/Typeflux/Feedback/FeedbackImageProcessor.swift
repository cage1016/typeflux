import AppKit
import Foundation

struct PreparedFeedbackImage: Equatable {
    let data: Data
    let filename: String
    let contentType: String
    let thumbnail: NSImage

    static func == (lhs: PreparedFeedbackImage, rhs: PreparedFeedbackImage) -> Bool {
        lhs.data == rhs.data
            && lhs.filename == rhs.filename
            && lhs.contentType == rhs.contentType
    }
}

enum FeedbackImageProcessor {
    static let maxPixelDimension = 1_600
    static let jpegCompression: CGFloat = 0.78

    static func prepare(url: URL) throws -> PreparedFeedbackImage {
        guard let sourceImage = NSImage(contentsOf: url),
              let sourceRep = bitmapRepresentation(for: sourceImage)
        else {
            throw FeedbackAPIError.networkError(L("feedback.error.invalidImage"))
        }

        let resizedImage = resized(sourceImage, pixelsWide: sourceRep.pixelsWide, pixelsHigh: sourceRep.pixelsHigh)
        guard let resizedRep = bitmapRepresentation(for: resizedImage),
              let data = resizedRep.representation(
                  using: .jpeg,
                  properties: [.compressionFactor: jpegCompression]
              )
        else {
            throw FeedbackAPIError.networkError(L("feedback.error.invalidImage"))
        }

        return PreparedFeedbackImage(
            data: data,
            filename: jpegFilename(from: url),
            contentType: "image/jpeg",
            thumbnail: resizedImage
        )
    }

    private static func bitmapRepresentation(for image: NSImage) -> NSBitmapImageRep? {
        if let tiffData = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiffData) {
            return rep
        }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return NSBitmapImageRep(cgImage: cgImage)
    }

    private static func resized(_ image: NSImage, pixelsWide: Int, pixelsHigh: Int) -> NSImage {
        let longestSide = max(pixelsWide, pixelsHigh)
        guard longestSide > maxPixelDimension else {
            return image
        }

        let scale = CGFloat(maxPixelDimension) / CGFloat(longestSide)
        let targetSize = NSSize(
            width: max(1, CGFloat(pixelsWide) * scale),
            height: max(1, CGFloat(pixelsHigh) * scale)
        )
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        resized.unlockFocus()
        return resized
    }

    private static func jpegFilename(from url: URL) -> String {
        let baseName = url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(baseName.isEmpty ? "feedback-image" : baseName).jpg"
    }
}
