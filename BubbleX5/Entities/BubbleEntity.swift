import RealityKit
import SwiftUI

class BubbleEntity: Entity, @unchecked Sendable {

    var radius: Float
    var tweetText: String
    var velocity: SIMD3<Float> = .zero
    var textOrbitAngle: Float = 0.0
    var textRingContainer: Entity?

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
        let container = Entity()
        container.name = "TextRingContainer"

        let orbitRadius = radius + 0.15
        let characters = Array(tweetText.prefix(50).reversed())

        guard !characters.isEmpty else { return container }

        let angleStep = (2.0 * .pi) / Float(characters.count)

        for (index, char) in characters.enumerated() {
            let angle = Float(index) * angleStep

            let charEntity = Entity()

            let x = orbitRadius * cos(angle)
            let z = orbitRadius * sin(angle)
            charEntity.position = [x, 0, z]

            let charMesh = MeshResource.generateText(
                String(char),
                extrusionDepth: 0.01,
                font: .systemFont(ofSize: 0.04),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byClipping
            )

            var textMaterial = UnlitMaterial()
            textMaterial.color = .init(tint: .white)

            charEntity.components.set(ModelComponent(mesh: charMesh, materials: [textMaterial]))
            charEntity.components.set(BillboardComponent())

            container.addChild(charEntity)
        }

        self.textRingContainer = container

        return container
    }

    func updateTextOrbit(deltaTime: Float) {
        guard let container = textRingContainer else { return }

        textOrbitAngle -= 0.15 * deltaTime

        container.orientation = simd_quatf(angle: textOrbitAngle, axis: [0, 1, 0])
    }
}
