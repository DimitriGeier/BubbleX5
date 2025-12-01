import Foundation
import Security

struct Tweet: Codable, Sendable {
    let id: String
    let text: String
    let authorId: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case authorId = "author_id"
        case createdAt = "created_at"
    }
}

struct TimelineResponse: Codable, Sendable {
    let data: [Tweet]?
    let meta: Meta?

    struct Meta: Codable, Sendable {
        let resultCount: Int?
        let newestId: String?
        let oldestId: String?

        enum CodingKeys: String, CodingKey {
            case resultCount = "result_count"
            case newestId = "newest_id"
            case oldestId = "oldest_id"
        }
    }
}

actor XAPIClient {

    private let baseURL = "https://api.twitter.com/2"
    private var bearerToken: String?

    enum XAPIError: Error {
        case noBearerToken
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case decodingError(Error)
        case httpError(statusCode: Int)
    }

    init() {
        self.bearerToken = loadBearerToken()
    }

    func setBearerToken(_ token: String) throws {
        try saveBearerToken(token)
        self.bearerToken = token
    }

    func fetchTimeline(userId: String, maxResults: Int = 10) async throws -> [Tweet] {
        guard let token = bearerToken else {
            throw XAPIError.noBearerToken
        }

        guard let url = URL(string: "\(baseURL)/users/\(userId)/tweets?max_results=\(maxResults)&tweet.fields=created_at,author_id") else {
            throw XAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw XAPIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw XAPIError.httpError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let timelineResponse = try decoder.decode(TimelineResponse.self, from: data)

            return timelineResponse.data ?? []

        } catch let error as DecodingError {
            throw XAPIError.decodingError(error)
        } catch {
            throw XAPIError.networkError(error)
        }
    }

    private func saveBearerToken(_ token: String) throws {
        let tokenData = token.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "XAPIBearerToken",
            kSecAttrService as String: "com.bubblex.xapi",
            kSecValueData as String: tokenData
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private func loadBearerToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "XAPIBearerToken",
            kSecAttrService as String: "com.bubblex.xapi",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let tokenData = result as? Data,
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }

        return token
    }
}
