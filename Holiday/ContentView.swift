// вношу изменения в функции поле миграции Свифт дата

//пром

// промежуток

// при Свайпе удаляет

// промежуточный главный Swift DATA




//промежуток

// при редактировании уведомленбиотают корректно

//основа
// основной

// основной промежуточный 1


// ирин промежуточный

// последняя версия



// 9


import SwiftUI
import UserNotifications
import RevenueCat
import RevenueCatUI
import WidgetKit
import WatchConnectivity
import SwiftData
import Speech
import AVFoundation
struct Constants {
    static let apiKey: String = {
        guard let value = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String else {
            fatalError("RevenueCat API key not found")
        }
        return value
    }()
}


enum EventType: String, Codable, CaseIterable {
    case event
    case birthday
    
    var localizedName: String {
        switch self {
        case .event:
            return NSLocalizedString("event_type_event", comment: "")
        case .birthday:
            return NSLocalizedString("event_type_birthday", comment: "")
        }
    }
}

enum NotificationType: String, Codable {
    case message
    case sound
}

struct EmojiCategory: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let emojis: [String]
}

let emojiCategories = [
    EmojiCategory(name: NSLocalizedString("CATEGORY_NAME_NONE", comment: ""), emojis: [""]),
    EmojiCategory(name: NSLocalizedString("CATEGORY_NAME_CELEBRATION", comment: ""), emojis: ["🎉", "🎈", "🎁", "🍰", "🎂", "🥳", "🎊", "🍾"]),
    EmojiCategory(name: NSLocalizedString("CATEGORY_NAME_FOOD", comment: ""), emojis: ["🍎", "🍊", "🍉", "🍓", "🍍", "🍕", "🍔", "🍣", "🍰", "🍪", "🥂", "🍷"]),
    EmojiCategory(name: NSLocalizedString("CATEGORY_NAME_SPORTS", comment: ""), emojis: ["⚽", "🏀", "🏈", "⚾", "🎾", "🏐", "🏓", "🏸", "🥋", "🥊", "🏆"]),
    EmojiCategory(name: NSLocalizedString("CATEGORY_NAME_NATURE", comment: ""), emojis: ["🌳", "🌴", "🌵", "🌿", "🌺", "🌻", "🌷", "🌸", "🍁", "🍂", "🌹", "🏞️", "🌍", "🌊", "☀️", "🌧️", "❄️"]),
    EmojiCategory(name: NSLocalizedString("CATEGORY_NAME_BEAUTY", comment: ""), emojis: ["💄", "💋", "💅", "💇‍♀️", "💇‍♂️", "💆‍♀️", "💆‍♂️", "👗", "👠", "👜", "🕶️"])
]







// обмен данными с часами



class PhoneConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneConnectivityManager()

    override init() {
        super.init()
        setupSession()
    }

    
    public func sendEventsImmediately(_ events: [Event]) {

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

    
    
    
  
    
    private func setupSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - WCSessionDelegate

    /// Вызывается один раз при активации сессии
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ Ошибка активации WCSession: \(error.localizedDescription)")
        } else {
            print("✅ WCSession активирован: \(activationState.rawValue)")
        }
    }

    /// Вызывается, если сессия стала неактивной (например, при сворачивании)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ WCSession стала неактивной")
    }
    
    
    

    /// Вызывается, если сессия деактивирована (например, при смене девайса)
    func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ WCSession деактивирована, повторная активация")
        WCSession.default.activate()
    }

    /// Получаем сообщение от часов (например, о создании нового события)
    // Внутри класса PhoneConnectivityManager
    // 1) Обновлённая функция получения сообщения от часов
    //    (удалён первый лишний вызов scheduleNotification)
    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: (([String : Any]) -> Void)?) {
        DispatchQueue.main.async {
            guard let eventData = message["newEvent"] as? [String: Any],
                  let idString  = eventData["id"] as? String,
                  let id        = UUID(uuidString: idString),
                  let name      = eventData["name"] as? String,
                  let ts        = eventData["date"] as? TimeInterval,
                  let typeRaw   = eventData["eventType"] as? String,
                  let eventType = EventType(rawValue: typeRaw),
                  let emoji     = eventData["emoji"] as? String,
                  let showCountdown = eventData["showCountdown"] as? Bool,
                  let repeatYearly   = eventData["repeatYearly"] as? Bool
            else { return }

            let notificationTime: Date? = {
                if let nt = eventData["notificationTime"] as? TimeInterval {
                    return Date(timeIntervalSince1970: nt)
                } else {
                    return nil
                }
            }()

            let newEvent = Event(
                id:               id,
                name:             name,
                date:             Date(timeIntervalSince1970: ts),
                showCountdown:    showCountdown,
                eventType:        eventType,
                emoji:            emoji,
                notificationTime: notificationTime,
                deletePastEvents: eventType != .birthday,
                repeatYearly:     repeatYearly
            )

            // Сохраняем и (только если событие новое) один раз планируем уведомление
            if EventManager.shared.events.contains(where: { $0.id == id }) ||
               EventManager.shared.birthdays.contains(where: { $0.id == id }) {
                EventManager.shared.saveEvent(newEvent, eventType: eventType)
            } else {
                EventManager.shared.saveEvent(newEvent, eventType: eventType)
               self.scheduleNotification(for: newEvent)
            }
        }
    }

    
    /// Обработка самой свежей конфигурации из applicationContext
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            guard let rawEvents = applicationContext["events"] as? [[String: Any]] else { return }
            self.handleIncomingEvents(rawEvents)
        }
    }

    /// Обработка гарантированной доставки через userInfo
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async {
            guard let rawEvents = userInfo["events"] as? [[String: Any]] else { return }
            self.handleIncomingEvents(rawEvents)
        }
    }

    
    
    
    // MARK: –– В вашем классе PhoneConnectivityManager

    // Функция создания уведомления
    func scheduleNotification(for event: Event) {
        guard event.notificationEnabled, event.notificationTime != nil else { return }
        let center = UNUserNotificationCenter.current()

        // 1. Определяем идентификатор
        let identifier = event.id.uuidString

        // 2. Формируем содержимое уведомления
        let content = UNMutableNotificationContent()
        content.title = event.name
        content.body = "Напоминание о событии: \(event.name)"
        switch event.notificationType {
        case .message:
            content.sound = .default
        case .sound:
            content.sound = UNNotificationSound(named: UNNotificationSoundName("test1.mp3"))
        }

        // 3. Особая логика для дней рождения с ежегодным повтором
        if event.eventType == .birthday && event.repeatYearly {
            // Запланируем единственное повторяющееся уведомление
            let notifDate = event.notificationTime ?? event.date
            scheduleBirthdayNotification(
                on: notifDate,
                identifier: identifier,
                content: content
            )
            return
        }

        // 4. Удаляем старое уведомление
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // 5. Обычная логика для всех остальных событий
        let notificationDate = event.notificationTime ?? event.date
        let components: Set<Calendar.Component> = event.repeatYearly
            ? [.month, .day, .hour, .minute]
            : [.year, .month, .day, .hour, .minute]

        let triggerDate = Calendar.current.dateComponents(components, from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerDate,
            repeats: event.repeatYearly || event.repeatInterval != .none
        )

        // 6. Создаём и добавляем запрос
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error = error {
                print("❌ Ошибка при добавлении уведомления: \(error.localizedDescription)")
            } else {
                print("✅ Уведомление запланировано для события: \(event.name) — \(notificationDate)")
            }
        }
    }

    // Вспомогательный метод для дней рождения:
    // – рассчитывает следующую дату (в этом или следующем году) и ставит единое повторяющееся уведомление
    private func scheduleBirthdayNotification(
        on date: Date,
        identifier: String,
        content: UNNotificationContent
    ) {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()

        // 1) Удаляем все старые уведомления по этому идентификатору
        print("🗑 Удаляем все старые ДР-уведомления с идентификатором: \(identifier)")
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // 2) Разбираем компоненты даты события
        let compsWithYear = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let compsWithoutYear = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
        guard let eventYear = compsWithYear.year else { return }
        let currentYear = calendar.component(.year, from: now)

        if eventYear > currentYear {
            // ——————————————
            // Одноразовое уведомление на точную дату в будущем (например, 2026)
            // ——————————————
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: compsWithYear,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error = error {
                    print("❌ Ошибка one-time ДР-уведомления [\(identifier)]: \(error.localizedDescription)")
                } else {
                    print("🎂 Одноразовый ДР-уведомление запланировано [\(identifier)] на \(date)")
                }
            }

        } else {
            // ——————————————
            // Повторяющееся уведомление каждый год
            // ——————————————
            // Вычисляем ближайшую будущую дату (этот или следующий год)
            var nextComps = compsWithoutYear
            nextComps.year = currentYear
            var nextDate = calendar.date(from: nextComps)!
            if nextDate < now {
                nextComps.year = currentYear + 1
                nextDate = calendar.date(from: nextComps)!
            }

            let triggerDate = calendar.dateComponents([.month, .day, .hour, .minute], from: nextDate)
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: triggerDate,
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error = error {
                    print("❌ Ошибка repeating ДР-уведомления [\(identifier)]: \(error.localizedDescription)")
                } else {
                    print("🎂 Repeating ДР-уведомление запланировано [\(identifier)] начиная с \(nextDate)")
                }
            }
        }
    }






    // MARK: - Синхронизация iPhone -> Watch

    /// Отправляем объединённый список событий и дней рождений на часы
    func sendEventsToWatch() {
        let allEvents = EventManager.shared.events + EventManager.shared.birthdays
        let eventsData = allEvents.map { event in
            event.toDictionary()
        }

        do {
            try WCSession.default.updateApplicationContext(["events": eventsData])
            WCSession.default.transferUserInfo(["events": eventsData])
            if WCSession.default.isReachable {
                // sendMessage может быть добавлен здесь при необходимости
            }
            print("✅ События (\(allEvents.count)) отправлены на Apple Watch")
        } catch {
            print("❌ Ошибка синхронизации с Apple Watch: \(error.localizedDescription)")
        }
    }
    
    
    
    
    
    // MARK: - Обработка пришедших «сырых» словарей
    // Внутри класса PhoneConnectivityManager, вместо прежнего handleIncomingEvents
    private func handleIncomingEvents(_ rawEvents: [[String: Any]]) {
        for dict in rawEvents {
            guard
                let idString       = dict["id"] as? String,
                let id             = UUID(uuidString: idString),
                let name           = dict["name"] as? String,
                let timestamp      = dict["date"] as? TimeInterval,
                let showCountdown  = dict["showCountdown"] as? Bool,
                let eventTypeRaw   = dict["eventType"] as? String,
                let eventType      = EventType(rawValue: eventTypeRaw),
                let emoji          = dict["emoji"] as? String,
                let repeatYearly   = dict["repeatYearly"] as? Bool
            else { continue }

            let originalIndex: Int? = dict["originalIndex"] as? Int
            let note: String? = dict["note"] as? String
            let incomingLastModified = (dict["lastModified"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()

            let hasNotification = dict["notificationTime"] != nil
            var notificationTime: Date? = nil
            if let nt = dict["notificationTime"] as? TimeInterval {
                notificationTime = Date(timeIntervalSince1970: nt)
            }

            let deletePastEvents = dict["deletePastEvents"] as? Bool ?? true

            if let index = EventManager.shared.events.firstIndex(where: { $0.id == id }) {
                var local = EventManager.shared.events[index]
                guard incomingLastModified > local.lastModified else { continue }
                local.name = name
                local.date = Date(timeIntervalSince1970: timestamp)
                local.showCountdown = showCountdown
                local.eventType = eventType
                local.originalIndex = originalIndex
                local.emoji = emoji
                local.note = note
                if hasNotification {
                    local.notificationTime = notificationTime
                } else {
                    local.notificationTime = nil
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [local.id.uuidString])
                }
                local.deletePastEvents = deletePastEvents
                local.repeatYearly = repeatYearly
                local.lastModified = incomingLastModified
                EventManager.shared.saveEvent(local, eventType: local.eventType)
                self.scheduleNotification(for: local)
            } else {
                var newEvent = Event(
                    id: id,
                    name: name,
                    date: Date(timeIntervalSince1970: timestamp),
                    showCountdown: showCountdown,
                    eventType: eventType,
                    originalIndex: originalIndex,
                    emoji: emoji,
                    note: note,
                    notificationTime: notificationTime,
                    deletePastEvents: deletePastEvents,
                    repeatYearly: repeatYearly
                )
                newEvent.lastModified = incomingLastModified
                EventManager.shared.saveEvent(newEvent, eventType: newEvent.eventType)
                self.scheduleNotification(for: newEvent)
            }
        }

    

        // 8. Обновляем виджеты
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 reloadAllTimelines() из handleIncomingEvents")
    }


    




    
}




    
    /// Метод для обновления application context с данными событий
    func updateContext(with events: [[String: Any]]) {
        do {
            try WCSession.default.updateApplicationContext(["events": events])
            print("Application context обновлён")
        } catch {
            print("Ошибка обновления application context: \(error.localizedDescription)")
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("Ошибка активации WCSession: \(error.localizedDescription)")
        } else {
            print("WCSession активирована: \(activationState.rawValue)")
        }
    }
    
    // Реализуем обязательные методы протокола:
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Здесь можно обработать ситуацию, когда сессия стала неактивной
        print("WCSession стала неактивной")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // После деактивации требуется повторно активировать сессию
        print("WCSession деактивирована, повторная активация")
        WCSession.default.activate()
    }








// только превью


struct WelcomeScreenView: View {
    @State private var currentScreen = 1
    @State private var isFirstLaunch: Bool? = nil
    @State private var isReversing = false // Определяет направление анимации
    @EnvironmentObject private var manager: EventManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Фиксированные цвета для одинакового отображения в светлой и тёмной темах
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 1.0, green: 1.0, blue: 1.0), // Чистый белый (без адаптации)
                        Color(red: 0.85, green: 0.85, blue: 0.85), // Серый, фиксированный
                        Color(red: 1.0, green: 1.0, blue: 1.0), // Белый
                        Color(red: 0.6, green: 0.6, blue: 0.6), // Более тёмный серый, но фиксированный
                        Color(red: 1.0, green: 1.0, blue: 1.0)  // Белый
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    Spacer(minLength: 0)
                    
                    Group {
                        switch currentScreen {
                        case 1:
                            FirstScreenView()
                        case 2:
                            SecondScreenView()
                        case 3:
                            ThirdScreenView()
                        case 4:
                            SidebarMenuPreviewView()
                        case 5:
                            NotificationWelcomeView(currentScreen: $currentScreen, isFirstLaunch: $isFirstLaunch)
                        case 6:
                            SubscriptionWelcomeView(isFirstLaunch: $isFirstLaunch)
                        default:
                            EventsListView().environmentObject(EventManager.shared)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: isReversing ? .move(edge: .leading) : .move(edge: .trailing),
                        removal: isReversing ? .move(edge: .trailing) : .move(edge: .leading)
                    ))
                    .animation(.easeInOut(duration: 0.4), value: currentScreen)
                    
                    Spacer(minLength: 0)
                    
                    HStack {
                        Spacer()
                        IndicatorView(currentScreen: $currentScreen)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .overlay(
                        (currentScreen != 5 && currentScreen != 6) ?
                        ContinueButton(currentScreen: $currentScreen, isFirstLaunch: $isFirstLaunch, isReversing: $isReversing)
                            .offset(x: geometry.size.width / 2 - 40, y: 0) : nil,
                        alignment: .center
                    )
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .top) {
                    HeaderView(currentScreen: $currentScreen, isFirstLaunch: $isFirstLaunch, isReversing: $isReversing)
                }
            }
            .onAppear {
                isFirstLaunch = manager.settings?.isFirstLaunch
            }
        }
    }
}



// MARK: - 4 экран (SidebarMenuPreviewView)

struct SidebarMenuPreviewView: View {
    @State private var selectedDate = Date()
    @State private var events: [Event] = [
        Event(
            id: UUID(),
            name: NSLocalizedString("EVENT_1_NAME", comment: ""),
            date: Date().addingTimeInterval(3600 * 24 * 2),
            showCountdown: true,
            eventType: .event,
            emoji: "🎉",
            note: NSLocalizedString("EVENT_1_NOTE", comment: ""),
            checklist: [],
            notificationEnabled: true,
            notificationTime: Date(),
            deletePastEvents: false,
            repeatYearly: true
        ),
        Event(
            id: UUID(),
            name: NSLocalizedString("EVENT_2_BIRTHDAY_NAME", comment: ""),
            date: Date().addingTimeInterval(3600 * 24 * 5),
            showCountdown: true,
            eventType: .birthday,
            emoji: "🎂",
            note: NSLocalizedString("EVENT_2_BIRTHDAY_NOTE", comment: ""),
            checklist: [],
            notificationEnabled: true,
            notificationTime: Date(),
            deletePastEvents: false,
            repeatYearly: true
        )
    ]
    
    @State private var birthdays: [Event] = [
        Event(
            id: UUID(),
            name: NSLocalizedString("EVENT_3_BIRTHDAY_NAME", comment: ""),
            date: Date().addingTimeInterval(3600 * 24 * 7),
            showCountdown: true,
            eventType: .birthday,
            emoji: "🎁",
            note: NSLocalizedString("EVENT_3_BIRTHDAY_NOTE", comment: ""),
            checklist: [],
            notificationEnabled: true,
            notificationTime: Date(),
            deletePastEvents: false,
            repeatYearly: true
        )
    ]
    
    var body: some View {
        let calendarWidth = UIScreen.main.bounds.width * 0.5
        return VStack(alignment: .leading, spacing: 10) {
            AnimatedCard {
                VStack(spacing: 0) {
                    VStack(alignment: .center, spacing: 5) {
                        Text("\(Calendar.current.component(.day, from: selectedDate))")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundColor(Color("darkCard"))
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 0)
                        
                        Text(DateFormatter.localizedString(from: selectedDate, dateStyle: .full, timeStyle: .none)
                            .components(separatedBy: ",").first?.uppercased() ?? "")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(Color("darkCard"))
                        .environment(\.layoutDirection, Locale.current.languageCode == "ar" ? .rightToLeft : .leftToRight) // Авто-RTL для арабского
                        
                        
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 0)
                    }
                    .padding(.vertical, 10)
                    .padding(.bottom, 10)
                    
                    CalendarViewPRE(selectedDate: $selectedDate, events: events, birthdays: birthdays)
                        .frame(width: calendarWidth, height: calendarWidth * 6 / 7 + 20)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 10)
                        .background(Color("darkCard"))
                        .cornerRadius(15)
                        .shadow(color: .white.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            Text("SIDEBAR_TODAY_EVENTS") // События на сегодня
                .font(.system(size: 14))
                .foregroundColor(Color("darkCard"))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
            
            // Первый блок
            Text("TIME_11_30") // 11:30
                .font(.system(size: 14))
                .foregroundColor(Color("darkCard"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 80)
                .padding(.top, 2)
            
            ZStack {
                GeometryReader { geometry in
                    AnimatedCard(aggressive: true) {
                        HStack {
                            Text("SIDEBAR_MEETING") // Совещание
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(width: 150, height: 30)
                        .padding(.horizontal, 10)
                        .background(Color("darkCard"))
                        .cornerRadius(15)
                        .shadow(color: .white.opacity(0.2), radius: 5, x: 0, y: 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 60)
                    
                    Text("SIDEBAR_MEETING_EMOJI") // 💼
                        .font(.system(size: 20))
                        .position(
                            x: geometry.size.width - 40,
                            y: geometry.size.height / 2
                        )
                }
                .frame(height: 30)
                .padding(.trailing, 60)
            }
            
            // Второй блок
            Text("TIME_18_00") // 18:00
                .font(.system(size: 14))
                .foregroundColor(Color("darkCard"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 80)
                .padding(.top, 2)
            
            ZStack {
                GeometryReader { geometry in
                    AnimatedCard(aggressive: true) {
                        HStack {
                            Text("SIDEBAR_DOCTOR") // Запись к врачу
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(width: 150, height: 30)
                        .padding(.horizontal, 10)
                        .background(Color("darkCard"))
                        .cornerRadius(15)
                        .shadow(color: .white.opacity(0.2), radius: 5, x: 0, y: 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 60)
                    
                    Text("SIDEBAR_DOCTOR_EMOJI") // 💊
                        .font(.system(size: 20))
                        .position(
                            x: geometry.size.width - 40,
                            y: geometry.size.height / 2
                        )
                }
                .frame(height: 30)
                .padding(.trailing, 60)
            }
            
            Spacer()
            
            VStack {
                Text("SIDEBAR_CONVENIENT_CALENDAR") // Удобный календарь
                    .font(.system(size: 24))
                    .foregroundColor(Color("darkCard"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .multilineTextAlignment(.center)
                
                Text("SIDEBAR_SHOWS_ALL_EVENTS") // Покажет все события на определенный день
                    .font(.system(size: 18))
                    .foregroundColor(Color("darkCard").opacity(0.8))
                    .padding(.horizontal, 60)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Spacer()
        }
    }
}


// Дополнительные View для SideBarMenu
struct DayViewPRE:  View {
    let date: Date
    let events: [Event]
    let birthdays: [Event]
    let isSelected: Bool
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        ZStack {
            ZStack {
                if isToday && isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                } else if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 20, height: 20)
                }
                
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: isToday ? 14 : 12))
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
            }
            
            if !events.isEmpty || !birthdays.isEmpty {
                Circle()
                    .fill(Color.red)
                    .frame(width: 4, height: 4)
                    .offset(y: -10)
                    .opacity(isSelected ? 0 : 1)
                    .animation(.easeInOut(duration: 0.3), value: isSelected)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var textColor: Color {
        if isToday && isSelected {
            return .white
        } else if isToday && !isSelected {
            return .blue
        } else if isSelected {
            return .white
        } else {
            return .white
        }
    }
}

struct CalendarViewPRE: View {
    @Binding var selectedDate: Date
    let events: [Event]
    let birthdays: [Event]
    
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }
    
    private var displayedMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: currentDate).capitalized
    }
    
    @State private var currentDate = Date()
    
    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: currentDate) else { return [] }
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentDate))!
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: firstDay) }
    }
    
    private var paddingDays: Int {
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentDate))!
        let weekday = calendar.component(.weekday, from: firstDay)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
    
    var body: some View {
        VStack {
            // Заголовок дней недели
            HStack(spacing: 0) {
                ForEach(weekdaySymbolsStartingFromMonday(), id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                        .fontWeight(.thin)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, -4)
            .padding(.horizontal, -16)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                ForEach(0..<paddingDays, id: \.self) { _ in
                    Text("")
                }
                ForEach(daysInMonth, id: \.self) { day in
                    DayViewPRE(
                        date: day,
                        events: eventsForDay(day),
                        birthdays: birthdaysForDay(day),
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDate)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        selectedDate = day
                    }
                }
            }
            .padding(.horizontal, -16)
        }
    }
    
    private func weekdaySymbolsStartingFromMonday() -> [String] {
        var symbols = calendar.shortWeekdaySymbols
        let firstHalf = symbols[0..<calendar.firstWeekday - 1]
        symbols.removeSubrange(0..<calendar.firstWeekday - 1)
        symbols.append(contentsOf: firstHalf)
        return symbols
    }
    
    private func eventsForDay(_ day: Date) -> [Event] {
        events.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }
    
    private func birthdaysForDay(_ day: Date) -> [Event] {
        birthdays.filter {
            let bd = calendar.dateComponents([.month, .day], from: $0.date)
            let dd = calendar.dateComponents([.month, .day], from: day)
            return bd.month == dd.month && bd.day == dd.day
        }
    }
}

// MARK: - HeaderView
struct HeaderView: View {
    @Binding var currentScreen: Int
    @Binding var isFirstLaunch: Bool?
    @Binding var isReversing: Bool
    @Environment(\.locale) private var locale: Locale  // Добавляем свойство окружения для локализации
    
    var body: some View {
        HStack {
            // Кнопка "Назад" (только иконка, без текста)
            Button {
                withAnimation(.easeInOut(duration: 0.4)) {
                    if currentScreen > 1 {
                        isReversing = true
                        currentScreen -= 1
                    }
                }
            } label: {
                Image(systemName: locale.languageCode == "ar" ? "chevron.right" : "chevron.left") // Меняем направление стрелки
                    .font(.title3)
                    .fontWeight(.semibold)
                    .contentShape(.rect)
            }
            .opacity(currentScreen > 1 ? 1 : 0)
            
            Spacer()
            
            // Кнопка "Закрыть" (только иконка, без текста)
            Button(action: {
                isFirstLaunch = false
                EventManager.shared.completeFirstLaunch()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
            }
            .opacity(currentScreen < 6 ? 1 : 0)
        }
        .foregroundStyle(.white)
        .padding(15)
    }
}



struct AnimatedCard<Content: View>: View {
    let content: Content
    @State private var autoRotateX: CGFloat = 0
    @State private var autoRotateY: CGFloat = 0
    @State private var direction: CGFloat = 0
    @State private var interactionOffset = CGSize.zero
    var aggressive: Bool = false
    
    init(aggressive: Bool = false, @ViewBuilder content: () -> Content) {
        self.aggressive = aggressive
        self.content = content()
    }
    
