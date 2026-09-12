// Generates AppIcon.icns for IGDL.app: a macOS squircle filled with Instagram's
// signature gradient (yellow -> orange -> magenta -> purple -> blue), with a
// white download-arrow glyph — Instagram's palette, not its camera logo.
import AppKit

let canvas = 1024.0
let rect = CGRect(x: 0, y: 0, width: canvas, height: canvas)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: Int(canvas), height: Int(canvas),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("could not create context")
}

// macOS "squircle" mask (~22% corner radius, matching Big Sur+ icon shape).
let cornerRadius = canvas * 0.223
let squirclePath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
ctx.addPath(squirclePath)
ctx.clip()

// Instagram's gradient stops, bottom-left to top-right.
let colors = [
    NSColor(red: 0.996, green: 0.855, blue: 0.459, alpha: 1).cgColor, // #FEDA75
    NSColor(red: 0.980, green: 0.494, blue: 0.118, alpha: 1).cgColor, // #FA7E1E
    NSColor(red: 0.839, green: 0.161, blue: 0.463, alpha: 1).cgColor, // #D62976
    NSColor(red: 0.588, green: 0.184, blue: 0.749, alpha: 1).cgColor, // #962FBF
    NSColor(red: 0.310, green: 0.357, blue: 0.835, alpha: 1).cgColor, // #4F5BD5
]
guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 0.28, 0.5, 0.72, 1]) else {
    fatalError("could not create gradient")
}
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: canvas, y: canvas),
    options: []
)

// White "download" arrow glyph: a vertical stem, a solid triangular arrowhead
// pointing down, and a baseline — like SF Symbols' arrow.down.to.line.
// Note: CGContext's own coordinate space has y=0 at the BOTTOM, increasing
// upward, so "down" on screen means smaller y here.
ctx.setFillColor(NSColor.white.cgColor)
let cx = canvas / 2

let stemWidth = canvas * 0.09
let stemTopY = canvas * 0.70
let stemBottomY = canvas * 0.50
let stemRect = CGRect(x: cx - stemWidth / 2, y: stemBottomY, width: stemWidth, height: stemTopY - stemBottomY)
let stemPath = CGPath(roundedRect: stemRect, cornerWidth: stemWidth / 2, cornerHeight: stemWidth / 2, transform: nil)
ctx.addPath(stemPath)
ctx.fillPath()

let arrowHead = CGMutablePath()
let shoulderHalfWidth = canvas * 0.16
let shoulderY = canvas * 0.50
let tipY = canvas * 0.335
arrowHead.move(to: CGPoint(x: cx - shoulderHalfWidth, y: shoulderY))
arrowHead.addLine(to: CGPoint(x: cx + shoulderHalfWidth, y: shoulderY))
arrowHead.addLine(to: CGPoint(x: cx, y: tipY))
arrowHead.closeSubpath()
ctx.addPath(arrowHead)
ctx.fillPath()

// Baseline under the arrow.
let baseWidth = canvas * 0.46
let baseHeight = canvas * 0.075
let baseY = canvas * 0.235
let baseRect = CGRect(x: cx - baseWidth / 2, y: baseY, width: baseWidth, height: baseHeight)
let basePath = CGPath(roundedRect: baseRect, cornerWidth: baseHeight / 2, cornerHeight: baseHeight / 2, transform: nil)
ctx.addPath(basePath)
ctx.fillPath()

guard let image = ctx.makeImage() else { fatalError("could not render image") }

let rep = NSBitmapImageRep(cgImage: image)
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not encode PNG")
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath)")
