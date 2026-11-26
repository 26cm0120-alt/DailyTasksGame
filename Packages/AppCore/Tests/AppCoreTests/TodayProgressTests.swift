import AppCore
import Testing

struct TodayProgressTests {
    @Test func countsOnlyEnabledTasksInActiveGames() throws {
        let games = [
            TodayProgress(isActive: true, tasks: [.pending, .completed, .disabled]),
            TodayProgress(isActive: true, tasks: [.pending, .pending]),
            TodayProgress(isActive: false, tasks: [.pending])
        ].compactMap { $0 }

        #expect(games.count == 2)
        let first = try #require(games.first)
        #expect(first.remaining == 1)
        #expect(first.total == 2)
        #expect(!first.isComplete)
        #expect(TodayProgress.totalRemaining(in: games) == 3)
    }

    @Test func completeRequiresAtLeastOneEnabledTaskAndNoPendingTasks() throws {
        let completed = try #require(TodayProgress(isActive: true, tasks: [.completed, .disabled]))
        let empty = try #require(TodayProgress(isActive: true, tasks: []))
        let disabled = try #require(TodayProgress(isActive: true, tasks: [.disabled]))

        #expect(completed.isComplete)
        #expect(completed.remaining == 0)
        #expect(completed.total == 1)
        #expect(empty.total == 0)
        #expect(!empty.isComplete)
        #expect(disabled.total == 0)
        #expect(!disabled.isComplete)
    }
}