    var body: some View {
        VStack {
            content
                .rotation3DEffect(
                    .degrees(autoRotateX - interactionOffset.height / (aggressive ? 15 : 30)),
                    axis: (x: 1, y: 0, z: 0)
                )
                .rotation3DEffect(
                    .degrees(autoRotateY + interactionOffset.width / (aggressive ? 15 : 30)),
                    axis: (x: 0, y: 1, z: 0)
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            interactionOffset = value.translation
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                interactionOffset = .zero
                            }
                        }
                )
                .onAppear {
                    startAutoRotation()
                }
        }
    }
    
    private func startAutoRotation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) {
                autoRotateX = (aggressive ? 5 : 2) * sin(direction) // Уменьшенная амплитуда для плавного вращения
                autoRotateY = (aggressive ? 5 : 2) * cos(direction) // Уменьшенная амплитуда для плавного вращения
            }
            direction += aggressive ? 0.02 : 0.04 // Медленнее изменения для плавного вращения
        }
    }
}



// MARK: - Кнопка "Продолжить"
struct ContinueButton: View {
    @Binding var currentScreen: Int
    @Binding var isFirstLaunch: Bool?
    @Binding var isReversing: Bool
    @Environment(\.locale) private var locale: Locale  // Добавляем свойство окружения для локализации
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.4)) {
                isReversing = false
                if currentScreen < 6 {
                    currentScreen += 1
                } else {
                    isFirstLaunch = false
                    EventManager.shared.completeFirstLaunch()
                }
            }
        }) {
            Image(systemName: locale.languageCode == "ar" ? "arrow.left" : "arrow.right")  // Меняем направление стрелки
                .font(.title)
                .foregroundColor(.white)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.4), Color.blue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: Color.blue.opacity(0.5), radius: 5, x: 0, y: 5)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 30)
    }
}




// MARK: - Первый экран
struct FirstScreenView: View {
    // Определяем язык пользователя
    var languageCode: String {
        Locale.current.languageCode ?? "en" // По умолчанию английский
    }
    
    // Словарь с соответствием языка и изображений
    let countryImages: [String: String] = [
        "ru": "firstscreen_russia",
        "ja": "firstscreen_japan",
        "ko": "firstscreen_korea",
        "it": "firstscreen_italy",
        "es": "firstscreen_spain",
        "tr": "firstscreen_turkey",
        "pt": "firstscreen_brazil",
        "de": "firstscreen_germany",
        "fr": "firstscreen_france",
        "en": "firstscreen_english",
        "zh": "firstscreen_china",
        "ar": "firstscreen_arabic"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            let imageName = countryImages[languageCode] ?? "firstscreen_default" // Выбираем изображение
            
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 350)
                .clipped()
                .ignoresSafeArea(edges: .top)
            
            VStack(alignment: .center) {
                EventCardPreviewView()
                    .padding(.horizontal, 30)
                    .padding(.top, -40)
                
                Text("FIRST_SCREEN_CREATE_EVENTS") // "Создавай события и Дни Рождения"
                    .font(.title3)
                    .foregroundColor(Color("darkCard"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
                    .padding(.bottom, 10)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}


// MARK: - Второй экран
struct SecondScreenView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image("2")
                .resizable()
                .scaledToFill()
                .frame(height: 370)
                .clipped()
                .ignoresSafeArea(edges: .top)
            
            VacationCardPreviewView()
                .padding(.top, -40)
                .padding(.horizontal, 30)
            
            Spacer()
            
            Text("SECOND_SCREEN_CHECKLISTS") // "Записывай заметки и интерактивные чек-листы"
                .font(.title3)
                .foregroundColor(Color("darkCard"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
                .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// Пример карточки для второго экрана
struct VacationCardPreviewView: View {
    @State private var autoRotateX: CGFloat = 0
    @State private var autoRotateY: CGFloat = 0
    @State private var direction: CGFloat = 0
    @State private var interactionOffset = CGSize.zero
    
    @State private var vacationEvent = Event(
        id: UUID(),
        name: NSLocalizedString("VACATION_BALI_EVENT_NAME", comment: ""), // "Отпуск на Бали"
        date: Date().addingTimeInterval(3600 * 24 * 10),
        showCountdown: true,
        eventType: .event,
        emoji: "🏖️",
        note: NSLocalizedString("VACATION_BALI_EVENT_NOTE", comment: ""), // "Забронировать отель, собрать чемодан"
        checklist: [
            ChecklistItem(text: NSLocalizedString("VACATION_BALI_CHECK_1", comment: ""), isCompleted: true),
            ChecklistItem(text: NSLocalizedString("VACATION_BALI_CHECK_2", comment: ""), isCompleted: false),
            ChecklistItem(text: NSLocalizedString("VACATION_BALI_CHECK_3", comment: ""), isCompleted: false)
        ],
        notificationEnabled: true,
        notificationTime: Date().addingTimeInterval(3600 * 24 * 7),
        deletePastEvents: false,
        notificationDaysOfWeek: [],
        notificationMonths: [],
        repeatInterval: .none,
        repeatMonthly: false,
        repeatYearly: false
    )
    
    var body: some View {
        VStack(spacing: 0) {
            Text("SECOND_SCREEN_EVENTS") // "События"
                .font(.system(size: 14))
                .foregroundColor(Color("darkCard"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 30)
                .padding(.bottom, 14)
            
            createCard(for: vacationEvent, autoRotateX: $autoRotateX, autoRotateY: $autoRotateY, interactionOffset: $interactionOffset)
                .onAppear {
                    startAutoRotation()
                }
        }
    }
    
    private func createCard(
        for event: Event,
        autoRotateX: Binding<CGFloat>,
        autoRotateY: Binding<CGFloat>,
        interactionOffset: Binding<CGSize>
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Уведомление
            HStack {
                Spacer()
                if event.notificationEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.yellow)
                        
                        Text(notificationTimeText(for: event.notificationTime))
                            .font(.caption2)
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    .padding(.trailing, 5)
                }
            }
            .padding(.top, 4)
            
            // Основное содержимое
            HStack(alignment: .top, spacing: 10) {
                Text(event.emoji)
                    .font(.system(size: 35))
                    .padding(.leading, 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name)
                        .font(.system(size: 18))
                        .lineLimit(1)
                        .foregroundColor(.white)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(eventDateText(for: event.date))
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.7))
                            
                            if eventIncludesTime(event.date) {
                                Text(eventTimeText(for: event.date))
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.7))
                            }
                        }
                        Spacer()
                        if let futureDate = getFutureDate(for: event.date, event: event) {
                            Text(futureDate, style: .relative)
                                .frame(maxWidth: 100, minHeight: 25, maxHeight: 30)
                                .monospacedDigit()
                                .multilineTextAlignment(.center)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .font(.footnote)
                                .padding(.horizontal, 8)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            if let note = event.note, !note.isEmpty {
                Divider()
                    .background(Color.gray.opacity(0.5))
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                
                Text(note)
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
            }
            
            if !event.checklist.isEmpty {
                Divider()
                    .background(Color.gray.opacity(0.5))
                    .padding(.horizontal, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(event.checklist, id: \.id) { item in
                        HStack {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isCompleted ? .green : .gray)
                            Text(item.text)
                                .strikethrough(item.isCompleted, color: .gray)
                                .foregroundColor(item.isCompleted ? .gray : .white.opacity(0.8))
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color("darkCard"))
        .cornerRadius(15)
        .shadow(color: .white.opacity(0.5), radius: 5, x: 0, y: 0)
        .rotation3DEffect(
            Angle(degrees: autoRotateY.wrappedValue + interactionOffset.wrappedValue.width / 15),
            axis: (x: 0.0, y: 1.0, z: 0.0)
        )
        .rotation3DEffect(
            Angle(degrees: autoRotateX.wrappedValue - interactionOffset.wrappedValue.height / 15),
            axis: (x: 1.0, y: 0.0, z: 0.0)
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    interactionOffset.wrappedValue = value.translation
                }
                .onEnded { _ in
                    withAnimation(.spring()) {
                        interactionOffset.wrappedValue = .zero
                    }
                }
        )
    }
    
    private func startAutoRotation() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                autoRotateX = 5 * sin(direction)
                autoRotateY = 5 * cos(direction)
            }
            direction += 0.04
        }
    }
    
    private func notificationTimeText(for date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func eventDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func eventTimeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func eventIncludesTime(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
        return timeComponents.hour != 0 || timeComponents.minute != 0
    }
    
    private func getFutureDate(for eventDate: Date, event: Event) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        if event.eventType == .birthday {
            let eventMonthDay = calendar.dateComponents([.month, .day], from: eventDate)
            let currentMonthDay = calendar.dateComponents([.month, .day], from: now)
            if let month = eventMonthDay.month, let day = eventMonthDay.day,
               let currentMonth = currentMonthDay.month, let currentDay = currentMonthDay.day {
                var futureDateComponents = DateComponents(year: calendar.component(.year, from: now), month: month, day: day)
                
                if currentMonth > month || (currentMonth == month && currentDay >= day) {
                    futureDateComponents.year! += 1
                }
                return calendar.date(from: futureDateComponents)
            }
        } else {
            return eventDate
        }
        return nil
    }
}

// MARK: - Третий экран
struct ThirdScreenView: View {
    var body: some View {
        ZStack(alignment: .top) {
            Image("3")
                .resizable()
                .scaledToFill()
                .frame(height: 370)
                .clipped()
                .ignoresSafeArea(edges: .top)
            
            VStack(spacing: 20) {
                VacationCardPreviewViewTHRE()
                    .padding(.top, 220)
                    .padding(.horizontal, 30)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

// Пример карточки для третьего экрана (таймеры)
struct VacationCardPreviewViewTHRE: View {
    @State private var autoRotateX: CGFloat = 0
    @State private var autoRotateY: CGFloat = 0
    @State private var direction: CGFloat = 0
    @State private var interactionOffset = CGSize.zero
    @Environment(\.locale) private var locale: Locale  // Добавляем свойство окружения
    
    @State private var vacationEvent = Event(
        id: UUID(),
        name: NSLocalizedString("TIMER_EVENT_1_NAME", comment: ""), // "Событие"
        date: Date().addingTimeInterval(125),
        showCountdown: true,
        eventType: .event,
        emoji: "🏖️",
        note: "",
        checklist: [],
        notificationEnabled: false,
        notificationTime: Date(),
        deletePastEvents: false,
        notificationDaysOfWeek: [],
        notificationMonths: [],
        repeatInterval: .none,
        repeatMonthly: false,
        repeatYearly: false
    )
    
    @State private var anotherVacationEvent = Event(
        id: UUID(),
        name: NSLocalizedString("TIMER_EVENT_2_NAME", comment: ""), // "Другое событие"
        date: Calendar.current.date(byAdding: .year, value: 2, to: Calendar.current.date(byAdding: .month, value: 8, to: Date())!)!,
        showCountdown: true,
        eventType: .event,
        emoji: "🎉",
        note: "",
        checklist: [],
        notificationEnabled: false,
        notificationTime: Date(),
        deletePastEvents: false,
        notificationDaysOfWeek: [],
        notificationMonths: [],
        repeatInterval: .none,
        repeatMonthly: false,
        repeatYearly: false
    )
    
    var body: some View {
        VStack {
            
            
            Text("THIRD_SCREEN_TIMER_TITLE") // <- Заменили "Таймер"
                .font(.system(
                    size: locale.languageCode == "es" ? 40 : 50, // Если язык "es", размер 40, иначе 50
                    weight: .bold)
                )
                .foregroundColor(Color("darkCard"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 110)
            
            
            Text("THIRD_SCREEN_TIMER_BEFORE") // <- Заменили "До события"
                .font(.system(size: 14).bold())
                .foregroundColor(Color("darkCard"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 30)
                .padding(.bottom, 2)
                .shadow(color: Color.white.opacity(0.4), radius: 5, x: 0, y: 0)
                .shadow(color: Color.white.opacity(0.2), radius: 10, x: 0, y: 0)
            
            createCard(for: vacationEvent,
                       autoRotateX: $autoRotateX,
                       autoRotateY: $autoRotateY,
                       interactionOffset: $interactionOffset,
                       backgroundColor: Color.blue,
                       reverseRotation: false)
            .onAppear {
                startAutoRotation()
            }
            
            // Текст под первой вращающейся ячейкой
            Text("THIRD_SCREEN_BLUE_TIMER_INFO")
                .font(.system(size: 12))
                .foregroundColor(Color("darkCard").opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            
            Text("THIRD_SCREEN_TIMER_AFTER") // <- Заменили "Прошло с момента события"
                .font(.system(size: 14).bold())
                .foregroundColor(Color("darkCard"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 30)
                .padding(.top, 30)
                .padding(.bottom, 2)
                .shadow(color: Color.white.opacity(0.4), radius: 5, x: 0, y: 0)
                .shadow(color: Color.white.opacity(0.2), radius: 10, x: 0, y: 0)
            
            createCard(for: anotherVacationEvent,
                       autoRotateX: $autoRotateX,
                       autoRotateY: $autoRotateY,
                       interactionOffset: $interactionOffset,
                       backgroundColor: Color("darkCard"),
                       reverseRotation: true)
            .onAppear {
                startAutoRotation()
            }
            
            // Текст под второй вращающейся ячейкой
            Text("THIRD_SCREEN_GRAY_TIMER_INFO")
                .font(.system(size: 12))
                .foregroundColor(Color("darkCard").opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
        }
        .padding(.horizontal, 16)
    }
    
    private func createCard(
        for event: Event,
        autoRotateX: Binding<CGFloat>,
        autoRotateY: Binding<CGFloat>,
        interactionOffset: Binding<CGSize>,
        backgroundColor: Color,
        reverseRotation: Bool
    ) -> some View {
        VStack(alignment: .center, spacing: 0) {
            if let futureDate = getFutureDate(for: event.date, event: event) {
                Text(futureDate, style: .relative)
                    .frame(maxWidth: 280, minHeight: 60, maxHeight: 80)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .font(.largeTitle)
                    .padding(.horizontal, 0)
                    .background(backgroundColor)
                    .cornerRadius(15)
            }
        }
        .padding(.vertical, 0)
        .padding(.horizontal, 0)
        .background(Color("darkCard"))
        .cornerRadius(15)
        .shadow(color: .white.opacity(0.5), radius: 4, x: 0, y: 2)
        .rotation3DEffect(
            Angle(degrees: reverseRotation
                  ? -(autoRotateY.wrappedValue + interactionOffset.wrappedValue.width / 15)
                  : (autoRotateY.wrappedValue + interactionOffset.wrappedValue.width / 15)),
            axis: (x: 0.0, y: 1.0, z: 0.0)
        )
        .rotation3DEffect(
            Angle(degrees: reverseRotation
                  ? -(autoRotateX.wrappedValue - interactionOffset.wrappedValue.height / 15)
                  : (autoRotateX.wrappedValue - interactionOffset.wrappedValue.height / 15)),
            axis: (x: 1.0, y: 0.0, z: 0.0)
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    interactionOffset.wrappedValue = value.translation
                }
                .onEnded { _ in
                    withAnimation(.spring()) {
                        interactionOffset.wrappedValue = .zero
                    }
                }
        )
    }
    
    private func startAutoRotation() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                autoRotateX = 5 * sin(direction)
                autoRotateY = 5 * cos(direction)
            }
            direction += 0.04
        }
    }
    
    private func getFutureDate(for eventDate: Date, event: Event) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        if event.eventType == .birthday {
            let eventMonthDay = calendar.dateComponents([.month, .day], from: event.date)
            let currentMonthDay = calendar.dateComponents([.month, .day], from: now)
            if let month = eventMonthDay.month, let day = eventMonthDay.day,
               let currentMonth = currentMonthDay.month, let currentDay = currentMonthDay.day {
                var futureDateComponents = DateComponents(year: calendar.component(.year, from: now), month: month, day: day)
                if currentMonth > month || (currentMonth == month && currentDay >= day) {
                    futureDateComponents.year! += 1
                }
                return calendar.date(from: futureDateComponents)
            }
        } else {
            return eventDate
        }
        return nil
    }
}







// Превью-карточка для первого экрана (EventCardPreviewView)
struct EventCardPreviewView: View {
    @State private var autoRotateXEvent: CGFloat = 0
    @State private var autoRotateYEvent: CGFloat = 0
    @State private var directionEvent: CGFloat = 0
    @State private var interactionOffsetEvent = CGSize.zero
    
    @State private var autoRotateXBirthday: CGFloat = 0
    @State private var autoRotateYBirthday: CGFloat = 0
    @State private var directionBirthday: CGFloat = 0
    @State private var interactionOffsetBirthday = CGSize.zero
    
    var event: Event = Event(
        id: UUID(),
        name: NSLocalizedString("FIRST_SCREEN_EVENT_NAME", comment: ""),     // "Встреча с командой"
        date: Date().addingTimeInterval(3600 * 24),
        showCountdown: true,
        eventType: .event,
        emoji: "",
        note: NSLocalizedString("FIRST_SCREEN_EVENT_NOTE", comment: ""),     // "Обсудить стратегию на Q1"
        checklist: [
            ChecklistItem(text: NSLocalizedString("FIRST_SCREEN_CHECK_1", comment: ""), isCompleted: false),
            ChecklistItem(text: NSLocalizedString("FIRST_SCREEN_CHECK_2", comment: ""), isCompleted: true)
        ],
        notificationEnabled: false,
        notificationTime: Date().addingTimeInterval(3600),
        deletePastEvents: false,
        notificationDaysOfWeek: [],
        notificationMonths: [],
        repeatInterval: .none,
        repeatMonthly: false,
        repeatYearly: false
    )
    
    var birthdayEvent: Event = Event(
        id: UUID(),
        name: NSLocalizedString("FIRST_SCREEN_BIRTHDAY_NAME", comment: ""), // "День рождения Анны"
        date: Date().addingTimeInterval(3600 * 24 * 3),
        showCountdown: true,
        eventType: .birthday,
        emoji: "🥂",
        note: NSLocalizedString("FIRST_SCREEN_BIRTHDAY_NOTE", comment: ""), // "Подарок купить"
        checklist: [],
        notificationEnabled: true,
        notificationTime: Date().addingTimeInterval(3600),
        deletePastEvents: false,
        notificationDaysOfWeek: [],
        notificationMonths: [],
        repeatInterval: .none,
        repeatMonthly: false,
        repeatYearly: true
    )
    
    var body: some View {
        VStack(spacing: 6) {
            Text("FIRST_SCREEN_EVENTS_LABEL") // "События"
                .font(.system(size: 14))
                .foregroundColor(Color("darkCard"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 30)
            
            createCard(
                for: event,
                autoRotateX: $autoRotateXEvent,
                autoRotateY: $autoRotateYEvent,
                interactionOffset: $interactionOffsetEvent
            )
            
            Text("FIRST_SCREEN_BIRTHDAYS_LABEL") // "Дни рождения"
                .font(.system(size: 14))
                .foregroundColor(Color("darkCard"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 30)
                .padding(.top, 2)
            
            createCard(
                for: birthdayEvent,
                autoRotateX: $autoRotateXBirthday,
                autoRotateY: $autoRotateYBirthday,
                interactionOffset: $interactionOffsetBirthday
            )
            Spacer()
        }
        .onAppear {
            startAutoRotation()
        }
    }
    
    private func createCard(
        for event: Event,
        autoRotateX: Binding<CGFloat>,
        autoRotateY: Binding<CGFloat>,
        interactionOffset: Binding<CGSize>
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                if event.notificationEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.yellow)
                        Text(notificationTimeText(for: event.notificationTime))
                            .font(.caption2)
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    .padding(.trailing, 5)
                }
            }
            .padding(.top, 10)
            
            HStack(alignment: .top, spacing: 6) {
                Text(event.emoji)
                    .font(.system(size: 35))
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name)
                        .font(.system(size: 18))
                        .lineLimit(2)
                        .foregroundColor(.white)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(eventDateText(for: event.date))
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.7))
                            
                            if event.eventType == .birthday {
                                Text(String(format: NSLocalizedString("FIRST_SCREEN_AGE_LABEL", comment: ""), calculateAge(for: event.date)))
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.7))
                            } else if eventIncludesTime(event.date) {
                                Text(eventTimeText(for: event.date))
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.7))
                            }
                        }
                        Spacer()
                        if let futureDate = getFutureDate(for: event.date, event: event) {
                            Text(futureDate, style: .relative)
                                .frame(maxWidth: 100, minHeight: 25, maxHeight: 30)
                                .monospacedDigit()
                                .multilineTextAlignment(.center)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .font(.footnote)
                                .padding(.horizontal, 8)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(.top, 2)
            }
            
            if let note = event.note, !note.isEmpty {
                Divider()
                    .background(Color.gray.opacity(0.5))
                    .padding(.top, 4)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                
                Text(note)
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineLimit(5)
                    .padding(.top, 6)
                    .padding(.horizontal, 6)
                    .padding(.bottom,8)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(width: 310, height: 130)
        .background(Color("darkCard"))
        .cornerRadius(15)
        .shadow(color: .white.opacity(0.5), radius: 5, x: 0, y: 0)
        .rotation3DEffect(
            Angle(degrees: autoRotateY.wrappedValue + interactionOffset.wrappedValue.width / 15),
            axis: (x: 0.0, y: 1.0, z: 0.0)
        )
        .rotation3DEffect(
            Angle(degrees: autoRotateX.wrappedValue - interactionOffset.wrappedValue.height / 15),
            axis: (x: 1.0, y: 0.0, z: 0.0)
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    interactionOffset.wrappedValue = value.translation
                }
                .onEnded { _ in
                    withAnimation(.spring()) {
                        interactionOffset.wrappedValue = .zero
                    }
                }
        )
    }
    
    private func startAutoRotation() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                autoRotateXEvent = 5 * sin(directionEvent)
                autoRotateYEvent = 5 * cos(directionEvent)
                autoRotateXBirthday = 5 * sin(directionEvent - 0.3)
                autoRotateYBirthday = 5 * cos(directionEvent - 0.3)
            }
            directionEvent += 0.06
            directionBirthday += 0.06
        }
    }
    
    private func calculateAge(for date: Date?) -> Int {
        guard let date = date else {
            return 24
        }
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year], from: date, to: now)
        return max(components.year ?? 24, 24)
    }
    
    private func eventDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func eventTimeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func notificationTimeText(for date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func eventIncludesTime(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
        return timeComponents.hour != 0 || timeComponents.minute != 0
    }
    
    private func getFutureDate(for eventDate: Date, event: Event) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        if event.eventType == .birthday {
            let eventMonthDay = calendar.dateComponents([.month, .day], from: event.date)
            let currentMonthDay = calendar.dateComponents([.month, .day], from: now)
            if let month = eventMonthDay.month, let day = eventMonthDay.day,
               let currentMonth = currentMonthDay.month, let currentDay = currentMonthDay.day {
                var futureDateComponents = DateComponents(
                    year: calendar.component(.year, from: now),
                    month: month,
                    day: day
                )
                if currentMonth > month || (currentMonth == month && currentDay >= day) {
                    futureDateComponents.year! += 1
                }
                return calendar.date(from: futureDateComponents)
            }
        } else {
            return eventDate
        }
        return nil
    }
}

