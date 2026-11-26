import AppCore
import SwiftData
import SwiftUI

struct GameDetailView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    let game: Game
    @Query private var tasks: [TaskItem]
    @State private var isAddingTask = false
    @State private var isEditingGame = false
    @State private var reorderError: String?
    @State private var deletionTarget: TaskItem?
    @State private var deletionError: String?
    @State private var completionError: String?
    @State private var completionTime = Date.now
    @State private var clockRevision = 0

    init(game: Game) {
        self.game = game
        let gameID = game.id
        _tasks = Query(
            filter: #Predicate<TaskItem> { $0.game.id == gameID },
            sort: \TaskItem.sortOrder
        )
    }

    var body: some View {
        let periods = TaskCompletion.periods(for: game, now: completionTime)
        let nextBoundary = periods.map { min($0.daily.end, $0.weekly.end) }
        let activeBoundary = scenePhase == .active ? nextBoundary : nil

        List {
            ForEach(tasks) { task in
                let periodKey = TaskCompletion.periodKey(for: task.kind, in: periods)
                TaskCompletionRow(
                    task: task,
                    periodKey: periodKey,
                    toggle: { toggleCompletion(task, displayedKey: periodKey) },
                    edit: { selectedTask = task }
                )
            }
            .onMove(perform: moveTasks)
            .onDelete(perform: requestTaskDeletion)
        }
        .navigationTitle(game.name)
        .onAppear { updateCompletionTime() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { updateCompletionTime() }
        }
        .onDeviceClockChange {
            updateCompletionTime()
            clockRevision &+= 1
        }
        .task(id: BoundaryWaitID(date: activeBoundary, clockRevision: clockRevision)) {
            guard let activeBoundary else { return }
            await refreshCompletion(at: activeBoundary)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button("ゲームを編集") {
                    isEditingGame = true
                }
                Button("タスクを追加", systemImage: "plus") {
                    isAddingTask = true
                }
            }
        }
        .sheet(isPresented: $isEditingGame, onDismiss: { updateCompletionTime() }) {
            GameEditView(game: game)
        }
        .sheet(isPresented: $isAddingTask) {
            TaskAddView(game: game)
        }
        .sheet(item: $selectedTask, onDismiss: { updateCompletionTime() }) { task in
            TaskEditView(task: task)
        }
        .alert("完了状態を更新できませんでした", isPresented: Binding(
            get: { completionError != nil },
            set: { if !$0 { completionError = nil } }
        )) {
            Button("OK", role: .cancel) { completionError = nil }
        } message: {
            Text(completionError ?? "")
        }
        .alert("並び順を保存できませんでした", isPresented: Binding(
            get: { reorderError != nil },
            set: { if !$0 { reorderError = nil } }
        )) {
            Button("OK", role: .cancel) { reorderError = nil }
        } message: {
            Text(reorderError ?? "")
        }
        .alert(item: $deletionTarget) { task in
            Alert(
                title: Text("タスクを削除しますか"),
                message: Text("「\(task.title)」を削除します。\n完了記録も削除されます。"),
                primaryButton: .destructive(Text("削除")) {
                    deleteTask(task)
                },
                secondaryButton: .cancel(Text("やめる"))
            )
        }
        .alert("タスクを削除できませんでした", isPresented: Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )) {
            Button("OK", role: .cancel) { deletionError = nil }
        } message: {
            Text(deletionError ?? "")
        }
    }

    @State private var selectedTask: TaskItem?

    private func updateCompletionTime(to now: Date = .now) {
        completionTime = now
    }

    private func refreshCompletion(at boundary: Date) async {
        do {
            // 待機中に時計が戻った場合も、実時刻が境界に達するまで待つ。
            var remaining = boundary.timeIntervalSinceNow
            while remaining > 0 {
                try await Task.sleep(for: .seconds(remaining))
                remaining = boundary.timeIntervalSinceNow
            }
            try Task.checkCancellation()
            updateCompletionTime()
        } catch is CancellationError {
            // 画面が閉じるか、待機する境界が変わった。
        } catch {
            completionError = error.localizedDescription
        }
    }

    private func toggleCompletion(_ task: TaskItem, displayedKey: String?) {
        let now = Date.now
        defer { updateCompletionTime(to: now) }
        do {
            try TaskCompletion.toggleDisplayedPeriod(displayedKey, for: task, context: modelContext, now: now)
        } catch {
            completionError = error.localizedDescription
        }
    }

    private func moveTasks(from source: IndexSet, to destination: Int) {
        // 有効状態・種別を問わず一覧全体を移動し、表示順を連番で保存する。
        var reorderedTasks = tasks
        reorderedTasks.move(fromOffsets: source, toOffset: destination)
        for (index, task) in reorderedTasks.enumerated() {
            task.sortOrder = index
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            reorderError = error.localizedDescription
        }
    }

    private func requestTaskDeletion(at offsets: IndexSet) {
        guard let index = offsets.first, tasks.indices.contains(index) else { return }
        deletionTarget = tasks[index]
    }

    private func deleteTask(_ task: TaskItem) {
        let remainingTasks = tasks.filter { $0.id != task.id }

        modelContext.delete(task)
        for (index, remainingTask) in remainingTasks.enumerated() {
            remainingTask.sortOrder = index
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deletionError = error.localizedDescription
        }
    }
}

private struct TaskCompletionRow: View {
    let task: TaskItem
    let periodKey: String?
    let toggle: () -> Void
    let edit: () -> Void
    @Query private var records: [CompletionRecord]

    init(task: TaskItem, periodKey: String?, toggle: @escaping () -> Void, edit: @escaping () -> Void) {
        self.task = task
        self.periodKey = periodKey
        self.toggle = toggle
        self.edit = edit
        let taskID = task.id
        _records = Query(filter: #Predicate<CompletionRecord> { $0.task.id == taskID })
    }

    var body: some View {
        let completed = TaskCompletion.isCompleted(in: records, periodKey: periodKey)
        let kind = task.kind == .daily ? "デイリー" : "ウィークリー"

        HStack {
            Button(action: toggle) {
                HStack {
                    Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                        .accessibilityHidden(true)
                    Text(task.title)
                    Spacer()
                    Text(task.isEnabled ? kind : "\(kind)・無効")
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(task.isEnabled ? .primary : .secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(completed ? "完了" : "未完了")

            Button(action: edit) {
                Image(systemName: "pencil")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("「\(task.title)」を編集")
        }
    }
}
