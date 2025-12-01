import SwiftUI

struct DebugPanelView: View {
    @Environment(\.dismiss) var dismiss

    @State private var bubbleCount = 5
    @State private var buoyancyEnabled = true
    @State private var orbitEnabled = false
    @State private var hapticEnabled = true
    @State private var handTrackingStatus = "Active"

    var body: some View {
        NavigationStack {
            Form {
                Section("Bubble Settings") {
                    Stepper("Bubble Count: \(bubbleCount)", value: $bubbleCount, in: 1...20)

                    Toggle("Buoyancy Effect", isOn: $buoyancyEnabled)
                    Toggle("Orbit Mode", isOn: $orbitEnabled)
                }

                Section("Interaction") {
                    Toggle("Haptic Feedback", isOn: $hapticEnabled)

                    HStack {
                        Text("Hand Tracking")
                        Spacer()
                        Text(handTrackingStatus)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("X API") {
                    Button("Configure Bearer Token") {

                    }

                    Button("Fetch Timeline") {

                    }
                    .disabled(true)
                }

                Section {
                    Button("Reset Scene", role: .destructive) {

                    }
                }
            }
            .navigationTitle("Debug Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
