import RealityKit

struct OrbitComponent: Component, Codable, Sendable {
    var center: SIMD3<Float>
    var radius: Float
    var speed: Float
    var angle: Float

    init(center: SIMD3<Float> = .zero, radius: Float = 0.5, speed: Float = 1.0, angle: Float = 0.0) {
        self.center = center
        self.radius = radius
        self.speed = speed
        self.angle = angle
    }
}
