import SwiftUI

struct UsageView: View {
    let snapshot: UsageSnapshot

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                sessionBlock
                weeklyBlock
                if let sonnet = snapshot.live?.sonnetPercent {
                    sonnetBlock(percent: sonnet, resetsIn: snapshot.live?.sonnetResetsIn)
                }
                if let extra = snapshot.live?.extraPercent {
                    extraBlock(
                        percent: extra,
                        used: snapshot.live?.extraUsedCredits ?? 0,
                        currency: snapshot.live?.extraCurrency ?? "USD",
                        resetsIn: snapshot.live?.extraResetsIn
                    )
                }
                // Only surface Claude-Code-local model breakdown when live data
                // is unavailable — otherwise it's noisy and non-actionable.
                if !snapshot.isLive && !snapshot.byModelWeekly.isEmpty {
                    modelBlock
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Session

    private var sessionBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Current session")
                    .font(DS.Font.display(13))
                    .foregroundStyle(DS.Palette.cream)
                Spacer()
                if let secs = snapshot.sessionResetsIn, secs > 0 {
                    Text("resets in \(FormatHelpers.relativeDuration(secs))")
                        .font(DS.Font.body(10))
                        .foregroundStyle(DS.Palette.warmGray)
                } else {
                    Text("idle")
                        .font(DS.Font.body(10))
                        .foregroundStyle(DS.Palette.warmGrayDim)
                }
            }
            ProgressBar(percent: snapshot.sessionPercent)
            HStack {
                Text(snapshot.isLive
                     ? "\(Int(min(snapshot.sessionPercent, 1) * 100))% of plan"
                     : "\(FormatHelpers.compactNumber(snapshot.sessionTokens.weighted)) weighted tokens")
                    .font(DS.Font.body(10))
                    .foregroundStyle(DS.Palette.warmGray)
                Spacer()
                Text("\(Int(min(snapshot.sessionPercent, 1) * 100))%")
                    .font(DS.Font.number(12, weight: .semibold))
                    .foregroundStyle(DS.Palette.cream)
            }
        }
    }

    // MARK: - Weekly

    private var weeklyBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekly")
                    .font(DS.Font.display(13))
                    .foregroundStyle(DS.Palette.cream)
                Spacer()
                if let secs = snapshot.weeklyResetsIn, secs > 0 {
                    Text("resets in \(FormatHelpers.relativeDuration(secs))")
                        .font(DS.Font.body(10))
                        .foregroundStyle(DS.Palette.warmGray)
                } else {
                    Text("last 7 days")
                        .font(DS.Font.body(10))
                        .foregroundStyle(DS.Palette.warmGrayDim)
                }
            }
            ProgressBar(percent: snapshot.weeklyPercent)
            HStack {
                Text(snapshot.isLive
                     ? "\(Int(min(snapshot.weeklyPercent, 1) * 100))% of plan"
                     : "\(FormatHelpers.compactNumber(snapshot.weeklyTokens.weighted)) weighted tokens")
                    .font(DS.Font.body(10))
                    .foregroundStyle(DS.Palette.warmGray)
                Spacer()
                Text("\(Int(min(snapshot.weeklyPercent, 1) * 100))%")
                    .font(DS.Font.number(12, weight: .semibold))
                    .foregroundStyle(DS.Palette.cream)
            }
        }
    }

    // MARK: - Sonnet-only (weekly)

    private func sonnetBlock(percent: Double, resetsIn: TimeInterval?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Sonnet only")
                    .font(DS.Font.display(13))
                    .foregroundStyle(DS.Palette.cream)
                Spacer()
                if let secs = resetsIn, secs > 0 {
                    Text("resets in \(FormatHelpers.relativeDuration(secs))")
                        .font(DS.Font.body(10))
                        .foregroundStyle(DS.Palette.warmGray)
                }
            }
            ProgressBar(percent: percent)
            HStack {
                Text("weekly Sonnet quota")
                    .font(DS.Font.body(10))
                    .foregroundStyle(DS.Palette.warmGray)
                Spacer()
                Text("\(Int(min(percent, 1) * 100))%")
                    .font(DS.Font.number(12, weight: .semibold))
                    .foregroundStyle(DS.Palette.cream)
            }
        }
    }

    // MARK: - Extra / pay-as-you-go

    private func extraBlock(percent: Double, used: Double, currency: String, resetsIn: TimeInterval?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Extra credits")
                    .font(DS.Font.display(13))
                    .foregroundStyle(DS.Palette.cream)
                Spacer()
                if let secs = resetsIn, secs > 0 {
                    Text("resets in \(FormatHelpers.relativeDuration(secs))")
                        .font(DS.Font.body(10))
                        .foregroundStyle(DS.Palette.warmGray)
                }
            }
            ProgressBar(percent: percent)
            HStack {
                Text(String(format: "$%.2f %@ spent", used, currency))
                    .font(DS.Font.body(10))
                    .foregroundStyle(DS.Palette.warmGray)
                Spacer()
                Text("\(Int(percent * 100))%")
                    .font(DS.Font.number(12, weight: .semibold))
                    .foregroundStyle(percent >= 1 ? DS.Palette.rust : DS.Palette.cream)
            }
        }
    }

    // MARK: - By model

    private var modelBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("By model · this week")
                .font(DS.Font.body(9, weight: .medium))
                .foregroundStyle(DS.Palette.warmGrayDim)
                .textCase(.uppercase)
                .tracking(0.8)
            HStack(spacing: 8) {
                ForEach([ModelFamily.opus, .sonnet, .haiku], id: \.self) { m in
                    ModelChip(family: m, tokens: snapshot.byModelWeekly[m]?.weighted ?? 0)
                }
            }
        }
    }
}

// MARK: - Reusable pieces

struct ProgressBar: View {
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DS.Palette.surface)
                Capsule()
                    .fill(DS.usageGradient(for: percent))
                    .frame(width: max(4, geo.size.width * clamp))
            }
        }
        .frame(height: 7)
    }

    private var clamp: CGFloat { CGFloat(min(max(percent, 0), 1)) }
}

struct ModelChip: View {
    let family: ModelFamily
    let tokens: Int

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 0) {
                Text(family.displayName)
                    .font(DS.Font.body(9, weight: .medium))
                    .foregroundStyle(DS.Palette.warmGray)
                Text(FormatHelpers.compactNumber(tokens))
                    .font(DS.Font.number(11, weight: .semibold))
                    .foregroundStyle(DS.Palette.cream)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(DS.Palette.surface)
        )
    }

    private var color: Color {
        switch family {
        case .opus:   return DS.Palette.coral
        case .sonnet: return DS.Palette.mustard
        case .haiku:  return DS.Palette.progressBlue
        case .other:  return DS.Palette.warmGrayDim
        }
    }
}
