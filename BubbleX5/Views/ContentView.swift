import SwiftUI
import RealityKit

struct ContentView: View {
    @Binding var immersiveSpaceIsShown: Bool
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    @State private var showDebugPanel = false
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 30) {
            Text("BubbleX")
                .font(.system(size: 48, weight: .bold, design: .rounded))

            Text("Floating X Feeds in AR")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button {
                Task {
                    isLoading = true
                    if immersiveSpaceIsShown {
                        await dismissImmersiveSpace()
                        immersiveSpaceIsShown = false
                    } else {
                        await openImmersiveSpace(id: "BubbleXSpace")
                        immersiveSpaceIsShown = true
                    }
                    isLoading = false
                }
            } label: {
                Label(
                    immersiveSpaceIsShown ? "Exit AR" : "Enter AR",
                    systemImage: immersiveSpaceIsShown ? "xmark.circle.fill" : "arkit"
                )
                .font(.title2)
            }
            .disabled(isLoading)
            .buttonStyle(.borderedProminent)
            .tint(immersiveSpaceIsShown ? .red : .blue)

            if immersiveSpaceIsShown {
                Button {
                    showDebugPanel.toggle()
                } label: {
                    Label("Debug", systemImage: "ladybug")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .sheet(isPresented: $showDebugPanel) {
            DebugPanelView()
        }
    }
}

struct ImmersiveSpaceView: View {
    var body: some View {
        RealityView { content in
            print("🔵 RealityView content closure started")

            BuoyancySystem.registerSystem()
            OrbitSystem.registerSystem()
            GestureSystem.registerSystem()

            print("✅ Systems registered")

            let rootEntity = Entity()
            rootEntity.name = "BubbleXRoot"
            content.add(rootEntity)

            let pointLight = PointLight()
            pointLight.light.intensity = 1000
            pointLight.light.attenuationRadius = 5.0
            pointLight.position = [0, 0.5, -0.5]
            rootEntity.addChild(pointLight)

            print("💡 Light added")

            Task {
                print("🔄 Creating bubbles...")
                for i in 0..<BubbleXConstants.Scene.defaultBubbleCount {
                    let bubble = await BubbleEntity.create(
                        position: .randomInZone(
                            min: BubbleXConstants.Scene.spawnZoneMin,
                            max: BubbleXConstants.Scene.spawnZoneMax
                        ),
                        radius: Float.random(in: BubbleXConstants.Bubble.minRadius...BubbleXConstants.Bubble.maxRadius),
                        tweetText: "Sample tweet \(i + 1)"
                    )
                    print("  ✅ Bubble \(i + 1) created at \(bubble.position)")
                    rootEntity.addChild(bubble)
                }
                print("🎉 All \(BubbleXConstants.Scene.defaultBubbleCount) bubbles created!")
            }
        }
    }
}
