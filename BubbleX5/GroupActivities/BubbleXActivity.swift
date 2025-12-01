import GroupActivities
import Foundation

struct BubbleXActivity: GroupActivity {
    static let activityIdentifier = "com.bubblex.shareplay"

    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "BubbleX AR Session"
        meta.subtitle = "Experience floating X feeds together"
        meta.type = .generic
        meta.supportsContinuationOnTV = false
        return meta
    }
}

@MainActor
class SharePlayManager: ObservableObject {

    @Published var isSharePlayActive = false
    @Published var participants: [Participant] = []

    private var tasks = Set<Task<Void, Never>>()
    private var groupSession: GroupSession<BubbleXActivity>?
    private var messenger: GroupSessionMessenger?

    init() {
        setupSessionObserver()
    }

    private func setupSessionObserver() {
        let task = Task {
            for await session in BubbleXActivity.sessions() {
                await configureGroupSession(session)
            }
        }
        tasks.insert(task)
    }

    private func configureGroupSession(_ session: GroupSession<BubbleXActivity>) async {
        groupSession = session
        messenger = GroupSessionMessenger(session: session)

        session.join()

        isSharePlayActive = true

        for await state in session.$state.values {
            if case .invalidated = state {
                cleanup()
            }
        }
    }

    func startSharing() async {
        do {
            _ = try await BubbleXActivity().activate()
        } catch {
            print("Failed to activate SharePlay: \(error)")
        }
    }

    func sendBubbleUpdate(position: SIMD3<Float>, bubbleId: String) {
        guard let messenger = messenger else { return }

        let message = BubbleUpdate(bubbleId: bubbleId, position: position)

        Task {
            do {
                try await messenger.send(message)
            } catch {
                print("Failed to send bubble update: \(error)")
            }
        }
    }

    private func cleanup() {
        isSharePlayActive = false
        participants.removeAll()
        groupSession = nil
        messenger = nil
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }
}

struct BubbleUpdate: Codable {
    let bubbleId: String
    let position: SIMD3<Float>
}

extension SIMD3: Codable where Scalar: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(Scalar.self)
        let y = try container.decode(Scalar.self)
        let z = try container.decode(Scalar.self)
        self.init(x, y, z)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.x)
        try container.encode(self.y)
        try container.encode(self.z)
    }
}
