import Foundation

enum FileOperationCancelled: Error {
    case cancelled
}

/// Copia, sposta ed enumera file con report di avanzamento e cancellazione.
enum FileOperationEngine {
    static let fm = FileManager.default
    private static let chunkSize = 1_048_576
    private static let smallFileLimit: Int64 = 8 * 1024 * 1024

    // MARK: Volumi

    static func deviceID(_ url: URL) -> UInt64? {
        var info = stat()
        let result = url.path.withCString { stat($0, &info) }
        guard result == 0 else { return nil }
        return UInt64(info.st_dev)
    }

    static func sameVolume(_ url: URL, _ directory: URL) -> Bool {
        guard let a = deviceID(url.deletingLastPathComponent()),
              let b = deviceID(directory) else { return false }
        return a == b
    }

    static func isDescendant(_ candidate: URL, of ancestor: URL) -> Bool {
        let candidatePath = candidate.standardizedFileURL.path
        let ancestorPath = ancestor.standardizedFileURL.path
        return candidatePath == ancestorPath || candidatePath.hasPrefix(ancestorPath + "/")
    }

    // MARK: Dimensioni

    static func totalSize(of urls: [URL], isCancelled: () -> Bool) throws -> Int64 {
        var total: Int64 = 0

        for url in urls {
            if isCancelled() { throw FileOperationCancelled.cancelled }

            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }

            if isDirectory.boolValue {
                let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
                guard let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: [],
                    errorHandler: nil
                ) else { continue }

                for case let child as URL in enumerator {
                    if isCancelled() { throw FileOperationCancelled.cancelled }
                    guard let values = try? child.resourceValues(forKeys: Set(keys)),
                          values.isRegularFile == true else { continue }
                    total += Int64(values.fileSize ?? 0)
                }
            } else if let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                      values.isRegularFile == true {
                total += Int64(values.fileSize ?? 0)
            }
        }

        return total
    }

    // MARK: Copia

    static func copy(
        _ urls: [URL],
        to directory: URL,
        progress: (Int64, String) -> Void,
        onItemCompleted: (Int) -> Void,
        isCancelled: () -> Bool
    ) throws {
        for (index, url) in urls.enumerated() {
            if isCancelled() { throw FileOperationCancelled.cancelled }

            let destination = FileSystem.uniqueDestination(for: url, in: directory)
            if isDescendant(destination, of: url) {
                throw NSError(
                    domain: "Commander",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: L("A folder cannot be copied into itself.")]
                )
            }
            do {
                try copyTree(from: url, to: destination, progress: progress, isCancelled: isCancelled)
            } catch {
                try? fm.removeItem(at: destination)
                throw error
            }
            onItemCompleted(index + 1)
        }
    }

    // MARK: Spostamento

    static func move(
        _ urls: [URL],
        to directory: URL,
        progress: (Int64, String) -> Void,
        onItemCompleted: (Int) -> Void,
        isCancelled: () -> Bool
    ) throws {
        for (index, url) in urls.enumerated() {
            if isCancelled() { throw FileOperationCancelled.cancelled }

            let destination = FileSystem.uniqueDestination(for: url, in: directory)
            if isDescendant(destination, of: url) {
                throw NSError(
                    domain: "Commander",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: L("A folder cannot be moved into itself.")]
                )
            }

            if sameVolume(url, directory) {
                try fm.moveItem(at: url, to: destination)
                progress(0, url.lastPathComponent)
            } else {
                do {
                    try copyTree(from: url, to: destination, progress: progress, isCancelled: isCancelled)
                    try fm.removeItem(at: url)
                } catch {
                    try? fm.removeItem(at: destination)
                    throw error
                }
            }
            onItemCompleted(index + 1)
        }
    }

    // MARK: - Interni

    private static func copyTree(
        from source: URL,
        to destination: URL,
        progress: (Int64, String) -> Void,
        isCancelled: () -> Bool
    ) throws {
        if isCancelled() { throw FileOperationCancelled.cancelled }

        let keys: Set<URLResourceKey> = [
            .isSymbolicLinkKey, .isDirectoryKey, .fileSizeKey,
            .contentModificationDateKey
        ]
        let values = try source.resourceValues(forKeys: keys)

        if values.isSymbolicLink == true {
            let target = try fm.destinationOfSymbolicLink(atPath: source.path)
            try fm.createSymbolicLink(atPath: destination.path, withDestinationPath: target)
            return
        }

        if values.isDirectory == true {
            try fm.createDirectory(at: destination, withIntermediateDirectories: false)
            let children = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil, options: [])
            for child in children {
                if isCancelled() { throw FileOperationCancelled.cancelled }
                try copyTree(
                    from: child,
                    to: destination.appendingPathComponent(child.lastPathComponent),
                    progress: progress,
                    isCancelled: isCancelled
                )
            }
            copyAttributes(from: source, to: destination, values: values)
            return
        }

        let size = Int64(values.fileSize ?? 0)
        let name = source.lastPathComponent

        if size > smallFileLimit {
            try copyLargeFile(
                from: source,
                to: destination,
                name: name,
                progress: progress,
                isCancelled: isCancelled
            )
        } else {
            try fm.copyItem(at: source, to: destination)
            progress(size, name)
        }

        copyAttributes(from: source, to: destination, values: values)
    }

    private static func copyLargeFile(
        from source: URL,
        to destination: URL,
        name: String,
        progress: (Int64, String) -> Void,
        isCancelled: () -> Bool
    ) throws {
        fm.createFile(atPath: destination.path, contents: nil)
        let input = try FileHandle(forReadingFrom: source)
        let output = try FileHandle(forWritingTo: destination)
        defer {
            try? input.close()
            try? output.close()
        }

        while true {
            if isCancelled() { throw FileOperationCancelled.cancelled }
            let data = try input.read(upToCount: chunkSize) ?? Data()
            if data.isEmpty { break }
            try output.write(contentsOf: data)
            progress(Int64(data.count), name)
        }
    }

    private static func copyAttributes(from source: URL, to destination: URL, values: URLResourceValues) {
        var attributes: [FileAttributeKey: Any] = [:]
        if let date = values.contentModificationDate {
            attributes[.modificationDate] = date
        }
        if let fileAttributes = try? fm.attributesOfItem(atPath: source.path),
           let permissions = fileAttributes[.posixPermissions] {
            attributes[.posixPermissions] = permissions
        }
        if !attributes.isEmpty {
            try? fm.setAttributes(attributes, ofItemAtPath: destination.path)
        }
    }
}
