import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
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
        let canvas = CGFloat(pixels)
        let bounds = NSRect(x: canvas * 0.06, y: canvas * 0.06, width: canvas * 0.88, height: canvas * 0.88)
        NSColor(calibratedRed: 0.15, green: 0.35, blue: 0.31, alpha: 1).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: canvas * 0.2, yRadius: canvas * 0.2).fill()
        let config = NSImage.SymbolConfiguration(pointSize: canvas * 0.51, weight: .medium)
        if let cup = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)?
            .withSymbolConfiguration(.init(paletteColors: [.white])) {
            let fit = min(canvas * 0.62 / cup.size.width, canvas * 0.62 / cup.size.height)
            let width = cup.size.width * fit
            let height = cup.size.height * fit
            cup.draw(in: NSRect(x: (canvas - width) / 2, y: (canvas - height) / 2, width: width, height: height))
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
