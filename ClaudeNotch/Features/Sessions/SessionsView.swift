import SwiftUI

struct SessionsView: View {
    let sessions: [SessionInfo]

    private var runningCount: Int {
        sessions.filter { if case .running = $0.state { return true } else { return false } }.count
    }

    private var totalTokens: Int { sessions.reduce(0) { $0 + $1.tokens } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if sessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(sessions.prefix(6)) { session in
                            SessionRow(session: session)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 6) {
                Circle()
                    .fill(runningCount > 0 ? DS.Palette.coral : DS.Palette.warmGrayDim)
                    .frame(width: 6, height: 6)
                Text("\(runningCount) running")
                    .font(DS.Font.display(13))
                    .foregroundStyle(DS.Palette.cream)
            }
            Spacer()
            Text("\(FormatHelpers.compactNumber(totalTokens)) tok · 24h")
                .font(DS.Font.body(10))
                .foregroundStyle(DS.Palette.warmGrayDim)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 22))
                .foregroundStyle(DS.Palette.warmGrayDim)
            Text("No Claude Code activity")
                .font(DS.Font.body(10))
                .foregroundStyle(DS.Palette.warmGrayDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SessionRow: View {
    let session: SessionInfo
    @State private var showCopied: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            stateIndicator
            VStack(alignment: .leading, spacing: 2) {
                // Top line: the first user message (most useful for "which conv was this?")
                Text(session.summary ?? session.projectName)
                    .font(DS.Font.display(11))
                    .foregroundStyle(DS.Palette.cream)
                    .lineLimit(1)
                    .truncationMode(.tail)
                // Bottom meta: project · branch · state · time · tokens
                HStack(spacing: 5) {
                    Text(session.projectName)
                        .font(DS.Font.body(9, weight: .medium))
                        .foregroundStyle(DS.Palette.warmGray)
                        .lineLimit(1)
                    if let branch = session.gitBranch {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(DS.Palette.progressBlue.opacity(0.9))
                        Text(branch)
                            .font(DS.Font.body(9, weight: .medium))
                            .foregroundStyle(DS.Palette.progressBlue.opacity(0.9))
                            .lineLimit(1)
                    }
                    Text("·").foregroundStyle(DS.Palette.warmGrayDim)
                    Text(session.state.label)
                        .font(DS.Font.body(9))
                        .foregroundStyle(statusColor)
                    Text("·").foregroundStyle(DS.Palette.warmGrayDim)
                    Text(relativeTime(session.lastActivity))
                        .font(DS.Font.body(9))
                        .foregroundStyle(DS.Palette.warmGrayDim)
                    if session.tokens > 0 {
                        Text("·").foregroundStyle(DS.Palette.warmGrayDim)
                        Text("\(FormatHelpers.compactNumber(session.tokens)) tok")
                            .font(DS.Font.number(9))
                            .foregroundStyle(DS.Palette.warmGrayDim)
                    }
                }
            }
            Spacer(minLength: 6)
            copyAffordance
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(showCopied ? DS.Palette.progressBlue.opacity(0.14) : DS.Palette.surface)
        )
        .contentShape(Rectangle())
        .onTapGesture { copyResumeCommand() }
        .help("Click to copy `claude --resume \(session.id)`")
    }

    @ViewBuilder
    private var copyAffordance: some View {
        if showCopied {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("copied · paste in terminal")
                    .font(DS.Font.body(9, weight: .semibold))
            }
            .foregroundStyle(DS.Palette.progressBlue)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else {
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.system(size: 10))
                Text("resume")
                    .font(DS.Font.body(9, weight: .medium))
            }
            .foregroundStyle(DS.Palette.warmGrayDim)
        }
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch session.state {
        case .running:
            ZStack {
                Circle()
                    .stroke(DS.Palette.coral.opacity(0.5), lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .scaleEffect(1.3)
                    .opacity(0)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: session.id)
                Circle()
                    .fill(DS.Palette.coral)
                    .frame(width: 7, height: 7)
            }
            .frame(width: 16, height: 16)
        case .idle:
            Circle()
                .fill(DS.Palette.mustard)
                .frame(width: 7, height: 7)
                .frame(width: 16, height: 16)
        case .ended:
            Circle()
                .fill(DS.Palette.warmGrayDim)
                .frame(width: 7, height: 7)
                .frame(width: 16, height: 16)
        }
    }

    private var statusColor: Color {
        switch session.state.color {
        case .active: return DS.Palette.coral
        case .warm:   return DS.Palette.mustard
        case .dim:    return DS.Palette.warmGrayDim
        }
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func relativeTime(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "just now" }
        return "\(FormatHelpers.relativeDuration(elapsed)) ago"
    }

    private func copyResumeCommand() {
        let command: String
        if let cwd = session.cwd {
            command = "cd \(shellQuote(cwd)) && claude --resume \(session.id)"
        } else {
            command = "claude --resume \(session.id)"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)

        withAnimation(.easeIn(duration: 0.15)) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.25)) { showCopied = false }
        }
    }
}
