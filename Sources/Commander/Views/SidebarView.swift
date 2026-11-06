import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SidebarContainer: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        if let tab = app.activeTab {
            SidebarView(tab: tab)
        } else {
            Color.clear
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject var tab: BrowserTab

    @State private var dropTargeted = false
    @State private var draggingFavoriteID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                if app.sidebarFavorites {
                    sectionHeader(L("Favorites"), showAdd: true)

                    ForEach(app.favorites.filter { FileSystem.fm.fileExists(atPath: $0.path) }) { favorite in
                        SidebarRow(
                            name: favorite.name,
                            symbol: favorite.symbol,
                            selected: isSelected(favorite.url)
                        ) {
                            open(favorite.url)
                        }
                        .contextMenu {
                            Button(L("Open in New Tab")) { app.newTab(at: favorite.url) }
                            Button(L("Show in Finder")) {
                                NSWorkspace.shared.activateFileViewerSelecting([favorite.url])
                            }
                            Divider()
                            Button(L("Remove from Favorites")) {
                                app.removeFavorite(favorite)
                            }
                        }
                    }
                }

                if app.sidebarCloud && !app.cloudLocations.isEmpty {
                    sectionHeader(L("Cloud"))
                    ForEach(app.cloudLocations) { location in
                        SidebarRow(
                            name: location.name,
                            symbol: location.symbol,
                            selected: isSelected(location.url)
                        ) {
                            open(location.url)
                        }
                    }
                }

                if app.sidebarLocations && (app.sidebarNetwork || app.sidebarVolumes || app.sidebarTrash) {
                    sectionHeader(L("Locations"))
                }

                if app.sidebarLocations && app.sidebarNetwork {
                    SidebarRow(
                        name: L("Network"),
                        symbol: "network",
                        selected: false
                    ) {
                        app.beginConnectToServer()
                    }
                    .contextMenu {
                        Button(L("Connect to Server…")) { app.beginConnectToServer() }
                    }
                }

                if app.sidebarLocations && app.sidebarVolumes {
                    ForEach(app.volumes) { volume in
                        VolumeSidebarRow(
                            volume: volume,
                            selected: isSelected(volume.url),
                            onOpen: { open(volume.url) },
                            onEject: { app.eject(volume) }
                        )
                        .contextMenu {
                            Button(L("Open")) { open(volume.url) }
                            if volume.canEject {
                                Button(volume.ejectTitle) { app.eject(volume) }
                            }
                            Button(L("Show in Finder")) {
                                NSWorkspace.shared.open(volume.url)
                            }
                        }
                    }
                }

                if app.sidebarLocations && app.sidebarTrash {
                    let trash = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash")
                    SidebarRow(
                        name: L("Trash"),
                        symbol: "trash",
                        selected: isSelected(trash)
                    ) {
                        open(trash)
                    }
                    .contextMenu {
                        Button(L("Open")) { open(trash) }
                        Button(L("Empty Trash…")) { app.emptyTrash() }
                    }
                }

                if app.sidebarLocations && app.sidebarNetwork {
                    SidebarNetworkSection(browser: app.network) { server in
                        app.connect(to: server)
                    }
                }

                if app.sidebarTags && !app.tagDefinitions.isEmpty {
                    sectionHeader(L("Tags"))
                    ForEach(app.tagDefinitions) { tag in
                        TagSidebarRow(
                            tag: tag,
                            selected: tab.tagFilterName == tag.name
                        ) {
                            app.showTag(tag)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .scrollIndicators(.never)
        .background(
            VisualEffectBackground(material: .sidebar, blending: .behindWindow)
        )
        .overlay(
            Rectangle()
                .strokeBorder(Color.accentColor.opacity(dropTargeted ? 0.5 : 0), lineWidth: 2)
        )
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $dropTargeted) { providers in
            DropHelper.urls(from: providers) { urls in
                for url in urls {
                    var isDirectory: ObjCBool = false
                    if FileSystem.fm.fileExists(atPath: url.path, isDirectory: &isDirectory),
                       isDirectory.boolValue {
                        app.addFavorite(url)
                    }
                }
            }
            return true
        }
    }

    private func open(_ url: URL) {
        app.activate(app.activePane ?? app.panes[0])
        app.go(to: url)
    }

    private func isSelected(_ url: URL) -> Bool {
        tab.currentFolder.standardizedFileURL.path == url.standardizedFileURL.path
    }

    private func sectionHeader(_ title: String, showAdd: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            if showAdd {
                Button {
                    chooseFolder()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Palette.textTertiary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L("Add Folder to Favorites"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 14)
        .padding(.bottom, 3)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = L("Add to Favorites")
        panel.message = L("Add Folder to Favorites")
        if panel.runModal() == .OK {
            for url in panel.urls {
                app.addFavorite(url)
            }
        }
    }
}

private struct FavoriteDropDelegate: DropDelegate {
    let target: Favorite
    @Binding var draggingID: String?
    let favorites: [Favorite]
    let move: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != target.id,
              let from = favorites.firstIndex(where: { $0.id == draggingID }),
              let to = favorites.firstIndex(where: { $0.id == target.id }) else { return }
        move(from, to)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

// MARK: - Riga semplice

struct SidebarRow: View {
    let name: String
    let symbol: String
    let selected: Bool
    var fileURL: URL? = nil
    let action: () -> Void

    @State private var hover = false

    var body: some View {
        HStack(spacing: 7) {
            sidebarIcon
                .frame(width: 17, height: 17)

            Text(name)
                .font(.system(size: 13))
                .foregroundStyle(selected ? Palette.selectedText : Palette.text)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? Palette.selection : (hover ? Palette.rowHover : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(perform: action)
    }

    @ViewBuilder
    private var sidebarIcon: some View {
        if let fileURL {
            Image(nsImage: NSWorkspace.shared.icon(forFile: fileURL.path))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(selected ? Palette.selectedText : sidebarTint)
        }
    }

    private var sidebarTint: Color {
        switch symbol {
        case "house.fill", "display", "doc.fill", "arrow.down.circle.fill", "square.grid.2x2.fill", "icloud", "cloud":
            return Color(nsColor: .systemBlue)
        case "film.fill":
            return Color(nsColor: .systemPurple)
        case "music.note":
            return Color(nsColor: .systemPink)
        case "photo.fill":
            return Color(nsColor: .systemOrange)
        default:
            return Palette.textSecondary
        }
    }
}

// MARK: - Riga volume con espulsione

struct VolumeSidebarRow: View {
    let volume: Volume
    let selected: Bool
    let onOpen: () -> Void
    let onEject: () -> Void

    @State private var hover = false

    var body: some View {
        HStack(spacing: 7) {
            HStack(spacing: 7) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: volume.url.path))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 17, height: 17)

                Text(volume.name)
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? Palette.selectedText : Palette.text)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            if volume.canEject && (hover || selected) {
                Button(action: onEject) {
                    Image(systemName: "eject")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(selected ? Palette.selectedTextSecondary : Palette.textSecondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(volume.ejectTitle)
            }
        }
        .padding(.horizontal, 7)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? Palette.selection : (hover ? Palette.rowHover : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
}

// MARK: - Tag nella barra laterale

struct TagSidebarRow: View {
    let tag: FinderTagDefinition
    let selected: Bool
    let action: () -> Void

    @State private var hover = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tag.color)
                .frame(width: 9, height: 9)
                .frame(width: 17, alignment: .center)

            Text(tag.name)
                .font(.system(size: 13))
                .foregroundStyle(selected ? Palette.selectedText : Palette.text)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? Palette.selection : (hover ? Palette.rowHover : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(perform: action)
    }
}

// MARK: - Server di rete scoperti

struct SidebarNetworkSection: View {
    @ObservedObject var browser: NetworkBrowser
    let onConnect: (NetworkServer) -> Void

    var body: some View {
        if !browser.servers.isEmpty {
            HStack(spacing: 4) {
                Text(L("Network Servers"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Button {
                    browser.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Palette.textTertiary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L("Refresh"))
            }
            .padding(.horizontal, 8)
            .padding(.top, 14)
            .padding(.bottom, 3)

            ForEach(browser.servers) { server in
                SidebarRow(
                    name: server.name,
                    symbol: "server.rack",
                    selected: false
                ) {
                    onConnect(server)
                }
            }
        }
    }
}
