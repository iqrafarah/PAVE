import Foundation
import Observation

private enum NotificationsServiceError: Error, LocalizedError, Sendable {
    case notConfigured
    case noSession
    case httpStatus(Int, String?)
    case invalidResponse
    case malformedPayload

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Meldingen zijn niet ingesteld. Controleer de Supabase-projectinstellingen van de app."
        case .noSession:
            "Je sessie is verlopen. Log opnieuw in om je meldingen te bekijken."
        case let .httpStatus(401, _):
            "Je sessie is verlopen. Log opnieuw in om je meldingen te bekijken."
        case let .httpStatus(403, code) where code == "insufficient_aal":
            "Bevestig eerst je identiteit met tweestapsverificatie en probeer opnieuw."
        case .httpStatus(403, _):
            "Je account heeft geen toegang tot deze meldingen."
        case .httpStatus(404, "not_found"):
            "Deze aanvraag is niet meer beschikbaar of je account is niet als beoordelaar toegewezen."
        case .httpStatus(404, _):
            "De meldingenfunctie staat nog niet op Supabase. Deploy de functie vault-review."
        case .httpStatus(409, "no_reviewers"):
            "Voor deze organisatie is nog geen beoordelaar ingesteld."
        case .httpStatus(409, "already_pending"):
            "Voor dit bewijs staat al een verificatieaanvraag open."
        case .httpStatus(500...599, _):
            "Supabase kon de meldingen niet ophalen. Controleer de logs van vault-review in Supabase."
        case let .httpStatus(status, _):
            "Meldingen ophalen is mislukt (HTTP \(status)). Probeer opnieuw."
        case .invalidResponse:
            "Supabase stuurde een ongeldige reactie terug. Controleer de Edge Function vault-review."
        case .malformedPayload:
            "Supabase stuurde meldingsgegevens terug die de app niet herkent. Controleer de response van vault-review."
        }
    }
}

struct NotificationReviewFile: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let mimeType: String
    let role: String
    let url: String
}

struct NotificationReviewItem: Decodable, Sendable {
    let id: String
    let title: String
    let category: String
    let description: String?
    let organisationName: String?
    let organisationLocation: String?
    let startDate: String?
    let endDate: String?
    let issuedOn: String?
    let isCurrent: Bool
    let skills: [String]
    let files: [NotificationReviewFile]

    var categoryTitle: String {
        switch category {
        case "diplomas": "Diploma"
        case "certificates": "Certificaat"
        case "badges": "Badge"
        case "projects": "Project"
        case "workExperience": "Werkervaring"
        case "internships": "Stage"
        case "skills": "Vaardigheid"
        case "feedback": "Feedback"
        case "reflections": "Reflectie"
        default: "Bewijs"
        }
    }

    var periodText: String? {
        if let issuedOn, startDate == nil, endDate == nil { return monthYear(issuedOn) }
        let start = startDate.map(monthYear)
        let end = isCurrent ? "nu" : endDate.map(monthYear)
        switch (start, end) {
        case let (a?, b?): return "\(a) - \(b)"
        case let (a?, nil): return "vanaf \(a)"
        case let (nil, b?): return "tot \(b)"
        default: return nil
        }
    }

    private func monthYear(_ raw: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: raw + "T00:00:00Z") else { return raw }
        return date.formatted(.dateTime.month(.abbreviated).year().locale(Locale(identifier: "nl_NL")))
    }
}

struct NotificationReviewPayload: Decodable, Sendable {
    let item: NotificationReviewItem
}

private struct InboxResponse: Decodable {
    let audience: String
    let notifications: [InboxRow]
}

private struct InboxRow: Decodable {
    let id: String
    let kind: String
    let title: String
    let personName: String
    let date: Date
    let isUnread: Bool
    let conversationID: String?
    let validationRequestID: String?
    let vaultItemID: String?
    let learnerName: String?
    let learnerOrganization: String?
    let documentName: String?
    let documentType: String?
}

struct SupabaseNotificationsService: Sendable {
    private let projectURL: URL
    private let key: String
    private let session: URLSession
    private let accessToken: @Sendable () async -> String?

