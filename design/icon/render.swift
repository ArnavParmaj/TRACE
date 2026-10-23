// Renders the app icon (concept A, "Route") to 1024px PNGs.
// Run from the repo root: swift design/icon/render.swift
// Geometry matches the mockup SVG: 1024 grid, y down.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let out = "TRACE/Assets.xcassets/AppIcon.appiconset"
let amber = CGColor(red: 1, green: 0x8A / 255, blue: 0x3D / 255, alpha: 1)   // --accent
let diagonal = CGColor(red: 0x1A / 255, green: 0x17 / 255, blue: 0x14 / 255, alpha: 1) // --diagonal
let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)                     // --ground
let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

func render(_ file: String, ground: CGColor?, mark: CGColor, stroke: CGFloat, diagonals: Bool) {
    let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        // opaque icons get no alpha channel at all; App Store rejects alpha on the default icon
                        bitmapInfo: (ground == nil ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast).rawValue)!
    ctx.translateBy(x: 0, y: 1024); ctx.scaleBy(x: 1, y: -1) // SVG coordinates
    if let ground { ctx.setFillColor(ground); ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024)) }

    if diagonals {
        ctx.setStrokeColor(diagonal); ctx.setLineWidth(8)
        for (a, b) in [((0, 790), (790, 0)), ((0, 1024), (1024, 0)), ((234, 1024), (1024, 234))] {
            ctx.move(to: CGPoint(x: a.0, y: a.1)); ctx.addLine(to: CGPoint(x: b.0, y: b.1))
        }
        ctx.strokePath()
    }

    ctx.setStrokeColor(mark); ctx.setFillColor(mark)
    ctx.setLineWidth(stroke); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    // M262 744 C262 600 520 690 530 510 S760 380 772 236  (S reflects the previous control point)
    ctx.move(to: CGPoint(x: 262, y: 744))
    ctx.addCurve(to: CGPoint(x: 530, y: 510), control1: CGPoint(x: 262, y: 600), control2: CGPoint(x: 520, y: 690))
    ctx.addCurve(to: CGPoint(x: 772, y: 236), control1: CGPoint(x: 540, y: 330), control2: CGPoint(x: 760, y: 380))
    ctx.strokePath()
    ctx.strokeEllipse(in: CGRect(x: 262 - 46, y: 790 - 46, width: 92, height: 92)) // start ring
    ctx.fillEllipse(in: CGRect(x: 772 - 44, y: 236 - 44, width: 88, height: 88))   // finish dot

    let url = URL(fileURLWithPath: "\(out)/\(file)")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(dest), "failed to write \(file)")
}

// Default must be opaque; dark is transparent (iOS adds its own dark ground);
// tinted is grayscale, iOS applies the user's tint.
render("AppIcon.png", ground: black, mark: amber, stroke: 34, diagonals: true)
render("AppIcon-Dark.png", ground: nil, mark: amber, stroke: 40, diagonals: false)
render("AppIcon-Tinted.png", ground: black, mark: white, stroke: 40, diagonals: false)
print("wrote 3 icons to \(out)")
