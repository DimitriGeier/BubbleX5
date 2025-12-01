import UIKit
import CoreHaptics
import Combine

@MainActor
class HapticFeedbackManager: ObservableObject {
    private var engine: CHHapticEngine?

    init() {
        prepareHaptics()
        setupNotificationObservers()
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("⚠️ Device does not support haptics")
            return
        }

        do {
            engine = try CHHapticEngine()
            try engine?.start()
            print("✅ Haptic engine started")
        } catch {
            print("❌ Failed to start haptic engine: \(error.localizedDescription)")
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBubbleSpawned),
            name: .bubbleSpawned,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBubbleEnteredOrbit),
            name: .bubbleEnteredOrbit,
            object: nil
        )
    }

    @objc private func handleBubbleSpawned() {
        playSpawnHaptic()
    }

    @objc private func handleBubbleEnteredOrbit() {
        playOrbitTransitionHaptic()
    }

    func playSpawnHaptic() {
        guard let engine = engine else { return }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)

        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity, sharpness],
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("❌ Failed to play spawn haptic: \(error.localizedDescription)")
        }
    }

    func playOrbitTransitionHaptic() {
        guard let engine = engine else { return }

        let intensity1 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
        let sharpness1 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)

        let intensity2 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9)
        let sharpness2 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)

        let event1 = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity1, sharpness1],
            relativeTime: 0
        )

        let event2 = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity2, sharpness2],
            relativeTime: 0.1
        )

        do {
            let pattern = try CHHapticPattern(events: [event1, event2], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("❌ Failed to play orbit transition haptic: \(error.localizedDescription)")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
