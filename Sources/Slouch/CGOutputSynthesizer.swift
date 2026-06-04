import CoreGraphics
import AppKit
import SlouchCore

final class CGOutputSynthesizer: OutputSynthesizer {
    private var downButtons: Set<MouseButton> = []
    private var scrollResidualX: Double = 0
    private var scrollResidualY: Double = 0

    func perform(_ command: SynthCommand) {
        switch command {
        case let .moveMouse(dx, dy): moveMouse(dx: dx, dy: dy)
        case let .scroll(dx, dy): scroll(dx: dx, dy: dy)
        case let .mouseDown(button): mouseButton(button, down: true)
        case let .mouseUp(button): mouseButton(button, down: false)
        case let .keyDown(stroke): key(stroke, down: true)
        case let .keyUp(stroke): key(stroke, down: false)
        case .openURL, .sleep, .keyboardViewer: break // handled by SystemActions, not the synthesizer
        }
    }

    private func currentLocation() -> CGPoint {
        // CGEvent uses top-left origin; NSEvent.mouseLocation is bottom-left.
        let p = NSEvent.mouseLocation
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: p.x, y: screenHeight - p.y)
    }

    private func clampToScreens(_ p: CGPoint) -> CGPoint {
        guard let main = NSScreen.screens.first else { return p }
        let h = main.frame.height
        let bounds = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        let x = min(max(p.x, bounds.minX), bounds.maxX - 1)
        // Convert union bounds (bottom-left) to top-left for clamping y.
        let topY = h - bounds.maxY
        let bottomY = h - bounds.minY
        let y = min(max(p.y, topY), bottomY - 1)
        return CGPoint(x: x, y: y)
    }

    private func moveMouse(dx: Double, dy: Double) {
        let from = currentLocation()
        let to = clampToScreens(CGPoint(x: from.x + dx, y: from.y + dy))
        let isDragging = downButtons.contains(.left)
        let type: CGEventType = isDragging ? .leftMouseDragged : .mouseMoved
        let button: CGMouseButton = .left
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: to, mouseButton: button)
        event?.post(tap: .cghidEventTap)
    }

    private func scroll(dx: Double, dy: Double) {
        scrollResidualY += dy
        scrollResidualX += dx
        let wheelY = scrollResidualY.rounded(.towardZero)
        let wheelX = scrollResidualX.rounded(.towardZero)
        scrollResidualY -= wheelY
        scrollResidualX -= wheelX
        guard wheelY != 0 || wheelX != 0 else { return }
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2,
                            wheel1: Int32(wheelY), wheel2: Int32(wheelX), wheel3: 0)
        event?.post(tap: .cghidEventTap)
    }

    private func mouseButton(_ button: MouseButton, down: Bool) {
        if down { downButtons.insert(button) } else { downButtons.remove(button) }
        let location = currentLocation()
        let (type, cgButton): (CGEventType, CGMouseButton)
        switch button {
        case .left: type = down ? .leftMouseDown : .leftMouseUp; cgButton = .left
        case .right: type = down ? .rightMouseDown : .rightMouseUp; cgButton = .right
        case .middle: type = down ? .otherMouseDown : .otherMouseUp; cgButton = .center
        }
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: cgButton)
        event?.post(tap: .cghidEventTap)
    }

    private func cgFlags(_ mods: ModifierFlags) -> CGEventFlags {
        var flags: CGEventFlags = []
        if mods.contains(.command) { flags.insert(.maskCommand) }
        if mods.contains(.shift) { flags.insert(.maskShift) }
        if mods.contains(.option) { flags.insert(.maskAlternate) }
        if mods.contains(.control) { flags.insert(.maskControl) }
        return flags
    }

    // Real modifier key events (not just flags on the main key) — system-wide
    // hotkeys like the ⌥⌘F5 accessibility toggle ignore flag-only synthesis.
    private static let modifierKeyCodes: [(ModifierFlags, CGKeyCode)] = [
        (.control, 59), (.option, 58), (.shift, 56), (.command, 55),
    ]

    // Standalone modifier keys (bindable as the main key, e.g. hold-to-talk
    // on right Option). The NX_DEVICE…KEYMASK bit is what lets apps tell
    // left from right.
    private static let standaloneModifierFlags: [UInt16: CGEventFlags] = [
        58: CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | 0x20), // left ⌥
        61: CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | 0x40), // right ⌥
    ]

    private func key(_ stroke: KeyStroke, down: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        let flags = cgFlags(stroke.modifiers)
        if let modifierFlags = Self.standaloneModifierFlags[stroke.keyCode] {
            let e = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: down)
            e?.type = .flagsChanged
            e?.flags = down ? flags.union(modifierFlags) : flags
            e?.post(tap: .cghidEventTap)
            return
        }
        if down {
            var accumulated: CGEventFlags = []
            for (mod, code) in Self.modifierKeyCodes where stroke.modifiers.contains(mod) {
                accumulated.insert(cgFlags(mod))
                let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
                e?.type = .flagsChanged
                e?.flags = accumulated
                e?.post(tap: .cghidEventTap)
            }
        }
        let event = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: down)
        event?.flags = flags
        event?.post(tap: .cghidEventTap)
        if !down {
            var remaining = flags
            for (mod, code) in Self.modifierKeyCodes.reversed() where stroke.modifiers.contains(mod) {
                remaining.remove(cgFlags(mod))
                let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
                e?.type = .flagsChanged
                e?.flags = remaining
                e?.post(tap: .cghidEventTap)
            }
        }
    }
}
