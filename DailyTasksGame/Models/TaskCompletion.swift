import AppCore
import Foundation
import SwiftData

enum TaskCompletion {
    enum Change {
        case complete
        case cancel
        case toggle
    }

    enum CompletionError: LocalizedError {
        case periodUnavailable

        var errorDescription: String? { "現在の期間を判定できませんでした。" }
    }

    static func periods(
        for game: Game, now: Date, timeZone: TimeZone = .autoupdatingCurrent
    ) -> GameDayCalculator.Periods? {
        GameDayCalculator.periods(
            now: now,
            dailyReset: .init(hour: game.resetTime.hour, minute: game.resetTime.minute),
            weeklyResetWeekday: game.weeklyResetWeekday,
            weeklyReset: .init(hour: game.weeklyResetTime.hour, minute: game.weeklyResetTime.minute),
            calendar: Calendar(identifier: .gregorian),
            timeZone: timeZone
        )
    }

    static func periodKey(for kind: TaskKind, in periods: GameDayCalculator.Periods?) -> String? {
        switch kind {
        case .daily: periods?.daily.key
        case .weekly: periods?.weekly.key
        }
    }

    static func isCompleted(in records: [CompletionRecord], periodKey: String?) -> Bool {
        guard let periodKey else { return false }
        return records.contains { $0.periodKey == periodKey }
    }

    static func apply(
        _ change: Change, to task: TaskItem, context: ModelContext,
        now: Date = .now, timeZone: TimeZone = .autoupdatingCurrent
    ) throws {
        let periods = periods(for: task.game, now: now, timeZone: timeZone)
        guard let key = periodKey(for: task.kind, in: periods) else {
            throw CompletionError.periodUnavailable
        }

        let taskID = task.id
        let matching = try context.fetch(FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.task.id == taskID && $0.periodKey == key }
        ))
        let shouldComplete = change == .complete || (change == .toggle && matching.isEmpty)
        if shouldComplete {
            guard matching.isEmpty else { return }
            context.insert(CompletionRecord(task: task, periodKey: key, completedAt: now))
        } else {
            guard !matching.isEmpty else { return }
            matching.forEach { context.delete($0) }
        }

        do {
            try context.save()
        } catch {
            // 永続化できなかった挿入・削除を元に戻す。
            context.rollback()
            throw error
        }
    }
}