// MARK: - Экран уведомлений (5-й)
struct NotificationWelcomeView: View {
    @Binding var currentScreen: Int
    @Binding var isFirstLaunch: Bool?
    
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                Text("NOTIFICATION_SCREEN_TITLE") // "Получай короткие или длинные уведомления"
                    .font(.system(size: 28))
                    .foregroundColor(Color("darkCard"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
            }
            Spacer()
            
            PushBellView()
                .frame(width: 120, height: 120)
                .padding()
            
            Spacer()
            
            VStack(spacing: 20) {
                Text("NOTIFICATION_SCREEN_SUBTITLE") // "Что бы быть в курсе предстоящих событий"
                    .font(.system(size: 22))
                    .foregroundColor(Color("darkCard").opacity(0.9))
                    .padding(.horizontal, 60)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                NotificationPermissionButton(currentScreen: $currentScreen)
                    .padding(.top, 30)
                    .padding(.bottom, 30)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Анимация колокольчика (PushBellView)
struct PushBellView: View {
    @State private var isPushed = false
    @State private var task: Task<Void, Never>? = nil
    
    var body: some View {
        Image(systemName: "bell.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
            .foregroundColor(.yellow)
            .shadow(color: .yellow.opacity(0.2), radius: 2, x: 1, y: -1)
            .shadow(color: .white.opacity(0.5), radius: 4, x: 1, y: -1)
            .scaleEffect(isPushed ? 1.4 : 1.0)
            .opacity(isPushed ? 0.8 : 1.0)
            .rotationEffect(isPushed ? Angle(degrees: 10) : Angle(degrees: 0))
            .animation(
                isPushed
                ? Animation.easeOut(duration: 0.6)
                : Animation.interpolatingSpring(stiffness: 200, damping: 10),
                value: isPushed
            )
            .overlay(
                RoundedRectangle(cornerRadius: 60)
                    .stroke(Color.yellow.opacity(isPushed ? 1 : 0), lineWidth: 4)
                    .blur(radius: isPushed ? 10 : 0)
            )
            .onAppear {
                task = Task {
                    while !Task.isCancelled {
                        withAnimation {
                            isPushed = true
                        }
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        withAnimation {
                            isPushed = false
                        }
                        try? await Task.sleep(nanoseconds: 900_000_000)
                    }
                }
            }
            .onDisappear {
                task?.cancel()
            }
    }
}

// MARK: - Кнопка "Разрешить уведомления"
struct NotificationPermissionButton: View {
    @Binding var currentScreen: Int
    
    var body: some View {
        Button(action: {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("Ошибка при запросе разрешения: \(error.localizedDescription)")
                } else {
                    print("Разрешение предоставлено: \(granted)")
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            currentScreen += 1
                        }
                    }
                }
            }
        }) {
            Text("NOTIFICATION_ALLOW_BUTTON") // "Разрешить уведомления"
                .font(.title2)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.4), Color.blue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - 6-й экран (Подписка)
struct SubscriptionWelcomeView: View {
    @Binding var isFirstLaunch: Bool?
    @State private var isUnlocked = false
    
    // Определяем язык пользователя
    var languageCode: String {
        Locale.current.languageCode ?? "en" // По умолчанию английский
    }
    
    // Словарь с соответствием языка и изображений
    let countryImages: [String: String] = [
        "ru": "subscription_russia",
        "ja": "subscription_japan",
        "ko": "subscription_korea",
        "it": "subscription_italy",
        "es": "subscription_spain",
        "tr": "subscription_turkey",
        "pt": "subscription_brazil",
        "de": "subscription_germany",
        "fr": "subscription_france",
        "en": "subscription_english",
        "zh": "subscription_china",
        "ar": "subscription_arabic"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            let imageName = countryImages[languageCode] ?? "subscription_default" // Выбираем изображение
            
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 370)
                .clipped()
                .ignoresSafeArea(edges: .top)
            
            ZStack {
                AnimatedKeyView()
                    .padding(.top, -20)
            }
            
            Spacer(minLength: 20)
            
            Text("SUBSCRIPTION_UNLIMITED_EVENTS") // "Создавай неограниченное число событий"
                .font(.system(size: 22))
                .foregroundColor(Color("darkCard"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            SubscriptionButton(isFirstLaunch: $isFirstLaunch) {
                withAnimation {
                    isUnlocked = true
                }
            }
            .padding(.horizontal, 40)
            
            NotNowButton(isFirstLaunch: $isFirstLaunch)
                .padding(.horizontal, 40)
                .padding(.top, 10)

            RestorePurchasesButton(isFirstLaunch: $isFirstLaunch)
                .padding(.horizontal, 40)
             
        }
    }
}


// Анимированный VIP-ключ (звезда)
struct AnimatedKeyView: View {
    @State private var glowOpacity = 0.0
    @State private var jiggle = false
    @State private var scaleEffectValue: CGFloat = 1.0
    @State private var isTapped = false
    
    var body: some View {
        VStack {
            Spacer()
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.cyan.opacity(0.7),
                                Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.7),
                                Color.indigo.opacity(0.7)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 5
                    )
                    .frame(width: 150, height: 150)
                    .blur(radius: 10)
                    .opacity(glowOpacity)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowOpacity)
                    .onAppear {
                        glowOpacity = 1.0
                    }
                
                ZStack {
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.cyan,
                                    Color(red: 1.0, green: 0.0, blue: 1.0),
                                    Color.indigo
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.cyan.opacity(0.6), radius: 5, x: 0, y: 0)
                        .shadow(color: Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.6), radius: 5, x: 0, y: 0)
                        .rotationEffect(Angle(degrees: jiggle ? 8 : -8))
                        .animation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true),
                            value: jiggle
                        )
                        .onAppear {
                            jiggle = true
                        }
                    
                    Text("VIP")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.yellow, Color.orange]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.yellow.opacity(0.8), radius: 3, x: 0, y: 0)
                        .rotationEffect(Angle(degrees: jiggle ? 8 : -8))
                        .animation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true),
                            value: jiggle
                        )
                }
                .scaleEffect(scaleEffectValue)
                .animation(
                    Animation.easeInOut(duration: 0.3),
                    value: scaleEffectValue
                )
                .gesture(
                    TapGesture()
                        .onEnded {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isTapped.toggle()
                                scaleEffectValue = isTapped ? 1.1 : 1.0
                            }
                        }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: 200)
            Spacer()
        }
    }
}

// Анимированный замок (не используется напрямую, но как пример)
struct AnimatedLockView: View {
    @State private var isUnlocked = false
    @State private var keyOffset: CGSize = .zero
    @State private var animateShackle = false
    @State private var glowOpacity = 0.0
    @State private var rotateLock = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.purple.opacity(glowOpacity), lineWidth: 8)
                .frame(width: 200, height: 200)
                .blur(radius: 10)
                .opacity(isUnlocked ? 0.8 : 0.0)
                .animation(.easeInOut(duration: 1.0), value: isUnlocked)
            
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.yellow, Color.orange]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 20)
                    .offset(y: animateShackle ? -60 : 0)
                    .rotationEffect(Angle(degrees: animateShackle ? -45 : 0))
                    .animation(.easeInOut(duration: 1.0), value: animateShackle)
                
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.blue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 100)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
                    .overlay(
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 24, height: 24)
                            )
                            .offset(y: -40)
                    )
            }
            .rotation3DEffect(
                Angle(degrees: rotateLock ? 10 : -10),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: rotateLock)
            .onAppear {
                rotateLock = true
            }
            
            Image(systemName: "key.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundColor(.yellow)
                .offset(x: keyOffset.width, y: keyOffset.height)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            keyOffset = value.translation
                        }
                        .onEnded { _ in
                            if abs(keyOffset.width) < 50 && abs(keyOffset.height) < 50 {
                                withAnimation(.easeInOut(duration: 1.0)) {
                                    isUnlocked = true
                                    animateShackle = true
                                    glowOpacity = 0.8
                                }
                            }
                            withAnimation(.spring()) {
                                keyOffset = .zero
                            }
                        }
                )
                .shadow(color: Color.yellow.opacity(0.6), radius: 5, x: 0, y: 0)
        }
    }
}

// MARK: - Кнопка "Подключить на год"
struct SubscriptionButton: View {
    @State private var transactionInProgress = false
    @State private var errorMessage: String?
    @Binding var isFirstLaunch: Bool?
    var onSuccess: () -> Void
    
    @State private var glowOpacity = 0.5
    @State private var scaleEffect = 1.0
    
    var body: some View {
        Spacer()
        Button(action: {
            purchaseAnnualSubscription()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.purple,
                                Color.cyan,
                                Color.blue
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.purple.opacity(glowOpacity), radius: 10, x: 0, y: 0)
                    .frame(height: 50)
                    .scaleEffect(scaleEffect)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            glowOpacity = 0.9
                            scaleEffect = 1.05
                        }
                    }
                
                Text("SUBSCRIPTION_BUTTON_ANNUAL") // "Подключить на год"
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 40)
        }
        .disabled(transactionInProgress)
        .alert(isPresented: .constant(errorMessage != nil)) {
            Alert(
                title: Text("SUBSCRIPTION_ERROR_TITLE"), // "Ошибка"
                message: Text(errorMessage ?? NSLocalizedString("SUBSCRIPTION_ERROR_DEFAULT", comment: "")),
                dismissButton: .default(Text("SUBSCRIPTION_OK_BUTTON")) {
                    errorMessage = nil
                }
            )
        }
    }
    
    private func purchaseAnnualSubscription() {
        transactionInProgress = true
        errorMessage = nil
        
        Purchases.shared.getOfferings { offerings, error in
            if let error = error {
                errorMessage = error.localizedDescription
                transactionInProgress = false
                return
            }
            
            guard let offering = offerings?.current,
                  let package = offering.annual else {
                errorMessage = NSLocalizedString("SUBSCRIPTION_NO_PACKAGES", comment: "")
                transactionInProgress = false
                return
            }
            
            Purchases.shared.purchase(package: package) { transaction, customerInfo, error, userCancelled in
                transactionInProgress = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else if let customerInfo = customerInfo, customerInfo.entitlements["Pro"]?.isActive == true {
                    EventManager.shared.settings?.pro = true
                    EventManager.shared.subscriptionIsActive = true
                    NotificationCenter.default.post(name: NSNotification.Name("Pro"), object: nil)
                    EventManager.shared.completeFirstLaunch()
                    isFirstLaunch = false
                    onSuccess()
                } else if userCancelled {
                    errorMessage = NSLocalizedString("SUBSCRIPTION_CANCELED_BY_USER", comment: "")
                } else {
                    errorMessage = NSLocalizedString("SUBSCRIPTION_PURCHASE_ERROR", comment: "")
                }
            }
        }
    }
}

// MARK: - Кнопка "Не сейчас"
struct NotNowButton: View {
    @Binding var isFirstLaunch: Bool?
    
    var body: some View {
        Button(action: {
            isFirstLaunch = false
            EventManager.shared.completeFirstLaunch()
        }) {
            Text("SUBSCRIPTION_NOT_NOW_BUTTON") // "Не сейчас"
                .font(.callout)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.bottom, 10)
    }
}

// MARK: - Кнопка "Восстановить покупки"
struct RestorePurchasesButton: View {
    @Binding var isFirstLaunch: Bool?

    var body: some View {
        Button(action: {
            Purchases.shared.restorePurchases { customerInfo, _ in
                if let info = customerInfo,
                   info.entitlements["Pro"]?.isActive == true {
                    EventManager.shared.settings?.pro = true
                    EventManager.shared.subscriptionIsActive = true
                    NotificationCenter.default.post(name: NSNotification.Name("Pro"), object: nil)
                    EventManager.shared.completeFirstLaunch()
                    DispatchQueue.main.async {
                        isFirstLaunch = false
                    }
                }
            }
        }) {
            Text("SUBSCRIPTION_RESTORE_BUTTON")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Индикатор
struct IndicatorView: View {
    @Binding var currentScreen: Int
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...6, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(currentScreen == index ? 1 : 0.4))
                    .frame(width: currentScreen == index ? 25 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.5), value: currentScreen)
            }
        }
        .background(Color.clear)
    }
}







struct SwipeableModifier: ViewModifier {
    let threshold: CGFloat = 380.0 // Порог для триггера свайпа
    let maxOffset: CGFloat = 500.0 // Максимальное смещение для длинного свайпа
    let minOffset: CGFloat = 120.0 // Минимальное смещение для фиксации
    let iconWidth: CGFloat = 80.0 // Ширина иконки корзины и закрепления + отступы
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    @State private var isIconVisible = true
    @State private var hasVibratedForMaxOffset = false
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void
    let isPinned: Bool // Добавлен флаг для проверки закрепленности
    
    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            HStack {
                if offset > 20 {
                    ZStack {
                        Color.green
                            .frame(maxWidth: .infinity, maxHeight: .infinity) // Заливка на всю карточку
                            .cornerRadius(15)

                        VStack {
                            Spacer()
                            Image(systemName: isPinned ? "pin.slash.fill" : "pin.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: getIconSize(for: offset), height: getIconSize(for: offset))
                                .foregroundColor(.white)
                                .padding(30)
                                .opacity(isIconVisible ? 1 : 0)
                                .scaleEffect(isIconVisible ? 1 : 0.5)
                                .animation(.easeInOut, value: isIconVisible)
                                .offset(x: offset > maxOffset ? maxOffset : offset - iconWidth)
                                .animation(.easeInOut, value: offset)
                            Spacer()
                        }
                    }
                }

                Spacer()

                if offset < -20 {
                    ZStack {
                        Color.red
                            .frame(maxWidth: .infinity, maxHeight: .infinity) // Заливка на всю карточку
                            .cornerRadius(15)

                        VStack {
                            Spacer()
                            Image(systemName: "trash.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: getIconSize(for: -offset), height: getIconSize(for: -offset))
                                .foregroundColor(.white)
                                .padding(30)
                                .opacity(isIconVisible ? 1 : 0)
                                .scaleEffect(isIconVisible ? 1 : 0.5)
                                .animation(.easeInOut, value: isIconVisible)
                                .offset(x: offset < -maxOffset ? -maxOffset : offset + iconWidth)
                                .animation(.easeInOut, value: offset)
                            Spacer()
                        }
                    }
                }


            }
            
            content
                .offset(x: offset)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.3), value: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let dragAmount = value.translation.width
                            if !isSwiping {
                                isSwiping = true
                            }
                            if dragAmount < 0 {
                                withAnimation {
                                    offset = max(dragAmount, -maxOffset)
                                }
                            } else if dragAmount > 0 {
                                withAnimation {
                                    offset = min(dragAmount, maxOffset)
                                }
                            } else {
                                withAnimation {
                                    offset = dragAmount
                                }
                            }
                            
                            // Вибрация при достижении максимального предела
                            if abs(offset) >= maxOffset && !hasVibratedForMaxOffset {
                                generateFeedback(style: .heavy)
                                hasVibratedForMaxOffset = true
                            } else if abs(offset) < maxOffset {
                                hasVibratedForMaxOffset = false
                            }
                        }
                        .onEnded { value in
                            if value.translation.width < -threshold {
                                onSwipeLeft()
                                animateIcon()
                                withAnimation {
                                    offset = -maxOffset
                                }
                                generateFeedback(style: .heavy)
                            } else if value.translation.width > threshold {
                                onSwipeRight()
                                animateIcon()
                                withAnimation {
                                    offset = maxOffset
                                }
                                generateFeedback(style: .heavy)
                            } else {
                                // Фиксируем смещение ближе к значку при частичном свайпе
                                withAnimation {
                                    if value.translation.width < 0 {
                                        offset = value.translation.width <= -minOffset ? -(iconWidth - 12) : 0
                                    } else if value.translation.width > 0 {
                                        offset = value.translation.width >= minOffset ? iconWidth - 12 : 0
                                    } else {
                                        offset = 0
                                    }
                                }
                                generateFeedback(style: .soft)
                            }
                            isSwiping = false
                        }
                )
        }
    }
    
    private func getIconSize(for offset: CGFloat) -> CGFloat {
        let size = 40 + (offset / maxOffset) * 20
        return max(40, min(size, 60))
    }
    
    private func animateIcon() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isIconVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isIconVisible = true
            }
        }
    }
    
    private func generateFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        HapticManager.shared.impact(style: style)
    }
}

extension View {
    func swipeable(isPinned: Bool, onSwipeLeft: @escaping () -> Void, onSwipeRight: @escaping () -> Void) -> some View {
        self.modifier(SwipeableModifier(onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight, isPinned: isPinned))
    }
}





struct EventCardView: View {
    let event: Event
    
    @EnvironmentObject var asEvents: EventManager
    
    // Для обработки свайпов
    @State private var offset: CGSize = .zero
    @State private var isSwiping: Bool = false
    @State private var isDragging: Bool = false
    
    // Анимация обводки и прочее
    @State private var gradientRotation = 0.0
    @State private var showCard = false
    @State private var showEditModal = false
    @State private var isPressed = false
    @State private var showNotificationTime = false
    
    // Логика таймера
    @State private var countdownText: String = ""
    @State private var timer: Timer?
    @State private var timerBackgroundColor: Color = .blue
    
    @State private var isExpandedContent = false // Для развертывания списка
    private let visibleChecklistCount = 3
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack(alignment: .leading) {
            // MARK: - Фон с иконками (виден при свайпе)
            if offset.width > 0 {
                HStack {
                    Image(systemName: event.isPinned ? "pin.slash.fill" : "pin.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(.leading, 30)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(15)
            } else if offset.width < 0 {
                HStack {
                    Spacer()
                    Image(systemName: "trash.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(.trailing, 30)
                }
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .cornerRadius(15)
            }
            
            // MARK: - Основной контент карточки
            VStack(alignment: .leading, spacing: 0) {
                // 1. Иконка уведомления
                HStack {
                    Spacer()
                    if event.notificationEnabled {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .resizable()
                                .frame(width: 15, height: 15)
                                .foregroundColor(.yellow)
                                .onTapGesture {
                                    toggleNotificationTime()
                                    generateFeedback(style: .medium)
                                }
                            if showNotificationTime {
                                Divider()
                                    .background(Color.gray)
                                    .frame(height: 15)
                                Text(notificationTimeText(for: event.notificationTime))
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                        .padding(.trailing, 5)
                    }
                }
                .padding(.top, 2)
                
                // 2. Основная строка
                HStack(alignment: .top, spacing: 10) {
                    Text(event.emoji)
                        .font(.system(size: 45))
                        .padding(.top, 2)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(event.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.bottom, 4)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                if event.eventType == .birthday {
                                    Text(
                                        DateFormatter.localizedString(
                                            from: event.date,
                                            dateStyle: .long,
                                            timeStyle: .none
                                        )
                                    )
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    
                                    if let age = event.age {
                                        Text(String(format: NSLocalizedString("event.age_prefix", comment: ""), age))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                } else {
                                    Text(eventDateText(for: event.date))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if eventIncludesTime(event.date) {
                                        Text(eventTimeText(for: event.date))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            if event.eventType == .birthday && isTodayBirthday(eventDate: event.date) {
                                Text(NSLocalizedString("event.birthday_today", comment: ""))
                                    .frame(width: 130, height: 20)
                                    .monospacedDigit()
                                    .multilineTextAlignment(.center)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .font(.footnote)
                                    .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                                    .background(Color.green.opacity(0.8))
                                    .cornerRadius(8)
                            } else if let futureDate = getFutureDate(for: event.date, event: event) {
                                Text(futureDate, style: .relative)
                                    .frame(width: 130, height: 20)
                                    .monospacedDigit()
                                    .multilineTextAlignment(.center)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .font(.footnote)
                                    .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                                    .background(timerBackgroundColor)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                
                // 3. Примечание
                if let note = event.note, !note.isEmpty {
                    Divider()
                        .background(Color.gray.opacity(0.5))
                        .padding(.top, 8)
                        .padding(.horizontal, 4)

                    Text(note)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpandedContent ? nil : 3)
                        .padding(.top, 8)
                        .padding(.horizontal, 10)
                }
                
                // 4. Чек-лист
                if !event.checklist.isEmpty {
                    Divider()
                        .background(Color.gray.opacity(0.5))
                        .padding(.top, 8)
                        .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(event.checklist.prefix(isExpandedContent
                                                      ? event.checklist.count
                                                      : 4),
                                id: \.id) { item in
                            HStack {
                                Button {
                                    toggleChecklistItemCompletion(item: item)
                                } label: {
                                    Image(systemName: item.isCompleted
                                          ? "checkmark.circle.fill"
                                          : "circle")
                                        .foregroundColor(item.isCompleted ? .green : .gray)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Text(item.text)
                                    .strikethrough(item.isCompleted, color: .gray)
                                    .foregroundColor(item.isCompleted ? .gray : .primary)
                                    .font(.caption)
                            }
                        }

                        let hiddenCount = max(0, event.checklist.count - 4)
                        if !isExpandedContent && hiddenCount > 0 {
                            Text(
                                String(
                                    format: NSLocalizedString("event.more_tasks",
                                                            comment: "и ещё %d задач..."),
                                    hiddenCount
                                )
                            )
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(Color.gray.opacity(0.5))
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 10)
                }

                // 5. Метки повтора
                if eventHasRepeatInfo() {
                    HStack {
                        if event.repeatYearly {
                            Text(NSLocalizedString("event.repeat_annually_text", comment: ""))
                                .tagLabelStyle(isHighlighted: true)
                        }
                        if event.repeatMonthly {
                            Text(NSLocalizedString("event.repeat_monthly_text", comment: ""))
                                .tagLabelStyle(isHighlighted: true)
                        }

                        if event.repeatInterval != .none {
                            Text("\(event.repeatInterval.displayName)")
                                .tagLabelStyle(isHighlighted: true)
                        }
                        ForEach(DayOfWeek.allCases, id: \.self) { day in
                            if event.notificationDaysOfWeek.contains(day) {
                                Text("\(day.displayName)")
                                    .tagLabelStyle(isHighlighted: dayIsNearest(day))
                            }
                        }
                        ForEach(event.notificationMonths, id: \.self) { month in
                            Text("\(month.displayName)")
                                .tagLabelStyle(isHighlighted: monthIsNearest(month))
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 4)
                }
                
                // 6. Кнопка «показать всё / свернуть»
                if canToggleContent {
                    Button(action: {
                        withAnimation(.easeInOut) {
                            isExpandedContent.toggle()
                        }
                    }) {
                        Image(systemName: isExpandedContent ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(height: 11)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color("BackgroundCard"))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(lineWidth: event.isToday ? 2 : 0)
                    .foregroundStyle(
                        AngularGradient(
                            gradient: Gradient(colors: [Color.green, Color.clear, Color.blue, Color.clear, Color.green]),
                            center: .center,
                            angle: .degrees(gradientRotation)
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.green.opacity(0.5),
                                Color.clear,
                                Color.blue.opacity(0.5),
                                Color.clear,
                                Color.green.opacity(0.5)
                            ]),
                            center: .center,
                            angle: .degrees(gradientRotation)
                        ),
                        lineWidth: event.isToday ? 2 : 0
                    )
                    .blur(radius: 2)
            )
            .onAppear {
                withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                    gradientRotation += 360
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.5)) {
                    showCard = true
                }
                setupTimer()
            }
            .onDisappear {
                timer?.invalidate()
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.05)) {
                    isPressed = true
                    generateFeedback(style: .medium)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    showEditModal.toggle()
                    withAnimation(.easeInOut(duration: 0.05)) {
                        isPressed = false
                    }
                }
            }
            .sheet(isPresented: $showEditModal) {
                EditEventView(event: event,
                              eventType: event.eventType,
                              eventIndex: findEventIndex(event: event))
                .environmentObject(asEvents)
            }
            .offset(x: showCard ? 0 : -UIScreen.main.bounds.width)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 0)
            .offset(x: offset.width)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.5), value: offset)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { gesture in
                        if abs(gesture.translation.width) > abs(gesture.translation.height) {
                            isSwiping = true
                            let resistance: CGFloat = 2.5
                            offset.width = gesture.translation.width / resistance
                            
                            // Вибрация при достижении порога
                            if abs(offset.width) > 80 && !isDragging {
                                generateFeedback(style: .medium)
                                isDragging = true
                            }
                        }
                    }
                    .onEnded { gesture in
                        if isSwiping {
                            let swipeThreshold: CGFloat = 120
                            let swipeVelocityThreshold: CGFloat = 200
                            let swipeVelocity = gesture.predictedEndLocation.x - gesture.location.x
                            
                            // Удаление (свайп влево)
                            if offset.width < -swipeThreshold || (offset.width < -50 && swipeVelocity < -swipeVelocityThreshold) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    offset.width = -UIScreen.main.bounds.width
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    EventManager.shared.deleteEvent(event, eventType: event.eventType, modelContext: modelContext)
                                }
                                generateFeedback(style: .heavy)
                            }
                            // Закрепить/открепить (свайп вправо)
                            else if offset.width > swipeThreshold || (offset.width > 50 && swipeVelocity > swipeVelocityThreshold) {
                                withAnimation {
                                    if event.isPinned {
                                        EventManager.shared.unpinEvent(event, eventType: event.eventType)
                                    } else {
                                        EventManager.shared.pinEvent(event, eventType: event.eventType)
                                    }
                                    offset.width = 0
                                }
                                generateFeedback(style: .medium)
                            }
                            // Возврат в исходное положение
                            else {
                                withAnimation(.spring()) {
                                    offset = .zero
                                }
                            }
                            isSwiping = false
                            isDragging = false
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { _ in isDragging = true }
                    .onEnded { _ in isDragging = false }
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    // MARK: - Вычисляемые свойства и методы
    
    private var canToggleContent: Bool {
        let noteLines = event.note?.split(separator: "\n").count ?? 0
        let isNoteLong = noteLines > 4
        let isChecklistLong = event.checklist.count > 4
        return isNoteLong || isChecklistLong
    }
    
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            updateCountdown()
        }
        updateCountdown()
    }
    
    private func updateCountdown() {
        let now = Date()
        if event.eventType != .birthday && !eventHasRepeatInfo() && event.date < now {
            changeTimerBackgroundColor()
        }
    }
    
    private func changeTimerBackgroundColor() {
        withAnimation {
            timerBackgroundColor = Color.gray
        }
    }
    
    private func eventHasRepeatInfo() -> Bool {
        return event.repeatYearly
        || event.repeatMonthly
        || event.repeatInterval != .none
        || !event.notificationDaysOfWeek.isEmpty
        || !event.notificationMonths.isEmpty
    }
    
    private func toggleNotificationTime() {
        withAnimation {
            showNotificationTime.toggle()
        }
    }
    
    private func eventDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func eventTimeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func notificationTimeText(for date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy HH:mm"
        let now = Date()
        var displayDate = date
        if displayDate < now {
            displayDate = Calendar.current.date(byAdding: .year, value: 1, to: displayDate) ?? displayDate
        }
        return formatter.string(from: displayDate)
    }
    
    private func eventIncludesTime(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
        return (timeComponents.hour ?? 0) != 0 || (timeComponents.minute ?? 0) != 0
    }
    
    private func findEventIndex(event: Event) -> Int {
        switch event.eventType {
        case .event:
            return asEvents.events.firstIndex(where: { $0.id == event.id }) ?? -1
        case .birthday:
            return asEvents.birthdays.firstIndex(where: { $0.id == event.id }) ?? -1
        }
    }
    
    private func generateFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        HapticManager.shared.impact(style: style)
    }
    
    private func getFutureDate(for eventDate: Date, event: Event) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        if event.eventType == .birthday {
            let eventMonthDay = calendar.dateComponents([.month, .day], from: eventDate)
            let currentMonthDay = calendar.dateComponents([.month, .day], from: now)
            
            if let month = eventMonthDay.month,
               let day = eventMonthDay.day,
               let currentMonth = currentMonthDay.month,
               let currentDay = currentMonthDay.day {
                var futureDateComponents = DateComponents(
                    year: calendar.component(.year, from: now),
                    month: month,
                    day: day
                )
                if currentMonth > month || (currentMonth == month && currentDay >= day) {
                    futureDateComponents.year! += 1
                }
                return calendar.date(from: futureDateComponents)
            }
        } else {
            return eventDate
        }
        return nil
    }
    
