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

    /// One-shot celebration moments, consumed by ContentView.
    @Published var pendingMilestone: String? = nil
    @Published var pendingRecap: String? = nil

    private var weekTossed: Int
    private var weekFreed: Int64

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
        weekTossed = defaults.integer(forKey: "weekTossed")
        weekFreed = Int64(defaults.integer(forKey: "weekFreed"))
        pendingRecap = defaults.string(forKey: "pendingRecap")
        rolloverWeekIfNeeded()
    }

    var isBurstDoneToday: Bool {
        burstCompletedDay == Stats.dayFormatter.string(from: Date())
    }

    func recordDelete(count: Int, freed: Int64) {
        rolloverWeekIfNeeded()
        lifetimeTossedCount += count
        lifetimeFreedBytes += max(0, freed)
        weekTossed += count
        weekFreed += max(0, freed)
        checkMilestones()
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
        checkMilestones()
        persist()
    }

    // MARK: - Milestones & weekly recap

    /// Fires each threshold exactly once, biggest first. The pending one
    /// is shown by ContentView at the next natural pause.
    private func checkMilestones() {
        let gb: Int64 = 1 << 30
        let candidates: [(String, Bool)] = [
            ("10 GB freed", lifetimeFreedBytes >= 10 * gb),
            ("5 GB freed", lifetimeFreedBytes >= 5 * gb),
            ("1 GB freed", lifetimeFreedBytes >= gb),
            ("10,000 photos deleted", lifetimeTossedCount >= 10_000),
            ("1,000 photos deleted", lifetimeTossedCount >= 1_000),
            ("100 photos deleted", lifetimeTossedCount >= 100),
            ("30-day streak", streakCount >= 30),
            ("7-day streak", streakCount >= 7),
        ]
        var shown = Set(defaults.stringArray(forKey: "milestonesShown") ?? [])
        for (name, hit) in candidates where hit && !shown.contains(name) {
            shown.insert(name)
            if pendingMilestone == nil { pendingMilestone = name }
        }
        defaults.set(Array(shown), forKey: "milestonesShown")
    }

    func clearMilestone() {
        pendingMilestone = nil
    }

    /// On the first activity of a new ISO week, bank last week's numbers
    /// as a recap moment.
    private func rolloverWeekIfNeeded() {
        let key = Self.weekKey(for: Date())
        let stored = defaults.string(forKey: "weekKey")
        guard stored != key else { return }
        if stored != nil, weekTossed > 0 {
            let freedText = weekFreed > 0
                ? " · \(ByteCountFormatter.string(fromByteCount: weekFreed, countStyle: .file)) freed"
                : ""
            pendingRecap = "\(weekTossed) deleted\(freedText)"
            defaults.set(pendingRecap, forKey: "pendingRecap")
        }
        weekTossed = 0
        weekFreed = 0
        defaults.set(key, forKey: "weekKey")
        persist()
    }

    func clearRecap() {
        pendingRecap = nil
        defaults.removeObject(forKey: "pendingRecap")
    }

    private static func weekKey(for date: Date) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let week = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        return "\(year)-W\(week)"
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
        defaults.set(weekTossed, forKey: "weekTossed")
        defaults.set(Int(weekFreed), forKey: "weekFreed")

        // Mirror for the widget (no-op until the App Group exists).
        shared?.set(streakCount, forKey: "streakCount")
        shared?.set(Int(lifetimeFreedBytes), forKey: "lifetimeFreedBytes")
        shared?.set(burstCompletedDay, forKey: "burstCompletedDay")
    }
}
