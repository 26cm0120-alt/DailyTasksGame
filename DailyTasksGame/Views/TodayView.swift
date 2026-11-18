import AppCore
import SwiftData
import SwiftUI

struct TodayView: View {
    @Query(sort: \Game.sortOrder) private var games: [Game]
    @State private var isAddingGame = false

    var body: some View {
        NavigationStack {
            List(games) { game in
                Text(game.name)
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
        }
    }
}
