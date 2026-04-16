import SwiftUI

struct VolumeHUDView: View {
    let state: VolumeHUDState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.Palette.cream)
                .frame(width: 22)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DS.Palette.surface)
                    Capsule()
                        .fill(DS.Palette.coral)
                        .frame(width: max(6, geo.size.width * CGFloat(state.level)))
                }
            }
            .frame(height: 6)

            Text("\(Int(state.level * 100))")
                .font(DS.Font.number(10))
                .foregroundStyle(DS.Palette.warmGray)
                .frame(width: 26, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var symbolName: String {
        switch state.level {
        case 0:         return "speaker.slash.fill"
        case ..<0.33:   return "speaker.wave.1.fill"
        case ..<0.66:   return "speaker.wave.2.fill"
        default:        return "speaker.wave.3.fill"
        }
    }
}