    private func isTodayBirthday(eventDate: Date) -> Bool {
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.month, .day], from: Date())
        let eventComponents = calendar.dateComponents([.month, .day], from: eventDate)
        return (todayComponents.month == eventComponents.month
                && todayComponents.day == eventComponents.day)
    }
    
    private func toggleChecklistItemCompletion(item: ChecklistItem) {
        var updatedEvent = event
        if let itemIndex = updatedEvent.checklist.firstIndex(where: { $0.id == item.id }) {
            updatedEvent.checklist[itemIndex].isCompleted.toggle()
            asEvents.updateEvent(updatedEvent, eventType: updatedEvent.eventType)
            generateFeedback(style: .medium)
        }
    }
    
    private func dayIsNearest(_ day: DayOfWeek) -> Bool {
        let calendar = Calendar.current

        guard !event.notificationDaysOfWeek.isEmpty else {
            let eventWeekday = calendar.component(.weekday, from: event.date)
            return day.calendarValue == eventWeekday
        }

        let now = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute], from: event.date)

        var nearestDay: DayOfWeek?
        var earliestDate: Date?

        for selectedDay in event.notificationDaysOfWeek {
            var components = DateComponents()
            components.weekday = selectedDay.calendarValue
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute

            if let candidateDate = calendar.nextDate(after: now,
                                                  matching: components,
                                                  matchingPolicy: .nextTimePreservingSmallerComponents),
               candidateDate >= now {
                if earliestDate == nil || candidateDate < earliestDate! {
                    earliestDate = candidateDate
                    nearestDay = selectedDay
                }
            }
        }

        return day == nearestDay
    }
    
    private func monthIsNearest(_ month: Month) -> Bool {
        let calendar = Calendar.current
        let eventMonth = calendar.component(.month, from: event.date)
        return eventMonth == month.calendarValue
    }
}






// MARK: - Вспомогательный модификатор, чтобы не дублировать стиль меток
extension View {
    func tagLabelStyle(isHighlighted: Bool = false) -> some View {
        self
            .font(.system(size: 10))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(isHighlighted ? Color.blue : Color.blue.opacity(0.4))
            .cornerRadius(4)
            .lineLimit(1)
    }
}




// для swift Data





class EventManager: ObservableObject {
    static let shared = EventManager()
    private let defaultLimit = 2
    
    @Published var subscriptionIsActive = false
    @Published var notificationsPermissionGranted = false
    @Published var microphonePermissionGranted = false
    var eventTimer: Timer?
    // Массивы теперь являются лишь отображением данных из SwiftData
    @Published private(set) var events: [Event] = []
    @Published private(set) var birthdays: [Event] = []
    
    @Published var settings: SettingsModel?
    
    init() {
        setupEventTimer()
        deletePastEventsHandler()
        removeNotificationsForDeletedEvents()
        checkNotificationPermissions()
        checkMicrophonePermissions()
    }
    
    
  

    /// Удаляет прошедшие события из памяти и, если передан контекст, из SwiftData.
    /// Без аргумента чистит только данные в памяти/UserDefaults.
    func deletePastEventsHandler(modelContext: ModelContext? = nil) {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)

        let ctx = modelContext ?? self.modelContext

        // Удаляем просроченные записи из SwiftData
        if let ctx = ctx {
            do {
                let descriptor = FetchDescriptor<EventModel>(
                    predicate: #Predicate { $0.date < oneMinuteAgo && $0.deletePastEvents }
                )
                for model in try ctx.fetch(descriptor) {
                    print("🗑️ Удалено (SwiftData): \(model.name)")
                    ctx.delete(model)
                }
                try ctx.save()
            } catch {
                print("❌ SwiftData-ошибка: \(error)")
            }
        }
        // Синхронизируем локальные массивы с базой
        syncFromDatabase()
        updateRepeatingEvents()

        // Обновляем виджеты и Apple Watch
        WidgetCenter.shared.reloadAllTimelines()
        updateWatchConnectivityContext(events: events, birthdays: birthdays)
        print("✅ Очистка завершена. Осталось событий: \(events.count)")
        Task {
            await updateLiveActivity()
        }
    }
    
    
    
    
    
    // для swift data
    // MARK: SwiftData → Runtime → Widgets
    private func syncFromDatabase() {
        guard let ctx = modelContext else { return }

        // Получаем все модели одним запросом
        let models = (try? ctx.fetch(FetchDescriptor<EventModel>())) ?? []

        // Конвертируем в Event и делим по типу
        let allEvents = models.map(Event.init)          // Event(from: EventModel)
        self.events     = allEvents.filter { $0.eventType == .event }
        self.birthdays  = allEvents.filter { $0.eventType == .birthday }

        WidgetCenter.shared.reloadAllTimelines()
        setupEventTimer()                               // перезапуск таймера
        Task {
            await updateLiveActivity()
        }
    }



    
    

    // для swift data
    // MARK: — SwiftData helpers

    /// Создаёт новую или обновляет существующую запись в SwiftData
    private func persistToSwiftData(_ event: Event) {
        guard let ctx = modelContext else { return }

        let descriptor = FetchDescriptor<EventModel>(
            predicate: #Predicate { $0.id == event.id }
        )

        do {
            if let existing = try ctx.fetch(descriptor).first {
                existing.update(from: event)          // метод см. ниже
            } else {
                ctx.insert(EventModel(from: event))
            }
            try ctx.save()
            print("💾 SwiftData saved: \(event.name)")
        } catch {
            print("❌ SwiftData error: \(error)")
        }
    }

    /// Сохраняет текущие настройки в базу данных
    private func saveSettings() {
        guard let ctx = modelContext else { return }
        do {
            try ctx.save()
            print("💾 Settings saved")
        } catch {
            print("❌ Failed to save settings: \(error)")
        }
    }

    /// Помечает, что первое открытие приложения завершено
    func completeFirstLaunch() {
        settings?.isFirstLaunch = false
        saveSettings()
    }

    
    // для swift data
    private var modelContext: ModelContext?
        /// Дайте ссылку на контекст один раз из корневого View
        func configure(modelContext: ModelContext) {
            self.modelContext = modelContext
            loadSettings()
            syncFromDatabase()          // ← сразу заполняем массивы из SwiftData
            updateWatchConnectivityContext(events: events, birthdays: birthdays)
        }

        private func loadSettings() {
            guard let ctx = modelContext else { return }
            if let existing = try? ctx.fetch(FetchDescriptor<SettingsModel>()).first {
                self.settings = existing
            } else {
                let newSettings = SettingsModel()
                ctx.insert(newSettings)
                try? ctx.save()
                self.settings = newSettings
            }
        }

    //добавил
    func scheduleNotificationsForAllEvents() {
            let center = UNUserNotificationCenter.current()
            // Перечитываем события из базы
            syncFromDatabase()
            // Собираем все события
            let allEvents = events + birthdays
            for event in allEvents {
                // Если уведомление не включено – пропускаем
                guard event.notificationEnabled else { continue }
                
                // Удаляем все уведомления для данного события
                center.removePendingNotificationRequests(withIdentifiers: [event.id.uuidString])
                center.removeDeliveredNotifications(withIdentifiers: [event.id.uuidString])
                
                let content = UNMutableNotificationContent()
                content.title = event.name
                content.body = "Напоминание о событии: \(event.name)"
                switch event.notificationType {
                case .message:
                    content.sound = .default
                case .sound:
                    content.sound = UNNotificationSound(named: UNNotificationSoundName("test1.mp3"))
                }
                
                // Используем обновлённое время уведомления или дату события, если время не задано
                let notificationDate = event.notificationTime ?? event.date
                let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: event.repeatYearly)
                
                let request = UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: trigger)
                
                center.add(request) { error in
                    if let error = error {
                        print("Ошибка при добавлении уведомления для события \(event.name): \(error.localizedDescription)")
                    } else {
                        print("Уведомление успешно запланировано для события: \(event.name)")
                    }
                }
            }
        }
    
    
    func updateWatchConnectivityContext(events: [Event], birthdays: [Event]) {

        let allEvents = (events + birthdays).map { $0.toDictionary() }
        WCSession.default.transferUserInfo(["events": allEvents])
        try? WCSession.default.updateApplicationContext(["events": allEvents])
    }


    
    
    
    private let eventLimit = 2
    func checkSubscriptionStatus(completion: @escaping () -> Void) {
        Purchases.shared.getCustomerInfo { (info, error) in
            DispatchQueue.main.async {
                if let customerInfo = info {
                    self.subscriptionIsActive = customerInfo.entitlements["Pro"]?.isActive ?? false
                }
                completion()
            }
        }
    }
    
    func handleSubscriptionChange() {
        NotificationCenter.default.post(name: NSNotification.Name("Pro"), object: nil)
    }
    
    func canAddEvent(ofType type: EventType) -> Bool {
        let currentLimit = subscriptionIsActive ? Int.max : defaultLimit
        switch type {
        case .event:
            return events.count < currentLimit
        case .birthday:
            return birthdays.count < currentLimit
        }
    }
    
    // MARK: — совместимость со старым кодом
    private func saveEvents()    {
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 reloadAllTimelines() из saveEvents")
    }
    private func saveBirthdays() {
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 reloadAllTimelines() из saveBirthdays")
    }
    
    
    func saveAndReload() {
        saveEvents()
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 reloadAllTimelines() из saveAndReload")
        WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
        print("🔄 reloadTimelines(ofKind:) из saveAndReload")

    }
    
    func getFutureDate(for eventDate: Date, event: Event) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        if event.eventType == .birthday {
            return eventDate
        } else {
            if event.repeatYearly {
                return calendar.nextDate(after: now, matching: calendar.dateComponents([.month, .day, .hour, .minute], from: eventDate), matchingPolicy: .nextTime)
            } else if event.repeatMonthly {
                return calendar.nextDate(after: now, matching: calendar.dateComponents([.day, .hour, .minute], from: eventDate), matchingPolicy: .nextTime)
            } else if !event.notificationMonths.isEmpty {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: eventDate)
                for month in event.notificationMonths {
                    if let candidateDate = calendar.nextDate(after: now, matching: DateComponents(month: month.calendarValue, day: calendar.component(.day, from: eventDate), hour: timeComponents.hour, minute: timeComponents.minute), matchingPolicy: .nextTime) {
                        return candidateDate
                    }
                }
            } else if !event.notificationDaysOfWeek.isEmpty {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: eventDate)
                for dayOfWeek in event.notificationDaysOfWeek {
                    if let candidateDate = calendar.nextDate(after: now, matching: DateComponents(hour: timeComponents.hour, minute: timeComponents.minute, weekday: dayOfWeek.calendarValue), matchingPolicy: .nextTime) {
                        return candidateDate
                    }
                }
            } else if event.repeatInterval != .none {
                var nextDate = event.date.addingTimeInterval(event.repeatInterval.timeInterval)
                while nextDate <= now {
                    nextDate = nextDate.addingTimeInterval(event.repeatInterval.timeInterval)
                }
                return nextDate
            }
        }
        
        return nil
    }
    
    
    
    func saveEvent(_ event: Event, eventType: EventType) {
        var newEvent = event
        newEvent.lastModified = Date()
        // Для обычных событий с датой в прошлом пересчитываем следующую дату
        if event.eventType == .event && event.date < Date() {
            if let updatedDate = getFutureDate(for: event.date, event: event) {
                newEvent.date = updatedDate
            }
        }

        // Сохраняем в SwiftData
        persistToSwiftData(newEvent)
        // После сохранения перечитываем данные из базы
        syncFromDatabase()

        // Планируем уведомление, если включено
        if newEvent.notificationEnabled {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [newEvent.id.uuidString])
            center.removeDeliveredNotifications(withIdentifiers: [newEvent.id.uuidString])
            scheduleNotification(for: newEvent)
        }

        // Дополнительные действия после сохранения
        deletePastEventsHandler()

        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 reloadAllTimelines() из saveEvent")
        WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
        print("🔄 reloadTimelines(ofKind:) из saveEvent")

        updateWatchConnectivityContext(events: events, birthdays: birthdays)
        Task {
            await updateLiveActivity()
        }
    }

    
    
    
    
    func updateEvent(_ updatedEvent: Event, eventType: EventType) {
        var newEvent = updatedEvent
        newEvent.lastModified = Date()

        // Если дата в прошлом — пересчитываем
        if updatedEvent.date < Date() {
            if let updatedDate = getFutureDate(for: updatedEvent.date, event: updatedEvent) {
                newEvent.date = updatedDate
                saveAndReload()
            }
        }

        // Обновляем запись в SwiftData
        persistToSwiftData(newEvent)
        if newEvent.notificationEnabled {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [newEvent.id.uuidString])
            center.removeDeliveredNotifications(withIdentifiers: [newEvent.id.uuidString])
            scheduleNotification(for: newEvent)
        } else {
            removeNotifications(for: newEvent)
        }

        // Перечитываем данные из базы
        syncFromDatabase()

        // Обновляем complication и виджеты
        WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
        print("🔄 reloadTimelines(ofKind:) из updateEvent")
        
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 reloadAllTimelines() из updateEvent")

        // Обновляем контекст для часов
        updateWatchConnectivityContext(events: events, birthdays: birthdays)
        Task {
            await updateLiveActivity()
        }
        // 🔄 обновляем локальные массивы, чтобы UI сразу получил свежие данные
        syncFromDatabase()
    }


    
    
    func deleteEvent(_ event: Event, eventType: EventType, modelContext: ModelContext) {
        // Удаление из SwiftData
        let descriptor = FetchDescriptor<EventModel>(predicate: #Predicate { $0.id == event.id })
        if let model = try? modelContext.fetch(descriptor).first {
            modelContext.delete(model)
            try? modelContext.save()
        }

        // После удаления перечитываем данные из базы
        syncFromDatabase()

        // Удаление уведомлений
        removeNotifications(for: event)

        // Сохраняем и обновляем всё остальное
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 reloadAllTimelines() из deleteEvent")

        // Синхронизация с Apple Watch
        updateWatchConnectivityContext(events: events, birthdays: birthdays)
        Task {
            await updateLiveActivity()
        }
    }


    
    
    /// Убирает все запланированные уведомления по UUID события
    func removeNotifications(for event: Event) {
        let identifiers = [
            event.id.uuidString,
            event.id.uuidString + "_event",
            event.id.uuidString + "_repeat"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🔕 Уведомления удалены: \(identifiers)")
    }

    
    func removeNotificationsForDeletedEvents() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let existingEventIDs = self.events.map { $0.id.uuidString } + self.birthdays.map { $0.id.uuidString }
            let notificationIDsToRemove = requests.map { $0.identifier }.filter { identifier in
                let eventID = identifier.components(separatedBy: "_").first ?? ""
                return !existingEventIDs.contains(eventID)
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIDsToRemove)
        }
    }
    
    func updateRepeatingEvent(_ event: Event) {
            let calendar = Calendar.current
            let now = Date()

            // Если дата ещё не наступила — ничего не делаем
            guard event.date <= now else { return }

            // Вычисляем смещение между датой события и датой уведомления
            let notificationOffset = (event.notificationTime ?? event.date).timeIntervalSince(event.date)

            // 1) Обработка дней рождения
            if event.eventType == .birthday {
                // Настраиваем компоненты: месяц, день, час, минута
                let timeComponents = calendar.dateComponents([.hour, .minute], from: event.date)
                let birthdayComponents = DateComponents(
                    month: calendar.component(.month, from: event.date),
                    day:   calendar.component(.day,   from: event.date),
                    hour:  timeComponents.hour,
                    minute: timeComponents.minute
                )
                // Ищем следующий день рождения
                var nextNotificationDate = calendar.nextDate(
                    after: now,
                    matching: birthdayComponents,
                    matchingPolicy: .nextTime
                )

                // На случай, если nextDate nil или < now, сдвигаем на год вперёд
                if nextNotificationDate == nil || nextNotificationDate! < now {
                    nextNotificationDate = calendar.date(
                        byAdding: .year,
                        value: 1,
                        to: event.date
                    )
                }

                // Обновляем модель
                if let newNotifDate = nextNotificationDate {
                    var updatedEvent = event
                    updatedEvent.notificationTime = newNotifDate
                    print("Обновлено уведомление для дня рождения: \(event.name). Новая дата уведомления: \(newNotifDate)")

                    // 2) Сохраняем обновлённое событие
                    self.updateEvent(updatedEvent, eventType: event.eventType)

                    // 3) Перепланируем локальное уведомление
                    let center = UNUserNotificationCenter.current()
                    center.removePendingNotificationRequests(withIdentifiers: [updatedEvent.id.uuidString])
                    PhoneConnectivityManager.shared.scheduleNotification(for: updatedEvent)
                }

                return
            }

            // 2) Обработка остальных повторяющихся событий
            var nextDate: Date? = nil

            if event.repeatYearly {
                let tc = calendar.dateComponents([.hour, .minute], from: event.date)
                nextDate = calendar.nextDate(
                    after: now,
                    matching: DateComponents(
                        month: calendar.component(.month, from: event.date),
                        day:   calendar.component(.day,   from: event.date),
                        hour:  tc.hour,
                        minute: tc.minute
                    ),
                    matchingPolicy: .nextTime
                )
            }
            else if event.repeatMonthly {
                let tc = calendar.dateComponents([.hour, .minute], from: event.date)
                nextDate = calendar.nextDate(
                    after: now,
                    matching: DateComponents(
                        day:    calendar.component(.day,    from: event.date),
                        hour:   tc.hour,
                        minute: tc.minute
                    ),
                    matchingPolicy: .nextTime
                )
            }
            else if !event.notificationMonths.isEmpty {
                let day = calendar.component(.day, from: event.date)
                let tc  = calendar.dateComponents([.hour, .minute], from: event.date)
                for month in event.notificationMonths {
                    let m = Month(rawValue: month.rawValue)?.calendarValue ?? 0
                    if let candidate = calendar.nextDate(
                        after: now,
                        matching: DateComponents(month: m, day: day, hour: tc.hour, minute: tc.minute),
                        matchingPolicy: .nextTime
                    ) {
                        if nextDate == nil || candidate < nextDate! {
                            nextDate = candidate
                        }
                    }
                }
            }
            else if !event.notificationDaysOfWeek.isEmpty {
                let tc = calendar.dateComponents([.hour, .minute], from: event.date)
                var earliest: Date? = nil
                for dow in event.notificationDaysOfWeek {
                    var comps = DateComponents()
                    comps.weekday = dow.calendarValue
                    comps.hour    = tc.hour
                    comps.minute  = tc.minute
                    if let cand = calendar.nextDate(
                        after: now,
                        matching: comps,
                        matchingPolicy: .nextTimePreservingSmallerComponents
                    ), cand >= now {
                        if earliest == nil || cand < earliest! {
                            earliest = cand
                        }
                    }
                }
                nextDate = earliest
            }
            else if event.repeatInterval != .none {
                var cand = event.date.addingTimeInterval(event.repeatInterval.timeInterval)
                while cand <= now {
                    cand = cand.addingTimeInterval(event.repeatInterval.timeInterval)
                }
                nextDate = cand
            }

            // 3) Если найдена новая дата — обновляем модель и перепланируем уведомление
            if let newDate = nextDate {
                var updatedEvent = event
                updatedEvent.date = newDate
                if event.notificationEnabled {
                    updatedEvent.notificationTime = newDate.addingTimeInterval(notificationOffset)
                }
                print("Обновлено повторяющееся событие: \(event.name). Новая дата: \(newDate)")

                // Сохраняем
                self.updateEvent(updatedEvent, eventType: event.eventType)

                // Перепланируем уведомление
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: [updatedEvent.id.uuidString])
                PhoneConnectivityManager.shared.scheduleNotification(for: updatedEvent)
            }
        }
    
    
    func updateRepeatingEvents() {
        let allEvents = events + birthdays
        for event in allEvents {
            updateRepeatingEvent(event)
        }
    }
    
    func pinEvent(_ event: Event, eventType: EventType) {
        var updated = event
        updated.isPinned = true
        updateEvent(updated, eventType: eventType)
    }

    func unpinEvent(_ event: Event, eventType: EventType) {
        var updated = event
        updated.isPinned = false
        updateEvent(updated, eventType: eventType)
    }
    
    func moveEvent(_ event: Event, to newIndex: Int, eventType: EventType) {
        switch eventType {
        case .event:
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                let removedEvent = events.remove(at: index)
                events.insert(removedEvent, at: newIndex)
            }
        case .birthday:
            if let index = birthdays.firstIndex(where: { $0.id == event.id }) {
                let removedBirthday = birthdays.remove(at: index)
                birthdays.insert(removedBirthday, at: newIndex)
            }
        }
    }
    
    func addEvent(name: String, date: Date, showCountdown: Bool, eventType: EventType, emoji: String, note: String?, notificationType: NotificationType, notificationEnabled: Bool, notificationTime: Date?, deletePastEvents: Bool, notificationDaysOfWeek: [DayOfWeek], notificationMonths: [Month], repeatInterval: RepeatInterval, repeatMonthly: Bool, repeatYearly: Bool, bellActivated: Bool) {
        guard canAddEvent(ofType: eventType) else {
            print("Превышен лимит событий для типа \(eventType.rawValue).")
            return
        }
        let newEvent = Event(name: name, date: date, creationDate: Date(), showCountdown: showCountdown, eventType: eventType, emoji: emoji, note: note, notificationType: notificationType, notificationEnabled: notificationEnabled, notificationTime: notificationTime, deletePastEvents: deletePastEvents, notificationDaysOfWeek: notificationDaysOfWeek, notificationMonths: notificationMonths, repeatInterval: repeatInterval, repeatMonthly: repeatMonthly, repeatYearly: eventType == .birthday ? true : repeatYearly, bellActivated: bellActivated)
        saveEvent(newEvent, eventType: eventType)
        setupNextEventTimer()
    }
    
    func setupNextEventTimer() {
        eventTimer?.invalidate()
        deletePastEventsHandler()
        let now = Date()
        let sortedEvents = (events + birthdays).filter { $0.date > now }.sorted { $0.date < $1.date }
        guard let nextEvent = sortedEvents.first else {
            return
        }
        let timeInterval = nextEvent.date.timeIntervalSinceNow + 60
        guard timeInterval > 0 else { return }
        DispatchQueue.main.async { [weak self] in
            self?.eventTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
                self?.handleEventTrigger(event: nextEvent)
                self?.setupNextEventTimer()
            }
        }
    }
    
    func setupDeletePastEventsTimer() {
        eventTimer?.invalidate()
        eventTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.deletePastEventsHandler()
        }
    }
    
    func movePastEventsToEnd() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let now = Date()
            let pastEvents = self.events.filter { $0.date < now }
            let futureEvents = self.events.filter { $0.date >= now }
            self.events = futureEvents + pastEvents
            let pastBirthdays = self.birthdays.filter { $0.date < now }
            let futureBirthdays = self.birthdays.filter { $0.date >= now }
            self.birthdays = futureBirthdays + pastBirthdays
            self.eventTimer?.invalidate()
            self.eventTimer = nil
            self.setupNextEventTimer()
            self.saveEvents()
            self.saveBirthdays()
        }
    }
    
    // Внутри класса EventManager:
    // Внутри вашего второго класса (EventManager):

    // MARK: — основной метод
    // Внутри EventManager

    func scheduleNotification(for event: Event) {
        guard event.notificationEnabled, event.notificationTime != nil else { return }
        let center = UNUserNotificationCenter.current()

        // 1. Идентификатор
        let identifier = event.id.uuidString

        // 2. Контент
        let content = UNMutableNotificationContent()
        content.title = event.name
        content.body = "Не забудьте о событии \(event.name)"
        switch event.notificationType {
        case .message:
            content.sound = .default
        case .sound:
            content.sound = UNNotificationSound(named: UNNotificationSoundName("test1.mp3"))
        }
        content.categoryIdentifier = "EVENT_REMINDER"

        // 3. Для дней рождения с repeatYearly — особая логика
        if event.eventType == .birthday && event.repeatYearly {
            let notifDate = event.notificationTime ?? event.date
            scheduleBirthdayNotification(
                on: notifDate,
                identifier: identifier,
                content: content
            )
            return
        }

        // 4. Обычные события
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let now = Date()
        var notificationDate = event.notificationTime ?? event.date

        if notificationDate < now {
            if event.repeatYearly {
                notificationDate = Calendar.current.date(
                    byAdding: .year,
                    value: 1,
                    to: notificationDate
                ) ?? notificationDate
            } else {
                return
            }
        }

        let components: Set<Calendar.Component> = event.repeatYearly
            ? [.month, .day, .hour, .minute]
            : [.year, .month, .day, .hour, .minute]

        let triggerDate = Calendar.current.dateComponents(components, from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerDate,
            repeats: event.repeatYearly || event.repeatInterval != .none
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error = error {
                print("❌ Ошибка при добавлении уведомления: \(error.localizedDescription)")
            } else {
                print("✅ Уведомление добавлено: \(event.name) — \(notificationDate)")
            }
        }
    }

    /// Теперь обновлённая логика для дней рождения:
    /// — Если дата (год) > текущего, ставим только одноразовое (на этот год).
    /// — Иначе (т.е. событие в этом или прошлом году) — единый repeats=true, который сам раз в год.
    private func scheduleBirthdayNotification(
        on date: Date,
        identifier: String,
        content: UNNotificationContent
    ) {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()

        // 1) Удаляем все старые запросы по этому идентификатору
        print("🗑 Удаляем старые ДР-уведомления с идентификатором: \(identifier)")
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // 2) Разбиваем дату на компоненты
        let compsWithYear = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let compsWithoutYear = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
        guard let eventYear = compsWithYear.year else { return }
        let currentYear = calendar.component(.year, from: now)

        if eventYear > currentYear {
            // ————— Запланировано далеко вперёд (например, 2026) —————
            let trigger = UNCalendarNotificationTrigger(dateMatching: compsWithYear, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request) { error in
                if let error = error {
                    print("❌ Ошибка one-time ДР-уведомления [\(identifier)]: \(error.localizedDescription)")
                } else {
                    print("🎂 Одноразовый ДР-уведомление запланировано [\(identifier)] на: \(date)")
                }
            }

        } else {
            // ————— Первый запуск в этом или следующем году —————
            // Вычисляем ближайшую будущую дату ДР
            var nextComponents = compsWithoutYear
            nextComponents.year = currentYear
            var nextBirthday = calendar.date(from: nextComponents)!
            if nextBirthday < now {
                nextComponents.year = currentYear + 1
                nextBirthday = calendar.date(from: nextComponents)!
            }

            // Единый repeating-триггер (каждый год)
            let triggerDate = calendar.dateComponents([.month, .day, .hour, .minute], from: nextBirthday)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request) { error in
                if let error = error {
                    print("❌ Ошибка repeating ДР-уведомления [\(identifier)]: \(error.localizedDescription)")
                } else {
                    print("🎂 Repeating ДР-уведомление запланировано [\(identifier)] начиная с: \(nextBirthday)")
                }
            }
        }
    }


    
    
    func setupEventTimer() {
        eventTimer?.invalidate()
        
        let now = Date()
        if let nextEvent = getNextEvent() {
            let timeInterval = nextEvent.date.timeIntervalSince(now)
            if timeInterval > 0 {
                eventTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    
                    // Обрабатываем событие
                    self.handleEventTrigger(event: nextEvent)
                    
                    // Устанавливаем таймер на удаление событий через 61 секунду
                    Timer.scheduledTimer(withTimeInterval: 61, repeats: false) { _ in
                        self.deletePastEventsHandler()
                    }
                    
                    // Перенастраиваем таймер для следующего события
                    self.setupEventTimer()
                }
            }
        }
    }
    
    
    
  
    
    func handleEventTrigger(event: Event) {
        updateRepeatingEvents()
    }
    
    func getNextEvent() -> Event? {
        let now = Date()
        let futureEvents = events.filter { $0.date > now }
        let futureBirthdays = birthdays.filter { $0.date > now }
        let allFutureEvents = futureEvents + futureBirthdays
        return allFutureEvents.sorted { $0.date < $1.date }.first
    }

    @MainActor
    func updateLiveActivity() {
        let now = Date()

        let normalPairs = events.map { ($0, $0.date) }
        let birthdayPairs = birthdays.map { b -> (Event, Date) in
            let calendar = Calendar.current
            let birthdayStartOfDay = calendar.startOfDay(for: b.date.nextBirthdayPreservingTime())
            let eventDate = birthdayStartOfDay < now ? now : birthdayStartOfDay
            return (b, eventDate)
        }

        let eventPairs = normalPairs + birthdayPairs
        let upcoming = eventPairs.filter { $0.1 >= now }

        guard let (nearest, activityDate) = upcoming.min(by: { $0.1 < $1.1 }) else {
            LiveActivityManager.shared.endActivity()
            return
        }

        LiveActivityManager.shared.startActivity(
            title: nearest.name,
            eventDate: activityDate,
            creationDate: nearest.creationDate,
            emoji: nearest.emoji,
            originalDate: nearest.date,
            bellActivated: nearest.bellActivated,
            isBirthday: nearest.eventType == .birthday
        )
    }
    
    // Добавленные методы для уведомлений
    func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsPermissionGranted = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    func updateNotificationsPermission(granted: Bool) {
        notificationsPermissionGranted = granted
    }

    func checkMicrophonePermissions() {
        let status = AVAudioSession.sharedInstance().recordPermission
        DispatchQueue.main.async {
            self.microphonePermissionGranted = (status == .granted)
        }
    }

    func updateMicrophonePermission(granted: Bool) {
        microphonePermissionGranted = granted
    }
}










