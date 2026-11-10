struct VaultItem: Identifiable {
    let id: String
    let title: String
    let organisation: String
    let period: String
    let category: VaultCategory
    let status: VaultItemStatus
    let logo: VaultCompanyLogo?

    static let mobilePrototype = [
        VaultItem(
            id: "full-stack-engineer",
            title: "Full-Stack Engineer",
            organisation: "Mijn labtest BV Rijen",
            period: "aug 2026 - nu (2 mnd)",
            category: .experiences,
            status: .verified,
            logo: nil
        ),
        VaultItem(
            id: "leidinggevende",
            title: "Leidinggevende",
            organisation: "Plus Laurijssen Oosterhout",
            period: "nov 2025 - nu (11 mnd)",
            category: .experiences,
            status: .toVerify,
            logo: .plus
        ),
        VaultItem(
            id: "vwo-diploma",
            title: "VWO Diploma",
            organisation: "Mgr. Frencken College Oosterhout",
            period: "2020 - 2025",
            category: .diplomas,
            status: .verified,
            logo: .frencken
        ),
    ]

    static let consentPrototype = [
        VaultItem(
            id: "havo-diploma",
            title: "HAVO Diploma",
            organisation: "Mgr. Frencken College Oosterhout",
            period: "2020 - 2025",
            category: .diplomas,
            status: .verified,
            logo: .frencken
        ),
        VaultItem(
            id: "leidinggevende",
            title: "Leidinggevende",
            organisation: "Plus Laurijssen Oosterhout",
            period: "nov 2025 - nu (11 mnd)",
            category: .experiences,
            status: .toVerify,
            logo: .plus
        ),
        VaultItem(
            id: "eindverslag-stage",
            title: "Eindverslag stage",
            organisation: "LiveWall Tilburg",
            period: "mrt 2025 - dec 2025",
            category: .projects,
            status: .rejected,
            logo: .livewall
        ),
    ]
}
