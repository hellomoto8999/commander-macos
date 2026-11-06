import AppKit

/// Monitor dei tasti a livello di applicazione, con rispetto dei campi di testo.
final class KeyMonitor {
    static let shared = KeyMonitor()

    private var monitor: Any?
    var handler: ((NSEvent) -> Bool)?

    private init() {}

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let handler = self.handler else { return event }
            if RunLoop.current.currentMode == .eventTracking { return event }
            if KeyMonitor.isEditingText { return event }
            if let window = NSApp.keyWindow, window.attachedSheet != nil { return event }
            return handler(event) ? nil : event
        }
    }

    static var isEditingText: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        if responder is NSTextView { return true }
        if let view = responder as? NSView, view.isKind(of: NSTextField.self) { return true }
        return false
    }
}
