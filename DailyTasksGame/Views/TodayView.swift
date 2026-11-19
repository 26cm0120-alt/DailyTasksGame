import AppCore
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Game.sortOrder) private var games: [Game]
    @State private var isAddingGame = false
    @State private var reorderError: String?
    @State private var deletionTarget: Game?
    @State private var deletionError: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(games) { game in
                    NavigationLink {
                        GameDetailView(game: game)
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
                .onDelete(perform: requestGameDeletion)
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
            .alert("並び順を保存できませんでした", isPresented: Binding(
                get: { reorderError != nil },
                set: { if !$0 { reorderError = nil } }
            )) {
                Button("OK", role: .cancel) { reorderError = nil }
            } message: {
                Text(reorderError ?? "")
            }
            .alert(item: $deletionTarget) { game in
                Alert(
                    title: Text("ゲームを削除しますか"),
                    message: Text("「\(game.name)」を削除します。\nタスクと完了記録もすべて削除されます。"),
                    primaryButton: .destructive(Text("削除")) {
                        deleteGame(game)
                    },
                    secondaryButton: .cancel(Text("やめる"))
                )
            }
            .alert("ゲームを削除できませんでした", isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )) {
                Button("OK", role: .cancel) { deletionError = nil }
            } message: {
                Text(deletionError ?? "")
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

    private func requestGameDeletion(at offsets: IndexSet) {
        guard let index = offsets.first, games.indices.contains(index) else { return }
        deletionTarget = games[index]
    }

    private func deleteGame(_ game: Game) {
        let remainingGames = games.filter { $0.id != game.id }

        modelContext.delete(game)
        for (index, remainingGame) in remainingGames.enumerated() {
            remainingGame.sortOrder = index
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deletionError = error.localizedDescription
        }
    }
}
