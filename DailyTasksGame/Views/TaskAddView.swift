import SwiftData
import SwiftUI

struct TaskAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let game: Game
    @State private var name = ""
    @State private var kind: TaskKind = .daily
    @State private var saveError: String?

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("タスク名（必須）", text: $name)
                }
                Section("種別") {
                    Picker("種別", selection: $kind) {
                        Text("デイリー").tag(TaskKind.daily)
                        Text("ウィークリー").tag(TaskKind.weekly)
                    }
                }
            }
            .navigationTitle("タスクを追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(!isNameValid)
                }
            }
            .alert("保存できませんでした", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private func save() {
        guard isNameValid else { return }

        do {
            let gameID = game.id
            // 種別や有効状態で分けず、このゲームの単一順序の末尾へ追加する。
            var descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate<TaskItem> { $0.game.id == gameID },
                sortBy: [SortDescriptor(\TaskItem.sortOrder, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            let lastOrder = try modelContext.fetch(descriptor).first?.sortOrder
            let nextOrder: Int
            if let lastOrder {
                let result = lastOrder.addingReportingOverflow(1)
                guard !result.overflow else {
                    saveError = "表示順の上限に達したため、タスクを追加できません。"
                    return
                }
                nextOrder = result.partialValue
            } else {
                nextOrder = 0
            }

            let task = try TaskItem(title: name, game: game, sortOrder: nextOrder,
                                    kind: kind, isEnabled: true)
            modelContext.insert(task)
            do {
                try modelContext.save()
            } catch {
                // 挿入を取り消しても、名前と種別の入力はStateに保持する。
                modelContext.rollback()
                throw error
            }
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
