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
    @State private var gestureRecognizer: HandGestureRecognizer?
    @State private var grabbedBubble: BubbleEntity?
    @State private var grabChirality: HandAnchor.Chirality?

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
                        Task { @MainActor in
                            entityCount += 1
                        }
                    }

                    await spawner.startSpawning(userPosition: userPosition)
                    print("🎬 Bubble spawning started")

                    let recognizer = HandGestureRecognizer()
                    gestureRecognizer = recognizer

                    recognizer.onGestureDetected = { [weak root] gestureType, chirality, position in
                        Task { @MainActor in
                            handleGesture(gestureType, chirality: chirality, position: position, root: root)
                        }
                    }

                    Task {
                        await recognizer.updateGestures()
                    }
                    print("✋ Hand gesture recognition started")
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

                DispatchQueue.main.async {
                    lastUpdateTime = now
                }

                for entity in root.children {
                    guard let entity = entity as? BubbleEntity else { continue }

                    entity.updateTextOrbit(deltaTime: deltaTime)

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

                    if let grabbed = grabbedBubble, grabbed == entity {
                        if let recognizer = gestureRecognizer {
                            let handState = grabChirality == .left ? recognizer.leftHandState : recognizer.rightHandState
                            if let state = handState {
                                entity.position = state.indexTipPosition
                            }
                        }
                    } else if var orbit = entity.components[OrbitComponent.self] {
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
                gestureRecognizer?.cleanup()
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

    private func handleGesture(_ gestureType: HandGestureRecognizer.GestureType, chirality: HandAnchor.Chirality, position: SIMD3<Float>, root: Entity?) {
        guard let root = root else { return }

        switch gestureType {
        case .pinch:
            if grabbedBubble == nil {
                let closestBubble = findClosestBubble(to: position, in: root)
                if let bubble = closestBubble {
                    grabbedBubble = bubble
                    grabChirality = chirality
                    print("🫧 Grabbed bubble at distance: \(distance(bubble.position, position))")
                }
            }

        case .pinchEnded:
            if grabChirality == chirality {
                if let bubble = grabbedBubble {
                    print("🫧 Released bubble")
                }
                grabbedBubble = nil
                grabChirality = nil
            }

        default:
            break
        }
    }

    private func findClosestBubble(to position: SIMD3<Float>, in root: Entity) -> BubbleEntity? {
        var closestBubble: BubbleEntity?
        var closestDistance: Float = 0.3

        for entity in root.children {
            guard let bubble = entity as? BubbleEntity else { continue }
            let dist = distance(bubble.position, position)
            if dist < closestDistance {
                closestDistance = dist
                closestBubble = bubble
            }
        }

        return closestBubble
    }
}
