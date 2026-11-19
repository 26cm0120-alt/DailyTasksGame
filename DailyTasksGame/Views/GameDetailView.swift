import SwiftData
import SwiftUI

struct GameDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let game: Game
    @Query private var tasks: [TaskItem]
    @State private var isAddingTask = false
    @State private var isEditingGame = false
    @State private var reorderError: String?
    @State private var deletionTarget: TaskItem?
    @State private var deletionError: String?

    init(game: Game) {
        self.game = game
        let gameID = game.id
        _tasks = Query(
            filter: #Predicate<TaskItem> { $0.game.id == gameID },
            sort: \TaskItem.sortOrder
        )
    }

    var body: some View {
        List {
            ForEach(tasks) { task in
                Button {
                    selectedTask = task
                } label: {
                    HStack {
                        Text(task.title)
                        Spacer()
                        if task.isEnabled {
                            Text(task.kind == .daily ? "デイリー" : "ウィークリー")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(task.kind == .daily ? "デイリー・無効" : "ウィークリー・無効")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(task.isEnabled ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
            .onMove(perform: moveTasks)
            .onDelete(perform: requestTaskDeletion)
        }
        .navigationTitle(game.name)
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
        .sheet(isPresented: $isEditingGame) {
            GameEditView(game: game)
        }
        .sheet(isPresented: $isAddingTask) {
            TaskAddView(game: game)
        }
        .sheet(item: $selectedTask) { task in
            TaskEditView(task: task)
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
