import SwiftUI

/// The look of one employer of the fair demo, the same as on its poster: its colours, logo and line. An employer
/// without one keeps PAVE's own plain header.
struct FairBrand {
    enum Motif { case chevron, sun, rings, band, zigzag }

    let logo: ImageResource
    let background: Color
    let accent: Color
    let ink: Color
    let kicker: String?
    let headline: String
    let motif: Motif
    let isMono: Bool
    let logoPlateRadius: CGFloat
    let headlineIsUppercase: Bool

    static func of(_ slug: String) -> FairBrand? {
        switch slug {
        case "ogd":
            FairBrand(
                logo: .fairLogoOgd, background: Color(brand: 0x034EA1), accent: Color(brand: 0x37CFB1), ink: .white,
                kicker: "> werken bij ogd", headline: "Start je\nict-carrière_", motif: .chevron, isMono: true, logoPlateRadius: 10, headlineIsUppercase: false
            )
        case "sioux-technologies":
            FairBrand(
                logo: .fairLogoSioux, background: Color(brand: 0x0D0D0D), accent: Color(brand: 0xE41B23), ink: .white,
                kicker: "// engineering", headline: "Engineers\ngezocht", motif: .sun, isMono: true, logoPlateRadius: 4, headlineIsUppercase: true
            )
        case "catharina-ziekenhuis":
            FairBrand(
                logo: .fairLogoCatharina, background: Color(brand: 0x66456C), accent: Color(brand: 0x24BBE5), ink: .white,
                kicker: nil, headline: "Werken in\nde zorg?", motif: .rings, isMono: false, logoPlateRadius: 30, headlineIsUppercase: false
            )
        case "jumbo":
            FairBrand(
                logo: .fairLogoJumbo, background: Color(brand: 0xEEB717), accent: Color(brand: 0xE30613), ink: .black,
                kicker: nil, headline: "Kom bij Jumbo", motif: .band, isMono: false, logoPlateRadius: 12, headlineIsUppercase: true
            )
        case "gemeente-eindhoven":
            FairBrand(
                logo: .fairLogoEindhoven, background: Color(brand: 0xEF4433), accent: .white, ink: .white,
                kicker: nil, headline: "Werk aan\nje eigen stad", motif: .zigzag, isMono: false, logoPlateRadius: 8, headlineIsUppercase: false
            )
        default: nil
        }
    }
}

private extension Color {
    init(brand value: UInt32) {
        self.init(red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}
