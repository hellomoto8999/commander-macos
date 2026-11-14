import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var zoom: ZoomState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            general
                .tabItem { Label(L("General"), systemImage: "gearshape") }
                .tag(0)
            sidebar
                .tabItem { Label(L("Sidebar"), systemImage: "sidebar.left") }
                .tag(1)
            tags
                .tabItem { Label(L("Tags"), systemImage: "tag") }
                .tag(2)
            advanced
                .tabItem { Label(L("Advanced"), systemImage: "slider.horizontal.3") }
                .tag(3)
            shortcuts
                .tabItem { Label(L("Shortcuts"), systemImage: "keyboard") }
                .tag(4)
            about
                .tabItem { Label(L("Info"), systemImage: "info.circle") }
                .tag(5)
        }
        .frame(width: 600, height: 700)
        .onAppear {
            if let raw = ProcessInfo.processInfo.environment["COMMANDER_SETTINGS_TAB"],
               let index = Int(raw), (0...5).contains(index) {
                selectedTab = index
            }
        }
    }

    // MARK: - Generali

    private var general: some View {
        Form {
            Section(L("Startup")) {
                HStack {
                    Text(L("New windows open in"))
                    Spacer()
                    Picker(L("Folder"), selection: $app.startFolderPath) {
                        ForEach(startFolders, id: \.path) { folder in
                            Label(folder.name, systemImage: folder.symbol)
                                .tag(folder.path)
                        }
                        if !startFolders.contains(where: { $0.path == app.startFolderPath }) {
                            Label(
                                FileManager.default.displayName(atPath: app.startFolderPath),
                                systemImage: "folder"
                            )
                            .tag(app.startFolderPath)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 260)

                    Button(L("Choose…")) { app.chooseStartFolder() }
                }

                Button(L("Reset Saved Tabs")) { app.resetSession() }
            }

            Section(L("Views")) {
                Picker(L("Default View"), selection: $app.defaultViewMode) {
                    ForEach(ViewMode.allCases) { mode in
                        Label(mode.label, systemImage: mode.symbol).tag(mode)
                    }
                }
                Toggle(L("Show Sidebar"), isOn: $app.showSidebar)
                Toggle(L("Show Preview Pane"), isOn: $app.showPreview)
                Toggle(L("Show Path Bar"), isOn: $app.showPathBar)
                Toggle(L("Show Status Bar"), isOn: $app.showStatusBar)
                Toggle(L("Show Tab Bar"), isOn: $app.showTabBar)
                Toggle(L("Show Hidden Files"), isOn: $app.showHidden)
                Toggle(L("Folders on Top"), isOn: $app.foldersFirst)
                Toggle(L("Use Relative Dates"), isOn: $app.useRelativeDates)
                Toggle(L("Show Icon Previews"), isOn: $app.showIconPreviews)
                Toggle(L("Show Item Info"), isOn: $app.showIconItemInfo)

                HStack {
                    Text(L("Icon Size"))
                    Slider(value: $zoom.iconSize, in: 48...160, step: 4)
                    Text("\(Int(zoom.iconSize)) px")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
            }

            Section(L("Browsing")) {
                Toggle(L("Open Folders in New Tabs"), isOn: $app.openFoldersInNewTab)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Barra laterale

    private var sidebar: some View {
        Form {
            Section(L("Show in Sidebar")) {
                Toggle(L("Favorites"), isOn: $app.sidebarFavorites)
                Toggle(L("Cloud"), isOn: $app.sidebarCloud)
                Toggle(L("Locations"), isOn: $app.sidebarLocations)
                Toggle(L("Volumes"), isOn: $app.sidebarVolumes)
                    .disabled(!app.sidebarLocations)
                Toggle(L("Network"), isOn: $app.sidebarNetwork)
                    .disabled(!app.sidebarLocations)
                Toggle(L("Trash"), isOn: $app.sidebarTrash)
                    .disabled(!app.sidebarLocations)
                Toggle(L("Tags"), isOn: $app.sidebarTags)
            }

            Section {
                Text(L("Choose which groups are shown in the sidebar, as in Finder."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tag

    private var tags: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Tags"))
                .font(.system(size: 13, weight: .semibold))
            Text(L("Tags appear in the item context menu and are written to the file metadata."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach($app.tagDefinitions) { $tag in
                        HStack(spacing: 10) {
                            HStack(spacing: 4) {
                                ForEach(0..<FinderTagPalette.colors.count, id: \.self) { index in
                                    Button {
                                        tag.colorIndex = index
                                    } label: {
                                        Circle()
                                            .fill(FinderTagPalette.color(at: index))
                                            .frame(width: 14, height: 14)
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        tag.colorIndex == index
                                                            ? Color(nsColor: .labelColor)
                                                            : Color.clear,
                                                        lineWidth: 1.5
                                                    )
                                                    .padding(-3)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            TextField(L("Name"), text: $tag.name)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))

                            Button {
                                app.tagDefinitions.removeAll { $0.id == tag.id }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(L("Remove"))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 260)

            HStack {
                Button(L("Add Tag")) {
                    app.tagDefinitions.append(
                        FinderTagDefinition(
                            name: L("New Tag"),
                            colorIndex: min(6, app.tagDefinitions.count % 7)
                        )
                    )
                }
                Button(L("Restore Default Tags")) { app.resetTagDefinitions() }
                Spacer()
            }
        }
        .padding(20)
    }

    // MARK: - Avanzate

    private var advanced: some View {
        Form {
            Section(L("Search")) {
                Toggle(L("Include Subfolders When Filtering"), isOn: $app.searchSubfolders)
                Text(L("When enabled, the filter also searches inside subfolders of the current folder."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section(L("Warnings")) {
                Toggle(L("Show Library Folder"), isOn: $app.showLibraryFolder)
                Toggle(L("Show All Filename Extensions"), isOn: $app.showAllExtensions)
                Toggle(L("Warn Before Changing Extension"), isOn: $app.warnExtensionChange)
                Toggle(L("Confirm Before Deleting Permanently"), isOn: $app.confirmDelete)
                Toggle(L("Warn Before Emptying Trash"), isOn: $app.warnEmptyTrash)
            }

            Section(L("Reset")) {
                Button(L("Reset Saved Tabs")) { app.resetSession() }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Scorciatoie e gesti

    private var shortcuts: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                shortcut(L("Change Pane"), "Tab")
                shortcut(L("New Tab"), "⌘T")
                shortcut(L("Close Tab"), "⌘W")
                shortcut(L("New Folder"), "⌘⇧N")
                shortcut(L("New File"), "⌃⌘N")
                shortcut(L("Rename"), "↩")
                shortcut(L("Open"), "⌘↓ / ⌘O")
                shortcut(L("Get Info"), "⌘I / ⌥⌘I")
                shortcut(L("Make Alias"), "⌃⌘A")
                shortcut(L("Quick Look"), "Space / ⌘Y")
                shortcut(L("Move to Trash"), "⌘⌫")
                shortcut(L("Empty Trash…"), "⌘⇧⌫")
                shortcut(L("Delete Immediately…"), "⌘⌥⌫")
                shortcut(L("Go to Folder…"), "⌘L / ⇧⌘G")
                shortcut(L("Back") + " / " + L("Forward"), "⌘[ / ⌘]")
                shortcut(L("Enclosing Folder"), "⌘↑")
                shortcut(L("Enclosing Folder in New Tab"), "⌘⇧↑")
                shortcut(L("Select first / last"), "Home / End")
                shortcut(L("Extend to first / last"), "⇧Home / ⇧End")
                shortcut(L("Page Up / Page Down"), "⇞ / ⇟")
                shortcut(L("Type-ahead"), L("Type the name"))
                shortcut(L("Filter in Folder"), "⌘F")
                shortcut(L("Refresh"), "⌘R")
                shortcut(L("Icons") + " / " + L("List") + " / " + L("Columns"), "⌘1 / ⌘2 / ⌘3")
                shortcut(L("Copy") + " / " + L("Cut") + " / " + L("Paste"), "⌘C / ⌘X / ⌘V")
                shortcut(L("Move Item Here"), "⌥⌘V")
                shortcut(L("Show Hidden Files"), "⇧⌘.")
                shortcut(L("Home") + " / " + L("Desktop") + " / " + L("Documents"), "⇧⌘H / ⇧⌘D / ⇧⌘O")
                shortcut(L("Applications") + " / " + L("Utilities") + " / " + L("Computer"), "⇧⌘A / ⇧⌘U / ⇧⌘C")
                shortcut(L("iCloud Drive") + " / " + L("Network"), "⇧⌘I / ⇧⌘K")
                shortcut(L("Connect to Server…"), "⌘K")
                shortcut(L("Eject"), "⌘E")
                shortcut(L("Copy Full Path"), "Click current folder / copy icon")
                shortcut(L("Double Pane") + " / " + L("Sidebar") + " / " + L("Preview"), "⌘⌥D / ⌘⌥S / ⌘⌥P")
                shortcut(L("Show/Hide Toolbar"), "⌘⌥T")
                shortcut(L("Show View Options"), "⌘J")

                Text(L("Mouse Gestures"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)

                shortcut(L("Select"), L("Click"))
                shortcut(L("Open"), L("Double-click"))
                shortcut(L("Context Menu"), L("Right-click / Control-click"))
                shortcut(L("Finder Context Menu"), L("Option + right-click"))
                shortcut(L("Open in New Tab"), L("Middle-click"))
                shortcut(L("Toggle Selection"), L("⌘-click"))
                shortcut(L("Extend Selection"), L("⇧-click"))
                shortcut(L("Open in New Tab"), L("⌘-double-click"))
                shortcut(L("Open in Other Pane"), L("⌥-double-click"))
                shortcut(L("Move / Copy"), L("Drag"))
                shortcut(L("Deselect"), L("Click background"))
                shortcut(L("Back") + " / " + L("Forward"), L("Two-finger swipe"))
                shortcut(L("Zoom Icons"), L("Pinch"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
    }

    private func shortcut(_ title: String, _ keys: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Palette.text)
            Spacer()
            Text(keys)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Palette.border, lineWidth: 0.5)
                )
        }
    }

    // MARK: - Info

    private var about: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            Text("Commander")
                .font(.system(size: 20, weight: .semibold))
            Text(L("Version 1.0.1"))
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.textSecondary)
            Text(L("A dual-pane file manager for macOS,\nwith Finder-style views, tabs and previews."))
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Text(L("Inspired by OneCommander"))
                .font(.system(size: 10))
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cartelle iniziali

    private struct StartFolder {
        let name: String
        let path: String
        let symbol: String
    }

    private var startFolders: [StartFolder] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            StartFolder(name: L("Home"), path: home.path, symbol: "house"),
            StartFolder(name: L("Desktop"), path: home.appendingPathComponent("Desktop").path, symbol: "display"),
            StartFolder(name: L("Documents"), path: home.appendingPathComponent("Documents").path, symbol: "doc"),
            StartFolder(name: L("Downloads"), path: home.appendingPathComponent("Downloads").path, symbol: "arrow.down.circle"),
            StartFolder(name: L("Applications"), path: "/Applications", symbol: "square.grid.2x2"),
            StartFolder(name: L("Computer"), path: "/", symbol: "internaldrive")
        ]
    }
}
