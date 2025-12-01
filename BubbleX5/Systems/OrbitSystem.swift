import RealityKit

struct OrbitSystem: System {

    static let query = EntityQuery(where: .has(OrbitComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var orbit = entity.components[OrbitComponent.self] else { continue }

            orbit.angle += orbit.speed * deltaTime

            let x = orbit.center.x + orbit.radius * cos(orbit.angle)
            let z = orbit.center.z + orbit.radius * sin(orbit.angle)

            entity.position.x = x
            entity.position.z = z

            entity.components[OrbitComponent.self] = orbit
        }
    }
}

extension OrbitSystem {
    static func registerSystem() {
        OrbitSystemComponent.registerComponent()
        SystemRegistration.register(OrbitSystem.self)
    }
}

struct OrbitSystemComponent: Component {

}
