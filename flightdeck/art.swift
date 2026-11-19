// Draws the Flight Deck artwork: a sunset sky with Bf 109 and P-51 silhouettes.
// Usage: art <outdir>
import AppKit

let outDir = CommandLine.arguments[1]

// ---------- aircraft side profiles (facing right, 100 x 34 box, y down) ----------
func p51() -> NSBezierPath {
    let p = NSBezierPath()
    // fuselage, fin and canopy
    p.move(to: .init(x: 1.5, y: 0.5))
    p.line(to: .init(x: 7, y: 1))
    p.curve(to: .init(x: 17, y: 14.5), controlPoint1: .init(x: 9, y: 6), controlPoint2: .init(x: 12, y: 12.5))
    p.line(to: .init(x: 55, y: 12.8))
    p.curve(to: .init(x: 62.5, y: 8.6), controlPoint1: .init(x: 57, y: 10.2), controlPoint2: .init(x: 59.5, y: 8.6))
    p.curve(to: .init(x: 70, y: 12), controlPoint1: .init(x: 66, y: 8.6), controlPoint2: .init(x: 69, y: 10.2))
    p.line(to: .init(x: 91, y: 12))
    p.curve(to: .init(x: 100, y: 17), controlPoint1: .init(x: 96, y: 12.5), controlPoint2: .init(x: 100, y: 14.5))
    p.curve(to: .init(x: 91, y: 22), controlPoint1: .init(x: 100, y: 19.5), controlPoint2: .init(x: 96, y: 21.5))
    p.line(to: .init(x: 84, y: 23.5))
    p.line(to: .init(x: 62, y: 24))
    // belly air scoop
    p.line(to: .init(x: 58, y: 24.5))
    p.curve(to: .init(x: 53, y: 27.3), controlPoint1: .init(x: 56.5, y: 26.5), controlPoint2: .init(x: 55, y: 27.3))
    p.line(to: .init(x: 42, y: 27.3))
    p.curve(to: .init(x: 39, y: 23.8), controlPoint1: .init(x: 40, y: 27.3), controlPoint2: .init(x: 39, y: 25.5))
    p.line(to: .init(x: 14, y: 20.5))
    p.line(to: .init(x: 3, y: 19))
    p.curve(to: .init(x: 1, y: 3), controlPoint1: .init(x: 1.5, y: 14), controlPoint2: .init(x: 0.5, y: 8))
    p.close()
    // horizontal stabiliser
    p.appendOval(in: NSRect(x: 1, y: 16, width: 18, height: 2.6))
    // wing, seen nearly edge-on
    let w = NSBezierPath(); w.move(to: .init(x: 50, y: 21)); w.line(to: .init(x: 80, y: 21)); w.line(to: .init(x: 75, y: 30)); w.line(to: .init(x: 56, y: 31.5)); w.close(); p.append(w)
    return p
}

func bf109() -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: .init(x: 0.5, y: 6))
    p.curve(to: .init(x: 8, y: 4.5), controlPoint1: .init(x: 2, y: 4.5), controlPoint2: .init(x: 5, y: 4))
    p.line(to: .init(x: 12, y: 15))
    p.line(to: .init(x: 55, y: 13))
    // angular, framed canopy
    p.line(to: .init(x: 59, y: 8.5))
    p.line(to: .init(x: 69, y: 8))
    p.line(to: .init(x: 74, y: 12))
    p.line(to: .init(x: 89, y: 13))
    // big pointed spinner
    p.curve(to: .init(x: 100, y: 18), controlPoint1: .init(x: 94, y: 13.5), controlPoint2: .init(x: 98, y: 15.5))
    p.curve(to: .init(x: 89, y: 23.5), controlPoint1: .init(x: 98, y: 20.5), controlPoint2: .init(x: 94, y: 23))
    // chin bulge and underwing radiator
    p.line(to: .init(x: 86, y: 25.5))
    p.line(to: .init(x: 75, y: 25))
    p.line(to: .init(x: 74, y: 27))
    p.line(to: .init(x: 63, y: 27))
    p.line(to: .init(x: 62, y: 24.5))
    p.line(to: .init(x: 12, y: 20))
    p.line(to: .init(x: 2, y: 18.5))
    p.curve(to: .init(x: 0.5, y: 6), controlPoint1: .init(x: 0.5, y: 14), controlPoint2: .init(x: 0, y: 9))
    p.close()
    p.appendOval(in: NSRect(x: 0, y: 14, width: 17, height: 2.6))
    let w = NSBezierPath(); w.move(to: .init(x: 52, y: 21.5)); w.line(to: .init(x: 78, y: 21.5)); w.line(to: .init(x: 73, y: 30)); w.line(to: .init(x: 57, y: 31)); w.close(); p.append(w)
    return p
}

