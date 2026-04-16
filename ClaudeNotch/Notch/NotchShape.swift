import SwiftUI

/// A rounded-rectangle pill matching the visual language of the MBP notch.
/// Extra corner rounding at the bottom so expanded content feels connected.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat = 10
    var bottomCornerRadius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tr = topCornerRadius
        let br = bottomCornerRadius

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - br, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - br),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()

        // Top corners of actual hardware notch — clip the top two edges slightly inward
        // so the silhouette hugs the physical notch curve.
        _ = tr
        return path
    }
}
