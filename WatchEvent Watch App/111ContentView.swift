//часы
import SwiftUI
import WatchConnectivity
import Combine
import UserNotifications
import WidgetKit
import SwiftData
import WatchKit

@main
struct WatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var events: [Event] = []
    private let dataManager = WatchDataManager.shared
    private var cleanupTimer: Timer?

    override init() {
        super.init()
        setupSession()
        deletePastEventsHandler()
        setupCleanupTimer()
    }

    private func setupSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("Ошибка активации WCSession: \(error.localizedDescription)")
        } else {
            print("✅ WCSession активирован: \(activationState.rawValue)")

            DispatchQueue.main.async {
                let loadedEvents = self.dataManager.loadAllEvents()
                if !loadedEvents.isEmpty {
                    self.events = loadedEvents
                    print("✅ Данные загружены из базы SwiftData")
                    self.removeNotificationsForDeletedEvents()
                }

                self.sendEventsToWatch()

                let context = session.receivedApplicationContext
                if !context.isEmpty {
                    self.processReceivedData(context)
                    self.removeNotificationsForDeletedEvents()
                }
            }
        }
    }

    func sendEventsImmediately(_ events: [Event]) {
        guard WCSession.default.activationState == .activated else {
            print("WCSession не активирован")
            return
        }

        let allEvents = events.map { $0.toDictionary() }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["command": "update", "events": allEvents], replyHandler: { _ in
                print("✅ События мгновенно доставлены на часы")
            }, errorHandler: { error in
                print("❌ Ошибка sendMessage: \(error.localizedDescription)")
                WCSession.default.transferUserInfo(["events": allEvents])
            })
        } else {
            WCSession.default.transferUserInfo(["events": allEvents])
        }

        try? WCSession.default.updateApplicationContext(["events": allEvents])
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.processReceivedData(applicationContext)
            WidgetCenter.shared.reloadAllTimelines()
            print("🔄 reloadAllTimelines() после получения ApplicationContext")
            WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
            print("🔄 reloadTimelines(ofKind:) выполнен")
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async {
            self.processReceivedData(userInfo)
            WidgetCenter.shared.reloadAllTimelines()
            print("🔄 reloadAllTimelines() после получения UserInfo")
            WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
            print("🔄 reloadTimelines(ofKind:) выполнен")
            self.dataManager.save(events: self.events)
        }
    }

    func forceSync() {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["command": "sync"], replyHandler: { reply in
                if let eventsData = reply["events"] as? [[String: Any]] {
                    DispatchQueue.main.async {
                        self.processReceivedData(["events": eventsData])
                    }
                }
            }, errorHandler: { error in
                print("Ошибка принудительной синхронизации: \(error.localizedDescription)")
                let loadedEvents = self.dataManager.loadAllEvents()
                if !loadedEvents.isEmpty {
                    DispatchQueue.main.async {
                        self.events = loadedEvents
                    }
                }
            })
        } else {
            let loadedEvents = self.dataManager.loadAllEvents()
            if !loadedEvents.isEmpty {
                DispatchQueue.main.async {
                    self.events = loadedEvents
                }
            }
        }
    }

    private func processReceivedData(_ data: [String: Any]) {
        if let receivedEvents = data["events"] as? [[String: Any]] {
            var incomingIDs = Set<UUID>()
            for dict in receivedEvents {
                guard let idString = dict["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let name = dict["name"] as? String,
                      let dateTimestamp = dict["date"] as? TimeInterval,
                      let eventTypeRaw = dict["eventType"] as? String,
                      let eventType = EventType(rawValue: eventTypeRaw),
                      let emoji = dict["emoji"] as? String,
                      let showCountdown = dict["showCountdown"] as? Bool,
                      let repeatYearly = dict["repeatYearly"] as? Bool else { continue }

                let notificationTypeRaw = dict["notificationType"] as? String
                let notificationType = NotificationType(rawValue: notificationTypeRaw ?? "message") ?? .message

                let eventDate = Date(timeIntervalSince1970: dateTimestamp)
                let incomingLastModified = (dict["lastModified"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()

                let hasNotification = dict["notificationTime"] != nil
                var notificationTime: Date? = nil
                if let ts = dict["notificationTime"] as? TimeInterval {
                    notificationTime = Date(timeIntervalSince1970: ts)
                }

                let bellActivated = dict["bellActivated"] as? Bool ?? hasNotification
                let notificationEnabled = dict["notificationEnabled"] as? Bool ?? true
                let deletePastEvents = dict["deletePastEvents"] as? Bool ?? true
                let isFromWatch = dict["isFromWatch"] as? Bool ?? false
                let isNewlyCreated = dict["isNewlyCreated"] as? Bool ?? false

                incomingIDs.insert(id)
                if let index = self.events.firstIndex(where: { $0.id == id }) {
                    let localEvent = self.events[index]
                    guard incomingLastModified > localEvent.lastModified else { continue }
                    self.events[index].name = name
                    self.events[index].date = eventDate
                    self.events[index].eventType = eventType
                    self.events[index].notificationType = notificationType
                    self.events[index].emoji = emoji
                    self.events[index].showCountdown = showCountdown
                    self.events[index].repeatYearly = repeatYearly
                    if hasNotification {
                        self.events[index].notificationTime = notificationTime
                    }
                    self.events[index].notificationEnabled = notificationEnabled
                    self.events[index].bellActivated = bellActivated
                    self.events[index].isNewlyCreated = isNewlyCreated
                    self.events[index].isFromWatch = isFromWatch
                    self.events[index].lastModified = incomingLastModified
                } else {
                    var newEvent = Event(
                        id: id,
                        name: name,
                        date: eventDate,
                        eventType: eventType,
                        emoji: emoji,
                        showCountdown: showCountdown,
                        notificationType: notificationType,
                        notificationEnabled: notificationEnabled,
                        repeatYearly: repeatYearly,
                        notificationTime: notificationTime,
                        bellActivated: bellActivated,
                        deletePastEvents: deletePastEvents,
                        isFromWatch: isFromWatch
                    )
                    newEvent.isNewlyCreated = isNewlyCreated
                    newEvent.lastModified = incomingLastModified
                    self.events.append(newEvent)
                }

                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])

                if notificationEnabled, notificationTime != nil {
                    scheduleNotification(for: self.events.first { $0.id == id }!)
                }
            }

            self.events.removeAll { !incomingIDs.contains($0.id) }


            // Обновляем published‑массив, чтобы UI отразил изменения
            DispatchQueue.main.async {
                self.events = self.events
            }
            
            self.dataManager.save(events: self.events)

            WidgetCenter.shared.reloadAllTimelines()
            print("🔄 reloadAllTimelines() после синхронизации с iPhone")
            WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
            print("🔄 reloadTimelines(ofKind:) выполнен")
            print("✅ Данные с iPhone обновлены на Apple Watch")

            // Удаляем устаревшие уведомления
            self.removeNotificationsForDeletedEvents()
        }
    }

    func sendEventsToWatch() {
        let allEvents = (EventManager.shared.events + EventManager.shared.birthdays)
        print("📤 Отправка \(allEvents.count) событий на часы")
        if let first = allEvents.first {
            print("🔍 Пример: \(first.name), isFromWatch = \(first.isFromWatch)")
        }

        let allEventDictionaries = allEvents.map { $0.toDictionary() }

        do {
            try WCSession.default.updateApplicationContext(["events": allEventDictionaries])
            WCSession.default.transferUserInfo(["events": allEventDictionaries])
            print("✅ События поставлены в очередь отправки")
        } catch {
            print("❌ Ошибка синхронизации: \(error.localizedDescription)")
        }
    }

    func addEvent(_ event: Event) {
        DispatchQueue.main.async {
            var newEvent = event
            newEvent.deletePastEvents = (event.eventType != .birthday)
            newEvent.lastModified = Date()
            self.events.append(newEvent)
            // Триггерим обновление UI после изменения массива
            self.events = self.events
            print("🟡 Добавлено событие: \(newEvent.name), isFromWatch: \(newEvent.isFromWatch)")

            self.sendEventsImmediately([newEvent])

            self.dataManager.save(events: self.events)

            WidgetCenter.shared.reloadAllTimelines()
            print("🔄 reloadAllTimelines() после добавления события")
            WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
            print("🔄 reloadTimelines(ofKind:) выполнен")
        }
    }

    func updateEvent(_ event: Event) {
        DispatchQueue.main.async {
            if let index = self.events.firstIndex(where: { $0.id == event.id }) {
                var updated = event
                updated.lastModified = Date()
                self.events[index] = updated
                // Обновляем published‑массив, чтобы отобразить изменения
                self.events = self.events
            }

            self.sendEventsImmediately([self.events.first { $0.id == event.id } ?? event])

            self.dataManager.save(events: self.events)

            WidgetCenter.shared.reloadAllTimelines()
            print("🔄 reloadAllTimelines() после обновления события")
            WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
            print("🔄 reloadTimelines(ofKind:) выполнен")
        }
    }

    /// Удаляет уведомления для событий, которых больше нет в хранилище
    func removeNotificationsForDeletedEvents() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let existingEventIDs = self.events.map { $0.id.uuidString }
            let idsToRemove = requests.map { $0.identifier }.filter { identifier in
                let eventID = identifier.components(separatedBy: "_").first ?? ""
                return !existingEventIDs.contains(eventID)
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }
    }

    /// Удаляет прошедшие события из SwiftData и локального массива
    func deletePastEventsHandler() {
        let now = Date()
        do {
            let descriptor = FetchDescriptor<EventModel>(
                predicate: #Predicate { $0.date < now && $0.deletePastEvents }
            )
            let outdated = try dataManager.context.fetch(descriptor)
            for model in outdated {
                print("🗑️ Удалено (WatchDataManager): \(model.name)")
                dataManager.context.delete(model)
                events.removeAll { $0.id == model.id }
            }
            if !outdated.isEmpty {
                try dataManager.context.save()
                WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
            }
        } catch {
            print("❌ SwiftData-ошибка: \(error)")
        }
    }

    private func scheduleNotification(for event: Event) {
        guard event.notificationEnabled, event.notificationTime != nil else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [event.id.uuidString])

        let content = UNMutableNotificationContent()
        content.title = event.name
        content.body = "Напоминание о событии: \(event.name)"
        switch event.notificationType {
        case .message:
            content.sound = .default
        case .sound:
            // в watchOS не поддерживается задание пользовательского звука для уведомления,
            // поэтому используем звук по умолчанию
            content.sound = .default
        }

        let notificationDate = event.notificationTime ?? event.date
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: event.repeatYearly)

        let request = UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Ошибка при добавлении уведомления: \(error.localizedDescription)")
            } else {
                print("Уведомление успешно обновлено для события: \(event.name)")
            }
        }
    }

    /// Настраивает таймер периодической очистки прошедших событий
    private func setupCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.deletePastEventsHandler()
        }
    }

}

