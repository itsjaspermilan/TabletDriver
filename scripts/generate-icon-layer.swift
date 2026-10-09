#!/usr/bin/swift
import Foundation

// Writes the pressure-stroke vector layer used by Resources/AppIcon.icon
// (the Icon Composer document). Thin -> thick -> thin, like a pen pressed
// harder mid-stroke. Usage: generate-icon-layer.swift [output.svg]

let p0 = (x: 245.0, y: 330.0), c1 = (x: 330.0, y: 760.0)
let c2 = (x: 560.0, y: 820.0), p3 = (x: 790.0, y: 700.0)

var circles = ""
let steps = 400
for i in 0...steps {
    let t = Double(i) / Double(steps), u = 1 - t
    let x = u*u*u*p0.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*p3.x
    let y = u*u*u*p0.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*p3.y
    let r = 2 + 62 * pow(sin(Double.pi * t), 1.1)
    // SVG y grows downward; the control points above are y-up.
    circles += String(format: "<circle cx=\"%.1f\" cy=\"%.1f\" r=\"%.1f\"/>", x, 1024 - y, r)
}

let svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="245" y1="694" x2="790" y2="304">
<stop offset="0" stop-color="#1AD9FF"/><stop offset="0.5" stop-color="#7380FF"/><stop offset="1" stop-color="#F24DD9"/>
</linearGradient></defs>
<g fill="url(#g)" transform="translate(512 512) scale(1.3) translate(-515 -450)">\(circles)</g>
</svg>
"""
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "stroke.svg"
try! svg.write(toFile: out, atomically: true, encoding: .utf8)
print("Wrote \(out)")