    init(projectURL: URL, publishableKey: String, session: URLSession = .shared, accessToken: @escaping @Sendable () async -> String?) {
        self.projectURL = projectURL
        key = publishableKey
        self.session = session
        self.accessToken = accessToken
    }

    func inbox() async throws -> (NotificationAudience, [PaveNotification]) {
        let data = try await function(["action": "inbox"])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Invalid notification date")
        }
        let response: InboxResponse
        do {
            response = try decoder.decode(InboxResponse.self, from: data)
        } catch {
            throw NotificationsServiceError.malformedPayload
        }
        let audience: NotificationAudience = response.audience == "administrator" ? .administrator : .learner
        let values = response.notifications.compactMap { row -> PaveNotification? in
            let kind: PaveNotificationKind
            switch row.kind {
            case "conversation": kind = .conversation
            case "evidence_verified": kind = .verifiedEvidence
            case "verification_request": kind = .verificationRequest
            default: return nil
            }
            return PaveNotification(
                id: row.id,
                kind: kind,
                title: row.title,
                personName: row.personName,
                date: row.date,
                isUnread: row.isUnread,
                conversationID: row.conversationID,
                validationRequestID: row.validationRequestID,
                vaultItemID: row.vaultItemID,
                learnerName: row.learnerName,
                learnerOrganization: row.learnerOrganization,
                documentName: row.documentName,
                documentType: row.documentType
            )
        }
        return (audience, values)
    }

    func review(requestID: String) async throws -> NotificationReviewPayload {
        let data = try await function(["action": "detail", "requestId": requestID])
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(NotificationReviewPayload.self, from: data)
    }

    func resolve(requestID: String, action: String, response: String?) async throws {
        _ = try await function(["action": "resolve", "requestId": requestID, "outcome": action, "response": response ?? ""])
    }

    func markRead(notificationID: String) async throws {
        var components = URLComponents(url: projectURL.appending(path: "rest/v1/user_notifications"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(notificationID)")]
        _ = try await call(components.url!, method: "PATCH", body: ["read_at": ISO8601DateFormatter().string(from: .now)])
    }

    private func function(_ body: [String: Any]) async throws -> Data {
        try await call(projectURL.appending(path: "functions/v1/vault-review"), method: "POST", body: body)
    }

    private func call(_ url: URL, method: String, body: [String: Any]) async throws -> Data {
        guard let token = await accessToken() else { throw NotificationsServiceError.noSession }
        var request = URLRequest(url: url, timeoutInterval: 40)
        request.httpMethod = method
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NotificationsServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let code = payload?["error"] as? String ?? payload?["code"] as? String
            throw NotificationsServiceError.httpStatus(http.statusCode, code)
        }
        return data
    }
}

@MainActor @Observable
final class NotificationsModel {
    private let service: SupabaseNotificationsService?
    private(set) var audience: NotificationAudience = .learner
    private(set) var notifications: [PaveNotification] = []
    private(set) var problem: String?

    init(service: SupabaseNotificationsService?) { self.service = service }

    func refresh() async {
        guard let service else {
            problem = NotificationsServiceError.notConfigured.localizedDescription
            return
        }
        do {
            let (newAudience, rows) = try await service.inbox()
            audience = newAudience
            notifications = rows
            problem = nil
        } catch let error as LocalizedError {
            problem = error.errorDescription ?? "Meldingen konden niet worden geladen. Probeer opnieuw."
        } catch {
            problem = "Meldingen konden niet worden geladen. Probeer opnieuw."
        }
    }

    func markRead(_ id: String) async { try? await service?.markRead(notificationID: id) }
    func review(_ id: String) async -> (payload: NotificationReviewPayload?, error: String?) {
        guard let service else {
            return (nil, NotificationsServiceError.notConfigured.localizedDescription)
        }
        do {
            return (try await service.review(requestID: id), nil)
        } catch let error as LocalizedError {
            return (nil, error.errorDescription ?? "De verificatieaanvraag kon niet worden geladen.")
        } catch {
            return (nil, "De verificatieaanvraag kon niet worden geladen. Probeer opnieuw.")
        }
    }

    func resolve(_ id: String, action: String, response: String?) async -> Bool {
        guard let service else { return false }
        do {
            try await service.resolve(requestID: id, action: action, response: response)
            await refresh()
            return true
        } catch { return false }
    }
}
