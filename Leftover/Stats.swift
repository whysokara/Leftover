//
//  Stats.swift
//  Leftover
//
//  Persistent counters and the streak/freeze engine.
//  Values mirror into the App Group suite so the widget can read them.
//

import Foundation

final class Stats: ObservableObject {
    static let appGroupID = "group.com.kara.leftover"

    private let defaults = UserDefaults.standard
    private let shared = UserDefaults(suiteName: Stats.appGroupID)

    @Published var lifetimeFreedBytes: Int64
    @Published var lifetimeTossedCount: Int
    @Published var streakCount: Int
    @Published var freezes: Int
    @Published var lastCompletedDay: String   // "yyyy-MM-dd", "" if never
    @Published var burstCompletedDay: String  // day the last burst finished
    @Published var freezeJustEarned = false
    @Published var streakJustIncremented = false

    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: "hasLaunchedBefore") }
        set { defaults.set(newValue, forKey: "hasLaunchedBefore") }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() {
        lifetimeFreedBytes = Int64(defaults.integer(forKey: "lifetimeFreedBytes"))
        lifetimeTossedCount = defaults.integer(forKey: "lifetimeTossedCount")
        streakCount = defaults.integer(forKey: "streakCount")
        freezes = defaults.integer(forKey: "freezes")
        lastCompletedDay = defaults.string(forKey: "lastCompletedDay") ?? ""
        burstCompletedDay = defaults.string(forKey: "burstCompletedDay") ?? ""
    }

    var isBurstDoneToday: Bool {
        burstCompletedDay == Stats.dayFormatter.string(from: Date())
    }

    func recordDelete(count: Int, freed: Int64) {
        lifetimeTossedCount += count
        lifetimeFreedBytes += max(0, freed)
        persist()
    }

    /// Marks today's burst complete and advances the streak.
    /// Gap of one day continues the streak; longer gaps consume freezes
    /// (one per missed day) before resetting. Every 7th consecutive day
    /// earns a freeze, capped at 3.
    func completeBurst() {
        let today = Stats.dayFormatter.string(from: Date())
        guard burstCompletedDay != today else { return }
        burstCompletedDay = today
        freezeJustEarned = false
        streakJustIncremented = false

        let gap = daysBetween(lastCompletedDay, and: today)
        switch gap {
        case nil:
            streakCount = 1
        case 0:
            break // already counted today via another path
        case 1:
            streakCount += 1
            streakJustIncremented = true
        default:
            let missed = gap! - 1
            if missed <= freezes {
                freezes -= missed
                streakCount += 1
                streakJustIncremented = true
            } else {
                streakCount = 1
            }
        }

        if streakCount > 0 && streakCount % 7 == 0 && freezes < 3 {
            freezes += 1
            freezeJustEarned = true
        }
        lastCompletedDay = today
        persist()
    }

    private func daysBetween(_ from: String, and to: String) -> Int? {
        guard !from.isEmpty,
              let fromDate = Stats.dayFormatter.date(from: from),
              let toDate = Stats.dayFormatter.date(from: to) else { return nil }
        return Calendar.current.dateComponents([.day], from: fromDate, to: toDate).day
    }

    private func persist() {
        defaults.set(Int(lifetimeFreedBytes), forKey: "lifetimeFreedBytes")
        defaults.set(lifetimeTossedCount, forKey: "lifetimeTossedCount")
        defaults.set(streakCount, forKey: "streakCount")
        defaults.set(freezes, forKey: "freezes")
        defaults.set(lastCompletedDay, forKey: "lastCompletedDay")
        defaults.set(burstCompletedDay, forKey: "burstCompletedDay")

        // Mirror for the widget (no-op until the App Group exists).
        shared?.set(streakCount, forKey: "streakCount")
        shared?.set(Int(lifetimeFreedBytes), forKey: "lifetimeFreedBytes")
        shared?.set(burstCompletedDay, forKey: "burstCompletedDay")
    }
}
