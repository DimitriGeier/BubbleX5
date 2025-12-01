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
        print("🔍 [XAPIClient] fetchHomeTimeline called with maxResults=\(maxResults)")

        let cacheKey = "timeline_\(maxResults)_\(paginationToken ?? "initial")" as NSString

        if let cached = cache.object(forKey: cacheKey) as? CachedResponse,
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            print("📦 [XAPIClient] Returning cached timeline with \(cached.response.data?.count ?? 0) tweets")
            return cached.response
        }

        print("🔑 [XAPIClient] Retrieving bearer token from keychain...")
        guard let token = try? keychainManager.retrieve(for: "x_bearer_token") else {
            print("❌ [XAPIClient] No bearer token found in keychain")
            throw XAPIError.noToken
        }
        print("✅ [XAPIClient] Token retrieved: \(String(token.prefix(10)))...")

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
            print("❌ [XAPIClient] Invalid URL construction")
            throw XAPIError.invalidURL
        }
        print("🌐 [XAPIClient] Request URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        print("📤 [XAPIClient] Sending request to X API...")
        let response = try await performRequestWithRetry(request: request, endpoint: "timeline")
        print("📥 [XAPIClient] Received response: \(response.count) bytes")

        let decoder = JSONDecoder()
        do {
            print("🔄 [XAPIClient] Decoding response...")

            if let jsonString = String(data: response, encoding: .utf8) {
                print("📄 [XAPIClient] Raw response: \(jsonString.prefix(500))...")
            }

            let timelineResponse = try decoder.decode(XTimelineResponse.self, from: response)
            print("✅ [XAPIClient] Successfully decoded \(timelineResponse.data?.count ?? 0) tweets")

            if let tweets = timelineResponse.data {
                for (index, tweet) in tweets.prefix(3).enumerated() {
                    print("   Tweet \(index + 1): \(tweet.text.prefix(50))...")
                }
            }

            let cached = CachedResponse(response: timelineResponse, timestamp: Date())
            cache.setObject(cached, forKey: cacheKey)

            return timelineResponse
        } catch {
            print("❌ [XAPIClient] Decoding error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   Missing key: \(key.stringValue), context: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch: \(type), context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   Value not found: \(type), context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("   Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
            throw XAPIError.decodingError(error)
        }
    }

    func summarizeWithGrok(tweetText: String) async throws -> GrokSuggestion {
        print("🤖 [XAPIClient] summarizeWithGrok called")
        print("   Tweet text: \(tweetText.prefix(100))...")

        let cacheKey = "grok_\(tweetText.hashValue)" as NSString

        if let cached = cache.object(forKey: cacheKey) as? CachedGrokResponse,
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            print("📦 [XAPIClient] Returning cached Grok response with \(cached.suggestion.queries.count) queries")
            return cached.suggestion
        }

        print("🔑 [XAPIClient] Retrieving X bearer token for Grok API...")
        guard let token = try? keychainManager.retrieve(for: "x_bearer_token") else {
            print("❌ [XAPIClient] No bearer token found in keychain")
            throw XAPIError.noToken
        }
        print("✅ [XAPIClient] Token retrieved: \(String(token.prefix(10)))...")

        guard let url = URL(string: grokURL) else {
            print("❌ [XAPIClient] Invalid Grok URL")
            throw XAPIError.invalidURL
        }
        print("🌐 [XAPIClient] Grok URL: \(url.absoluteString))")

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

        print("📤 [XAPIClient] Sending request to Grok API...")
        let responseData = try await performRequestWithRetry(request: request, endpoint: "grok")
        print("📥 [XAPIClient] Received Grok response: \(responseData.count) bytes")

        let decoder = JSONDecoder()
        do {
            print("🔄 [XAPIClient] Decoding Grok response...")

            if let jsonString = String(data: responseData, encoding: .utf8) {
                print("📄 [XAPIClient] Raw Grok response: \(jsonString.prefix(300))...")
            }

            let grokResponse = try decoder.decode(GrokResponse.self, from: responseData)
            print("✅ [XAPIClient] Successfully decoded Grok response")

            guard let content = grokResponse.choices.first?.message.content else {
                print("❌ [XAPIClient] No content in Grok response")
                throw XAPIError.invalidResponse
            }
            print("💬 [XAPIClient] Grok content: \(content)")

            let suggestion = parseGrokResponse(content)
            print("✅ [XAPIClient] Parsed \(suggestion.queries.count) queries from Grok response")
            for (index, query) in suggestion.queries.enumerated() {
                print("   Query \(index + 1): \(query)")
            }

            let cached = CachedGrokResponse(suggestion: suggestion, timestamp: Date())
            cache.setObject(cached, forKey: cacheKey)

            return suggestion
        } catch {
            print("❌ [XAPIClient] Grok decoding error: \(error)")
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
        print("🔄 [XAPIClient] performRequestWithRetry for endpoint '\(endpoint)' (attempt \(retryCount + 1))")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("📬 [XAPIClient] Received response for '\(endpoint)'")

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [XAPIClient] Invalid HTTP response for '\(endpoint)'")
                throw XAPIError.invalidResponse
            }

            print("📊 [XAPIClient] HTTP Status Code: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200...299:
                print("✅ [XAPIClient] Success for '\(endpoint)' - \(data.count) bytes")
                rateLimitRetryCount[endpoint] = 0
                return data
            case 429:
                print("⚠️ [XAPIClient] Rate limited (429) for '\(endpoint)'")
                if retryCount < maxRetries {
                    let delay = baseBackoffDelay * pow(2.0, Double(retryCount))
                    print("⏱️ [XAPIClient] Rate limited, retrying after \(delay)s")
                    rateLimitRetryCount[endpoint] = retryCount + 1
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await performRequestWithRetry(request: request, endpoint: endpoint)
                } else {
                    print("❌ [XAPIClient] Max retries exceeded for rate limit")
                    throw XAPIError.rateLimited
                }
            case 400...499:
                print("❌ [XAPIClient] Client error \(httpResponse.statusCode) for '\(endpoint)'")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("   Error details: \(errorString.prefix(200))")
                }
                throw XAPIError.serverError(httpResponse.statusCode)
            case 500...599:
                print("❌ [XAPIClient] Server error \(httpResponse.statusCode) for '\(endpoint)'")
                if retryCount < maxRetries {
                    let delay = baseBackoffDelay * pow(2.0, Double(retryCount))
                    print("⏱️ [XAPIClient] Server error, retrying after \(delay)s")
                    rateLimitRetryCount[endpoint] = retryCount + 1
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await performRequestWithRetry(request: request, endpoint: endpoint)
                } else {
                    print("❌ [XAPIClient] Max retries exceeded for server error")
                    throw XAPIError.serverError(httpResponse.statusCode)
                }
            default:
                print("❌ [XAPIClient] Unexpected status code \(httpResponse.statusCode) for '\(endpoint)'")
                throw XAPIError.serverError(httpResponse.statusCode)
            }
        } catch let error as XAPIError {
            print("❌ [XAPIClient] XAPIError thrown: \(error)")
            throw error
        } catch {
            print("❌ [XAPIClient] Network error: \(error.localizedDescription)")
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
