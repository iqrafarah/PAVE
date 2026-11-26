import SwiftUI

/// The drawn shape behind an employer's header, taken from its poster: OGD's chevron, Sioux's sun on a grid,
/// Catharina's rings, Jumbo's big letter and Eindhoven's zigzag.
struct FairBrandMotif: View {
    let brand: FairBrand
    let letter: String?

    var body: some View {
        Canvas { context, size in
            switch brand.motif {
            case .chevron: chevron(&context, size)
            case .sun: sun(&context, size)
            case .rings: rings(&context, size)
            case .band: break
            case .zigzag: zigzag(&context, size)
            }
        }
        .overlay(alignment: .trailing) {
            if brand.motif == .band, let letter {
                Text(letter)
                    .font(.system(size: 220, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.12))
                    .offset(x: 20, y: 30)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private func chevron(_ context: inout GraphicsContext, _ size: CGSize) {
        let h = size.height * 0.62
        let w = h * 0.55
        let x = size.width - w * 0.75
        let y = size.height * 0.5
        var path = Path()
        path.move(to: CGPoint(x: x - w, y: y - h / 2))
        path.addLine(to: CGPoint(x: x - w * 0.55, y: y - h / 2))
        path.addLine(to: CGPoint(x: x + w * 0.1, y: y))
        path.addLine(to: CGPoint(x: x - w * 0.55, y: y + h / 2))
        path.addLine(to: CGPoint(x: x - w, y: y + h / 2))
        path.addLine(to: CGPoint(x: x - w * 0.35, y: y))
        path.closeSubpath()
        context.fill(path, with: .color(Color(red: 0.925, green: 0.11, blue: 0.14)))
    }

    private func sun(_ context: inout GraphicsContext, _ size: CGSize) {
        var grid = Path()
        for x in stride(from: 0, through: size.width, by: 20) { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height)) }
        for y in stride(from: 0, through: size.height, by: 20) { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y)) }
        context.stroke(grid, with: .color(.white.opacity(0.07)), lineWidth: 0.5)
        let center = CGPoint(x: size.width - 62, y: 66)
        for index in 0..<24 {
            let angle = CGFloat(index) / 24 * 2 * .pi
            let long = index.isMultiple(of: 2)
            var ray = Path()
            ray.move(to: CGPoint(x: center.x + cos(angle) * 42, y: center.y + sin(angle) * 42))
            ray.addLine(to: CGPoint(x: center.x + cos(angle) * (long ? 80 : 64), y: center.y + sin(angle) * (long ? 80 : 64)))
            context.stroke(ray, with: .color(brand.accent), style: StrokeStyle(lineWidth: long ? 4.5 : 2.5, lineCap: .round))
        }
        context.stroke(Path(ellipseIn: CGRect(x: center.x - 28, y: center.y - 28, width: 56, height: 56)), with: .color(brand.accent), lineWidth: 7)
        if let letter {
            context.draw(Text(letter).font(.system(size: 30, weight: .black)).foregroundStyle(.white), at: center)
        }
    }

    private func rings(_ context: inout GraphicsContext, _ size: CGSize) {
        for (index, radius) in [CGFloat(250), 190, 130].enumerated() {
            let color = index.isMultiple(of: 2) ? brand.accent : Color.white
            let rect = CGRect(x: size.width - 40 - radius, y: 30 - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.10 + Double(index) * 0.04)))
        }
    }

    private func zigzag(_ context: inout GraphicsContext, _ size: CGSize) {
        var path = Path()
        for y in stride(from: CGFloat(10), through: size.height + 20, by: 44) {
            var x: CGFloat = -20
            var isUp = false
            path.move(to: CGPoint(x: x, y: y))
            while x < size.width + 30 {
                x += 26
                isUp.toggle()
                path.addLine(to: CGPoint(x: x, y: y - (isUp ? 16 : 0)))
            }
        }
        context.stroke(path, with: .color(.white.opacity(0.2)), lineWidth: 12)
    }
}