extension Event {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "date": date.timeIntervalSince1970,
            "eventType": eventType.rawValue,
            "emoji": emoji,
            "showCountdown": showCountdown,
            "notificationType": notificationType.rawValue,
            "notificationEnabled": notificationEnabled,
            "repeatYearly": repeatYearly,
            "bellActivated": bellActivated,
            "deletePastEvents": deletePastEvents,
            "isNewlyCreated": isNewlyCreated,
            "isFromWatch": isFromWatch,
            "lastModified": lastModified.timeIntervalSince1970
        ]
        if let notificationTime {
            dict["notificationTime"] = notificationTime.timeIntervalSince1970
        }
        return dict
    }
}




class EventManager {
    static let shared = EventManager()

    var events: [Event] = [] {
        didSet {
            Task {
                await WatchConnectivityManager.shared.sendEventsToWatch() // Отправка обновлений на часы при изменении событий
            }
        }
    }

    var birthdays: [Event] = [] {
        didSet {
            Task {
                await WatchConnectivityManager.shared.sendEventsToWatch() // Отправка обновлений на часы при изменении дней рождений
            }
        }
    }
    
    
    
    func updateWatchConnectivityContext(events: [Event], birthdays: [Event]) {

        let eventsData = events.map { event -> [String: Any] in
            let notifInterval = event.notificationTime?.timeIntervalSince1970
                ?? event.date.timeIntervalSince1970
            return [
                "id": event.id.uuidString,
                "name": event.name,
                "date": event.date.timeIntervalSince1970,
                "eventType": event.eventType.rawValue,
                "emoji": event.emoji,
                "showCountdown": event.showCountdown,
                "repeatYearly": event.repeatYearly,
                "deletePastEvents": event.deletePastEvents,
                "notificationTime": notifInterval
            ]
        }

        let birthdaysData = birthdays.map { event -> [String: Any] in
            let notifInterval = event.notificationTime?.timeIntervalSince1970
                ?? event.date.timeIntervalSince1970
            return [
                "id": event.id.uuidString,
                "name": event.name,
                "date": event.date.timeIntervalSince1970,
                "eventType": event.eventType.rawValue,
                "emoji": event.emoji,
                "showCountdown": event.showCountdown,
                "repeatYearly": event.repeatYearly,
                "deletePastEvents": event.deletePastEvents,
                "notificationTime": notifInterval
            ]
        }

        let allEvents = eventsData + birthdaysData

        // мгновенная передача
        WCSession.default.transferUserInfo(["events": allEvents])
        // надёжное обновление
        do {
            try WCSession.default.updateApplicationContext(["events": allEvents])
            print("✅ События успешно отправлены на Apple Watch")
        } catch {
            print("❌ Ошибка синхронизации: \(error)")
        }
    }


