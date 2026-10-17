import AppKit

final class CanvasView: NSView, NSTextFieldDelegate {
    weak var controller: AnnotationController?

    var backdrop: Backdrop = .none {
        didSet { needsDisplay = true }
    }

    private(set) var annotations: [Annotation] = []
    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []
    private var current: Annotation?
    private var shapeStart: CGPoint = .zero
    private var eraseSnapshot: [Annotation]?

    private var textField: NSTextField?
    private var pendingTextSize: CGFloat = 24
    private var pendingTextColor: NSColor = .red

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        if let bg = backdrop.color {
            bg.setFill()
        } else {
            // Nearly invisible fill: fully transparent pixels let clicks fall through the window.
            NSColor.black.withAlphaComponent(0.01).setFill()
        }
        dirtyRect.fill()

        for a in annotations { render(a) }
        if let c = current { render(c) }
    }

    private func render(_ a: Annotation) {
        switch a.tool {
        case .text:
            guard let origin = a.points.first else { return }
            (a.text as NSString).draw(at: origin, withAttributes: Geometry.textAttributes(for: a))
        case .eraser:
            break
        default:
            let path = Geometry.path(for: a)
            path.lineWidth = a.drawWidth
            path.lineCapStyle = a.tool == .highlighter ? .square : .round
            path.lineJoinStyle = .round
            a.drawColor.setStroke()
            path.stroke()
        }
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        guard let c = controller else { return }
        commitText()
        let p = convert(event.locationInWindow, from: nil)
        c.canvasBecameActive(self)
        switch c.tool {
        case .text:
            beginText(at: p)
        case .eraser:
            eraseSnapshot = annotations
            erase(at: p)
        default:
            shapeStart = p
            current = Annotation(tool: c.tool, color: c.color, width: c.width, points: [p])
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if controller?.tool == .eraser {
            erase(at: p)
            return
        }
        guard var a = current else { return }
        switch a.tool {
        case .pen, .highlighter:
            if let last = a.points.last, hypot(p.x - last.x, p.y - last.y) < 1.0 { return }
            a.points.append(p)
        default:
            var end = p
            if event.modifierFlags.contains(.shift) {
                end = Geometry.constrain(tool: a.tool, start: shapeStart, end: p)
            }
            a.points = [shapeStart, end]
        }
        current = a
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        eraseSnapshot = nil
        guard let a = current else { return }
        current = nil
        switch a.tool {
        case .pen, .highlighter:
            commit(a)
        default:
            guard a.points.count == 2,
                  hypot(a.points[1].x - a.points[0].x, a.points[1].y - a.points[0].y) > 2 else {
                needsDisplay = true
                return
            }
            commit(a)
        }
    }

    private func commit(_ a: Annotation) {
        pushUndo(annotations)
        annotations.append(a)
        needsDisplay = true
    }

    private func pushUndo(_ snapshot: [Annotation]) {
        undoStack.append(snapshot)
        if undoStack.count > 200 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    // MARK: Eraser

    private func erase(at p: CGPoint) {
        let radius = max(8, (controller?.width ?? 4) * 1.5)
        let remaining = annotations.filter { !Geometry.hit($0, p, radius: radius) }
        guard remaining.count != annotations.count else { return }
        if let snap = eraseSnapshot {
            pushUndo(snap)
            eraseSnapshot = nil
        }
        annotations = remaining
        needsDisplay = true
    }

    // MARK: Text

    private func beginText(at p: CGPoint) {
        guard let c = controller else { return }
        let size = max(16, c.width * 4)
        pendingTextSize = size
        pendingTextColor = c.color
        let f = NSTextField(frame: NSRect(x: p.x, y: p.y - size * 0.7, width: 420, height: size * 1.4))
        f.font = NSFont.systemFont(ofSize: size, weight: .semibold)
        f.textColor = c.color
        f.isBordered = false
        f.drawsBackground = false
        f.focusRingType = .none
        f.placeholderString = "Type…"
        f.delegate = self
        f.target = self
        f.action = #selector(commitText)
        addSubview(f)
        window?.makeFirstResponder(f)
        textField = f
    }

    @objc func commitText() {
        guard let f = textField else { return }
        textField = nil
        let value = f.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let frame = f.frame
        f.removeFromSuperview()
        window?.makeFirstResponder(self)
        guard !value.isEmpty else { return }
        var a = Annotation(tool: .text, color: pendingTextColor, width: 1, points: [])
        a.text = value
        a.fontSize = pendingTextSize
        let lineHeight = ("Ag" as NSString).size(withAttributes: Geometry.textAttributes(for: a)).height
        a.points = [CGPoint(x: frame.minX + 2, y: frame.minY + (frame.height - lineHeight) / 2)]
        commit(a)
    }

    private func cancelText() {
        guard let f = textField else { return }
        textField = nil
        f.removeFromSuperview()
        window?.makeFirstResponder(self)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitText()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelText()
            return true
        }
        return false
    }

    // MARK: Keys & cursor

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            controller?.setDrawing(false)
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if textField == nil, flags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "z" {
            if flags.contains(.shift) { redo() } else { undo() }
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func resetCursorRects() {
        let cursor: NSCursor = controller?.tool == .text ? .iBeam : .crosshair
        addCursorRect(bounds, cursor: cursor)
    }

    func refreshCursor() {
        window?.invalidateCursorRects(for: self)
    }

    // MARK: History

    func undo() {
        cancelText()
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = prev
        needsDisplay = true
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
        needsDisplay = true
    }

    func clear() {
        cancelText()
        guard !annotations.isEmpty else { return }
        undoStack.append(annotations)
        redoStack.removeAll()
        annotations = []
        needsDisplay = true
    }
}
