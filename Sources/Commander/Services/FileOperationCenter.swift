import SwiftUI
import AppKit

enum FileOperationKind {
    case copy
    case move
}

enum FileOperationState {
    case preparing
    case running
    case cancelling
    case finished
    case cancelled
    case failed
}

final class FileOperationModel: ObservableObject, Identifiable {
    let id = UUID()
    let kind: FileOperationKind
    let destination: URL
    let itemCount: Int
    let icon: NSImage?

    @Published var state: FileOperationState = .preparing
    @Published var completedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var currentName = ""
    @Published var completedItems = 0

    private let lock = NSLock()
    private var _cancelled = false

    init(kind: FileOperationKind, destination: URL, urls: [URL]) {
        self.kind = kind
        self.destination = destination
        self.itemCount = urls.count
        self.icon = NSWorkspace.shared.icon(forFile: urls.first?.path ?? destination.path)
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _cancelled
    }

    func cancel() {
        lock.lock()
        _cancelled = true
        lock.unlock()

        DispatchQueue.main.async {
            switch self.state {
            case .finished, .cancelled, .failed:
                break
            default:
                self.state = .cancelling
            }
        }
    }

    var title: String {
        switch state {
        case .preparing:
            return L("Preparing…")
        case .cancelling:
            return L("Cancelling…")
        case .finished:
            return L("Done")
        case .cancelled:
            return L("Cancelled")
        case .failed:
            return L("Operation Failed")
        case .running:
            if kind == .copy {
                return itemCount == 1
                    ? L("Copying 1 item")
                    : String(format: L("Copying %d items"), itemCount)
            }
            return itemCount == 1
                ? L("Moving 1 item")
                : String(format: L("Moving %d items"), itemCount)
        }
    }

    var itemProgressText: String {
        "\(completedItems) \(L("of")) \(itemCount)"
    }

    var progressValue: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(completedBytes) / Double(totalBytes))
    }

    func updateOnMain(_ block: @escaping (FileOperationModel) -> Void) {
        DispatchQueue.main.async {
            block(self)
        }
    }
}

// MARK: - Vista

struct FileOperationView: View {
    @ObservedObject var model: FileOperationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(nsImage: model.icon ?? NSImage())
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    Text(model.destination.path)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if model.state == .preparing || model.state == .cancelling || model.totalBytes == 0 {
                ProgressView()
                    .progressViewStyle(.linear)
                    .controlSize(.small)
            } else {
                ProgressView(value: model.progressValue)
                    .progressViewStyle(.linear)
                    .controlSize(.small)
            }

            HStack(spacing: 8) {
                Text(model.currentName.isEmpty ? L("Preparing…") : model.currentName)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if model.totalBytes > 0 {
                    Text("\(Format.bytes(model.completedBytes)) \(L("of")) \(Format.bytes(model.totalBytes))")
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            HStack {
                Text(model.itemProgressText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(L("Cancel")) {
                    model.cancel()
                }
                .controlSize(.small)
                .disabled(model.state == .finished || model.state == .cancelled || model.state == .failed)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 26)
        .padding(.bottom, 16)
        .frame(width: 380)
        .background(Palette.window)
    }
}

// MARK: - Pannello

final class FileOperationPanelController: NSWindowController, NSWindowDelegate {
    let model: FileOperationModel
    private let onClose: () -> Void
    private var allowClose = false

    init(model: FileOperationModel, onClose: @escaping () -> Void) {
        self.model = model
        self.onClose = onClose

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 170),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = model.kind == .copy ? L("Copying…") : L("Moving…")
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.appearance = nil
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = NSHostingController(rootView: FileOperationView(model: model))

        super.init(window: panel)
        panel.delegate = self
        panel.setContentSize(NSSize(width: 380, height: 170))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(offset: CGFloat) {
        guard let panel = window else { return }
        let screen = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: screen.midX - panel.frame.width / 2 + offset,
            y: screen.midY - panel.frame.height / 2 + offset
        )
        panel.setFrameOrigin(origin)
        panel.orderFront(nil)
    }

    func finish(closeAfter delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.allowClose = true
            self.window?.close()
            self.onClose()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if allowClose { return true }
        model.cancel()
        return false
    }
}

// MARK: - Centro operazioni

final class FileOperationCenter {
    private var controllers: [UUID: FileOperationPanelController] = [:]
    private var showWorkItems: [UUID: DispatchWorkItem] = [:]
    private let queue = DispatchQueue(
        label: "commander.file-operations",
        qos: .userInitiated,
        attributes: .concurrent
    )

