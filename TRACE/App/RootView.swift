import SwiftUI

enum AppTab: String, CaseIterable, Comparable {
    case today, rides, money, bike
    static func < (a: AppTab, b: AppTab) -> Bool { allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)! }
    var title: String { rawValue.uppercased() }
}

/// Four tabs, one per pillar plus the hub (decision 32).
struct RootView: View {
    @State private var tab = AppTab.today
    @State private var forward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @AppStorage("onboarded") private var onboarded = false
    @State private var onboarding = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack { screen.id(tab).transition(slide) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .undoBar()   // above the tab bar
            TabBar(selection: tab) { new in
                forward = new > tab
                // Short and functional (decision 63): shows which way you moved, never in the way.
                withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.18)) { tab = new }
            }
            .ignoresSafeArea(.keyboard)   // stays at the bottom, under the keyboard
        }
        .background(Color.ground.ignoresSafeArea())
        // Existing installs already have a bike, so they never see it.
        .task { onboarding = !onboarded && (try? Garage(context: context, user: LocalStubUser.load()).bike()) == nil }
        .fullScreenCover(isPresented: $onboarding) { OnboardingView(firstRun: true) }
    }

    private var slide: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let shift: CGFloat = 28
        return .asymmetric(insertion: .opacity.combined(with: .offset(x: forward ? shift : -shift)),
                           removal: .opacity.combined(with: .offset(x: forward ? -shift : shift)))
    }

    @ViewBuilder private var screen: some View {
            if tab == .today {
                TodayView()
            } else if tab == .rides {
                RidesView()
            } else if tab == .bike {
                BikeView()
            } else {
                MoneyView()
            }
    }
}

/// Custom bar: the stock tab bar is 49pt, under the 60pt glove rule.
struct TabBar: View {
    let selection: AppTab
    let onSelect: (AppTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isOn = tab == selection
                Button { if tab != selection { onSelect(tab) } } label: {
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
