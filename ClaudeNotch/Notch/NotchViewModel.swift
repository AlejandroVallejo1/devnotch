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
    @Published var volumeHUD: VolumeHUDState?

    // Feature state
    @Published private(set) var usage: UsageSnapshot = .empty
    @Published private(set) var sessions: [SessionInfo] = []

    var isExpanded: Bool { isHovered || isPinned || volumeHUD != nil }

    private var cancellables = Set<AnyCancellable>()
    private var hudHideWork: DispatchWorkItem?

    func wire(
        usage: UsageTracker,
        sessions: SessionMonitor,
        volume: VolumeService,
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

    func showVolumeHUD(level: Float) {
        let state = VolumeHUDState(level: level)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.volumeHUD = state
        }
        hudHideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                self.volumeHUD = nil
            }
        }
        hudHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }
}

struct VolumeHUDState: Equatable {
    let level: Float
}
