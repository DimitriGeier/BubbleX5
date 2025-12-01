import RealityKit
import ARKit

@MainActor
class HandGestureRecognizer: @unchecked Sendable {

    enum GestureType {
        case waveLeft
        case waveRight
        case waveAway
        case waveToward
        case fingerBeckon
        case unknown
    }

    struct HandState {
        var palmPosition: SIMD3<Float>
        var palmNormal: SIMD3<Float>
        var indexTipPosition: SIMD3<Float>
        var indexKnucklePosition: SIMD3<Float>
        var wristPosition: SIMD3<Float>
        var velocity: SIMD3<Float> = .zero
        var previousPosition: SIMD3<Float>?
        var chirality: HandAnchor.Chirality
        var timestamp: TimeInterval
    }

    private var arkitSession: ARKitSession?
    private var handTracking: HandTrackingProvider?

    private var leftHandState: HandState?
    private var rightHandState: HandState?

    private let velocityThreshold: Float = 0.3
    private let waveAwayThreshold: Float = 0.25
    private let waveTowardThreshold: Float = 0.25
    private let beckonThreshold: Float = 0.02

    private var beckonCycleCount: Int = 0
    private var lastBeckonTime: TimeInterval = 0
    private let beckonCooldown: TimeInterval = 0.3

    var onGestureDetected: ((GestureType, HandAnchor.Chirality, SIMD3<Float>) -> Void)?

    init() {
        setupHandTracking()
    }

    private func setupHandTracking() {
        arkitSession = ARKitSession()
        handTracking = HandTrackingProvider()

        Task {
            do {
                if HandTrackingProvider.isSupported {
                    try await arkitSession?.run([handTracking!])
                }
            } catch {
                print("Hand tracking setup error: \(error)")
            }
        }
    }

    func updateGestures() async {
        guard let handTracking = handTracking else { return }

        for await update in handTracking.anchorUpdates {
            switch update.event {
            case .added, .updated:
                let anchor = update.anchor
                processHandAnchor(anchor)

            case .removed:
                if anchor.chirality == .left {
                    leftHandState = nil
                } else if anchor.chirality == .right {
                    rightHandState = nil
                }
            }
        }
    }

    private func processHandAnchor(_ anchor: HandAnchor) {
        guard let skeleton = anchor.handSkeleton else { return }

        guard let wrist = skeleton.joint(.wrist),
              let middleMetacarpal = skeleton.joint(.middleFingerMetacarpal),
              let indexTip = skeleton.joint(.indexFingerTip),
              let indexKnuckle = skeleton.joint(.indexFingerKnuckle) else {
            return
        }

        let wristPos = extractPosition(from: wrist.anchorFromJointTransform)
        let palmPos = extractPosition(from: middleMetacarpal.anchorFromJointTransform)
        let indexTipPos = extractPosition(from: indexTip.anchorFromJointTransform)
        let indexKnucklePos = extractPosition(from: indexKnuckle.anchorFromJointTransform)

        let palmToWrist = normalize(wristPos - palmPos)
        let palmNormal = palmToWrist

        let currentTime = CACurrentMediaTime()

        var velocity: SIMD3<Float> = .zero
        if anchor.chirality == .left, let previous = leftHandState {
            let deltaTime = Float(currentTime - previous.timestamp)
            if deltaTime > 0 {
                velocity = (palmPos - previous.palmPosition) / deltaTime
            }
        } else if anchor.chirality == .right, let previous = rightHandState {
            let deltaTime = Float(currentTime - previous.timestamp)
            if deltaTime > 0 {
                velocity = (palmPos - previous.palmPosition) / deltaTime
            }
        }

        let handState = HandState(
            palmPosition: palmPos,
            palmNormal: palmNormal,
            indexTipPosition: indexTipPos,
            indexKnucklePosition: indexKnucklePos,
            wristPosition: wristPos,
            velocity: velocity,
            previousPosition: anchor.chirality == .left ? leftHandState?.palmPosition : rightHandState?.palmPosition,
            chirality: anchor.chirality,
            timestamp: currentTime
        )

        if anchor.chirality == .left {
            leftHandState = handState
        } else {
            rightHandState = handState
        }

        detectGestures(handState: handState)
    }

    private func detectGestures(handState: HandState) {
        let palmNormal = handState.palmNormal
        let velocity = handState.velocity
        let speed = length(velocity)

        let forwardDot = dot(palmNormal, SIMD3<Float>(0, 0, -1))
        let isPalmForward = forwardDot > 0.5

        let cameraDot = dot(palmNormal, SIMD3<Float>(0, 0, 1))
        let isPalmTowardCamera = cameraDot > 0.5

        if isPalmForward && speed > velocityThreshold {
            let leftVelocity = dot(velocity, SIMD3<Float>(-1, 0, 0))
            let rightVelocity = dot(velocity, SIMD3<Float>(1, 0, 0))

            if leftVelocity > velocityThreshold {
                triggerGesture(.waveLeft, chirality: handState.chirality, position: handState.palmPosition)
            } else if rightVelocity > velocityThreshold {
                triggerGesture(.waveRight, chirality: handState.chirality, position: handState.palmPosition)
            }
        }

        if isPalmTowardCamera {
            let awayVelocity = dot(velocity, SIMD3<Float>(0, 0, -1))
            let towardVelocity = dot(velocity, SIMD3<Float>(0, 0, 1))

            if awayVelocity > waveAwayThreshold {
                triggerGesture(.waveAway, chirality: handState.chirality, position: handState.palmPosition)
            } else if towardVelocity > waveTowardThreshold {
                triggerGesture(.waveToward, chirality: handState.chirality, position: handState.palmPosition)
            }
        }

        detectFingerBeckon(handState: handState)
    }

    private func detectFingerBeckon(handState: HandState) {
        let palmUp = dot(handState.palmNormal, SIMD3<Float>(0, 1, 0)) > 0.5

        guard palmUp else {
            beckonCycleCount = 0
            return
        }

        let fingerCurlDistance = distance(handState.indexTipPosition, handState.indexKnucklePosition)
        let isCurled = fingerCurlDistance < beckonThreshold

        let currentTime = CACurrentMediaTime()

        if isCurled && (currentTime - lastBeckonTime) > beckonCooldown {
            beckonCycleCount += 1
            lastBeckonTime = currentTime

            if beckonCycleCount >= 2 {
                triggerGesture(.fingerBeckon, chirality: handState.chirality, position: handState.palmPosition)
                beckonCycleCount = 0
            }
        }
    }

    private func triggerGesture(_ gesture: GestureType, chirality: HandAnchor.Chirality, position: SIMD3<Float>) {
        onGestureDetected?(gesture, chirality, position)

        NotificationCenter.default.post(
            name: .gestureDetected,
            object: nil,
            userInfo: ["gestureType": gesture, "chirality": chirality]
        )
    }

    private func extractPosition(from transform: simd_float4x4) -> SIMD3<Float> {
        return SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }

    func cleanup() {
        arkitSession?.stop()
        arkitSession = nil
        handTracking = nil
        leftHandState = nil
        rightHandState = nil
    }
}

extension Notification.Name {
    static let gestureDetected = Notification.Name("gestureDetected")
}
