// Renders Resources/AppIcon.icns. Run: swift Scripts/make-icon.swift
import AppKit

let canvas: CGFloat = 1024
// Apple's icon grid: 824pt squircle centered on a 1024pt canvas.
let inset: CGFloat = 100
let cornerRadius: CGFloat = 185

let image = NSImage(size: NSSize(width: canvas, height: canvas))
image.lockFocus()

let rect = NSRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
let squircle = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
NSGradient(
    starting: NSColor(red: 0.43, green: 0.48, blue: 1.0, alpha: 1),
    ending: NSColor(red: 0.22, green: 0.26, blue: 0.86, alpha: 1)
)!.draw(in: squircle, angle: -90)

let config = NSImage.SymbolConfiguration(pointSize: 420, weight: .medium)
    .applying(.init(paletteColors: [.white]))
guard let symbol = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) else {
    fatalError("gamecontroller.fill unavailable")
}
let targetWidth: CGFloat = 560
let scale = targetWidth / symbol.size.width
let symbolSize = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
symbol.draw(in: NSRect(x: (canvas - symbolSize.width) / 2,
                       y: (canvas - symbolSize.height) / 2,
                       width: symbolSize.width, height: symbolSize.height),
            from: .zero, operation: .sourceOver, fraction: 1)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG encode failed")
}
let out = URL(fileURLWithPath: "icon-1024.png")
try! png.write(to: out)
print("wrote \(out.path)")
