import PAVECore
import SwiftUI
import VisionKit

/// The camera, looking for a QR code: an employer at a fair, or someone's shared profile.
struct ShareScanner: UIViewControllerRepresentable {
    let onFound: (ShareLinks.Scanned) -> Void
    /// A QR code that is not PAVE's, so the screen can say so instead of staying silent.
    var onUnknown: () -> Void = {}

    static var isAvailable: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    func makeCoordinator() -> Coordinator { Coordinator(onFound: onFound, onUnknown: onUnknown) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced,
            recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false, isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onFound: (ShareLinks.Scanned) -> Void
        let onUnknown: () -> Void
        private var isDone = false
        private var unknown: Set<String> = []

        init(onFound: @escaping (ShareLinks.Scanned) -> Void, onUnknown: @escaping () -> Void) {
            self.onFound = onFound
            self.onUnknown = onUnknown
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !isDone else { return }
            for case .barcode(let code) in items {
                guard let text = code.payloadStringValue else { continue }
                guard let found = ShareLinks.scanned(text) else {
                    if unknown.insert(text).inserted { onUnknown() }
                    continue
                }
                isDone = true
                scanner.stopScanning()
                PaveHaptics.success()
                onFound(found)
                return
            }
        }
    }
}
