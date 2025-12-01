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
    @State private var rootEntity: Entity?
    @State private var showDebugOverlay = true
    @State private var entityCount = 0
    @State private var lastUpdateTime: Date?

    var body: some View {
        TimelineView(.animation) { timeline in
            ZStack {
                RealityView { content in
                print("🔵 RealityView initializing...")

                BubbleMovementComponent.registerComponent()
                OrbitComponent.registerComponent()
                BuoyancyComponent.registerComponent()
                DraggableComponent.registerComponent()

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

                    spawner.onBubbleCreated = { [weak root] bubble in
                        root?.addChild(bubble)
                        entityCount += 1
                    }

                    await spawner.startSpawning(userPosition: userPosition)
                    print("🎬 Bubble spawning started")
                }
            } update: { content in
                guard let root = rootEntity else { return }

                let now = timeline.date
                let deltaTime: Float
                if let last = lastUpdateTime {
                    deltaTime = Float(now.timeIntervalSince(last))
                } else {
                    deltaTime = 1.0 / 60.0
                }
                lastUpdateTime = now

                for entity in root.children {
                    guard let entity = entity as? BubbleEntity else { continue }
                    guard var movement = entity.components[BubbleMovementComponent.self] else { continue }

                    if movement.isApproaching && !movement.hasReachedOrbit {
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
                            let orbitSpeed: Float = (2.0 * .pi) / 15.0

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

                    if var orbit = entity.components[OrbitComponent.self] {
                        orbit.angle += orbit.speed * deltaTime

                        let newX = orbit.center.x + orbit.radius * cos(orbit.angle)
                        let newZ = orbit.center.z + orbit.radius * sin(orbit.angle)

                        entity.position = SIMD3<Float>(newX, orbit.center.y, newZ)

                        entity.components[OrbitComponent.self] = orbit
                    }
                }
            }

            VStack {
                HStack {
                    Spacer()
                    if showDebugOverlay {
                        ARDebugOverlay()
                            .padding()
                    }
                }
                Spacer()
            }
            }
            .onDisappear {
                spawner.stopSpawning()
            }
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
