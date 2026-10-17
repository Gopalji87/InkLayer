import AppKit

final class ToolbarPanel: NSPanel {
    private let controller: AnnotationController
    private var toolButtons: [Tool: NSButton] = [:]
    private var swatches: [NSButton] = []
    private var selectedSwatch: Int? = 0
    private var pointerButton: NSButton!
    private var whiteButton: NSButton!
    private var blackButton: NSButton!
    private var hideButton: NSButton!
    private var slider: NSSlider!

    init(controller: AnnotationController) {
        self.controller = controller
        super.init(contentRect: NSRect(x: 0, y: 0, width: 600, height: 52),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        buildUI()
        refresh()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: Build

    private func buildUI() {
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false

        pointerButton = button(symbol: "cursorarrow", tip: "Cursor mode — click through to apps (Esc)", action: #selector(pointerPressed))
        stack.addArrangedSubview(pointerButton)
        stack.addArrangedSubview(separator())

        for tool in [Tool.pen, .highlighter, .eraser, .line, .arrow, .rectangle, .ellipse, .text] {
            let b = button(symbol: tool.symbol, tip: tool.title, action: #selector(toolPressed(_:)))
            b.tag = tool.rawValue
            toolButtons[tool] = b
            stack.addArrangedSubview(b)
            if tool == .eraser { stack.addArrangedSubview(separator()) }
        }
        stack.addArrangedSubview(separator())

        for (i, _) in Palette.colors.enumerated() {
            let b = NSButton(image: NSImage(), target: self, action: #selector(swatchPressed(_:)))
            b.isBordered = false
            b.tag = i
            b.translatesAutoresizingMaskIntoConstraints = false
            b.widthAnchor.constraint(equalToConstant: 24).isActive = true
            b.heightAnchor.constraint(equalToConstant: 24).isActive = true
            swatches.append(b)
            stack.addArrangedSubview(b)
        }
        stack.addArrangedSubview(button(symbol: "paintpalette", tip: "More colors…", action: #selector(morePressed)))

        slider = NSSlider(value: Double(controller.width), minValue: 1, maxValue: 40,
                          target: self, action: #selector(sliderChanged(_:)))
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 90).isActive = true
        slider.toolTip = "Pen size"
        stack.addArrangedSubview(slider)
        stack.addArrangedSubview(separator())

        stack.addArrangedSubview(button(symbol: "arrow.uturn.backward", tip: "Undo (⌘Z)", action: #selector(undoPressed)))
        stack.addArrangedSubview(button(symbol: "arrow.uturn.forward", tip: "Redo (⇧⌘Z)", action: #selector(redoPressed)))
        stack.addArrangedSubview(button(symbol: "trash", tip: "Clear all", action: #selector(clearPressed)))
        stack.addArrangedSubview(separator())

        whiteButton = button(symbol: "square", tip: "Whiteboard", action: #selector(whitePressed))
        blackButton = button(symbol: "square.fill", tip: "Blackboard", action: #selector(blackPressed))
        stack.addArrangedSubview(whiteButton)
        stack.addArrangedSubview(blackButton)
        stack.addArrangedSubview(button(symbol: "camera.viewfinder", tip: "Screenshot a region (copies + saves to Desktop)", action: #selector(regionPressed)))
        stack.addArrangedSubview(button(symbol: "camera", tip: "Screenshot the whole screen", action: #selector(screenPressed)))
        hideButton = button(symbol: "eye.slash", tip: "Hide / show annotations", action: #selector(hidePressed))
        stack.addArrangedSubview(hideButton)
        stack.addArrangedSubview(button(symbol: "power", tip: "Quit InkLayer", action: #selector(quitPressed)))

        effect.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            stack.topAnchor.constraint(equalTo: effect.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor)
        ])
        contentView = effect

        effect.layoutSubtreeIfNeeded()
        let size = stack.fittingSize
        setContentSize(size)
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            setFrameOrigin(NSPoint(x: vf.midX - size.width / 2, y: vf.minY + 24))
        }
    }

    private func button(symbol: String, tip: String, action: Selector) -> NSButton {
        let base = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
        let img = base?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)) ?? base ?? NSImage()
        let b = NSButton(image: img, target: self, action: action)
        b.isBordered = false
        b.toolTip = tip
        b.imageScaling = .scaleProportionallyDown
        b.contentTintColor = .labelColor
        b.wantsLayer = true
        b.layer?.cornerRadius = 7
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 32).isActive = true
        b.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return b
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 1).isActive = true
        box.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return box
    }

    private func swatchImage(_ color: NSColor, selected: Bool) -> NSImage {
        NSImage(size: NSSize(width: 24, height: 24), flipped: false) { r in
            let circle = NSBezierPath(ovalIn: r.insetBy(dx: 5, dy: 5))
            color.setFill()
            circle.fill()
            NSColor.black.withAlphaComponent(0.35).setStroke()
            circle.lineWidth = 1
            circle.stroke()
            if selected {
                let ring = NSBezierPath(ovalIn: r.insetBy(dx: 1.5, dy: 1.5))
                NSColor.labelColor.setStroke()
                ring.lineWidth = 2
                ring.stroke()
            }
            return true
        }
    }

    private func setHighlight(_ b: NSButton?, _ on: Bool) {
        b?.layer?.backgroundColor = on
            ? NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor
            : NSColor.clear.cgColor
    }

    // MARK: Refresh

    func refresh() {
        for (tool, b) in toolButtons {
            setHighlight(b, controller.drawing && controller.tool == tool)
        }
        setHighlight(pointerButton, !controller.drawing)
        setHighlight(whiteButton, controller.backdrop == .white)
        setHighlight(blackButton, controller.backdrop == .black)
        setHighlight(hideButton, !controller.annotationsVisible)
        for (i, b) in swatches.enumerated() {
            b.image = swatchImage(Palette.colors[i], selected: selectedSwatch == i)
        }
        slider.doubleValue = Double(controller.width)
    }

    // MARK: Actions

    @objc private func pointerPressed() { controller.toggleDrawing() }
    @objc private func toolPressed(_ s: NSButton) {
        if let t = Tool(rawValue: s.tag) { controller.select(t) }
    }
    @objc private func swatchPressed(_ s: NSButton) {
        selectedSwatch = s.tag
        controller.setColor(Palette.colors[s.tag])
    }
    @objc private func morePressed() {
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorPicked(_:)))
        panel.orderFront(nil)
    }
    @objc private func colorPicked(_ s: NSColorPanel) {
        selectedSwatch = nil
        controller.setColor(s.color)
    }
    @objc private func sliderChanged(_ s: NSSlider) { controller.setWidth(CGFloat(s.doubleValue)) }
    @objc private func undoPressed() { controller.undo() }
    @objc private func redoPressed() { controller.redo() }
    @objc private func clearPressed() { controller.clearAll() }
    @objc private func whitePressed() { controller.toggleBackdrop(.white) }
    @objc private func blackPressed() { controller.toggleBackdrop(.black) }
    @objc private func regionPressed() { controller.capture(region: true) }
    @objc private func screenPressed() { controller.capture(region: false) }
    @objc private func hidePressed() { controller.toggleAnnotationsVisible() }
    @objc private func quitPressed() { NSApp.terminate(nil) }
}
