import SwiftUI

enum AppTab: String, CaseIterable {
    case today, rides, money, bike
    var title: String { rawValue.uppercased() }
}

/// Four tabs, one per pillar plus the hub (decision 32). Today shows the M2 recorder debug screen; other tabs are empty until M3+.
struct RootView: View {
    @State private var tab = AppTab.today

    var body: some View {
        VStack(spacing: 0) {
            if tab == .today {
                RecorderDebugView()   // M2 only; the Today screen replaces it in M3
            } else {
                Text(tab.title)
                    .font(.oswald(28, .bold, relativeTo: .largeTitle))
                    .tracking(1.6)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            TabBar(selection: $tab)
        }
        .background(Color.ground.ignoresSafeArea())
    }
}

/// Custom bar: the stock tab bar is 49pt, under the 60pt glove rule.
struct TabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isOn = tab == selection
                Button { selection = tab } label: {   // instant: tabs switch tens of times a day
                    VStack(spacing: 6) {
                        Rectangle().fill(isOn ? Color.accent : .clear).frame(width: 28, height: 2)
                        Text(tab.title)
                            .font(.oswald(13, .medium, relativeTo: .caption))
                            .tracking(2)
                            .foregroundStyle(isOn ? Color.ink : Color.inkMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: minTouch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(Color.surfaceRule).frame(height: 1) }
        .background(Color.ground)
    }
}
