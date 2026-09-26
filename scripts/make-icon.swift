import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
guard let cupArtwork = NSImage(contentsOfFile: "Sources/Dougie/Assets/lludix-cup.png") else {
    fatalError("Could not load cup artwork")
}
var iconChunks = Data()
let chunkTypes = [
    16: [1: "icp4", 2: "ic11"],
    32: [1: "icp5", 2: "ic12"],
    128: [1: "ic07", 2: "ic13"],
    256: [1: "ic08", 2: "ic14"],
    512: [1: "ic09", 2: "ic10"]
]

func bigEndianLength(_ length: Int) -> Data {
    withUnsafeBytes(of: UInt32(length).bigEndian) { Data($0) }
}

func drawSteam(at x: CGFloat, canvas: CGFloat) {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: x, y: canvas * 0.78))
    path.curve(to: CGPoint(x: x + canvas * 0.015, y: canvas * 0.91),
               controlPoint1: CGPoint(x: x - canvas * 0.035, y: canvas * 0.83),
               controlPoint2: CGPoint(x: x + canvas * 0.055, y: canvas * 0.87))
    path.lineWidth = max(1, canvas * 0.009)
    path.lineCapStyle = .round
    NSColor(calibratedWhite: 0.96, alpha: 0.53).setStroke()
    path.stroke()
}

func drawSmallCup(canvas: CGFloat) {
    let cream = NSColor(calibratedRed: 0.95, green: 0.92, blue: 0.83, alpha: 1)
    cream.setStroke()
    let handle = NSBezierPath(ovalIn: CGRect(x: canvas * 0.60, y: canvas * 0.39,
                                             width: canvas * 0.19, height: canvas * 0.26))
    handle.lineWidth = canvas * 0.052
    handle.stroke()

    cream.setFill()
    NSBezierPath(roundedRect: CGRect(x: canvas * 0.25, y: canvas * 0.36,
                                      width: canvas * 0.42, height: canvas * 0.32),
                 xRadius: canvas * 0.055, yRadius: canvas * 0.055).fill()
    NSBezierPath(ovalIn: CGRect(x: canvas * 0.18, y: canvas * 0.27,
                                width: canvas * 0.58, height: canvas * 0.09)).fill()
    NSColor(calibratedRed: 0.30, green: 0.16, blue: 0.09, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: canvas * 0.27, y: canvas * 0.62,
                                width: canvas * 0.38, height: canvas * 0.075)).fill()
    drawSteam(at: canvas * 0.43, canvas: canvas)
    drawSteam(at: canvas * 0.54, canvas: canvas)
}

func drawLargeCup(canvas: CGFloat) {
    for x in [0.42, 0.50, 0.58] {
        drawSteam(at: canvas * x, canvas: canvas)
    }
    let imageRect = CGRect(x: canvas * 0.065, y: canvas * 0.08,
                           width: canvas * 0.87, height: canvas * 0.87)
    cupArtwork.draw(in: imageRect)

    // Match the mouth coordinates used by CoffeeCupView, translated from its
    // top-origin artwork space into AppKit's bottom-origin drawing space.
    let scale = imageRect.width / 1254
    let coffeeRect = CGRect(x: imageRect.minX + 291 * scale,
                            y: imageRect.minY + 730 * scale,
                            width: 661 * scale, height: 285 * scale)
    let surface = NSBezierPath(ovalIn: coffeeRect)
    NSGradient(starting: NSColor(calibratedRed: 0.27, green: 0.14, blue: 0.08, alpha: 1),
               ending: NSColor(calibratedRed: 0.08, green: 0.04, blue: 0.025, alpha: 1))?
        .draw(in: surface, angle: -65)
    surface.lineWidth = max(1, canvas * 0.003)
    NSColor(calibratedRed: 0.68, green: 0.40, blue: 0.20, alpha: 0.8).setStroke()
    surface.stroke()
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            fatalError("Could not create icon canvas")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        let canvas = CGFloat(pixels)
        let bounds = NSRect(x: canvas * 0.06, y: canvas * 0.06, width: canvas * 0.88, height: canvas * 0.88)
        let background = NSBezierPath(roundedRect: bounds, xRadius: canvas * 0.20, yRadius: canvas * 0.20)
        NSGradient(starting: NSColor(calibratedRed: 0.19, green: 0.37, blue: 0.30, alpha: 1),
                   ending: NSColor(calibratedRed: 0.07, green: 0.17, blue: 0.14, alpha: 1))?
            .draw(in: background, angle: -55)
        if pixels <= 64 {
            drawSmallCup(canvas: canvas)
        } else {
            drawLargeCup(canvas: canvas)
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Could not render app icon")
        }
        let suffix = scale == 2 ? "@2x" : ""
        try png.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
        iconChunks.append(Data(chunkTypes[size]![scale]!.utf8))
        iconChunks.append(bigEndianLength(png.count + 8))
        iconChunks.append(png)
    }
}

var icns = Data("icns".utf8)
icns.append(bigEndianLength(iconChunks.count + 8))
icns.append(iconChunks)
try icns.write(to: output.deletingLastPathComponent().appendingPathComponent("AppIcon.icns"))