    // Сохранение события
    func saveEvent(_ event: Event, eventType: EventType) {
        var storedEvent = event
        storedEvent.bellActivated = storedEvent.notificationTime != nil
        storedEvent.deletePastEvents = (eventType != .birthday)
        storedEvent.lastModified = Date()

        if eventType == .birthday {
            if let index = birthdays.firstIndex(where: { $0.id == storedEvent.id }) {
                birthdays[index] = storedEvent
            } else {
                birthdays.append(storedEvent)
            }
        } else {
            if let index = events.firstIndex(where: { $0.id == storedEvent.id }) {
                events[index] = storedEvent
            } else {
                events.append(storedEvent)
            }
        }
    }

}

enum EventType: String, Codable, CaseIterable {
    case event, birthday
    
    var localizedName: String {
        switch self {
        case .event:
            return NSLocalizedString("event_type_event", comment: "")
        case .birthday:
            return NSLocalizedString("event_type_birthday", comment: "")
        }
    }
}

struct Event: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var date: Date
    var eventType: EventType
    var emoji: String
    var showCountdown: Bool = true
    var notificationType: NotificationType = .message
    var notificationEnabled: Bool = true
    var repeatYearly: Bool = false
    var notificationTime: Date?
    var bellActivated: Bool = false
    var deletePastEvents: Bool = false
    var lastModified: Date = Date()
    var isNewlyCreated: Bool = false
    var isFromWatch: Bool = false // ✅ Добавить это свойство
}