// place an aircraft: centre, length in points, rotation (deg), mirror to face left
func drawPlane(_ path: NSBezierPath, at c: NSPoint, length: CGFloat, angle: CGFloat, faceLeft: Bool, color: NSColor, prop: Bool = true) {
    let s = length / 100
    let t = NSAffineTransform()
    t.translateX(by: c.x, yBy: c.y)
    t.rotate(byDegrees: angle)
    t.scaleX(by: faceLeft ? -s : s, yBy: -s)        // flip y (paths are y-down)
    t.translateX(by: -50, yBy: -17)
    let p = path.copy() as! NSBezierPath
    p.transform(using: t as AffineTransform)
    color.setFill(); p.fill()
    if prop {
        let d = NSBezierPath(ovalIn: NSRect(x: 99.5, y: 1, width: 2, height: 32))
        d.transform(using: t as AffineTransform)
        color.withAlphaComponent(color.alphaComponent * 0.35).setFill(); d.fill()
    }
}

func tracer(from a: NSPoint, to b: NSPoint, alpha: CGFloat) {
    let l = NSBezierPath(); l.move(to: a); l.line(to: b)
    l.lineWidth = 1.2; l.lineCapStyle = .round
    NSColor(red: 1, green: 0.85, blue: 0.45, alpha: alpha).setStroke(); l.stroke()
}

func sky(_ r: NSRect) {
    NSGradient(colorsAndLocations:
        (NSColor(red: 0.06, green: 0.10, blue: 0.22, alpha: 1), 0.0),
        (NSColor(red: 0.20, green: 0.22, blue: 0.40, alpha: 1), 0.45),
        (NSColor(red: 0.78, green: 0.42, blue: 0.30, alpha: 1), 0.82),
        (NSColor(red: 0.98, green: 0.70, blue: 0.38, alpha: 1), 1.0))!
        .draw(in: r, angle: -90)
    // sun
    NSGradient(colors: [NSColor(red: 1, green: 0.85, blue: 0.55, alpha: 0.9), NSColor(red: 1, green: 0.6, blue: 0.3, alpha: 0)])!
        .draw(fromCenter: NSPoint(x: r.maxX * 0.78, y: r.minY + r.height * 0.12), radius: 0,
              toCenter: NSPoint(x: r.maxX * 0.78, y: r.minY + r.height * 0.12), radius: r.height * 0.55, options: [])
    // soft cloud bands
    var rng = SystemRandomNumberGenerator()
    for i in 0..<14 {
        let y = r.minY + r.height * CGFloat.random(in: 0.08...0.45, using: &rng)
        let x = r.minX + r.width * CGFloat(i) / 13 + CGFloat.random(in: -40...40, using: &rng)
        let w = CGFloat.random(in: 120...300, using: &rng), h = CGFloat.random(in: 10...26, using: &rng)
        NSColor(red: 1, green: 0.78, blue: 0.62, alpha: CGFloat.random(in: 0.08...0.18, using: &rng)).setFill()
        NSBezierPath(ovalIn: NSRect(x: x - w / 2, y: y, width: w, height: h)).fill()
    }
}

func dogfight(in r: NSRect, scale k: CGFloat, tracers: Bool = true) {
    let ink = NSColor(red: 0.05, green: 0.06, blue: 0.13, alpha: 0.92)
    let far = NSColor(red: 0.16, green: 0.15, blue: 0.27, alpha: 0.75)
    func P(_ fx: CGFloat, _ fy: CGFloat) -> NSPoint { NSPoint(x: r.minX + r.width * fx, y: r.minY + r.height * fy) }
    // distant flight of P-51s
    drawPlane(p51(), at: P(0.12, 0.70), length: 34 * k, angle: 4, faceLeft: false, color: far)
    drawPlane(p51(), at: P(0.19, 0.76), length: 30 * k, angle: 4, faceLeft: false, color: far)
    // distant Bf 109 diving away
    drawPlane(bf109(), at: P(0.90, 0.80), length: 30 * k, angle: 18, faceLeft: true, color: far)
    // main pass: P-51 chasing a Bf 109
    if tracers {
        tracer(from: P(0.47, 0.50), to: P(0.60, 0.585), alpha: 0.85)
        tracer(from: P(0.47, 0.47), to: P(0.61, 0.555), alpha: 0.6)
    }
    drawPlane(bf109(), at: P(0.70, 0.62), length: 92 * k, angle: 14, faceLeft: false, color: ink)
    drawPlane(p51(), at: P(0.36, 0.44), length: 120 * k, angle: 12, faceLeft: false, color: ink)
    // wingman
    drawPlane(p51(), at: P(0.18, 0.30), length: 70 * k, angle: 9, faceLeft: false, color: ink.withAlphaComponent(0.85))
}

