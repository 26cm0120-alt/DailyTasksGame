import SwiftData
import SwiftUI

struct TaskEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let task: TaskItem
    @State private var name: String
    @State private var kind: TaskKind
    @State private var isEnabled: Bool
    @State private var saveError: String?
    @State private var isConfirmingKindChange = false

    init(task: TaskItem) {
        self.task = task
        _name = State(initialValue: task.title)
        _kind = State(initialValue: task.kind)
        _isEnabled = State(initialValue: task.isEnabled)
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isKindChanged: Bool {
        kind != task.kind
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
                Section {
                    Toggle("有効", isOn: $isEnabled)
                }
            }
            .navigationTitle("タスクを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: requestSave)
                        .disabled(!isNameValid)
                }
            }
            .alert("種別を変更しますか？", isPresented: $isConfirmingKindChange) {
                Button("変更して保存", role: .destructive) {
                    save()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("種別を変更すると、このタスクの完了記録が削除されます")
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

    private func requestSave() {
        guard isNameValid else { return }
        if isKindChanged {
            isConfirmingKindChange = true
        } else {
            save()
        }
    }

    private func save() {
        guard isNameValid else { return }

        task.title = name
        task.isEnabled = isEnabled
        if isKindChanged {
            task.completionRecords.forEach(modelContext.delete)
            task.kind = kind
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }
}
