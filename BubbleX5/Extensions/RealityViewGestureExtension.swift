import SwiftUI
import RealityKit

extension RealityView {

    var dragGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                guard let gestureComponent = value.entity.components[GestureComponent.self] else { return }
                gestureComponent.onDragChanged(value: value)
            }
            .onEnded { value in
                guard let gestureComponent = value.entity.components[GestureComponent.self] else { return }
                gestureComponent.onDragEnded(value: value)
            }
    }

    var magnifyGesture: some Gesture {
        MagnifyGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                guard let gestureComponent = value.entity.components[GestureComponent.self] else { return }
                gestureComponent.onScaleChanged(value: value)
            }
            .onEnded { value in
                guard let gestureComponent = value.entity.components[GestureComponent.self] else { return }
                gestureComponent.onScaleEnded(value: value)
            }
    }

    var rotateGesture: some Gesture {
        RotateGesture3D()
            .targetedToAnyEntity()
            .onChanged { value in
                guard let gestureComponent = value.entity.components[GestureComponent.self] else { return }
                gestureComponent.onRotateChanged(value: value)
            }
            .onEnded { value in
                guard let gestureComponent = value.entity.components[GestureComponent.self] else { return }
                gestureComponent.onRotateEnded(value: value)
            }
    }

    func installGestures() -> some View {
        self
            .gesture(dragGesture)
            .simultaneousGesture(magnifyGesture)
            .simultaneousGesture(rotateGesture)
    }
}
