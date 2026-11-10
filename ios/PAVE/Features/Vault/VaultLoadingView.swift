import SwiftUI

/// Grey shapes where the folders and cards will appear, so nothing jumps when the vault has loaded.
struct VaultLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDimmed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 9) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16).fill(Color.tileFill).frame(width: 140, height: 100)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            RoundedRectangle(cornerRadius: 10).fill(Color.tileFill).frame(width: 220, height: 44)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16).fill(Color.tileFill).frame(height: 190)
                }
            }
        }
        .opacity(isDimmed ? 0.55 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever()) { isDimmed = true }
        }
        .accessibilityElement()
        .accessibilityLabel("Je kluis wordt geladen")
    }
}

#Preview {
    VaultLoadingView()
        .padding(20)
}
