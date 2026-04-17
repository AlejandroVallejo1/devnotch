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
}

struct PreferencesView: View {
    @EnvironmentObject var prefs: Preferences
    @ObservedObject private var auth = ClaudeAuth.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                SettingsCard(title: "Claude account") {
                    accountSection
                }

                SettingsCard(title: "Behavior") {
                    behaviorSection
                }

                SettingsCard(
                    title: "Local token limits",
                    footnote: "Used when you aren't signed in to claude.ai. Tune to your plan."
                ) {
                    limitsSection
                }

                SettingsCard(title: "Support") {
                    supportSection
                }

                Text("v0.1.0 · DevNotch · MIT")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .padding(24)
        }
        .frame(width: 520, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DevNotch")
                .font(.system(size: 22, weight: .semibold, design: .serif))
            Text("Live Claude usage in your notch. One-click session resume.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        if auth.isAuthenticated {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(red: 0x4D/255, green: 0x7E/255, blue: 0xEB/255))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connected")
                        .font(.system(size: 12, weight: .semibold))
                    if let email = auth.accountEmail {
                        Text(email)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Sign out") { auth.signOut() }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Text("Not connected")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button("Connect to claude.ai") {
                        ClaudeLoginWindowController.shared.present()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                Text("Signs you in to claude.ai in a secure window to show your real plan meter. The session cookie is stored only in macOS Keychain.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Expand on hover", isOn: $prefs.hoverActivation)
                .toggleStyle(.switch)

            LabeledStepper(
                label: "Expand delay",
                value: $prefs.expandDelayMs,
                range: 0...500,
                step: 20,
                suffix: "ms"
            )
            LabeledStepper(
                label: "Collapse delay",
                value: $prefs.collapseDelayMs,
                range: 0...1000,
                step: 50,
                suffix: "ms"
            )
        }
    }

    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledTokenField(
                label: "Session (5h)",
                value: $prefs.sessionTokenLimit
            )
            LabeledTokenField(
                label: "Weekly",
                value: $prefs.weeklyTokenLimit
            )
            LabeledStepper(
                label: "Notify at",
                value: $prefs.notifyAtPercent,
                range: 50...100,
                step: 5,
                suffix: "%"
            )
        }
    }

    private var supportSection: some View {
        VStack(spacing: 8) {
            SupportLinkRow(
                symbol: "star.fill",
                tint: Color(red: 0xC9/255, green: 0xA9/255, blue: 0x59/255),
                title: "Star on GitHub",
                subtitle: "github.com/AlejandroVallejo1/devnotch",
                url: "https://github.com/AlejandroVallejo1/devnotch"
            )
            Divider().opacity(0.5)
            SupportLinkRow(
                symbol: "cup.and.saucer.fill",
                tint: Color(red: 0xD9/255, green: 0x77/255, blue: 0x57/255),
                title: "Buy me a coffee",
                subtitle: "buymeacoffee.com/alejandrovallejo",
                url: "https://buymeacoffee.com/alejandrovallejo"
            )
            Divider().opacity(0.5)
            SupportLinkRow(
                symbol: "ladybug.fill",
                tint: Color(red: 0xC9/255, green: 0x64/255, blue: 0x48/255),
                title: "Report a bug",
                subtitle: "Open an issue on GitHub",
                url: "https://github.com/AlejandroVallejo1/devnotch/issues/new"
            )
        }
    }
}

// MARK: - Card

private struct SettingsCard<Content: View>: View {
    let title: String
    var footnote: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 0) {
                content()
                    .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )

            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Reusable rows

private struct LabeledStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let suffix: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            Text("\(value)\(suffix.isEmpty ? "" : " \(suffix)")")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
    }
}

private struct LabeledTokenField: View {
    let label: String
    @Binding var value: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            TextField("", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 160)
            Text("tokens")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

struct SupportLinkRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    let url: String

    @State private var hovered = false

    var body: some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 30, height: 30)
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(hovered ? .primary : .tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
