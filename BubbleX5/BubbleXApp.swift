import SwiftUI
import os

@main
struct BubbleXApp: App {

    @State private var immersiveSpaceIsShown = false
    @StateObject private var sharePlayManager = SharePlayManager()

    init() {
        setupApp()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(immersiveSpaceIsShown: $immersiveSpaceIsShown)
                .environmentObject(sharePlayManager)
        }

        ImmersiveSpace(id: "BubbleXSpace") {
            ImmersiveSpaceView()
                .environmentObject(sharePlayManager)
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }

    private func setupApp() {
        guard VisionOSConfiguration.checkCompatibility() else {
            Logger.app.critical("BubbleX requires visionOS 2.0 or later")
            return
        }

        Logger.app.info("BubbleX initialized successfully")
        Logger.app.debug("\(VisionOSConfiguration.features.debugDescription)")
    }
}
