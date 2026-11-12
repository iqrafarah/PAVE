import SwiftUI

/// A square checkbox from Figma: the accent colour with a white tick when on, a grey outline when off.
struct PaveCheckbox: View {
    let isOn: Bool
    var size: CGFloat = 18

    var body: some View {
        Group {
            if isOn {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.paveAccent)
                    Path { path in
                        path.move(to: CGPoint(x: size * 4 / 18, y: size * 9.2 / 18))
                        path.addLine(to: CGPoint(x: size * 6.857 / 18, y: size * 12 / 18))
                        path.addLine(to: CGPoint(x: size * 14 / 18, y: size * 5 / 18))
                    }
                    .stroke(Color.white, style: StrokeStyle(lineWidth: size * 1.8 / 18, lineCap: .round, lineJoin: .round))
                }
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.checkboxBorder, lineWidth: size >= 18 ? 1.5 : 1.3)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 20) {
        PaveCheckbox(isOn: true)
        PaveCheckbox(isOn: false)
        PaveCheckbox(isOn: false, size: 15)
    }
    .padding()
}
