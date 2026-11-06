import SwiftUI

struct ViewOptionsSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let tab = app.activeTab {
                ViewOptionsContent(tab: tab) { dismiss() }
            } else {
                EmptyFolderView(message: L("No Selection"))
                    .frame(width: 430, height: 420)
            }
        }
    }
}

private struct ViewOptionsContent: View {
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var zoom: ZoomState
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.tint)
                Text(L("Show View Options"))
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }

            Form {
                Section(L("View")) {
                    Picker(L("View"), selection: Binding(
                        get: { tab.viewMode },
                        set: { app.setViewMode($0) }
                    )) {
                        ForEach(ViewMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.symbol).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text(L("Default View for New Tabs"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(String(format: L("Use “%@”"), tab.viewMode.label)) {
                            app.defaultViewMode = tab.viewMode
                        }
                        .controlSize(.small)
                        .disabled(app.defaultViewMode == tab.viewMode)
                    }

                    if tab.viewMode == .icons {
                        HStack {
                            Text(L("Icon Size"))
                            Slider(value: $zoom.iconSize, in: 48...160, step: 4)
                            Text("\(Int(zoom.iconSize)) px")
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                }

                Section(L("Sort By")) {
                    Picker(L("Sort By"), selection: Binding(
                        get: { tab.sortField },
                        set: { tab.sort(by: $0) }
                    )) {
                        ForEach(SortField.allCases) { field in
                            Text(field.label).tag(field)
                        }
                    }
                    Toggle(L("Ascending"), isOn: Binding(
                        get: { tab.sortAscending },
                        set: { tab.sortAscending = $0 }
                    ))
                }

                Section(L("Show")) {
                    Toggle(L("Show Sidebar"), isOn: $app.showSidebar)
                    Toggle(L("Show Preview Pane"), isOn: $app.showPreview)
                    Toggle(L("Show Path Bar"), isOn: $app.showPathBar)
                    Toggle(L("Show Status Bar"), isOn: $app.showStatusBar)
                    Toggle(L("Show Tab Bar"), isOn: $app.showTabBar)
                    Toggle(L("Show Hidden Files"), isOn: $app.showHidden)
                    Toggle(L("Folders on Top"), isOn: $app.foldersFirst)
                    Toggle(L("Show Icon Previews"), isOn: $app.showIconPreviews)
                    Toggle(L("Show Item Info"), isOn: $app.showIconItemInfo)
                    Toggle(L("Use Relative Dates"), isOn: $app.useRelativeDates)
                }

                Section(L("Browsing")) {
                    Toggle(L("Open Folders in New Tabs"), isOn: $app.openFoldersInNewTab)
                    Toggle(L("Show All Filename Extensions"), isOn: $app.showAllExtensions)
                    Toggle(L("Show Library Folder"), isOn: $app.showLibraryFolder)
                    Toggle(L("Include Subfolders When Filtering"), isOn: $app.searchSubfolders)
                }
            }
            .formStyle(.grouped)

            HStack {
                Text(tab.currentFolder.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(L("Close"), action: close)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.small)
            }
        }
        .padding(18)
        .frame(width: 470, height: 620)
    }
}
