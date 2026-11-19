import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// Behind PAVE's screen while knopmodus is on: what the camera sees, nearly see-through, so iOS treats PAVE as a
/// camera app and sends it the Camera Control button; and the catcher for full presses of that button.
struct PaveCameraControlSurface: UIViewRepresentable {
    let camera: CameraControlSession
    let onPress: () -> Void

    func makeUIView(context: Context) -> SurfaceView {
        let view = SurfaceView(layer: camera.makePreviewLayer())
        // Below 0.01 UIKit treats a view as hidden, and a hidden or untouchable view gets no button events; behind
        // the screen it still takes no taps from PAVE's buttons.
        view.alpha = 0.02
        view.isUserInteractionEnabled = true
        let interaction = AVCaptureEventInteraction { event in
            if event.phase == .ended { context.coordinator.onPress() }
        }
        view.addInteraction(interaction)
        return view
    }

    func updateUIView(_ view: SurfaceView, context: Context) {
        context.coordinator.onPress = onPress
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPress: onPress)
    }

    final class Coordinator {
        var onPress: () -> Void
        init(onPress: @escaping () -> Void) { self.onPress = onPress }
    }

    final class SurfaceView: UIView {
        private let preview: AVCaptureVideoPreviewLayer

        init(layer: AVCaptureVideoPreviewLayer) {
            preview = layer
            super.init(frame: .zero)
            self.layer.addSublayer(layer)
        }

        required init?(coder: NSCoder) { nil }

        override func layoutSubviews() {
            super.layoutSubviews()
            preview.frame = bounds
        }
    }
}
