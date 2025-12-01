import RealityKit

struct BubbleMovementSystem: System {

    static let query = EntityQuery(where: .has(BubbleMovementComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var movement = entity.components[BubbleMovementComponent.self] else { continue }

            if movement.isApproaching && !movement.hasReachedOrbit {
                let direction = movement.targetPosition - entity.position
                let distance = length(direction)

                if distance > 2.0 {
                    let normalizedDirection = normalize(direction)
                    entity.position += normalizedDirection * movement.speed * deltaTime
                } else {
                    movement.isApproaching = false
                    movement.hasReachedOrbit = true

                    let orbitCenter = movement.targetPosition
                    let orbitRadius: Float = 2.0
                    let orbitSpeed: Float = (2.0 * .pi) / 15.0

                    let startAngle = atan2(entity.position.z - orbitCenter.z, entity.position.x - orbitCenter.x)

                    let orbitComponent = OrbitComponent(
                        center: orbitCenter,
                        radius: orbitRadius,
                        speed: orbitSpeed,
                        angle: startAngle
                    )
                    entity.components.set(orbitComponent)

                    NotificationCenter.default.post(name: .bubbleEnteredOrbit, object: nil)
                }
            }

            entity.components[BubbleMovementComponent.self] = movement
        }
    }
}

extension BubbleMovementSystem {
    static func registerSystem() {
        BubbleMovementComponent.registerComponent()
        OrbitComponent.registerComponent()
    }
}

extension Notification.Name {
    static let bubbleEnteredOrbit = Notification.Name("bubbleEnteredOrbit")
    static let bubbleSpawned = Notification.Name("bubbleSpawned")
}
