import Foundation
import Testing
import AppCore

struct GameDayCalculatorTests {
    private func instant(_ value: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: value))
    }

    private func assertBoundary(
        zone: String, hour: Int, minute: Int = 0, weekday: Int,
        boundary: String, dailyEnd: String, weeklyEnd: String,
        dailyBefore: String, weeklyBefore: String, key: String
    ) throws {
        let timeZone = try #require(TimeZone(identifier: zone))
        let reset = GameDayCalculator.ResetTime(hour: hour, minute: minute)
        let start = try instant(boundary)
        func calculate(_ now: Date) throws -> GameDayCalculator.Periods {
            try #require(GameDayCalculator.periods(
                now: now, dailyReset: reset, weeklyResetWeekday: weekday, weeklyReset: reset,
                calendar: Calendar(identifier: .gregorian), timeZone: timeZone
            ))
        }
        let before = try calculate(start.addingTimeInterval(-1))
        let at = try calculate(start)
        #expect(before.daily.end == start)
        #expect(before.weekly.end == start)
        #expect(before.daily.key == dailyBefore)
        #expect(before.weekly.key == weeklyBefore)
        #expect(at.daily.start == start)
        #expect(at.weekly.start == start)
        #expect(at.daily.end == (try instant(dailyEnd)))
        #expect(at.weekly.end == (try instant(weeklyEnd)))
        #expect(at.daily.key == key)
        #expect(at.weekly.key == key)
    }

    @Test func midnightAtNewYear() throws {
        try assertBoundary(zone: "Asia/Tokyo", hour: 0, weekday: 5,
            boundary: "2025-12-31T15:00:00Z", dailyEnd: "2026-01-01T15:00:00Z",
            weeklyEnd: "2026-01-07T15:00:00Z", dailyBefore: "2025-12-31",
            weeklyBefore: "2025-12-25", key: "2026-01-01")
    }

    @Test func fiveAMAfterLeapDay() throws {
        try assertBoundary(zone: "Asia/Tokyo", hour: 5, weekday: 6,
            boundary: "2024-02-29T20:00:00Z", dailyEnd: "2024-03-01T20:00:00Z",
            weeklyEnd: "2024-03-07T20:00:00Z", dailyBefore: "2024-02-29",
            weeklyBefore: "2024-02-23", key: "2024-03-01")
    }

    @Test func springGapStartsImmediatelyAfterJump() throws {
        try assertBoundary(zone: "America/New_York", hour: 2, minute: 30, weekday: 1,
            boundary: "2026-03-08T07:00:00Z", dailyEnd: "2026-03-09T06:30:00Z",
            weeklyEnd: "2026-03-15T06:30:00Z", dailyBefore: "2026-03-07",
            weeklyBefore: "2026-03-01", key: "2026-03-08")
    }

    @Test func autumnRepeatStartsAtFirstOccurrenceAndLengthensPeriod() throws {
        try assertBoundary(zone: "America/New_York", hour: 1, minute: 30, weekday: 1,
            boundary: "2026-11-01T05:30:00Z", dailyEnd: "2026-11-02T06:30:00Z",
            weeklyEnd: "2026-11-08T06:30:00Z", dailyBefore: "2026-10-31",
            weeklyBefore: "2026-10-25", key: "2026-11-01")
        let reset = GameDayCalculator.ResetTime(hour: 1, minute: 30)
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        for now in ["2026-11-01T06:00:00Z", "2026-11-01T06:30:00Z"] {
            let periods = try #require(GameDayCalculator.periods(
                now: instant(now), dailyReset: reset, weeklyResetWeekday: 1, weeklyReset: reset,
                calendar: Calendar(identifier: .gregorian), timeZone: timeZone
            ))
            #expect(periods.daily.key == "2026-11-01")
            #expect(periods.weekly.key == "2026-11-01")
            #expect(periods.daily.end.timeIntervalSince(periods.daily.start) == 25 * 3600)
            #expect(periods.weekly.end.timeIntervalSince(periods.weekly.start) == 169 * 3600)
        }
    }

    @Test func weeklyBoundaryIsIndependentOfDailyReset() throws {
        let timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        // 地方時の月曜4:00。日次の5:00より先に週次だけが切り替わる。
        let boundary = try instant("2026-11-15T19:00:00Z")
        func calculate(_ now: Date) throws -> GameDayCalculator.Periods {
            try #require(GameDayCalculator.periods(
                now: now, dailyReset: .init(hour: 5, minute: 0),
                weeklyResetWeekday: 2, weeklyReset: .init(hour: 4, minute: 0),
                calendar: Calendar(identifier: .gregorian), timeZone: timeZone
            ))
        }
        let before = try calculate(boundary.addingTimeInterval(-1))
        let at = try calculate(boundary)

        #expect(before.weekly.key == "2026-11-09")
        #expect(before.weekly.start == (try instant("2026-11-08T19:00:00Z")))
        #expect(before.weekly.end == boundary)
        #expect(at.weekly.key == "2026-11-16")
        #expect(at.weekly.start == boundary)
        #expect(at.weekly.end == (try instant("2026-11-22T19:00:00Z")))

        // 週次境界の前後でも日次は日曜5:00から月曜5:00の同じ期間に属する。
        #expect(before.daily.key == "2026-11-15")
        #expect(before.daily.start == (try instant("2026-11-14T20:00:00Z")))
        #expect(before.daily.end == (try instant("2026-11-15T20:00:00Z")))
        #expect(at.daily == before.daily)
    }

    @Test func weeklyKeyIsIndependentOfDailyReset() throws {
        let timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let periods = try #require(GameDayCalculator.periods(
            now: instant("2026-11-15T19:00:00Z"),
            dailyReset: .init(hour: 5, minute: 0),
            weeklyResetWeekday: 2, weeklyReset: .init(hour: 4, minute: 0),
            calendar: Calendar(identifier: .gregorian), timeZone: timeZone
        ))
        #expect(periods.daily.key == "2026-11-15")
        #expect(periods.weekly.key == "2026-11-16")
    }
}
