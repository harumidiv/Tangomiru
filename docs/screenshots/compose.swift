import AppKit
import ImageIO

let W = 2007, H = 2853
let src = CommandLine.arguments[1], out = CommandLine.arguments[2]
func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(red: r, green: g, blue: b, alpha: 1) }
let slides: [(String, String, String, NSColor, NSColor)] = [
    ("01_library", "英文を貼るだけで\n単語帳ができる", "記事ごとに習得率と学習日をひと目で", c(1.0, 0.58, 0.20), c(0.98, 0.36, 0.36)),
    ("02_review", "覚えたい単語を\n自動で抽出", "意味つきで一覧化、出題する語も選べる", c(0.25, 0.52, 0.98), c(0.30, 0.78, 0.95)),
    ("04_detail", "苦手な単語から\nクイズで復習", "覚えた・うろ覚え・苦手を自動で記録", c(0.62, 0.38, 0.96), c(0.36, 0.50, 0.98)),
    ("03_quiz", "4択でテンポよく\n意味をチェック", "10問・20問・全問から選べる", c(1.0, 0.50, 0.25), c(1.0, 0.72, 0.20)),
    ("05_reading", "本文の中で\n習熟度が見える", "苦手な単語ほど色が濃くハイライト", c(0.15, 0.72, 0.60), c(0.20, 0.55, 0.92)),
    ("06_study", "1文ずつ\n和訳と解説つき", "文法のポイントもていねいに解説", c(0.98, 0.40, 0.50), c(0.70, 0.36, 0.95)),
    ("07_comprehension", "内容理解クイズで\n読解力アップ", "本文を理解できたか4択で確かめる", c(0.20, 0.70, 0.45), c(0.15, 0.62, 0.85)),
]

for (i, s) in slides.enumerated() {
    guard let shot = NSImage(contentsOfFile: "\(src)/\(s.0).png") else { fatalError(s.0) }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let full = NSRect(x: 0, y: 0, width: W, height: H)
    NSGradient(starting: s.3, ending: s.4)!.draw(in: full, angle: -60)

    // 装飾の円
    NSColor.white.withAlphaComponent(0.12).setFill()
    NSBezierPath(ovalIn: NSRect(x: -300, y: H - 700, width: 900, height: 900)).fill()
    NSBezierPath(ovalIn: NSRect(x: W - 500, y: -250, width: 900, height: 900)).fill()

    // キャプション
    let center = NSMutableParagraphStyle(); center.alignment = .center; center.lineSpacing = 12
    let title = NSAttributedString(string: s.1, attributes: [.font: NSFont.systemFont(ofSize: 150, weight: .heavy), .foregroundColor: NSColor.white, .paragraphStyle: center])
    title.draw(in: NSRect(x: 60, y: H - 520, width: W - 120, height: 420))
    let sub = NSAttributedString(string: s.2, attributes: [.font: NSFont.systemFont(ofSize: 72, weight: .semibold), .foregroundColor: NSColor.white.withAlphaComponent(0.92), .paragraphStyle: center])
    sub.draw(in: NSRect(x: 60, y: H - 660, width: W - 120, height: 110))

    // スクリーンショット（角丸＋影＋端末風フチ）
    let sw: CGFloat = 1500, sh = sw * 2853 / 2007
    let rect = NSRect(x: (CGFloat(W) - sw) / 2, y: CGFloat(H) - 760 - sh, width: sw, height: sh)
    let bezel = rect.insetBy(dx: -28, dy: -28)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.35); shadow.shadowBlurRadius = 60; shadow.shadowOffset = NSSize(width: 0, height: -20)
    shadow.set()
    NSColor(white: 0.08, alpha: 1).setFill()
    NSBezierPath(roundedRect: bezel, xRadius: 110, yRadius: 110).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: 84, yRadius: 84).addClip()
    shot.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    // App Store はアルファ不可のため RGB で書き出す
    let url = URL(fileURLWithPath: "\(out)/appstore_\(String(format: "%02d", i + 1)).png")
    let flat = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    flat.draw(rep.cgImage!, in: CGRect(x: 0, y: 0, width: W, height: H))
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, flat.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}
print("done")
