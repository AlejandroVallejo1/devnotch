import Foundation
import Combine

/// Scans ~/.claude/projects/**/*.jsonl, parses usage events, and — when the user
/// is signed in to claude.ai — also polls the live plan-meter endpoint.
/// Publishes a unified snapshot.
@MainActor
final class UsageTracker: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot = .empty

    private let fileManager = FileManager.default
    private var localTimer: Timer?
    private var liveTimer: Timer?
    private let workQueue = DispatchQueue(label: "com.devnotch.usage", qos: .utility)
    private var cancellables = Set<AnyCancellable>()

    private var claudeProjectsURL: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects", isDirectory: true)
    }

    func start() {
        refreshLocal()
        refreshLive()

        localTimer?.invalidate()
        localTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshLocal() }
        }

        // Live is polled less frequently (claude.ai API is rate-limited).
        liveTimer?.invalidate()
        liveTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshLive() }
        }

        // Also refresh live immediately when auth state changes.
        ClaudeAuth.shared.$isAuthenticated
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshLive() }
            }
            .store(in: &cancellables)
    }

    func stop() {
        localTimer?.invalidate(); localTimer = nil
        liveTimer?.invalidate();  liveTimer = nil
    }

    func refreshLocal() {
        workQueue.async { [weak self] in
            guard let self else { return }
            let events = self.collectEvents()
            let sessionLimit = UserDefaults.standard.integer(forKey: "sessionTokenLimit").nonZero ?? 150_000_000
            let weeklyLimit  = UserDefaults.standard.integer(forKey: "weeklyTokenLimit").nonZero ?? 1_500_000_000
            var snap = UsageCalculator.snapshot(
                from: events,
                sessionLimit: sessionLimit,
                weeklyLimit: weeklyLimit
            )
            DispatchQueue.main.async {
                snap.live = self.snapshot.live   // preserve the live overlay
                self.snapshot = snap
            }
        }
    }

    func refreshLive() {
        guard let sessionKey = ClaudeAuth.shared.sessionKey else {
            #if DEBUG
            NSLog("[DevNotch] refreshLive: no session key, skipping")
            #endif
            if snapshot.live != nil || snapshot.liveError != nil {
                var s = snapshot
                s.live = nil
                s.liveError = nil
                snapshot = s
            }
            return
        }
        let orgUUID = ClaudeAuth.shared.organizationUUID
        Task { [weak self] in
            let api = ClaudeWebAPI(sessionKey: sessionKey, organizationUUID: orgUUID)
            do {
                let result = try await api.fetchRateLimit()
                await MainActor.run {
                    guard let self else { return }
                    var s = self.snapshot
                    s.live = LiveUsage(
                        sessionPercent: result.sessionPercent,
                        sessionResetsIn: result.sessionResetsIn,
                        weeklyPercent: result.weeklyPercent,
                        weeklyResetsIn: result.weeklyResetsIn,
                        sonnetPercent: result.sonnetPercent,
                        sonnetResetsIn: result.sonnetResetsIn,
                        extraPercent: result.extraPercent,
                        extraUsedCredits: result.extraUsedCredits,
                        extraMonthlyLimit: result.extraMonthlyLimit,
                        extraCurrency: result.extraCurrency,
                        extraResetsIn: result.extraResetsIn,
                        planName: result.planName
                    )
                    s.liveError = nil
                    self.snapshot = s
                }
            } catch {
                #if DEBUG
                NSLog("[DevNotch] refreshLive failed: %@", String(describing: error))
                #endif
                await MainActor.run {
                    guard let self else { return }
                    var s = self.snapshot
                    s.live = nil
                    s.liveError = String(describing: error)
                    self.snapshot = s
                }
            }
        }
    }

    nonisolated private func collectEvents() -> [UsageCalculator.ParsedEvent] {
        let fileManager = FileManager.default
        let claudeProjectsURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects", isDirectory: true)
        guard fileManager.fileExists(atPath: claudeProjectsURL.path) else { return [] }

        var events: [UsageCalculator.ParsedEvent] = []
        let cutoff = Date().addingTimeInterval(-UsageCalculator.weeklyWindow - 3600)

        let jsonlFiles = enumerateJSONLFiles(root: claudeProjectsURL)
        for url in jsonlFiles {
            // Skip files last-modified before our weekly cutoff
            if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
               let mtime = attrs[.modificationDate] as? Date,
               mtime < cutoff {
                continue
            }
            events.append(contentsOf: parseFile(at: url))
        }
        return events
    }

    nonisolated private func enumerateJSONLFiles(root: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [URL] = []
        for case let url as URL in enumerator {
            if url.pathExtension == "jsonl" {
                results.append(url)
            }
        }
        return results
    }

    nonisolated private func parseFile(at url: URL) -> [UsageCalculator.ParsedEvent] {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }

        var events: [UsageCalculator.ParsedEvent] = []
        events.reserveCapacity(64)
        text.enumerateLines { line, _ in
            if let event = UsageCalculator.parseLine(line) {
                events.append(event)
            }
        }
        return events
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
