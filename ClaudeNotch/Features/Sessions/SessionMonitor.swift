import Foundation
import Combine

enum SessionState: Equatable {
    case running(tool: String?)
    case idle
    case ended

    var label: String {
        switch self {
        case .running(let tool): return tool.map { "using \($0)" } ?? "thinking"
        case .idle:              return "idle"
        case .ended:             return "ended"
        }
    }

    var color: SessionStateColor {
        switch self {
        case .running: return .active
        case .idle:    return .warm
        case .ended:   return .dim
        }
    }
}

enum SessionStateColor { case active, warm, dim }

struct SessionInfo: Identifiable, Equatable {
    let id: String
    let projectName: String
    let cwd: String?
    let gitBranch: String?
    let state: SessionState
    let lastActivity: Date
    let startedAt: Date?
    let tokens: Int          // weighted tokens
    let fileURL: URL
    /// Short summary — first user message, truncated. Helps identify "which
    /// conversation was this?" at a glance.
    let summary: String?
}

/// Lists Claude Code sessions with rich developer context: git branch, cwd,
/// last tool invoked, and weighted token cost per session.
@MainActor
final class SessionMonitor: ObservableObject {
    @Published private(set) var sessions: [SessionInfo] = []

    private let fileManager = FileManager.default
    private var timer: Timer?

    private var claudeProjectsURL: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects", isDirectory: true)
    }

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func refresh() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let found = self.scan()
            await MainActor.run {
                self.sessions = found
            }
        }
    }

    nonisolated private func scan() -> [SessionInfo] {
        let fileManager = FileManager.default
        let root = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects", isDirectory: true)
        guard fileManager.fileExists(atPath: root.path),
              let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else { return [] }

        var results: [SessionInfo] = []
        let now = Date()
        let visibleCutoff = now.addingTimeInterval(-24 * 3600)
        let runningCutoff = now.addingTimeInterval(-30)

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            if url.path.contains("/subagents/") { continue }

            guard let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let mtime = attrs.contentModificationDate,
                  mtime > visibleCutoff else { continue }

            let sessionId = url.deletingPathExtension().lastPathComponent
            if let info = buildSessionInfo(
                url: url,
                sessionId: sessionId,
                mtime: mtime,
                runningCutoff: runningCutoff
            ) {
                results.append(info)
            }
        }

        return results.sorted { a, b in
            let aRunning = a.state == .running(tool: nil) || isRunning(a.state)
            let bRunning = b.state == .running(tool: nil) || isRunning(b.state)
            if aRunning != bRunning { return aRunning && !bRunning }
            return a.lastActivity > b.lastActivity
        }
    }

    private nonisolated func isRunning(_ state: SessionState) -> Bool {
        if case .running = state { return true }
        return false
    }

    /// Streams the JSONL once to extract: cwd, first timestamp, last timestamp,
    /// total weighted tokens, and the last tool_use encountered.
    private nonisolated func buildSessionInfo(
        url: URL,
        sessionId: String,
        mtime: Date,
        runningCutoff: Date
    ) -> SessionInfo? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        var cwd: String?
        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var weightedTokens: Int = 0
        var lastTool: String?
        var firstUserText: String?

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        text.enumerateLines { line, _ in
            guard let ld = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: ld) as? [String: Any] else { return }

            if cwd == nil, let c = obj["cwd"] as? String { cwd = c }

            if let ts = obj["timestamp"] as? String, let d = iso.date(from: ts) {
                if firstTimestamp == nil { firstTimestamp = d }
                lastTimestamp = d
            }

            // Capture the first user message text as the session summary.
            if firstUserText == nil, (obj["type"] as? String) == "user",
               let message = obj["message"] as? [String: Any] {
                if let s = message["content"] as? String {
                    firstUserText = Self.cleanSummary(s)
                } else if let arr = message["content"] as? [[String: Any]] {
                    for block in arr {
                        if (block["type"] as? String) == "text",
                           let t = block["text"] as? String {
                            firstUserText = Self.cleanSummary(t)
                            break
                        }
                    }
                }
            }

            if let message = obj["message"] as? [String: Any] {
                if let usage = message["usage"] as? [String: Any] {
                    let tb = TokenBreakdown(
                        input:       (usage["input_tokens"] as? Int) ?? 0,
                        output:      (usage["output_tokens"] as? Int) ?? 0,
                        cacheCreate: (usage["cache_creation_input_tokens"] as? Int) ?? 0,
                        cacheRead:   (usage["cache_read_input_tokens"] as? Int) ?? 0
                    )
                    weightedTokens += tb.weighted
                }
                // tool_use blocks live in message.content[] (assistant messages).
                if (obj["type"] as? String) == "assistant",
                   let content = message["content"] as? [[String: Any]] {
                    for block in content.reversed() {
                        if (block["type"] as? String) == "tool_use",
                           let name = block["name"] as? String {
                            lastTool = name
                            break
                        }
                    }
                }
            }
        }

        let projectName = Self.prettifyProject(dir: url.deletingLastPathComponent().lastPathComponent, cwd: cwd)
        let branch = cwd.flatMap(Self.readGitBranch)

        let state: SessionState
        if mtime > runningCutoff {
            state = .running(tool: lastTool)
        } else if mtime > Date().addingTimeInterval(-5 * 60) {
            state = .idle
        } else {
            state = .ended
        }

        return SessionInfo(
            id: sessionId,
            projectName: projectName,
            cwd: cwd,
            gitBranch: branch,
            state: state,
            lastActivity: lastTimestamp ?? mtime,
            startedAt: firstTimestamp,
            tokens: weightedTokens,
            fileURL: url,
            summary: firstUserText
        )
    }

    /// Strips leading system reminders / tool responses so the summary shows
    /// the actual first thing the user typed.
    nonisolated private static func cleanSummary(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Claude Code often wraps the very first "user" message with system
        // reminders like <system-reminder>…</system-reminder>. Skip those.
        while s.hasPrefix("<") {
            guard let close = s.range(of: ">"),
                  let tagEnd = s[close.upperBound...].range(of: "</", options: .literal) else { break }
            let afterClose = s[close.upperBound...]
            if let closingTag = afterClose.range(of: ">\n", range: tagEnd.lowerBound..<s.endIndex) {
                s = String(s[closingTag.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                break
            }
        }
        // Collapse whitespace, cap length.
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        if s.isEmpty { return nil }
        if s.count > 90 { s = String(s.prefix(87)) + "…" }
        return s
    }

    // MARK: - Helpers

    nonisolated private static func prettifyProject(dir: String, cwd: String?) -> String {
        if let cwd {
            return (cwd as NSString).lastPathComponent
        }
        // Folder names look like "-Users-name-path-project"; take the last segment.
        let parts = dir.split(separator: "-")
        return String(parts.last ?? Substring(dir))
    }

    nonisolated private static func readGitBranch(cwd: String) -> String? {
        let headPath = (cwd as NSString).appendingPathComponent(".git/HEAD")
        guard FileManager.default.fileExists(atPath: headPath),
              let content = try? String(contentsOfFile: headPath, encoding: .utf8) else {
            return nil
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("ref: refs/heads/") {
            return String(trimmed.dropFirst("ref: refs/heads/".count))
        }
        // Detached HEAD: show short SHA
        return String(trimmed.prefix(7))
    }
}