//🔁 EventModel из Event:




extension EventModel {

    /// Создаём новую SwiftData-модель из обычного `Event`
    convenience init(from event: Event) {
            self.init(
                id: event.id,
                name: event.name,
                date: event.date,
                creationDate: event.creationDate,
                showCountdown: event.showCountdown,
                eventType: event.eventType,
                isPinned: event.isPinned,
                originalIndex: event.originalIndex,
                emoji: event.emoji,
                note: event.note,
                checklist: [],
                notificationType: event.notificationType,
                notificationEnabled: event.notificationEnabled,
                notificationTime: event.notificationTime,
                deletePastEvents: event.deletePastEvents,
                lastModified: event.lastModified,
                notificationDaysOfWeek: event.notificationDaysOfWeek,
                notificationMonths: event.notificationMonths,
                repeatInterval: event.repeatInterval,
                repeatMonthly: event.repeatMonthly,
                repeatYearly: event.repeatYearly,
                bellActivated: event.bellActivated,
                isFromWatch: event.isFromWatch,
                isNewlyCreated: event.isNewlyCreated
            )
            self.checklist = event.checklist.enumerated().map { index, item in
                ChecklistItemModel(from: item, event: self, order: index)
            }
        }

    /// Обновляем существующую `EventModel` свежими данными
    func update(from event: Event) {
        name                = event.name
        date                = event.date
        creationDate        = event.creationDate
        showCountdown       = event.showCountdown
        eventType           = event.eventType
        isPinned            = event.isPinned
        originalIndex       = event.originalIndex
        emoji               = event.emoji
        note                = event.note
        notificationType    = event.notificationType
        notificationEnabled = event.notificationEnabled
        notificationTime    = event.notificationTime
        deletePastEvents    = event.deletePastEvents
        lastModified        = event.lastModified
        notificationDaysOfWeek = event.notificationDaysOfWeek
        notificationMonths     = event.notificationMonths
        repeatInterval      = event.repeatInterval
        repeatMonthly       = event.repeatMonthly
        repeatYearly        = event.repeatYearly
        bellActivated       = event.bellActivated
        isFromWatch         = event.isFromWatch
        isNewlyCreated      = event.isNewlyCreated

        // Обновляем чек-лист без создания дубликатов
        var existingItems = Dictionary(uniqueKeysWithValues: checklist.map { ($0.id, $0) })
        var updatedModels: [ChecklistItemModel] = []

        for (index, item) in event.checklist.enumerated() {
            if let model = existingItems[item.id] {
                model.text        = item.text
                model.isCompleted = item.isCompleted
                model.isEditing   = item.isEditing
                model.order       = index
                updatedModels.append(model)
                existingItems.removeValue(forKey: item.id)
            } else {
                updatedModels.append(ChecklistItemModel(from: item, event: self, order: index))
            }
        }

        checklist = updatedModels
    }
}



//🔁 Event из EventModel:


extension Event {
    init(from model: EventModel) {
        self.id = model.id
        self.name = model.name
        self.date = model.date
        self.creationDate = model.creationDate
        self.showCountdown = model.showCountdown
        self.eventType = model.eventType
        self.isPinned = model.isPinned
        self.originalIndex = model.originalIndex
        self.emoji = model.emoji
        self.note = model.note
        self.checklist = model.checklist
            .sorted { $0.order < $1.order }
            .map { ChecklistItem(from: $0) }
        self.notificationType = model.notificationType
        self.notificationEnabled = model.notificationEnabled
        self.notificationTime = model.notificationTime
        self.deletePastEvents = model.deletePastEvents
        self.notificationDaysOfWeek = model.notificationDaysOfWeek
        self.notificationMonths = model.notificationMonths
        self.repeatInterval = model.repeatInterval
        self.repeatMonthly = model.repeatMonthly
        self.repeatYearly = model.repeatYearly
        self.bellActivated = model.bellActivated
        self.isFromWatch = model.isFromWatch
        self.isNewlyCreated = model.isNewlyCreated
        self.lastModified = model.lastModified
    }
}

func persistToSwiftData(_ event: Event, context: ModelContext) {
    let model = EventModel(from: event)
    context.insert(model)
    do {
        try context.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
    } catch {
        print("❌ Ошибка сохранения в SwiftData: \(error)")
    }
}



func migrateLegacyToSwiftDataIfNeeded(context: ModelContext) {
    guard let settings = EventManager.shared.settings, !settings.migrationCompleted else { return }

    for event in EventManager.shared.events {
        persistToSwiftData(event, context: context)
    }

    for birthday in EventManager.shared.birthdays {
        persistToSwiftData(birthday, context: context)
    }

    settings.migrationCompleted = true
    if (try? context.save()) != nil {
        WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
    }
}








extension ChecklistItem {
    init(from model: ChecklistItemModel) {
        self.id = model.id
        self.text = model.text
        self.isCompleted = model.isCompleted
        self.isEditing = model.isEditing
    }
}




// Модель элемента контрольного списка
struct ChecklistItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var isCompleted: Bool = false
    var isEditing: Bool = false
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
            "lastModified": lastModified.timeIntervalSince1970
        ]
        if notificationEnabled, let notificationTime {
            dict["notificationTime"] = notificationTime.timeIntervalSince1970
        }
        dict["deletePastEvents"] = deletePastEvents
        dict["isNewlyCreated"] = isNewlyCreated
        dict["isFromWatch"] = isFromWatch
        return dict
    }
}


extension Event {
    var isToday: Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(self.date)
    }
}

// Обновлённая структура Event с уведомлениями включёнными по умолчанию
struct Event: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var date: Date
    var creationDate: Date = Date()
    var showCountdown: Bool = true
    var eventType: EventType
    var isPinned: Bool = false
    var originalIndex: Int?
    var emoji: String
    var note: String?
    var checklist: [ChecklistItem] = []
    
    var notificationType: NotificationType = .message
    var notificationEnabled: Bool = true // для событий, созданных на часах – уведомление включено по умолчанию
    var notificationTime: Date? = nil
    var deletePastEvents: Bool = false
    var lastModified: Date = Date()
    var notificationDaysOfWeek: [DayOfWeek] = []
    var notificationMonths: [Month] = []
    var repeatInterval: RepeatInterval = .none
    var repeatMonthly: Bool = false
    var repeatYearly: Bool
    var bellActivated: Bool = false
    
    
    // 🛠️ ДОБАВЬ ЭТИ ДВА ПОЛЯ НИЖЕ:
    var isFromWatch: Bool = false
    var isNewlyCreated: Bool = false
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static let emojis = ["", "🎉", "🎈", "🎁", "🍰", "🎂", "🥳", "🎊", "🎇", "🍾"]
    
    var age: Int? {
        if case .birthday = eventType {
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.year], from: date, to: now)
            return components.year
        }
        return nil
    }
}



// для swift data





extension ChecklistItemModel {

    /// Старый вариант — без ссылки на событие (оставляем, вдруг нужен)
    convenience init(from item: ChecklistItem, order: Int) {
        self.init(
            id:          item.id,
            text:        item.text,
            isCompleted: item.isCompleted,
            isEditing:   item.isEditing,
            order:       order,
            event:       nil
        )
    }

    /// Новый вариант — сразу устанавливает связь с `EventModel`
    convenience init(from item: ChecklistItem, event: EventModel, order: Int) {
        self.init(
            id:          item.id,
            text:        item.text,
            isCompleted: item.isCompleted,
            isEditing:   item.isEditing,
            order:       order,
            event:       event          // ← обратная связь
        )
    }
}


@Model
class ChecklistItemModel {
    @Attribute(.unique) var id: UUID
    var text: String
    var isCompleted: Bool
    var isEditing: Bool
    var order: Int

    // Обратная связь с EventModel (для каскадного удаления)
    @Relationship var event: EventModel?

    init(id: UUID = UUID(), text: String, isCompleted: Bool = false, isEditing: Bool = false, order: Int = 0, event: EventModel? = nil) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.isEditing = isEditing
        self.order = order
        self.event = event
    }
}















// MARK: - конец работы с поделями

extension DayOfWeek {
    var calendarValue: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}

extension Month {
    var calendarValue: Int {
        switch self {
        case .january: return 1
        case .february: return 2
        case .march: return 3
        case .april: return 4
        case .may: return 5
        case .june: return 6
        case .july: return 7
        case .august: return 8
        case .september: return 9
        case .october: return 10
        case .november: return 11
        case .december: return 12
        }
    }
}

enum DayOfWeek: String, Codable, CaseIterable {
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday
    
    
    
    
    var displayName: String {
        switch self {
        case .monday:
            return NSLocalizedString("dayOfWeek.monday", comment: "")
        case .tuesday:
            return NSLocalizedString("dayOfWeek.tuesday", comment: "")
        case .wednesday:
            return NSLocalizedString("dayOfWeek.wednesday", comment: "")
        case .thursday:
            return NSLocalizedString("dayOfWeek.thursday", comment: "")
        case .friday:
            return NSLocalizedString("dayOfWeek.friday", comment: "")
            
        case .saturday:
            return NSLocalizedString("dayOfWeek.saturday", comment: "")
        case .sunday:
            return NSLocalizedString("dayOfWeek.sunday", comment: "")
        }
    }
}

// Пример локализации месяцев
enum Month: String, Codable, CaseIterable {
    case january
    case february
    case march
    case april
    case may
    case june
    case july
    case august
    case september
    case october
    case november
    case december
    
    var displayName: String {
        switch self {
        case .january:   return NSLocalizedString("month.january", comment: "")
        case .february:  return NSLocalizedString("month.february", comment: "")
        case .march:     return NSLocalizedString("month.march", comment: "")
        case .april:     return NSLocalizedString("month.april", comment: "")
        case .may:       return NSLocalizedString("month.may", comment: "")
        case .june:      return NSLocalizedString("month.june", comment: "")
        case .july:      return NSLocalizedString("month.july", comment: "")
        case .august:    return NSLocalizedString("month.august", comment: "")
        case .september: return NSLocalizedString("month.september", comment: "")
        case .october:   return NSLocalizedString("month.october", comment: "")
        case .november:  return NSLocalizedString("month.november", comment: "")
        case .december:  return NSLocalizedString("month.december", comment: "")
        }
    }
}





// Пример локализации интервалов повтора
enum RepeatInterval: String, Codable, CaseIterable {
    case none
    case minute1
    case minute5
    case minute10
    case minute15
    case minute30
    case minute35
    case minute40
    case hour
    
    var timeInterval: TimeInterval {
        switch self {
        case .none:
            return 0
        case .minute1:
            return 60
        case .minute5:
            return 5 * 60
        case .minute10:
            return 10 * 60
        case .minute15:
            return 15 * 60
        case .minute30:
            return 30 * 60
        case .minute35:
            return 35 * 60
        case .minute40:
            return 40 * 60
        case .hour:
            return 60 * 60
        }
    }
    
    
    
    
    // Если нужно показывать локализованную подпись вместо «rawValue»
    var displayName: String {
        switch self {
        case .none:
            return NSLocalizedString("repeatInterval.none", comment: "")
        case .minute1:
            return NSLocalizedString("repeatInterval.minute1", comment: "")
        case .minute5:
            return NSLocalizedString("repeatInterval.minute5", comment: "")
        case .minute10:
            return NSLocalizedString("repeatInterval.minute10", comment: "")
        case .minute15:
            return NSLocalizedString("repeatInterval.minute15", comment: "")
        case .minute30:
            return NSLocalizedString("repeatInterval.minute30", comment: "")
        case .minute35:
            return NSLocalizedString("repeatInterval.minute35", comment: "")
        case .minute40:
            return NSLocalizedString("repeatInterval.minute40", comment: "")
        case .hour:
            return NSLocalizedString("repeatInterval.hour", comment: "")
        }
    }
}



// страницца редактирования






// Пример экрана редактирования события


struct EditEventView: View {
    @EnvironmentObject var asBirthdays: EventManager
    @Environment(\.presentationMode) var presentationMode
    
    // Основные свойства события
    var eventIndex: Int
    var eventType: EventType
    
    @State private var name: String
    @State private var eventDate: Date
    @State private var selectedEmoji: String
    @State private var note: String
    @State private var checklist: [ChecklistItem]
    
    // Уведомления
    @State private var notificationEnabled: Bool
    @State private var notificationTime: Date?
    @State private var selectedNotificationType: NotificationType
    
    // Повтор
    @State private var deletePastEvents: Bool
    @State private var selectedDaysOfWeek: Set<DayOfWeek>
    @State private var selectedMonths: Set<Month>
    @State private var selectedRepeatInterval: RepeatInterval
    @State private var repeatMonthly: Bool
    @State private var repeatYearly: Bool
    @State private var isRepeatSectionExpanded: Bool
    @State private var isDateSectionExpanded: Bool
    
    // Вспомогательные
    @State private var includeTimeForEvent: Bool
    @State private var includeTimeForNotification: Bool
    @State private var selectedEmojiCategory: EmojiCategory?
    @State private var newItemText: String = ""
    @State private var isEmojiSectionExpanded: Bool
    @State private var isEditingChecklist = false // Новое состояние для редактирования чек-листа
    
