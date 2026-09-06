#!/usr/bin/swift
import AppKit
import CoreGraphics

// Renders a Liquid-Glass-style app icon: a rounded-squircle base with a
// vibrant gradient, a soft frosted-glass highlight layer, and a pencil
// glyph -- approximating macOS 26's Liquid Glass material (a true Icon
// Composer .icon asset isn't scriptable from the command line, so this is
// a static-PNG visual approximation of the same look).

let size = 1024.0
let rect = CGRect(x: 0, y: 0, width: size, height: size)

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

// macOS squircle mask (superellipse-ish rounded rect, ~22% corner radius).
let cornerRadius = size * 0.225
let squircle = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
ctx.addPath(squircle)
ctx.clip()

// Base vibrant gradient (blue -> violet), typical of macOS 26 system app icons.
let colors = [
    NSColor(calibratedRed: 0.20, green: 0.47, blue: 0.98, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.46, green: 0.29, blue: 0.95, alpha: 1.0).cgColor
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: size, y: 0),
    options: []
)

// Frosted-glass highlight: a large soft white ellipse across the top half,
// blurred, at low opacity -- the signature Liquid Glass "sheen".
let glassLayer = NSImage(size: NSSize(width: size, height: size))
glassLayer.lockFocus()
if let glassCtx = NSGraphicsContext.current?.cgContext {
    glassCtx.setFillColor(NSColor.white.withAlphaComponent(0.55).cgColor)
    let ellipse = CGRect(x: size * 0.05, y: size * 0.50, width: size * 0.90, height: size * 0.55)
    glassCtx.fillEllipse(in: ellipse)
}
glassLayer.unlockFocus()

if let tiff = glassLayer.tiffRepresentation, let ciImage = CIImage(data: tiff) {
    let blurred = ciImage.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: size * 0.05])
    let ciContext = CIContext()
    if let cgBlurred = ciContext.createCGImage(blurred, from: ciImage.extent) {
        ctx.saveGState()
        ctx.setAlpha(0.5)
        ctx.draw(cgBlurred, in: rect)
        ctx.restoreGState()
    }
}

// Subtle inner top-edge highlight stroke for a glassy rim.
ctx.addPath(squircle)
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.35).cgColor)
ctx.setLineWidth(size * 0.01)
ctx.strokePath()

// Pencil glyph, white, centered.
let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .medium)
if let symbol = NSImage(systemSymbolName: "pencil.and.outline", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfig) {
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    NSColor.white.set()
    let symbolRect = CGRect(origin: .zero, size: symbol.size)
    symbol.draw(in: symbolRect)
    symbolRect.fill(using: .sourceAtop)
    tinted.unlockFocus()

    let drawSize = CGSize(width: size * 0.5, height: size * 0.5 * (symbol.size.height / symbol.size.width))
    let origin = CGPoint(x: (size - drawSize.width) / 2, y: (size - drawSize.height) / 2)
    tinted.draw(in: CGRect(origin: origin, size: drawSize))
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("failed to render icon PNG")
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
try! png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
