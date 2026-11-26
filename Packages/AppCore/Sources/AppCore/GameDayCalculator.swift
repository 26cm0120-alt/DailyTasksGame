import Foundation

public enum GameDayCalculator {
    public struct ResetTime: Equatable, Sendable {
        public let hour: Int
        public let minute: Int

        public init(hour: Int, minute: Int) {
            precondition((0..<24).contains(hour) && (0..<60).contains(minute))
            self.hour = hour
            self.minute = minute
        }
    }

    public struct Period: Equatable, Sendable {
        public let start: Date
        // 終了時刻は次の期間に属する。
        public let end: Date
        public let key: String
    }

    public struct Periods: Equatable, Sendable {
        public let daily: Period
        public let weekly: Period
    }

    // 曜日は Calendar と同じく日曜が1、土曜が7。
    public static func periods(
        now: Date,
        dailyReset: ResetTime,
        weeklyResetWeekday: Int,
        weeklyReset: ResetTime,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> Periods? {
        precondition((1...7).contains(weeklyResetWeekday))
        var calendar = calendar
        calendar.timeZone = timeZone

        let today = calendar.startOfDay(for: now)
        guard let daily = period(now: now, today: today, reset: dailyReset, weekday: nil, calendar: calendar),
              let weekly = period(now: now, today: today, reset: weeklyReset, weekday: weeklyResetWeekday, calendar: calendar)
        else { return nil }
        return Periods(daily: daily, weekly: weekly)
    }

    private static func period(
        now: Date, today: Date, reset: ResetTime, weekday: Int?, calendar: Calendar
    ) -> Period? {
        let step = weekday == nil ? 1 : 7
        let daysSinceReset = weekday.map { (calendar.component(.weekday, from: today) - $0 + 7) % 7 } ?? 0
        guard let day = calendar.date(byAdding: .day, value: -daysSinceReset, to: today),
              let boundary = boundary(on: day, reset: reset, calendar: calendar)
        else { return nil }

        let isCurrent = boundary <= now
        guard let neighbor = calendar.date(byAdding: .day, value: isCurrent ? step : -step, to: day),
              let neighboringBoundary = self.boundary(on: neighbor, reset: reset, calendar: calendar)
        else { return nil }

        let start = isCurrent ? boundary : neighboringBoundary
        let end = isCurrent ? neighboringBoundary : boundary
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return Period(start: start, end: end, key: formatter.string(from: start))
    }

    private static func boundary(on day: Date, reset: ResetTime, calendar: Calendar) -> Date? {
        let startOfDay = calendar.startOfDay(for: day)
        let targetMinute = reset.hour * 60 + reset.minute
        let firstMinute = calendar.component(.hour, from: startOfDay) * 60
            + calendar.component(.minute, from: startOfDay)
        if firstMinute >= targetMinute { return startOfDay }

        guard let match = calendar.nextDate(
            after: startOfDay,
            matching: DateComponents(hour: reset.hour, minute: reset.minute, second: 0),
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first
        ), calendar.isDate(match, inSameDayAs: day) else { return nil }

        // 秋の重複で後の時刻が返った場合は、オフセット差だけ戻して地方時を照合する。
        let zone = calendar.timeZone
        if let transition = zone.nextDaylightSavingTimeTransition(after: startOfDay),
           transition <= match {
            let shift = zone.secondsFromGMT(for: transition.addingTimeInterval(-1))
                - zone.secondsFromGMT(for: transition)
            if shift > 0 {
                let earlier = match.addingTimeInterval(-TimeInterval(shift))
                if earlier >= startOfDay,
                   calendar.isDate(earlier, inSameDayAs: day),
                   calendar.component(.hour, from: earlier) == reset.hour,
                   calendar.component(.minute, from: earlier) == reset.minute {
                    return earlier
                }
            }
        }
        return match
    }
}
