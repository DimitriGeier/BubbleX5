import RealityKit
import Foundation
import SwiftUI
import Combine

@MainActor
class BubbleSpawner: ObservableObject {
    private let xApiClient = XAPIClient()
    private var spawnTimer: Timer?
    private var tweetQueue: [Tweet] = []
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
            let userId = "44196397"
            let tweets = try await xApiClient.fetchTimeline(userId: userId, maxResults: 20)
            tweetQueue = tweets
            print("✅ Loaded \(tweets.count) tweets")
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

    private func generateSampleTweets() -> [Tweet] {
        return (1...20).map { i in
            Tweet(
                id: "\(i)",
                text: "Sample tweet #\(i): This is a test message for BubbleX AR experience",
                authorId: "sample_user",
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
        }
    }

    deinit {
        spawnTimer?.invalidate()
        spawnTimer = nil
    }
}
