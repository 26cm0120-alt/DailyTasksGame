import SwiftData
import SwiftUI

struct GameEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let game: Game
    @State private var name: String
    @State private var resetTime: ResetTime
    @State private var weeklyResetWeekday: Int
    @State private var weeklyResetTime: ResetTime
    @State private var note: String
    @State private var isPaused: Bool
    @State private var saveError: String?

    init(game: Game) {
        self.game = game
        // 入力値をモデルからコピーし、キャンセル時に元の値を変更しない。
        _name = State(initialValue: game.name)
        _resetTime = State(initialValue: game.resetTime)
        _weeklyResetWeekday = State(initialValue: game.weeklyResetWeekday)
        _weeklyResetTime = State(initialValue: game.weeklyResetTime)
        _note = State(initialValue: game.note)
        _isPaused = State(initialValue: !game.isActive)
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("ゲーム名（必須）", text: $name)
                }

                Section("日次リセット") {
                    ResetTimeInput(time: $resetTime)
                }

                Section("週次リセット") {
                    Picker("曜日", selection: $weeklyResetWeekday) {
                        Text("日曜日").tag(1)
                        Text("月曜日").tag(2)
                        Text("火曜日").tag(3)
                        Text("水曜日").tag(4)
                        Text("木曜日").tag(5)
                        Text("金曜日").tag(6)
                        Text("土曜日").tag(7)
                    }
                    ResetTimeInput(time: $weeklyResetTime)
                }

                Section("メモ（任意）") {
                    TextField("メモ", text: $note, axis: .vertical)
                }

                Section {
                    Toggle("休止", isOn: $isPaused)
                }
            }
            .navigationTitle("ゲームを編集")
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

        // モデルへの代入は保存ボタンを押した時だけ行う。
        // 表示順・タスクや完了記録には触れない。
        game.name = name
        game.resetTime = resetTime
        game.weeklyResetWeekday = weeklyResetWeekday
        game.weeklyResetTime = weeklyResetTime
        game.note = note
        game.isActive = !isPaused

        do {
            try modelContext.save()
            dismiss()
        } catch {
            // モデルの変更を戻しても、再入力用のStateはそのまま保持する。
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }
}
