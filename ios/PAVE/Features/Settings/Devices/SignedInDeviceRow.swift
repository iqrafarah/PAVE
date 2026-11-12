import PAVECore
import SwiftUI

/// One signed-in device: an icon for the kind of device, its name, when it was active and, for another device, a
/// button to sign it out.
struct SignedInDeviceRow: View {
    let device: SignedInDevice
    var isSigningOut = false
    var onSignOut: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(device.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(device.isCurrent ? Color.white : .brandGreen)
                .frame(width: 40, height: 40)
                .background(device.isCurrent ? Color.brandGreen : .dropZone, in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(DevicesMessages.name(of: device))
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                Text(DevicesMessages.activity(of: device))
                    .textStyle(.caption)
                    .foregroundStyle(device.isCurrent ? Color.brandGreen : .inkMuted)
                Text(DevicesMessages.signedIn(of: device))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onSignOut {
                Button(action: onSignOut) {
                    Group {
                        if isSigningOut {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.critical)
                        } else {
                            Text("Uitloggen")
                                .textStyle(.gapChip)
                        }
                    }
                    .foregroundStyle(Color.critical)
                    .padding(.horizontal, 12)
                    .frame(minWidth: 44, minHeight: 34)
                    .background(Color.critical.opacity(0.08), in: .capsule)
                    .contentShape(.capsule)
                }
                .buttonStyle(.pave)
                .disabled(isSigningOut)
                .accessibilityLabel("Uitloggen op \(DevicesMessages.name(of: device))")
            }
        }
        .padding(12)
        .background(Color.white, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }
}

extension SignedInDevice {
    var icon: ImageResource {
        switch kind {
        case .iPhone, .android: .iconDevicePhoneMobileSolid
        case .iPad: .iconDeviceTabletSolid
        case .mac, .windows, .linux: .iconComputerDesktopSolid
        case .unknown: client == .paveApp ? .iconDevicePhoneMobileSolid : .iconQuestionMarkCircleSolid
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        SignedInDeviceRow(device: SignedInDevice(id: "a", kind: .iPhone, client: .paveApp, signedInAt: .now, lastActiveAt: .now, isCurrent: true))
        SignedInDeviceRow(device: SignedInDevice(id: "b", kind: .mac, client: .browser("Safari"), signedInAt: .now.addingTimeInterval(-86_400 * 3), lastActiveAt: .now.addingTimeInterval(-7200), isCurrent: false)) {}
    }
    .padding(24)
    .background(Color.canvas)
}
