import RealityKit
import Foundation
import SwiftUI
import Combine

@MainActor
class BubbleSpawner: ObservableObject {
    private let xApiClient = XAPIClient.shared
    private var spawnTimer: Timer?
    private var tweetQueue: [XTweet] = []
    private var spawnInterval: TimeInterval = 3.0

    @Published var isSpawning = false
    private(set) var spawnedCount = 0

    var onBubbleCreated: ((BubbleEntity) -> Void)?

    func startSpawning(userPosition: SIMD3<Float>) async {
        guard !isSpawning else { return }
        isSpawning = true

        await loadTweets()

        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.spawnNextBubble(userPosition: userPosition)
            }
        }
    }

    func stopSpawning() {
        isSpawning = false
        spawnTimer?.invalidate()
        spawnTimer = nil
    }

    private func loadTweets() async {
        do {
            let response = try await xApiClient.fetchHomeTimeline(maxResults: 20)
            tweetQueue = response.data ?? []
            print("✅ Loaded \(tweetQueue.count) tweets")
        } catch {
            print("⚠️ Failed to load tweets: \(error). Using sample data.")
            tweetQueue = generateSampleTweets()
        }
    }

    private func spawnNextBubble(userPosition: SIMD3<Float>) async {
        guard !tweetQueue.isEmpty else {
            await loadTweets()
            return
        }

        let tweet = tweetQueue.removeFirst()

        let spawnPosition = userPosition + SIMD3<Float>(0, 0, -5.0)

        let bubble = await BubbleEntity.create(
            position: spawnPosition,
            radius: Float.random(in: BubbleXConstants.Bubble.minRadius...BubbleXConstants.Bubble.maxRadius),
            tweetText: tweet.text
        )

        let textLabel = bubble.addTextLabel()
        bubble.addChild(textLabel)

        let movementComponent = BubbleMovementComponent(
            targetPosition: userPosition,
            speed: 0.075
        )
        bubble.components.set(movementComponent)

        spawnedCount += 1

        onBubbleCreated?(bubble)

        NotificationCenter.default.post(name: .bubbleSpawned, object: nil)

        print("🫧 Spawned bubble #\(spawnedCount) at \(spawnPosition) -> target: \(userPosition)")
        print("   Distance to target: \(length(userPosition - spawnPosition))")
    }

    private func generateSampleTweets() -> [XTweet] {
        return (1...20).map { i in
            XTweet(
                id: "\(i)",
                text: "Sample tweet #\(i): This is a test message for BubbleX AR experience",
                authorId: "sample_user",
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
        }
    }

    func createBubble(at position: SIMD3<Float>, targetPosition: SIMD3<Float>, tweetText: String) -> BubbleEntity {
        let bubble = BubbleEntity()
        bubble.position = position

        let radius = Float.random(in: BubbleXConstants.Bubble.minRadius...BubbleXConstants.Bubble.maxRadius)

        let sphereMesh = MeshResource.generateSphere(radius: radius)
        let material = IridescentMaterial.create()

        let modelComponent = ModelComponent(
            mesh: sphereMesh,
            materials: [material]
        )

        bubble.components.set(modelComponent)

        let textLabel = bubble.addTextLabel()
        textLabel.position = [0, radius + 0.05, 0]
        bubble.addChild(textLabel)

        let movementComponent = BubbleMovementComponent(
            targetPosition: targetPosition,
            speed: 0.075
        )
        bubble.components.set(movementComponent)

        let buoyancyComponent = BuoyancyComponent(
            amplitude: Float.random(in: BubbleXConstants.Bubble.minBuoyancyAmplitude...BubbleXConstants.Bubble.maxBuoyancyAmplitude),
            frequency: Float.random(in: BubbleXConstants.Bubble.minBuoyancyFrequency...BubbleXConstants.Bubble.maxBuoyancyFrequency),
            phase: Float.random(in: 0...(2 * .pi))
        )
        bubble.components.set(buoyancyComponent)

        let orbitComponent = OrbitComponent(
            center: targetPosition,
            radius: 0.5,
            speed: 1.0,
            angle: Float.random(in: 0...(2 * .pi))
        )
        bubble.components.set(orbitComponent)

        spawnedCount += 1
        print("🫧 Created bubble #\(spawnedCount) with text: \(tweetText)")

        return bubble
    }

    deinit {
        spawnTimer?.invalidate()
        spawnTimer = nil
    }
}
