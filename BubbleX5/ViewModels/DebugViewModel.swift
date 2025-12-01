import SwiftUI
import Combine

@MainActor
class DebugViewModel: ObservableObject {
    @Published var isPaused = false
    @Published var fps: Double = 0
    @Published var entityCount = 0
    @Published var batteryLevel: Float = 0
    @Published var reducedMotion = false
    @Published var showNiceList = false
    @Published var showNaughtyList = false

    private var fpsUpdateTimer: Timer?
    private var lastFrameTime = Date()
    private var frameCount = 0

    init() {
        updateBatteryLevel()
        startFPSTracking()
    }

    func startFPSTracking() {
        fpsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            let elapsed = now.timeIntervalSince(self.lastFrameTime)
            if elapsed > 0 {
                self.fps = Double(self.frameCount) / elapsed
            }
            self.lastFrameTime = now
            self.frameCount = 0
        }
    }

    func updateFrame() {
        frameCount += 1
    }

    func updateBatteryLevel() {
        #if os(visionOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel
        #endif
    }

    func togglePause() {
        isPaused.toggle()
    }

    func toggleReducedMotion() {
        reducedMotion.toggle()
    }
}
