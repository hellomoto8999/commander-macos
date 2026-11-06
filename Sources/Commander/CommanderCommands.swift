import SwiftUI
import AppKit

struct CommanderCommands: Commands {
    @ObservedObject var app: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(L("New Tab")) { app.newTab() }
                .keyboardShortcut("t", modifiers: .command)
            Button(L("New Folder")) { app.createFolder() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button(L("New File")) { app.createFile() }
                .keyboardShortcut("n", modifiers: [.command, .control])
            Divider()
            Button(L("Close Tab")) { app.closeTab() }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            Button(L("Next Tab")) { app.nextTab() }
                .keyboardShortcut(.tab, modifiers: .control)
            Button(L("Previous Tab")) { app.previousTab() }
                .keyboardShortcut(.tab, modifiers: [.control, .shift])
        }

        CommandGroup(after: .newItem) {
            Divider()
            Button(L("Open")) { app.openSelection() }
                .keyboardShortcut("o", modifiers: .command)
            Button(L("Rename")) { app.renameSelection() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Button(L("Duplicate")) { app.duplicateSelection() }
                .keyboardShortcut("d", modifiers: .command)
            Button(L("Get Info")) { app.getInfo() }
                .keyboardShortcut("i", modifiers: .command)
            Button(L("Show Inspector")) { app.getInfo() }
                .keyboardShortcut("i", modifiers: [.command, .option])
            Button(L("Make Alias")) { app.makeAliasSelection() }
                .keyboardShortcut("a", modifiers: [.command, .control])
            Button(L("Quick Look")) { app.toggleQuickLook() }
                .keyboardShortcut("y", modifiers: .command)
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button(L("Copy File")) { app.copySelection() }
            Button(L("Cut File")) { app.cutSelection() }
            Button(L("Paste File")) { app.paste() }
                .keyboardShortcut("v", modifiers: .command)
            Button(L("Move Item Here")) { app.movePasteHere() }
                .keyboardShortcut("v", modifiers: [.command, .option])
            Button(L("Move to Trash")) { app.trashSelection() }
                .keyboardShortcut(.delete, modifiers: .command)
            Button(L("Empty Trash…")) { app.emptyTrash() }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
            Button(L("Delete Immediately…")) { app.deletePermanently() }
                .keyboardShortcut(.delete, modifiers: [.command, .option])
        }

        CommandMenu(L("Go")) {
            Button(L("Back")) { app.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(app.activeTab?.canGoBack != true)
            Button(L("Forward")) { app.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(app.activeTab?.canGoForward != true)
            Button(L("Enclosing Folder")) { app.goUp() }
                .keyboardShortcut(.upArrow, modifiers: .command)
            Button(L("Enclosing Folder in New Tab")) { app.openEnclosingInNewTab() }
                .keyboardShortcut(.upArrow, modifiers: [.command, .shift])
            Divider()
            Button(L("Go to Folder…")) { app.focusPathBar() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Button(L("Filter in Folder")) { app.focusSearch() }
                .keyboardShortcut("f", modifiers: .command)
            Divider()
            Button(L("Home")) { app.go(to: FileManager.default.homeDirectoryForCurrentUser) }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            Button(L("Desktop")) {
                app.go(to: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"))
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            Button(L("Documents")) {
                app.go(to: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents"))
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            Button(L("Downloads")) {
                app.go(to: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"))
            }
            .keyboardShortcut("l", modifiers: [.command, .option])
            Button(L("Applications")) { app.go(to: URL(fileURLWithPath: "/Applications")) }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            Button(L("Utilities")) { app.goToUtilities() }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            Button(L("Computer")) { app.goToComputer() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            Button(L("iCloud Drive")) { app.goToICloud() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            Button(L("Network")) { app.goToNetwork() }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            Divider()
            Button(L("Connect to Server…")) { app.beginConnectToServer() }
                .keyboardShortcut("k", modifiers: .command)
            Button(L("Eject")) { app.ejectCurrentVolume() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(!app.canEjectCurrentVolume)
            Divider()
            Button(L("Next Pane")) { app.activateOtherPane() }
                .keyboardShortcut(.tab, modifiers: [.command, .option])
        }

        CommandMenu(L("View")) {
            Button(L("Icons")) { app.setViewMode(.icons) }
                .keyboardShortcut("1", modifiers: .command)
            Button(L("List")) { app.setViewMode(.list) }
                .keyboardShortcut("2", modifiers: .command)
            Button(L("Columns")) { app.setViewMode(.columns) }
                .keyboardShortcut("3", modifiers: .command)
            Divider()

            Button(L("Show View Options")) { app.showViewOptions = true }
                .keyboardShortcut("j", modifiers: .command)

            Menu(L("Sort By")) {
                ForEach(SortField.allCases) { field in
                    Button(field.label) {
                        app.activeTab?.sort(by: field)
                    }
                }
                Divider()
                Button(L("Ascending")) {
                    if app.activeTab?.sortAscending == false {
                        app.activeTab?.sortAscending = true
                    }
                }
                Button(L("Descending")) {
                    if app.activeTab?.sortAscending == true {
                        app.activeTab?.sortAscending = false
                    }
                }
            }

            Divider()
            Button(app.showSidebar ? L("Hide Sidebar") : L("Show Sidebar")) {
                app.showSidebar.toggle()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            Button(app.showPreview ? L("Hide Preview") : L("Show Preview")) {
                app.showPreview.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
            Button(L("Show/Hide Toolbar")) { app.toggleToolbar() }
                .keyboardShortcut("t", modifiers: [.command, .option])
            Button(app.showPathBar ? L("Hide Path Bar") : L("Show Path Bar")) {
                app.showPathBar.toggle()
            }
            Button(app.showStatusBar ? L("Hide Status Bar") : L("Show Status Bar")) {
                app.showStatusBar.toggle()
            }
            .keyboardShortcut("/", modifiers: .command)
            Button(app.showTabBar ? L("Hide Tab Bar") : L("Show Tab Bar")) {
                app.showTabBar.toggle()
            }
            Button(app.dualPane ? L("Single Pane") : L("Double Pane")) {
                app.dualPane.toggle()
            }
            .keyboardShortcut("d", modifiers: [.command, .option])
            Divider()
            Button(app.showHidden ? L("Hide Hidden Files") : L("Show Hidden Files")) {
                app.showHidden.toggle()
            }
            .keyboardShortcut(".", modifiers: [.command, .shift])
            Toggle(L("Folders on Top"), isOn: $app.foldersFirst)
            Divider()
            Button(L("Refresh")) { app.refreshAllTabs() }
                .keyboardShortcut("r", modifiers: .command)
            Button(L("Zoom In")) { app.zoomIconsIn() }
                .keyboardShortcut("+", modifiers: .command)
            Button(L("Zoom Out")) { app.zoomIconsOut() }
                .keyboardShortcut("-", modifiers: .command)
            Button(L("Actual Size")) { app.resetIconSize() }
                .keyboardShortcut("0", modifiers: .command)
            Button(L("Quick Look")) { app.toggleQuickLook() }
                .keyboardShortcut("y", modifiers: .command)
            Button(L("Share…")) { app.shareSelection() }
            Button(L("Show in Finder")) { app.revealInFinder() }
            Button(L("Open in Terminal")) { app.openInTerminal() }
            Divider()
            Button(L("Enter Full Screen")) {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .control])
        }
    }
}
