import SwiftUI
import UIKit

/// The part of an image that shows in a frame, as you move and zoom it: worked out apart from the view so it can be tested.
enum VaultImageFrame {
    /// How far the image may move each way before the frame would show an edge.
    static func clamped(_ offset: CGSize, image: CGSize, frame: CGSize, zoom: CGFloat) -> CGSize {
        let shown = displayed(image: image, frame: frame, zoom: zoom)
        let limitX = max(0, (shown.width - frame.width) / 2)
        let limitY = max(0, (shown.height - frame.height) / 2)
        return CGSize(width: min(max(offset.width, -limitX), limitX), height: min(max(offset.height, -limitY), limitY))
    }

    /// The image size on screen: it always covers the frame, and zoom makes it larger.
    static func displayed(image: CGSize, frame: CGSize, zoom: CGFloat) -> CGSize {
        let scale = max(frame.width / image.width, frame.height / image.height) * zoom
        return CGSize(width: image.width * scale, height: image.height * scale)
    }

    /// The rectangle of the image, in image points, that the frame shows.
    static func crop(image: CGSize, frame: CGSize, zoom: CGFloat, offset: CGSize) -> CGRect {
        let shown = displayed(image: image, frame: frame, zoom: zoom)
        let scale = shown.width / image.width
        return CGRect(
            x: ((shown.width - frame.width) / 2 - offset.width) / scale,
            y: ((shown.height - frame.height) / 2 - offset.height) / scale,
            width: frame.width / scale,
            height: frame.height / scale
        )
    }
}

/// "Verplaatsen en schalen", like setting a contact photo: drag and pinch the image until the right part sits in the
/// circle (a logo) or the band (a cover). Klaar keeps exactly that part.
struct VaultImageFramer: View {
    enum Shape {
        case circle
        case band

        var aspect: CGFloat { self == .circle ? 1 : 4 }
        var output: CGSize { self == .circle ? CGSize(width: 600, height: 600) : CGSize(width: 1600, height: 400) }
    }

    let image: UIImage
    let shape: Shape
    let onDone: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var dragging: CGSize = .zero
    @GestureState private var pinching: CGFloat = 1
    @State private var frameSize: CGSize = .zero

    private static let maximumZoom: CGFloat = 5

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let frame = Self.frame(in: proxy.size, aspect: shape.aspect)
                let liveZoom = min(max(zoom * pinching, 1), Self.maximumZoom)
                let liveOffset = VaultImageFrame.clamped(
                    CGSize(width: offset.width + dragging.width, height: offset.height + dragging.height),
                    image: image.size, frame: frame, zoom: liveZoom
                )
                let shown = VaultImageFrame.displayed(image: image.size, frame: frame, zoom: liveZoom)
                ZStack {
                    Color.black
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: shown.width, height: shown.height)
                        .offset(liveOffset)
                    hole(frame: frame)
                    Text("Sleep om te verplaatsen, knijp om te schalen")
                        .textStyle(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .offset(y: frame.height / 2 + 28)
                        .allowsHitTesting(false)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(.rect)
                .gesture(
                    DragGesture()
                        .updating($dragging) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            offset = VaultImageFrame.clamped(
                                CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height),
                                image: image.size, frame: frame, zoom: zoom
                            )
                        }
                        .simultaneously(with: MagnifyGesture()
                            .updating($pinching) { value, state, _ in state = value.magnification }
                            .onEnded { value in
                                zoom = min(max(zoom * value.magnification, 1), Self.maximumZoom)
                                offset = VaultImageFrame.clamped(offset, image: image.size, frame: frame, zoom: zoom)
                            })
                )
                .onAppear { frameSize = frame }
                .onChange(of: proxy.size) { frameSize = Self.frame(in: proxy.size, aspect: shape.aspect) }
                .accessibilityElement()
                .accessibilityLabel(shape == .circle ? "Logo in de cirkel" : "Omslag in de band")
                .accessibilityHint("Sleep om te verplaatsen, knijp om te schalen")
                .accessibilityAdjustableAction { direction in
                    zoom = min(max(zoom + (direction == .increment ? 0.25 : -0.25), 1), Self.maximumZoom)
                    offset = VaultImageFrame.clamped(offset, image: image.size, frame: frame, zoom: zoom)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(shape == .circle ? "Logo" : "Omslag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") {
                        onDone(render())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// The frame in the middle, as large as fits with room around it.
    static func frame(in size: CGSize, aspect: CGFloat) -> CGSize {
        let width = min(size.width - 48, (size.height - 120) * aspect, 560)
        return CGSize(width: max(width, 120), height: max(width, 120) / aspect)
    }

    /// Everything outside the frame is dimmed, so you see what stays.
    private func hole(frame: CGSize) -> some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.6))
            Group {
                if shape == .circle {
                    Circle().frame(width: frame.width, height: frame.height)
                } else {
                    RoundedRectangle(cornerRadius: 12).frame(width: frame.width, height: frame.height)
                }
            }
            .blendMode(.destinationOut)
        }
        .compositingGroup()
        .overlay {
            Group {
                if shape == .circle {
                    Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.8), lineWidth: 1)
                }
            }
            .frame(width: frame.width, height: frame.height)
        }
        .allowsHitTesting(false)
    }

    private func render() -> UIImage {
        let crop = VaultImageFrame.crop(image: image.size, frame: frameSize, zoom: zoom, offset: offset)
        let output = shape.output
        let scale = output.width / crop.width
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: output, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: output))
            image.draw(in: CGRect(
                x: -crop.minX * scale,
                y: -crop.minY * scale,
                width: image.size.width * scale,
                height: image.size.height * scale
            ))
        }
    }
}
