import SwiftData
import SwiftUI

struct GameAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var resetTime = ResetTime(hour: 5, minute: 0)
    @State private var weeklyResetWeekday = 2
    // 日次と同じ初期値を持つが、入力中の日次変更には連動させない。
    @State private var weeklyResetTime = ResetTime(hour: 5, minute: 0)
    @State private var note = ""
    @State private var saveError: String?

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
            }
            .navigationTitle("ゲームを追加")
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
            var descriptor = FetchDescriptor<Game>(sortBy: [SortDescriptor(\Game.sortOrder, order: .reverse)])
            descriptor.fetchLimit = 1
            let lastOrder = try modelContext.fetch(descriptor).first?.sortOrder
            let nextOrder: Int
            if let lastOrder {
                let result = lastOrder.addingReportingOverflow(1)
                guard !result.overflow else {
                    saveError = "表示順の上限に達したため、ゲームを追加できません。"
                    return
                }
                nextOrder = result.partialValue
            } else {
                nextOrder = 0
            }

            let game = try Game(
                name: name,
                sortOrder: nextOrder,
                resetTime: resetTime,
                weeklyResetWeekday: weeklyResetWeekday,
                weeklyResetTime: weeklyResetTime,
                isActive: true,
                note: note
            )
            modelContext.insert(game)
            do {
                try modelContext.save()
            } catch {
                // 保存できなかった挿入を戻す。フォームの入力値はStateに残す。
                modelContext.rollback()
                throw error
            }
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

// 時刻設定を日付に変換せず、時・分として直接入力する。
struct ResetTimeInput: View {
    @Binding var time: ResetTime

    var body: some View {
        Picker("時", selection: Binding(
            get: { time.hour },
            set: { time = ResetTime(hour: $0, minute: time.minute) }
        )) {
            ForEach(0..<24, id: \.self) { hour in
                Text("\(hour)時").tag(hour)
            }
        }
        Picker("分", selection: Binding(
            get: { time.minute },
            set: { time = ResetTime(hour: time.hour, minute: $0) }
        )) {
            ForEach(0..<60, id: \.self) { minute in
                Text("\(minute)分").tag(minute)
            }
        }
    }
}
