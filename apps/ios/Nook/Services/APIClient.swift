import Foundation
import Supabase

final class APIClient: Sendable {
    private let baseURL: URL

    init() {
        self.baseURL = URL(string: "https://wzakmmuxsosfybqufdsn.supabase.co/functions/v1")!
    }

    func request<T: Decodable & Sendable>(
        _ endpoint: String,
        body: some Encodable & Sendable
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Attach user JWT if available
        if let session = try? await supabase.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.unknown(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        case 401:
            throw AppError.unauthorized
        case 404:
            throw AppError.notFound
        case 422:
            // Moderation rejection from the content gateway — surface its message.
            let errorBody = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw AppError.contentRejected(errorBody?.error
                ?? "Your content was flagged as violating our community guidelines.")
        case 429:
            throw AppError.rateLimited
        case 503:
            // Moderation temporarily unavailable (fail-closed) — show its message.
            let errorBody = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw AppError.clientError(errorBody?.error
                ?? "We couldn't verify your content right now. Please try again.")
        case 400...499:
            let errorBody = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw AppError.clientError(errorBody?.error ?? "Request failed")
        case 500...599:
            throw AppError.serverError(httpResponse.statusCode)
        default:
            throw AppError.serverError(httpResponse.statusCode)
        }
    }

    /// Calls the `content` moderation gateway with a typed `{action, payload}`
    /// envelope and decodes its response.
    @discardableResult
    func content<P: Encodable & Sendable, R: Decodable & Sendable>(
        _ action: String,
        _ payload: P
    ) async throws -> R {
        try await request("content", body: ContentRequest(action: action, payload: payload))
    }
}

/// `{action, payload}` envelope expected by the `content` Edge Function.
struct ContentRequest<P: Encodable & Sendable>: Encodable, Sendable {
    let action: String
    let payload: P
}

/// Response carrying the id of a freshly-created row.
struct ContentIdResponse: Decodable, Sendable {
    let id: UUID
}

/// Response for gateway actions that don't return a useful body.
struct EmptyResponse: Decodable, Sendable {}

private struct ErrorResponse: Decodable {
    let error: String
}
