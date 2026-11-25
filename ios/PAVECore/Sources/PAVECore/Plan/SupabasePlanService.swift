import Foundation

public enum PlanServiceError: Error, Equatable, Sendable {
    /// The tables of the plans do not exist yet (migration 20261125130000).
    case notSetUp
    case noSession
    case failed(status: Int)
}

/// Plans in Supabase (`plans`, `plan_steps`, migration 20261125130000), with the user's own session, so row level
/// security decides what can be read and changed. A whole plan is saved at once with `save_plan`; the chats of a plan
/// are the conversations whose `plan_id` points to it.
public struct SupabasePlanService: PlanService {
    private let restURL: URL
    private let publishableKey: String
    private let session: URLSession
    private let accessToken: @Sendable () async -> String?

    public init(projectURL: URL, publishableKey: String, session: URLSession = .shared, accessToken: @escaping @Sendable () async -> String?) {
        restURL = projectURL.appending(path: "rest/v1")
        self.publishableKey = publishableKey
        self.session = session
        self.accessToken = accessToken
    }

    public func plans() async throws -> [PavePlan] {
        async let plans = get("plans", query: [
            ("select", "id,name,goal,template_id,metadata,created_at,updated_at,completed_at,plan_steps(id,position,title,summary,kind,status,completed_at,metadata)"),
            ("order", "updated_at.desc"),
        ])
        async let chats = get("ayla_conversations", query: [
            ("select", "id,title,plan_id,plan_step_id,created_at"),
            ("plan_id", "not.is.null"),
        ])
        return try Self.decode(plans: await plans, chats: await chats)
    }

    public func save(_ plan: PavePlan) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try JSONSerialization.data(withJSONObject: ["p_plan": try JSONSerialization.jsonObject(with: encoder.encode(plan))])
        var request = try await request(restURL.appending(path: "rpc/save_plan"), method: "POST")
        request.httpBody = body
        _ = try await send(request)
    }

    public func delete(id: String) async throws {
        var components = URLComponents(url: restURL.appending(path: "plans"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        _ = try await send(try await request(components.url!, method: "DELETE"))
    }

    // MARK: Rows

    struct PlanRow: Decodable {
        let id: String
        let name: String
        let goal: String
        let templateId: String?
        let metadata: Metadata?
        let createdAt: String
        let updatedAt: String
        let completedAt: String?
        let planSteps: [StepRow]?
    }

    struct StepRow: Decodable {
        let id: String
        let position: Int
        let title: String
        let summary: String
        let kind: String
        let status: String
        let completedAt: String?
        let metadata: Metadata?
    }

    struct ChatRow: Decodable {
        let id: String
        let title: String?
        let planId: String
        let planStepId: String?
        let createdAt: String?
    }

    /// `metadata` as text values; values of another type (a number a flow stored) become text too.
    struct Metadata: Decodable {
        let values: [String: String]

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = (try? container.decode([String: JSONScalar].self)) ?? [:]
            values = raw.compactMapValues(\.text)
        }
    }

    enum JSONScalar: Decodable {
        case text(String)
        case other

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) { self = .text(text) }
            else if let number = try? container.decode(Double.self) { self = .text(number.rounded() == number ? String(Int(number)) : String(number)) }
            else if let flag = try? container.decode(Bool.self) { self = .text(flag ? "true" : "false") }
            else { self = .other }
        }

        var text: String? {
            if case .text(let text) = self { return text }
            return nil
        }
    }

    /// The rows as plans: steps in their order, and the chats of each plan, the first one first.
    static func decode(plans: Data, chats: Data) throws -> [PavePlan] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let planRows = try decoder.decode([PlanRow].self, from: plans)
        let chatRows = (try? decoder.decode([ChatRow].self, from: chats)) ?? []
        let chatsByPlan = Dictionary(grouping: chatRows, by: \.planId)
        return planRows.map { row in
            let steps = (row.planSteps ?? []).sorted { $0.position < $1.position }.map { step in
                PavePlanStep(
                    id: step.id, title: step.title, summary: step.summary, kind: PavePlanStep.Kind(rawValue: step.kind),
                    status: PavePlanStep.Status(rawValue: step.status) ?? .upcoming,
                    conversationID: nil, completedAt: step.completedAt.map(date(from:)), metadata: step.metadata?.values ?? [:]
                )
            }
            let chats = (chatsByPlan[row.id] ?? [])
                .map { PavePlanConversation(id: $0.id, title: $0.title ?? "", stepID: $0.planStepId, addedAt: $0.createdAt.map(date(from:)) ?? .distantPast) }
                .sorted { $0.addedAt < $1.addedAt }
            var plan = PavePlan(
                id: row.id, name: row.name, goal: row.goal, templateID: row.templateId, steps: steps, conversations: [],
                createdAt: date(from: row.createdAt), updatedAt: date(from: row.updatedAt), metadata: row.metadata?.values ?? [:]
            )
            for chat in chats {
                plan.attach(conversationID: chat.id, title: chat.title, stepID: chat.stepID, at: chat.addedAt)
            }
            plan.updatedAt = date(from: row.updatedAt)
            plan.completedAt = row.completedAt.map(date(from:))
            return plan
        }
    }

    static func date(from text: String) -> Date {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text))
            ?? (try? Date.ISO8601FormatStyle().parse(text))
            ?? .distantPast
    }

    // MARK: Requests

    private func get(_ table: String, query: [(String, String)]) async throws -> Data {
        var components = URLComponents(url: restURL.appending(path: table), resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        return try await send(try await request(components.url!))
    }

    private func request(_ url: URL, method: String = "GET") async throws -> URLRequest {
        guard let token = await accessToken() else { throw PlanServiceError.noSession }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw Self.error(status: status, body: data) }
        return data
    }

    /// A table, column or function that is not there means the migration has not run yet.
    static func error(status: Int, body: Data) -> PlanServiceError {
        let payload = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        let code = payload?["code"] as? String ?? ""
        if ["PGRST202", "PGRST204", "PGRST205", "42P01", "42703", "42883"].contains(code) { return .notSetUp }
        if status == 404, code.isEmpty { return .notSetUp }
        return .failed(status: status)
    }
}
