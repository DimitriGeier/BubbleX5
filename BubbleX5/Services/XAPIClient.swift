import Foundation
import Combine

@MainActor
class XAPIClient: ObservableObject {
    static let shared = XAPIClient()

    let objectWillChange = PassthroughSubject<Void, Never>()

    private let keychainManager = KeychainManager.shared
    private let baseURL = "https://api.x.com/2"
    private let grokURL = "https://api.x.ai/v1/chat/completions"

    private let cache = NSCache<NSString, AnyObject>()
    private let cacheExpiration: TimeInterval = 300

    private var rateLimitRetryCount: [String: Int] = [:]
    private let maxRetries = 3
    private let baseBackoffDelay: TimeInterval = 1.0

    enum XAPIError: Error {
        case invalidURL
        case noToken
        case networkError(Error)
        case rateLimited
        case decodingError(Error)
        case serverError(Int)
        case noData
        case invalidResponse
    }

    init() {
        setupTokens()
    }

    private func setupTokens() {
        do {
            try keychainManager.save("AAAAAAAAAAAAAAAAAAAAAHbz5gEAAAAAnxWqMoxO0YOjb%2Fp1BiqIkRE%2BUeE%3D7FS7mFLT3tNq3mcSCA9FVomDqMtS4L8eSDJ67k7odPgiDXPhxD", for: "x_bearer_token")
            try keychainManager.save("1889547074103848960-73kDWaFxMB7U2hWmXcqAqlM8vLJEbb", for: "x_access_token")
            try keychainManager.save("5xqTi9KQwVpDm6j7iqynWfmmMequjq1JdK7Wl3X6dgQly", for: "x_access_token_secret")
            try keychainManager.save("1995315699154407425notdimitrig", for: "x_api_key")
            print("✅ X API tokens stored in Keychain")
        } catch {
            print("❌ Failed to store tokens: \(error)")
        }
    }

    func fetchHomeTimeline(maxResults: Int = 10, paginationToken: String? = nil) async throws -> XTimelineResponse {
        let cacheKey = "timeline_\(maxResults)_\(paginationToken ?? "initial")" as NSString

        if let cached = cache.object(forKey: cacheKey) as? CachedResponse,
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            print("📦 Returning cached timeline")
            return cached.response
        }

        guard let token = try? keychainManager.retrieve(for: "x_bearer_token") else {
            throw XAPIError.noToken
        }

        var components = URLComponents(string: "\(baseURL)/tweets/search/recent")
        components?.queryItems = [
            URLQueryItem(name: "query", value: "from:me"),
            URLQueryItem(name: "max_results", value: "\(maxResults)"),
            URLQueryItem(name: "tweet.fields", value: "created_at,author_id"),
            URLQueryItem(name: "expansions", value: "author_id"),
            URLQueryItem(name: "user.fields", value: "username,name")
        ]

        if let paginationToken = paginationToken {
            components?.queryItems?.append(URLQueryItem(name: "pagination_token", value: paginationToken))
        }

        guard let url = components?.url else {
            throw XAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let response = try await performRequestWithRetry(request: request, endpoint: "timeline")

        let decoder = JSONDecoder()
        do {
            let timelineResponse = try decoder.decode(XTimelineResponse.self, from: response)

            let cached = CachedResponse(response: timelineResponse, timestamp: Date())
            cache.setObject(cached, forKey: cacheKey)

            print("✅ Fetched \(timelineResponse.data?.count ?? 0) tweets")
            return timelineResponse
        } catch {
            throw XAPIError.decodingError(error)
        }
    }

    func summarizeWithGrok(tweetText: String) async throws -> GrokSuggestion {
        let cacheKey = "grok_\(tweetText.hashValue)" as NSString

        if let cached = cache.object(forKey: cacheKey) as? CachedGrokResponse,
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            print("📦 Returning cached Grok response")
            return cached.suggestion
        }

