import PAVECore
import SwiftUI

/// The icon of who a share is for: white on a tile of the accent colour, as the rows of Instellingen. Grey once the
/// share has ended.
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
        ShareRowIcon(icon: Self.image(template), isMuted: isMuted)
    }
}
