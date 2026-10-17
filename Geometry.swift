import AppKit

enum Geometry {
    static func rect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    /// Constrains the end point when Shift is held (45° snapping for lines, squares/circles for shapes).
    static func constrain(tool: Tool, start: CGPoint, end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        switch tool {
        case .line, .arrow:
            let len = hypot(dx, dy)
            guard len > 0 else { return end }
            let angle = atan2(dy, dx)
            let step = CGFloat.pi / 4
            let snapped = (angle / step).rounded() * step
            return CGPoint(x: start.x + cos(snapped) * len, y: start.y + sin(snapped) * len)
        case .rectangle, .ellipse:
            let m = max(abs(dx), abs(dy))
            return CGPoint(x: start.x + (dx < 0 ? -m : m), y: start.y + (dy < 0 ? -m : m))
        default:
            return end
        }
    }

    static func smoothPath(_ pts: [CGPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = pts.first else { return path }
        path.move(to: first)
        if pts.count == 1 {
            path.line(to: CGPoint(x: first.x + 0.01, y: first.y))
            return path
        }
        if pts.count == 2 {
            path.line(to: pts[1])
            return path
        }
        var cur = first
        for i in 1..<(pts.count - 1) {
            let ctrl = pts[i]
            let end = CGPoint(x: (pts[i].x + pts[i + 1].x) / 2, y: (pts[i].y + pts[i + 1].y) / 2)
            let c1 = CGPoint(x: cur.x + 2.0 / 3.0 * (ctrl.x - cur.x), y: cur.y + 2.0 / 3.0 * (ctrl.y - cur.y))
            let c2 = CGPoint(x: end.x + 2.0 / 3.0 * (ctrl.x - end.x), y: end.y + 2.0 / 3.0 * (ctrl.y - end.y))
            path.curve(to: end, controlPoint1: c1, controlPoint2: c2)
            cur = end
        }
        path.line(to: pts[pts.count - 1])
        return path
    }

    static func arrowPath(from a: CGPoint, to b: CGPoint, width: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: a)
        path.line(to: b)
        let angle = atan2(b.y - a.y, b.x - a.x)
        let head = max(14, width * 4.5)
        let spread = CGFloat.pi * 28 / 180
        for sign in [-1.0, 1.0] as [CGFloat] {
            let theta = angle + CGFloat.pi + sign * spread
            path.move(to: b)
            path.line(to: CGPoint(x: b.x + cos(theta) * head, y: b.y + sin(theta) * head))
        }
        return path
    }

    static func path(for a: Annotation) -> NSBezierPath {
        switch a.tool {
        case .pen, .highlighter:
            return smoothPath(a.points)
        case .line:
            let p = NSBezierPath()
            guard a.points.count >= 2 else { return p }
            p.move(to: a.points[0])
            p.line(to: a.points[1])
            return p
        case .arrow:
            guard a.points.count >= 2 else { return NSBezierPath() }
            return arrowPath(from: a.points[0], to: a.points[1], width: a.width)
        case .rectangle:
            guard a.points.count >= 2 else { return NSBezierPath() }
            return NSBezierPath(rect: rect(a.points[0], a.points[1]))
        case .ellipse:
            guard a.points.count >= 2 else { return NSBezierPath() }
            return NSBezierPath(ovalIn: rect(a.points[0], a.points[1]))
        default:
            return NSBezierPath()
        }
    }

    static func polyline(for a: Annotation) -> [CGPoint] {
        switch a.tool {
        case .pen, .highlighter, .line, .arrow:
            return a.points
        case .rectangle:
            guard a.points.count >= 2 else { return a.points }
            let r = rect(a.points[0], a.points[1])
            return [
                CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY),
                CGPoint(x: r.minX, y: r.minY)
            ]
        case .ellipse:
            guard a.points.count >= 2 else { return a.points }
            let r = rect(a.points[0], a.points[1])
            let rx = r.width / 2, ry = r.height / 2
            return (0...48).map { i in
                let t = CGFloat(i) / 48 * 2 * CGFloat.pi
                return CGPoint(x: r.midX + rx * cos(t), y: r.midY + ry * sin(t))
            }
        default:
            return []
        }
    }

    static func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        if len2 == 0 { return hypot(p.x - a.x, p.y - a.y) }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2
        t = max(0, min(1, t))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }

    static func textAttributes(for a: Annotation) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: a.fontSize, weight: .semibold),
            .foregroundColor: a.color
        ]
    }

    static func textBounds(_ a: Annotation) -> CGRect {
        guard let origin = a.points.first else { return .zero }
        let size = (a.text as NSString).size(withAttributes: textAttributes(for: a))
        return CGRect(origin: origin, size: size)
    }

    static func hit(_ a: Annotation, _ p: CGPoint, radius: CGFloat) -> Bool {
        if a.tool == .text {
            return textBounds(a).insetBy(dx: -radius, dy: -radius).contains(p)
        }
        let pts = polyline(for: a)
        let reach = radius + a.drawWidth / 2
        if pts.count == 1 {
            return hypot(p.x - pts[0].x, p.y - pts[0].y) <= reach
        }
        guard pts.count >= 2 else { return false }
        for i in 0..<(pts.count - 1) where distance(p, pts[i], pts[i + 1]) <= reach {
            return true
        }
        return false
    }
}
