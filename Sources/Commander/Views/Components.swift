import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Pulsante icona

struct IconButton: View {
    let system: String
    var help: String = ""
    var active: Bool = false
    var disabled: Bool = false
    var iconSize: CGFloat = 13
    var width: CGFloat = 26
    let action: () -> Void

    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(disabled ? Palette.textTertiary.opacity(0.45) : .secondary)
                .frame(width: width, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(active ? Color(nsColor: .quaternaryLabelColor).opacity(0.25) : (hover && !disabled ? Palette.rowHover : Color.clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
        .onHover { hover = $0 }
    }
}

// MARK: - Icone file (icone di sistema, miniature dove richiesto)

struct FileIconView: View {
    let item: FileItem
    var size: CGFloat = 16
    var preferThumbnail: Bool = false

    @State private var thumbnail: NSImage?

    private var supportsThumbnail: Bool {
        preferThumbnail && !item.isBrowsableFolder
    }

    var body: some View {
        Group {
            if supportsThumbnail, let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Image(nsImage: IconProvider.shared.icon(for: item))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(width: size, height: size)
        .task(id: item.url) {
            guard supportsThumbnail, thumbnail == nil else { return }
            if let cached = ThumbnailProvider.shared.cached(for: item.url) {
                thumbnail = cached
                return
            }
            let requestSize = min(512, max(64, size * 2))
            ThumbnailProvider.shared.thumbnail(for: item.url, size: requestSize) { image in
                thumbnail = image
            }
        }
    }
}

// MARK: - Riga file in stile Finder

struct FileRow: View {
    let item: FileItem
    var isSelected = false
    var isActivePane = true
    var alternate = false
    var hovered = false
    var showDate = true
    var showSize = true
    var showKind = true
    var height: CGFloat = 24
    var preferThumbnail = false

    var body: some View {
        HStack(spacing: 6) {
            FileIconView(item: item, size: 16, preferThumbnail: preferThumbnail)

            Text(item.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(primaryColor)
                .layoutPriority(1)

            if let color = item.tagColor {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }

            Spacer(minLength: 8)

            if showDate {
                Text(Format.relativeDate(item.modified))
                    .font(.system(size: 11))
                    .foregroundStyle(secondaryColor)
                    .frame(width: 110, alignment: .leading)
                    .lineLimit(1)
            }

            if showSize {
                Text(item.isBrowsableFolder ? "--" : Format.bytes(item.size))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(secondaryColor)
                    .frame(width: 72, alignment: .trailing)
                    .lineLimit(1)
            }

            if showKind {
                Text(item.displayKind)
                    .font(.system(size: 11))
                    .foregroundStyle(secondaryColor)
                    .frame(width: 140, alignment: .leading)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: height)
        .background(backgroundColor)
        .contentShape(Rectangle())
    }

    private var primaryColor: Color {
        if isSelected && isActivePane { return Palette.selectedText }
        return Palette.text
    }

    private var secondaryColor: Color {
        if isSelected && isActivePane { return Palette.selectedTextSecondary }
        return Palette.textSecondary
    }

    private var backgroundColor: Color {
        if isSelected {
            return isActivePane ? Palette.selection : Palette.selectionInactive
        }
        if hovered { return Palette.rowHover }
        if alternate { return Palette.rowAlternate }
        return .clear
    }
}

// MARK: - Stato vuoto

struct EmptyFolderView: View {
    var message: String = ""
    var detail: String?

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "folder")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Palette.textTertiary)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Overlay attività

struct ActivityOverlay: View {
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Palette.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 14, y: 5)
    }
}

// MARK: - Foglio rinomina

struct RenameSheet: View {
    let request: RenameRequest
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @FocusState private var focused: Bool

    init(request: RenameRequest) {
        self.request = request
        _name = State(initialValue: request.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.tint)
                Text(L("Rename"))
                    .font(.system(size: 14, weight: .semibold))
            }

            TextField(L("Name"), text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .focused($focused)
                .onSubmit(commit)

            HStack {
                Text(request.url.deletingLastPathComponent().lastPathComponent)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
                Spacer()
                Button(L("Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L("Rename")) { commit() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 430)
        .onAppear {
            focused = true
            DispatchQueue.main.async {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            }
        }
    }

    private func commit() {
        app.commitRename(request, newName: name)
    }
}

// MARK: - Drag & Drop

enum DropHelper {
    static func urls(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        let lock = NSLock()
        var result: [URL] = []

        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let value = item as? NSURL {
                    url = value as URL
                } else if let value = item as? URL {
                    url = value
                }
                if let url {
                    lock.lock()
                    result.append(url)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            completion(result)
        }
    }
}

// MARK: - Divisore

struct VDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.border)
            .frame(width: 1)
    }
}

/// Divisore verticale trascinabile per sidebar e pannello anteprima.
struct SplitDivider: View {
    @Binding var width: Double
    let minWidth: Double
    let maxWidth: Double
    var inverted = false

    @State private var startWidth: Double?
    @State private var cursorPushed = false

    var body: some View {
        ZStack {
            Color.clear
            Rectangle()
                .fill(Palette.border)
                .frame(width: 1)
        }
        .frame(width: 6)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside, !cursorPushed {
                NSCursor.resizeLeftRight.push()
                cursorPushed = true
            } else if !inside, cursorPushed {
                NSCursor.pop()
                cursorPushed = false
            }
        }
        .onDisappear {
            if cursorPushed {
                NSCursor.pop()
                cursorPushed = false
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if startWidth == nil { startWidth = width }
                    let base = startWidth ?? width
                    let delta = inverted ? -value.translation.width : value.translation.width
                    width = min(maxWidth, max(minWidth, base + delta))
                }
                .onEnded { _ in
                    startWidth = nil
                }
        )
    }
}
