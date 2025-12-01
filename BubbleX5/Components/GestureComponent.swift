import RealityKit
import SwiftUI

public struct GestureComponent: Component, Codable {

    public var canDrag: Bool = true
    public var canScale: Bool = false
    public var canRotate: Bool = false
    public var pivotOnDrag: Bool = true
    public var preserveOrientationOnPivotDrag: Bool = true

    public init(canDrag: Bool = true, canScale: Bool = false, canRotate: Bool = false) {
        self.canDrag = canDrag
        self.canScale = canScale
        self.canRotate = canRotate
    }
}

public class EntityGestureState {

    var targetedEntity: Entity?

    var dragStartPosition: SIMD3<Float> = .zero
    var isDragging = false
    var pivotEntity: Entity?
    var initialOrientation: simd_quatf?

    var startScale: SIMD3<Float> = .one
    var isScaling = false

    var startOrientation = simd_quatf.init(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    var isRotating = false

    static let shared = EntityGestureState()
}

extension GestureComponent {

    func onDragChanged(value: EntityTargetValue<DragGesture.Value>) {
        guard canDrag else { return }
        let entity = value.entity
        let state = EntityGestureState.shared

        if state.targetedEntity == nil {
            state.targetedEntity = entity
            state.dragStartPosition = entity.position(relativeTo: nil)
            state.initialOrientation = entity.orientation(relativeTo: nil)
            state.isDragging = true
            print("🎯 Started dragging entity")
        }

        guard state.targetedEntity == entity else { return }

        let translation3D = value.convert(value.translation3D, from: .local, to: .scene)
        let translation = SIMD3<Float>(
            Float(translation3D.x),
            Float(translation3D.y),
            Float(translation3D.z)
        )

        entity.position = state.dragStartPosition + translation
    }

    func onDragEnded(value: EntityTargetValue<DragGesture.Value>) {
        guard canDrag else { return }
        let state = EntityGestureState.shared

        if state.targetedEntity == value.entity {
            print("🎯 Ended dragging entity")
            state.targetedEntity = nil
            state.isDragging = false
        }
    }

    func onScaleChanged(value: EntityTargetValue<MagnifyGesture.Value>) {
        guard canScale else { return }
        let entity = value.entity
        let state = EntityGestureState.shared

        if !state.isScaling {
            state.startScale = entity.scale
            state.isScaling = true
        }

        let magnification = Float(value.magnification)
        entity.scale = state.startScale * magnification
    }

    func onScaleEnded(value: EntityTargetValue<MagnifyGesture.Value>) {
        guard canScale else { return }
        EntityGestureState.shared.isScaling = false
    }

    func onRotateChanged(value: EntityTargetValue<RotateGesture3D.Value>) {
        guard canRotate else { return }
        let entity = value.entity
        let state = EntityGestureState.shared

        if !state.isRotating {
            state.startOrientation = entity.orientation(relativeTo: nil)
            state.isRotating = true
        }

        let rotation = value.rotation
        let flippedRotation = Rotation3D(
            angle: rotation.angle,
            axis: RotationAxis3D(x: -rotation.axis.x, y: rotation.axis.y, z: -rotation.axis.z)
        )
        let newOrientation = state.startOrientation.rotated(by: flippedRotation)
        entity.setOrientation(.init(newOrientation), relativeTo: nil)
    }

    func onRotateEnded(value: EntityTargetValue<RotateGesture3D.Value>) {
        guard canRotate else { return }
        EntityGestureState.shared.isRotating = false
    }
}

extension Entity {
    func rotated(by rotation: Rotation3D) -> simd_quatf {
        let currentOrientation = self.orientation(relativeTo: nil)
        return currentOrientation.rotated(by: rotation)
    }
}

extension simd_quatf {
    func rotated(by rotation: Rotation3D) -> simd_quatf {
        let rotationQuat = simd_quatf(angle: Float(rotation.angle.radians), axis: SIMD3<Float>(
            Float(rotation.axis.x),
            Float(rotation.axis.y),
            Float(rotation.axis.z)
        ))
        return rotationQuat * self
    }
}
