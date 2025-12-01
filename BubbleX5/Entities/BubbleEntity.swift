import RealityKit
import SwiftUI

class BubbleEntity: Entity, @unchecked Sendable {

    var radius: Float
    var tweetText: String
    var velocity: SIMD3<Float> = .zero

    required init() {
        self.radius = BubbleXConstants.Bubble.defaultRadius
        self.tweetText = ""
        super.init()
    }

    init(radius: Float, tweetText: String) {
        self.radius = radius
        self.tweetText = tweetText
        super.init()
    }

    static func create(
        position: SIMD3<Float>,
        radius: Float,
        tweetText: String
    ) async -> BubbleEntity {
        let bubble = BubbleEntity(radius: radius, tweetText: tweetText)
        bubble.position = position

        let mesh = MeshResource.generateSphere(radius: radius)

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(
            tint: .init(
                hue: Double.random(in: 0...1),
                saturation: 0.7,
                brightness: 0.9, alpha: 1.0
            )
        )
        material.roughness = .init(floatLiteral: BubbleXConstants.Bubble.defaultRoughness)
        material.metallic = .init(floatLiteral: BubbleXConstants.Bubble.defaultMetallic)
        material.blending = .transparent(opacity: .init(floatLiteral: BubbleXConstants.Bubble.defaultOpacity))

        let modelComponent = ModelComponent(
            mesh: mesh,
            materials: [material]
        )
        bubble.components.set(modelComponent)

        let collision = CollisionComponent(shapes: [.generateSphere(radius: radius)])
        bubble.components.set(collision)

        let input = InputTargetComponent(allowedInputTypes: .indirect)
        bubble.components.set(input)

        let buoyancy = BuoyancyComponent(
            amplitude: Float.random(in: BubbleXConstants.Bubble.minBuoyancyAmplitude...BubbleXConstants.Bubble.maxBuoyancyAmplitude),
            frequency: Float.random(in: BubbleXConstants.Bubble.minBuoyancyFrequency...BubbleXConstants.Bubble.maxBuoyancyFrequency),
            phase: Float.random(in: 0...(.pi * 2))
        )
        bubble.components.set(buoyancy)

        let draggable = DraggableComponent(isDragging: false, dragOffset: .zero)
        bubble.components.set(draggable)

        let billboard = BillboardComponent()
        bubble.components.set(billboard)

        return bubble
    }

    func addTextLabel() -> Entity {
        let textEntity = Entity()
        textEntity.position = [0, radius + 0.05, 0]

        let textMesh = MeshResource.generateText(
            tweetText,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.05),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )

        var textMaterial = UnlitMaterial()
        textMaterial.color = .init(tint: .white)

        textEntity.components.set(ModelComponent(mesh: textMesh, materials: [textMaterial]))
        textEntity.components.set(BillboardComponent())

        return textEntity
    }
}
