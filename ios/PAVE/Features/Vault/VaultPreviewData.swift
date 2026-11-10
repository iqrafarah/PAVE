#if DEBUG
import PAVECore

/// Made-up items of Ravi for previews only. The app itself shows only what is in your own vault.
extension VaultContents {
    static let preview = VaultContents(
        items: [
            VaultItem(
                id: "propedeuse", category: .diplomas, title: "Propedeuse HBO-ICT",
                organisationName: "Hogeschool Zuidrand", organisationLocation: "Eindhoven",
                issuedOn: VaultDay(year: 2024, month: 7, day: 1), status: .verified, source: .organization
            ),
            VaultItem(
                id: "teamleider", category: .workExperience, title: "Teamleider avondploeg",
                organisationName: "Supermarkt De Hoek", organisationLocation: "Tilburg",
                startDate: VaultDay(year: 2025, month: 11, day: 1), isCurrent: true,
                skills: ["Leiderschap", "Communicatie", "Planning"]
            ),
            VaultItem(
                id: "stageverslag", folderID: "stage", category: .projects, title: "Eindverslag stage",
                organisationName: "Pixelwerk", organisationLocation: "Eindhoven",
                startDate: VaultDay(year: 2025, month: 3, day: 1), endDate: VaultDay(year: 2025, month: 12, day: 1),
                status: .rejected, skills: ["Swift", "Testen"]
            ),
        ],
        folders: [VaultFolder(id: "stage", name: "Stage", color: .rose, icon: .rocket)]
    )
}
#endif
