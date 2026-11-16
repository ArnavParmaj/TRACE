import SwiftUI
import WidgetKit

/// One entry per moment the widget can change by itself (decision 91). The snapshot is the
/// same in each; the state is worked out from the entry's date when it draws.
struct HomeEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct HomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> HomeEntry { HomeEntry(date: .now, snapshot: WidgetSnapshot()) }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (HomeEntry) -> Void) {
        completion(HomeEntry(date: .now, snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<HomeEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let now = Date.now
        let entries = ([now] + snapshot.changeDates(after: now)).map { HomeEntry(date: $0, snapshot: snapshot) }
        // The app reloads the widget whenever its data changes; .atEnd only covers a week untouched.
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

/// The dynamic widget: add it once, TRACE decides what it shows.
struct HomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TRACEHome", provider: HomeProvider()) { entry in
            HomeWidgetView(entry: entry).containerBackground(Color.ground, for: .widget)
        }
        .configurationDisplayName("TRACE")
        .description("What your bike needs now. The wide one adds START RIDE and LOG.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct HomeWidgetView: View {
    let entry: HomeEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let link = WidgetLink.panel(entry.snapshot.state(at: entry.date))
        if family == .systemSmall {
            WidgetPanel(snapshot: entry.snapshot, now: entry.date, small: true).widgetURL(link)
        } else {
            HStack(spacing: 16) {
                WidgetPanel(snapshot: entry.snapshot, now: entry.date, links: true)
                WidgetActions(riding: entry.snapshot.live != nil, logged: entry.snapshot.justLogged(at: entry.date))
            }
            .widgetURL(link)   // a tap in the margins goes where the panel goes
        }
    }
}

/// A small square that is one START RIDE button.
struct StartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TRACEStart", provider: HomeProvider()) { entry in
            WidgetStartTile(snapshot: entry.snapshot)
                .widgetURL(WidgetLink.url(entry.snapshot.live == nil ? .start : .ride))
                .containerBackground(Color.ground, for: .widget)
        }
        .configurationDisplayName("Start ride")
        .description("One tap opens TRACE already recording.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
