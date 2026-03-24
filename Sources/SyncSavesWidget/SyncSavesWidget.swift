import WidgetKit
import SwiftUI
import AppIntents

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

struct SyncSavesWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView()
        case .systemMedium:
            MediumWidgetView()
        case .accessoryCircular:
            AccessoryCircularView()
        case .accessoryInline:
            AccessoryInlineView()
        default:
            SmallWidgetView()
        }
    }
}

struct SmallWidgetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title)
                .foregroundColor(.blue)
            
            Text("SyncSaves")
                .font(.headline)
                .minimumScaleFactor(0.8)
            
            SyncButton()
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MediumWidgetView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("SyncSaves")
                        .font(.headline)
                }
                
                Text("Sync DS, GBA & GBC saves")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
            }
            
            Spacer()
            
            VStack {
                SyncButton()
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                
                Text("One tap sync")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct AccessoryCircularView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 2) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.headline)
                Text("Sync")
                    .font(.caption2)
            }
        }
    }
}

struct AccessoryInlineView: View {
    var body: some View {
        Label("SyncSaves", systemImage: "arrow.triangle.2.circlepath")
    }
}

struct SyncButton: View {
    var body: some View {
        Button(intent: SyncIntent()) {
            Label("Sync", systemImage: "arrow.triangle.2.circlepath")
        }
    }
}

struct SyncSavesWidget: Widget {
    let kind: String = "SyncSavesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            SyncSavesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("SyncSaves")
        .description("Quickly sync DS, GBA & GBC save files.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryInline])
        #if os(iOS)
        .contentMarginsDisabled()
        #endif
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "SyncSaves widget configuration." }
}

struct SyncIntent: AppIntent {
    static var title: LocalizedStringResource { "Sync Now" }
    static var description: IntentDescription { "Trigger a save file synchronization." }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // This would trigger the sync logic
        // In a real app, we'd use App Groups to share data with the main app
        // and trigger the sync through a shared manager
        
        // For now, show a notification
        let content = UNMutableNotificationContent()
        content.title = "SyncSaves"
        content.body = "Sync started from widget"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        try? await UNUserNotificationCenter.current().add(request)
        
        return .result()
    }
}

#Preview(as: .systemSmall) {
    SyncSavesWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent())
    SimpleEntry(date: .now.addingTimeInterval(3600), configuration: ConfigurationAppIntent())
}

#Preview(as: .systemMedium) {
    SyncSavesWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent())
    SimpleEntry(date: .now.addingTimeInterval(3600), configuration: ConfigurationAppIntent())
}

#Preview(as: .accessoryCircular) {
    SyncSavesWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent())
}

#Preview(as: .accessoryInline) {
    SyncSavesWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent())
}