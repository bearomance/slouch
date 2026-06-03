import SwiftUI
import SlouchCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Sensitivity") {
                LabeledContent("Cursor speed") {
                    Slider(value: $model.config.settings.cursorSpeed, in: 400...3000)
                }
                LabeledContent("Scroll speed") {
                    Slider(value: $model.config.settings.scrollSpeed, in: 5...80)
                }
                LabeledContent("Dead zone") {
                    Slider(value: $model.config.settings.deadZone, in: 0...0.5)
                }
            }
            Section("Sticks") {
                Picker("Right stick", selection: $model.config.mapping.rightStick) {
                    Text("Move mouse").tag(StickRole.mouseMove)
                    Text("Scroll").tag(StickRole.scroll)
                    Text("Off").tag(StickRole.none)
                }
                Picker("Left stick", selection: $model.config.mapping.leftStick) {
                    Text("Move mouse").tag(StickRole.mouseMove)
                    Text("Scroll").tag(StickRole.scroll)
                    Text("Off").tag(StickRole.none)
                }
            }
            // The "Buttons" section is added in Task 12.
        }
        .padding()
        .frame(width: 420)
    }
}
