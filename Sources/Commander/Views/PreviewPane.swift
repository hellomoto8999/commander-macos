import SwiftUI
import AppKit
import PDFKit

struct PreviewContainer: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        if let tab = app.activeTab {
            PreviewPane(tab: tab)
        } else {
            EmptyFolderView(message: L("No Selection"))
        }
    }
}

private struct FolderStats {
    var count: Int
    var size: Int64
}

struct PreviewPane: View {
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject private var app: AppState

    @State private var textPreview: String?
    @State private var folderStats: FolderStats?
    @State private var fullItem: FileItem?

    private var url: URL? { tab.previewURL }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(Palette.border)
                .frame(height: 1)

            if let url {
                ScrollView {
                    VStack(spacing: 0) {
                        previewArea(url: url)
                        Rectangle()
                            .fill(Palette.border)
                            .frame(height: 1)
                        details(url: url)
                        Rectangle()
                            .fill(Palette.border)
                            .frame(height: 1)
                        actions(url: url)
                    }
                }
                .scrollIndicators(.never)
            } else {
                EmptyFolderView(
                    message: L("No Selection"),
                    detail: L("Select an item to preview")
                )
            }
        }
        .background(Palette.preview)
        .task(id: url) {
            await load(url)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(L("Preview"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            IconButton(system: "xmark", help: L("Hide Preview"), iconSize: 10, width: 20) {
                app.showPreview = false
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(VisualEffectBackground(material: .headerView))
    }

    @ViewBuilder
    private func previewArea(url: URL) -> some View {
        let item = fullItem ?? FileItem(url: url)

        VStack(spacing: 8) {
            Group {
                if item.isImage {
                    AsyncThumbnail(url: url)
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .padding(.horizontal, 12)
                } else if item.isPDF {
                    PDFPreviewView(url: url)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .padding(.horizontal, 12)
                } else if item.isText && !item.isBrowsableFolder {
                    Text(textPreview ?? L("Loading…"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Palette.border, lineWidth: 1)
                        )
                        .padding(.horizontal, 12)
                } else if item.isAudio || item.isMovie {
                    VStack(spacing: 10) {
                        Image(nsImage: IconProvider.shared.icon(for: item))
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                        Button(L("Open")) {
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(nsImage: IconProvider.shared.icon(for: item))
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)

                        if item.isBrowsableFolder {
                            Text(L10n.items(folderStats?.count ?? FileSystem.itemCount(of: url)))
                                .font(.system(size: 10.5))
                                .foregroundStyle(Palette.textTertiary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()

            if tab.selection.count > 1 {
                Text(L10n.selected(tab.selection.count))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.bottom, 8)
            }
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity)
    }

    private func details(url: URL) -> some View {
        let item = fullItem ?? FileItem(url: url)

        return VStack(alignment: .leading, spacing: 9) {
            Text(item.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.text)
                .lineLimit(3)
                .truncationMode(.middle)
                .textSelection(.enabled)

            VStack(spacing: 6) {
                detailRow(L("Kind"), item.isBrowsableFolder ? L("Folder") : item.displayKind)
                detailRow(L("Size"), sizeText(item))
                detailRow(L("Created"), Format.fullDate(item.created))
                detailRow(L("Modified"), Format.fullDate(item.modified))
                if !item.tagNames.isEmpty {
                    detailRow(L("Tags"), item.tagNames.joined(separator: ", "))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(L("Path"))
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textTertiary)
                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Palette.textSecondary)
                    .textSelection(.enabled)
                    .lineLimit(3)
                    .truncationMode(.middle)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.textTertiary)
                .frame(width: 62, alignment: .leading)
            Text(value)
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(2)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func sizeText(_ item: FileItem) -> String {
        if item.isBrowsableFolder {
            if let folderStats {
                return Format.bytes(folderStats.size)
            }
            return L("Calculating…")
        }
        return Format.bytes(item.size)
    }

    private func actions(url: URL) -> some View {
        VStack(spacing: 8) {
            Button {
                if FileItem(url: url).isBrowsableFolder {
                    tab.navigate(to: url)
                } else {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text(L("Open"))
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
            }
            .buttonStyle(.bordered)

            HStack(spacing: 8) {
                actionButton(L("Quick Look"), "eye") {
                    QuickLookController.shared.toggle(urls: tab.previewItems)
                }
                actionButton(L("Show in Finder"), "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                actionButton(L("Copy Path"), "doc.on.doc") {
                    app.copyPath(url)
                }
            }
        }
        .padding(12)
    }

    private func actionButton(_ help: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(help)
    }

    private func load(_ url: URL?) async {
        textPreview = nil
        folderStats = nil
        fullItem = nil

        guard let url else { return }
        let item = FileItem(url: url)
        fullItem = item

        if item.isText && !item.isBrowsableFolder {
            let text = await Task.detached(priority: .userInitiated) {
                PreviewLoader.text(at: url)
            }.value
            textPreview = text
        }

        if item.isBrowsableFolder {
            let stats = await Task.detached(priority: .utility) {
                FolderStats(count: FileSystem.itemCount(of: url), size: FileSystem.size(of: url))
            }.value
            folderStats = stats
        }
    }
}

// MARK: - Miniatura asincrona

struct AsyncThumbnail: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(height: 80)
            }
        }
        .task(id: url) {
            image = ThumbnailProvider.shared.cached(for: url)
            guard image == nil else { return }
            ThumbnailProvider.shared.thumbnail(for: url, size: 640) { loaded in
                image = loaded
            }
        }
    }
}

// MARK: - PDF

struct PDFPreviewView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displaysPageBreaks = false
        view.backgroundColor = .clear
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.documentURL?.standardizedFileURL != url.standardizedFileURL {
            view.document = PDFDocument(url: url)
        }
    }
}

// MARK: - Lettura testo

enum PreviewLoader {
    static func text(at url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: 200_000)) ?? Data()
        guard !data.isEmpty else { return nil }
        if let string = String(data: data, encoding: .utf8) {
            return String(string.prefix(20_000))
        }
        if let string = String(data: data, encoding: .isoLatin1) {
            return String(string.prefix(20_000))
        }
        return nil
    }
}
