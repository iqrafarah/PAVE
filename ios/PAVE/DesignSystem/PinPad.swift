import PAVECore
import SwiftUI

struct PinPad: View {
    @Binding var digits: String
    var isError = false
    var keySize: CGFloat = 76
    var biometricKind: BiometricKind?
    var onBiometric: (() -> Void)?
    let onComplete: (String) -> Void

    var body: some View {
        VStack(spacing: keySize * 0.4) {
            PinDots(filled: digits.count, isError: isError)
            PinKeypad(
                keySize: keySize,
                biometricKind: biometricKind,
                onDigit: append,
                onDelete: deleteLast,
                onBiometric: onBiometric
            )
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: digits.count)
    }

    private func append(_ digit: Int) {
        guard digits.count < PinPolicy.length else { return }
        digits.append(String(digit))
        if digits.count == PinPolicy.length {
            onComplete(digits)
        }
    }

    private func deleteLast() {
        guard !digits.isEmpty else { return }
        digits.removeLast()
    }
}

struct PinDots: View {
    let filled: Int
    var isError = false

    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<PinPolicy.length, id: \.self) { index in
                Circle()
                    .fill(index < filled ? tint : .clear)
                    .overlay {
                        Circle().strokeBorder(index < filled ? tint : Color.hairline, lineWidth: 1.5)
                    }
                    .frame(width: 14, height: 14)
            }
        }
        .animation(.easeOut(duration: 0.12), value: filled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PIN")
        .accessibilityValue("\(filled) of \(PinPolicy.length) digits entered")
    }

    private var tint: Color {
        isError ? .critical : .brandGreen
    }
}

struct PinKeypad: View {
    var keySize: CGFloat = 76
    var biometricKind: BiometricKind?
    let onDigit: (Int) -> Void
    let onDelete: () -> Void
    var onBiometric: (() -> Void)?

    private let rows: [[Int]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        Grid(horizontalSpacing: keySize * 0.26, verticalSpacing: keySize * 0.2) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self, content: digitKey)
                }
            }
            GridRow {
                biometricKey
                digitKey(0)
                deleteKey
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func digitKey(_ digit: Int) -> some View {
        Button { onDigit(digit) } label: {
            Text("\(digit)")
                .textStyle(.keypad)
                .foregroundStyle(Color.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .buttonStyle(KeyStyle(size: keySize, filled: true))
    }

    private var deleteKey: some View {
        Button(action: onDelete) {
            Image(systemName: "delete.backward")
                .font(.title3)
                .foregroundStyle(Color.ink)
        }
        .buttonStyle(KeyStyle(size: keySize, filled: false))
        .accessibilityLabel("Delete")
    }

    @ViewBuilder
    private var biometricKey: some View {
        if let biometricKind, let onBiometric {
            Button(action: onBiometric) {
                Image(systemName: biometricKind.symbolName)
                    .font(.title2)
                    .foregroundStyle(Color.brandGreen)
            }
            .buttonStyle(KeyStyle(size: keySize, filled: false))
            .accessibilityLabel("Unlock with \(biometricKind.name)")
        } else {
            Color.clear.frame(width: keySize, height: keySize)
        }
    }
}

private struct KeyStyle: ButtonStyle {
    let size: CGFloat
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background {
                if filled {
                    Circle()
                        .fill(configuration.isPressed ? Color.surfaceTint : .white)
                        .overlay { Circle().strokeBorder(Color.hairline, lineWidth: 1) }
                }
            }
            .contentShape(.circle)
            .opacity(!filled && configuration.isPressed ? 0.5 : 1)
    }
}

#Preview {
    @Previewable @State var digits = "48"
    PinPad(digits: $digits, biometricKind: .faceID, onBiometric: {}) { _ in }
        .padding(32)
        .background(Color.canvas)
}
