import SwiftUI
import AppKit

// MARK: - Menu dello sfondo di una cartella

struct FolderBackgroundMenu: View {
    @ObservedObject var tab: BrowserTab
    let folder: URL
    @EnvironmentObject private var app: AppState

    private var isCurrent: Bool {
        folder.standardizedFileURL == tab.currentFolder.standardizedFileURL
    }

    var body: some View {
        if isCurrent {
            Button(L("New Folder")) { app.createFolder(in: folder) }
            Button(L("New File")) { app.createFile(in: folder) }
            Button(L("Paste")) { app.paste(into: folder) }
                .disabled(!FileClipboard.hasFiles())
            Divider()
            Button(L("Select All")) { tab.selectAll() }
            Divider()
        }

        Button(L("Refresh")) { tab.load(folder, force: true) }
        Button(L("Show in Finder")) {
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        }
        Button(L("Open in Terminal")) { app.openTerminal(at: folder) }

        if isCurrent {
            Divider()
            Toggle(L("Show Hidden Files"), isOn: $app.showHidden)
            Toggle(L("Folders on Top"), isOn: $app.foldersFirst)

            Menu(L("Sort By")) {
                ForEach(SortField.allCases) { field in
                    Button {
                        tab.sort(by: field)
                    } label: {
                        Label(
                            field.label + (tab.sortField == field ? (tab.sortAscending ? " ↑" : " ↓") : ""),
                            systemImage: tab.sortField == field ? "checkmark" : field.symbol
                        )
                    }
                }
            }

            Menu(L("View")) {
                ForEach(ViewMode.allCases) { mode in
                    Button(mode.label) { tab.viewMode = mode }
                }
            }

            Divider()
            Button(L("Add to Favorites")) { app.addFavorite(folder) }
            Button(L("Copy Path")) { app.copyPath(folder) }
        }
    }
}
