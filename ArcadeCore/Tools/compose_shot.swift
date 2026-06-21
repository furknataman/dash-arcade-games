// compose_shot.swift — App Store marketing screenshot composer for 2D games.
//
// Renders a polished 1320x2868 (6.9") screenshot: a themed gradient backdrop,
// a bold headline (+ optional subtitle), and the raw gameplay screenshot shown
// inside a rounded "device" card with a soft shadow and a subtle floating coin
// motif. Reusable across every ArcadeCore game — drive it from a manifest.
//
// Usage:
//   swift compose_shot.swift <out.png> <raw.png> <bgTopHex> <bgBotHex> <accentHex> <headline> [subtitle]
//
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CoreText

let args = CommandLine.arguments
guard args.count >= 7 else { FileHandle.standardError.write("need 6+ args\n".data(using: .utf8)!); exit(1) }
let outPath = args[1], rawPath = args[2]
let bgTop = args[3], bgBot = args[4], accent = args[5], headline = args[6]
let subtitle = args.count >= 8 ? args[7] : ""

let W = 1320, H = 2868
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let Wf = CGFloat(W), Hf = CGFloat(H)

func hex(_ s: String, _ a: CGFloat = 1) -> CGColor {
    var h = s; if h.hasPrefix("#") { h.removeFirst() }
    let v = UInt32(h, radix: 16) ?? 0
    return CGColor(red: CGFloat((v>>16)&0xFF)/255, green: CGFloat((v>>8)&0xFF)/255,
                   blue: CGFloat(v&0xFF)/255, alpha: a)
}

// 1) Background gradient (diagonal for energy).
let grad = CGGradient(colorsSpace: cs, colors: [hex(bgTop), hex(bgBot)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: Hf), end: CGPoint(x: Wf, y: 0), options: [])

// Soft accent glow blobs for depth.
func blob(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ c: CGColor) {
    let g = CGGradient(colorsSpace: cs, colors: [c, hex(accent, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0,
                           endCenter: CGPoint(x: x, y: y), endRadius: r, options: [])
}
blob(Wf*0.18, Hf*0.82, 520, hex(accent, 0.22))
blob(Wf*0.86, Hf*0.30, 600, hex(accent, 0.14))

// 2) Read the raw screenshot first so we can size the card and place text.
guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: rawPath) as CFURL, nil),
      let raw = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    FileHandle.standardError.write("cannot read raw\n".data(using: .utf8)!); exit(1)
}
let cardW: CGFloat = Wf * 0.60
let cardH = cardW * CGFloat(raw.height) / CGFloat(raw.width)
let cardX = (Wf - cardW)/2
let cardY: CGFloat = 200
let cardTop = cardY + cardH
let radius: CGFloat = 70

func draw(_ text: String, font: CTFont, color: CGColor, cx: CGFloat, y: CGFloat, maxW: CGFloat) {
    let s = CFAttributedStringCreateMutable(nil, 0)!
    CFAttributedStringReplaceString(s, CFRange(location: 0, length: 0), text as CFString)
    let full = CFRange(location: 0, length: (text as NSString).length)
    CFAttributedStringSetAttribute(s, full, kCTFontAttributeName, font)
    CFAttributedStringSetAttribute(s, full, kCTForegroundColorAttributeName, color)
    let line = CTLineCreateWithAttributedString(s)
    let b = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.textPosition = CGPoint(x: cx - b.width/2, y: y)
    CTLineDraw(line, ctx)
}

// Word-wrap the headline to ~2 lines.
let words = headline.split(separator: " ").map(String.init)
var lines: [String] = []
if words.count <= 2 { lines = [headline] }
else {
    let mid = (words.count + 1) / 2
    lines = [words[0..<mid].joined(separator: " "), words[mid...].joined(separator: " ")]
}
// Title block sits in the space above the card.
let lineGap: CGFloat = 132
let titleFont = CTFontCreateWithName("Avenir-Heavy" as CFString, 110, nil)
let subFont = CTFontCreateWithName("Avenir-Medium" as CFString, 52, nil)
let blockTop = min(Hf - 240, cardTop + 600)   // title block anchored above card
var ty = blockTop
for ln in lines {
    draw(ln.uppercased(), font: titleFont, color: hex("FFFFFF"), cx: Wf/2, y: ty, maxW: Wf-120)
    ty -= lineGap
}
if !subtitle.isEmpty {
    draw(subtitle, font: subFont, color: hex(accent), cx: Wf/2, y: ty + 18, maxW: Wf-160)
}

// 3) Device card holding the raw screenshot.
func roundedRect(_ r: CGRect, _ rad: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
}
let cardRect = CGRect(x: cardX, y: cardY, width: cardW, height: cardH)

// Shadow.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 70, color: hex("000000", 0.55))
ctx.addPath(roundedRect(cardRect, radius)); ctx.setFillColor(hex("000000")); ctx.fillPath()
ctx.restoreGState()

// Accent border frame.
ctx.addPath(roundedRect(cardRect.insetBy(dx: -10, dy: -10), radius+8))
ctx.setStrokeColor(hex(accent, 0.9)); ctx.setLineWidth(10); ctx.strokePath()

// Clip + draw screenshot.
ctx.saveGState()
ctx.addPath(roundedRect(cardRect, radius)); ctx.clip()
ctx.draw(raw, in: cardRect)
ctx.restoreGState()

// 4) A couple of floating accent coins for playfulness.
for (cxp, cyp, rr) in [(Wf*0.16, cardY+cardH*0.18, 46.0), (Wf*0.86, cardY+cardH*0.66, 34.0)] {
    ctx.setShadow(offset: .zero, blur: 30, color: hex(accent, 0.8))
    ctx.setFillColor(hex(accent))
    ctx.fillEllipse(in: CGRect(x: cxp-CGFloat(rr), y: cyp-CGFloat(rr), width: CGFloat(rr)*2, height: CGFloat(rr)*2))
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
}

guard let img = ctx.makeImage() else { exit(1) }
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                           UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outPath)")