    @Environment(\.modelContext) private var modelContext //для swift data

    
    init(event: Event, eventType: EventType, eventIndex: Int) {
        self.eventType = eventType
        self.eventIndex = eventIndex

        _name = State(initialValue: event.name)
        _eventDate = State(initialValue: event.date)
        _selectedEmoji = State(initialValue: event.emoji)
        _note = State(initialValue: event.note ?? "")
        _checklist = State(initialValue: event.checklist)

        _notificationEnabled = State(initialValue: event.notificationEnabled)
        _notificationTime = State(initialValue: event.notificationTime)
        _selectedNotificationType = State(initialValue: event.notificationType)

        _deletePastEvents = State(initialValue: event.deletePastEvents)
        _selectedDaysOfWeek = State(initialValue: Set(event.notificationDaysOfWeek))
        _selectedMonths = State(initialValue: Set(event.notificationMonths))
        _selectedRepeatInterval = State(initialValue: event.repeatInterval)
        _repeatMonthly = State(initialValue: event.repeatMonthly)
        _repeatYearly = State(initialValue: event.repeatYearly)

        let hasAnyRepeat = event.repeatInterval != .none
                         || event.repeatMonthly
                         || event.repeatYearly
                         || !event.notificationDaysOfWeek.isEmpty
                         || !event.notificationMonths.isEmpty
        _isRepeatSectionExpanded = State(initialValue: hasAnyRepeat)
        _isDateSectionExpanded = State(initialValue: false)

        let hasEmoji = !event.emoji.isEmpty
        _isEmojiSectionExpanded = State(initialValue: hasEmoji)

        _includeTimeForEvent = State(initialValue: eventType != .birthday)
        _includeTimeForNotification = State(initialValue: true)

        _selectedEmojiCategory = State(
            initialValue: emojiCategories.first(where: { $0.emojis.contains(event.emoji) })
                           ?? emojiCategories.first
        )
    }
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: Заголовок и базовые поля
                Section(header: Text(eventType == .birthday ? LocalizedStringKey("editEvent.sectionHeader.birthday") : LocalizedStringKey("editEvent.sectionHeader.event"))) {
                    TextField(LocalizedStringKey("editEvent.namePlaceholder"), text: $name)
                    ZStack(alignment: .topLeading) {
                        if note.isEmpty {
                            Text(LocalizedStringKey("editEvent.placeholder.notes"))
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.vertical, 12)
                        }
                        TextEditor(text: $note)
                            .frame(height: 100)
                    }
                }
                
                // MARK: Чек-лист с возможностью перемещения
                Section(header: HStack {
                    Text(LocalizedStringKey("editEvent.checklist.header"))
                    Spacer()
                    Button {
                        withAnimation {
                            isEditingChecklist.toggle()
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.blue)
                    }
                }) {
                    ForEach($checklist) { $item in
                        HStack {
                            Button { item.isCompleted.toggle() } label: {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isCompleted ? .green : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            TextField(LocalizedStringKey("editEvent.checklist.taskPlaceholder"), text: $item.text)
                                .disabled(item.isCompleted)
                                .foregroundColor(item.isCompleted ? .gray : .primary)
                                .strikethrough(item.isCompleted, color: .gray)
                            Spacer()
                            Button {
                                if let idx = checklist.firstIndex(where: { $0.id == item.id }) {
                                    checklist.remove(at: idx)
                                }
                            } label: {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                        }
                    }
                    .onMove(perform: moveChecklistItem)
                    .onDelete { checklist.remove(atOffsets: $0) }
                    
                    HStack {
                        TextField(LocalizedStringKey("editEvent.checklist.newItemPlaceholder"), text: $newItemText)
                        Button { addItemToList() } label: {
                            Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                        }
                    }
                }
                .environment(\.editMode, isEditingChecklist ? .constant(.active) : .constant(.inactive))
                
                // MARK: Дата и уведомления
                Section(header:
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("date_section_header"))
                        if !isDateSectionExpanded {
                            Text(dateSummary)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        Image(systemName: isDateSectionExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation { isDateSectionExpanded.toggle() } }
                ) {
                    if isDateSectionExpanded {
                        HStack {
                            Image(systemName: "calendar").font(.title2).foregroundColor(.blue)
                            DatePicker("", selection: $eventDate, displayedComponents: eventType == .birthday ? [.date] : (includeTimeForEvent ? [.date, .hourAndMinute] : [.date]))
                                .labelsHidden()
                                .datePickerStyle(CompactDatePickerStyle())
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            if includeTimeForEvent && eventType != .birthday {
                                Button { includeTimeForEvent = false; eventDate = Calendar.current.startOfDay(for: eventDate) } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                }
                            } else if eventType != .birthday {
                                Button { includeTimeForEvent = true } label: {
                                    Image(systemName: "plus.circle.fill").foregroundColor(.green)
                                }
                            }
                        }
                        HStack {
                            Image(systemName: "bell").font(.title2).foregroundColor(.blue)
                            Toggle(LocalizedStringKey("editEvent.notification.toggle"), isOn: $notificationEnabled)
                                .onChange(of: notificationEnabled) { if $0 && eventType == .birthday { setNotificationTimeForBirthday() } }
                        }
                        if notificationEnabled {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { notificationTime ?? eventDate },
                                    set: { notificationTime = $0 }
                                ),
                                displayedComponents: includeTimeForNotification ? [.date, .hourAndMinute] : [.date]
                            )
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Picker(LocalizedStringKey("editEvent.notification.typePickerTitle"), selection: $selectedNotificationType) {
                                Text(LocalizedStringKey("editEvent.notification.type.message")).tag(NotificationType.message)
                                Text(LocalizedStringKey("editEvent.notification.type.sound")).tag(NotificationType.sound)
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }
                
                // MARK: Эмоджи
                Section(header:
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("editEvent.emoji.sectionHeader"))
                        Image(systemName: isEmojiSectionExpanded
                              ? "chevron.down" : "chevron.right")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation { isEmojiSectionExpanded.toggle() }
                    }
                ) {
                    if isEmojiSectionExpanded {
                        HStack {
                            Image(systemName: "face.smiling")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .padding(.trailing, 8)
                            Picker(LocalizedStringKey("editEvent.emoji.categoryPicker"),
                                   selection: $selectedEmojiCategory) {
                                ForEach(emojiCategories, id: \.self) {
                                    Text($0.name).tag($0 as EmojiCategory?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .onChange(of: selectedEmojiCategory) { category in
                                if category?.name == NSLocalizedString("CATEGORY_NAME_NONE", comment: "") {
                                    selectedEmoji = ""
                                }
                            }
                        }
                        if let category = selectedEmojiCategory {
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(category.emojis, id: \.self) { emoji in
                                        Text(emoji)
                                            .font(.largeTitle)
                                            .padding(4)
                                            .background(selectedEmoji == emoji
                                                        ? Color.blue.opacity(0.3)
                                                        : Color.clear)
                                            .cornerRadius(8)
                                            .onTapGesture { selectedEmoji = emoji }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
                .padding(.bottom, -8)
                
                // MARK: Повтор
                if eventType == .event {
                    Section(header: HStack(spacing: 4) {
                        Text(LocalizedStringKey("repeat_section_header"))
                        Image(systemName: isRepeatSectionExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation { isRepeatSectionExpanded.toggle() } }) {
                        if isRepeatSectionExpanded {
                            NavigationLink(destination: RepeatSettingsView(
                                selectedDaysOfWeek: $selectedDaysOfWeek,
                                selectedMonths: $selectedMonths,
                                selectedRepeatInterval: $selectedRepeatInterval,
                                repeatMonthly: $repeatMonthly,
                                repeatYearly: $repeatYearly,
                                deletePastEvents: $deletePastEvents,
                                onDismiss: saveChanges
                            )) {
                                HStack {
                                    Image(systemName: "arrow.2.circlepath").foregroundColor(.blue)
                                        .font(.system(size: 24))
                                    Spacer()
                                    Text(repeatSettingsDescription())
                                        .font(.system(size: 14)).foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
                    .onChange(of: selectedRepeatInterval) { _ in checkRepeatStatus() }
                    .onChange(of: repeatMonthly) { _ in checkRepeatStatus() }
                    .onChange(of: repeatYearly) { _ in checkRepeatStatus() }
                    .onChange(of: selectedDaysOfWeek) { _ in checkRepeatStatus() }
                    .onChange(of: selectedMonths) { _ in checkRepeatStatus() }
                }
                
                // MARK: Удалить прошедшие
                Section {
                    HStack {
                        Spacer()
                        Text(LocalizedStringKey("editEvent.deletePastEvents.label"))
                            .foregroundColor(.gray).font(.callout)
                        Button { deletePastEvents.toggle() } label: {
                            Image(systemName: deletePastEvents ? "checkmark.circle.fill" : "circle")
                                .resizable().frame(width:16, height:16)
                                .foregroundColor(deletePastEvents ? .blue : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                // MARK: Сохранить
                Button {
                    saveChanges()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text(LocalizedStringKey("common.saveButton")).font(.headline)
                        .foregroundColor(.white).frame(maxWidth: .infinity)
                        .padding().background(Color.blue).cornerRadius(10)
                }
                .padding(.horizontal).listRowBackground(Color.clear)
            }
            .padding(.top, -30)
            .navigationBarItems(leading: Button(action: { saveChanges(); presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark").foregroundColor(.blue)
            })
            .onChange(of: selectedEmoji) { newEmoji in
                LiveActivityManager.shared.updateEmoji(newEmoji)
            }
        }        
    }

    // MARK: - Вспомогательные функции

    private var dateSummary: String {
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateStyle = .medium
        fmt.timeStyle = includeTimeForEvent ? .short : .none
        return fmt.string(from: eventDate)
    }
    
    private func moveChecklistItem(from source: IndexSet, to destination: Int) {
        checklist.move(fromOffsets: source, toOffset: destination)
    }
    
    private func repeatSettingsDescription() -> String {
        var descriptions: [String] = []
        if repeatYearly { descriptions.append(NSLocalizedString("yearly_repeat", comment: "")) }
        if repeatMonthly { descriptions.append(NSLocalizedString("monthly_repeat", comment: "")) }
        if selectedRepeatInterval != .none {
            let key = "repeatInterval.\(selectedRepeatInterval.rawValue)"
            descriptions.append(NSLocalizedString(key, comment: ""))
        }
        if !selectedDaysOfWeek.isEmpty {
            let days = selectedDaysOfWeek.map { $0.displayName }.joined(separator: ", ")
            let format = NSLocalizedString("weekdays_format", comment: "")
            descriptions.append(String(format: format, days))
        }
        if !selectedMonths.isEmpty {
            let months = selectedMonths.map { $0.displayName }.joined(separator: ", ")
            let format = NSLocalizedString("months_format", comment: "")
            descriptions.append(String(format: format, months))
        }
        return descriptions.isEmpty
            ? NSLocalizedString("no_repeat", comment: "")
            : descriptions.joined(separator: ", ")
    }
    
    private func checkRepeatStatus() {
        if selectedRepeatInterval != .none || repeatMonthly || repeatYearly || !selectedDaysOfWeek.isEmpty || !selectedMonths.isEmpty {
            deletePastEvents = false
        }
    }
    
    private func setNotificationTimeForBirthday() {
        let calendar = Calendar.current
        let now = Date()
        var comp = calendar.dateComponents([.year, .month, .day], from: eventDate)
        comp.year = calendar.component(.year, from: now)
        if let dateThisYear = calendar.date(from: comp), dateThisYear < now {
            comp.year! += 1
        }
        notificationTime = calendar.date(from: comp) ?? notificationTime
        includeTimeForNotification = true
    }
    
    private func addItemToList() {
        let text = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        checklist.append(ChecklistItem(text: text))
        newItemText = ""
    }
    
    private func saveChanges() {
        var updatedEvent = Event(
            id: eventType == .event
                ? asBirthdays.events[eventIndex].id
                : asBirthdays.birthdays[eventIndex].id,
            name: name,
            date: eventDate,
            showCountdown: false,
            eventType: eventType,
            isPinned: eventType == .event
                ? asBirthdays.events[eventIndex].isPinned
                : asBirthdays.birthdays[eventIndex].isPinned,
            originalIndex: eventType == .event
                ? asBirthdays.events[eventIndex].originalIndex
                : asBirthdays.birthdays[eventIndex].originalIndex,
            emoji: selectedEmoji,
            note: note,
            checklist: checklist,
            notificationType: selectedNotificationType,
            notificationEnabled: notificationEnabled,
            notificationTime: notificationTime,
            deletePastEvents: deletePastEvents,
            notificationDaysOfWeek: Array(selectedDaysOfWeek),
            notificationMonths: Array(selectedMonths),
            repeatInterval: selectedRepeatInterval,
            repeatMonthly: repeatMonthly,
            repeatYearly: repeatYearly
        )

        updatedEvent.isFromWatch = eventType == .event
            ? asBirthdays.events[eventIndex].isFromWatch
            : asBirthdays.birthdays[eventIndex].isFromWatch

        updatedEvent.isNewlyCreated = eventType == .event
            ? asBirthdays.events[eventIndex].isNewlyCreated
            : asBirthdays.birthdays[eventIndex].isNewlyCreated

        if updatedEvent.date < Date() {
            if let futureDate = asBirthdays.getFutureDate(for: updatedEvent.date, event: updatedEvent) {
                updatedEvent.date = futureDate
            }
        }

        asBirthdays.updateEvent(updatedEvent, eventType: eventType)

        let identifiersToRemove = [
            updatedEvent.id.uuidString,
            updatedEvent.id.uuidString + "_event",
            updatedEvent.id.uuidString + "_repeat"
        ]

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        center.removeDeliveredNotifications(withIdentifiers: identifiersToRemove)

        EventManager.shared.scheduleNotificationsForAllEvents()

        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 reloadAllTimelines() из scheduleNotificationsForAllEvents")
        WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
        print("🔄 reloadTimelines(ofKind:) из scheduleNotificationsForAllEvents")
        
        
        //для swift data
        
        do {
            let descriptor = FetchDescriptor<EventModel>(
                predicate: #Predicate { $0.id == updatedEvent.id },
                sortBy: []
            )

            if let swiftDataEvent = try modelContext.fetch(descriptor).first {
                swiftDataEvent.name = updatedEvent.name
                swiftDataEvent.date = updatedEvent.date
                swiftDataEvent.emoji = updatedEvent.emoji
                swiftDataEvent.note = updatedEvent.note
                swiftDataEvent.isPinned = updatedEvent.isPinned
                swiftDataEvent.originalIndex = updatedEvent.originalIndex
                swiftDataEvent.eventType = updatedEvent.eventType
                swiftDataEvent.notificationEnabled = updatedEvent.notificationEnabled
                swiftDataEvent.notificationTime = updatedEvent.notificationTime
                swiftDataEvent.notificationType = updatedEvent.notificationType
                swiftDataEvent.deletePastEvents = updatedEvent.deletePastEvents
                swiftDataEvent.notificationDaysOfWeek = updatedEvent.notificationDaysOfWeek
                swiftDataEvent.notificationMonths = updatedEvent.notificationMonths
                swiftDataEvent.repeatInterval = updatedEvent.repeatInterval
                swiftDataEvent.repeatMonthly = updatedEvent.repeatMonthly
                swiftDataEvent.repeatYearly = updatedEvent.repeatYearly
                swiftDataEvent.isFromWatch = updatedEvent.isFromWatch
                swiftDataEvent.isNewlyCreated = updatedEvent.isNewlyCreated

                // 📝 Обновляем чеклист
                swiftDataEvent.checklist.removeAll()
                for (index, item) in updatedEvent.checklist.enumerated() {
                    let newItem = ChecklistItemModel(text: item.text, isCompleted: item.isCompleted, order: index)
                    newItem.event = swiftDataEvent
                    swiftDataEvent.checklist.append(newItem)
                }

                try modelContext.save()
            }
        } catch {
            print("Ошибка при обновлении SwiftData: \(error)")
        }
// конец swif data
        
        

        presentationMode.wrappedValue.dismiss()
    }
}





// Экран настроек повтора
struct RepeatSettingsView: View {
    @Binding var selectedDaysOfWeek: Set<DayOfWeek>
    @Binding var selectedMonths: Set<Month>
    @Binding var selectedRepeatInterval: RepeatInterval
    @Binding var repeatMonthly: Bool
    @Binding var repeatYearly: Bool
    @Binding var deletePastEvents: Bool
    
    var onDismiss: (() -> Void)?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            Section(header: Text(LocalizedStringKey("repeatSettings.annualRepeatHeader"))) {
                Toggle(isOn: $repeatYearly) {
                    Text(LocalizedStringKey("repeatSettings.annualRepeatToggle"))
                }
                .onChange(of: repeatYearly) { newValue in
                    if newValue {
                        selectedRepeatInterval = .none
                        selectedDaysOfWeek.removeAll()
                        repeatMonthly = false
                        selectedMonths.removeAll()
                        deletePastEvents = false
                    }
                }
            }
            
            Section(header: Text(LocalizedStringKey("repeatSettings.intervalHeader"))) {
                Picker(LocalizedStringKey("repeatSettings.intervalPicker"), selection: $selectedRepeatInterval) {
                    ForEach(RepeatInterval.allCases, id: \.self) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .onChange(of: selectedRepeatInterval) { newValue in
                    repeatMonthly = false
                    repeatYearly = false
                    selectedDaysOfWeek.removeAll()
                    selectedMonths.removeAll()
                    if newValue != .none {
                        deletePastEvents = false
                    }
                }
            }
            
            Section(header: Text(LocalizedStringKey("repeatSettings.daysOfWeekHeader"))) {
                ForEach(DayOfWeek.allCases, id: \.self) { dayOfWeek in
                    Toggle(dayOfWeek.displayName, isOn: Binding(
                        get: {
                            selectedDaysOfWeek.contains(dayOfWeek)
                        },
                        set: { isSelected in
                            if isSelected {
                                selectedDaysOfWeek.insert(dayOfWeek)
                                selectedRepeatInterval = .none
                                repeatMonthly = false
                                repeatYearly = false
                                selectedMonths.removeAll()
                                deletePastEvents = false
                            } else {
                                selectedDaysOfWeek.remove(dayOfWeek)
                            }
                        }
                    ))
              
                }
            }
            
            Section(header: Text(LocalizedStringKey("repeatSettings.monthsHeader"))) {
                ForEach(Month.allCases, id: \.self) { month in
                    Toggle(month.displayName, isOn: Binding(
                        get: {
                            selectedMonths.contains(month)
                        },
                        set: { isSelected in
                            if isSelected {
                                selectedMonths.insert(month)
                                selectedRepeatInterval = .none
                                selectedDaysOfWeek.removeAll()
                                repeatMonthly = false
                                repeatYearly = false
                                deletePastEvents = false
                            } else {
                                selectedMonths.remove(month)
                            }
                        }
                    ))
                }
            }
            
            Section(header: Text(LocalizedStringKey("repeatSettings.monthlyRepeatHeader"))) {
                Toggle(isOn: $repeatMonthly) {
                    Text(LocalizedStringKey("repeatSettings.monthlyRepeatToggle"))
                }
                .onChange(of: repeatMonthly) { newValue in
                    if newValue {
                        selectedRepeatInterval = .none
                        selectedDaysOfWeek.removeAll()
                        repeatYearly = false
                        selectedMonths.removeAll()
                        deletePastEvents = false
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            onDismiss?()
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Image(systemName: "chevron.backward")
                Text(LocalizedStringKey("common.saveButton"))
            }
        })
        .onDisappear {
            onDismiss?()
        }
    }
}




struct MultipleSelectionRow: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: self.action) {
            HStack {
                Text(self.title)
                Spacer()
                if self.isSelected {
                    Image(systemName: "checkmark.square.fill")
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "square")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}


// Расширение для добавления методов к EventsListView
extension EventsListView {
    // Метод для проверки подписки перед добавлением события
    private func checkSubscriptionBeforeAddingEvent() {
        eventManager.checkSubscriptionStatus {
            DispatchQueue.main.async {
                if !eventManager.canAddEvent(ofType: .event) && !eventManager.subscriptionIsActive {
                    // Показываем только Paywall, если лимит событий превышен и подписка неактивна
                    displayPaywall = true
                    dictationDraft = nil
                } else {
                    // Показываем окно добавления события, если лимит не превышен
                    displayPaywall = false
                    dictationDraft = DictationDraft(title: "", date: selectedDate, note: "", hasTime: true)
                }
            }
        }
    }
    
    // Метод для обновления повторяющихся событий
    func updateRepeatingEvents() {
        for event in eventManager.events + eventManager.birthdays {
            eventManager.updateRepeatingEvent(event)
        }
    }
}







// Основная структура представления
//промежуток




// для чеклиста


//промежуток




struct AddEventView: View {
    @EnvironmentObject var eventManager: EventManager
    private let sourceDate: Date
    private let sourceHasTime: Bool
    @State private var showingSubscriptionModal = false
    @State private var name: String = ""
    @State private var eventDate: Date = Date()
    @State private var eventType: EventType = .event
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedEmoji = ""
    @State private var note = ""
    @State private var notificationEnabled: Bool = false
    @State private var notificationTime: Date? = Date()
    @State private var deletePastEvents: Bool = true
    @State private var selectedNotificationType: NotificationType = .message
    @State private var selectedDaysOfWeek: Set<DayOfWeek> = []
    @State private var selectedMonths: Set<Month> = []
    @State private var selectedRepeatInterval: RepeatInterval = .none
    @State private var repeatMonthly: Bool = false
    @State private var repeatYearly: Bool = false
    @State private var includeTimeForEvent: Bool = true
    @State private var includeTimeForNotification: Bool = true
    @State private var selectedEmojiCategory: EmojiCategory? = nil
    @State private var displayPaywall = false

    @State private var isInteractiveList: Bool = false
    @State private var checklist: [ChecklistItem] = []
    @State private var newChecklistItemText: String = ""
    @State private var isEditingChecklist = false

    @State private var hasAppeared = false
    @State private var isRepeatSectionExpanded: Bool = false
    @State private var isDateSectionExpanded: Bool = false
    
    @Environment(\.modelContext) private var modelContext

    private let editorHeight: CGFloat = 100

    init(initialDate: Date, initialName: String = "", initialNote: String = "", hasTime: Bool = true) {
        self.sourceDate = initialDate
        self.sourceHasTime = hasTime

        let cal   = Calendar.current
        let comps  = cal.dateComponents([.hour, .minute], from: initialDate)
        let hasTimeInDate = (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0

        let finalDate: Date = hasTimeInDate
            ? initialDate
            : cal.date(
                bySettingHour: cal.component(.hour, from: Date()),
                minute:        cal.component(.minute, from: Date()),
                second:        0,
                of: initialDate
              ) ?? initialDate

        let showTime = hasTime || hasTimeInDate

        _eventDate = State(initialValue: finalDate)
        _notificationTime = State(initialValue: finalDate)
        _includeTimeForEvent = State(initialValue: showTime)
        _includeTimeForNotification = State(initialValue: showTime)
        _name = State(initialValue: initialName)
        _note = State(initialValue: initialNote)
        _isDateSectionExpanded = State(initialValue: true)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // -----------------------------
                //   СЕКЦИЯ ВЫБОРА ТИПА И НАЗВАНИЯ
                // -----------------------------
                Section {
                    Picker(LocalizedStringKey("event_type_picker_title"), selection: $eventType) {
                        ForEach(EventType.allCases, id: \.self) { type in
                            Text(type.localizedName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .listRowSeparator(.hidden)
                    .frame(minHeight: -100)
                    
                    .onChange(of: eventType) { newValue in
                        if hasAppeared {
                            resetEventAndNotificationSettings(for: newValue)
                        }
                    }
                    
                    TextField(
                        eventType == .birthday
                        ? NSLocalizedString("birthday_name_placeholder", comment: "")
                        : NSLocalizedString("event_name_placeholder", comment: ""),
                        text: $name
                    )
                    
                    // -----------------------------
                    //  ЗАМЕТКА ИЛИ СПИСОК
                    // -----------------------------
                    if isInteractiveList {
                        // Секция чек-листа
                        Section(header: HStack {
                           Text(LocalizedStringKey("checklist_section_header"))
                            Spacer()
                            Button {
                                withAnimation {
                                    isEditingChecklist.toggle()
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .foregroundColor(.blue)
                            }
                        }) {
                            ForEach($checklist) { $item in
                                HStack {
                                    Button { item.isCompleted.toggle() } label: {
                                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(item.isCompleted ? .green : .gray)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    TextField(LocalizedStringKey("checklist_item_placeholder"), text: $item.text)
                                        .disabled(item.isCompleted)
                                        .foregroundColor(item.isCompleted ? .gray : .primary)
                                        .strikethrough(item.isCompleted, color: .gray)
                                    
                                    Spacer()
                                    
                                    Button {
                                        if let idx = checklist.firstIndex(where: { $0.id == item.id }) {
                                            checklist.remove(at: idx)
                                        }
                                    } label: {
                                        Image(systemName: "trash").foregroundColor(.red)
                                    }
                                }
                            }
                            .onMove(perform: moveChecklistItem)
                            
                            HStack {
                                TextField(LocalizedStringKey("new_checklist_item_placeholder"), text: $newChecklistItemText)
                                Button { addChecklistItem() } label: {
                                    Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                                }
                            }
                        }
                        .environment(\.editMode, isEditingChecklist ? .constant(.active) : .constant(.inactive))
                    } else {
                        // Поле заметки
                        ZStack(alignment: .topLeading) {
                            if note.isEmpty {
                                Text(LocalizedStringKey("notes_placeholder_text"))
                                    .foregroundColor(Color.gray.opacity(0.5))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 4)
                            }
                            TextEditor(text: $note)
                                .padding(.horizontal, 4)
                                .scrollDisabled(false)
                                .scrollContentBackground(.hidden)
                        }
                        .frame(minHeight: editorHeight)
                    }
          
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isInteractiveList = false
                            }
                        }) {
                            Text(LocalizedStringKey("notes_tab_title"))
                                .foregroundColor(isInteractiveList ? Color.gray : Color.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Rectangle())
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isInteractiveList = true
                            }
                        }) {
                            Text(LocalizedStringKey("checklist_tab_title"))
                                .foregroundColor(isInteractiveList ? Color.primary : Color.gray)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Rectangle())
                    }
                    .frame(height: 44)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
                
                // Остальные секции остаются без изменений...
                // -----------------------------
                //   СЕКЦИЯ ДАТЫ И УВЕДОМЛЕНИЙ
                // -----------------------------
                Section(header:
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("date_section_header"))
                        if !isDateSectionExpanded {
                            Text(dateSummary)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        Image(systemName: isDateSectionExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation { isDateSectionExpanded.toggle() }
                    }
                ) {
                    if isDateSectionExpanded {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.title2)
                                .foregroundColor(.blue)
                            DatePicker(
                                "",
                                selection: $eventDate,
                                displayedComponents: eventType == .birthday
                                ? [.date]
                                : (includeTimeForEvent ? [.date, .hourAndMinute] : [.date])
                            )
                            .labelsHidden()
                            .datePickerStyle(CompactDatePickerStyle())
                            .onChange(of: eventDate) { newValue in
                                if notificationEnabled {
                                    syncNotificationTime(for: newValue)
                                }
                            }
                            Spacer()
                            if includeTimeForEvent && eventType != .birthday {
                                Button(action: {
                                    includeTimeForEvent = false
                                    eventDate = Calendar.current.startOfDay(for: eventDate)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            } else if eventType != .birthday {
                                Button(action: {
                                    includeTimeForEvent = true
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }

                        HStack {
                            Image(systemName: "bell")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Toggle(LocalizedStringKey("notification_toggle_title"), isOn: $notificationEnabled)
                                .onChange(of: notificationEnabled) { newValue in
                                    if newValue {
                                        syncNotificationTime(for: eventDate)
                                    }
                                    if newValue && eventType == .birthday {
                                        setNotificationTimeForBirthday()
                                    }
                                }
                        }

                        if notificationEnabled {
                            HStack {
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { notificationTime ?? eventDate },
                                        set: { notificationTime = $0 }
                                    ),
                                    displayedComponents: includeTimeForNotification
                                    ? [.date, .hourAndMinute]
                                    : [.date]
                                )
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }

                            Picker("", selection: $selectedNotificationType) {
                                Text(LocalizedStringKey("notification_type_message")).tag(NotificationType.message)
                                Text(LocalizedStringKey("notification_type_sound")).tag(NotificationType.sound)
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
                
                // Секция выбора эмоджи
                Section(header: Text(LocalizedStringKey("emoji_section_header"))
                    .padding(.top, -10)
                ) {
                    // Выбор категории
                    HStack {
                        Image(systemName: "face.smiling")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .padding(.trailing, 8)
                        
                        Picker(LocalizedStringKey("editEvent.emoji.categoryPicker"), selection: $selectedEmojiCategory) {
                            ForEach(emojiCategories, id: \.self) { category in
                                Text(category.name).tag(category as EmojiCategory?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    if let category = selectedEmojiCategory, category.name != NSLocalizedString("CATEGORY_NAME_NONE", comment: "") {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(category.emojis, id: \.self) { emoji in
                                    Text(emoji)
                                        .font(.largeTitle)
                                        .padding(4)
                                        .background(selectedEmoji == emoji ? Color.blue.opacity(0.3) : Color.clear)
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            selectedEmoji = emoji
                                        }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
                
                // -----------------------------
                //   СЕКЦИЯ ПОВТОРА (ТОЛЬКО ДЛЯ EVENT)
                // -----------------------------
                if eventType == .event {
                    Section(header: HStack(spacing: 4) {
                        Text(LocalizedStringKey("repeat_section_header"))
                        Image(systemName: isRepeatSectionExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation { isRepeatSectionExpanded.toggle() }
                    }) {
                        if isRepeatSectionExpanded {
                            NavigationLink(
                                destination: RepeatSettingsView(
                                    selectedDaysOfWeek: $selectedDaysOfWeek,
                                    selectedMonths: $selectedMonths,
                                    selectedRepeatInterval: $selectedRepeatInterval,
                                    repeatMonthly: $repeatMonthly,
                                    repeatYearly: $repeatYearly,
                                    deletePastEvents: $deletePastEvents,
                                    onDismiss: saveChanges
                                )
                            ) {
                                HStack {
                                    Image(systemName: "arrow.2.circlepath")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 24))
                                    Spacer()
                                    Text(repeatSettingsDescription())
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
                    .padding(.bottom, 0)
                }
                
                // -----------------------------
                //   СЕКЦИЯ «УДАЛИТЬ ПОСЛЕ ЗАВЕРШЕНИЯ»
                // -----------------------------
                if eventType == .event {
                    HStack {
                        Spacer()
                        
                        Text(LocalizedStringKey("delete_past_events_text"))
                            .foregroundColor(.gray)
                            .font(.callout)
                        
                        Button(action: {
                            deletePastEvents.toggle()
                        }) {
                            Image(systemName: deletePastEvents ? "checkmark.circle.fill" : "circle")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .foregroundColor(deletePastEvents ? .blue : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                    }
                    .listRowInsets(EdgeInsets(top: -20, leading: 15, bottom: 0, trailing: 15))
                    .listRowBackground(Color.clear)
                    .padding(.bottom, 0)
                    .navigationBarTitleDisplayMode(.inline)
                    
                    .onChange(of: selectedRepeatInterval) { _ in
                        checkRepeatStatus()
                    }
                    .onChange(of: repeatMonthly) { _ in
                        checkRepeatStatus()
                    }
                    .onChange(of: selectedDaysOfWeek) { _ in
                        checkRepeatStatus()
                    }
                    .onChange(of: selectedMonths) { _ in
                        checkRepeatStatus()
                    }
                    
                    // Кнопка «Сохранить»
                    Button(action: {
                        saveEvent()
                    }) {
                        Text(LocalizedStringKey("save_button_title"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .listRowBackground(Color.clear)
                    .padding(.top, 0)
                    
                    .listRowSeparator(.hidden)
                }
                
                // -----------------------------
                //   СЕКЦИЯ "СОХРАНИТЬ" (ТОЛЬКО ДЛЯ ДНЕЙ РОЖДЕНИЙ)
                // -----------------------------
                if eventType == .birthday {
                    Section {
                        Button(action: {
                            saveEvent()
                        }) {
                            Text(LocalizedStringKey("save_button_title"))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .listRowBackground(Color.clear)
                        .padding(.top, 0)
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .padding(.top, -40)
            .onAppear {
                DispatchQueue.main.async {
                    if !hasAppeared {
                        hasAppeared = true
                    }
                    includeTimeForEvent = sourceHasTime ||
                        !Calendar.current.isDate(
                            sourceDate,
                            equalTo: Calendar.current.startOfDay(for: sourceDate),
                            toGranularity: .minute
                        )
                }
            }
            .navigationBarItems(leading: Button(action: {
                saveChanges()
                presentationMode.wrappedValue.dismiss()
                generateFeedback()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
            })
            .sheet(isPresented: $displayPaywall) {
                PaywallView(displayCloseButton: true)
            }
        }
    }

    // MARK: - Вспомогательные функции

    private var dateSummary: String {
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateStyle = .medium
        fmt.timeStyle = includeTimeForEvent ? .short : .none
        return fmt.string(from: eventDate)
    }

    private func syncNotificationTime(for date: Date) {
        let now = Date()
        let calendar = Calendar.current
        
        if date < now {
            var components = calendar.dateComponents([.hour, .minute, .month, .day], from: date)
            components.year = calendar.component(.year, from: now)
            if let notificationDateThisYear = calendar.date(from: components), notificationDateThisYear < now {
                components.year! += 1
            }
            notificationTime = calendar.date(from: components) ?? notificationTime
        } else {
            notificationTime = date
        }
    }
    
    private func addChecklistItem() {
        let trimmedText = newChecklistItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        checklist.append(ChecklistItem(text: trimmedText))
        newChecklistItemText = ""
    }
    
    private func moveChecklistItem(from source: IndexSet, to destination: Int) {
        checklist.move(fromOffsets: source, toOffset: destination)
    }
    
    private func resetEventAndNotificationSettings(for eventType: EventType) {
        switch eventType {
        case .birthday:
            includeTimeForEvent = false
            includeTimeForNotification = true
            deletePastEvents = false
        case .event:
            includeTimeForEvent = true
            includeTimeForNotification = true
        }
    }
    
    private func saveEvent() {
        eventManager.checkSubscriptionStatus {
            if !eventManager.canAddEvent(ofType: eventType) && !eventManager.subscriptionIsActive {
                displayPaywall = true
            } else {
                var newEvent = Event(
                    name: name,
                    date: eventDate,
                    showCountdown: false,
                    eventType: eventType,
                    emoji: selectedEmoji,
                    note: note,
                    checklist: checklist.map { ChecklistItem(text: $0.text, isCompleted: $0.isCompleted) },
                    notificationType: selectedNotificationType,
                    notificationEnabled: notificationEnabled,
                    notificationTime: notificationTime,
                    deletePastEvents: deletePastEvents,
                    notificationDaysOfWeek: Array(selectedDaysOfWeek),
                    notificationMonths: Array(selectedMonths),
                    repeatInterval: selectedRepeatInterval,
                    repeatMonthly: repeatMonthly,
                    repeatYearly: eventType == .birthday ? true : repeatYearly
                )

                if newEvent.date < Date() {
                    if let updatedDate = eventManager.getFutureDate(for: newEvent.date, event: newEvent) {
                        newEvent.date = updatedDate
                    }
                }

                eventManager.saveEvent(newEvent, eventType: eventType)

                WidgetCenter.shared.reloadAllTimelines()
                print("🔄 reloadAllTimelines() из создания события")

                PhoneConnectivityManager.shared.sendEventsImmediately(
                    eventManager.events + eventManager.birthdays
                )

                let swiftDataModel = EventModel(from: newEvent)
                modelContext.insert(swiftDataModel)
                try? modelContext.save()

                presentationMode.wrappedValue.dismiss()
                generateFeedback()
            }
        }
    }
    
    private func saveChanges() {
        // Дополнительные действия при сохранении изменений
    }
    
    private func repeatSettingsDescription() -> String {
        var descriptions: [String] = []
        
        if repeatYearly {
            descriptions.append(NSLocalizedString("yearly_repeat", comment: ""))
        }
        if repeatMonthly {
            descriptions.append(NSLocalizedString("monthly_repeat", comment: ""))
        }
        if selectedRepeatInterval != .none {
               let key = "repeatInterval.\(selectedRepeatInterval.rawValue)"
               descriptions.append(NSLocalizedString(key, comment: ""))
          }
        if !selectedDaysOfWeek.isEmpty {
            let days = selectedDaysOfWeek.map { $0.displayName }.joined(separator: ", ")
            let formatString = NSLocalizedString("weekdays_format", comment: "")
            descriptions.append(String(format: formatString, days))
        }
        if !selectedMonths.isEmpty {
            let months = selectedMonths.map { $0.displayName }.joined(separator: ", ")
            let formatString = NSLocalizedString("months_format", comment: "")
            descriptions.append(String(format: formatString, months))
        }
        
        return descriptions.isEmpty
        ? NSLocalizedString("no_repeat", comment: "")
        : descriptions.joined(separator: ", ")
    }
    
    private func checkRepeatStatus() {
        if selectedRepeatInterval != .none
            || repeatMonthly
            || repeatYearly
            || !selectedDaysOfWeek.isEmpty
            || !selectedMonths.isEmpty
        {
            deletePastEvents = false
        }
    }
    
    private func generateFeedback() {
        HapticManager.shared.impact(style: .medium)
    }
    
    private func setNotificationTimeForBirthday() {
        let calendar = Calendar.current
        let now = Date()
        
        var components = calendar.dateComponents([.year, .month, .day], from: eventDate)
        components.year = calendar.component(.year, from: now)
        
        if components.hour == nil || components.minute == nil {
            components.hour = 9
            components.minute = 0
        }
        
        if let notificationDateThisYear = calendar.date(from: components), notificationDateThisYear < now {
            components.year! += 1
        }
        
        notificationTime = calendar.date(from: components) ?? notificationTime
        includeTimeForNotification = true
    }
}



struct AnimatedSideBar<Content: View, MenuView: View, Background: View>: View {
    var rotatesWhenExpands: Bool = true
    var sideMenuWidth: CGFloat = 500
    var cornerRadius: CGFloat = 25
    @Binding var showMenu: Bool
    
    @ViewBuilder var content: (UIEdgeInsets) -> Content
    @ViewBuilder var menuView: (UIEdgeInsets) -> MenuView
    
    @ViewBuilder var background: () -> Background
    
    @GestureState private var isDragging: Bool = false
    @State private var offsetX: CGFloat = 0
    @State private var lastOffsetX: CGFloat = 0
    @State private var progress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            let safeArea = geometry.safeAreaInsets.toUIEdgeInsets() // ✅ Конвертация в UIEdgeInsets
            
            HStack(spacing: 0) {
                GeometryReader { _ in
                    menuView(safeArea)
                }
                .frame(width: sideMenuWidth)
                .contentShape(Rectangle())
                
                GeometryReader { _ in
                    content(safeArea)
                }
                .frame(width: geometry.size.width)
                .mask {
                    RoundedRectangle(cornerRadius: progress * cornerRadius)
                }
                .scaleEffect(rotatesWhenExpands ? 1 - (progress * 0.1) : 1, anchor: .trailing)
                .rotation3DEffect(
                    .init(degrees: rotatesWhenExpands ? (progress * -15) : 0),
                    axis: (x: 0.0, y: 1.0, z: 0.0)
                )
            }
            .frame(width: geometry.size.width + sideMenuWidth, height: geometry.size.height)
            .offset(x: -sideMenuWidth)
            .offset(x: offsetX)
            .contentShape(Rectangle())
            .gesture(showMenu ? dragGesture : nil)
        }
        .background(background())
        .ignoresSafeArea()
        .onChange(of: showMenu, initial: true) { oldValue, newValue in
            withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {
                if newValue {
                    showSideBar()
                } else {
                    reset()
                }
            }
        }
    }
    
    var dragGesture: some Gesture {
        DragGesture()
            .updating($isDragging) { _, out, _ in
                out = true
            }.onChanged { value in
                guard showMenu else { return }
                DispatchQueue.main.async {
                    let translationX = max(min(value.translation.width + lastOffsetX, sideMenuWidth), 0)
                    offsetX = translationX
                    calculateProgress()
                }
            }.onEnded { value in
                guard showMenu else { return }
                withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {
                    let velocityX = value.velocity.width / 8
                    let total = velocityX + offsetX
                    if total > (sideMenuWidth * 0.5) {
                        showSideBar()
                    } else {
                        reset()
                    }
                }
            }
    }
    
    func showSideBar() {
        offsetX = sideMenuWidth
        lastOffsetX = offsetX
        showMenu = true
        calculateProgress()
    }
    
    func reset() {
        offsetX = 0
        lastOffsetX = 0
        showMenu = false
        calculateProgress()
    }
    
    func calculateProgress() {
        progress = max(min(offsetX / sideMenuWidth, 1), 0)
    }
}

// 🔥 **Расширение для конвертации EdgeInsets в UIEdgeInsets**
extension EdgeInsets {
    func toUIEdgeInsets() -> UIEdgeInsets {
        return UIEdgeInsets(top: self.top, left: self.leading, bottom: self.bottom, right: self.trailing)
    }
}





// Дополнительное расширение, позволяющее условно применять модификатор (если у вас его ещё нет)
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool,
                               transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}



// лайв активити


  extension Date {
      /// Возвращает ближайшую будущую дату ДР, сохраняя часы, минуты и секунды из self
      func nextBirthdayPreservingTime() -> Date {
          let cal = Calendar.current
          let now = Date()
          // Берём месяц, день, час, минуту, секунду из self
          var comps = cal.dateComponents([.month, .day, .hour, .minute, .second], from: self)
          // Подставляем текущий год
          comps.year = cal.component(.year, from: now)
          // Дата-кандидат на этот год
          let candidate = cal.date(from: comps)!
          // Если уже в прошлом – сдвигаем на +1 год
          return candidate >= now
              ? candidate
              : cal.date(byAdding: .year, value: 1, to: candidate)!
      }
  }

  




extension String: Identifiable {
    public var id: String { self }   // Само значение строки и будет её уникальным id
}




struct EventsListView: View {
    @EnvironmentObject var eventManager: EventManager
    
    @State private var dictationDraft: DictationDraft? = nil
    @State private var isCreatingEventFromSidebar = true
    @State private var searchText = ""
    @State private var showingSettingsSheet = false
    @State private var displayPaywall = false
    @State private var showMenu: Bool = false
    @State private var selectedDate = Date()
    @State private var selectedEventForEditing: Event?

    @State private var contentOffset: CGFloat = 0 // Отслеживание скролла
    @State private var isAtTop = false // Проверка, достиг ли скролл нулевой позиции
    
    // Фильтр событий
    @State private var selectedFilter: EventFilter = .all


    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isLongPressing = false
    @State private var isPlusPressed = false // finger-contact only
    @State private var longPressTimer: Timer?
    @State private var showDictationButton = false   // синяя кнопка всплыла?
    @State private var didLongPress = false   // Было ли длинное нажатие

    // ——— жест «отмена свайпом» ———
    @State private var dragOffset: CGSize = .zero      // текущее смещение пальца
    @State private var isCancelledBySwipe = false      // отменили ли диктовку
    private let cancelThreshold: CGFloat = -100        // «насколько» увести палец влево
    /// Прогресс закрытия окна (0 – порог не достигнут, 1 – у порога)
    private var cancelSwipeProgress: CGFloat {
        let leftDrag = max(0, -dragOffset.width)
        let ratio = min(1, leftDrag / abs(cancelThreshold))
        return 1 - ratio
    }
    

    @Environment(\.modelContext) private var modelContext //для swift data
    @State private var eventCleanupTimer: Timer? //для swift data

    // ① НОВОЕ: все записи из БД, уже отсортированы по дате
      @Query(sort: \EventModel.date) private var models: [EventModel]
    
   
    // MARK: — преобразования из EventModel → Event
       private var asEvents:    [Event] { models.filter { $0.eventType == .event     }.map(Event.init) }
       private var asBirthdays: [Event] { models.filter { $0.eventType == .birthday  }.map(Event.init) }
       private var allEvents:   [Event] { asEvents + asBirthdays }

    
    enum EventFilter: CaseIterable {
        case all
        case events
        case birthdays
        
        var index: Int {
            switch self {
            case .all:
                return 0
            case .events:
                return 1
            case .birthdays:
                return 2
            }
        }
        
        var localized: String {
            switch self {
            case .all:
                return NSLocalizedString("filter.all", comment: "Все события и дни рождения")
            case .events:
                return NSLocalizedString("filter.events", comment: "События")
            case .birthdays:
                return NSLocalizedString("filter.birthdays", comment: "Дни рождения")
            }
        }
    }
    
    
    
    
   private var totalEventsCount: Int { allEvents.count }
    
    var body: some View {
        let hideUI = isLongPressing
        AnimatedSideBar(
            rotatesWhenExpands: true,
            sideMenuWidth: 310,
            cornerRadius: 25,
            showMenu: $showMenu,

            content: { safeArea in
                ZStack(alignment: .bottomTrailing) {
                    NavigationView {
                        eventList
                            .navigationBarHidden(isLongPressing)
                    }
                    .if(!isLongPressing) {
                        $0.searchable(text: $searchText,
                                      prompt: NSLocalizedString("search.prompt", comment: ""))
                    }

                    plusButton

                    if isLongPressing {
                        VoiceRecorderOverlay(
                            amplitude: $speechRecognizer.amplitude,
                            dragOffset: $dragOffset,
                            transcript: speechRecognizer.transcript,
                            fadeProgress: cancelSwipeProgress
                        )

                            .ignoresSafeArea()
                            .overlay(alignment: .bottomTrailing) { dictationButton }
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragOffset = value.translation
                                        if dragOffset.width < cancelThreshold {
                                            isCancelledBySwipe = true
                                            didLongPress = false
                                            speechRecognizer.stopRecording { _ in }
                                            isLongPressing = false
                                        }
                                    }
                                    .onEnded { _ in dragOffset = .zero }
                            )
                            .onAppear {
                                showDictationButton = true
                                lightHaptic()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { lightHaptic() }
                            }
                            .onDisappear {
                                showDictationButton = false
                                isCancelledBySwipe = false
                                lightHaptic()
                            }
                            .transition(.opacity)
                    }
                }
                .allowsHitTesting(!showMenu)
            },
            
            menuView: { safeArea in
                SideBarMenuView(
                    safeArea: safeArea,
                    selectedDate: $selectedDate,
                    dictationDraft: $dictationDraft,
                    showingSettingsSheet: $showingSettingsSheet,
                    isCreatingEventFromSidebar: $isCreatingEventFromSidebar
                )
            },
            
            background: {
                Rectangle()
                    .fill(Color.black)
            }
        )
        .sheet(item: $dictationDraft) { draft in
            AddEventView(initialDate: draft.date,
                         initialName: draft.title,
                         initialNote: draft.note,
                         hasTime: draft.hasTime)
                .environmentObject(eventManager)
        }
        .onChange(of: isLongPressing) { started in
            if started {
                HapticManager.shared.light()
            }
        }
        .onChange(of: showDictationButton) { visible in
            if visible {
                HapticManager.shared.light()
            }
        }

    }


    private var eventList: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(.systemGray6)
                .edgesIgnoringSafeArea(.all)

            VStack {
                ScrollView {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                contentOffset = geo.frame(in: .global).minY
                            }
                            .onChange(of: geo.frame(in: .global).minY) { newValue in
                                contentOffset = newValue

                                if newValue <= 0 {
                                    isAtTop = true
                                } else {
                                    isAtTop = false
                                }
                            }
                    }
                    .frame(height: 0)

                    Picker("Фильтр", selection: $selectedFilter) {
                        ForEach(EventFilter.allCases, id: \.index) { filter in
                            Text(filter.localized).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if filteredPinnedEvents.isEmpty && filteredUnpinnedEvents.isEmpty && filteredBirthdays.isEmpty {
                        VStack {
                            (
                                Text(LocalizedStringKey("empty.prefix")) +
                                Text(LocalizedStringKey("empty.event"))
                                    .foregroundColor(.blue)
                                    .fontWeight(.bold) +
                                Text(LocalizedStringKey("empty.middle")) +
                                Text(LocalizedStringKey("empty.birthday"))
                                    .foregroundColor(.blue)
                                    .fontWeight(.bold)
                            )
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 40)
                        }
                    } else {
                        LazyVStack(alignment: .leading, pinnedViews: [.sectionHeaders]) {
                            if !filteredPinnedEvents.isEmpty {
                                Section(
                                    header: Text(LocalizedStringKey("header.pinned"))
                                        .foregroundColor(.gray.opacity(0.7))
                                        .font(.subheadline)
                                        .padding(.leading, 20)
                                ) {
                                    ForEach(filteredPinnedEvents) { event in
                                        EventCardView(event: event)
                                            .id(event.id)
                                            .padding(.horizontal, 10)
                                            .onTapGesture {
                                                selectedEventForEditing = event
                                            }
                                    }
                                }
                            }

                            if !filteredUnpinnedEvents.isEmpty {
                                Section(
                                    header: Text(LocalizedStringKey("header.events"))
                                        .foregroundColor(.gray.opacity(0.7))
                                        .font(.subheadline)
                                        .padding(.leading, 20)
                                ) {
                                    ForEach(filteredUnpinnedEvents) { event in
                                        EventCardView(event: event)
                                            .id(event.id)
                                            .padding(.horizontal, 10)
                                            .onTapGesture {
                                                selectedEventForEditing = event
                                            }
                                    }
                                }
                            }

                            if !filteredBirthdays.isEmpty {
                                Section(
                                    header: Text(LocalizedStringKey("header.birthdays"))
                                        .foregroundColor(.gray.opacity(0.7))
                                        .font(.subheadline)
                                        .padding(.leading, 20)
                                ) {
                                    ForEach(filteredBirthdays) { event in
                                        EventCardView(event: event)
                                            .id(event.id)
                                            .padding(.horizontal, 10)
                                            .onTapGesture {
                                                selectedEventForEditing = event
                                            }
                                    }
                                }
                            }
                        }
                        .padding(.top, 10)
                    }
                }
                .onAppear {
                    startLiveActivityIfNeeded()
                    EventManager.shared.deletePastEventsHandler(modelContext: modelContext)
                    setupEventCleanupTimer()
                }
                .onDisappear {
                    eventCleanupTimer?.invalidate()
                    eventCleanupTimer = nil
                }
            }
        }
        .allowsHitTesting(!showMenu)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showMenu.toggle() }) {
                    Image(systemName: showMenu ? "xmark" : "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }

            ToolbarItem(placement: .principal) {
                if isAtTop {
                    Menu {
                        ForEach(EventFilter.allCases, id: \.index) { filter in
                            Button(action: { selectedFilter = filter }) {
                                Text(filter.localized)
                                    .font(.system(size: 8))
                            }
                        }
                    } label: {
                        Text(selectedFilter.localized)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }


    private var plusButton: some View {
        Button {
            // gасим обычный tap, если был долгий нажим
            guard !didLongPress else {
                didLongPress = false      // сброс на будущее
                return
            }
            // "Нормальный" короткий тап
            dictationDraft = DictationDraft(title: "", date: selectedDate, note: "", hasTime: true)
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .foregroundColor(.blue)
                .padding()
                .background(Circle().fill(.ultraThinMaterial))
        }
        .padding(.trailing, 24)
        .padding(.bottom,   34)
        .scaleEffect(isPlusPressed ? 0.95 : 1)
        .animation(.easeInOut(duration: 0.1), value: isPlusPressed)
        .onLongPressGesture(minimumDuration: 0,
                            pressing: handlePressing,
                            perform: {})
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    if isLongPressing && dragOffset.width < cancelThreshold {
                        isCancelledBySwipe = true
                        didLongPress = false
                        speechRecognizer.stopRecording { _ in }
                        isLongPressing = false
                    }
                }
                .onEnded { _ in dragOffset = .zero }
        )
    }

    private var dictationButton: some View {
        Image(systemName: "plus")
            .font(.title2)
            .foregroundColor(.white)
            .padding()
            .background(Circle().fill(Color.blue))
            // Двигаем кнопку в соответствии с свайпом
            .offset(x: min(dragOffset.width, 0))
            .opacity(cancelSwipeProgress)
            .scaleEffect(showDictationButton ? 1.25 : 0.4)
            .scaleEffect(0.85 + 0.15 * cancelSwipeProgress)
            .animation(
                .interpolatingSpring(stiffness: 170, damping: 11)
                    .speed(1.2),
                value: showDictationButton
            )
            .animation(.easeInOut(duration: 0.2), value: cancelSwipeProgress)
            .padding(.trailing, 24)
            .padding(.bottom,   34)
            .onTapGesture {
                speechRecognizer.stopRecording { rawText in
                    let draft = parseDictation(rawText)
                    dictationDraft = draft
                    isLongPressing = false
                }

            }
    }

    private func handlePressing(_ pressing: Bool) {
        withAnimation(.easeInOut(duration: 0.1)) { isPlusPressed = pressing }

        if pressing {
            longPressTimer?.invalidate()
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5,
                                                  repeats: false) { _ in
                isLongPressing = true
                speechRecognizer.startRecording()
                didLongPress = true
                
            }
        } else {
            longPressTimer?.invalidate()
            longPressTimer = nil
            if isLongPressing {
                speechRecognizer.stopRecording { rawText in
                    if !isCancelledBySwipe {
                        let draft = parseDictation(rawText)
                        dictationDraft = draft
                    }
                    isLongPressing = false
                    didLongPress = false

                }

            }
        }
    }
    
    var filteredPinnedEvents: [Event] {
        filterEvents(events: pinnedEvents)
    }
    
    var filteredUnpinnedEvents: [Event] {
        filterEvents(events: sortedUnpinnedEvents)
    }
    
    var filteredBirthdays: [Event] {
        filterEvents(events: sortedBirthdays)
    }
    
    //для swift data
    private func setupEventCleanupTimer() {
        eventCleanupTimer?.invalidate()
        eventCleanupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            EventManager.shared.deletePastEventsHandler(modelContext: modelContext)
        }
    }

    
    //лайв активити
  
    
    
    
    private func startLiveActivityIfNeeded() {
        EventManager.shared.updateLiveActivity()
    }




    
    
    func filterEvents(events: [Event]) -> [Event] {
        var filtered = events
        
        switch selectedFilter {
        case .birthdays:
            filtered = filtered.filter { $0.eventType == .birthday }
        case .events:
            filtered = filtered.filter { $0.eventType == .event }
        case .all:
            break
        }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // MARK: — закреплённые
    private var pinnedEvents: [Event] {
        allEvents
            .filter(\.isPinned)
            .sorted { $0.date < $1.date }           // ближайшие вперёд
    }

    // MARK: — незакреплённые события
    private var sortedUnpinnedEvents: [Event] {
        asEvents
            .filter { !$0.isPinned }
            .sorted { $0.date < $1.date }
    }

    // MARK: — незакреплённые дни рождения
    private var sortedBirthdays: [Event] {
        asBirthdays
            .filter { !$0.isPinned }
            .sorted { $0.date < $1.date }
    }

    
}



// MARK: - Пульсирующий плюс

/// Пульсирующая иконка «+» с синим свечением.
struct PulsatingPlusIcon: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Синий «фонарь»/свечение позади иконки
            Circle()
                .fill(Color.blue.opacity(0.4))
            // Лёгкое масштабирование, чтобы свечение немного «дышало» вместе с иконкой
                .scaleEffect(animate ? 1.2 : 1.0)
            // Блюр для мягкого рассеивания
                .blur(radius: 20)
            // Мягкое изменение прозрачности
                .opacity(animate ? 0.3 : 0.1)
                .animation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                    value: animate
                )
            
            // Собственно иконка «плюс»
            Image(systemName: "plus")
                .font(.title2)
            // Плавно пульсирует (масштаб/прозрачность)
                .scaleEffect(animate ? 1.2 : 1.0)
                .opacity(animate ? 1.0 : 0.8)
            // Дополнительная лёгкая тень/свечение от иконки
                .shadow(color: Color.blue.opacity(0.3), radius: animate ? 10 : 5, x: 0, y: 0)
                .animation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                    value: animate
                )
        }
        .frame(width: 44, height: 44) // При необходимости можно задать явный размер
        .onAppear {
            // Запускаем анимацию
            animate = true
        }
    }
}

struct CalendarView: View {
    @Binding var selectedDate: Date
    let events: [Event]
    let birthdays: [Event]
    @Environment(\.locale) var locale
    
    private var calendar: Calendar {
        var calendar = Calendar.current
        // Для арабского языка неделя начинается с воскресенья (1), для остальных – с понедельника (2)
        calendar.firstWeekday = locale.languageCode == "ar" ? 1 : 2
        return calendar
    }
    
    private var displayedMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: currentDate).capitalized
    }
    
    @State private var currentDate = Date()
    
    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: currentDate) else { return [] }
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentDate))!
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: firstDay) }
    }
    
    private var paddingDays: Int {
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentDate))!
        let weekday = calendar.component(.weekday, from: firstDay)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
    
    var body: some View {
        VStack {
            // Заголовок с месяцем и кнопками навигации
            HStack {
                Button(action: {
                    currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate)!
                }) {
                    Image(systemName: locale.languageCode == "ar" ? "chevron.right" : "chevron.left")
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(displayedMonth)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
                }) {
                    Image(systemName: locale.languageCode == "ar" ? "chevron.left" : "chevron.right")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            // Ряд с заголовками дней недели
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbolsStartingFromLocale().enumerated()), id: \.offset) { index, weekday in
                    // Для не-арабской локали (неделя начинается с понедельника):
                    // если индекс равен 5 или 6 (соответственно суббота и воскресенье),
                    // то текст делаем белым, обычным (без жирности) и без прозрачности.
                    let isWeekend = locale.languageCode != "ar" && (index == 5 || index == 6)
                    
                    Text(weekday)
                        .font(.subheadline)
                        .foregroundColor(isWeekend ? .white : .gray)
                        .fontWeight(isWeekend ? .regular : .thin)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .opacity(1.0)
                }
            }
            // Принудительно задаём направление left-to-right для заголовка
            .environment(\.layoutDirection, .leftToRight)
            .padding(.bottom, -4)
            .padding(.horizontal, -16)
            
            // Сетка с днями месяца
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                spacing: 6
            ) {
                // Пустые ячейки для выравнивания первого дня месяца
                ForEach(0..<paddingDays, id: \.self) { _ in
                    Text("")
                }
                ForEach(daysInMonth, id: \.self) { day in
                    DayView(
                        date: day,
                        events: eventsForDay(day),
                        birthdays: birthdaysForDay(day),
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDate)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        selectedDate = day
                    }
                }
            }
            // Принудительно задаём направление left-to-right для сетки с датами
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, -16)
        }
    }
    
    // Функция для получения символов дней недели с учётом локали
    private func weekdaySymbolsStartingFromLocale() -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        if locale.languageCode == "ar" {
            // Для арабской локали используем исходный порядок: воскресенье, понедельник, вторник, …, суббота.
            return symbols
        } else {
            // Для остальных локалей, когда неделя начинается с понедельника
            var modifiedSymbols = symbols
            let firstHalf = modifiedSymbols[0..<calendar.firstWeekday - 1]
            modifiedSymbols.removeSubrange(0..<calendar.firstWeekday - 1)
            modifiedSymbols.append(contentsOf: firstHalf)
            return modifiedSymbols
        }
    }
    
    private func eventsForDay(_ day: Date) -> [Event] {
        events.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }
    
    private func birthdaysForDay(_ day: Date) -> [Event] {
        birthdays.filter {
            let bd = calendar.dateComponents([.month, .day], from: $0.date)
            let dd = calendar.dateComponents([.month, .day], from: day)
            return bd.month == dd.month && bd.day == dd.day
        }
    }
}


struct DayView: View {
    let date: Date
    let events: [Event]
    let birthdays: [Event]
    let isSelected: Bool
    
    @Environment(\.locale) var locale
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    /// Вычисляем эффективный цвет текста для не-арабских локалей:
    /// Если выбран или выходной, то белый; если текущий, то синий; иначе primary.
    private var effectiveTextColor: Color {
        if locale.languageCode == "ar" {
            return textColor
        } else {
            let cal = Calendar(identifier: .gregorian)
            let weekday = cal.component(.weekday, from: date)
            let isWeekend = (weekday == 1 || weekday == 7) // воскресенье = 1, суббота = 7
            if isSelected {
                return .white
            } else if isWeekend {
                return .white
            } else if isToday {
                return .blue
            } else {
                return .primary
            }
        }
    }
    
    /// Вычисляем непрозрачность (opacity) для не-арабских локалей:
    /// Если выбран, текущий или выходной — 1.0, для остальных будних — 0.6.
    private var effectiveOpacity: Double {
        if locale.languageCode == "ar" {
            return 1.0
        } else {
            let cal = Calendar(identifier: .gregorian)
            let weekday = cal.component(.weekday, from: date)
            let isWeekend = (weekday == 1 || weekday == 7)
            if isSelected {
                return 1.0
            } else if isToday {
                return 1.0
            } else if isWeekend {
                return 1.0
            } else {
                return 0.6
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Фоновый круг (подсветка выбранного или текущего дня)
            ZStack {
                if isToday && isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 30, height: 30)
                } else if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 30, height: 30)
                }
                
                // Отображение цифры дня
                Group {
                    if locale.languageCode == "ar" {
                        // Для арабской локали стандартное оформление
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: isToday ? 18 : 16))
                            .fontWeight(isToday ? .bold : .regular)
                            .foregroundColor(textColor)
                            .multilineTextAlignment(.center)
                            .opacity(1.0)
                    } else {
                        // Для остальных локалей используем вычисленные effectiveTextColor и effectiveOpacity
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: isToday ? 18 : 16))
                            .fontWeight(isToday ? .bold : .regular)
                            .foregroundColor(effectiveTextColor)
                            .multilineTextAlignment(.center)
                            .opacity(effectiveOpacity)
                    }
                }
            }
            
            // Индикаторы событий и дней рождений
            ZStack {
                if !events.isEmpty {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 4, height: 4)
                        .offset(y: -12)
                        .opacity(isSelected ? 0 : 1)
                        .animation(.easeInOut(duration: 0.3), value: isSelected)
                }
                if !birthdays.isEmpty {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 4, height: 4)
                        .offset(y: -12)
                        .opacity(isSelected ? 0 : 1)
                        .animation(.easeInOut(duration: 0.3), value: isSelected)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Используемая логика для арабской локали (без изменений)
    var textColor: Color {
        if isToday && isSelected {
            return .white
        } else if isToday && !isSelected {
            return .blue
        } else if isSelected {
            return .white
        } else {
            return .primary
        }
    }
}



struct SideBarMenuView: View {
    let safeArea: UIEdgeInsets
    @Binding var selectedDate: Date
    @Binding var dictationDraft: DictationDraft?
    @Binding var showingSettingsSheet: Bool
    @Binding var isCreatingEventFromSidebar: Bool
    @EnvironmentObject var eventManager: EventManager

    @State private var selectedEventForEditing: Event?
    @State private var displayPaywall = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // ⚙️ Кнопка настроек
            HStack {
                Button(action: {
                    showingSettingsSheet = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .padding(10)
                }
                Spacer()
            }
            .padding(.top, 40)

            VStack(alignment: .center, spacing: -10) {
                Text("\(Calendar.current.component(.day, from: selectedDate))")
                    .font(.system(size: 100, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(localizedWeekday(from: selectedDate))
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 15)
            .padding(.top, -40)

            CalendarView(selectedDate: $selectedDate, events: eventManager.events, birthdays: eventManager.birthdays)
                .padding(.horizontal, 15)
                .frame(maxWidth: .infinity)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(LocalizedStringKey("events_section_header"))
                            .font(.system(size: 14))
                            .foregroundColor(Color.gray.opacity(0.5))
                            .padding(.horizontal, 15)
                        Spacer()
                    }

                    ForEach(eventsForSelectedDate(selectedDate)) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(eventTimeText(for: event.date))
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.leading, 15)

                            Button(action: {
                                selectedEventForEditing = event
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(event.emoji)
                                            .font(.system(size: 18))
                                        Text(event.name)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if event.notificationEnabled {
                                            Image(systemName: "bell.fill")
                                                .resizable()
                                                .frame(width: 12, height: 12)
                                                .foregroundColor(.yellow)
                                        }
                                    }

                                    if let note = event.note, !note.isEmpty {
                                        Text(note)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }

                                    if !event.checklist.isEmpty {
                                        VStack(alignment: .leading, spacing: 2) {
                                            ForEach(event.checklist, id: \.id) { item in
                                                HStack {
                                                    Button(action: {
                                                        toggleChecklistItemCompletion(event: event, item: item)
                                                    }) {
                                                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                                            .foregroundColor(item.isCompleted ? .green : .gray)
                                                    }
                                                    .buttonStyle(PlainButtonStyle())

                                                    Text(item.text)
                                                        .strikethrough(item.isCompleted, color: .gray)
                                                        .foregroundColor(item.isCompleted ? .gray : .primary)
                                                        .font(.caption2)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 15)
                        }
                    }
                }
                .padding(.top, 0)
                .background(Color(.systemBackground))
            }

            Spacer()

            HStack {
                Button(action: {
                    if eventManager.subscriptionIsActive {
                        isCreatingEventFromSidebar = true
                        dictationDraft = DictationDraft(title: "", date: selectedDate, note: "", hasTime: true)
                    } else {
                        checkSubscriptionBeforeAddingEventFromSidebar()
                    }
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        Text(LocalizedStringKey("add_event_button_title"))
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, safeArea.bottom + 10)
        }
        .frame(width: 310)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
        .environment(\.colorScheme, .dark)

        // 🟡 Встроенные sheets
        .sheet(item: $selectedEventForEditing) { event in
            let eventIndex = findEventIndex(for: event)
            EditEventView(event: event, eventType: event.eventType, eventIndex: eventIndex)
                .environmentObject(eventManager)
        }

        .sheet(isPresented: $showingSettingsSheet) {
            SettingsSheetView()
                .environmentObject(eventManager)
        }
        
        .sheet(isPresented: $displayPaywall) {
            PaywallView()
                .environmentObject(eventManager)
        }
    }

    private func localizedWeekday(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale.current
        return formatter.string(from: date).capitalized
    }

    private func eventsForSelectedDate(_ date: Date) -> [Event] {
        let calendar = Calendar.current
        let events = eventManager.events.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let birthdays = eventManager.birthdays.filter { birthday in
            let birthdayComponents = calendar.dateComponents([.day, .month], from: birthday.date)
            let selectedDateComponents = calendar.dateComponents([.day, .month], from: date)
            return birthdayComponents.day == selectedDateComponents.day &&
                   birthdayComponents.month == selectedDateComponents.month
        }
        return events + birthdays
    }

    private func findEventIndex(for event: Event) -> Int {
        switch event.eventType {
        case .event:
            return eventManager.events.firstIndex(where: { $0.id == event.id }) ?? -1
        case .birthday:
            return eventManager.birthdays.firstIndex(where: { $0.id == event.id }) ?? -1
        }
    }

    private func eventTimeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func checkSubscriptionBeforeAddingEventFromSidebar() {
        if eventManager.subscriptionIsActive {
            dictationDraft = DictationDraft(title: "", date: selectedDate, note: "", hasTime: true)
            displayPaywall = false
            return
        }
        
        eventManager.checkSubscriptionStatus {
            DispatchQueue.main.async {
                if !eventManager.canAddEvent(ofType: .event) {
                    displayPaywall = true
                    dictationDraft = nil
                } else {
                    displayPaywall = false
                    dictationDraft = DictationDraft(title: "", date: selectedDate, note: "", hasTime: true)
                }
            }
        }
    }

    private func toggleChecklistItemCompletion(event: Event, item: ChecklistItem) {
        var updatedEvent = event

        if let itemIndex = updatedEvent.checklist.firstIndex(where: { $0.id == item.id }) {
            updatedEvent.checklist[itemIndex].isCompleted.toggle()
            eventManager.updateEvent(updatedEvent, eventType: updatedEvent.eventType)
            generateFeedback()
        }
    }

    private func generateFeedback() {
        HapticManager.shared.impact(style: .medium)
    }
}






struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    
    class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        
        init(text: Binding<String>) {
            _text = text
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text)
    }
    
    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text
    }
}


