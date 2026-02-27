import SwiftUI

struct ProgressBarView: View {
    let fraction: Double
    let color: Color

    private var barColor: Color {
        if fraction >= 0.9 { return .red }
        if fraction >= 0.75 { return .orange }
        return color
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.12))

                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [barColor.opacity(0.8), barColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geometry.size.width * fraction))
                    .animation(.easeInOut(duration: 0.4), value: fraction)
            }
        }
        .frame(height: 6)
    }
}
