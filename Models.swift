import AppKit

enum Tool: Int, CaseIterable {
    case pen, highlighter, eraser, line, arrow, rectangle, ellipse, text

    var symbol: String {
        switch self {
        case .pen: return "pencil"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .text: return "textformat"
        }
    }

    var title: String {
        switch self {
        case .pen: return "Pen"
        case .highlighter: return "Highlighter"
        case .eraser: return "Eraser"
        case .line: return "Line (hold ⇧ to snap)"
        case .arrow: return "Arrow (hold ⇧ to snap)"
        case .rectangle: return "Rectangle (hold ⇧ for square)"
        case .ellipse: return "Ellipse (hold ⇧ for circle)"
        case .text: return "Text"
        }
    }
}

enum Backdrop: Int {
    case none, white, black

    var color: NSColor? {
        switch self {
        case .none: return nil
        case .white: return NSColor.white
        case .black: return NSColor(calibratedWhite: 0.08, alpha: 1)
        }
    }
}

struct Annotation {
    var tool: Tool
    var color: NSColor
    var width: CGFloat
    var points: [CGPoint]
    var text: String = ""
    var fontSize: CGFloat = 24

    var drawWidth: CGFloat { tool == .highlighter ? width * 2.5 : width }
    var drawColor: NSColor { tool == .highlighter ? color.withAlphaComponent(0.4) : color }
}

enum Palette {
    static let colors: [NSColor] = [
        NSColor(srgbRed: 0.93, green: 0.20, blue: 0.20, alpha: 1),
        NSColor(srgbRed: 1.00, green: 0.58, blue: 0.10, alpha: 1),
        NSColor(srgbRed: 1.00, green: 0.85, blue: 0.10, alpha: 1),
        NSColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 1),
        NSColor(srgbRed: 0.20, green: 0.50, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 0.65, green: 0.40, blue: 0.95, alpha: 1),
        NSColor.white,
        NSColor.black
    ]
}
