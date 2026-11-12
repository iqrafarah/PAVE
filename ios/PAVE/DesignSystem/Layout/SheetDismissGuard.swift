import SwiftUI
import UIKit

extension View {
    /// A sheet you close by swiping it down, without a close button. While `isBlocked` is true (something is filled in),
    /// the swipe does not close it but calls `onAttempt`, so the sheet can ask whether to stop, like Mail and Notes do.
    func sheetDismissGuard(isBlocked: Bool, onAttempt: @escaping () -> Void) -> some View {
        background(SheetDismissGuard(isBlocked: isBlocked, onAttempt: onAttempt).frame(width: 0, height: 0))
    }
}

private struct SheetDismissGuard: UIViewControllerRepresentable {
    let isBlocked: Bool
    let onAttempt: () -> Void

    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.isBlocked = isBlocked
        controller.onAttempt = onAttempt
        controller.install()
    }

    /// Sits between the sheet and SwiftUI's own delegate: it only decides about the swipe and passes everything else on,
    /// so SwiftUI still knows when the sheet closes.
    final class Controller: UIViewController, UIAdaptivePresentationControllerDelegate {
        var isBlocked = false
        var onAttempt: () -> Void = {}
        /// Read from `responds(to:)` and `forwardingTarget(for:)`, which UIKit calls on the main thread.
        nonisolated(unsafe) private weak var original: UIAdaptivePresentationControllerDelegate?

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            install()
        }

        func install() {
            guard let presentation = presentationController, presentation.delegate !== self else { return }
            original = presentation.delegate
            presentation.delegate = self
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            !isBlocked && (original?.presentationControllerShouldDismiss?(presentationController) ?? true)
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            if isBlocked {
                onAttempt()
            } else {
                original?.presentationControllerDidAttemptToDismiss?(presentationController)
            }
        }

        func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
            original?.presentationControllerWillDismiss?(presentationController)
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            original?.presentationControllerDidDismiss?(presentationController)
        }

        nonisolated override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || (original?.responds(to: selector) ?? false)
        }

        nonisolated override func forwardingTarget(for selector: Selector!) -> Any? {
            original?.responds(to: selector) == true ? original : super.forwardingTarget(for: selector)
        }
    }
}
