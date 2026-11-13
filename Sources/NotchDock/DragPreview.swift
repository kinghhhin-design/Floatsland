import AppKit

/// Drag image coordinates are relative to the source view, not the row's icon.
enum DragPreview {
    static func frame(at pointer: NSPoint, size: NSSize, index: Int, flipped: Bool) -> NSRect {
        let offset = CGFloat(index % 6) * 4
        return NSRect(x: pointer.x + 10 + offset,
                      y: flipped ? pointer.y + 10 + offset : pointer.y - 10 - size.height - offset,
                      width: size.width, height: size.height)
    }

    static func textImage() -> NSImage {
        let size = NSSize(width: 36, height: 36)
        return NSImage(size: size, flipped: false) { rect in
            // Opaque neutral backing gives consistent contrast on any destination.
            let outer = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
            NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
            outer.fill()
            let card = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 7, yRadius: 7)
            NSColor(calibratedWhite: 0.76, alpha: 1).setFill()
            card.fill()
            NSColor(calibratedWhite: 0.22, alpha: 1).setStroke()
            card.lineWidth = 1
            card.stroke()
            NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
            for (y, width) in [(23.0, 18.0), (17.0, 18.0), (11.0, 12.0)] {
                NSBezierPath(roundedRect: NSRect(x: 9, y: y, width: width, height: 2.5),
                             xRadius: 1.25, yRadius: 1.25).fill()
            }
            return true
        }
    }
}
