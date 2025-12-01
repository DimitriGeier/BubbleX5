import Foundation
import RealityKit

struct BubbleXConstants {

    struct Bubble {
        static let minRadius: Float = 0.05
        static let maxRadius: Float = 0.2
        static let defaultRadius: Float = 0.1

        static let minBuoyancyAmplitude: Float = 0.03
        static let maxBuoyancyAmplitude: Float = 0.2

        static let minBuoyancyFrequency: Float = 0.3
        static let maxBuoyancyFrequency: Float = 2.0

        static let defaultOpacity: Float = 0.65
        static let defaultRoughness: Float = 0.1
        static let defaultMetallic: Float = 0.8
    }

    struct Interaction {
        static let pinchThreshold: Float = 0.02
        static let grabThreshold: Float = 0.05
        static let pointThreshold: Float = 0.1

        static let dragSmoothingFactor: Float = 0.15
        static let velocityDamping: Float = 0.95
    }

    struct Scene {
        static let spawnZoneMin = SIMD3<Float>(-1.0, -0.5, -1.5)
        static let spawnZoneMax = SIMD3<Float>(1.0, 0.5, -0.5)

        static let maxBubbles = 20
        static let defaultBubbleCount = 5

        static let environmentLightIntensity: Float = 1.0
        static let ambientLightIntensity: Float = 0.3
    }

    struct API {
        static let baseURL = "https://api.twitter.com/2"
        static let maxTweetsPerRequest = 10
        static let timeoutInterval: TimeInterval = 30

        static let keychainAccount = "XAPIBearerToken"
        static let keychainService = "com.bubblex.xapi"
    }

    struct SharePlay {
        static let activityIdentifier = "com.bubblex.shareplay"
        static let maxParticipants = 8
        static let syncInterval: TimeInterval = 0.1
    }

    struct Haptics {
        static let selectionIntensity: Float = 0.6
        static let selectionSharpness: Float = 0.4

        static let impactIntensity: Float = 0.8
        static let impactSharpness: Float = 0.7

        static let successIntensity: Float = 0.7
        static let successSharpness: Float = 0.3
    }

    struct Animation {
        static let defaultDuration: TimeInterval = 0.3
        static let springDuration: TimeInterval = 0.6
        static let springResponse: Double = 0.5
        static let springDampingFraction: Double = 0.7
    }
}

extension SIMD3 where Scalar == Float {
    static func random(in range: ClosedRange<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(
            Float.random(in: range),
            Float.random(in: range),
            Float.random(in: range)
        )
    }

    static func randomInZone(min: SIMD3<Float>, max: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(
            Float.random(in: min.x...max.x),
            Float.random(in: min.y...max.y),
            Float.random(in: min.z...max.z)
        )
    }

    var magnitude: Float {
        return sqrt(x * x + y * y + z * z)
    }

    func normalized() -> SIMD3<Float> {
        let mag = magnitude
        return mag > 0 ? self / mag : .zero
    }
}

extension Color {
    static func randomHue(saturation: Double = 0.7, brightness: Double = 0.9) -> Color {
        return Color(hue: Double.random(in: 0...1), saturation: saturation, brightness: brightness)
    }
}
