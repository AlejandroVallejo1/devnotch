import Foundation
import SwiftUI

final class Preferences: ObservableObject {
    @AppStorage("hoverActivation") var hoverActivation: Bool = true
    @AppStorage("expandDelayMs") var expandDelayMs: Int = 80
    @AppStorage("collapseDelayMs") var collapseDelayMs: Int = 250

    /// Session/weekly token budgets. Anthropic doesn't expose the exact token
    /// equivalents of plan quotas, so these are user-tunable. Defaults are
    /// generous so the bar doesn't visually max out for heavy users.
    @AppStorage("sessionTokenLimit") var sessionTokenLimit: Int = 150_000_000
    @AppStorage("weeklyTokenLimit") var weeklyTokenLimit: Int = 1_500_000_000

    @AppStorage("notifyAtPercent") var notifyAtPercent: Int = 80
    @AppStorage("showVolumeHUD") var showVolumeHUD: Bool = true
}

struct PreferencesView: View {
    @EnvironmentObject var prefs: Preferences
    @ObservedObject private var auth = ClaudeAuth.shared

    var body: some View {
        Form {
            Section("Claude account") {
                if auth.isAuthenticated {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connected")
                                .font(.system(size: 12, weight: .semibold))
                            if let email = auth.accountEmail {
                                Text(email).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Sign out") { auth.signOut() }
                            .buttonStyle(.bordered)
                    }
                } else {
                    HStack {
                        Text("Not connected").foregroundStyle(.secondary)
                        Spacer()
                        Button("Connect to claude.ai") {
                            ClaudeLoginWindowController.shared.present()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Text("Signs you in to claude.ai in a secure window to show your real plan meter. Session cookie is stored in macOS Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Section("Behavior") {
                Toggle("Expand on hover", isOn: $prefs.hoverActivation)
                Stepper("Expand delay: \(prefs.expandDelayMs) ms", value: $prefs.expandDelayMs, in: 0...500, step: 20)
                Stepper("Collapse delay: \(prefs.collapseDelayMs) ms", value: $prefs.collapseDelayMs, in: 0...1000, step: 50)
            }
            Section("Local token limits (used when not connected)") {
                HStack {
                    Text("Session (5h)")
                    Spacer()
                    TextField("tokens", value: $prefs.sessionTokenLimit, format: .number).frame(width: 140)
                }
                HStack {
                    Text("Weekly")
                    Spacer()
                    TextField("tokens", value: $prefs.weeklyTokenLimit, format: .number).frame(width: 140)
                }
                Stepper("Notify at \(prefs.notifyAtPercent)%", value: $prefs.notifyAtPercent, in: 50...100, step: 5)
            }
            Section("Features") {
                Toggle("Show volume HUD", isOn: $prefs.showVolumeHUD)
            }
            Section("Support") {
                SupportLinkRow(
                    symbol: "star.fill",
                    tint: .yellow,
                    title: "Star on GitHub",
                    subtitle: "Support the project with a star",
                    url: "https://github.com/AlejandroVallejo1/devnotch"
                )
                SupportLinkRow(
                    symbol: "cup.and.saucer.fill",
                    tint: .orange,
                    title: "Buy me a coffee",
                    subtitle: "Support development",
                    url: "https://buymeacoffee.com/alejandrovallejo"
                )
                SupportLinkRow(
                    symbol: "ant.fill",
                    tint: .red,
                    title: "Report a Bug",
                    subtitle: "Open a GitHub issue",
                    url: "https://github.com/AlejandroVallejo1/devnotch/issues/new"
                )
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}

struct SupportLinkRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    let url: String

    var body: some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 12, weight: .semibold))
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
