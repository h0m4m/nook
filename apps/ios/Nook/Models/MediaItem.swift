import Foundation

// MARK: - API Response Models (from Edge Functions)

struct APISearchResult: Codable, Sendable {
    let mediaId: String
    let source: String
    let mediaType: String
    let title: String
    let imageUrl: String?
    let year: String?
    let score: Double?

    enum CodingKeys: String, CodingKey {
        case mediaId = "media_id"
        case source
        case mediaType = "media_type"
        case title
        case imageUrl = "image_url"
        case year
        case score
    }
}

struct APISearchResponse: Codable, Sendable {
    let results: [APISearchResult]
    let page: Int
    let totalPages: Int
    let perPage: Int

    enum CodingKeys: String, CodingKey {
        case results
        case page
        case totalPages = "total_pages"
        case perPage = "per_page"
    }
}

struct APIMediaDetail: Codable, Sendable {
    let mediaId: String
    let source: String
    let mediaType: String
    let sourceUrl: String
    let title: String
    let imageUrl: String?
    let synopsis: String
    let genres: [String]
    let score: Double?
    let scoreCount: Int?
    let maxProgress: Int?
    let details: [String: JSONValue]
    let related: APIRelated?
    let dbId: UUID?

    enum CodingKeys: String, CodingKey {
        case mediaId = "media_id"
        case source
        case mediaType = "media_type"
        case sourceUrl = "source_url"
        case title
        case imageUrl = "image_url"
        case synopsis
        case genres
        case score
        case scoreCount = "score_count"
        case maxProgress = "max_progress"
        case details
        case related
        case dbId = "db_id"
    }
}

struct APIRelated: Codable, Sendable {
    let recommendations: [APISearchResult]?
}

// MARK: - JSONValue (for flexible details dict)

enum JSONValue: Codable, Sendable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
            return
        }
        if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
            return
        }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let v) = self { return v }
        if case .int(let v) = self { return Double(v) }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let v) = self { return v }
        return nil
    }

    var stringArrayValue: [String]? {
        arrayValue?.compactMap(\.stringValue)
    }
}

// MARK: - View-Facing Search Result

struct MediaSearchResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let mediaId: String
    let source: String
    let mediaType: String
    let title: String
    let imageURL: URL?
    let year: String?
    let score: Double?

    init(from api: APISearchResult) {
        self.id = UUID()
        self.mediaId = api.mediaId
        self.source = api.source
        self.mediaType = api.mediaType
        self.title = api.title
        self.imageURL = api.imageUrl.flatMap { URL(string: $0) }
        self.year = api.year
        self.score = api.score
    }

    init(
        id: UUID = UUID(),
        mediaId: String,
        source: String,
        mediaType: String,
        title: String,
        imageURL: URL?,
        year: String?,
        score: Double?
    ) {
        self.id = id
        self.mediaId = mediaId
        self.source = source
        self.mediaType = mediaType
        self.title = title
        self.imageURL = imageURL
        self.year = year
        self.score = score
    }
}