        guard let token = try? keychainManager.retrieve(for: "x_bearer_token") else {
            throw XAPIError.noToken
        }

        guard let url = URL(string: grokURL) else {
            throw XAPIError.invalidURL
        }

        let prompt = """
        Summarize this tweet in one sentence and suggest exactly 3 related search queries.

        Tweet: "\(tweetText)"

        Respond in this exact format:
        Summary: [your summary]
        Query 1: [query]
        Query 2: [query]
        Query 3: [query]
        """

        let grokRequest = GrokRequest(
            messages: [
                GrokMessage(role: "system", content: "You are a helpful assistant that summarizes tweets and suggests search queries."),
                GrokMessage(role: "user", content: prompt)
            ],
            model: "grok-beta",
            stream: false,
            temperature: 0.7
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(grokRequest)

        let responseData = try await performRequestWithRetry(request: request, endpoint: "grok")

        let decoder = JSONDecoder()
        do {
            let grokResponse = try decoder.decode(GrokResponse.self, from: responseData)

            guard let content = grokResponse.choices.first?.message.content else {
                throw XAPIError.invalidResponse
            }

            let suggestion = parseGrokResponse(content)

            let cached = CachedGrokResponse(suggestion: suggestion, timestamp: Date())
            cache.setObject(cached, forKey: cacheKey)

            print("✅ Grok summarized tweet with \(suggestion.queries.count) queries")
            return suggestion
        } catch {
            throw XAPIError.decodingError(error)
        }
    }

    private func parseGrokResponse(_ content: String) -> GrokSuggestion {
        let lines = content.components(separatedBy: .newlines)
        var summary = ""
        var queries: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Summary:") {
                summary = trimmed.replacingOccurrences(of: "Summary:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Query") {
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    let query = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    queries.append(query)
                }
            }
        }

        if queries.count < 3 {
            queries = ["AI trends", "Tech news", "Innovation"]
        }

        return GrokSuggestion(summary: summary.isEmpty ? "Interesting tweet" : summary, queries: Array(queries.prefix(3)))
    }

    private func performRequestWithRetry(request: URLRequest, endpoint: String) async throws -> Data {
        let retryCount = rateLimitRetryCount[endpoint] ?? 0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw XAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                rateLimitRetryCount[endpoint] = 0
                return data
            case 429:
                if retryCount < maxRetries {
                    let delay = baseBackoffDelay * pow(2.0, Double(retryCount))
                    print("⏱️ Rate limited, retrying after \(delay)s")
                    rateLimitRetryCount[endpoint] = retryCount + 1
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await performRequestWithRetry(request: request, endpoint: endpoint)
                } else {
                    throw XAPIError.rateLimited
                }
            case 400...499:
                throw XAPIError.serverError(httpResponse.statusCode)
            case 500...599:
                if retryCount < maxRetries {
                    let delay = baseBackoffDelay * pow(2.0, Double(retryCount))
                    print("⏱️ Server error, retrying after \(delay)s")
                    rateLimitRetryCount[endpoint] = retryCount + 1
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await performRequestWithRetry(request: request, endpoint: endpoint)
                } else {
                    throw XAPIError.serverError(httpResponse.statusCode)
                }
            default:
                throw XAPIError.serverError(httpResponse.statusCode)
            }
        } catch let error as XAPIError {
            throw error
        } catch {
            throw XAPIError.networkError(error)
        }
    }

    func clearCache() {
        cache.removeAllObjects()
        print("🗑️ Cache cleared")
    }
}

class CachedResponse: NSObject {
    let response: XTimelineResponse
    let timestamp: Date

    init(response: XTimelineResponse, timestamp: Date) {
        self.response = response
        self.timestamp = timestamp
    }
}

class CachedGrokResponse: NSObject {
    let suggestion: GrokSuggestion
    let timestamp: Date

    init(suggestion: GrokSuggestion, timestamp: Date) {
        self.suggestion = suggestion
        self.timestamp = timestamp
    }
}
