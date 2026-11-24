import SwiftUI

/// The skills as small pills in the page's colour.
struct CVSkillsView: View {
    let skills: [String]
    let accent: Color
    var onDark = false

    var body: some View {
        FlowLayout(spacing: 5) {
            ForEach(skills, id: \.self) { skill in
                Text(skill)
                    .font(ApplicationPage.font(8.5, .medium))
                    .foregroundStyle(onDark ? Color.white : accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(onDark ? Color.white.opacity(0.16) : accent.opacity(0.1), in: .capsule)
            }
        }
    }
}
