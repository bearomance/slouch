import SwiftUI

/// Line-art Xbox-style gamepad, ported from the design's SVG (380×248 viewBox).
struct ControllerArt: View {
    @Environment(\.colorScheme) private var colorScheme

    private struct Palette {
        let bodyStroke: Color
        let bodyFill: Color
        let controlStroke: Color
        let controlFill: Color
        let stickFill: Color
        let stickInner: Color
        let letter: Color
    }

    private var palette: Palette {
        if colorScheme == .dark {
            return Palette(
                bodyStroke: .white.opacity(0.35),
                bodyFill: .white.opacity(0.06),
                controlStroke: .white.opacity(0.30),
                controlFill: .white.opacity(0.10),
                stickFill: .white.opacity(0.12),
                stickInner: .white.opacity(0.05),
                letter: .white.opacity(0.55))
        }
        return Palette(
            bodyStroke: Color(red: 0.73, green: 0.73, blue: 0.77),
            bodyFill: Color(red: 0.99, green: 0.99, blue: 0.995),
            controlStroke: Color(red: 0.60, green: 0.60, blue: 0.65),
            controlFill: Color(red: 0.95, green: 0.96, blue: 0.97),
            stickFill: Color(red: 0.93, green: 0.94, blue: 0.96),
            stickInner: Color(red: 0.99, green: 0.99, blue: 1.0),
            letter: Color(red: 0.49, green: 0.49, blue: 0.53))
    }

    var body: some View {
        Canvas { ctx, size in
            let p = palette
            ctx.scaleBy(x: size.width / 380, y: size.height / 248)

            func roundedRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
                let path = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
                ctx.stroke(path, with: .color(p.controlStroke), lineWidth: 1.6)
            }
            func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, fill: Color, stroke: Color, lineWidth: CGFloat = 1.6) {
                let path = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
                ctx.fill(path, with: .color(fill))
                ctx.stroke(path, with: .color(stroke), lineWidth: lineWidth)
            }

            // Triggers and bumpers
            roundedRect(62, 20, 42, 16, 7)
            roundedRect(276, 20, 42, 16, 7)
            roundedRect(54, 40, 58, 15, 7.5)
            roundedRect(268, 40, 58, 15, 7.5)

            // Body
            var body = Path()
            body.move(to: CGPoint(x: 118, y: 56))
            body.addCurve(to: CGPoint(x: 54, y: 86), control1: CGPoint(x: 92, y: 50), control2: CGPoint(x: 66, y: 60))
            body.addCurve(to: CGPoint(x: 50, y: 184), control1: CGPoint(x: 42, y: 112), control2: CGPoint(x: 38, y: 150))
            body.addCurve(to: CGPoint(x: 104, y: 200), control1: CGPoint(x: 58, y: 208), control2: CGPoint(x: 84, y: 218))
            body.addCurve(to: CGPoint(x: 150, y: 166), control1: CGPoint(x: 120, y: 186), control2: CGPoint(x: 128, y: 168))
            body.addCurve(to: CGPoint(x: 230, y: 166), control1: CGPoint(x: 168, y: 164), control2: CGPoint(x: 212, y: 164))
            body.addCurve(to: CGPoint(x: 276, y: 200), control1: CGPoint(x: 252, y: 168), control2: CGPoint(x: 260, y: 186))
            body.addCurve(to: CGPoint(x: 330, y: 184), control1: CGPoint(x: 296, y: 218), control2: CGPoint(x: 322, y: 208))
            body.addCurve(to: CGPoint(x: 326, y: 86), control1: CGPoint(x: 342, y: 150), control2: CGPoint(x: 338, y: 112))
            body.addCurve(to: CGPoint(x: 262, y: 56), control1: CGPoint(x: 314, y: 60), control2: CGPoint(x: 288, y: 50))
            body.addCurve(to: CGPoint(x: 190, y: 64), control1: CGPoint(x: 238, y: 61), control2: CGPoint(x: 214, y: 64))
            body.addCurve(to: CGPoint(x: 118, y: 56), control1: CGPoint(x: 166, y: 64), control2: CGPoint(x: 142, y: 61))
            body.closeSubpath()
            ctx.fill(body, with: .color(p.bodyFill))
            ctx.stroke(body, with: .color(p.bodyStroke), lineWidth: 1.6)

            // Sticks
            for (cx, cy) in [(98.0, 104.0), (232.0, 162.0)] {
                circle(cx, cy, 21, fill: p.stickFill, stroke: p.bodyStroke)
                circle(cx, cy, 12, fill: p.stickInner, stroke: p.bodyStroke, lineWidth: 1.2)
            }

            // D-pad plus
            let (cx, cy, a, b): (CGFloat, CGFloat, CGFloat, CGFloat) = (112, 168, 11, 22)
            var plus = Path()
            plus.move(to: CGPoint(x: cx - a, y: cy - b))
            plus.addLine(to: CGPoint(x: cx + a, y: cy - b))
            plus.addLine(to: CGPoint(x: cx + a, y: cy - a))
            plus.addLine(to: CGPoint(x: cx + b, y: cy - a))
            plus.addLine(to: CGPoint(x: cx + b, y: cy + a))
            plus.addLine(to: CGPoint(x: cx + a, y: cy + a))
            plus.addLine(to: CGPoint(x: cx + a, y: cy + b))
            plus.addLine(to: CGPoint(x: cx - a, y: cy + b))
            plus.addLine(to: CGPoint(x: cx - a, y: cy + a))
            plus.addLine(to: CGPoint(x: cx - b, y: cy + a))
            plus.addLine(to: CGPoint(x: cx - b, y: cy - a))
            plus.addLine(to: CGPoint(x: cx - a, y: cy - a))
            plus.closeSubpath()
            ctx.fill(plus, with: .color(p.controlFill))
            ctx.stroke(plus, with: .color(p.bodyStroke), lineWidth: 1.4)

            // Menu / Options
            circle(168, 96, 9, fill: .clear, stroke: p.controlStroke)
            for y in [93.5, 96.0, 98.5] {
                var line = Path()
                line.move(to: CGPoint(x: 164.5, y: y))
                line.addLine(to: CGPoint(x: 171.5, y: y))
                ctx.stroke(line, with: .color(p.controlStroke), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            }
            circle(212, 96, 9, fill: .clear, stroke: p.controlStroke)
            ctx.stroke(Path(roundedRect: CGRect(x: 208.5, y: 92.5, width: 5, height: 5), cornerRadius: 1),
                       with: .color(p.controlStroke), lineWidth: 1.3)
            let innerSquare = Path(roundedRect: CGRect(x: 210.5, y: 94.5, width: 5, height: 5), cornerRadius: 1)
            ctx.fill(innerSquare, with: .color(p.bodyFill))
            ctx.stroke(innerSquare, with: .color(p.controlStroke), lineWidth: 1.3)

            // Face buttons
            let faces: [(String, CGFloat, CGFloat)] = [("Y", 285, 84), ("B", 309, 108), ("A", 285, 132), ("X", 261, 108)]
            for (letter, fx, fy) in faces {
                circle(fx, fy, 13.5, fill: p.controlFill, stroke: p.bodyStroke)
                ctx.draw(Text(letter).font(.system(size: 13, weight: .semibold)).foregroundColor(p.letter),
                         at: CGPoint(x: fx, y: fy))
            }
        }
        .aspectRatio(380 / 248, contentMode: .fit)
    }
}
