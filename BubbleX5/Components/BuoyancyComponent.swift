import RealityKit

struct BuoyancyComponent: Component, Codable, Sendable {
    var amplitude: Float
    var frequency: Float
    var phase: Float
    var elapsedTime: Float = 0.0

    init(amplitude: Float = 0.1, frequency: Float = 1.0, phase: Float = 0.0) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
    }
}
