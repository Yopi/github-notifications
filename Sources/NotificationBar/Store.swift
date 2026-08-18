import Foundation
import Combine

@MainActor
final class Store: ObservableObject {
    @Published private(set) var login = ""
    @Published private(set) var groups: [InboxSection: [PR]] = [:]
    @Published private(set) var newActivity: [String: Int] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private var seen: [String: Int] = [:]
    private var baselined: Bool
    private let stateURL: URL
    private var lastStates: [String: PRState] = [:]
    private var statesLoaded = false
    private let notifyStateURL: URL

    struct PRState: Codable, Equatable {
        var activity: Int
        var decision: String?
        var review: Bool
    }

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NotificationBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        stateURL = dir.appendingPathComponent("readstate.json")
        notifyStateURL = dir.appendingPathComponent("notifystate.json")
        if let data = try? Data(contentsOf: stateURL),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            seen = decoded
            baselined = true
        } else {
            baselined = false
        }
        if let data = try? Data(contentsOf: notifyStateURL),
           let decoded = try? JSONDecoder().decode([String: PRState].self, from: data) {
            lastStates = decoded
            statesLoaded = true
        }
    }

    var allPRs: [PR] { InboxSection.allCases.flatMap { groups[$0] ?? [] } }

    var badgeCount: Int {
        let reviewURLs = Set((groups[.needsReview] ?? []).map(\.url))
        let unreadElsewhere = newActivity.keys.filter { !reviewURLs.contains($0) }.count
        return reviewURLs.count + unreadElsewhere
    }

    func isUnread(_ pr: PR) -> Bool { newActivity[pr.url] != nil }
    func newCommentCount(_ pr: PR) -> Int { newActivity[pr.url] ?? 0 }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await GitHubClient.fetchInbox()
            login = result.login
            var newGroups: [InboxSection: [PR]] = [:]
            let reviewRequested = result.reviewRequested.sorted { $0.updatedAt > $1.updatedAt }
            newGroups[.needsReview] = reviewRequested
            let reviewURLs = Set(reviewRequested.map(\.url))
            for pr in result.mine.sorted(by: { $0.updatedAt > $1.updatedAt })
            where !reviewURLs.contains(pr.url) {
                newGroups[classifyOwn(pr), default: []].append(pr)
            }
            groups = newGroups

            var activity: [String: Int] = [:]
            var seenChanged = false
            for pr in allPRs {
                if let seenCount = seen[pr.url] {
                    if pr.activityCount > seenCount {
                        activity[pr.url] = pr.activityCount - seenCount
                    } else if pr.activityCount < seenCount {
                        seen[pr.url] = pr.activityCount
                        seenChanged = true
                    }
                } else if !baselined {
                    seen[pr.url] = pr.activityCount
                    seenChanged = true
                } else {
                    activity[pr.url] = 0
                }
            }
            baselined = true
            newActivity = activity
            if seenChanged { persist() }
            sendNotifications(reviewURLs: reviewURLs)
            errorMessage = nil
            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markRead(_ pr: PR) {
        seen[pr.url] = pr.activityCount
        newActivity[pr.url] = nil
        persist()
    }

    func markAllRead() {
        for pr in allPRs { seen[pr.url] = pr.activityCount }
        newActivity = [:]
        persist()
    }

    private func sendNotifications(reviewURLs: Set<String>) {
        var newStates = lastStates
        for pr in allPRs {
            let inReview = reviewURLs.contains(pr.url)
            newStates[pr.url] = PRState(activity: pr.activityCount, decision: pr.reviewDecision, review: inReview)
            guard statesLoaded else { continue }
            let old = lastStates[pr.url]
            let isOwn = pr.author == login
            let subject = "\(pr.title) · \(pr.repo) #\(pr.number)"
            if inReview && !(old?.review ?? false) {
                if Prefs.reviewRequested {
                    Notifier.shared.post(title: "Review requested", body: "\(pr.author) · \(subject)", url: pr.url)
                }
            } else if isOwn, pr.reviewDecision == "APPROVED", old?.decision != "APPROVED" {
                if Prefs.approved {
                    Notifier.shared.post(title: "Pull request approved", body: subject, url: pr.url)
                }
            } else if isOwn, pr.reviewDecision == "CHANGES_REQUESTED", old?.decision != "CHANGES_REQUESTED" {
                if Prefs.changesRequested {
                    Notifier.shared.post(title: "Changes requested", body: subject, url: pr.url)
                }
            } else if let old, pr.activityCount > old.activity {
                if Prefs.comments && pr.lastActivityAuthor != login {
                    let delta = pr.activityCount - old.activity
                    Notifier.shared.post(
                        title: delta == 1 ? "New comment" : "\(delta) new comments",
                        body: subject,
                        url: pr.url
                    )
                }
            }
        }
        statesLoaded = true
        if newStates != lastStates {
            lastStates = newStates
            if let data = try? JSONEncoder().encode(lastStates) {
                try? data.write(to: notifyStateURL, options: .atomic)
            }
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(seen) {
            try? data.write(to: stateURL, options: .atomic)
        }
    }
}
