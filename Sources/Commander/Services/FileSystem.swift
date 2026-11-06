import Foundation
import AppKit

enum FileSystem {

    static let fm = FileManager.default

    static let resourceKeys: [URLResourceKey] = [
        .nameKey, .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey,
        .isHiddenKey, .fileSizeKey, .totalFileAllocatedSizeKey,
        .contentModificationDateKey, .creationDateKey, .contentTypeKey,
        .localizedTypeDescriptionKey, .tagNamesKey
    ]

    // MARK: Lettura

    static func list(_ directory: URL, showHidden: Bool) throws -> [FileItem] {
        let urls = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsPackageDescendants]
        )
        let showLibrary = UserDefaults.standard.bool(forKey: "pref.showLibraryFolder")
        let home = fm.homeDirectoryForCurrentUser.standardizedFileURL
        var items: [FileItem] = []
        items.reserveCapacity(urls.count)
        for url in urls {
            if !showHidden && url.lastPathComponent.hasPrefix(".") { continue }
            let item = FileItem(url: url)
            if !showHidden && item.isHidden {
                let isHomeLibrary = showLibrary
                    && url.lastPathComponent == "Library"
                    && url.deletingLastPathComponent().standardizedFileURL == home
                if !isHomeLibrary { continue }
            }
            items.append(item)
        }
        return items
    }

    static func sorted(_ items: [FileItem], by field: SortField, ascending: Bool, foldersFirst: Bool) -> [FileItem] {
        items.sorted { a, b in
            if foldersFirst && a.isBrowsableFolder != b.isBrowsableFolder {
                return a.isBrowsableFolder
            }
            let result: ComparisonResult
            switch field {
            case .name:
                result = a.name.localizedStandardCompare(b.name)
            case .kind:
                result = a.displayKind.localizedStandardCompare(b.displayKind)
            case .size:
                if a.size == b.size { result = .orderedSame }
                else { result = a.size < b.size ? .orderedAscending : .orderedDescending }
            case .dateModified:
                if a.modified == b.modified { result = .orderedSame }
                else { result = a.modified < b.modified ? .orderedAscending : .orderedDescending }
            case .dateCreated:
                if a.created == b.created { result = .orderedSame }
                else { result = a.created < b.created ? .orderedAscending : .orderedDescending }
            }
            if result == .orderedSame {
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            return ascending ? (result == .orderedAscending) : (result == .orderedDescending)
        }
    }

    // MARK: Operazioni

    static func uniqueDestination(for url: URL, in directory: URL) -> URL {
        let direct = directory.appendingPathComponent(url.lastPathComponent)
        if !fm.fileExists(atPath: direct.path) { return direct }

        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var index = 2
        while true {
            let name = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            let candidate = directory.appendingPathComponent(name)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    static func copy(_ urls: [URL], to directory: URL) throws {
        for url in urls {
            let destination = uniqueDestination(for: url, in: directory)
            try fm.copyItem(at: url, to: destination)
        }
    }

    static func move(_ urls: [URL], to directory: URL) throws {
        for url in urls {
            if url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL { continue }
            let destination = uniqueDestination(for: url, in: directory)
            do {
                try fm.moveItem(at: url, to: destination)
            } catch {
                // Volumi diversi: copia e rimuovi.
                try fm.copyItem(at: url, to: destination)
                try fm.removeItem(at: url)
            }
        }
    }

    static func rename(_ url: URL, to newName: String) throws -> URL {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != url.lastPathComponent else { return url }
        guard !trimmed.contains("/") else {
            throw NSError(domain: "Commander", code: 1, userInfo: [NSLocalizedDescriptionKey: L("The name cannot contain “/”.")])
        }
        let destination = url.deletingLastPathComponent().appendingPathComponent(trimmed)
        if fm.fileExists(atPath: destination.path) {
            throw NSError(domain: "Commander", code: 2, userInfo: [NSLocalizedDescriptionKey: L("An item with the same name already exists.")])
        }
        try fm.moveItem(at: url, to: destination)
        return destination
    }

    static func createFolder(in directory: URL) throws -> URL {
        let baseName = L("untitled folder")
        var candidate = directory.appendingPathComponent(baseName)
        var index = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName) \(index)")
            index += 1
        }
        try fm.createDirectory(at: candidate, withIntermediateDirectories: false)
        return candidate
    }

    static func createFile(in directory: URL, name: String? = nil) throws -> URL {
        let filename = name ?? "\(L("New Document")).txt"
        var candidate = directory.appendingPathComponent(filename)
        let base = candidate.deletingPathExtension().lastPathComponent
        let ext = candidate.pathExtension
        var index = 2
        while fm.fileExists(atPath: candidate.path) {
            let n = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            candidate = directory.appendingPathComponent(n)
            index += 1
        }
        fm.createFile(atPath: candidate.path, contents: Data())
        return candidate
    }

    static func trash(_ urls: [URL]) throws {
        for url in urls {
            var resulting: NSURL?
            try fm.trashItem(at: url, resultingItemURL: &resulting)
        }
    }

    static func deletePermanently(_ urls: [URL]) throws {
        for url in urls {
            try fm.removeItem(at: url)
        }
    }

    static func size(of directory: URL) -> Int64 {
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else { return 0 }
        var total: Int64 = 0
        var count = 0
        for case let url as URL in enumerator {
            count += 1
            if count > 250_000 { break }
            guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey]),
                  values.isDirectory != true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }

    static func itemCount(of directory: URL) -> Int {
        (try? fm.contentsOfDirectory(atPath: directory.path).count) ?? 0
    }

    static func existingItems(at urls: [URL]) -> [URL] {
        urls.filter { fm.fileExists(atPath: $0.path) }
    }

    /// Ricerca Spotlight per tag Finder, limitata alla cartella home.
    static func searchByTag(_ name: String, in directory: URL, limit: Int) -> [FileItem] {
        let escaped = name
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = [
            "-onlyin", directory.path,
            "-0",
            "kMDItemUserTags == \"\(escaped)\""
        ]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return []
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [] }
        return String(data: data, encoding: .utf8)?
            .split(separator: "\0", omittingEmptySubsequences: true)
            .prefix(limit)
            .map { FileItem(url: URL(fileURLWithPath: String($0))) }
            .filter { fm.fileExists(atPath: $0.url.path) } ?? []
    }

    /// Ricerca per nome, con limite per non bloccare cartelle enormi.
    static func search(in directory: URL, query: String, showHidden: Bool, limit: Int) -> [FileItem] {
        guard !query.isEmpty else { return [] }
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        let showAllExtensions = UserDefaults.standard.bool(forKey: "pref.showAllExtensions")
        var results: [FileItem] = []
        for case let url as URL in enumerator {
            if results.count >= limit { break }
            let name = showAllExtensions
                ? url.lastPathComponent
                : ((try? url.resourceValues(forKeys: [.nameKey]))?.name ?? url.lastPathComponent)
            if !showHidden && name.hasPrefix(".") { continue }
            guard name.localizedCaseInsensitiveContains(query) else { continue }
            results.append(FileItem(url: url))
        }
        return results
    }
}

// MARK: - Appunti file

enum FileClipboard {
    static let cutType = NSPasteboard.PasteboardType("com.frank.commander.cut")

    static func write(_ urls: [URL], cut: Bool) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(urls as [NSURL])
        if cut {
            pb.setString("1", forType: cutType)
        }
    }

    static func read() -> (urls: [URL], cut: Bool) {
        let pb = NSPasteboard.general
        let objects = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [NSURL] ?? []
        let urls = objects.map { $0 as URL }
        return (urls, pb.string(forType: cutType) != nil)
    }

    static func hasFiles() -> Bool {
        !read().urls.isEmpty
    }
}
