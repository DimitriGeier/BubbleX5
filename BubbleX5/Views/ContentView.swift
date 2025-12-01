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
    @State private var bubbleEntities: [BubbleEntity] = []

    var body: some View {
        RealityView { content in
            let rootEntity = Entity()
            content.add(rootEntity)

            await initializeBubbleSystem(root: rootEntity)

            if let ibl = try? await EnvironmentResource(named: "ImageBasedLight") {
                let iblComponent = ImageBasedLightComponent(
                    source: .single(ibl),
                    intensityExponent: 1.0
                )
                rootEntity.components[ImageBasedLightComponent.self] = iblComponent
            }
        }
    }

    private func initializeBubbleSystem(root: Entity) async {
        BuoyancySystem.registerSystem()
        OrbitSystem.registerSystem()
        GestureSystem.registerSystem()

        for i in 0..<BubbleXConstants.Scene.defaultBubbleCount {
            let bubble = await BubbleEntity.create(
                position: .randomInZone(
                    min: BubbleXConstants.Scene.spawnZoneMin,
                    max: BubbleXConstants.Scene.spawnZoneMax
                ),
                radius: Float.random(in: BubbleXConstants.Bubble.minRadius...BubbleXConstants.Bubble.maxRadius),
                tweetText: "Sample tweet \(i + 1)"
            )
            root.addChild(bubble)
            bubbleEntities.append(bubble)
        }
    }
}
