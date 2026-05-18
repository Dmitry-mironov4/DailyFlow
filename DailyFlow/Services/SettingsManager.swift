import Foundation

enum SettingsManager {
    private static let defaults = UserDefaults(suiteName: "group.com.dmitry.dailyflow") ?? .standard

    private enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let dailySummaryEnabled = "dailySummaryEnabled"
        static let dailySummaryTime = "dailySummaryTime"
        static let calendarSyncEnabled = "calendarSyncEnabled"
        static let firstWeekday = "firstWeekday"
    }

    static var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }

    static var dailySummaryEnabled: Bool {
        get { defaults.bool(forKey: Key.dailySummaryEnabled) }
        set { defaults.set(newValue, forKey: Key.dailySummaryEnabled) }
    }

    static var dailySummaryTime: Date {
        get {
            guard let stored = defaults.object(forKey: Key.dailySummaryTime) as? Date else {
                return defaultSummaryTime()
            }
            return stored
        }
        set { defaults.set(newValue, forKey: Key.dailySummaryTime) }
    }

    static var calendarSyncEnabled: Bool {
        get {
            let stored = defaults.object(forKey: Key.calendarSyncEnabled)
            return stored == nil ? true : defaults.bool(forKey: Key.calendarSyncEnabled)
        }
        set { defaults.set(newValue, forKey: Key.calendarSyncEnabled) }
    }

    static var firstWeekday: Int {
        get {
            let stored = defaults.integer(forKey: Key.firstWeekday)
            return stored == 0 ? 2 : stored // 2 = понедельник
        }
        set { defaults.set(newValue, forKey: Key.firstWeekday) }
    }
}

private func defaultSummaryTime() -> Date {
    var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
    components.hour = 21
    components.minute = 0
    return Calendar.current.date(from: components) ?? .now
}
