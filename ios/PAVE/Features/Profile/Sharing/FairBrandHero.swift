import PAVECore
import SwiftUI

/// The top of an employer's page in its own look, like its poster at the stand: logo, stand, its line and where it is.
struct FairBrandHero: View {
    let employer: FairEmployer
    let brand: FairBrand

    private var standLetter: String? { employer.stand?.split(separator: " ").last.map(String.init) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image(brand.logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: brand.motif == .band ? 52 : 34)
                    .padding(.horizontal, brand.motif == .band ? 0 : 12)
                    .padding(.vertical, brand.motif == .band ? 0 : 9)
                    .background(brand.motif == .band ? Color.clear : Color.white, in: .rect(cornerRadius: brand.logoPlateRadius))
                    .accessibilityLabel(employer.name)
                Spacer(minLength: 12)
                if let stand = employer.stand, brand.motif != .sun {
                    Text(brand.isMono ? stand.replacingOccurrences(of: "Stand ", with: "stand_") : stand)
                        .font(.system(size: 14, weight: .bold, design: brand.isMono ? .monospaced : .default))
                        .foregroundStyle(standInk)
                        .padding(.horizontal, brand.isMono ? 0 : 12)
                        .padding(.vertical, brand.isMono ? 0 : 7)
                        .background(standFill, in: .capsule)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                if let kicker = brand.kicker {
                    Text(kicker).font(.system(size: 13, design: .monospaced)).foregroundStyle(brand.accent)
                }
                headline
            }
            Text([employer.name, employer.city].compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(brand.ink.opacity(0.85))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { FairBrandMotif(brand: brand, letter: standLetter) }
        .background(brand.background)
        .clipShape(.rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var headline: some View {
        let text = Text(brand.headlineIsUppercase ? brand.headline.uppercased() : brand.headline)
            .font(.system(size: 34, weight: brand.headlineIsUppercase ? .black : .heavy))
            .tracking(brand.headlineIsUppercase ? 0 : -0.8)
            .lineSpacing(-2)
            .fixedSize(horizontal: false, vertical: true)
        if brand.motif == .band {
            text
                .foregroundStyle(brand.background)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.vertical, 10)
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .padding(.horizontal, -40)
                .rotationEffect(.degrees(-4))
                .padding(.vertical, 10)
        } else {
            text.foregroundStyle(brand.ink)
        }
    }

    private var standInk: Color {
        switch brand.motif {
        case .chevron: brand.accent
        case .band: .white
        default: brand.background
        }
    }

    private var standFill: Color {
        switch brand.motif {
        case .chevron: .clear
        case .band: brand.accent
        default: .white
        }
    }
}
