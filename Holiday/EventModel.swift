//
//  EventModel.swift
//  Holiday
//
//  Created by Павел Пушкин on 12.06.2025.
//

import Foundation
import SwiftData

@Model
class EventModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var date: Date
    var creationDate: Date
    var showCountdown: Bool = true
    var eventType: EventType
    var isPinned: Bool
    var originalIndex: Int?
    var emoji: String
    var note: String?

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItemModel.event)
    var checklist: [ChecklistItemModel] = []

    var notificationType: NotificationType
    var notificationEnabled: Bool
    var notificationTime: Date?
    var deletePastEvents: Bool
    var lastModified: Date = Date()
    var notificationDaysOfWeek: [DayOfWeek]
    var notificationMonths: [Month]
    var repeatInterval: RepeatInterval
    var repeatMonthly: Bool
    var repeatYearly: Bool
    var bellActivated: Bool
    var isFromWatch: Bool = false
    var isNewlyCreated: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        date: Date,
        creationDate: Date = Date(),
        showCountdown: Bool = true,
        eventType: EventType,
        isPinned: Bool = false,
        originalIndex: Int? = nil,
        emoji: String,
        note: String? = nil,
        checklist: [ChecklistItemModel] = [],
        notificationType: NotificationType = .message,
        notificationEnabled: Bool = true,
        notificationTime: Date? = nil,
        deletePastEvents: Bool = false,
        lastModified: Date = Date(),
        notificationDaysOfWeek: [DayOfWeek] = [],
        notificationMonths: [Month] = [],
        repeatInterval: RepeatInterval = .none,
        repeatMonthly: Bool = false,
        repeatYearly: Bool,
        bellActivated: Bool = false,
        isFromWatch: Bool = false,
        isNewlyCreated: Bool = false
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.creationDate = creationDate
        self.showCountdown = showCountdown
        self.eventType = eventType
        self.isPinned = isPinned
        self.originalIndex = originalIndex
        self.emoji = emoji
        self.note = note
        self.checklist = checklist
        self.notificationType = notificationType
        self.notificationEnabled = notificationEnabled
        self.notificationTime = notificationTime
        self.deletePastEvents = deletePastEvents
        self.lastModified = lastModified
        self.notificationDaysOfWeek = notificationDaysOfWeek
        self.notificationMonths = notificationMonths
        self.repeatInterval = repeatInterval
        self.repeatMonthly = repeatMonthly
        self.repeatYearly = repeatYearly
        self.bellActivated = bellActivated
        self.isFromWatch = isFromWatch
        self.isNewlyCreated = isNewlyCreated
    }
}
