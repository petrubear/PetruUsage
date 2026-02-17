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
                RoundedRectangle(cornerRadius: 2)
                    .fill(.quaternary)

                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: max(0, geometry.size.width * fraction))
            }
        }
        .frame(height: 4)
    }
}
