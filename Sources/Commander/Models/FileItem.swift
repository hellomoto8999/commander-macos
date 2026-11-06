import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let isPackage: Bool
    let isSymlink: Bool
    let isHidden: Bool
    let size: Int64
    let modified: Date
    let created: Date
    let kind: String
    let type: UTType?
    let tagNames: [String]

    var id: URL { url }
    var ext: String { url.pathExtension.lowercased() }
    var isBrowsableFolder: Bool { isDirectory && !isPackage }

    /// Usa la descrizione di tipo già localizzata dal sistema (Finder-style).
    var displayKind: String {
        if isBrowsableFolder { return L("Folder") }
        if isPackage { return kind.isEmpty ? L("Package") : kind }
        if !kind.isEmpty { return kind }
        if ext.isEmpty { return L("Document") }
        return "\(ext.uppercased()) \(L("file"))"
    }

    var isImage: Bool { type?.conforms(to: .image) ?? false }
    var isMovie: Bool { type?.conforms(to: .movie) ?? false }
    var isAudio: Bool { type?.conforms(to: .audio) ?? false }
    var isPDF: Bool { type?.conforms(to: .pdf) ?? false }

    var isText: Bool {
        if let type {
            return type.conforms(to: .text)
                || type.conforms(to: .sourceCode)
                || type.conforms(to: .json)
                || type.conforms(to: .xml)
                || type.conforms(to: .yaml)
        }
        return ["txt", "md", "swift", "js", "ts", "py", "json", "yml", "yaml", "html", "css", "sh", "c", "h", "cpp", "rs", "go", "toml", "ini", "log", "csv"].contains(ext)
    }

    var tagColor: Color? {
        for tag in tagNames {
            if let color = FinderTagColor.color(for: tag) { return color }
        }
        return nil
    }

    init(url: URL) {
        self.url = url
        let keys: Set<URLResourceKey> = [
            .nameKey, .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey,
            .isHiddenKey, .fileSizeKey, .totalFileAllocatedSizeKey,
            .contentModificationDateKey, .creationDateKey, .contentTypeKey,
            .localizedTypeDescriptionKey, .tagNamesKey
        ]
        let values = try? url.resourceValues(forKeys: keys)
        let showAllExtensions = UserDefaults.standard.bool(forKey: "pref.showAllExtensions")
        name = showAllExtensions
            ? url.lastPathComponent
            : (values?.name ?? url.lastPathComponent)
        isPackage = values?.isPackage ?? false
        isSymlink = values?.isSymbolicLink ?? false
        isHidden = values?.isHidden ?? false

        var directory = values?.isDirectory ?? false
        if !directory && isSymlink {
            let resolved = (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory
            directory = resolved ?? false
        }
        isDirectory = directory

        size = Int64(values?.fileSize ?? values?.totalFileAllocatedSize ?? 0)
        modified = values?.contentModificationDate ?? .distantPast
        created = values?.creationDate ?? .distantPast
        kind = values?.localizedTypeDescription ?? ""
        type = values?.contentType
        tagNames = values?.tagNames ?? []
    }
}

enum SortField: String, CaseIterable, Identifiable, Codable {
    case name, kind, size, dateModified, dateCreated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return L("Name")
        case .kind: return L("Kind")
        case .size: return L("Size")
        case .dateModified: return L("Date Modified")
        case .dateCreated: return L("Date Created")
        }
    }

    var symbol: String {
        switch self {
        case .name: return "textformat"
        case .kind: return "doc"
        case .size: return "externaldrive"
        case .dateModified: return "clock"
        case .dateCreated: return "calendar"
        }
    }
}

enum ViewMode: String, CaseIterable, Identifiable, Codable {
    case icons, list, columns

    var id: String { rawValue }

    var label: String {
        switch self {
        case .icons: return L("Icons")
        case .columns: return L("Columns")
        case .list: return L("List")
        }
    }

    var symbol: String {
        switch self {
        case .icons: return "square.grid.2x2"
        case .columns: return "rectangle.split.3x1"
        case .list: return "list.bullet"
        }
    }
}
