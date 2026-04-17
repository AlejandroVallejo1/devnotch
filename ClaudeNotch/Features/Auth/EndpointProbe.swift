#if DEBUG
import AppKit
import Foundation

/// Debug-only: probes candidate claude.ai endpoints using the stored session
/// cookie so we can discover or recover the live-usage path if it changes.
@MainActor
enum EndpointProbe {
    struct Result {
        let path: String
        let httpStatus: Int
        let hasUsageFields: Bool
        let matchedFields: [String]
        let preview: String
    }

    static func run() async {
        guard let sessionKey = ClaudeAuth.shared.sessionKey else {
            show(message: "Not signed in", info: "Use Connect to claude.ai… first.")
            return
        }
        let orgUUID = ClaudeAuth.shared.organizationUUID

        var paths = [
            "/api/organizations",
            "/api/account"
        ]
        if let u = orgUUID {
            paths.append(contentsOf: [
                "/api/bootstrap/\(u)",
                "/api/bootstrap/\(u)/full",
                "/api/organizations/\(u)",
                "/api/organizations/\(u)/usage",
                "/api/organizations/\(u)/usage_statistics",
                "/api/organizations/\(u)/usage_quotas",
                "/api/organizations/\(u)/usage_data",
                "/api/organizations/\(u)/rate_limit",
                "/api/organizations/\(u)/rate_limits",
                "/api/organizations/\(u)/rate_limit_status",
                "/api/organizations/\(u)/chat_conversations/recent_rate_limit",
                "/api/organizations/\(u)/statsig"
            ])
        }

        var results: [Result] = []
        for path in paths {
            if let r = await probe(path: path, sessionKey: sessionKey) {
                results.append(r)
            }
        }

        let winners = results.filter { $0.hasUsageFields }
        var text = "Probed \(results.count) endpoints. \(winners.count) returned usage-like fields.\n\n"
        for r in results {
            let marker = r.hasUsageFields ? "*" : (r.httpStatus == 200 ? "·" : "x")
            text += "\(marker) [\(r.httpStatus)] \(r.path)\n"
            if !r.matchedFields.isEmpty {
                text += "   fields: \(r.matchedFields.prefix(6).joined(separator: ", "))\n"
            }
        }

        // Always include full bodies of the 2 critical paths so we can write parsers.
        let interesting = results.filter {
            $0.hasUsageFields &&
            ($0.path.hasSuffix("/usage") || $0.path.hasSuffix("/rate_limits"))
        }
        for r in interesting {
            text += "\n================ \(r.path) (full body) ================\n"
            text += r.preview
            text += "\n"
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        show(message: "Endpoint probe complete — copied to clipboard",
             info: text.prefix(2000).description)
    }

    private static func probe(path: String, sessionKey: String) async -> Result? {
        guard let url = URL(string: "https://claude.ai" + path) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("https://claude.ai/", forHTTPHeaderField: "Referer")
        request.setValue("DevNotch/0.1 (macOS)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else {
            return Result(path: path, httpStatus: 0, hasUsageFields: false, matchedFields: [], preview: "")
        }

        let text = String(data: data, encoding: .utf8) ?? ""
        let keywords = ["percent", "pct", "resets", "used", "limit", "usage", "rate"]
        // Extract JSON keys that contain any of the keywords.
        let keyPattern = try? NSRegularExpression(
            pattern: "\"([a-z_]*(percent|pct|resets|used|limit|usage|rate)[a-z_]*)\"\\s*:",
            options: .caseInsensitive
        )
        var matched: [String] = []
        if let re = keyPattern {
            let range = NSRange(text.startIndex..., in: text)
            re.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1,
                      let r = Range(match.range(at: 1), in: text) else { return }
                let key = String(text[r])
                if !matched.contains(key) { matched.append(key) }
            }
        }
        let hasAny = !matched.isEmpty
        _ = keywords  // silence warning

        // Keep a larger preview for critical paths so the full shape is visible.
        let wantFull = path.hasSuffix("/usage") || path.hasSuffix("/rate_limits")
        let preview = wantFull ? String(text.prefix(8000)) : String(text.prefix(800))
        return Result(
            path: path,
            httpStatus: http.statusCode,
            hasUsageFields: hasAny,
            matchedFields: matched,
            preview: preview
        )
    }

    private static func show(message: String, info: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
#endif
