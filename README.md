# InkLayer

A screen-annotation app for macOS (draw on top of anything, presentations, videos, websites) in the spirit of Epic Pen. Native Swift/AppKit, lives in the menu bar.

## Build & run

Requires macOS 12+ and Xcode or the Xcode Command Line Tools (`xcode-select --install`).

```bash
chmod +x build_app.sh
./build_app.sh
open build/InkLayer.app
```

If macOS blocks the first launch: right-click the app → Open.

## Permissions

- **Screen Recording** (System Settings → Privacy & Security): required for the screenshot buttons, otherwise captures show only the wallpaper.
- Hotkeys use Carbon `RegisterEventHotKey`, so no Accessibility permission is needed.

## Features

| Feature | How |
|---|---|
| Draw over any screen / app / full-screen Space, on every display | Overlay windows, one per screen |
| Pen, highlighter, eraser (stroke eraser) | Toolbar or hotkeys |
| Line, arrow, rectangle, ellipse | Hold ⇧ for 45° lines, squares, circles |
| Text | Click, type, Enter to place, Esc to cancel |
| Colors + custom color picker, size slider | Toolbar |
| Undo / redo / clear | Toolbar, ⌘Z / ⇧⌘Z, hotkeys |
| Cursor mode (click through, ink stays visible) | Cursor button, Esc, or ⌃⌥D |
| Whiteboard / blackboard backgrounds | Toolbar or hotkeys |
| Hide / show annotations, hide toolbar | Toolbar eye button, ⌃⌥H, ⌃⌥Space |
| Screenshots (region or full screen) → clipboard + Desktop | Camera buttons, ⌃⌥S / ⌃⌥G |
| Draggable floating toolbar, menu-bar icon | — |

## Global hotkeys (⌃⌥ + key)

D draw/click-through · Space toolbar · H hide ink · C clear · Z undo · Y redo
P pen · M highlighter · E eraser · L line · A arrow · R rectangle · O ellipse · T text
W whiteboard · B blackboard · S region screenshot · G full-screen screenshot

Edit the table in `Sources/InkLayer/AppDelegate.swift` (`registerHotKeys`) to change them.

## Layout

```
Sources/InkLayer/
  main.swift                 entry point (accessory / menu-bar app)
  AppDelegate.swift          menu bar item, menus, hotkey table
  AnnotationController.swift overlay windows, modes, history, screenshots
  CanvasView.swift           drawing, eraser, text, undo stack
  Geometry.swift             smoothing, arrows, hit-testing
  ToolbarPanel.swift         floating toolbar
  HotKeys.swift              global hotkey registration
  Models.swift               tools, annotations, palette
```

## Not included

Epic Pen's paid extras (e.g. saved sessions, PDF/image import) are not implemented.
