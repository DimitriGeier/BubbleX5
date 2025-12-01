import SwiftUI

struct TweetListView: View {
    let isNice: Bool
    @ObservedObject var viewModel: DebugViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tweets: [TweetListItem] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if tweets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: isNice ? "star.slash" : "checkmark.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No \(isNice ? "nice" : "naughty") tweets yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ForEach(tweets) { tweet in
                            TweetCard(tweet: tweet)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(isNice ? "Nice List" : "Naughty List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        clearList()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(tweets.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            loadTweets()
        }
    }

    private func loadTweets() {
        let defaults = UserDefaults.standard
        let key = isNice ? "niceTweets" : "naughtyTweets"
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([TweetListItem].self, from: data) {
            tweets = decoded.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private func clearList() {
        let defaults = UserDefaults.standard
        let key = isNice ? "niceTweets" : "naughtyTweets"
        defaults.removeObject(forKey: key)
        tweets = []
    }
}

struct TweetCard: View {
    let tweet: TweetListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: tweet.isNice ? "star.fill" : "xmark.circle.fill")
                    .foregroundStyle(tweet.isNice ? .yellow : .red)
                Text("@\(tweet.author)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(tweet.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(tweet.tweetText)
                .font(.body)
                .lineLimit(nil)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}
