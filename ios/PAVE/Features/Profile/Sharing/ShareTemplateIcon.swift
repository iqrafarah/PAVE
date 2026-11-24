import PAVECore
import SwiftUI

/// The icon of who a share is for, in a tinted square as in Meldingen.
struct ShareTemplateIcon: View {
    let template: ShareTemplate
    var isMuted = false

    static func image(_ template: ShareTemplate) -> ImageResource {
        switch template {
        case .employer: .iconBriefcaseSolid
        case .education: .iconAcademicCapSolid
        case .municipality: .iconBuildingOfficeSolid
        case .fair: .iconUserGroupSolid
        }
    }

    var body: some View {
        Image(Self.image(template))
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(isMuted ? Color.inkMuted : Color.paveAccent)
            .frame(width: 18, height: 18)
            .frame(width: 36, height: 36)
            .background(isMuted ? Color.tileFill : Color.paveSurfaceTint, in: .rect(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}
