import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// Miniature QuickLook con cache in memoria.
final class ThumbnailProvider {
    static let shared = ThumbnailProvider()

    private let cache = NSCache<NSURL, NSImage>()
    private let queue = DispatchQueue(label: "commander.thumbnails", qos: .userInitiated)
    private var inFlight: Set<URL> = []

    init() {
        cache.countLimit = 400
    }

    func thumbnail(for url: URL, size: CGFloat, completion: @escaping (NSImage?) -> Void) {
        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }

        queue.async { [weak self] in
            guard let self else { return }

            if let textImage = self.textThumbnail(for: url, size: size) {
                self.cache.setObject(textImage, forKey: url as NSURL)
                DispatchQueue.main.async { completion(textImage) }
                return
            }

            let scale = NSScreen.main?.backingScaleFactor ?? 2
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: size, height: size),
                scale: scale,
                representationTypes: .thumbnail
            )
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                guard let image = representation?.nsImage else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                self.cache.setObject(image, forKey: url as NSURL)
                DispatchQueue.main.async { completion(image) }
            }
        }
    }

    func cached(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    private func textThumbnail(for url: URL, size: CGFloat) -> NSImage? {
        guard let type = UTType(filenameExtension: url.pathExtension),
              type.conforms(to: .text),
              let text = PreviewLoader.text(at: url),
              !text.isEmpty else { return nil }

        let dimension = max(128, min(512, size * 2))
        let preview = String(text.prefix(1_800))
        let fontSize = max(9, dimension * 0.036)
        let inset = dimension * 0.07
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 1.6
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph
        ]

        return NSImage(size: NSSize(width: dimension, height: dimension), flipped: true) { rect in
            NSColor.white.setFill()
            NSBezierPath(rect: rect).fill()
            let textRect = rect.insetBy(dx: inset, dy: inset)
            (preview as NSString).draw(in: textRect, withAttributes: attributes)
            return true
        }
    }
}
