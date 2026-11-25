import PAVECore
import SwiftUI

/// What Ayla found about a company: a short description, a few facts, its site, and the pages it came from.
struct EmployerAboutFound: View {
    let about: CompanyAbout

    private var details: [String] {
        [about.sector, about.size, about.locations.isEmpty ? nil : about.locations.joined(separator: ", ")].compactMap { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(about.about)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !details.isEmpty {
                Text(details.joined(separator: " · "))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !about.facts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(about.facts, id: \.label) { fact in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(.iconCheckCircleSolid)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .paveIconFrame(14)
                                .foregroundStyle(Color.paveAccent)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(fact.label).textStyle(.label).foregroundStyle(Color.ink)
                                Text(fact.text).textStyle(.caption).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 16))
            }
            if let website = about.websiteURL {
                Link(destination: website) {
                    HStack(spacing: 6) {
                        Text(about.website ?? "")
                        Image(.iconArrowUpRightSolid).renderingMode(.template).resizable().scaledToFit().frame(width: 12, height: 12).accessibilityHidden(true)
                    }
                    .textStyle(.link)
                    .foregroundStyle(Color.paveAccent)
                    .frame(minHeight: 44)
                }
                .accessibilityHint(EmployerMessages.opensOutside)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(EmployerMessages.sources)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                ForEach(about.sources, id: \.url) { source in
                    Link(source.title, destination: source.url)
                        .textStyle(.caption)
                        .foregroundStyle(Color.paveAccent)
                        .lineLimit(1)
                        .frame(minHeight: 30, alignment: .leading)
                }
                Text(EmployerMessages.foundBy(about.foundAt))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
