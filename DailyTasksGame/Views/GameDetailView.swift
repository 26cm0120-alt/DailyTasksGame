import SwiftData
import SwiftUI

struct GameDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let game: Game
    @Query private var tasks: [TaskItem]
    @State private var isAddingTask = false
    @State private var isEditingGame = false
    @State private var reorderError: String?

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
}
