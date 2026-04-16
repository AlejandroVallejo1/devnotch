import Foundation

enum FormatHelpers {
    static func compactNumber(_ n: Int) -> String {
        let absN = abs(n)
        switch absN {
        case 1_000_000...:
            return String(format: "%.2fM", Double(n) / 1_000_000)
        case 10_000...:
            return String(format: "%.0fK", Double(n) / 1_000)
        case 1_000...:
            return String(format: "%.1fK", Double(n) / 1_000)
        default:
            return "\(n)"
        }
    }

    static func duration(from date: Date, to end: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(date)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)min" }
        return "\(m)min"
    }

    static func relativeDuration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        if s < 60 { return "\(s)s" }
        let m = s / 60
        if m < 60 { return "\(m)m" }
        let h = m / 60
        return "\(h)h \(m % 60)m"
    }
}
