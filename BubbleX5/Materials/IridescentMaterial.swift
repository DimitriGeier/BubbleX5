import RealityKit
import SwiftUI

struct IridescentMaterial {

    static func create(baseHue: Double = 0.6) -> RealityKit.Material {
        var material = PhysicallyBasedMaterial()

        material.baseColor = .init(
            tint: .init(
                hue: baseHue,
                saturation: 0.8,
                brightness: 0.95, alpha: 1.0
            )
        )

        material.roughness = .init(floatLiteral: 0.05)

        material.metallic = .init(floatLiteral: 0.9)

        material.blending = .transparent(opacity: .init(floatLiteral: 0.75))

        material.faceCulling = .none

        material.emissiveColor = .init(
            color: .init(
                hue: baseHue,
                saturation: 0.6,
                brightness: 0.4, alpha: 1.0
            )
        )
        material.emissiveIntensity = 0.3

        return material
    }

    static func createShimmering(phase: Float = 0.0) -> RealityKit.Material {
        let hue = Double((sin(phase) + 1.0) / 2.0)
        return create(baseHue: hue)
    }

    static func rainbow() -> [RealityKit.Material] {
        var materials: [RealityKit.Material] = []

        for i in 0..<7 {
            let hue = Double(i) / 7.0
            materials.append(create(baseHue: hue))
        }

        return materials
    }
}
