import RealityKit
import CoreHaptics

struct GestureSystem: System {

    static let query = EntityQuery(where: .has(DraggableComponent.self))

    private var hapticEngine: CHHapticEngine?

    init(scene: Scene) {
        setupHaptics()
    }

    mutating func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine creation error: \(error)")
        }
    }

    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let draggable = entity.components[DraggableComponent.self] else { continue }

            if draggable.isDragging {

            }
        }
    }

    func triggerHaptic(intensity: Float = 0.7, sharpness: Float = 0.5) {
        guard let engine = hapticEngine else { return }

        let hapticEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: [hapticEvent], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Haptic playback error: \(error)")
        }
    }
}

extension GestureSystem {
    static func registerSystem() {
        GestureSystemComponent.registerComponent()
        SystemRegistration.register(GestureSystem.self)
    }
}

struct GestureSystemComponent: Component {

}
