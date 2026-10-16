// Draws the DMG window background: an arrow from the app icon to Applications and an install hint.
// Usage: swift scripts/dmg-background.swift <output.png> <scale>
// Layout must match the icon positions in scripts/make-dmg.sh (window 640×400, icons at x 170 and 470, y 180).
import AppKit

let args = CommandLine.arguments
let output = URL(fileURLWithPath: args[1])
let scale = CGFloat(Double(args[2]) ?? 1)
let size = CGSize(width: 640, height: 400)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = size  // draw in points; the rep holds `scale` pixels per point

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Background: soft vertical gradient.
NSGradient(starting: NSColor(white: 0.97, alpha: 1), ending: NSColor(white: 0.90, alpha: 1))!
    .draw(in: NSRect(origin: .zero, size: size), angle: -90)

// Arrow between the icons (Finder's y 180 from the top is 220 from the bottom).
let arrowColor = NSColor(white: 0.55, alpha: 1)
let y: CGFloat = 220
let shaft = NSBezierPath()
shaft.move(to: NSPoint(x: 262, y: y))
shaft.line(to: NSPoint(x: 366, y: y))
shaft.lineWidth = 6
shaft.lineCapStyle = .round
arrowColor.setStroke()
shaft.stroke()
let head = NSBezierPath()
head.move(to: NSPoint(x: 384, y: y))
head.line(to: NSPoint(x: 360, y: y + 16))
head.line(to: NSPoint(x: 360, y: y - 16))
head.close()
arrowColor.setFill()
head.fill()

// Hint under the icons.
let hint = "Drag Audra to Applications to install" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .medium),
    .foregroundColor: NSColor(white: 0.40, alpha: 1),
]
let hintSize = hint.size(withAttributes: attributes)
hint.draw(at: NSPoint(x: (size.width - hintSize.width) / 2, y: 70), withAttributes: attributes)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: output)
