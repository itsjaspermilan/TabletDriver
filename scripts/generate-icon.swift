#!/usr/bin/swift
import AppKit
import CoreGraphics
import CoreImage

// Renders the app icon: a dark glass tile with a glowing, pressure-tapered
// ink stroke (thin -> thick -> thin, like a pen pressed harder mid-stroke).
// Usage: generate-icon.swift [output.png]   (writes a 1024x1024 PNG)

let canvas = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func makeContext() -> CGContext {
    CGContext(
        data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [r, g, b, a])!
}

func blurred(_ image: CGImage, radius: Double) -> CGImage {
    let ci = CIImage(cgImage: image)
    let out = ci.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius]).cropped(to: ci.extent)
    return CIContext().createCGImage(out, from: ci.extent)!
}

let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

func strokeOutline() -> CGPath {
    let p0 = CGPoint(x: 245, y: 330), c1 = CGPoint(x: 330, y: 760)
    let c2 = CGPoint(x: 560, y: 820), p3 = CGPoint(x: 790, y: 700)
    func point(_ t: Double) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u*u*u*p0.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*p3.x,
            y: u*u*u*p0.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*p3.y
        )
    }
    let steps = 400
    let path = CGMutablePath()
    for i in 0...steps {
        let t = Double(i) / Double(steps)
        let radius = 2 + 52 * pow(sin(Double.pi * t), 1.1)
        let p = point(t)
        path.addEllipse(in: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
    }
    return path
}

func gradientFill(_ ctx: CGContext, path: CGPath) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let g = CGGradient(colorsSpace: colorSpace, colors: [
        color(0.10, 0.85, 1.0), color(0.45, 0.50, 1.0), color(0.95, 0.30, 0.85)
    ] as CFArray, locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 245, y: 330), end: CGPoint(x: 790, y: 720), options: [])
    ctx.restoreGState()
}

let ctx = makeContext()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: color(0, 0, 0, 0.45))
ctx.addPath(tilePath)
ctx.setFillColor(color(0.05, 0.05, 0.12))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()

let background = CGGradient(colorsSpace: colorSpace, colors: [
    color(0.16, 0.12, 0.42), color(0.05, 0.05, 0.14), color(0.03, 0.03, 0.08)
] as CFArray, locations: [0, 0.55, 1])!
ctx.drawRadialGradient(
    background, startCenter: CGPoint(x: 330, y: 840), startRadius: 0,
    endCenter: CGPoint(x: 330, y: 840), endRadius: 900, options: [.drawsAfterEndLocation]
)

var centering = CGAffineTransform(translationX: 512, y: 512).scaledBy(x: 1.18, y: 1.18).translatedBy(x: -515, y: -585)
let outline = strokeOutline().copy(using: &centering)!
let glowLayer = makeContext()
gradientFill(glowLayer, path: outline)
let glowImage = glowLayer.makeImage()!
ctx.setBlendMode(.plusLighter)
ctx.draw(blurred(glowImage, radius: 46), in: CGRect(x: 0, y: 0, width: canvas, height: canvas))
ctx.setAlpha(0.6)
ctx.draw(blurred(glowImage, radius: 14), in: CGRect(x: 0, y: 0, width: canvas, height: canvas))
ctx.setAlpha(1)
ctx.setBlendMode(.normal)

gradientFill(ctx, path: outline)

ctx.saveGState()
ctx.addPath(outline)
ctx.clip()
let sheen = CGGradient(colorsSpace: colorSpace, colors: [
    color(1, 1, 1, 0.55), color(1, 1, 1, 0)
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: 860), end: CGPoint(x: 0, y: 560), options: [])
ctx.restoreGState()

let glass = CGGradient(colorsSpace: colorSpace, colors: [
    color(1, 1, 1, 0.16), color(1, 1, 1, 0)
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(glass, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 520), options: [])

ctx.restoreGState()

let rimLayer = makeContext()
rimLayer.addPath(tilePath)
rimLayer.clip()
rimLayer.addPath(tilePath)
rimLayer.setLineWidth(6)
rimLayer.replacePathWithStrokedPath()
rimLayer.clip()
let rim = CGGradient(colorsSpace: colorSpace, colors: [
    color(1, 1, 1, 0.65), color(1, 1, 1, 0.05), color(1, 1, 1, 0.2)
] as CFArray, locations: [0, 0.6, 1])!
rimLayer.drawLinearGradient(rim, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])
ctx.draw(rimLayer.makeImage()!, in: CGRect(x: 0, y: 0, width: canvas, height: canvas))

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
let png = rep.representation(using: .png, properties: [:])!
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
try! png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
