import SwiftUI

/// The edge of the chats column on a wide screen: drag it to make the column wider or narrower, as on the web. VoiceOver
/// can change the width step by step. The width is remembered on this device.
struct AylaColumnResizeHandle: View {
    @Binding var width: Double

    static let range: ClosedRange<Double> = 240...460
    @State private var startWidth: Double?
    @State private var isDragging = false

    var body: some View {
        Capsule()
            .fill(isDragging ? Color.paveAccentFill : Color.hairline)
            .frame(width: 4, height: 40)
            .opacity(isDragging ? 1 : 0.8)
            .frame(width: 20)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .hoverEffect(.highlight)
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { value in
                        if startWidth == nil {
                            startWidth = width
                            isDragging = true
                            PaveHaptics.selection()
                        }
                        let next = (startWidth ?? width) + value.translation.width
                        let clamped = min(max(next, Self.range.lowerBound), Self.range.upperBound)
                        if clamped != next, clamped != width { PaveHaptics.tap(.light) }
                        width = clamped
                    }
                    .onEnded { _ in
                        startWidth = nil
                        isDragging = false
                    }
            )
            .animation(.easeOut(duration: 0.15), value: isDragging)
            .accessibilityElement()
            .accessibilityLabel(AylaMessages.panelResize)
            .accessibilityValue("\(Int(width)) punten breed")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: width = min(width + 30, Self.range.upperBound)
                case .decrement: width = max(width - 30, Self.range.lowerBound)
                @unknown default: break
                }
            }
    }
}
