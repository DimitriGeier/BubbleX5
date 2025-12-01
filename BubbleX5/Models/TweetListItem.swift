import Foundation

struct TweetListItem: Identifiable, Codable {
    let id: UUID
    let tweetText: String
    let author: String
    let createdAt: Date
    let isNice: Bool

    init(id: UUID = UUID(), tweetText: String, author: String, createdAt: Date = Date(), isNice: Bool) {
        self.id = id
        self.tweetText = tweetText
        self.author = author
        self.createdAt = createdAt
        self.isNice = isNice
    }
}
