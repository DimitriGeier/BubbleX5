import RealityKit

struct BubbleMovementComponent: Component, Codable, Sendable {
    var targetPosition: SIMD3<Float>
    var speed: Float
    var isApproaching: Bool
    var hasReachedOrbit: Bool

    init(targetPosition: SIMD3<Float>, speed: Float = 0.075) {
        self.targetPosition = targetPosition
        self.speed = speed
        self.isApproaching = true
        self.hasReachedOrbit = false
    }
}
