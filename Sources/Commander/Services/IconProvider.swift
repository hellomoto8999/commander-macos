import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Cache delle icone di sistema, per evitare di chiedere a NSWorkspace un'icona per ogni riga.
final class IconProvider {
    static let shared = IconProvider()

    private var cache: [String: NSImage] = [:]
    private let lock = NSLock()

    func icon(for item: FileItem) -> NSImage {
        if item.isBrowsableFolder {
            return folderIcon(for: item.url)
        }
        if item.isPackage || item.isSymlink {
            return fileIcon(for: item.url, key: "path:" + item.url.path)
        }
        if let type = item.type {
            return fileIcon(for: item.url, key: "type:" + type.identifier, type: type)
        }
        if !item.ext.isEmpty {
            return fileIcon(for: item.url, key: "ext:" + item.ext)
        }
        return fileIcon(for: item.url, key: "path:" + item.url.path)
    }

    func icon(for url: URL) -> NSImage {
        if url.hasDirectoryPath {
            return folderIcon(for: url)
        }
        return fileIcon(for: url, key: "path:" + url.path)
    }

    private func folderIcon(for url: URL) -> NSImage {
        lock.lock()
        if let cached = cache["folder:" + url.path] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 128, height: 128)

        lock.lock()
        if cache.count > 4000 { cache.removeAll(keepingCapacity: true) }
        cache["folder:" + url.path] = image
        lock.unlock()
        return image
    }

    private func fileIcon(for url: URL, key: String, type: UTType? = nil) -> NSImage {
        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let image: NSImage
        if let type {
            image = NSWorkspace.shared.icon(for: type)
        } else {
            image = NSWorkspace.shared.icon(forFile: url.path)
        }
        image.size = NSSize(width: 128, height: 128)

        lock.lock()
        if cache.count > 4000 { cache.removeAll(keepingCapacity: true) }
        cache[key] = image
        lock.unlock()
        return image
    }
}