private func deleteAction(_ event: Event, eventType: EventType, modelContext: ModelContext) -> some View {
    Button(role: .destructive) {
        EventManager.shared.deleteEvent(event, eventType: eventType, modelContext: modelContext)
    } label: {
        Label("Удалить", systemImage: "trash")
    }
    .tint(.red)
}

private func pinUnpinAction(_ event: Event) -> some View {
    Button {
        if event.isPinned {
            EventManager.shared.unpinEvent(event, eventType: event.eventType)
        } else {
            EventManager.shared.pinEvent(event, eventType: event.eventType)
        }
    } label: {
        Label(event.isPinned ? "Открепить" : "Закрепить", systemImage: event.isPinned ? "pin.slash.fill" : "pin.fill")
    }
    .tint(event.isPinned ? .blue : .green)
}

struct EventRow: View {
    let event: Event
    @EnvironmentObject var eventManager: EventManager
    
    var body: some View {
        HStack {
            Text(event.emoji)
                .font(.system(size: 45))
                .padding(.trailing, 4)
            VStack(alignment: .leading) {
                HStack {
                    Text(event.name)
                        .foregroundColor(.black) // Оставляем черный цвет текста
                    Spacer()
                    if event.notificationEnabled {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.yellow)
                    }
                }
                Text(eventDateText(for: event.date))
                    .font(.subheadline)
                    .foregroundColor(.black) // Оставляем черный цвет текста
                if event.showCountdown {
                    CountdownView(event: event)
                }
                if let note = event.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(event.isToday ? Color.white : Color.clear)
        .cornerRadius(8)
    }
    
    private func eventDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        
        if event.eventType == .birthday {
            // Для дней рождения отображаем только дату
            formatter.dateFormat = "dd MMMM yyyy"
            return formatter.string(from: date) + (event.age != nil ? "; возраст: \(event.age!)" : "")
        } else {
            // Для остальных событий отображаем дату и время
            formatter.dateFormat = "dd MMMM yyyy"
            return formatter.string(from: date)
        }
    }
    
}




