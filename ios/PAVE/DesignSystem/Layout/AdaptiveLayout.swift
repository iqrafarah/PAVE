import PAVECore
import SwiftUI
import UIKit

enum AdaptiveMode: Equatable {
    case compact
    case card
    case split(FoldSplit)

    /// - Parameters:
    ///   - size: The space the content gets. It shrinks when the keyboard is open, so use it to place content.
    ///   - stableSize: The space without the keyboard. Decide portrait or landscape with this one,
    ///     otherwise opening the keyboard on a portrait screen switches the layout and closes the keyboard again.
    static func resolve(size: CGSize, stableSize: CGSize, sizeClass: UserInterfaceSizeClass?, fold: FoldSplit?) -> AdaptiveMode {
        if let fold {
            return .split(fold)
        }
        guard sizeClass == .regular else {
            return .compact
        }
        return stableSize.width > stableSize.height ? .split(.landscape(in: size)) : .card
    }
}

extension View {
    /// Reports the size of the whole window. Unlike a `GeometryReader`, it does not shrink when the keyboard opens.
    func trackingStableSize(_ size: Binding<CGSize>) -> some View {
        background {
            WindowSizeReader(size: size)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct WindowSizeReader: UIViewRepresentable {
    @Binding var size: CGSize

    func makeUIView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.isUserInteractionEnabled = false
        view.onChange = { size = $0 }
        return view
    }

    func updateUIView(_ view: ReportingView, context: Context) {
        view.onChange = { newSize in
            if size != newSize {
                size = newSize
            }
        }
        view.report()
    }

    final class ReportingView: UIView {
        var onChange: ((CGSize) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        func report() {
            guard let scene = window?.windowScene else { return }
            let newSize = scene.coordinateSpace.bounds.size
            DispatchQueue.main.async { [weak self] in
                self?.onChange?(newSize)
            }
        }
    }
}

extension GeometryProxy {
    func foldSplit() -> FoldSplit? {
        guard #available(iOS 27.1, *) else { return nil }
        let regions = reservedRegions(kind: .division)
            .filter(\.isActive)
            .map { region in
                FoldSplit.Region(
                    frame: region.frame,
                    top: region.margins.top,
                    leading: region.margins.leading,
                    bottom: region.margins.bottom,
                    trailing: region.margins.trailing
                )
            }
        return FoldSplit.around(regions, in: size)
    }
}

struct SplitPanes<First: View, Second: View>: View {
    let split: FoldSplit
    @ViewBuilder let first: First
    @ViewBuilder let second: Second

    var body: some View {
        ZStack(alignment: .topLeading) {
            first
                .frame(width: split.first.width, height: split.first.height)
                .offset(x: split.first.minX, y: split.first.minY)
            second
                .frame(width: split.second.width, height: split.second.height)
                .offset(x: split.second.minX, y: split.second.minY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