/// Возвращает ближайшую дату наступления события.
func nextOccurrenceDate(for event: Event) -> Date? {
    let calendar = Calendar.current
    let now = Date()
    if event.eventType == .birthday {
        var nextDate = event.date
        while nextDate < now {
            nextDate = calendar.date(byAdding: .year, value: 1, to: nextDate) ?? nextDate
        }
        return nextDate
    } else {
        return event.date > now ? event.date : nil
    }
}




// MARK: - Карточка события с таймером


struct EventCardView: View {
    let event: Event
    @State private var timerBackgroundColor: Color = .blue
    @Environment(\.isWatch) var isWatch: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                if !event.emoji.isEmpty {
                    Text(event.emoji)
                        .font(.system(size: 26))
                        .frame(maxHeight: .infinity, alignment: .center)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                        .foregroundColor(.white)

                    Text(event.date, style: .date)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    HStack(spacing: 6) {
                        if event.eventType == .birthday {
                            if let age = getAge(for: event.date) {
                                Text("\(age) лет")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Text(event.date, style: .time)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        if event.eventType == .birthday && isTodayBirthday(eventDate: event.date) {
                            Text("🎂 Сегодня!")
                                .frame(minWidth: 70)
                                .monospacedDigit()
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(5)
                        } else if let futureDate = nextOccurrenceDate(for: event) {
                            Text(futureDate, style: .relative)
                                .frame(minWidth: 70)
                                .monospacedDigit()
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(timerBackgroundColor)
                                .cornerRadius(5)
                        } else {
                            Text(event.date, style: .relative)
                                .frame(minWidth: 70)
                                .monospacedDigit()
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(Color.gray.opacity(0.8))
                                .cornerRadius(5)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .cornerRadius(8)
        .shadow(radius: 2)
        .overlay(alignment: .topTrailing) {
            if shouldShowBellIcon {
                Image(systemName: "bell.fill")
                    .resizable()
                    .frame(width: 8, height: 8)
                    .foregroundColor(bellColor)
                    .padding(5)
            }
        }
        .onAppear {
            updateTimerColor()
        }
    }

    // MARK: - Колокольчик
    private var shouldShowBellIcon: Bool {
        return event.bellActivated
    }




    private var bellColor: Color {
        return .yellow // Всегда жёлтый, раз отображение уже решено выше
    }


    private func isTodayBirthday(eventDate: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.dateComponents([.month, .day], from: Date())
        let eventDay = calendar.dateComponents([.month, .day], from: eventDate)
        return today.month == eventDay.month && today.day == eventDay.day
    }


    private func getAge(for birthDate: Date) -> Int? {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
        return ageComponents.year
    }

    private func updateTimerColor() {
        if event.eventType != .birthday, event.date < Date() {
            timerBackgroundColor = .gray
        }
    }
}



    



struct ContentView: View {
    @ObservedObject var watchManager = WatchConnectivityManager.shared
    @State private var showingAddEvent = false
    @State private var dictatedName: String = ""

    /// Будущие события, отсортированные по дате ближайшего наступления
    private var upcomingEvents: [Event] {
        watchManager.events
            .filter { nextOccurrenceDate(for: $0) != nil }
            .sorted {
                let date1 = nextOccurrenceDate(for: $0) ?? .distantFuture
                let date2 = nextOccurrenceDate(for: $1) ?? .distantFuture
                return date1 < date2
            }
    }

    /// Завершённые события, которые не требуется удалять
    private var completedEvents: [Event] {
        watchManager.events
            .filter { nextOccurrenceDate(for: $0) == nil && !$0.deletePastEvents }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        TabView {
            // Экран предстоящих событий с кнопкой добавления
            NavigationView {
                List(Array(upcomingEvents.enumerated()), id: \.element.id) { _, event in
                    EventCardView(event: event)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 4)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            dictatedName = ""
                            showingAddEvent = true
                        }) {
                            Image(systemName: "plus")
                        }
                        .onLongPressGesture {
                            presentDictation()
                        }
                    }
                }
            }
            .tabItem { Text("Активные") }

            // Экран завершённых событий
            NavigationView {
                List(completedEvents) { event in
                    EventCardView(event: event)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 4)
                }
                .navigationTitle(Text("WATCH_PAST_EVENTS_TITLE"))
                .navigationBarTitleDisplayMode(.automatic)
            }
            .tabItem { Text("Завершённые") }
        }
        .tabViewStyle(.page)
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(initialName: dictatedName)
        }
        .onAppear {
            requestNotificationPermission()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Разрешение на уведомления получено")
            } else if let error = error {
                print("Ошибка при запросе разрешения на уведомления: \(error.localizedDescription)")
            }
        }
    }

    private func presentDictation() {
        if let controller = WKExtension.shared().visibleInterfaceController {
            controller.presentTextInputController(withSuggestions: nil, allowedInputMode: .plain) { results in
                if let first = results?.first as? String {
                    dictatedName = first
                }
                showingAddEvent = true
            }
        } else {
            showingAddEvent = true
        }
    }
}



