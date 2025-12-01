import Foundation

class TweetListManager {
    static let shared = TweetListManager()

    private let niceTweetsKey = "niceTweets"
    private let naughtyTweetsKey = "naughtyTweets"

    func addToNiceList(tweetText: String, author: String) {
        let item = TweetListItem(tweetText: tweetText, author: author, isNice: true)
        addItem(item, to: niceTweetsKey)
    }

    func addToNaughtyList(tweetText: String, author: String) {
        let item = TweetListItem(tweetText: tweetText, author: author, isNice: false)
        addItem(item, to: naughtyTweetsKey)
    }

    private func addItem(_ item: TweetListItem, to key: String) {
        var items = loadItems(from: key)
        items.append(item)
        saveItems(items, to: key)
    }

    private func loadItems(from key: String) -> [TweetListItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TweetListItem].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveItems(_ items: [TweetListItem], to key: String) {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    func clearNiceList() {
        UserDefaults.standard.removeObject(forKey: niceTweetsKey)
    }

    func clearNaughtyList() {
        UserDefaults.standard.removeObject(forKey: naughtyTweetsKey)
    }
}
