import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let controller = AnnotationController.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        buildStatusItem()
        controller.start()
        registerHotKeys()
    }

    // MARK: Hotkeys (Control + Option + key)

    static let hotkeyHelp = """
    All hotkeys use ⌃⌥ (Control + Option):

    D  Toggle draw / click-through
    Space  Show / hide toolbar
    H  Show / hide annotations
    C  Clear all
    Z  Undo      Y  Redo
    P  Pen       M  Highlighter     E  Eraser
    L  Line      A  Arrow
    R  Rectangle O  Ellipse         T  Text
    W  Whiteboard   B  Blackboard
    S  Screenshot (region)
    G  Screenshot (full screen)

    While drawing: Esc = click-through, ⌘Z / ⇧⌘Z = undo / redo,
    hold ⇧ for straight lines, squares and circles.
    """

    private func registerHotKeys() {
        let mods = UInt32(controlKey | optionKey)
        let c = controller
        func reg(_ key: Int, _ action: @escaping () -> Void) {
            HotKeyCenter.shared.register(keyCode: key, modifiers: mods, handler: action)
        }
        reg(kVK_ANSI_D) { c.toggleDrawing() }
        reg(kVK_Space) { c.toggleToolbar() }
        reg(kVK_ANSI_H) { c.toggleAnnotationsVisible() }
        reg(kVK_ANSI_C) { c.clearAll() }
        reg(kVK_ANSI_Z) { c.undo() }
        reg(kVK_ANSI_Y) { c.redo() }
        reg(kVK_ANSI_P) { c.select(.pen) }
        reg(kVK_ANSI_M) { c.select(.highlighter) }
        reg(kVK_ANSI_E) { c.select(.eraser) }
        reg(kVK_ANSI_L) { c.select(.line) }
        reg(kVK_ANSI_A) { c.select(.arrow) }
        reg(kVK_ANSI_R) { c.select(.rectangle) }
        reg(kVK_ANSI_O) { c.select(.ellipse) }
        reg(kVK_ANSI_T) { c.select(.text) }
        reg(kVK_ANSI_W) { c.toggleBackdrop(.white) }
        reg(kVK_ANSI_B) { c.toggleBackdrop(.black) }
        reg(kVK_ANSI_S) { c.capture(region: true) }
        reg(kVK_ANSI_G) { c.capture(region: false) }
    }

    // MARK: Menus

    private func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit InkLayer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = main
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "pencil.circle", accessibilityDescription: "InkLayer")
            button.image = img
            if img == nil { button.title = "✎" }
        }
        let menu = NSMenu()
        func add(_ title: String, _ sel: Selector) {
            let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        add("Toggle Draw / Click-through", #selector(menuToggleDrawing))
        add("Show / Hide Toolbar", #selector(menuToggleToolbar))
        add("Show / Hide Annotations", #selector(menuToggleAnnotations))
        menu.addItem(.separator())
        add("Undo", #selector(menuUndo))
        add("Redo", #selector(menuRedo))
        add("Clear All", #selector(menuClear))
        menu.addItem(.separator())
        add("Screenshot Region", #selector(menuRegion))
        add("Screenshot Full Screen", #selector(menuScreen))
        menu.addItem(.separator())
        add("Hotkeys…", #selector(menuHotkeys))
        add("Quit InkLayer", #selector(menuQuit))
        statusItem.menu = menu
    }

    @objc private func menuToggleDrawing() { controller.toggleDrawing() }
    @objc private func menuToggleToolbar() { controller.toggleToolbar() }
    @objc private func menuToggleAnnotations() { controller.toggleAnnotationsVisible() }
    @objc private func menuUndo() { controller.undo() }
    @objc private func menuRedo() { controller.redo() }
    @objc private func menuClear() { controller.clearAll() }
    @objc private func menuRegion() { controller.capture(region: true) }
    @objc private func menuScreen() { controller.capture(region: false) }
    @objc private func menuQuit() { NSApp.terminate(nil) }
    @objc private func menuHotkeys() {
        let alert = NSAlert()
        alert.messageText = "InkLayer Hotkeys"
        alert.informativeText = AppDelegate.hotkeyHelp
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
