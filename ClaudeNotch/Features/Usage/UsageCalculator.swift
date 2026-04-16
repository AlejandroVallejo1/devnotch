import Foundation

/// Parses a single JSONL line and returns (timestamp, model family, tokens) if it's an assistant message with usage.
enum UsageCalculator {
    /// Anthropic's Max plan billing session is a 5h rolling window that begins
    /// with the first assistant reply after a >5h gap.
    static let sessionWindow: TimeInterval = 5 * 60 * 60
    static let weeklyWindow: TimeInterval = 7 * 24 * 60 * 60

    struct ParsedEvent {
        let timestamp: Date
        let model: ModelFamily
        let tokens: TokenBreakdown
    }

    static func parseLine(_ line: String) -> ParsedEvent? {
        guard let data = line.data(using: .utf8) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard (obj["type"] as? String) == "assistant" else { return nil }
        guard let message = obj["message"] as? [String: Any] else { return nil }
        guard let usage = message["usage"] as? [String: Any] else { return nil }

        let timestamp: Date = {
            if let ts = obj["timestamp"] as? String {
                return Self.iso.date(from: ts) ?? Date()
            }
            return Date()
        }()

        let modelString = (message["model"] as? String) ?? ""
        let family = ModelFamily.from(modelString)

        let tokens = TokenBreakdown(
            input: (usage["input_tokens"] as? Int) ?? 0,
            output: (usage["output_tokens"] as? Int) ?? 0,
            cacheCreate: (usage["cache_creation_input_tokens"] as? Int) ?? 0,
            cacheRead: (usage["cache_read_input_tokens"] as? Int) ?? 0
        )
        if tokens.total == 0 { return nil }

        return ParsedEvent(timestamp: timestamp, model: family, tokens: tokens)
    }

    /// Computes a usage snapshot from a flat list of events (any order).
    static func snapshot(
        from events: [ParsedEvent],
        now: Date = Date(),
        sessionLimit: Int,
        weeklyLimit: Int
    ) -> UsageSnapshot {
        let sorted = events.sorted { $0.timestamp < $1.timestamp }

        // Build session blocks: Anthropic's 5h window opens at the first message and
        // closes 5h later. The next message after the window closes opens a new block.
        var blocks: [(start: Date, end: Date)] = []
        var currentStart: Date? = nil
        for event in sorted {
            if let start = currentStart {
                if event.timestamp >= start.addingTimeInterval(sessionWindow) {
                    blocks.append((start, start.addingTimeInterval(sessionWindow)))
                    currentStart = event.timestamp
                }
            } else {
                currentStart = event.timestamp
            }
        }
        if let start = currentStart {
            blocks.append((start, start.addingTimeInterval(sessionWindow)))
        }

        // Active block = the one that contains `now`.
        let active = blocks.last { $0.start <= now && $0.end > now }
        let sessionStart = active?.start
        let sessionEnd = active?.end

        let weeklyStart = now.addingTimeInterval(-weeklyWindow)

        var sessionTotal = TokenBreakdown()
        var weeklyTotal = TokenBreakdown()
        var byModelSession: [ModelFamily: TokenBreakdown] = [:]
        var byModelWeekly: [ModelFamily: TokenBreakdown] = [:]

        for event in sorted {
            if event.timestamp >= weeklyStart && event.timestamp <= now {
                weeklyTotal += event.tokens
                byModelWeekly[event.model, default: .init()] += event.tokens
            }
            if let start = active?.start, let end = active?.end,
               event.timestamp >= start, event.timestamp < end {
                sessionTotal += event.tokens
                byModelSession[event.model, default: .init()] += event.tokens
            }
        }

        return UsageSnapshot(
            sessionStart: sessionStart,
            sessionEnd: sessionEnd,
            sessionTokens: sessionTotal,
            weeklyTokens: weeklyTotal,
            byModelSession: byModelSession,
            byModelWeekly: byModelWeekly,
            lastUpdated: now,
            sessionLimit: sessionLimit,
            weeklyLimit: weeklyLimit,
            live: nil,
            liveError: nil
        )
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
