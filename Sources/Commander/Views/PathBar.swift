import SwiftUI
import AppKit

struct PathBar: View {
    @ObservedObject var pane: PaneState
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject private var app: AppState

    @State private var editing = false
    @State private var pathText = ""
    @State private var copied = false
    @FocusState private var pathFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            if editing {
                HStack(spacing: 5) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    TextField(L("Path"), text: $pathText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($pathFocused)
                        .onSubmit(commitPath)
                        .onExitCommand {
                            editing = false
                            pathFocused = false
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.8), lineWidth: 1)
                )
                .padding(.horizontal, 4)
            } else {
                Breadcrumb(
                    url: tab.currentFolder,
                    onNavigate: { url in
                        app.activate(pane)
                        tab.navigate(to: url)
                    },
                    onCopyPath: { _ in
                        app.activate(pane)
                        copyFullPath()
                    }
                )
                .padding(.horizontal, 4)
                .contextMenu {
                    Button(L("Copy Full Path")) { copyFullPath() }
                    Button(L("Edit Path…")) { startEditing() }
                    Button(L("Show in Finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([tab.currentFolder])
                    }
                }
            }

            Spacer(minLength: 4)

            Button {
                copyFullPath()
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(copied ? Color.accentColor : Color.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("Copy Full Path"))

            Menu {
                Button(L("New Folder")) { app.createFolder(in: tab.currentFolder) }
                Button(L("New File")) { app.createFile(in: tab.currentFolder) }
                Button(L("Paste")) { app.paste(into: tab.currentFolder) }
                    .disabled(!FileClipboard.hasFiles())
                Divider()
                Button(L("Refresh")) { tab.refresh() }
                Toggle(L("Show Hidden Files"), isOn: $app.showHidden)
                Toggle(L("Folders on Top"), isOn: $app.foldersFirst)
                Divider()
                Button(L("Add to Favorites")) { app.addFavorite(tab.currentFolder) }
                Button(L("Open in Terminal")) { app.openTerminal(at: tab.currentFolder) }
                Button(L("Copy Full Path")) { copyFullPath() }
                Button(L("Show in Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([tab.currentFolder])
                }
                Divider()
                Button(L("Close Tab")) { pane.closeTab(tab) }
                    .disabled(pane.tabs.count <= 1)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(L("Actions"))
        }
        .padding(.horizontal, 6)
        .frame(height: 30)
        .background(VisualEffectBackground(material: .headerView))
        .onChange(of: app.focusPathToken) { _, _ in
            startEditing()
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                app.activate(pane)
            }
        )
    }

    private func copyFullPath() {
        app.activate(pane)
        app.copyPath(tab.currentFolder)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copied = false
        }
    }

    private func startEditing() {
        app.activate(pane)
        pathText = tab.currentFolder.path
        editing = true
        DispatchQueue.main.async {
            pathFocused = true
        }
    }

    private func commitPath() {
        editing = false
        pathFocused = false
        let expanded = (pathText as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileSystem.fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            app.errorMessage = ErrorInfo(
                title: L("Path Not Found"),
                message: L("The path does not exist.")
            )
            return
        }
        if isDirectory.boolValue {
            tab.navigate(to: url)
        } else {
            tab.navigate(to: url.deletingLastPathComponent())
            tab.selection = [url]
        }
    }
}
