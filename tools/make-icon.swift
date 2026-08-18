import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

let inset: CGFloat = 100
let squircle = NSBezierPath(
    roundedRect: NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset),
    xRadius: 200, yRadius: 200
)
ctx.saveGState()
squircle.addClip()
let gradient = NSGradient(
    starting: NSColor(calibratedRed: 0.69, green: 0.74, blue: 1.0, alpha: 1),
    ending: NSColor(calibratedRed: 0.43, green: 0.44, blue: 0.86, alpha: 1)
)
gradient?.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)
ctx.restoreGState()

ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineWidth(58)
ctx.setLineCap(.round)

func donut(_ cx: CGFloat, _ cy: CGFloat) {
    ctx.strokeEllipse(in: CGRect(x: cx - 76, y: (size - cy) - 76, width: 152, height: 152))
}
func flip(_ y: CGFloat) -> CGFloat { size - y }

donut(362, 412)
donut(362, 660)
donut(662, 660)

ctx.beginPath()
ctx.move(to: CGPoint(x: 362, y: flip(514)))
ctx.addLine(to: CGPoint(x: 362, y: flip(558)))
ctx.strokePath()

ctx.beginPath()
ctx.move(to: CGPoint(x: 470, y: flip(412)))
ctx.addLine(to: CGPoint(x: 566, y: flip(412)))
ctx.addQuadCurve(to: CGPoint(x: 662, y: flip(508)), control: CGPoint(x: 662, y: flip(412)))
ctx.addLine(to: CGPoint(x: 662, y: flip(556)))
ctx.strokePath()

let dotCenter = CGPoint(x: 745, y: flip(300))
ctx.setFillColor(NSColor(calibratedRed: 1.0, green: 0.49, blue: 0.56, alpha: 1).cgColor)
ctx.fillEllipse(in: CGRect(x: dotCenter.x - 108, y: dotCenter.y - 108, width: 216, height: 216))

ctx.setFillColor(NSColor.white.cgColor)
ctx.fillEllipse(in: CGRect(x: dotCenter.x - 52 - 15, y: dotCenter.y + 8, width: 30, height: 30))
ctx.fillEllipse(in: CGRect(x: dotCenter.x + 52 - 15, y: dotCenter.y + 8, width: 30, height: 30))

ctx.setLineWidth(16)
ctx.beginPath()
ctx.addArc(
    center: CGPoint(x: dotCenter.x, y: dotCenter.y - 8),
    radius: 44,
    startAngle: .pi * 1.15,
    endAngle: .pi * 1.85,
    clockwise: false
)
ctx.strokePath()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else { exit(1) }
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
