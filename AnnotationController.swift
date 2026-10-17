import AppKit

final class OverlayWindow: NSWindow {
    let canvas: CanvasView

    init(screen: NSScreen, controller: AnnotationController) {
        canvas = CanvasView(frame: NSRect(origin: .zero, size: screen.frame.size))
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        canvas.controller = controller
        canvas.autoresizingMask = [.width, .height]
        contentView = canvas
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        setFrame(screen.frame, display: true)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class AnnotationController {
    static let shared = AnnotationController()

    var tool: Tool = .pen {
        didSet { windows.forEach { $0.canvas.refreshCursor() } }
    }
    var color: NSColor = Palette.colors[0]
    var width: CGFloat = 4
    var drawing = true
    var backdrop: Backdrop = .none
    var annotationsVisible = true

    private var windows: [OverlayWindow] = []
    private(set) var toolbar: ToolbarPanel?
    private weak var activeCanvas: CanvasView?
    var onChange: (() -> Void)?

    // MARK: Lifecycle

    func start() {
        rebuildWindows()
        let tb = ToolbarPanel(controller: self)
        toolbar = tb
        tb.orderFrontRegardless()
        onChange = { [weak tb] in tb?.refresh() }
        applyMode()
        onChange?()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.rebuildWindows()
            self?.applyMode()
        }
    }

    private func rebuildWindows() {
        let frames = NSScreen.screens.map { $0.frame }
        if frames == windows.map({ $0.frame }) { return }
        windows.forEach { $0.orderOut(nil); $0.close() }
        windows = NSScreen.screens.map { OverlayWindow(screen: $0, controller: self) }
        for w in windows {
            w.canvas.backdrop = backdrop
            if annotationsVisible { w.orderFrontRegardless() }
        }
        activeCanvas = windows.first?.canvas
    }

    func canvasBecameActive(_ canvas: CanvasView) {
        activeCanvas = canvas
    }

    // MARK: Modes & tools

    func select(_ newTool: Tool) {
        tool = newTool
        if !drawing { drawing = true; applyMode() }
        onChange?()
    }

    func setColor(_ c: NSColor) {
        color = c
        if tool == .eraser { tool = .pen }
        onChange?()
    }

    func setWidth(_ w: CGFloat) {
        width = w
        onChange?()
    }

    func setDrawing(_ on: Bool) {
        drawing = on
        applyMode()
        onChange?()
    }

    func toggleDrawing() { setDrawing(!drawing) }

    func applyMode() {
        for w in windows { w.ignoresMouseEvents = !drawing }
        guard drawing, annotationsVisible else { return }
        NSApp.activate(ignoringOtherApps: true)
        let mouse = NSEvent.mouseLocation
        let target = windows.first(where: { $0.frame.contains(mouse) }) ?? windows.first
        target?.makeKeyAndOrderFront(nil)
        if let t = target { t.makeFirstResponder(t.canvas) }
    }

    func toggleBackdrop(_ b: Backdrop) {
        backdrop = (backdrop == b) ? .none : b
        windows.forEach { $0.canvas.backdrop = backdrop }
        if backdrop != .none && !drawing { setDrawing(true) }
        onChange?()
    }

    func toggleAnnotationsVisible() {
        annotationsVisible.toggle()
        for w in windows {
            if annotationsVisible { w.orderFrontRegardless() } else { w.orderOut(nil) }
        }
        if annotationsVisible { applyMode() }
        onChange?()
    }

    func toggleToolbar() {
        guard let tb = toolbar else { return }
        if tb.isVisible { tb.orderOut(nil) } else { tb.orderFrontRegardless() }
    }

    // MARK: History

    func undo() { (activeCanvas ?? windows.first?.canvas)?.undo() }
    func redo() { (activeCanvas ?? windows.first?.canvas)?.redo() }
    func clearAll() { windows.forEach { $0.canvas.clear() } }

    // MARK: Screenshots

    func capture(region: Bool) {
        let toolbarWasVisible = toolbar?.isVisible ?? false
        toolbar?.orderOut(nil)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        let url = desktop.appendingPathComponent("InkLayer \(df.string(from: Date())).png")

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.25) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = (region ? ["-i", "-x"] : ["-x"]) + [url.path]
            try? p.run()
            p.waitUntilExit()
            DispatchQueue.main.async { [weak self] in
                if toolbarWasVisible { self?.toolbar?.orderFrontRegardless() }
                if let img = NSImage(contentsOf: url) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([img])
                    NSSound(named: "Pop")?.play()
                }
            }
        }
    }
}
