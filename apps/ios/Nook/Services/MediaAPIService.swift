import Foundation

final class MediaAPIService: Sendable {
    private let client: APIClient
    private let searchCache = InMemoryCache<String, APISearchResponse>(ttl: 300)
    private let detailCache = InMemoryCache<String, APIMediaDetail>(ttl: 3600)

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func search(query: String, mediaType: String, page: Int = 1) async throws -> APISearchResponse {
        let cacheKey = "\(mediaType):\(query):\(page)"
        if let cached = await searchCache.get(cacheKey) {
            return cached
        }

        struct Body: Encodable {
            let query: String
            let media_type: String
            let page: Int
        }

        let response: APISearchResponse = try await client.request(
            "search-media",
            body: Body(query: query, media_type: mediaType, page: page)
        )
        await searchCache.set(cacheKey, value: response)
        return response
    }

    func detail(source: String, sourceId: String, mediaType: String) async throws -> APIMediaDetail {
        let cacheKey = "\(source):\(sourceId)"
        if let cached = await detailCache.get(cacheKey) {
            return cached
        }

        struct Body: Encodable {
            let source: String
            let source_id: String
            let media_type: String
        }

        let response: APIMediaDetail = try await client.request(
            "media-detail",
            body: Body(source: source, source_id: sourceId, media_type: mediaType)
        )
        await detailCache.set(cacheKey, value: response)
        return response
    }
}
