import SwiftUI

/// While the Camera Control button steers PAVE: a small badge that says so (the camera is on for it, records
/// nothing) and stops it with one tap.
struct PaveCameraControlBadge: View {
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text("Knopmodus")
                .textStyle(.meta)
                .foregroundStyle(Color.ink)
            Button("Stop", action: onStop)
                .textStyle(.label)
                .foregroundStyle(Color.paveAccent)
                .buttonStyle(.pave)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Knopmodus staat aan. De cameraknop bedient PAVE.")
        .accessibilityAction(named: "Stop") { onStop() }
    }
}
