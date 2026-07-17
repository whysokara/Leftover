//
//  Stats.swift
//  Leftover
//
//  Persistent counters and milestone tracking.
//  Values mirror into the App Group suite so the widget can read them.
//

import Foundation

final class Stats: ObservableObject {
    static let appGroupID = "group.com.kara.leftover"

    private let defaults = UserDefaults.standard
    private let shared = UserDefaults(suiteName: Stats.appGroupID)

    @Published var lifetimeFreedBytes: Int64
    @Published var lifetimeTossedCount: Int
    @Published var burstCompletedDay: String  // day the last burst finished

    /// One-shot celebration moments, consumed by ContentView.
    @Published var pendingMilestone: String? = nil
    @Published var pendingRecap: String? = nil

    /// Every milestone ever hit — the trophy shelf's data source.
    /// Backed by the same "milestonesShown" key checkMilestones has
    /// always written, so existing installs keep their history.
    @Published private(set) var achievedMilestones: Set<String>


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
        burstCompletedDay = defaults.string(forKey: "burstCompletedDay") ?? ""
        weekTossed = defaults.integer(forKey: "weekTossed")
        weekFreed = Int64(defaults.integer(forKey: "weekFreed"))
        pendingRecap = defaults.string(forKey: "pendingRecap")
        achievedMilestones = Set(defaults.stringArray(forKey: "milestonesShown") ?? [])
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

    /// Marks today's burst complete.
    func completeBurst() {
        let today = Stats.dayFormatter.string(from: Date())
        guard burstCompletedDay != today else { return }
        burstCompletedDay = today
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
        ]
        var shown = Set(defaults.stringArray(forKey: "milestonesShown") ?? [])
        for (name, hit) in candidates where hit && !shown.contains(name) {
            shown.insert(name)
            if pendingMilestone == nil { pendingMilestone = name }
        }
        defaults.set(Array(shown), forKey: "milestonesShown")
        achievedMilestones = shown
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

    private func persist() {
        defaults.set(Int(lifetimeFreedBytes), forKey: "lifetimeFreedBytes")
        defaults.set(lifetimeTossedCount, forKey: "lifetimeTossedCount")
        defaults.set(burstCompletedDay, forKey: "burstCompletedDay")
        defaults.set(weekTossed, forKey: "weekTossed")
        defaults.set(Int(weekFreed), forKey: "weekFreed")

        // Mirror for the widget (no-op until the App Group exists).
        shared?.set(Int(lifetimeFreedBytes), forKey: "lifetimeFreedBytes")
        shared?.set(burstCompletedDay, forKey: "burstCompletedDay")
    }
}
