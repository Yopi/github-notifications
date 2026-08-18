import Foundation

struct PR: Identifiable, Hashable {
    let id: String
    let title: String
    let number: Int
    let url: String
    let isDraft: Bool
    let updatedAt: Date
    let repo: String
    let author: String
    let activityCount: Int
    let lastActivityAuthor: String?
    let reviewDecision: String?
    let checkState: String?
    let mergeable: String?

    var checksFailing: Bool { checkState == "FAILURE" || checkState == "ERROR" }
    var checksPending: Bool { checkState == "PENDING" || checkState == "EXPECTED" }
    var hasConflicts: Bool { mergeable == "CONFLICTING" }
    var changesRequested: Bool { reviewDecision == "CHANGES_REQUESTED" }
}

enum InboxSection: Int, CaseIterable, Identifiable {
    case needsReview
    case drafts
    case waiting
    case needsAction
    case readyToMerge

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .needsReview: return "Needs your review"
        case .drafts: return "Your drafts"
        case .waiting: return "Waiting for review or checks"
        case .needsAction: return "Needs action"
        case .readyToMerge: return "Ready to merge"
        }
    }
}

func classifyOwn(_ pr: PR) -> InboxSection {
    if pr.isDraft { return .drafts }
    if pr.checksFailing || pr.changesRequested || pr.hasConflicts { return .needsAction }
    if pr.reviewDecision == "APPROVED" && !pr.checksPending { return .readyToMerge }
    return .waiting
}

func shortRelativeTime(from date: Date, to now: Date = Date()) -> String {
    let seconds = max(0, now.timeIntervalSince(date))
    let minutes = Int(seconds / 60)
    if minutes < 1 { return "now" }
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h" }
    let days = hours / 24
    if days < 14 { return "\(days)d" }
    let weeks = days / 7
    if weeks < 9 { return "\(weeks)w" }
    return "\(days / 30)mo"
}
