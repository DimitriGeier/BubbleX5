import Foundation

struct XTweet: Codable, Identifiable {
    let id: String
    let text: String
    let authorId: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case authorId = "author_id"
        case createdAt = "created_at"
    }
}

struct XUser: Codable {
    let id: String
    let username: String
    let name: String
}

struct XTimelineResponse: Codable {
    let data: [XTweet]?
    let includes: XIncludes?
    let meta: XMeta?
}

struct XIncludes: Codable {
    let users: [XUser]?
}

struct XMeta: Codable {
    let resultCount: Int?
    let newestId: String?
    let oldestId: String?
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case resultCount = "result_count"
        case newestId = "newest_id"
        case oldestId = "oldest_id"
        case nextToken = "next_token"
    }
}

struct GrokRequest: Codable {
    let messages: [GrokMessage]
    let model: String
    let stream: Bool
    let temperature: Double
}

struct GrokMessage: Codable {
    let role: String
    let content: String
}

struct GrokResponse: Codable {
    let id: String
    let choices: [GrokChoice]
}

struct GrokChoice: Codable {
    let message: GrokMessage
}

struct GrokSuggestion {
    let summary: String
    let queries: [String]
}
