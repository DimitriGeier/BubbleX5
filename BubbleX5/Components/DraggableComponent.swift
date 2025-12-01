import RealityKit

struct DraggableComponent: Component, Codable, Sendable {
    var isDragging: Bool
    var dragOffset: SIMD3<Float>
    var originalPosition: SIMD3<Float> = .zero

    init(isDragging: Bool = false, dragOffset: SIMD3<Float> = .zero) {
        self.isDragging = isDragging
        self.dragOffset = dragOffset
    }
}
