import PAVECore
import SwiftUI

extension VaultCategory {
    var icon: ImageResource {
        switch self {
        case .diplomas: .iconAcademicCapSolid
        case .certificates: .iconCheckBadgeSolid
        case .badges: .iconStar
        case .projects: .iconWrenchScrewdriverSolid
        case .workExperience: .iconBriefcaseSolid
        case .internships: .iconBuildingOfficeSolid
        case .skills: .iconPaintBrush
        case .feedback: .iconChatBubbleLeftEllipsisSolid
        case .reflections: .iconDocumentText
        case .other: .iconFolderSolid
        }
    }

    /// The outline icon on the folder tiles, as in the design. Everywhere else the vault uses filled icons.
    var folderIcon: ImageResource {
        switch self {
        case .diplomas: .iconAcademicCapOutline
        case .certificates: .iconCheckBadgeOutline
        case .badges: .iconStarOutline
        case .projects: .iconWrenchScrewdriverOutline
        case .workExperience: .iconBriefcaseOutline
        case .internships: .iconBuildingOfficeOutline
        case .skills: .iconPaintBrushOutline
        case .feedback: .iconChatBubbleLeftEllipsisOutline
        case .reflections: .iconDocumentTextOutline
        case .other: .iconFolderOutline
        }
    }

    var tint: Color {
        switch self {
        case .diplomas, .certificates, .badges: .cardTintApricot
        case .workExperience, .internships: .cardTintGreen
        case .projects, .skills: .cardTintLime
        case .feedback, .reflections, .other: .cardTintLavender
        }
    }
}

extension VaultConfirmationRequest.Recipient {
    var icon: ImageResource {
        switch self {
        case .school: .iconAcademicCapSolid
        case .employer: .iconBriefcaseSolid
        case .mentor: .iconUserGroup
        }
    }
}

extension VaultItem.Status {
    var icon: ImageResource {
        switch self {
        case .verified: .iconCheckBadgeSolid
        case .toVerify: .iconClockSolid
        case .rejected: .iconExclamationCircleSolid
        }
    }

    var foreground: Color {
        switch self {
        case .verified: .paveAccent
        case .toVerify: .statusPending
        case .rejected: .statusRejected
        }
    }

    var background: Color {
        switch self {
        case .verified: .paveVerifiedSurface
        case .toVerify: .statusPendingSurface
        case .rejected: .statusRejectedSurface
        }
    }
}

extension VaultFolderColor {
    /// Green follows the accent of the app; the others are the theme colours, as on the web.
    var color: Color {
        self == .green ? .paveAccent : Color(uiColor: UIColor(hex: hex))
    }

    /// The light band behind the folder: 11% of the colour on white, which for green is exactly the surface tint.
    var surface: Color {
        self == .green ? .paveSurfaceTint : color.mix(with: Color.panel, by: 0.89)
    }

    /// White on the colour when that reads well (WCAG AA for the icon), otherwise ink, as for lime or a light own colour.
    var foreground: Color {
        self == .green || PaveThemeColor.contrastWithWhite(hex) >= 3 ? .white : .ink
    }
}

extension VaultFolderIcon {
    /// Filled, for projects (web: every project icon is filled).
    var solidImage: ImageResource {
        switch self {
        case .folder: .iconFolderSolid
        case .briefcase: .iconBriefcaseSolid
        case .academicCap: .iconAcademicCapSolid
        case .checkBadge: .iconCheckBadgeSolid
        case .wrenchScrewdriver: .iconWrenchScrewdriverSolid
        case .chatBubble: .iconChatBubbleLeftEllipsisSolid
        case .star: .iconStarSolid
        case .heart: .iconHeartSolid
        case .codeBracket: .iconCodeBracketSolid
        case .lightBulb: .iconLightBulbSolid
        case .rocket: .iconRocketLaunchSolid
        case .globe: .iconGlobeEuropeAfricaSolid
        case .paintBrush: .iconPaintBrushSolid
        case .documentText: .iconDocumentTextSolid
        case .userGroup: .iconUserGroupSolid
        case .trophy: .iconTrophySolid
        }
    }

    /// Outline, like the icons on the category folders.
    var image: ImageResource {
        switch self {
        case .folder: .iconFolderOutline
        case .briefcase: .iconBriefcaseOutline
        case .academicCap: .iconAcademicCapOutline
        case .checkBadge: .iconCheckBadgeOutline
        case .wrenchScrewdriver: .iconWrenchScrewdriverOutline
        case .chatBubble: .iconChatBubbleLeftEllipsisOutline
        case .star: .iconStarOutline
        case .heart: .iconHeartOutline
        case .codeBracket: .iconCodeBracketOutline
        case .lightBulb: .iconLightBulbOutline
        case .rocket: .iconRocketLaunchOutline
        case .globe: .iconGlobeEuropeAfricaOutline
        case .paintBrush: .iconPaintBrushOutline
        case .documentText: .iconDocumentTextOutline
        case .userGroup: .iconUserGroupOutline
        case .trophy: .iconTrophyOutline
        }
    }
}
