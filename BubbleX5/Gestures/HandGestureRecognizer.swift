import RealityKit
import ARKit

@MainActor
class HandGestureRecognizer: @unchecked Sendable {

    enum GestureType {
        case pinch
        case grab
        case point
        case unknown
    }

    private var arkitSession: ARKitSession?
    private var handTracking: HandTrackingProvider?

    var onGestureDetected: ((GestureType, SIMD3<Float>) -> Void)?

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

                if anchor.chirality == .right {
                    processHandGesture(anchor)
                }

            case .removed:
                break
            }
        }
    }

    private func processHandGesture(_ anchor: HandAnchor) {
        guard let thumbTip = anchor.handSkeleton?.joint(.thumbTip),
              let indexTip = anchor.handSkeleton?.joint(.indexFingerTip) else {
            return
        }

        let thumbPos = SIMD3<Float>(
            thumbTip.anchorFromJointTransform.columns.3.x,
            thumbTip.anchorFromJointTransform.columns.3.y,
            thumbTip.anchorFromJointTransform.columns.3.z
        )

        let indexPos = SIMD3<Float>(
            indexTip.anchorFromJointTransform.columns.3.x,
            indexTip.anchorFromJointTransform.columns.3.y,
            indexTip.anchorFromJointTransform.columns.3.z
        )

        let distance = simd_distance(thumbPos, indexPos)

        if distance < 0.02 {
            onGestureDetected?(.pinch, indexPos)
        } else if distance > 0.1 {
            onGestureDetected?(.point, indexPos)
        }
    }

    func cleanup() {
        arkitSession?.stop()
        arkitSession = nil
        handTracking = nil
    }
}