    func copy(
        _ urls: [URL],
        to directory: URL,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(kind: .copy, urls: urls, to: directory, completion: completion)
    }

    func move(
        _ urls: [URL],
        to directory: URL,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(kind: .move, urls: urls, to: directory, completion: completion)
    }

    /// Pannello dimostrativo usato solo dagli hook di sviluppo.
    func showPreviewPanel() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let urls = [
            home.appendingPathComponent("Pictures"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop")
        ]
        let model = FileOperationModel(
            kind: .copy,
            destination: home.appendingPathComponent("Downloads"),
            urls: urls
        )
        model.state = .running
        model.totalBytes = 48_200_000
        model.completedBytes = 21_400_000
        model.currentName = "vacanze-estate-2026.jpg"
        model.completedItems = 1

        let controller = FileOperationPanelController(model: model) { [weak self] in
            self?.controllers.removeValue(forKey: model.id)
        }
        controllers[model.id] = controller
        controller.show(offset: 0)
    }

    private func run(
        kind: FileOperationKind,
        urls: [URL],
        to directory: URL,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var urls = urls
        if kind == .move {
            urls = urls.filter {
                $0.deletingLastPathComponent().standardizedFileURL != directory.standardizedFileURL
            }
        }
        guard !urls.isEmpty else {
            completion(.success(()))
            return
        }

        let model = FileOperationModel(kind: kind, destination: directory, urls: urls)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard model.state == .preparing || model.state == .running else {
                self.showWorkItems.removeValue(forKey: model.id)
                return
            }

            let controller = FileOperationPanelController(model: model) { [weak self] in
                self?.controllers.removeValue(forKey: model.id)
                self?.showWorkItems.removeValue(forKey: model.id)
            }
            self.controllers[model.id] = controller
            controller.show(offset: CGFloat(max(0, self.controllers.count - 1)) * 22)
        }

        showWorkItems[model.id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)

        queue.async {
            let result: Result<Void, Error>
            do {
                let isCancelled: () -> Bool = { model.isCancelled }

                if kind == .move {
                    let sameVolume = urls.allSatisfy { FileOperationEngine.sameVolume($0, directory) }
                    if sameVolume {
                        model.updateOnMain { $0.state = .running }
                    } else {
                        let total = try FileOperationEngine.totalSize(of: urls, isCancelled: isCancelled)
                        model.updateOnMain {
                            $0.totalBytes = total
                            $0.state = .running
                        }
                    }
                } else {
                    let total = try FileOperationEngine.totalSize(of: urls, isCancelled: isCancelled)
                    model.updateOnMain {
                        $0.totalBytes = total
                        $0.state = .running
                    }
                }

                var completed: Int64 = 0
                var lastUpdate = Date.distantPast
                var lastName = ""

                let progress: (Int64, String) -> Void = { delta, name in
                    completed += delta
                    let now = Date()
                    if now.timeIntervalSince(lastUpdate) > 0.05 || name != lastName {
                        lastUpdate = now
                        lastName = name
                        let snapshot = completed
                        model.updateOnMain {
                            $0.completedBytes = snapshot
                            $0.currentName = name
                        }
                    }
                }

                let onItem: (Int) -> Void = { count in
                    model.updateOnMain { $0.completedItems = count }
                }

                if kind == .copy {
                    try FileOperationEngine.copy(
                        urls,
                        to: directory,
                        progress: progress,
                        onItemCompleted: onItem,
                        isCancelled: isCancelled
                    )
                } else {
                    try FileOperationEngine.move(
                        urls,
                        to: directory,
                        progress: progress,
                        onItemCompleted: onItem,
                        isCancelled: isCancelled
                    )
                }

                result = .success(())
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async {
                switch result {
                case .success:
                    model.state = .finished
                case .failure(let error):
                    if error is FileOperationCancelled {
                        model.state = .cancelled
                    } else {
                        model.state = .failed
                    }
                }

                self.showWorkItems[model.id]?.cancel()
                self.showWorkItems.removeValue(forKey: model.id)

                let delay: TimeInterval = model.state == .finished ? 0.4 : 0
                self.controllers[model.id]?.finish(closeAfter: delay)
                completion(result)
            }
        }
    }
}
