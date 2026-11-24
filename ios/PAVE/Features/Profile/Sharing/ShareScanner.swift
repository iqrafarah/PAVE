import PAVECore
import SwiftUI
import VisionKit

/// The camera, looking for a QR code: an employer at a fair, or someone's shared profile.
struct ShareScanner: UIViewControllerRepresentable {
    let onFound: (ShareLinks.Scanned) -> Void

    static var isAvailable: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    func makeCoordinator() -> Coordinator { Coordinator(onFound: onFound) }

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
        private var isDone = false

        init(onFound: @escaping (ShareLinks.Scanned) -> Void) {
            self.onFound = onFound
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !isDone else { return }
            for case .barcode(let code) in items {
                guard let text = code.payloadStringValue, let found = ShareLinks.scanned(text) else { continue }
                isDone = true
                scanner.stopScanning()
                PaveHaptics.success()
                onFound(found)
                return
            }
        }
    }
}
