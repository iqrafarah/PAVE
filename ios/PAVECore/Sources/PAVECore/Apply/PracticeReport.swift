import Foundation

/// What Ayla gets to write the report of a practice interview: the vacancy, the conversation, and the titles of the
/// evidence she may see (the `ayla-practice` function).
public struct PracticeReportRequest: Encodable, Equatable, Sendable {
    public struct Job: Encodable, Equatable, Sendable { public let title: String; public let company: String; public let summary: String? }
    public struct Turn: Encodable, Equatable, Sendable { public let role: String; public let text: String }

    public let vacancy: Job
    public let turns: [Turn]
    public let evidence: [String]

    public init(vacancy: Vacancy, turns: [(fromUser: Bool, text: String)], items: [VaultItem]) {
        self.vacancy = Job(title: vacancy.title, company: vacancy.company, summary: vacancy.summary)
        self.turns = turns.suffix(40).map { Turn(role: $0.fromUser ? "user" : "ayla", text: String($0.text.prefix(1500))) }
        evidence = items.filter { $0.aylaAllowedAt != nil && $0.archivedAt == nil }.prefix(40).map(\.title)
    }
}

/// The report: a verdict, what went well, what can be better, and example answers. Kept with the application.
public struct PracticeReport: Codable, Equatable, Sendable, Identifiable {
    public struct Example: Codable, Equatable, Sendable {
        public let question: String
        public let answer: String

        public init(question: String, answer: String) {
            self.question = question
            self.answer = answer
        }
    }

    public var id: Date { madeAt }
    public let verdict: String
    public let strengths: [String]
    public let improve: [String]
    public let examples: [Example]
    public var madeAt: Date

    private enum CodingKeys: String, CodingKey { case verdict, strengths, improve, examples, madeAt }

    public init(verdict: String, strengths: [String] = [], improve: [String] = [], examples: [Example] = [], madeAt: Date = .now) {
        self.verdict = verdict
        self.strengths = strengths
        self.improve = improve
        self.examples = examples
        self.madeAt = madeAt
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        verdict = try values.decode(String.self, forKey: .verdict)
        strengths = (try? values.decode([String].self, forKey: .strengths)) ?? []
        improve = (try? values.decode([String].self, forKey: .improve)) ?? []
        examples = (try? values.decode([Example].self, forKey: .examples)) ?? []
        // The server sends no date: the report is made now.
        madeAt = (try? values.decode(Date.self, forKey: .madeAt)) ?? .now
    }
}
