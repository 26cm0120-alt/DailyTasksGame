import AppCore
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Game.sortOrder) private var games: [Game]
    @State private var isAddingGame = false
    @State private var editingGame: Game?
    @State private var reorderError: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(games) { game in
                    Button {
                        editingGame = game
                    } label: {
                        HStack {
                            Text(game.name)
                            if !game.isActive {
                                Spacer()
                                Text("休止中")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onMove(perform: moveGames)
            }
            .navigationTitle("今日")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("ゲームを追加", systemImage: "plus") {
                        isAddingGame = true
                    }
                }
            }
            .sheet(isPresented: $isAddingGame) {
                GameAddView()
            }
            .sheet(item: $editingGame) { game in
                GameEditView(game: game)
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
    }

    private func moveGames(from source: IndexSet, to destination: Int) {
        // 休止中も含む一覧全体を移動し、表示順を連番で保存する。
        var reorderedGames = games
        reorderedGames.move(fromOffsets: source, toOffset: destination)
        for (index, game) in reorderedGames.enumerated() {
            game.sortOrder = index
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            reorderError = error.localizedDescription
        }
    }
}
