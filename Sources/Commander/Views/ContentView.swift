import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var app: AppState
    @AppStorage("pref.sidebarWidth") private var sidebarWidth: Double = 210
    @AppStorage("pref.previewWidth") private var previewWidth: Double = 290

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                if app.showSidebar {
                    SidebarContainer()
                        .frame(width: CGFloat(sidebarWidth))
                    SplitDivider(
                        width: $sidebarWidth,
                        minWidth: 165,
                        maxWidth: 310
                    )
                }

                HSplitView {
                    ForEach(app.visiblePanes) { pane in
                        PaneView(pane: pane, isActive: app.activePaneID == pane.id)
                            .frame(minWidth: 180, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)

                if app.showPreview {
                    SplitDivider(
                        width: $previewWidth,
                        minWidth: 190,
                        maxWidth: 430,
                        inverted: true
                    )
                    PreviewContainer()
                        .frame(width: CGFloat(previewWidth))
                }
            }

            if let activity = app.activity {
                ActivityOverlay(label: activity)
            }
        }
        .background(Palette.window)
        .background(WindowTitleHost())
        .toolbar {
            MainToolbar(app: app)
        }
        .sheet(item: $app.renameTarget) { request in
            RenameSheet(request: request)
                .environmentObject(app)
        }
        .sheet(isPresented: $app.showConnectSheet) {
            ConnectServerSheet(browser: app.network)
                .environmentObject(app)
        }
        .sheet(isPresented: $app.showViewOptions) {
            ViewOptionsSheet()
                .environmentObject(app)
                .environmentObject(app.zoom)
        }
        .alert(item: $app.errorMessage) { info in
            Alert(
                title: Text(info.title),
                message: Text(info.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            KeyMonitor.shared.install()
            app.persistSession()
        }
    }
}

// MARK: - Titolo finestra con icona proxy (stile Finder)

struct WindowTitleHost: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        if let tab = app.activeTab {
            WindowTitle(tab: tab)
        }
    }
}

private struct WindowTitle: View {
    @ObservedObject var tab: BrowserTab

    var body: some View {
        WindowTitleSetter(title: tab.title, url: tab.currentFolder)
            .frame(width: 0, height: 0)
    }
}

private struct WindowTitleSetter: NSViewRepresentable {
    let title: String
    let url: URL

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.title = title
            window.representedURL = url
        }
    }
}

// MARK: - Foglio connessione server

struct ConnectServerSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var browser: NetworkBrowser

    @State private var address = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.tint)
                Text(L("Connect to Server…"))
                    .font(.system(size: 14, weight: .semibold))
            }

            if !browser.servers.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("Network Servers"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(browser.servers.prefix(5)) { server in
                        HStack(spacing: 8) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(server.name)
                                    .font(.system(size: 12, weight: .medium))
                                Text(server.host == server.name
                                     ? server.scheme.uppercased()
                                     : "\(server.scheme.uppercased()) · \(server.host)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(L("Use")) {
                                address = "\(server.scheme)://\(server.connectHost)/"
                                app.connectError = nil
                                focused = true
                            }
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                }
                Divider()
            }

            Text(L("Enter a server address, for example smb://server/share."))
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)

            TextField(L("Server Address"), text: $address)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12.5))
                .focused($focused)
                .onSubmit(connect)

            if let error = app.connectError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: .systemRed))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(L("Cancel")) {
                    app.connectError = nil
                    app.connectAddress = ""
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(L("Connect")) { connect() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            address = app.connectAddress
            if address.isEmpty { app.connectError = nil }
            focused = true
        }
    }

    private func connect() {
        if app.connectToServer(address) {
            dismiss()
        }
    }
}