func render(w: CGFloat, h: CGFloat, scale: CGFloat, path: String, _ body: (NSRect) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w * scale), pixelsHigh: Int(h * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: w, height: h)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    body(NSRect(x: 0, y: 0, width: w, height: h))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, in r: NSRect, kern: CGFloat = 0, align: NSTextAlignment = .center) {
    let p = NSMutableParagraphStyle(); p.alignment = align
    let shadow = NSShadow(); shadow.shadowColor = NSColor(white: 0, alpha: 0.35); shadow.shadowBlurRadius = 4; shadow.shadowOffset = .init(width: 0, height: -1)
    NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color,
                                               .paragraphStyle: p, .kern: kern, .shadow: shadow]).draw(in: r)
}

// 1. App header (760 x 230)
for (sc, name) in [(1, "header.png"), (2, "header@2x.png")] as [(CGFloat, String)] {
    render(w: 760, h: 230, scale: sc, path: "\(outDir)/\(name)") { r in sky(r); dogfight(in: r, scale: 1.0) }
}

// 2. DMG background (660 x 470): sky band on top, light panel below so Finder's dark labels stay readable
for (sc, name) in [(1, "dmg.png"), (2, "dmg@2x.png")] as [(CGFloat, String)] {
    render(w: 660, h: 470, scale: sc, path: "\(outDir)/\(name)") { r in
        NSColor(red: 0.93, green: 0.94, blue: 0.97, alpha: 1).setFill(); r.fill()
        let band = NSRect(x: 0, y: 330, width: 660, height: 140)
        NSGraphicsContext.saveGraphicsState(); NSBezierPath(rect: band).addClip()
        sky(band); dogfight(in: NSRect(x: 0, y: 268, width: 660, height: 190), scale: 0.62, tracers: false)
        NSGraphicsContext.restoreGraphicsState()
        text("WORLD OF WARPLANES FOR MAC", size: 21, weight: .heavy, color: .white, in: NSRect(x: 0, y: 418, width: 660, height: 32), kern: 1.6)
        text("Unofficial community port  ·  not affiliated with Wargaming", size: 11, weight: .medium, color: NSColor(white: 1, alpha: 0.85), in: NSRect(x: 0, y: 398, width: 660, height: 18))
        // runway arrow between the two top icons (centre y = 470 - 190 = 280)
        let y: CGFloat = 280
        let dash = NSBezierPath(); dash.move(to: .init(x: 252, y: y)); dash.line(to: .init(x: 392, y: y))
        dash.lineWidth = 5; dash.setLineDash([14, 9], count: 2, phase: 0); dash.lineCapStyle = .round
        NSColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1).setStroke(); dash.stroke()
        let head = NSBezierPath(); head.move(to: .init(x: 410, y: y)); head.line(to: .init(x: 390, y: y + 13)); head.line(to: .init(x: 390, y: y - 13)); head.close()
        NSColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1).setFill(); head.fill()
        let ink = NSColor(red: 0.12, green: 0.17, blue: 0.28, alpha: 1)
        let p = NSMutableParagraphStyle(); p.alignment = .center
        func label(_ s: String, _ y: CGFloat, _ size: CGFloat, _ wgt: NSFont.Weight) {
            NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: wgt), .foregroundColor: ink, .paragraphStyle: p])
                .draw(in: NSRect(x: 0, y: y, width: 660, height: size * 1.5))
        }
        label("Taxi the plane into your hangar (Applications)", 186, 12, .semibold)
        NSColor(white: 0, alpha: 0.08).setFill(); NSRect(x: 60, y: 176, width: 540, height: 1).fill()
        label("Then open Flight Deck — it gets you airborne", 150, 12, .semibold)
    }
}

// 3. App icon (rounded square, sky + P-51)
for px in [16, 32, 64, 128, 256, 512, 1024] {
    render(w: CGFloat(px), h: CGFloat(px), scale: 1, path: "\(outDir)/icon_\(px).png") { r in
        let inset = r.width * 0.09
        let box = r.insetBy(dx: inset, dy: inset)
        let rr = NSBezierPath(roundedRect: box, xRadius: box.width * 0.225, yRadius: box.width * 0.225)
        NSGraphicsContext.saveGraphicsState(); rr.addClip(); sky(box)
        drawPlane(p51(), at: NSPoint(x: box.midX, y: box.midY + box.height * 0.05), length: box.width * 0.92, angle: 10, faceLeft: false,
                  color: NSColor(red: 0.05, green: 0.06, blue: 0.13, alpha: 0.95))
        NSGraphicsContext.restoreGraphicsState()
    }
}
print("art written to \(outDir)")
