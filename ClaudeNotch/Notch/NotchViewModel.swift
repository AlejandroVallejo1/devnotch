import Combine
import SwiftUI

@MainActor
final class NotchViewModel: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable {
        case usage, sessions
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .usage:    return "chart.bar.xaxis"
            case .sessions: return "terminal"
            }
        }
    }

    @Published var isHovered: Bool = false
    @Published var isPinned: Bool = false
    @Published var activeTab: Tab = .usage

    // Feature state
    @Published private(set) var usage: UsageSnapshot = .empty
    @Published private(set) var sessions: [SessionInfo] = []

    var isExpanded: Bool { isHovered || isPinned }

    private var cancellables = Set<AnyCancellable>()

    func wire(
        usage: UsageTracker,
        sessions: SessionMonitor,
        preferences: Preferences
    ) {
        usage.$snapshot
            .receive(on: DispatchQueue.main)
            .assign(to: &$usage)
        sessions.$sessions
            .receive(on: DispatchQueue.main)
            .assign(to: &$sessions)
    }

    func setHovered(_ hovered: Bool) {
        guard isHovered != hovered else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            isHovered = hovered
        }
    }
}