extension EnvironmentValues {
    var isWatch: Bool {
        #if os(watchOS)
        return true
        #else
        return false
        #endif
    }
}






struct AddEventView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String
    @State private var eventType: EventType = .event

    init(initialName: String = "") {
        _name = State(initialValue: initialName)
    }

    enum AddStep: Hashable, Codable { case datePicker }
    @State private var path = NavigationPath()
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Spacer().frame(height: 4) // Уменьшаем отступ между кнопкой закрытия и типом события
                
                GeometryReader { geometry in
                    VStack {
                        let elementWidth = min(max(geometry.size.width - 40, 0), 160) // Гарантируем неотрицательное значение ширины
                        
                        // 🔥 Выбор типа события (WheelPicker)
                        Picker("Тип события", selection: $eventType) {
                            Text("🎉 Событие").tag(EventType.event)
                            Text("🎂 День рождения").tag(EventType.birthday)
                        }
                        .pickerStyle(.wheel)
                        .frame(width: elementWidth, height: 60, alignment: .center)
                        .padding(.bottom, 10)

                        
                        // 📝 Поле ввода названия события
                        TextField("Название события", text: $name)
                            .frame(width: elementWidth)
#if os(watchOS)
                            .textFieldStyle(.plain)
#else
                            .textFieldStyle(.roundedBorder)
#endif
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 17)
                            .focused($nameFocused)
                            .onSubmit {
                                nameFocused = false
                                DispatchQueue.main.async {
                                    path.append(AddStep.datePicker)
                                }
                            }
                    }
                    .frame(width: geometry.size.width, alignment: .center) // Центрируем все внутри
                }
                .frame(height: 120) // Ограничиваем высоту контейнера
            }
            .padding(.horizontal, 2) // Даем небольшой фиксированный отступ слева и справа
            .navigationDestination(for: AddStep.self) { step in
                switch step {
                case .datePicker:
                    DatePickerView(
                        name: $name,
                        eventType: $eventType,
                        onSave: { presentationMode.wrappedValue.dismiss() }
                    )
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                }
            }
        }
    }
}


               

