import RealityKit

struct BuoyancySystem: System {

    static let query = EntityQuery(where: .has(BuoyancyComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var buoyancy = entity.components[BuoyancyComponent.self] else { continue }

            buoyancy.elapsedTime += deltaTime

            let offset = sin(buoyancy.frequency * buoyancy.elapsedTime + buoyancy.phase) * buoyancy.amplitude

            if let draggable = entity.components[DraggableComponent.self], !draggable.isDragging {
                entity.position.y += offset * deltaTime
            }

            entity.components[BuoyancyComponent.self] = buoyancy
        }
    }
}

extension BuoyancySystem {
    static func registerSystem() {
        BuoyancySystemComponent.registerComponent()
        SystemRegistration.register(BuoyancySystem.self)
    }
}

struct BuoyancySystemComponent: Component {

}
