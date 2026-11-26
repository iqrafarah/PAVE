import CoreImage.CIFilterBuiltins
import SwiftUI

/// A QR code of a link, built from the blocks of Ayla's orb: they start as a small orb and click into the code, and
/// flow back into the orb when the code goes away. At rest it is dark on white with whole squares, so every scanner
/// reads it, also in dark mode.
struct ShareQRCode: View {
    let url: URL
    /// False lets the blocks flow back into the orb, before the code is taken away.
    var isShown = true

    @Environment(\.paveReduceMotion) private var reduceMotion
    @Environment(\.paveOrbPalette) private var palette
    @State private var modules: [[Bool]] = []
    @State private var changedAt = Date.now
    @State private var isSettled = false

    private static let duration = 0.85

    var body: some View {
        TimelineView(.animation(paused: isSettled || reduceMotion)) { context in
            Canvas { graphics, size in
                let passed = min(1, max(0, context.date.timeIntervalSince(changedAt) / Self.duration))
                let mix = reduceMotion || isSettled ? (isShown ? 1 : 0) : (isShown ? passed : 1 - passed)
                draw(in: &graphics, side: min(size.width, size.height), mix: mix, time: context.date.timeIntervalSinceReferenceDate)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(reduceMotion && !isShown ? 0 : 1)
        .padding(14)
        .background(.white, in: .rect(cornerRadius: 16))
        .accessibilityLabel("QR-code van de link")
        .task(id: url) { modules = Self.modules(for: url.absoluteString) }
        .task(id: isShown) {
            changedAt = .now
            isSettled = false
            try? await Task.sleep(for: .seconds(Self.duration + 0.05))
            if !Task.isCancelled { isSettled = true }
        }
    }

    /// Every dark square of the code is one block. `mix` 0 is the orb, 1 the code; each block leaves at its own moment.
    private func draw(in graphics: inout GraphicsContext, side: CGFloat, mix: Double, time: Double) {
        let count = modules.count
        guard count > 0, !palette.isEmpty else { return }
        let cell = side / CGFloat(count)
        let center = Double(count - 1) / 2
        for row in 0..<count {
            for column in 0..<count where modules[row][column] {
                let x = (Double(column) - center) / center
                let y = (Double(row) - center) / center
                let h = Self.hash(column, row)
                let raw = min(1, max(0, mix * 1.6 - h * 0.6))
                let local = raw * raw * (3 - 2 * raw)

                // In the orb: the square of the code pressed into a small disc, turning a little while it is loose.
                let reach = max(abs(x), abs(y))
                let length = (x * x + y * y).squareRoot()
                let disc = length > 0 ? reach / length * 0.56 : 0
                let angle = (1 - local) * (0.9 + h * 0.5)
                let orbX = (x * cos(angle) - y * sin(angle)) * disc
                let orbY = (x * sin(angle) + y * cos(angle)) * disc
                let px = orbX + (x - orbX) * local
                let py = orbY + (y - orbY) * local

                // Orb colours on the way, light to dark towards the lower left like Ayla's slash; dark once in place.
                let shade = 0.62 - reach * 0.35 + (y - x) * 0.12 + 0.16 * sin(time * 1.1 + h * .pi * 2)
                let tint = min(1, max(0, shade + (1 - shade) * local))
                let color = palette[min(palette.count - 1, Int(tint * Double(palette.count)))]

                // Loose blocks keep the orb's gap; in the code they touch, so nothing gets between the squares.
                let gap = cell * 0.16 * (1 - local)
                let block = cell * (0.56 + 0.44 * local) - gap
                let middle = CGPoint(x: side / 2 + CGFloat(px) * (side - cell) / 2, y: side / 2 + CGFloat(py) * (side - cell) / 2)
                // Half a point over the edge when in place, so no hairline shows between neighbours.
                let rect = CGRect(x: middle.x - block / 2, y: middle.y - block / 2, width: block, height: block).insetBy(dx: -0.25 * local, dy: -0.25 * local)
                let alpha = min(1, max(0, (mix - 0.03) * 6))
                graphics.fill(Path(rect), with: .color(color.opacity(alpha)))
                graphics.fill(Path(rect), with: .color(.black.opacity(0.6 * local * alpha)))
            }
        }
    }

    private static func hash(_ i: Int, _ j: Int) -> Double {
        let x = sin(Double(i) * 12.9898 + Double(j) * 78.233) * 43758.5453
        return x - x.rounded(.down)
    }

    /// The squares of the code, row by row, without the white edge around it.
    static func modules(for text: String) -> [[Bool]] {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "Q"
        guard let output = filter.outputImage else { return [] }
        let width = Int(output.extent.width), height = Int(output.extent.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        CIContext().render(output, toBitmap: &pixels, rowBytes: width * 4, bounds: output.extent, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        let grid = (0..<height).map { row in (0..<width).map { pixels[(row * width + $0) * 4] < 128 } }
        let rows = grid.indices.filter { grid[$0].contains(true) }
        let columns = (0..<width).filter { column in grid.contains { $0[column] } }
        guard let top = rows.first, let bottom = rows.last, let left = columns.first, let right = columns.last else { return [] }
        return grid[top...bottom].map { Array($0[left...right]) }
    }

    static func image(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage, let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// For the Watch: a bitmap big enough to stay sharp there.
    static func png(for text: String, size: CGFloat = 400) -> Data? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: size / output.extent.width, y: size / output.extent.height))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg).pngData()
    }
}
