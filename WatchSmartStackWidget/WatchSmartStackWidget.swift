import WidgetKit
import SwiftUI
import AppIntents

struct SmartStackData: Codable {
    let title: String
    let subtitle: String
}

struct SmartStackEntry: TimelineEntry {
    var date: Date
    var configuration: ConfigurationAppIntent
    var data: SmartStackData
    var relevance: TimelineEntryRelevance? {
        .init(score: 100)
    }
}

struct SmartStackProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SmartStackEntry {
        SmartStackEntry(date: .now,
                        configuration: ConfigurationAppIntent(),
                        data: SmartStackData(title: "Загрузка...", subtitle: ""))
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SmartStackEntry {
        SmartStackEntry(date: .now,
                        configuration: configuration,
                        data: SmartStackData(title: "Пример", subtitle: "Снапшот"))
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SmartStackEntry> {
        let entry = SmartStackEntry(date: .now,
                                    configuration: configuration,
                                    data: SmartStackData(title: "Привет", subtitle: "Смарт-стек"))
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60*60)))
    }

    static func recommendations() -> [AppIntentRecommendation<ConfigurationAppIntent>] {
        [AppIntentRecommendation(intent: ConfigurationAppIntent(), description: "Смарт-виджет")]
    }
}

struct SmartStackWidgetView: View {
    var entry: SmartStackProvider.Entry

    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
            VStack(alignment: .leading) {
                Text(entry.data.title)
                    .font(.headline)
                Text(entry.data.subtitle)
                    .font(.caption)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct SmartStackWidget: Widget {
    let kind: String = "SmartStackWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: SmartStackProvider()) { entry in
            SmartStackWidgetView(entry: entry)
        }
        .configurationDisplayName("Смарт стек")
        .description("Пример виджета для Smart Stack")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview("Smart Stack Widget") {
    SmartStackWidgetView(entry: SmartStackEntry(date: .now,
                                               configuration: ConfigurationAppIntent(),
                                               data: SmartStackData(title: "Тест", subtitle: "Предпросмотр")))
        .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
}
