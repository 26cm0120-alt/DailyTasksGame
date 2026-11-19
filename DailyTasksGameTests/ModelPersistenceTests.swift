import Foundation
import SwiftData
import Testing
@testable import DailyTasksGame

@MainActor
struct ModelPersistenceTests {
    private func openStore(at url: URL) throws -> ModelContainer {
        let schema = Schema([Game.self, TaskItem.self, CompletionRecord.self])
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    // ストア本体とWAL等をまとめて、成功・失敗のどちらでも後片付けする。
    private func withTemporaryStore(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyTasksGame-ModelTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
                #expect(!FileManager.default.fileExists(atPath: directory.path))
            } catch {
                Issue.record("一時ストアの削除に失敗: \(error)")
            }
        }
        try body(directory.appendingPathComponent("test.store"))
    }

    // この関数から値だけを返し、コンテナ・コンテキスト・モデルを次の読取へ持ち越さない。
    private func seedStore(at url: URL) throws -> [UUID] {
        let container = try openStore(at: url)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let game = try Game(name: "ゲームA", sortOrder: 1,
                            resetTime: ResetTime(hour: 4, minute: 30),
                            weeklyResetWeekday: 3,
                            weeklyResetTime: ResetTime(hour: 6, minute: 15),
                            isActive: false, note: "保存確認")
        let otherGame = try Game(name: "ゲームB", sortOrder: 0)
        context.insert(game)
        context.insert(otherGame)
        let daily = try TaskItem(title: "日次", game: game, sortOrder: 1)
        let weekly = try TaskItem(title: "週次", game: game, sortOrder: 0,
                                  kind: .weekly, isEnabled: false)
        let otherTask = try TaskItem(title: "別ゲーム", game: otherGame, sortOrder: 0)
        context.insert(daily)
        context.insert(weekly)
        context.insert(otherTask)
        let date = Date(timeIntervalSince1970: 1_795_000_000)
        let dailyRecord = CompletionRecord(task: daily, periodKey: "2026-11-18", completedAt: date)
        let weeklyRecord = CompletionRecord(task: weekly, periodKey: "2026-11-16", completedAt: date)
        let otherRecord = CompletionRecord(task: otherTask, periodKey: "2026-11-18", completedAt: date)
        context.insert(dailyRecord)
        context.insert(weeklyRecord)
        context.insert(otherRecord)
        try context.save()
        #expect(FileManager.default.fileExists(atPath: url.path))
        return [game.id, otherGame.id, daily.id, weekly.id, otherTask.id,
                dailyRecord.id, weeklyRecord.id, otherRecord.id]
    }

    @Test func diskStoreRetainsValuesRelationshipsAndOrder() throws {
        try withTemporaryStore { url in
            let ids = try seedStore(at: url)
            let container = try openStore(at: url)
            let context = ModelContext(container)
            let games = try context.fetch(FetchDescriptor<Game>(sortBy: [SortDescriptor(\Game.sortOrder)]))
            #expect(games.map(\.id) == [ids[1], ids[0]])
            let game = try #require(games.last)
            #expect(game.name == "ゲームA")
            #expect(game.resetTime == ResetTime(hour: 4, minute: 30))
            #expect(game.weeklyResetWeekday == 3)
            #expect(game.weeklyResetTime == ResetTime(hour: 6, minute: 15))
            #expect(!game.isActive)
            #expect(game.note == "保存確認")
            let tasks = game.tasks.sorted { $0.sortOrder < $1.sortOrder }
            #expect(tasks.map(\.id) == [ids[3], ids[2]])
            #expect(tasks.map(\.title) == ["週次", "日次"])
            #expect(tasks.map(\.kind) == [.weekly, .daily])
            #expect(tasks.map(\.isEnabled) == [false, true])
            #expect(tasks.allSatisfy { $0.game.id == game.id })
            let records = try context.fetch(FetchDescriptor<CompletionRecord>())
            #expect(Set(records.map(\.id)) == Set(ids[5...7]))
            let record = try #require(records.first { $0.id == ids[5] })
            #expect(record.task.id == ids[2])
            #expect(record.periodKey == "2026-11-18")
            #expect(record.completedAt == Date(timeIntervalSince1970: 1_795_000_000))
            #expect(tasks[1].completionRecords.map(\.id) == [record.id])
        }
    }

    private func deleteGame(at url: URL, id: UUID) throws {
        let container = try openStore(at: url)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let games = try context.fetch(FetchDescriptor<Game>())
        context.delete(try #require(games.first { $0.id == id }))
        try context.save()
    }

    @Test func deletingGameCascadesOnlyItsTasksAndRecords() throws {
        try withTemporaryStore { url in
            let ids = try seedStore(at: url)
            try deleteGame(at: url, id: ids[0])
            let container = try openStore(at: url)
            let context = ModelContext(container)
            #expect(try context.fetch(FetchDescriptor<Game>()).map(\.id) == [ids[1]])
            #expect(try context.fetch(FetchDescriptor<TaskItem>()).map(\.id) == [ids[4]])
            #expect(try context.fetch(FetchDescriptor<CompletionRecord>()).map(\.id) == [ids[7]])
        }
    }

    private func deleteTask(at url: URL, id: UUID) throws {
        let container = try openStore(at: url)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        context.delete(try #require(tasks.first { $0.id == id }))
        try context.save()
    }

    @Test func deletingTaskCascadesOnlyItsRecords() throws {
        try withTemporaryStore { url in
            let ids = try seedStore(at: url)
            try deleteTask(at: url, id: ids[2])
            let container = try openStore(at: url)
            let context = ModelContext(container)
            #expect(try context.fetchCount(FetchDescriptor<Game>()) == 2)
            let tasks = try context.fetch(FetchDescriptor<TaskItem>())
            #expect(Set(tasks.map(\.id)) == Set([ids[3], ids[4]]))
            let records = try context.fetch(FetchDescriptor<CompletionRecord>())
            #expect(Set(records.map(\.id)) == Set([ids[6], ids[7]]))
            let game = try #require(tasks.first { $0.id == ids[3] }?.game)
            #expect(game.tasks.map(\.id) == [ids[3]])
        }
    }

    @Test func deletingTaskRecompactsOrderAndCascadesOnlyItsRecords() throws {
        try withTemporaryStore { url in
            let ids = try seedStore(at: url)
            let container = try openStore(at: url)
            let context = ModelContext(container)
            context.autosaveEnabled = false

            let gameTasks = try context.fetch(
                FetchDescriptor<TaskItem>(
                    predicate: #Predicate<TaskItem> { $0.game.id == ids[0] },
                    sortBy: [SortDescriptor(\TaskItem.sortOrder)]
                )
            )
            let deletedTask = try #require(gameTasks.first { $0.id == ids[2] })
            let remainingTasks = gameTasks.filter { $0.id != ids[2] }

            context.delete(deletedTask)
            for (index, task) in remainingTasks.enumerated() {
                task.sortOrder = index
            }
            try context.save()

            let reopened = try openStore(at: url)
            let reopenedContext = ModelContext(reopened)
            let reopenedTasks = try reopenedContext.fetch(
                FetchDescriptor<TaskItem>(
                    predicate: #Predicate<TaskItem> { $0.game.id == ids[0] },
                    sortBy: [SortDescriptor(\TaskItem.sortOrder)]
                )
            )
            #expect(reopenedTasks.map(\.id) == [ids[3]])
            #expect(reopenedTasks.map(\.sortOrder) == [0])
            #expect(reopenedTasks.map(\.title) == ["週次"])

            let records = try reopenedContext.fetch(FetchDescriptor<CompletionRecord>())
            #expect(Set(records.map(\.id)) == Set([ids[6], ids[7]]))
            #expect(!records.contains { $0.id == ids[5] })
            #expect(reopenedTasks[0].completionRecords.map(\.id) == [ids[6]])
            #expect(records.first { $0.id == ids[7] }?.task.id == ids[4])
        }
    }

    @Test func defaultsAndIndependentWeeklyTime() throws {
        let game = try Game(name: "ゲーム", sortOrder: 0)
        let task = try TaskItem(title: "タスク", game: game, sortOrder: 0)
        #expect(game.isActive)
        #expect(game.resetTime == ResetTime(hour: 5, minute: 0))
        #expect(game.weeklyResetWeekday == 2)
        #expect(game.weeklyResetTime == game.resetTime)
        #expect(task.isEnabled)
        #expect(task.kind == .daily)
        game.resetTime = ResetTime(hour: 4, minute: 0)
        #expect(game.weeklyResetTime == ResetTime(hour: 5, minute: 0))
        let custom = try Game(name: "ゲーム", sortOrder: 1,
                              resetTime: ResetTime(hour: 7, minute: 30))
        #expect(custom.weeklyResetTime == ResetTime(hour: 7, minute: 30))
    }

    @Test func namesRejectOnlyEmptyInputWithoutChangingStoredText() throws {
        for name in ["", "  \n\t", "　"] {
            #expect(throws: ModelInputError.emptyName) { try Game(name: name, sortOrder: 0) }
        }
        let game = try Game(name: " ゲーム ", sortOrder: 0)
        #expect(game.name == " ゲーム ")
        #expect(throws: ModelInputError.emptyName) {
            try TaskItem(title: " \n ", game: game, sortOrder: 0)
        }
        let first = try TaskItem(title: " タスク ", game: game, sortOrder: 0)
        let second = try TaskItem(title: " タスク ", game: game, sortOrder: 1)
        #expect(first.title == second.title)
        _ = try Game(name: " ゲーム ", sortOrder: 1)
        _ = try TaskItem(title: String(repeating: "あ", count: 10_000), game: game, sortOrder: 2)
    }

    @Test func changingTaskKindDeletesOnlyItsCompletionRecords() throws {
        try withTemporaryStore { url in
            let ids = try seedStore(at: url)
            let container = try openStore(at: url)
            let context = ModelContext(container)
            let task = try #require(
                context.fetch(FetchDescriptor<TaskItem>()).first { $0.id == ids[2] }
            )

            task.kind = .weekly
            task.completionRecords.forEach(context.delete)
            try context.save()

            let reopened = try openStore(at: url)
            let reopenedContext = ModelContext(reopened)
            let records = try reopenedContext.fetch(FetchDescriptor<CompletionRecord>())
            #expect(Set(records.map(\.id)) == Set([ids[6], ids[7]]))
            let changedTask = try #require(
                reopenedContext.fetch(FetchDescriptor<TaskItem>()).first { $0.id == ids[2] }
            )
            #expect(changedTask.kind == .weekly)
            #expect(changedTask.completionRecords.isEmpty)
        }
    }

    @Test func renamingTaskPreservesCompletionRecords() throws {
        try withTemporaryStore { url in
            let ids = try seedStore(at: url)
            let container = try openStore(at: url)
            let context = ModelContext(container)
            let task = try #require(
                context.fetch(FetchDescriptor<TaskItem>()).first { $0.id == ids[2] }
            )

            task.title = "変更後の名前"
            try context.save()

            let reopened = try openStore(at: url)
            let reopenedContext = ModelContext(reopened)
            let renamedTask = try #require(
                reopenedContext.fetch(FetchDescriptor<TaskItem>()).first { $0.id == ids[2] }
            )
            #expect(renamedTask.title == "変更後の名前")
            #expect(renamedTask.kind == .daily)
            #expect(renamedTask.completionRecords.map(\.id) == [ids[5]])
            #expect(Set(try reopenedContext.fetch(FetchDescriptor<CompletionRecord>()).map(\.id))
                == Set([ids[5], ids[6], ids[7]]))
        }
    }

    @Test func disablingTaskPreservesRecordsAndSortOrder() throws {
        try withTemporaryStore { url in
            let ids = try seedStore(at: url)
            let container = try openStore(at: url)
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let task = try #require(
                context.fetch(FetchDescriptor<TaskItem>()).first { $0.id == ids[2] }
            )
            let originalSortOrder = task.sortOrder

            task.isEnabled = false
            try context.save()

            let reopened = try openStore(at: url)
            let reopenedContext = ModelContext(reopened)
            let disabledTask = try #require(
                reopenedContext.fetch(FetchDescriptor<TaskItem>()).first { $0.id == ids[2] }
            )
            #expect(!disabledTask.isEnabled)
            #expect(disabledTask.sortOrder == originalSortOrder)
            #expect(disabledTask.completionRecords.map(\.id) == [ids[5]])
            #expect(Set(try reopenedContext.fetch(FetchDescriptor<CompletionRecord>()).map(\.id))
                == Set([ids[5], ids[6], ids[7]]))
        }
    }

    @Test func reorderingTasksPreservesValuesAndCompletionRecords() throws {
        try withTemporaryStore { url in
            let ids = try seedStore(at: url)
            let container = try openStore(at: url)
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let tasks = try context.fetch(FetchDescriptor<TaskItem>())
                .filter { $0.game.id == ids[0] }
                .sorted { $0.sortOrder < $1.sortOrder }
            #expect(tasks.map(\.id) == [ids[3], ids[2]])

            for (index, task) in tasks.reversed().enumerated() {
                task.sortOrder = index
            }
            try context.save()

            let reopened = try openStore(at: url)
            let reopenedContext = ModelContext(reopened)
            let reorderedTasks = try reopenedContext.fetch(
                FetchDescriptor<TaskItem>(
                    predicate: #Predicate<TaskItem> { $0.game.id == ids[0] },
                    sortBy: [SortDescriptor(\TaskItem.sortOrder)]
                )
            )
            #expect(reorderedTasks.map(\.id) == [ids[2], ids[3]])
            #expect(reorderedTasks.map(\.sortOrder) == [0, 1])
            #expect(reorderedTasks.map(\.title) == ["日次", "週次"])
            #expect(reorderedTasks.map(\.kind) == [.daily, .weekly])
            #expect(reorderedTasks.map(\.isEnabled) == [true, false])
            #expect(reorderedTasks[0].completionRecords.map(\.id) == [ids[5]])
            #expect(reorderedTasks[1].completionRecords.map(\.id) == [ids[6]])
            #expect(Set(try reopenedContext.fetch(FetchDescriptor<CompletionRecord>()).map(\.id))
                == Set([ids[5], ids[6], ids[7]]))
        }
    }
}
