import RealityKit
import ARKit
import QuartzCore

@MainActor
class HandGestureRecognizer: @unchecked Sendable {

    enum GestureType {
        case waveLeft
        case waveRight
        case waveAway
        case waveToward
        case fingerBeckon
        case pinch
        case pinchEnded
        case unknown
    }

    struct HandState {
        var palmPosition: SIMD3<Float>
        var palmNormal: SIMD3<Float>
        var indexTipPosition: SIMD3<Float>
        var indexKnucklePosition: SIMD3<Float>
        var thumbTipPosition: SIMD3<Float>
        var wristPosition: SIMD3<Float>
        var velocity: SIMD3<Float> = .zero
        var previousPosition: SIMD3<Float>?
        var chirality: HandAnchor.Chirality
        var timestamp: TimeInterval
        var isPinching: Bool = false
    }

    private var arkitSession: ARKitSession?
    private var handTracking: HandTrackingProvider?

    var leftHandState: HandState?
    var rightHandState: HandState?

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
        print("👋 Setting up hand tracking...")
        arkitSession = ARKitSession()
        handTracking = HandTrackingProvider()

        Task {
            do {
                if HandTrackingProvider.isSupported {
                    print("✅ Hand tracking is supported, starting session...")
                    try await arkitSession?.run([handTracking!])
                    print("✅ Hand tracking session started successfully")
                } else {
                    print("❌ Hand tracking is NOT supported on this device")
                }
            } catch {
                print("❌ Hand tracking setup error: \(error)")
            }
        }
    }

    func updateGestures() async {
        guard let handTracking = handTracking else {
            print("❌ No hand tracking provider available")
            return
        }

        print("👋 Starting gesture update loop...")

        for await update in handTracking.anchorUpdates {
            let anchor = update.anchor

            switch update.event {
            case .added, .updated:
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

        let wrist = skeleton.joint(.wrist)
        let middleMetacarpal = skeleton.joint(.middleFingerMetacarpal)
        let indexTip = skeleton.joint(.indexFingerTip)
        let indexKnuckle = skeleton.joint(.indexFingerKnuckle)
        let thumbTip = skeleton.joint(.thumbTip)

        let wristPos = extractPosition(from: wrist.anchorFromJointTransform)
        let palmPos = extractPosition(from: middleMetacarpal.anchorFromJointTransform)
        let indexTipPos = extractPosition(from: indexTip.anchorFromJointTransform)
        let indexKnucklePos = extractPosition(from: indexKnuckle.anchorFromJointTransform)
        let thumbTipPos = extractPosition(from: thumbTip.anchorFromJointTransform)

        let palmToFingers = normalize(indexTipPos - palmPos)
        let palmToThumb = normalize(thumbTipPos - palmPos)
        let palmNormal = normalize(cross(palmToFingers, palmToThumb))

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

        let pinchDistance = distance(indexTipPos, thumbTipPos)
        let isPinching = pinchDistance < 0.03
        let wasPinching = anchor.chirality == .left ? leftHandState?.isPinching ?? false : rightHandState?.isPinching ?? false

        let handState = HandState(
            palmPosition: palmPos,
            palmNormal: palmNormal,
            indexTipPosition: indexTipPos,
            indexKnucklePosition: indexKnucklePos,
            thumbTipPosition: thumbTipPos,
            wristPosition: wristPos,
            velocity: velocity,
            previousPosition: anchor.chirality == .left ? leftHandState?.palmPosition : rightHandState?.palmPosition,
            chirality: anchor.chirality,
            timestamp: currentTime,
            isPinching: isPinching
        )

        if isPinching && !wasPinching {
            triggerGesture(.pinch, chirality: anchor.chirality, position: indexTipPos)
        } else if !isPinching && wasPinching {
            triggerGesture(.pinchEnded, chirality: anchor.chirality, position: indexTipPos)
        }

        if anchor.chirality == .left {
            leftHandState = handState
        } else {
            rightHandState = handState
        }

        detectGestures(handState: handState)
    }

    private func detectGestures(handState: HandState) {
        let velocity = handState.velocity
        let speed = length(velocity)

        guard speed > 0.1 else { return }

        let leftVelocity = dot(velocity, SIMD3<Float>(-1, 0, 0))
        let rightVelocity = dot(velocity, SIMD3<Float>(1, 0, 0))
        let awayVelocity = dot(velocity, SIMD3<Float>(0, 0, -1))
        let towardVelocity = dot(velocity, SIMD3<Float>(0, 0, 1))

        if leftVelocity > velocityThreshold {
            triggerGesture(.waveLeft, chirality: handState.chirality, position: handState.palmPosition)
        } else if rightVelocity > velocityThreshold {
            triggerGesture(.waveRight, chirality: handState.chirality, position: handState.palmPosition)
        } else if awayVelocity > waveAwayThreshold {
            triggerGesture(.waveAway, chirality: handState.chirality, position: handState.palmPosition)
        } else if towardVelocity > waveTowardThreshold {
            triggerGesture(.waveToward, chirality: handState.chirality, position: handState.palmPosition)
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
        let handString = chirality == .left ? "LEFT" : "RIGHT"

        switch gesture {
        case .waveLeft:
            print("✅ WAVE LEFT DETECTED - \(handString) hand")
        case .waveRight:
            print("✅ WAVE RIGHT DETECTED - \(handString) hand")
        case .waveAway:
            print("✅ WAVE AWAY DETECTED - \(handString) hand")
        case .waveToward:
            print("✅ WAVE TOWARD DETECTED - \(handString) hand")
        case .fingerBeckon:
            print("✅ FINGER BECKON DETECTED - \(handString) hand")
        case .pinch:
            print("✅ PINCH DETECTED - \(handString) hand")
        case .pinchEnded:
            print("✅ PINCH ENDED - \(handString) hand")
        case .unknown:
            print("✅ UNKNOWN gesture - \(handString) hand")
        }

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
