import SwiftUI
import AppKit

let prSymbol: String = {
    NSImage(systemSymbolName: "arrow.triangle.pull", accessibilityDescription: nil) != nil
        ? "arrow.triangle.pull" : "arrow.branch"
}()

struct ContentView: View {
    @ObservedObject var store: Store
    var isSnapshot = false
    var dismiss: () -> Void = {}
    var openSettings: () -> Void = {}

    private var visibleSections: [(InboxSection, [PR])] {
        InboxSection.allCases.compactMap { section in
            guard let prs = store.groups[section], !prs.isEmpty else { return nil }
            return (section, prs)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if isSnapshot {
                listContent
            } else {
                ScrollView {
                    listContent
                }
                .frame(height: scrollHeight)
            }
            Divider()
            footer
        }
        .frame(width: 360)
    }

    private var scrollHeight: CGFloat {
        let rows = visibleSections.reduce(0) { $0 + $1.1.count }
        let headers = visibleSections.count
        let estimated = CGFloat(rows) * 46 + CGFloat(headers) * 30 + 12
        return min(max(estimated, 140), 520)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Inbox")
                .font(.system(size: 13, weight: .semibold))
            if !store.login.isEmpty {
                Text("@\(store.login)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if let updated = store.lastUpdated {
                Text(shortRelativeTime(from: updated))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Button {
                Task { await store.refresh() }
            } label: {
                if store.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = store.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            if visibleSections.isEmpty && store.errorMessage == nil {
                emptyState
            }
            ForEach(visibleSections, id: \.0) { section, prs in
                sectionHeader(section, count: prs.count)
                ForEach(prs) { pr in
                    PRRow(pr: pr, newComments: store.newCommentCount(pr), isUnread: store.isUnread(pr), viewerLogin: store.login) {
                        store.markRead(pr)
                        if let url = URL(string: pr.url) { NSWorkspace.shared.open(url) }
                        dismiss()
                    }
                }
            }
            Spacer(minLength: 8)
        }
        .padding(.top, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.secondary)
            Text(store.lastUpdated == nil ? "Loading…" : "You're all caught up")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func sectionHeader(_ section: InboxSection, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(section.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(.quaternary))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 3)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            FooterButton(title: "Open inbox", systemImage: "arrow.up.right.square") {
                NSWorkspace.shared.open(URL(string: "https://github.com/pulls/inbox")!)
                dismiss()
            }
            Spacer()
            FooterButton(title: "Mark all read", systemImage: "checkmark.circle") {
                store.markAllRead()
            }
            FooterButton(title: nil, systemImage: "gearshape") {
                openSettings()
            }
            FooterButton(title: nil, systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct FooterButton: View {
    let title: String?
    let systemImage: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .medium))
                if let title {
                    Text(title).font(.system(size: 11))
                }
            }
            .foregroundStyle(hovered ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

struct PRRow: View {
    let pr: PR
    let newComments: Int
    let isUnread: Bool
    var viewerLogin = ""
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: prSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(pr.isDraft ? Color.secondary : Color(nsColor: .systemGreen))
                    .frame(width: 16)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pr.title)
                        .font(.system(size: 12.5, weight: isUnread ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    subtitle
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 6)
                if let (symbol, label, color) = statusInfo {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(color)
                        .padding(.top, 2)
                        .help(label)
                }
                if newComments > 0 {
                    Text("\(newComments) new")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                        .padding(.top, 1)
                } else if isUnread {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(hovered ? 0.07 : 0))
            )
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    private var subtitle: Text {
        var parts = ["\(pr.repo) #\(String(pr.number))"]
        if pr.author != viewerLogin { parts.append(pr.author) }
        parts.append(shortRelativeTime(from: pr.updatedAt))
        return Text(parts.joined(separator: " · "))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
    }

    private var statusInfo: (String, String, Color)? {
        if pr.checksFailing { return ("xmark.circle.fill", "Checks failed", .red) }
        if pr.changesRequested { return ("exclamationmark.circle.fill", "Changes requested", .orange) }
        if pr.hasConflicts { return ("exclamationmark.triangle.fill", "Merge conflicts", .orange) }
        if pr.checksPending { return ("clock.fill", "Checks running", .orange) }
        return nil
    }
}
