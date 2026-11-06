import SwiftUI
import AppKit

/// Registro geometrico delle righe visibili. Il monitor degli eventi usa i
/// frame in coordinate finestra per capire su quale elemento è avvenuto il
/// click, senza dipendere dall'hit-testing delle viste SwiftUI.
final class ClickRegistry {
    static let shared = ClickRegistry()

    private final class WeakTarget {
        weak var view: RowTargetView?

        init(_ view: RowTargetView) {
            self.view = view
        }
    }

    private var targets: [WeakTarget] = []
    private final class WeakAreaTarget {
        weak var view: AreaTargetView?

        init(_ view: AreaTargetView) {
            self.view = view
        }
    }
    private var areas: [WeakAreaTarget] = []

    func add(_ view: RowTargetView) {
        targets.removeAll { $0.view == nil || $0.view === view }
        targets.append(WeakTarget(view))
    }

    func remove(_ view: RowTargetView) {
        targets.removeAll { $0.view == nil || $0.view === view }
    }

    func target(for event: NSEvent) -> RowTargetView? {
        guard let window = event.window else { return nil }
        return target(at: event.locationInWindow, in: window)
    }

    func target(at point: NSPoint, in window: NSWindow) -> RowTargetView? {
        for wrapper in targets {
            guard let view = wrapper.view,
                  view.window === window,
                  !view.isHiddenOrHasHiddenAncestor,
                  let superview = view.superview else { continue }

            let frame = superview.convert(view.frame, to: nil)
            guard frame.width > 0, frame.height > 0 else { continue }
            if frame.contains(point) {
                return view
            }
        }
        return nil
    }

    func targets(in window: NSWindow) -> [RowTargetView] {
        targets.compactMap(\.view).filter {
            $0.window === window && !$0.isHiddenOrHasHiddenAncestor
        }
    }

    // MARK: - Aree di sfondo

    func addArea(_ view: AreaTargetView) {
        areas.removeAll { $0.view == nil || $0.view === view }
        areas.append(WeakAreaTarget(view))
    }

    func removeArea(_ view: AreaTargetView) {
        areas.removeAll { $0.view == nil || $0.view === view }
    }

    func areaTarget(at point: NSPoint, in window: NSWindow) -> AreaTargetView? {
        for wrapper in areas {
            guard let view = wrapper.view,
                  view.window === window,
                  !view.isHiddenOrHasHiddenAncestor,
                  let superview = view.superview else { continue }

            let frame = superview.convert(view.frame, to: nil)
            guard frame.width > 0, frame.height > 0 else { continue }
            if frame.contains(point) {
                return view
            }
        }
        return nil
    }

    func areaTargets(in window: NSWindow) -> [AreaTargetView] {
        areas.compactMap(\.view).filter {
            $0.window === window && !$0.isHiddenOrHasHiddenAncestor
        }
    }
}

/// Vista trasparente, non interattiva, usata solo per registrare il frame
/// della riga e inoltrare le azioni decise dal monitor.
final class RowTargetView: NSView, NSDraggingSource {
    var onSingle: ((NSEvent) -> Void)?
    var onDouble: ((NSEvent) -> Void)?
    var onMiddle: ((NSEvent) -> Void)?
    var contextMenu: ((NSEvent) -> NSMenu?)?
    var dragURLs: (() -> [URL])?
    var dragImage: (() -> NSImage?)?

    override var acceptsFirstResponder: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            ClickRegistry.shared.add(self)
        } else {
            ClickRegistry.shared.remove(self)
        }

        if ProcessInfo.processInfo.environment["COMMANDER_CLICK_DEBUG"] == "1" {
            let rect = superview.map { $0.convert(frame, to: nil) } ?? frame
            print("TARGET frame=\(frame) bounds=\(bounds) windowRect=\(rect)")
        }
    }

    deinit {
        if Thread.isMainThread {
            ClickRegistry.shared.remove(self)
        }
    }

    func performSingle(_ event: NSEvent) {
        onSingle?(event)
    }

    func performDouble(_ event: NSEvent) {
        onDouble?(event)
    }

    func performMiddle(_ event: NSEvent) {
        onMiddle?(event)
    }

    func showContextMenu(_ event: NSEvent) {
        guard let menu = contextMenu?(event) else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    func startDrag(with event: NSEvent, urls: [URL]) {
        guard !urls.isEmpty, window != nil else { return }

        var image = dragImage?()
        if let copy = image?.copy() as? NSImage {
            copy.size = NSSize(width: 32, height: 32)
            image = copy
        }

        let point = convert(event.locationInWindow, from: nil)
        var items: [NSDraggingItem] = []
        for (index, url) in urls.prefix(12).enumerated() {
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let offset = CGFloat(min(index, 6)) * 3
            item.setDraggingFrame(
                NSRect(
                    x: point.x - 16 + offset,
                    y: point.y - 16 - offset,
                    width: 32,
                    height: 32
                ),
                contents: image
            )
            items.append(item)
        }

        beginDraggingSession(with: items, event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        if context == .outsideApplication {
            return [.copy, .move]
        }
        return [.copy, .move, .link]
    }
}

/// Rappresentabile SwiftUI che collega la riga al registro.
struct RowTarget: NSViewRepresentable {
    var onSingle: (NSEvent) -> Void = { _ in }
    var onDouble: (NSEvent) -> Void = { _ in }
    var onMiddle: (NSEvent) -> Void = { _ in }
    var contextMenu: (NSEvent) -> NSMenu? = { _ in nil }
    var dragURLs: () -> [URL] = { [] }
    var dragImage: () -> NSImage? = { nil }

    func makeNSView(context: Context) -> RowTargetView {
        let view = RowTargetView()
        configure(view)
        return view
    }

    func updateNSView(_ view: RowTargetView, context: Context) {
        configure(view)
    }

    static func dismantleNSView(_ nsView: RowTargetView, coordinator: Void) {
        ClickRegistry.shared.remove(nsView)
    }

    private func configure(_ view: RowTargetView) {
        view.onSingle = onSingle
        view.onDouble = onDouble
        view.onMiddle = onMiddle
        view.contextMenu = contextMenu
        view.dragURLs = dragURLs
        view.dragImage = dragImage
    }
}

/// Area dello sfondo del pannello, usata per deselezionare con un click.
final class AreaTargetView: NSView {
    var onSingle: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            ClickRegistry.shared.addArea(self)
        } else {
            ClickRegistry.shared.removeArea(self)
        }

        if ProcessInfo.processInfo.environment["COMMANDER_CLICK_DEBUG"] == "1" {
            let rect = superview.map { $0.convert(frame, to: nil) } ?? frame
            print("AREA frame=\(frame) windowRect=\(rect)")
        }
    }

    deinit {
        if Thread.isMainThread {
            ClickRegistry.shared.removeArea(self)
        }
    }

    func performSingle(_ event: NSEvent) {
        onSingle?(event)
    }
}

struct AreaTarget: NSViewRepresentable {
    var onSingle: (NSEvent) -> Void = { _ in }

    func makeNSView(context: Context) -> AreaTargetView {
        let view = AreaTargetView()
        view.onSingle = onSingle
        return view
    }

    func updateNSView(_ view: AreaTargetView, context: Context) {
        view.onSingle = onSingle
    }

    static func dismantleNSView(_ nsView: AreaTargetView, coordinator: Void) {
        ClickRegistry.shared.removeArea(nsView)
    }
}
