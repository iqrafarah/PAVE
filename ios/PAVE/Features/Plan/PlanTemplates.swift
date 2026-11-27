import PAVECore
import SwiftUI

/// The templates a plan can start with. Each step is a kind that leads somewhere in PAVE: a chat with Ayla, the vault,
/// the profile or contact (Meldingen). The user can change, add, remove and skip every step afterwards. Other flows
/// bring their own `PavePlanTemplate` and create the plan with `PlanModel.create(name:goal:from:)`.
enum PlanTemplates {
    static let job = PavePlanTemplate(
        id: "job",
        name: "Een baan vinden",
        summary: "Van wat je zoekt tot je eerste werkdag.",
        goal: "Een baan vinden die bij me past.",
        steps: [
            .init("Wat voor werk zoek je?", summary: "Bespreek met Ayla wat je zoekt: soort werk, uren en plek.", kind: .conversation),
            .init("Je profiel bijwerken", summary: "Laat in je profiel zien wie je bent en wat je kunt.", kind: .profile),
            .init("Bewijs in je kluis", summary: "Zet diploma's, certificaten en werkervaring in je kluis.", kind: .evidence),
            .init("Vacatures zoeken", summary: "Zoek samen met Ayla vacatures die bij je passen.", kind: .research),
            .init("Solliciteren", summary: "Schrijf je motivatie en stuur je sollicitatie.", kind: .document),
            .init("Contact houden", summary: "Houd bij wie je hebt gesproken en wat je terughoort.", kind: .contact),
            .init("Je gesprek voorbereiden", summary: "Oefen je sollicitatiegesprek met Ayla.", kind: .conversation),
        ]
    )

    static let internship = PavePlanTemplate(
        id: "internship",
        name: "Een stage vinden",
        summary: "Een stageplek die past bij je opleiding.",
        goal: "Een stage vinden waar ik veel leer.",
        steps: [
            .init("Wat wil je leren?", summary: "Bespreek met Ayla wat je in je stage wilt leren.", kind: .conversation),
            .init("Eisen van je opleiding", summary: "Zoek uit wat je opleiding van een stage vraagt.", kind: .research),
            .init("Je profiel bijwerken", summary: "Zet je opleiding en wat je al kunt in je profiel.", kind: .profile),
            .init("Stageplekken zoeken", summary: "Zoek met Ayla bedrijven die stages bieden.", kind: .research),
            .init("Overleggen met je begeleider", summary: "Bespreek je keuze met je stagebegeleider van school.", kind: .contact),
            .init("Solliciteren", summary: "Schrijf je motivatie en stuur je sollicitatie.", kind: .document),
            .init("Stageovereenkomst regelen", summary: "Leg de afspraken vast met school en je stageplek.", kind: .milestone),
        ]
    )

    static let career = PavePlanTemplate(
        id: "career",
        name: "Mijn loopbaan ontdekken",
        summary: "Ontdek welke richting bij je past.",
        goal: "Ontdekken welk werk bij me past.",
        steps: [
            .init("Wat geeft je energie?", summary: "Praat met Ayla over wat je leuk vindt en belangrijk.", kind: .conversation),
            .init("Je sterke punten", summary: "Kijk met Ayla naar wat je al kunt, ook in je kluis.", kind: .reflection),
            .init("Richtingen verkennen", summary: "Zoek een paar richtingen die je aanspreken.", kind: .research),
            .init("Praten met iemand uit het vak", summary: "Vraag iemand naar diens werk en ervaring.", kind: .contact),
            .init("Een richting kiezen", summary: "Kies de richting waar je mee verder gaat.", kind: .milestone),
            .init("Je volgende stap plannen", summary: "Maak met Ayla een plan voor die richting.", kind: .conversation),
        ]
    )

    static let education = PavePlanTemplate(
        id: "education",
        name: "Een vervolgopleiding kiezen",
        summary: "Van oriënteren tot aanmelden.",
        goal: "Een opleiding kiezen die bij me past.",
        steps: [
            .init("Wat wil je worden?", summary: "Bespreek met Ayla wat je interesseert en wat je wilt.", kind: .conversation),
            .init("Opleidingen vergelijken", summary: "Zet een paar opleidingen naast elkaar.", kind: .research),
            .init("Toelatingseisen checken", summary: "Kijk welk diploma en welke vakken je nodig hebt.", kind: .research),
            .init("Open dag of meeloopdag", summary: "Ga kijken en praat met studenten en docenten.", kind: .action),
            .init("Diploma's in je kluis", summary: "Zet je diploma's en cijferlijsten in je kluis.", kind: .evidence),
            .init("Aanmelden", summary: "Meld je op tijd aan voor je opleiding.", kind: .milestone),
        ]
    )

