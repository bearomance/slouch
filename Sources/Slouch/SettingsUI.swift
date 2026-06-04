import SwiftUI

enum ChipColor {
    case blue, green, gray, graphite, orange, red, purple, indigo, teal, pink

    var gradient: LinearGradient {
        let (top, bottom): (Color, Color) = switch self {
        case .blue: (Color(red: 0.23, green: 0.61, blue: 1.0), Color(red: 0.04, green: 0.47, blue: 0.94))
        case .green: (Color(red: 0.27, green: 0.82, blue: 0.38), Color(red: 0.14, green: 0.69, blue: 0.27))
        case .gray: (Color(red: 0.60, green: 0.60, blue: 0.64), Color(red: 0.49, green: 0.49, blue: 0.52))
        case .graphite: (Color(red: 0.44, green: 0.44, blue: 0.47), Color(red: 0.33, green: 0.33, blue: 0.36))
        case .orange: (Color(red: 1.0, green: 0.68, blue: 0.23), Color(red: 0.98, green: 0.55, blue: 0.06))
        case .red: (Color(red: 1.0, green: 0.42, blue: 0.37), Color(red: 0.95, green: 0.23, blue: 0.19))
        case .purple: (Color(red: 0.69, green: 0.42, blue: 1.0), Color(red: 0.55, green: 0.24, blue: 0.94))
        case .indigo: (Color(red: 0.43, green: 0.48, blue: 1.0), Color(red: 0.28, green: 0.33, blue: 0.94))
        case .teal: (Color(red: 0.24, green: 0.79, blue: 0.90), Color(red: 0.10, green: 0.66, blue: 0.80))
        case .pink: (Color(red: 1.0, green: 0.48, blue: 0.69), Color(red: 0.96, green: 0.28, blue: 0.56))
        }
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }
}

struct IconChip: View {
    let color: ChipColor
    let symbol: String

    var body: some View {
        RoundedRectangle(cornerRadius: 6.5, style: .continuous)
            .fill(color.gradient)
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }
    }
}

/// Standard settings row: icon chip + title/subtitle on the left, control on
/// the right. Mirrors the System Settings row anatomy from the design.
struct SettingsRow<Control: View>: View {
    let color: ChipColor
    let symbol: String
    let title: String
    var subtitle: String?
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(spacing: 11) {
            IconChip(color: color, symbol: symbol)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(.vertical, 2)
    }
}

/// NSTextField wrapper whose only reason to exist is refusesFirstResponder:
/// the field never receives focus automatically (window open, Tab, popover
/// dismissal) — only an explicit click starts editing. SwiftUI's TextField
/// has no such switch, and clearing focus after the fact flashes the ring.
struct ClickToEditTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder = ""
    var alignment: NSTextAlignment = .natural
    var onEndEditing: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.refusesFirstResponder = true
        field.bezelStyle = .roundedBezel
        field.alignment = alignment
        field.placeholderString = placeholder.isEmpty ? nil : placeholder
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.currentEditor() == nil, field.stringValue != text {
            field.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ClickToEditTextField
        init(_ parent: ClickToEditTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
            parent.onEndEditing()
        }
    }
}

/// Slider + editable number field + stepper, the Sensitivity control combo.
struct SliderInputRow<F: ParseableFormatStyle>: View
where F.FormatInput == Double, F.FormatOutput == String {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: F

    @State private var text = ""

    var body: some View {
        HStack(spacing: 10) {
            Slider(value: $value, in: range)
                .controlSize(.small)
                .frame(width: 190)
            ClickToEditTextField(text: $text, alignment: .center, onEndEditing: commit)
                .frame(width: 56)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
        .onAppear { text = format.format(value) }
        .onChange(of: value) { _, newValue in text = format.format(newValue) }
    }

    /// Validation happens only on ⏎ or focus loss — never mid-typing.
    private func commit() {
        if let parsed = try? format.parseStrategy.parse(text) {
            value = min(max(parsed, range.lowerBound), range.upperBound)
        }
        text = format.format(value)
    }
}
