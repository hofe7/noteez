import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let S = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
  CGColor(colorSpace: cs, components: [CGFloat(r/255), CGFloat(g/255), CGFloat(b/255), CGFloat(a)])!
}

// ── macOS icon grid: artwork inset within the 1024 canvas ──
let inset: CGFloat = 92
let icon = CGRect(x: inset, y: inset, width: CGFloat(S) - 2*inset, height: CGFloat(S) - 2*inset)
let radius = icon.width * 0.2237   // Apple-ish continuous-ish corner

// ── 1. Rounded-rect background (soft warm cream) ──
let bgPath = CGPath(roundedRect: icon, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.saveGState()
// soft outer shadow under the whole tile
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 34, color: rgb(0,0,0,0.18))
ctx.addPath(bgPath); ctx.setFillColor(rgb(255,255,255)); ctx.fillPath()
ctx.restoreGState()
// cream gradient fill, clipped to the tile
ctx.saveGState()
ctx.addPath(bgPath); ctx.clip()
let bgGrad = CGGradient(colorsSpace: cs, colors: [rgb(255,255,255), rgb(255,246,221)] as CFArray,
                        locations: [0, 1])!
ctx.drawLinearGradient(bgGrad, start: CGPoint(x: icon.midX, y: icon.maxY),
                       end: CGPoint(x: icon.midX, y: icon.minY), options: [])
ctx.restoreGState()

// ── 2. The sticky note (square-ish, slight tilt, dog-eared top-right) ──
let noteW: CGFloat = icon.width * 0.62
let noteH: CGFloat = noteW * 1.06
let cx = icon.midX, cy = icon.midY
let fold = noteW * 0.26   // dog-ear size

ctx.saveGState()
// rotate the whole note slightly for life
ctx.translateBy(x: cx, y: cy)
ctx.rotate(by: -4 * .pi / 180)
ctx.translateBy(x: -noteW/2, y: -noteH/2)

let L: CGFloat = 0, R = noteW, B: CGFloat = 0, T = noteH

// page polygon with top-right corner cut
let page = CGMutablePath()
page.move(to: CGPoint(x: L, y: B))
page.addLine(to: CGPoint(x: R, y: B))
page.addLine(to: CGPoint(x: R, y: T - fold))
page.addLine(to: CGPoint(x: R - fold, y: T))
page.addLine(to: CGPoint(x: L, y: T))
page.closeSubpath()

// note shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 22, color: rgb(80,60,0,0.28))
ctx.addPath(page); ctx.setFillColor(rgb(255,226,122)); ctx.fillPath()
ctx.restoreGState()

// page gradient
ctx.saveGState()
ctx.addPath(page); ctx.clip()
let pg = CGGradient(colorsSpace: cs, colors: [rgb(255,239,168), rgb(255,224,118)] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(pg, start: CGPoint(x: 0, y: T), end: CGPoint(x: 0, y: B), options: [])
ctx.restoreGState()

// folded corner (underside triangle)
let foldTri = CGMutablePath()
foldTri.move(to: CGPoint(x: R, y: T - fold))
foldTri.addLine(to: CGPoint(x: R - fold, y: T))
foldTri.addLine(to: CGPoint(x: R - fold, y: T - fold))
foldTri.closeSubpath()
ctx.saveGState()
ctx.addPath(foldTri); ctx.clip()
let fg = CGGradient(colorsSpace: cs, colors: [rgb(232,201,94), rgb(212,178,70)] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(fg, start: CGPoint(x: R - fold, y: T), end: CGPoint(x: R, y: T - fold), options: [])
ctx.restoreGState()

// ── 3. note content: a checked todo + text lines ──
let ink = rgb(122,106,46, 0.62)
let pad = noteW * 0.16
let lineX = L + pad
let lineW = R - L - pad*1.4
let lineH = noteH * 0.052
func roundLine(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ color: CGColor) {
  let r = CGRect(x: x, y: y, width: w, height: lineH)
  ctx.addPath(CGPath(roundedRect: r, cornerWidth: lineH/2, cornerHeight: lineH/2, transform: nil))
  ctx.setFillColor(color); ctx.fillPath()
}
// checkbox row (top)
let boxS = noteH * 0.105
let boxY = T - pad - boxS
let box = CGRect(x: lineX, y: boxY, width: boxS, height: boxS)
ctx.addPath(CGPath(roundedRect: box, cornerWidth: boxS*0.28, cornerHeight: boxS*0.28, transform: nil))
ctx.setStrokeColor(rgb(94,140,76)); ctx.setLineWidth(boxS*0.16); ctx.strokePath()
// checkmark
ctx.move(to: CGPoint(x: box.minX + boxS*0.24, y: box.minY + boxS*0.50))
ctx.addLine(to: CGPoint(x: box.minX + boxS*0.43, y: box.minY + boxS*0.28))
ctx.addLine(to: CGPoint(x: box.minX + boxS*0.78, y: box.minY + boxS*0.72))
ctx.setStrokeColor(rgb(76,156,92)); ctx.setLineWidth(boxS*0.18)
ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.strokePath()
// line beside checkbox + 3 lines below
roundLine(box.maxX + pad*0.5, boxY + (boxS-lineH)/2, lineW - boxS - pad*0.5, ink)
let gap = lineH * 2.4
roundLine(lineX, boxY - gap, lineW, ink)
roundLine(lineX, boxY - gap*2, lineW, ink)
roundLine(lineX, boxY - gap*3, lineW * 0.66, ink)

ctx.restoreGState()

// ── write PNG ──
let img = ctx.makeImage()!
let url = URL(fileURLWithPath: "/tmp/noteez_appicon_1024.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("wrote \(url.path)")
