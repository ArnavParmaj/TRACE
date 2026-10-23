import SwiftUI

/// Hairline 135° diagonals in `--diagonal`: the unlit Agit-Print texture (DESIGN.md rule 4).
struct Hatch: View {
    var spacing: CGFloat = 14

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var x = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += spacing
            }
            ctx.stroke(path, with: .color(.diagonal), lineWidth: 1)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

/// 72pt top bar of a tab: title, optional trailing content, rule below. Edge to edge.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var hatched = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title).font(.oswald(28, .bold, relativeTo: .largeTitle)).tracking(1.7).foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 72)
        .background { if hatched { Hatch() } }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceRule).frame(height: 1) }
        .padding(.horizontal, -20)   // screens pad 20; the bar runs to the edges
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, hatched: Bool = false) {
        self.init(title: title, hatched: hatched) { EmptyView() }
    }
}
