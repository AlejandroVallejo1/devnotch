import SwiftUI

struct NotchRootView: View {
    @EnvironmentObject var vm: NotchViewModel
    let collapsedSize: CGSize

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            NotchContainer(isExpanded: vm.isExpanded, collapsedSize: collapsedSize) {
                if let hud = vm.volumeHUD, !vm.isHovered && !vm.isPinned {
                    VolumeHUDView(state: hud)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if vm.isExpanded {
                    ExpandedContent()
                        .transition(.opacity)
                } else {
                    CollapsedContent()
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct NotchContainer<Content: View>: View {
    let isExpanded: Bool
    let collapsedSize: CGSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        let width: CGFloat = isExpanded ? NotchLayout.expandedSize.width : collapsedSize.width
        let height: CGFloat = isExpanded ? NotchLayout.expandedSize.height : collapsedSize.height

        VStack(spacing: 0) {
            content()
                .frame(width: width, height: height)
                .background(
                    NotchShape(bottomCornerRadius: isExpanded ? 22 : 12)
                        .fill(DS.Palette.background)
                        .overlay(
                            NotchShape(bottomCornerRadius: isExpanded ? 22 : 12)
                                .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
                )
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isExpanded)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

// MARK: - Collapsed

struct CollapsedContent: View {
    @EnvironmentObject var vm: NotchViewModel

    var body: some View {
        HStack(spacing: 6) {
            CollapsedUsagePill(percent: vm.usage.sessionPercent)
            Spacer(minLength: 0)
            CollapsedUsagePill(percent: vm.usage.weeklyPercent)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CollapsedUsagePill: View {
    let percent: Double

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(DS.usageAccent(for: percent))
                .frame(width: 4, height: 4)
            Text("\(Int(min(percent, 1) * 100))%")
                .font(DS.Font.number(9))
                .foregroundStyle(DS.Palette.cream)
        }
    }
}

// MARK: - Expanded

struct ExpandedContent: View {
    @EnvironmentObject var vm: NotchViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(DS.Palette.divider).frame(height: 0.5)
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, 4)
    }

    private var header: some View {
        HStack(spacing: 6) {
            ForEach(NotchViewModel.Tab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        vm.activeTab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 11, weight: .semibold))
                        if vm.activeTab == tab {
                            Text(tab.title)
                                .font(DS.Font.body(10, weight: .medium))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(vm.activeTab == tab ? DS.Palette.coralSoft : .clear)
                    )
                    .foregroundStyle(vm.activeTab == tab ? DS.Palette.coral : DS.Palette.warmGray)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            liveBadge
            Button {
                vm.isPinned.toggle()
            } label: {
                Image(systemName: vm.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(vm.isPinned ? 0 : 45))
                    .foregroundStyle(vm.isPinned ? DS.Palette.coral : DS.Palette.warmGray)
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var liveBadge: some View {
        if vm.usage.isLive {
            HStack(spacing: 4) {
                Circle().fill(DS.Palette.coral).frame(width: 5, height: 5)
                Text("live")
                    .font(DS.Font.body(9, weight: .semibold))
                    .foregroundStyle(DS.Palette.coral)
            }
            .padding(.horizontal, 6)
        } else if let err = vm.usage.liveError {
            HStack(spacing: 4) {
                Circle().fill(DS.Palette.rust).frame(width: 5, height: 5)
                Text("live err")
                    .font(DS.Font.body(9, weight: .semibold))
                    .foregroundStyle(DS.Palette.rust)
            }
            .padding(.horizontal, 6)
            .help(err)
        } else if ClaudeAuth.shared.isAuthenticated {
            HStack(spacing: 4) {
                Circle().fill(DS.Palette.warmGray).frame(width: 5, height: 5)
                Text("syncing")
                    .font(DS.Font.body(9, weight: .semibold))
                    .foregroundStyle(DS.Palette.warmGray)
            }
            .padding(.horizontal, 6)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch vm.activeTab {
        case .usage:    UsageView(snapshot: vm.usage)
        case .sessions: SessionsView(sessions: vm.sessions)
        }
    }
}

private extension NotchViewModel.Tab {
    var title: String {
        switch self {
        case .usage: return "Usage"
        case .sessions: return "Sessions"
        }
    }
}