struct DatePickerView: View {
    
    @Environment(\.presentationMode) var presentationMode // ✅ Добавлено
 
    @Binding var name: String
    @Binding var eventType: EventType
    var onSave: () -> Void

    @State private var date = Date()
    // 📱 При создании события на часах используем иконку часов по умолчанию
    @State private var emoji: String = "⌚"
    @State private var selectedDay: Int = Calendar.current.component(.day, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedHour: Int = Calendar.current.component(.hour, from: Date())
    @State private var selectedMinute: Int = Calendar.current.component(.minute, from: Date())

    var body: some View {
           VStack(spacing: 8) {
               
             // 📅 Дата
               
               HStack(alignment: .center) {
                   Image(systemName: "calendar")
                       .foregroundColor(.blue)
                       .frame(maxHeight: .infinity, alignment: .center) // Центрируем значок
                       .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] } // Выравниваем по первой линии цифр
                   
                   // 📅 Выбор дня (1-31)
                   Picker("", selection: $selectedDay) {
                       ForEach(1...31, id: \.self) { day in
                           Text("\(day)").tag(day) // Цифры без контейнера
                       }
                   }
                   .pickerStyle(WheelPickerStyle())
                   .frame(width: 50, height: 73)
                   
                   // 📅 Выбор месяца (1-12)
                   Picker("", selection: $selectedMonth) {
                       ForEach(1...12, id: \.self) { month in
                           Text("\(month)").tag(month)
                       }
                   }
                   .pickerStyle(WheelPickerStyle())
                   .frame(width: 50, height: 73)
                   
                   // 📅 Выбор года
                   Picker("", selection: $selectedYear) {
                       ForEach(1...9999, id: \.self) { year in
                           Text("\(year)").tag(year)
                       }
                   }
                   .pickerStyle(WheelPickerStyle())
                   .frame(width: 60, height: 73)
               }
               .padding(.top, 0) // Поднимаем ближе к названию
               .padding(.horizontal, 2) // Оставляем небольшой горизонтальный отступ
               .onChange(of: selectedDay, perform: { _ in updateDate() })
               .onChange(of: selectedMonth, perform: { _ in updateDate() })
               .onChange(of: selectedYear, perform: { _ in updateDate() })

               
               // 🔔 время
               //  Выбор времени
               VStack {
                   HStack {
                       // Выбор часов с форматированием (добавляем ведущий ноль)
                       Picker("Часы", selection: $selectedHour) {
                           ForEach(0..<24, id: \.self) { hour in
                               Text(String(format: "%02d", hour)) // Форматируем с ведущим нулем
                                   .tag(hour)
                           }
                       }
                       .frame(width: 55, height: 50)
                       .clipped()
                       .labelsHidden()
                       
                       // Выбор минут с форматированием (добавляем ведущий ноль)
                       Picker("Минуты", selection: $selectedMinute) {
                           ForEach(0..<60, id: \.self) { minute in
                               Text(String(format: "%02d", minute)) // Форматируем с ведущим нулем
                                   .tag(minute)
                           }
                       }
                       .frame(width: 55, height: 50)
                       .clipped()
                       .labelsHidden()
                   }
                   .padding(.top, 3)
               }
               
               Button("Сохранить") {
                                  saveEvent()
                                  onSave()
                              }
                              .frame(maxWidth: .infinity)
                              .disabled(name.isEmpty)
                          }
                          .navigationTitle("Выбор даты")
                          .onAppear(perform: updateDate)
                      }
              
                      private func updateDate() {
                          let calendar = Calendar.current
                          if let newDate = calendar.date(from: DateComponents(
                              year: selectedYear,
                              month: selectedMonth,
                              day: selectedDay,
                              hour: selectedHour,
                              minute: selectedMinute
                          )) {
                              date = newDate
                          }
                      }
              
    private func saveEvent() {
        guard !name.isEmpty else { return }

        updateDate()

        let newEvent = Event(
            id: UUID(),
            name: name,
            date: date,
            eventType: eventType,
            emoji: emoji,
            showCountdown: true,
            notificationEnabled: true,
            repeatYearly: eventType == .birthday,
            notificationTime: date,
            deletePastEvents: eventType != .birthday,
            isFromWatch: true
        )

        print("🆕 Creating event on watch: \(newEvent)")

        // Отметка, что создано только что
        var mutableEvent = newEvent
        mutableEvent.isNewlyCreated = true

        // ✅ Добавляем напрямую в WatchConnectivityManager
        WatchConnectivityManager.shared.addEvent(mutableEvent)

        // ✅ Закрываем экран
        presentationMode.wrappedValue.dismiss()
        onSave()

        // ✅ Уведомление
        scheduleNotification(for: mutableEvent)

        // ✅ Принудительная синхронизация через 1 секунду
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            WatchConnectivityManager.shared.forceSync()
        }
    }



    
    
    
  
              
        

    private func scheduleNotification(for event: Event) {
        guard event.notificationEnabled, event.notificationTime != nil else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [event.id.uuidString])

        let content = UNMutableNotificationContent()
        content.title = event.name
        content.body = "Напоминание о событии: \(event.name)"
        switch event.notificationType {
        case .message:
            content.sound = .default
        case .sound:
            // в watchOS не поддерживается задание пользовательского звука для уведомления,
            // поэтому используем звук по умолчанию
            content.sound = .default
        }

        let notificationDate = event.notificationTime ?? event.date
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: event.repeatYearly)

        let request = UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Ошибка при добавлении уведомления: \(error.localizedDescription)")
            } else {
                print("Уведомление успешно обновлено для события: \(event.name)")
            }
        }
    }
}

