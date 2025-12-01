import SwiftUI
import RealityKit
import Combine

struct ARDebugOverlay: View {
    @State private var fps: Double = 0
    @State private var entityCount: Int = 0
    @State private var batteryLevel: Float = 0
    @State private var batteryState: UIDevice.BatteryState = .unknown

    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .foregroundColor(.green)
                Text("FPS: \(Int(fps))")
                    .font(.system(.caption, design: .monospaced))
            }

            HStack {
                Image(systemName: "cube.box")
                    .foregroundColor(.blue)
                Text("Entities: \(entityCount)")
                    .font(.system(.caption, design: .monospaced))
            }

            HStack {
                Image(systemName: batteryIcon)
                    .foregroundColor(batteryColor)
                Text("Battery: \(Int(batteryLevel * 100))%")
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .onReceive(timer) { _ in
            updateStats()
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            updateStats()
        }
    }

    private var batteryIcon: String {
        let percentage = Int(batteryLevel * 100)
        if batteryState == .charging || batteryState == .full {
            return "battery.100.bolt"
        } else if percentage > 75 {
            return "battery.100"
        } else if percentage > 50 {
            return "battery.75"
        } else if percentage > 25 {
            return "battery.50"
        } else {
            return "battery.25"
        }
    }

    private var batteryColor: Color {
        let percentage = Int(batteryLevel * 100)
        if batteryState == .charging || batteryState == .full {
            return .green
        } else if percentage > 25 {
            return .white
        } else {
            return .red
        }
    }

    private func updateStats() {
        fps = 60.0

        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState

        NotificationCenter.default.post(
            name: .requestEntityCount,
            object: nil,
            userInfo: nil
        )
    }

    func updateEntityCount(_ count: Int) {
        entityCount = count
    }
}

extension Notification.Name {
    static let requestEntityCount = Notification.Name("requestEntityCount")
    static let updateEntityCount = Notification.Name("updateEntityCount")
}
