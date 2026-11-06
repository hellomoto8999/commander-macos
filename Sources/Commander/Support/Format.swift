import Foundation
import AppKit

enum Format {

    // MARK: Dimensioni

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        f.isAdaptive = true
        return f
    }()

    static func bytes(_ value: Int64) -> String {
        if value < 0 { return "—" }
        if value == 0 { return "0 byte" }
        return byteFormatter.string(fromByteCount: value)
    }

    static func bytes(_ value: Int) -> String {
        bytes(Int64(value))
    }

    // MARK: Date (seguono la lingua del sistema)

    static func relativeDate(_ date: Date) -> String {
        if UserDefaults.standard.object(forKey: "pref.useRelativeDates") as? Bool == false {
            return fullDate(date)
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(date) {
            return L("Yesterday")
        }
        let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    static func fullDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: Conteggi

    static func items(_ count: Int) -> String {
        L10n.items(count)
    }

    static func selected(_ count: Int) -> String {
        L10n.selected(count)
    }

    static func freeSpace(for url: URL) -> String? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let free = values?.volumeAvailableCapacityForImportantUsage else { return nil }
        return "\(byteFormatter.string(fromByteCount: free)) \(L("available"))"
    }
}

enum PathText {
    static func abbreviated(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }
}