    static let skill = PavePlanTemplate(
        id: "skill",
        name: "Een vaardigheid ontwikkelen",
        summary: "Leer iets nieuws en laat zien dat je het kunt.",
        goal: "Een vaardigheid leren en laten zien dat ik die beheers.",
        steps: [
            .init("Je doel scherp krijgen", summary: "Bespreek met Ayla wat je wilt leren en waarom.", kind: .conversation),
            .init("Wat je al kunt", summary: "Kijk terug op wat je al hebt gedaan en geleerd.", kind: .reflection),
            .init("Leren en oefenen", summary: "Zoek een cursus, project of manier om te oefenen.", kind: .research),
            .init("Bewijs in je kluis", summary: "Bewaar een project, resultaat of feedback.", kind: .evidence),
            .init("Laten verifiëren", summary: "Vraag iemand om je bewijs te bevestigen.", kind: .verification),
            .init("Je profiel bijwerken", summary: "Zet de vaardigheid in je profiel.", kind: .profile),
        ]
    )

    static let certificate = PavePlanTemplate(
        id: "certificate",
        name: "Een certificaat behalen",
        summary: "Van kiezen tot een geverifieerd certificaat.",
        goal: "Een certificaat halen dat me verder helpt.",
        steps: [
            .init("Het juiste certificaat kiezen", summary: "Bespreek met Ayla welk certificaat bij je doel past.", kind: .conversation),
            .init("Inschrijven", summary: "Schrijf je in voor de cursus of het examen.", kind: .action),
            .init("Een studieplanning maken", summary: "Maak met Ayla een planning tot het examen.", kind: .conversation),
            .init("Leren en oefenen", summary: "Werk de stof door en oefen met proefexamens.", kind: .research),
            .init("Het examen", summary: "De dag van je examen.", kind: .milestone),
            .init("Certificaat in je kluis", summary: "Zet je certificaat in je kluis.", kind: .evidence),
            .init("Laten verifiëren", summary: "Laat de uitgever je certificaat bevestigen.", kind: .verification),
            .init("Je profiel bijwerken", summary: "Zet het certificaat in je profiel.", kind: .profile),
        ]
    )

    static let careerSwitch = PavePlanTemplate(
        id: "switch",
        name: "Een carrièreswitch maken",
        summary: "Stap over naar ander werk, met wat je al kunt.",
        goal: "Overstappen naar werk dat beter bij me past.",
        steps: [
            .init("Waarom wil je switchen?", summary: "Bespreek met Ayla wat je zoekt en wat je achterlaat.", kind: .conversation),
            .init("Wat neem je mee?", summary: "Breng je ervaring en vaardigheden in kaart.", kind: .reflection),
            .init("Een nieuwe richting verkennen", summary: "Zoek uit welk werk bij je past.", kind: .research),
            .init("Praten met mensen uit het vak", summary: "Vraag hoe het werk echt is en hoe zij erin kwamen.", kind: .contact),
            .init("Wat je nog mist", summary: "Bespreek met Ayla welke kennis of certificaten je nodig hebt.", kind: .conversation),
            .init("Bijscholen", summary: "Volg een cursus of opleiding voor je nieuwe vak.", kind: .research),
            .init("Profiel en kluis bijwerken", summary: "Laat zien wat je meeneemt en wat je erbij leerde.", kind: .profile),
            .init("Solliciteren", summary: "Solliciteer in je nieuwe vak.", kind: .document),
        ]
    )

    /// What the Plan screen offers when you make a plan; the empty one first.
    /// No steps yet: once the plan is made, Ayla proposes them and the user picks.
    static let withAyla = PavePlanTemplate(id: "with-ayla", name: "", summary: PlanMessages.withAylaSummary, goal: "", steps: [])

    static let all: [PavePlanTemplate] = [.empty, withAyla, job, internship, career, education, skill, certificate, careerSwitch]

    static func title(of template: PavePlanTemplate) -> String {
        if template.id == withAyla.id { return PlanMessages.withAylaTitle }
        return template.steps.isEmpty ? "Leeg plan" : template.name
    }

    static func summary(of template: PavePlanTemplate) -> String {
        if template.id == withAyla.id { return PlanMessages.withAylaSummary }
        return template.steps.isEmpty ? "Begin met een doel en voeg zelf stappen toe." : template.summary
    }

    /// The icon of a template, and of a plan that started from it.
    static func icon(for templateID: String?) -> ImageResource {
        switch templateID {
        case job.id: .iconBriefcaseOutline
        case internship.id: .iconBuildingOfficeOutline
        case career.id: .iconRocketLaunchOutline
        case education.id: .iconAcademicCapOutline
        case skill.id: .iconWrenchScrewdriverOutline
        case certificate.id: .iconCheckBadgeOutline
        case careerSwitch.id: .iconArrowsRightLeftOutline
        case PavePlanTemplate.empty.id: .iconPlus
        case withAyla.id: .iconChatBubbleLeftEllipsisOutline
        case "vacancy": .iconBriefcaseOutline
        default: .iconMap
        }
    }
}
