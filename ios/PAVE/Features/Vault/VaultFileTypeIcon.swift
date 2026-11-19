import SwiftUI

/// A page with the kind of file on it (PDF, DOC, TXT or a photo), drawn like the icons of the web
/// (public/images/vault/files). Shown in the round badge of evidence without a logo.
struct VaultFileTypeIcon: View {
    enum Kind {
        case pdf, word, text, image

        /// By the extension of the file name, as on the web; anything unknown is text.
        init(fileName: String) {
            switch (fileName as NSString).pathExtension.lowercased() {
            case "pdf": self = .pdf
            case "doc", "docx": self = .word
            case "jpg", "jpeg", "png", "heic", "heif", "webp": self = .image
            default: self = .text
            }
        }

        var label: String? {
            switch self {
            case .pdf: "PDF"
            case .word: "DOC"
            case .text: "TXT"
            case .image: nil
            }
        }

        var badge: Color {
            switch self {
            case .pdf: Color(.fileBadgePdf)
            case .word: Color(.fileBadgeWord)
            case .text, .image: Color(.fileBadgeText)
            }
        }
    }

    let kind: Kind
    var size: CGFloat = 26

    var body: some View {
        // Drawn on a 40 × 40 grid, like the SVGs.
        let unit = size / 40
        ZStack(alignment: .topLeading) {
            PageShape()
                .fill(.white)
                .overlay { PageShape().stroke(Color.cardBorder, lineWidth: 1.5 * unit) }
            FoldShape()
                .fill(Color.canvas)
                .overlay { FoldShape().stroke(Color.cardBorder, style: StrokeStyle(lineWidth: 1.5 * unit, lineJoin: .round)) }
            if let label = kind.label {
                Text(label)
                    .font(.system(size: 8.2 * unit, weight: .heavy))
                    .tracking(0.3 * unit)
                    .foregroundStyle(.white)
                    .frame(width: 22 * unit, height: 12 * unit)
                    .background(kind.badge, in: .rect(cornerRadius: 3 * unit))
                    .offset(x: 2 * unit, y: 19 * unit)
            } else {
                Circle()
                    .fill(Color(.fileBadgeSun))
                    .frame(width: 5.2 * unit, height: 5.2 * unit)
                    .offset(x: 11.9 * unit, y: 15.4 * unit)
                MountainShape()
                    .fill(Color(.brandGreen))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private nonisolated struct PageShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 40
        var path = Path()
        path.move(to: CGPoint(x: 9 * u, y: 3 * u))
        path.addLine(to: CGPoint(x: 22.2 * u, y: 3 * u))
        path.addLine(to: CGPoint(x: 31 * u, y: 11.8 * u))
        path.addLine(to: CGPoint(x: 31 * u, y: 33 * u))
        path.addArc(tangent1End: CGPoint(x: 31 * u, y: 36 * u), tangent2End: CGPoint(x: 28 * u, y: 36 * u), radius: 3 * u)
        path.addLine(to: CGPoint(x: 9 * u, y: 36 * u))
        path.addArc(tangent1End: CGPoint(x: 6 * u, y: 36 * u), tangent2End: CGPoint(x: 6 * u, y: 33 * u), radius: 3 * u)
        path.addLine(to: CGPoint(x: 6 * u, y: 6 * u))
        path.addArc(tangent1End: CGPoint(x: 6 * u, y: 3 * u), tangent2End: CGPoint(x: 9 * u, y: 3 * u), radius: 3 * u)
        path.closeSubpath()
        return path
    }
}

private nonisolated struct FoldShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 40
        var path = Path()
        path.move(to: CGPoint(x: 22 * u, y: 3.4 * u))
        path.addLine(to: CGPoint(x: 22 * u, y: 9 * u))
        path.addArc(tangent1End: CGPoint(x: 22 * u, y: 12 * u), tangent2End: CGPoint(x: 25 * u, y: 12 * u), radius: 3 * u)
        path.addLine(to: CGPoint(x: 30.6 * u, y: 12 * u))
        path.closeSubpath()
        return path
    }
}

private nonisolated struct MountainShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 40
        var path = Path()
        path.move(to: CGPoint(x: 8.5 * u, y: 31.5 * u))
        path.addLine(to: CGPoint(x: 15 * u, y: 25 * u))
        path.addLine(to: CGPoint(x: 18.5 * u, y: 28.5 * u))
        path.addLine(to: CGPoint(x: 24 * u, y: 22 * u))
        path.addLine(to: CGPoint(x: 29 * u, y: 28 * u))
        path.addLine(to: CGPoint(x: 29 * u, y: 31.5 * u))
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: 16) {
        VaultFileTypeIcon(kind: .pdf, size: 40)
        VaultFileTypeIcon(kind: .word, size: 40)
        VaultFileTypeIcon(kind: .text, size: 40)
        VaultFileTypeIcon(kind: .image, size: 40)
    }
    .padding()
    .background(Color.canvas)
}
