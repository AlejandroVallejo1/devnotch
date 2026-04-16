import Foundation

struct TokenBreakdown: Equatable {
    var input: Int = 0
    var output: Int = 0
    var cacheCreate: Int = 0
    var cacheRead: Int = 0

    /// Sum of all four raw counts. Cache-read dominates, so this is usually an
    /// order of magnitude larger than "useful" work.
    var total: Int { input + output + cacheCreate + cacheRead }

    /// Weighted-by-cost tokens — mirrors Anthropic's API pricing ratios and
    /// correlates much more closely with the opaque % shown in claude.ai.
    ///
    ///     weighted = input × 1 + output × 5 + cacheCreate × 1.25 + cacheRead × 0.1
    var weighted: Int {
        Int(
            Double(input) * 1.0
            + Double(output) * 5.0
            + Double(cacheCreate) * 1.25
            + Double(cacheRead) * 0.1
        )
    }

    static func +(lhs: TokenBreakdown, rhs: TokenBreakdown) -> TokenBreakdown {
        TokenBreakdown(
            input: lhs.input + rhs.input,
            output: lhs.output + rhs.output,
            cacheCreate: lhs.cacheCreate + rhs.cacheCreate,
            cacheRead: lhs.cacheRead + rhs.cacheRead
        )
    }

    static func +=(lhs: inout TokenBreakdown, rhs: TokenBreakdown) { lhs = lhs + rhs }
}

enum ModelFamily: String, CaseIterable {
    case opus, sonnet, haiku, other

    static func from(_ model: String) -> ModelFamily {
        let lower = model.lowercased()
        if lower.contains("opus") { return .opus }
        if lower.contains("sonnet") { return .sonnet }
        if lower.contains("haiku") { return .haiku }
        return .other
    }

    var displayName: String {
        switch self {
        case .opus: return "Opus"
        case .sonnet: return "Sonnet"
        case .haiku: return "Haiku"
        case .other: return "Other"
        }
    }
}

struct LiveUsage: Equatable {
    var sessionPercent: Double
    var sessionResetsIn: TimeInterval?
    var weeklyPercent: Double?
    var weeklyResetsIn: TimeInterval?

    /// Weekly quota restricted to Sonnet specifically (null if N/A on plan).
    var sonnetPercent: Double?
    var sonnetResetsIn: TimeInterval?

    /// Pay-as-you-go credit usage on top of the plan allowance.
    var extraPercent: Double?
    var extraUsedCredits: Double?
    var extraMonthlyLimit: Double?
    var extraCurrency: String?
    var extraResetsIn: TimeInterval?

    var planName: String?
}

struct UsageSnapshot: Equatable {
    var sessionStart: Date?
    var sessionEnd: Date?
    var sessionTokens: TokenBreakdown
    var weeklyTokens: TokenBreakdown
    var byModelSession: [ModelFamily: TokenBreakdown]
    var byModelWeekly: [ModelFamily: TokenBreakdown]
    var lastUpdated: Date

    var sessionLimit: Int
    var weeklyLimit: Int

    /// When the user is connected to claude.ai, this carries the "real" plan
    /// meter values. UI prefers these over the local-token approximation.
    var live: LiveUsage?

    /// When a live fetch was attempted but failed, this explains why.
    var liveError: String?

    /// Percentages prefer the live claude.ai plan meter when available,
    /// falling back to weighted-token approximation from Claude Code logs.
    var sessionPercent: Double {
        if let live = live?.sessionPercent { return live }
        guard sessionLimit > 0 else { return 0 }
        return Double(sessionTokens.weighted) / Double(sessionLimit)
    }
    var weeklyPercent: Double {
        if let live = live?.weeklyPercent { return live }
        guard weeklyLimit > 0 else { return 0 }
        return Double(weeklyTokens.weighted) / Double(weeklyLimit)
    }

    var sessionResetsIn: TimeInterval? {
        if let live = live?.sessionResetsIn { return live }
        guard let end = sessionEnd else { return nil }
        return end.timeIntervalSinceNow
    }

    var weeklyResetsIn: TimeInterval? { live?.weeklyResetsIn }

    var isLive: Bool { live != nil }

    static let empty = UsageSnapshot(
        sessionStart: nil,
        sessionEnd: nil,
        sessionTokens: TokenBreakdown(),
        weeklyTokens: TokenBreakdown(),
        byModelSession: [:],
        byModelWeekly: [:],
        lastUpdated: .distantPast,
        sessionLimit: 150_000_000,
        weeklyLimit: 1_500_000_000,
        live: nil,
        liveError: nil
    )
}
