import Foundation

struct GitHubError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum GitHubClient {
    private static var cachedToken: String?

    static func findToken() -> String? {
        if let cachedToken { return cachedToken }
        if let t = ProcessInfo.processInfo.environment["GITHUB_TOKEN"], !t.isEmpty {
            cachedToken = t
            return t
        }
        for path in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        where FileManager.default.isExecutableFile(atPath: path) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["auth", "token"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { continue }
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let data = try? pipe.fileHandleForReading.readToEnd(),
                  let token = String(data: data, encoding: .utf8)?
                      .trimmingCharacters(in: .whitespacesAndNewlines),
                  !token.isEmpty
            else { continue }
            cachedToken = token
            return token
        }
        return nil
    }

    private static let query = """
    query {
      viewer { login }
      reviewRequested: search(query: "type:pr state:open review-requested:@me archived:false", type: ISSUE, first: 30) {
        issueCount
        nodes { ...prFields }
      }
      mine: search(query: "type:pr state:open author:@me archived:false", type: ISSUE, first: 50) {
        issueCount
        nodes { ...prFields }
      }
    }
    fragment prFields on PullRequest {
      id title number url isDraft updatedAt mergeable reviewDecision
      repository { nameWithOwner }
      author { login }
      comments(last: 1) { totalCount nodes { author { login } updatedAt } }
      reviews(last: 1) { totalCount nodes { author { login } updatedAt } }
      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
    }
    """

    static func fetchInbox() async throws -> (login: String, reviewRequested: [PR], mine: [PR]) {
        guard let token = findToken() else {
            throw GitHubError(message: "No GitHub token found. Run `gh auth login` or set GITHUB_TOKEN.")
        }
        var request = URLRequest(url: URL(string: "https://api.github.com/graphql")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["query": query])

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            if http.statusCode == 401 { cachedToken = nil }
            throw GitHubError(message: "GitHub API returned HTTP \(http.statusCode)")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GQLResponse.self, from: data)
        if let errors = decoded.errors, !errors.isEmpty {
            throw GitHubError(message: errors.map(\.message).joined(separator: "; "))
        }
        guard let body = decoded.data else {
            throw GitHubError(message: "Empty response from GitHub")
        }
        return (
            login: body.viewer.login,
            reviewRequested: body.reviewRequested.nodes.compactMap { $0.flatMap(makePR) },
            mine: body.mine.nodes.compactMap { $0.flatMap(makePR) }
        )
    }

    private static func latestAuthor(_ counts: GQLResponse.Node.Count?...) -> String? {
        counts
            .flatMap { $0?.nodes ?? [] }
            .compactMap { $0 }
            .compactMap { item in item.updatedAt.map { ($0, item.author?.login) } }
            .max { $0.0 < $1.0 }?.1
    }

    private static func makePR(_ node: GQLResponse.Node) -> PR? {
        guard let id = node.id, let title = node.title, let number = node.number,
              let url = node.url, let updatedAt = node.updatedAt, let repo = node.repository
        else { return nil }
        return PR(
            id: id,
            title: title,
            number: number,
            url: url,
            isDraft: node.isDraft ?? false,
            updatedAt: updatedAt,
            repo: repo.nameWithOwner,
            author: node.author?.login ?? "ghost",
            activityCount: (node.comments?.totalCount ?? 0) + (node.reviews?.totalCount ?? 0),
            lastActivityAuthor: latestAuthor(node.comments, node.reviews),
            reviewDecision: node.reviewDecision,
            checkState: node.commits?.nodes.first?.commit.statusCheckRollup?.state,
            mergeable: node.mergeable
        )
    }
}

private struct GQLResponse: Decodable {
    struct Body: Decodable {
        let viewer: Viewer
        let reviewRequested: Search
        let mine: Search
    }
    struct Viewer: Decodable { let login: String }
    struct Search: Decodable {
        let issueCount: Int
        let nodes: [Node?]
    }
    struct Node: Decodable {
        struct Repo: Decodable { let nameWithOwner: String }
        struct Author: Decodable { let login: String }
        struct Count: Decodable {
            struct Item: Decodable {
                let author: Author?
                let updatedAt: Date?
            }
            let totalCount: Int
            let nodes: [Item?]?
        }
        struct Commits: Decodable {
            struct CommitNode: Decodable { let commit: Commit }
            struct Commit: Decodable { let statusCheckRollup: Rollup? }
            struct Rollup: Decodable { let state: String }
            let nodes: [CommitNode]
        }
        let id: String?
        let title: String?
        let number: Int?
        let url: String?
        let isDraft: Bool?
        let updatedAt: Date?
        let mergeable: String?
        let reviewDecision: String?
        let repository: Repo?
        let author: Author?
        let comments: Count?
        let reviews: Count?
        let commits: Commits?
    }
    struct Err: Decodable { let message: String }
    let data: Body?
    let errors: [Err]?
}
