import Foundation

/// Where the plans are kept: Supabase for a real account (`SupabasePlanService`), memory or a file for the demo login,
/// previews and tests (`LocalPlanService`).
public protocol PlanService: Sendable {
    func plans() async throws -> [PavePlan]
    /// Adds the plan, or replaces the one with the same id.
    func save(_ plan: PavePlan) async throws
    func delete(id: String) async throws
}

/// Plans in a JSON file on the device. The first time, before there is a file, it starts with `seed`.
public actor LocalPlanService: PlanService {
    private let fileURL: URL?
    private let seed: [PavePlan]
    private var cache: [PavePlan]?

    /// `fileURL` nil keeps the plans in memory only, for previews and tests.
    public init(fileURL: URL?, seed: [PavePlan] = []) {
        self.fileURL = fileURL
        self.seed = seed
    }

    public func plans() async throws -> [PavePlan] {
        try load()
    }

    public func save(_ plan: PavePlan) async throws {
        var plans = try load()
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }
        try write(plans)
    }

    public func delete(id: String) async throws {
        var plans = try load()
        plans.removeAll { $0.id == id }
        try write(plans)
    }

    private func load() throws -> [PavePlan] {
        if let cache { return cache }
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path()) else {
            cache = seed
            return seed
        }
        let plans = try Self.decoder.decode([PavePlan].self, from: Data(contentsOf: fileURL))
        cache = plans
        return plans
    }

    private func write(_ plans: [PavePlan]) throws {
        cache = plans
        guard let fileURL else { return }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(plans).write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
