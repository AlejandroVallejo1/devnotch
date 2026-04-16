import Foundation

/// Client for internal (undocumented) claude.ai endpoints, authenticated via the
/// `sessionKey` cookie captured from a WKWebView login.
///
/// ⚠️ These endpoints are NOT a public API. Anthropic can change them without
/// notice. We fetch defensively and fall back to local data if anything fails.
struct ClaudeWebAPI {
    let sessionKey: String
    let organizationUUID: String?

    private let base = URL(string: "https://claude.ai")!

    enum APIError: Error {
        case badResponse
        case missingOrganization
    }

    struct RateLimitSnapshot {
        var sessionPercent: Double
        var sessionResetsIn: TimeInterval?
        var weeklyPercent: Double?
        var weeklyResetsIn: TimeInterval?
        var sonnetPercent: Double?
        var sonnetResetsIn: TimeInterval?
        var extraPercent: Double?
        var extraUsedCredits: Double?
        var extraMonthlyLimit: Double?
        var extraCurrency: String?
        var extraResetsIn: TimeInterval?
        var planName: String?
        var raw: [String: Any]
    }

    // MARK: - Public

    func fetchAccountInfo() async throws -> (organizationUUID: String?, email: String?) {
        let json = try await getJSON(path: "/api/organizations")
        // Response is an array of orgs. Pick the first personal/primary one.
        guard let orgs = json as? [[String: Any]] else { throw APIError.badResponse }
        let primary = orgs.first
        let uuid = primary?["uuid"] as? String
        let email: String? = {
            if let members = primary?["members"] as? [[String: Any]],
               let me = members.first,
               let user = me["user"] as? [String: Any],
               let e = user["email_address"] as? String {
                return e
            }
            return primary?["name"] as? String
        }()
        return (uuid, email)
    }

    func fetchRateLimit() async throws -> RateLimitSnapshot {
        guard let orgUUID = organizationUUID else { throw APIError.missingOrganization }

        let json = try await getJSON(path: "/api/organizations/\(orgUUID)/usage")
        guard let dict = json as? [String: Any] else { throw APIError.badResponse }

        func bucket(_ key: String) -> (Double, TimeInterval?)? {
            guard let block = dict[key] as? [String: Any],
                  let util = block["utilization"] as? Double else { return nil }
            let resetsIn: TimeInterval? = {
                guard let ts = block["resets_at"] as? String else { return nil }
                return Self.iso.date(from: ts)?.timeIntervalSinceNow
            }()
            return (util / 100.0, resetsIn)
        }

        let session = bucket("five_hour")
        let weekly  = bucket("seven_day")
        let sonnet  = bucket("seven_day_sonnet")

        // Pay-as-you-go ("extra_usage") block — used_credits is absolute dollar
        // amount; utilization is pre-computed percent.
        var extraPct: Double?
        var extraUsed: Double?
        var extraLimit: Double?
        var extraCurrency: String?
        var extraResets: TimeInterval?
        if let extra = dict["extra_usage"] as? [String: Any] {
            // API returns used_credits/monthly_limit in cents. Convert to dollars for display.
            let usedCents = (extra["used_credits"] as? Double) ?? 0
            let limitCents: Double = {
                if let m = extra["monthly_limit"] as? Double { return m }
                if let m = extra["monthly_limit"] as? Int { return Double(m) }
                return 0
            }()
            extraUsed = usedCents / 100.0
            extraLimit = limitCents / 100.0
            // Use the real ratio (Anthropic caps utilization at 100 even when you overflow).
            if limitCents > 0 { extraPct = usedCents / limitCents }
            else if let u = extra["utilization"] as? Double { extraPct = u / 100.0 }
            extraCurrency = extra["currency"] as? String
            if let ts = extra["resets_at"] as? String,
               let d = Self.iso.date(from: ts) {
                extraResets = d.timeIntervalSinceNow
            }
        }

        let planName = (dict["rate_limit_tier"] as? String) ?? nil

        return RateLimitSnapshot(
            sessionPercent: session?.0 ?? 0,
            sessionResetsIn: session?.1,
            weeklyPercent: weekly?.0,
            weeklyResetsIn: weekly?.1,
            sonnetPercent: sonnet?.0,
            sonnetResetsIn: sonnet?.1,
            extraPercent: extraPct,
            extraUsedCredits: extraUsed,
            extraMonthlyLimit: extraLimit,
            extraCurrency: extraCurrency,
            extraResetsIn: extraResets,
            planName: planName,
            raw: dict
        )
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - HTTP plumbing

    private func getJSON(path: String) async throws -> Any {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("ClaudeNotch/0.1 (macOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://claude.ai/", forHTTPHeaderField: "Referer")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse
        }
        return try JSONSerialization.jsonObject(with: data)
    }

}
