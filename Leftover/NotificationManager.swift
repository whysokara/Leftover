//
//  NotificationManager.swift
//  Leftover
//
//  One gentle nudge a day, only if today's burst isn't done.
//  No repeating triggers: we always schedule exactly one notification
//  for the next day that still needs a burst.
//

import Foundation
import UserNotifications

final class NotificationManager: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var reminderEnabled: Bool {
        didSet { defaults.set(reminderEnabled, forKey: "reminderEnabled") }
    }
    @Published var reminderHour: Int {
        didSet { defaults.set(reminderHour, forKey: "reminderHour") }
    }
    @Published var reminderMinute: Int {
        didSet { defaults.set(reminderMinute, forKey: "reminderMinute") }
    }
    @Published var authDenied = false

    /// Set by ContentView before rescheduling: a peek at what's waiting
    /// ("3 photos from July 2019") and a streak worth protecting (≥ 3).
    var burstTeaser: String? = nil
    var streakToProtect: Int = 0

    init() {
        reminderEnabled = defaults.bool(forKey: "reminderEnabled")
        reminderHour = defaults.object(forKey: "reminderHour") as? Int ?? 19
        reminderMinute = defaults.object(forKey: "reminderMinute") as? Int ?? 0
    }

    var reminderTime: Date {
        get {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date()
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = comps.hour ?? 19
            reminderMinute = comps.minute ?? 0
        }
    }

    func setEnabled(_ enabled: Bool, burstDoneToday: Bool) {
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    self.authDenied = !granted
                    self.reminderEnabled = granted
                    if granted {
                        self.reschedule(burstDoneToday: burstDoneToday)
                    }
                }
            }
        } else {
            reminderEnabled = false
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }

    /// Replaces any pending reminder with one for the next moment a nudge
    /// makes sense: today at the chosen time if the burst isn't done and the
    /// time hasn't passed, otherwise tomorrow.
    func reschedule(burstDoneToday: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard reminderEnabled else { return }

        let calendar = Calendar.current
        let now = Date()
        var fireDate = calendar.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: now) ?? now
        if fireDate <= now || burstDoneToday {
            fireDate = calendar.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }

        // Still at most one nudge a day — only the copy adapts: protect a
        // streak first, tease a memory second, generic last.
        let content = UNMutableNotificationContent()
        if streakToProtect >= 3 {
            content.title = "Day \(streakToProtect + 1) is waiting"
            content.body = "Two minutes keeps your streak alive."
        } else if let teaser = burstTeaser {
            content.title = "Your memories are waiting"
            content.body = "\(teaser). Two minutes of swiping."
        } else {
            content.title = "Time to tidy your library"
            content.body = "Two minutes of swiping keeps it clean."
        }
        content.sound = .default

        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "leftover.daily-reminder", content: content, trigger: trigger)
        center.add(request)
    }
}
