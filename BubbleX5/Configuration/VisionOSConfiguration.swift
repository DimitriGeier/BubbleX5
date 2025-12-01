import Foundation
import os

enum VisionOSVersion {
    case v2
    case v3
    case unknown

    static var current: VisionOSVersion {
        let info = ProcessInfo.processInfo
        // Check for visionOS 3.0 or later
        if info.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 3, minorVersion: 0, patchVersion: 0)) {
            return .v3
        }
        // Check for visionOS 2.0 or later
        if info.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 2, minorVersion: 0, patchVersion: 0)) {
            return .v2
        }
        return .unknown
    }
}

struct VisionOSConfiguration {

    static let minimumVersion = "2.0"
    static let targetVersion = "3.0"

    static var isVisionOS3Available: Bool {
        if #available(visionOS 3.0, *) { return true }
        return false
    }

    static func checkCompatibility() -> Bool {
        guard VisionOSVersion.current != .unknown else {
            Logger.app.error("Unsupported visionOS version detected")
            return false
        }

        Logger.app.info("Running on visionOS \(VisionOSVersion.current == .v3 ? "3.0+" : "2.0+")")
        return true
    }

    static var features: FeatureFlags {
        FeatureFlags(
            advancedHandTracking: isVisionOS3Available,
            enhancedSceneUnderstanding: isVisionOS3Available,
            multiUserSupport: isVisionOS3Available,
            spatialAudio: true,
            hapticsSupport: true
        )
    }
}

struct FeatureFlags {
    let advancedHandTracking: Bool
    let enhancedSceneUnderstanding: Bool
    let multiUserSupport: Bool
    let spatialAudio: Bool
    let hapticsSupport: Bool

    var debugDescription: String {
        """
        Feature Flags:
        - Advanced Hand Tracking: \(advancedHandTracking)
        - Enhanced Scene Understanding: \(enhancedSceneUnderstanding)
        - Multi-User Support: \(multiUserSupport)
        - Spatial Audio: \(spatialAudio)
        - Haptics Support: \(hapticsSupport)
        """
    }
}

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.bubblex"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let ar = Logger(subsystem: subsystem, category: "ar")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let gesture = Logger(subsystem: subsystem, category: "gesture")
}
