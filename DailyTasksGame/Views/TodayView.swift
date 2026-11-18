import AppCore
import SwiftData
import SwiftUI

struct TodayView: View {
    @Query(sort: \Game.sortOrder) private var games: [Game]
    @State private var isAddingGame = false
    @State private var editingGame: Game?

    var body: some View {
        NavigationStack {
            List(games) { game in
                Button {
                    editingGame = game
                } label: {
                    Text(game.name)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("今日")
            .toolbar {
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
        }
    }
}
