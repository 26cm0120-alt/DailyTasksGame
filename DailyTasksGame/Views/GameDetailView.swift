import SwiftData
import SwiftUI

struct GameDetailView: View {
    let game: Game
    @Query private var tasks: [TaskItem]
    @State private var isAddingTask = false
    @State private var isEditingGame = false

    init(game: Game) {
        self.game = game
        let gameID = game.id
        _tasks = Query(
            filter: #Predicate<TaskItem> { $0.game.id == gameID },
            sort: \TaskItem.sortOrder
        )
    }

    var body: some View {
        List(tasks) { task in
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
        .navigationTitle(game.name)
        .toolbar {
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
    }

    @State private var selectedTask: TaskItem?
}
