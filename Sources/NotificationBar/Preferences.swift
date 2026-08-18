import SwiftUI

enum Prefs {
    static let reviewRequestedKey = "notifyReviewRequested"
    static let commentsKey = "notifyComments"
    static let approvedKey = "notifyApproved"
    static let changesRequestedKey = "notifyChangesRequested"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            reviewRequestedKey: true,
            commentsKey: true,
            approvedKey: true,
            changesRequestedKey: true,
        ])
    }

    static var reviewRequested: Bool { UserDefaults.standard.bool(forKey: reviewRequestedKey) }
    static var comments: Bool { UserDefaults.standard.bool(forKey: commentsKey) }
    static var approved: Bool { UserDefaults.standard.bool(forKey: approvedKey) }
    static var changesRequested: Bool { UserDefaults.standard.bool(forKey: changesRequestedKey) }
}

struct SettingsView: View {
    @AppStorage(Prefs.reviewRequestedKey) private var reviewRequested = true
    @AppStorage(Prefs.commentsKey) private var comments = true
    @AppStorage(Prefs.approvedKey) private var approved = true
    @AppStorage(Prefs.changesRequestedKey) private var changesRequested = true

    var body: some View {
        Form {
            Section {
                Toggle("Review requested", isOn: $reviewRequested)
                Toggle("New comments", isOn: $comments)
                Toggle("Pull request approved", isOn: $approved)
                Toggle("Changes requested", isOn: $changesRequested)
            } header: {
                Text("Notify me when")
            } footer: {
                Text("Checked every minute. Approvals and change requests apply to your own pull requests.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 340)
        .fixedSize()
    }
}
