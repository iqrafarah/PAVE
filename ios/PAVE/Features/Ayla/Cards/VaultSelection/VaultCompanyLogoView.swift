import SwiftUI

/// A supplied organisation mark, with the existing monogram treatment as a fallback.
struct VaultCompanyLogoView: View {
    let logo: VaultCompanyLogo?
    let organisation: String
    var size: CGFloat = 58

    var body: some View {
        Group {
            switch logo {
            case .frencken:
                Image(.vaultLogoFrencken)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(.circle)
                    .overlay { Circle().strokeBorder(Color.cardBorder, lineWidth: 1) }
            case .plus:
                Image(.vaultLogoPlus)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(.rect(cornerRadius: 12))
            case .livewall:
                Image(.vaultLogoLivewall)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .background(.black, in: .circle)
                    .clipShape(.circle)
            case nil:
                CompanyMonogram(name: organisation, size: size)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 12) {
        VaultCompanyLogoView(logo: .frencken, organisation: "Mgr. Frencken College")
        VaultCompanyLogoView(logo: .plus, organisation: "Plus")
        VaultCompanyLogoView(logo: .livewall, organisation: "LiveWall")
    }
    .padding()
}