struct CountdownView: View {
    @EnvironmentObject var eventManager: EventManager
    
    let event: Event
    @State private var timer: Timer?
    @State private var countdownText: String = ""
    
    var body: some View {
        Text(countdownText)
            .onAppear {
                setupTimer()
            }
            .onDisappear {
                timer?.invalidate()
            }
    }
    
    private func setupTimer() {
        // Устанавливаем таймер с интервалом в одну минуту
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            updateCountdown()
        }
        updateCountdown()
    }
    
    private func updateCountdown() {
        let now = Date()
        let calendar = Calendar.current
        var targetDate = event.date
        
        // Если событие день рождения, корректируем целевую дату
        if event.eventType == .birthday {
            let currentYear = calendar.component(.year, from: now)
            var targetComponents = calendar.dateComponents([.month, .day], from: event.date)
            targetComponents.year = currentYear
            targetDate = calendar.date(from: targetComponents) ?? event.date
            if targetDate < now {
                targetComponents.year = currentYear + 1
                targetDate = calendar.date(from: targetComponents) ?? event.date
            }
        }
        
        let diffComponents = calendar.dateComponents([.day, .hour, .minute], from: now, to: targetDate)
        let isEventPassed = targetDate < now
        
        if let days = diffComponents.day, let hours = diffComponents.hour, let minutes = diffComponents.minute {
            if isEventPassed {
                countdownText = "С момента события прошло: \(abs(days))д \(abs(hours))ч \(abs(minutes))м"
            } else {
                countdownText = "До события: \(days)д \(hours)ч \(minutes)м"
            }
        }
    }
}

// настройки

import SwiftUI
import UserNotifications

struct SettingsSheetView: View {
    @EnvironmentObject var eventManager: EventManager
    @State private var showingFeedbackView = false
    @State private var showingSubscriptionView = false
    @Environment(\.presentationMode) var presentationMode

    let privacyPolicyURL = URL(string: "https://mpbdigital.tech/privacy_police")!

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    Section(header: Text(NSLocalizedString("SETTINGS_SUBSCRIPTION_HEADER", comment: ""))) {
                        HStack {
                            Text(NSLocalizedString("SETTINGS_SUBSCRIPTION_CURRENT_STATUS", comment: ""))
                            Spacer()
                            Text(eventManager.subscriptionIsActive
                                 ? NSLocalizedString("SETTINGS_SUBSCRIPTION_ACTIVE", comment: "")
                                 : NSLocalizedString("SETTINGS_SUBSCRIPTION_INACTIVE", comment: ""))
                                .foregroundColor(eventManager.subscriptionIsActive ? .green : .red)
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: eventManager.subscriptionIsActive ? "infinity" : "info.circle.fill")
                                .foregroundColor(.orange)
                            Text(eventManager.subscriptionIsActive ?
                                 LocalizedStringKey("SETTINGS_SUBSCRIPTION_UNLIMITED_INFO") :
                                 LocalizedStringKey("SETTINGS_SUBSCRIPTION_LIMITS_INFO"))
                                .font(.footnote)
                        }

                        if !eventManager.subscriptionIsActive {
                            Button(action: {
                                showingSubscriptionView = true
                            }) {
                                Text(NSLocalizedString("SETTINGS_SUBSCRIPTION_BUY_BUTTON", comment: ""))
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    Section(header: Text(NSLocalizedString("SETTINGS_NOTIFICATIONS_HEADER", comment: ""))) {
                        HStack {
                            Text(NSLocalizedString("SETTINGS_NOTIFICATIONS_PERMISSION", comment: ""))
                            Spacer()
                            if eventManager.notificationsPermissionGranted {
                                Text(NSLocalizedString("SETTINGS_NOTIFICATIONS_GRANTED", comment: ""))
                                    .foregroundColor(.green)
                            } else {
                                Button(action: {
                                    requestNotificationPermission()
                                }) {
                                    Text(NSLocalizedString("SETTINGS_NOTIFICATIONS_ALLOW_BUTTON", comment: ""))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        if !eventManager.notificationsPermissionGranted {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                Text(LocalizedStringKey("SETTINGS_NOTIFICATIONS_PERMISSION_INFO"))
                                    .font(.footnote)
                            }
                        }
                    }

                    Section(header: Text("Микрофон")) {
                        HStack {
                            Text(NSLocalizedString("SETTINGS_MICROPHONE_PERMISSION", comment: ""))
                            Spacer()
                            if eventManager.microphonePermissionGranted {
                                Text(NSLocalizedString("SETTINGS_MICROPHONE_GRANTED", comment: ""))
                                    .foregroundColor(.green)
                            } else {
                                Button(action: {
                                    requestMicrophonePermission()
                                }) {
                                    Text(NSLocalizedString("SETTINGS_MICROPHONE_ALLOW_BUTTON", comment: ""))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        if !eventManager.microphonePermissionGranted {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                Text(LocalizedStringKey("SETTINGS_MICROPHONE_PERMISSION_INFO"))
                                    .font(.footnote)
                            }
                        }
                    }

                    Section(header: Text(NSLocalizedString("SETTINGS_FEEDBACK_HEADER", comment: ""))) {
                        Button(action: {
                            showingFeedbackView = true
                        }) {
                            Text(NSLocalizedString("SETTINGS_FEEDBACK_SEND_BUTTON", comment: ""))
                        }
                    }
                }

                // Нижние ссылки — локализованные
                VStack(spacing: 6) {
                    Link(NSLocalizedString("SETTINGS_PRIVACY_POLICY", comment: ""), destination: privacyPolicyURL)
                    Link(NSLocalizedString("SETTINGS_TERMS_OF_USE", comment: ""), destination: privacyPolicyURL)
                }
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(Color.gray.opacity(0.6))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemGroupedBackground))
            }
            .navigationTitle("")
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            )
            .sheet(isPresented: $showingFeedbackView) {
                FeedbackView()
            }
            .sheet(isPresented: $showingSubscriptionView, onDismiss: {
                          eventManager.checkSubscriptionStatus {}
                      }) {
                PaywallView(displayCloseButton: true)
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                eventManager.updateNotificationsPermission(granted: granted)
            }
        }
    }

    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                eventManager.updateMicrophonePermission(granted: granted)
            }
        }
    }
}




struct FeedbackView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var feedbackText = ""
    @State private var userEmail = ""
    @State private var showAlert = false
    @State private var showConfirmation = false 
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    Section(header: Text("Ваш Email")) {
                        TextField("example@mail.com", text: $userEmail)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }

                    Section(header: Text("Обратная связь")) {
                        TextEditor(text: $feedbackText)
                            .frame(height: 200)
                    }

                    Button(NSLocalizedString("FEEDBACK_SEND_BUTTON", comment: "")) {
                        if validateEmail(userEmail) {
                            showConfirmation = true
                        } else {
                            alertMessage = "Пожалуйста, введите корректный email для ответа."
                            showAlert = true
                        }
                    }
                    .alert(NSLocalizedString("FEEDBACK_CONFIRM_TITLE", comment: ""), isPresented: $showConfirmation) {
                        Button(NSLocalizedString("FEEDBACK_SEND_BUTTON", comment: "")) {
                            sendFeedbackToTelegram(feedback: feedbackText, email: userEmail)
                            presentationMode.wrappedValue.dismiss()
                        }
                        Button(NSLocalizedString("FEEDBACK_CANCEL_BUTTON", comment: ""), role: .cancel) {}
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                    Text(NSLocalizedString("FEEDBACK_TELEGRAM_INFO", comment: ""))
                }
                .font(.footnote)
                .foregroundColor(Color.gray.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
                .background(Color.clear)
            }
            .navigationTitle("Отзыв")
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
            })
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Ошибка"), message: Text(alertMessage), dismissButton: .default(Text("ОК")))
            }
        }
    }

    func validateEmail(_ email: String) -> Bool {
        // Простая проверка: наличие "@" и "."
        return email.contains("@") && email.contains(".")
    }

    func sendFeedbackToTelegram(feedback: String, email: String) {
        let token = "7626244847:AAHxF9gA7dh1VWsRJvR2VwlRx6DGnJyqV90"
        let chatID = "743851714"
        let text = """
        📬 Новый отзыв:

        ✉️ Email: \(email)
        💬 Отзыв: \(feedback)
        """

        let urlString = "https://api.telegram.org/bot\(token)/sendMessage"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = "chat_id=\(chatID)&text=\(encodedText)"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Ошибка: \(error.localizedDescription)")
            } else {
                print("✅ Отзыв отправлен в Telegram")
            }
        }.resume()
    }
}




// Генерация тактильного отклика
func generateFeedback() {
    HapticManager.shared.impact(style: .medium)
}

struct OnboardingView: View {
    @Binding var currentStep: Int
    
    var body: some View {
        VStack {
            // Пример формата "Онбординг шаг X"
            Text(String(format: NSLocalizedString("ONBOARDING_STEP_TITLE", comment: ""), currentStep + 1))
                .font(.largeTitle)
                .padding()
            
            Spacer()
            
            Button(action: {
                currentStep += 1
            }) {
                Text(NSLocalizedString("ONBOARDING_STEP_CONTINUE", comment: "")) // "Продолжить"
                    .font(.title2)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}


struct OnboardingContainerView: View {
    // Ссылка на значение, которым управляет родительский View
    @Binding var isOnboardingCompleted: Bool

    // Локальный счётчик шага онбординга
    @State private var currentStep = 0
    @EnvironmentObject private var manager: EventManager

    var body: some View {
        VStack {
            if currentStep < 6 {
                VStack {
                    HStack {
                        Button(action: {
                            // При нажатии на кнопку «✕» считаем,
                            // что онбординг пропущен/прерван
                            // 1) уведомляем родителя
                            isOnboardingCompleted = true
                            // 2) сохраняем, что первый запуск уже не активен
                            manager.completeFirstLaunch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                        .padding()
                        Spacer()
                    }
                    OnboardingView(currentStep: $currentStep)
                }
            } else {
                EventsListView()
                    .environmentObject(EventManager.shared)
                    .onAppear {
                        // Когда дошли до последнего шага и показываем список событий:
                        // 1) помечаем, что онбординг завершён
                        manager.settings?.isOnboardingCompleted = true
                        // 2) передаём это состояние вверх
                        isOnboardingCompleted = true
                    }
            }
        }
    }
}


//Новый корневой контейнер

struct RootContainer: View {

    @EnvironmentObject private var manager: EventManager      // получаем тот же объект
    @Environment(\.modelContext) private var modelContext     // здесь контекст уже гарантированно есть

    var body: some View {
        Group {
            if let firstLaunch = manager.settings?.isFirstLaunch {
                if firstLaunch {
                    WelcomeScreenView()
                } else {
                    EventsListView()
                }
            } else {
                Color.clear
            }
        }
        .onAppear {
            // вызывается сразу на старте и при возвращении из бэкграунда
            manager.configure(modelContext: modelContext)
        }
    }
}





@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // один‐единственный экземпляр менеджера
    @StateObject private var manager = EventManager.shared

    init() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Constants.apiKey)
    }

    var body: some Scene {
        WindowGroup {
            // — Помещаем основное содержимое в RootContainer —
            RootContainer()
                .environmentObject(manager)           // ← инъекция как и было
        }
        // контейнер на WindowGroup, как и прежде
        .modelContainer(sharedContainer)
    }

    private var sharedContainer: ModelContainer = {
        let schema = Schema([EventModel.self, ChecklistItemModel.self, SettingsModel.self])
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mpb.momenttimer") else {
            print("⚠️ Failed to locate app group container. Using default location.")
            if let container = try? ModelContainer(for: schema) {
                return container
            }
            fatalError("Unable to create SwiftData container")
        }
        print("[ContentView] container path: \(url.path)")
        let storeURL = url.appendingPathComponent("Events.store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        } else {
            print("⚠️ Failed to load SwiftData container. Falling back to default.")
            if let fallback = try? ModelContainer(for: schema) {
                return fallback
            }
            fatalError("Unable to create SwiftData container")
        }
    }()
}



class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        _ = PhoneConnectivityManager.shared
        EventManager.shared.checkSubscriptionStatus {}
        
        let stopAction = UNNotificationAction(identifier: "STOP_ACTION", title: "Остановить", options: .foreground)
        let category = UNNotificationCategory(identifier: "EVENT_REMINDER", actions: [stopAction], intentIdentifiers: [], options: .customDismissAction)
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = self
        
        EventManager.shared.removeNotificationsForDeletedEvents()
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        EventManager.shared.saveAndReload()
    }
 
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "STOP_ACTION" {
            print("Уведомление остановлено пользователем.")
        }
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

/// Помощник, чтобы дергать системный Taptic Engine
func lightHaptic() {
    let gen = UIImpactFeedbackGenerator(style: .light)
    gen.prepare()
    gen.impactOccurred()
}


