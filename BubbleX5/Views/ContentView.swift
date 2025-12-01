import SwiftUI
import RealityKit
import ARKit

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
    @StateObject private var spawner = BubbleSpawner()
    @StateObject private var hapticManager = HapticFeedbackManager()
    @StateObject private var debugViewModel = DebugViewModel()
    @State private var rootEntity: Entity?
    @State private var showDebugOverlay = true
    @State private var entityCount = 0
    @State private var lastUpdateTime: Date?
    @State private var gestureRecognizer: HandGestureRecognizer?

    var body: some View {
        TimelineView(.animation) { timeline in
            ZStack {
                RealityView { content in
                print("🔵 RealityView initializing...")

                BubbleMovementComponent.registerComponent()
                OrbitComponent.registerComponent()
                BuoyancyComponent.registerComponent()
                DraggableComponent.registerComponent()
                GestureComponent.registerComponent()

                print("✅ All components registered")

                let worldAnchor = AnchorEntity(world: .zero)
                worldAnchor.name = "WorldOrigin"
                content.add(worldAnchor)

                let root = Entity()
                root.name = "BubbleXRoot"
                worldAnchor.addChild(root)
                rootEntity = root

                let ambientLight = PointLight()
                ambientLight.light.intensity = 2000
                ambientLight.light.attenuationRadius = 10.0
                ambientLight.position = [0, 2, 0]
                root.addChild(ambientLight)

                print("💡 Lighting setup complete")

                setupEntityCountObserver()

                Task {
                    let userPosition = SIMD3<Float>(0, 1.6, 0)
                    print("👤 [ImmersiveSpaceView] User position set to: \(userPosition)")

                    spawner.onBubbleCreated = { [weak root] bubble in
                        print("🫧 [ImmersiveSpaceView] Bubble created callback - adding to root")
                        root?.addChild(bubble)
                        Task { @MainActor in
                            entityCount += 1
                            print("📊 [ImmersiveSpaceView] Entity count: \(entityCount)")
                        }
                    }

                    print("🚀 [ImmersiveSpaceView] Starting spawner...")
                    await spawner.startSpawning(userPosition: userPosition)
                    print("✅ [ImmersiveSpaceView] Bubble spawning started")

                    let recognizer = HandGestureRecognizer()
                    gestureRecognizer = recognizer

                    recognizer.onGestureDetected = { [weak spawner] gestureType, chirality, position in
                        print("✋ Gesture callback received: \(gestureType) from \(chirality == .left ? "LEFT" : "RIGHT") hand")

                        if gestureType == .waveToward {
                            Task {
                                await handleWaveTowardGesture(spawner: spawner, position: position, root: root)
                            }
                        }
                    }

                    Task {
                        await recognizer.updateGestures()
                    }
                    print("✋ Hand gesture recognition started")
                }
            } update: { content in
                guard let root = rootEntity else { return }

                debugViewModel.updateFrame()

                let now = timeline.date
                let deltaTime: Float
                if let last = lastUpdateTime {
                    deltaTime = Float(now.timeIntervalSince(last))
                } else {
                    deltaTime = 1.0 / 60.0
                }

                DispatchQueue.main.async {
                    lastUpdateTime = now
                    entityCount = root.children.count
                    debugViewModel.entityCount = entityCount
                    debugViewModel.updateBatteryLevel()
                }

                guard !debugViewModel.isPaused else { return }

                for entity in root.children {
                    guard let entity = entity as? BubbleEntity else { continue }

                    entity.updateTextOrbit(deltaTime: deltaTime)

                    let isBeingDragged = EntityGestureState.shared.targetedEntity == entity

                    guard var movement = entity.components[BubbleMovementComponent.self] else { continue }

                    if !isBeingDragged && movement.isApproaching && !movement.hasReachedOrbit {
                        let direction = movement.targetPosition - entity.position
                        let distance = length(direction)

                        if distance > 2.0 {
                            let normalizedDirection = normalize(direction)
                            entity.position += normalizedDirection * movement.speed * deltaTime
                        } else {
                            movement.isApproaching = false
                            movement.hasReachedOrbit = true

                            let orbitCenter = movement.targetPosition
                            let orbitRadius: Float = 2.0
                            let orbitSpeed: Float = -((2.0 * .pi) / 30.0)

                            let startAngle = atan2(entity.position.z - orbitCenter.z, entity.position.x - orbitCenter.x)

                            let orbitComponent = OrbitComponent(
                                center: orbitCenter,
                                radius: orbitRadius,
                                speed: orbitSpeed,
                                angle: startAngle
                            )
                            entity.components.set(orbitComponent)

                            NotificationCenter.default.post(name: .bubbleEnteredOrbit, object: nil)
                        }
                    }

                    entity.components[BubbleMovementComponent.self] = movement

                    if !debugViewModel.reducedMotion && !isBeingDragged, var orbit = entity.components[OrbitComponent.self] {
                        orbit.angle += orbit.speed * deltaTime

                        let newX = orbit.center.x + orbit.radius * cos(orbit.angle)
                        let newZ = orbit.center.z + orbit.radius * sin(orbit.angle)

                        entity.position = SIMD3<Float>(newX, orbit.center.y, newZ)

                        entity.components[OrbitComponent.self] = orbit
                    }
                }
            }
            .installGestures()

            VStack {
                HStack {
                    Spacer()
                    VolumetricDebugPanel(viewModel: debugViewModel)
                        .padding()
                        .allowsHitTesting(true)
                }
                Spacer()
            }
            .allowsHitTesting(true)
            }
            .onDisappear {
                spawner.stopSpawning()
                gestureRecognizer?.cleanup()
            }
        }
    }

    private func handleWaveTowardGesture(spawner: BubbleSpawner?, position: SIMD3<Float>, root: Entity) async {
        print("🌊 Wave Toward gesture triggered - fetching tweet and calling Grok API")

        guard let spawner = spawner else { return }

        do {
            let timeline = try await XAPIClient.shared.fetchHomeTimeline(maxResults: 1)

            guard let latestTweet = timeline.data?.first else {
                print("❌ No tweets found in timeline")
                return
            }

            print("📱 Latest tweet: \(latestTweet.text)")

            let suggestion = try await XAPIClient.shared.summarizeWithGrok(tweetText: latestTweet.text)

            print("✨ Grok Summary: \(suggestion.summary)")
            print("🔍 Queries: \(suggestion.queries)")

            for (index, query) in suggestion.queries.enumerated() {
                let offset: Float = Float(index - 1) * 0.4
                let spawnPosition = SIMD3<Float>(
                    position.x + offset,
                    position.y,
                    position.z - 0.5
                )

                let bubble = spawner.createBubble(at: spawnPosition, targetPosition: spawnPosition, tweetText: query)
                root.addChild(bubble)
                print("🫧 Spawned bubble \(index + 1) with query: \(query)")
            }

        } catch {
            print("❌ Error handling wave toward gesture: \(error)")
        }
    }

    private func setupEntityCountObserver() {
        NotificationCenter.default.addObserver(
            forName: .requestEntityCount,
            object: nil,
            queue: .main
        ) { _ in
            NotificationCenter.default.post(
                name: .updateEntityCount,
                object: nil,
                userInfo: ["count": entityCount]
            )
        }
    }

}
