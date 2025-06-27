import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Настройки виджета"

    static var description = IntentDescription("Параметры конфигурации для виджета")
}
