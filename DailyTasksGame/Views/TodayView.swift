import AppCore
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Game.sortOrder) private var games: [Game]
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @Query private var records: [CompletionRecord]
    @State private var editMode: EditMode = .inactive
    @State private var completionTime = Date.now
    @State private var expandedCompletedGames: Set<UUID> = []
    @State private var completionError: String?
    @State private var isAddingGame = false
    @State private var reorderError: String?
    @State private var deletionTarget: Game?
    @State private var deletionError: String?

    var body: some View {
        let cards = makeCards()
        let nextReset = cards.compactMap { $0.nextReset?.end }.min()
        let nextMidnight = Calendar.autoupdatingCurrent.dateInterval(of: .day, for: completionTime)?.end
        let nextRefresh = [nextReset, nextMidnight].compactMap { $0 }.min()
        let activeRefresh = scenePhase == .active ? nextRefresh : nil

        NavigationStack {
            Group {
                if editMode.isEditing {
                    managementList
                } else {
                    todayList(cards)
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("今日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !games.isEmpty || editMode.isEditing {
                        Button(editMode.isEditing ? "完了" : "編集") {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("ゲームを追加", systemImage: "plus") {
                        isAddingGame = true
                    }
                }
            }
            .sheet(isPresented: $isAddingGame) {
                GameAddView(existingGameCount: games.count)
            }
            .alert("完了状態を更新できませんでした", isPresented: Binding(
                get: { completionError != nil },
                set: { if !$0 { completionError = nil } }
            )) {
                Button("OK", role: .cancel) { completionError = nil }
            } message: {
                Text(completionError ?? "")
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
        .onAppear { completionTime = .now }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { completionTime = .now }
        }
        .task(id: activeRefresh) {
            guard let activeRefresh else { return }
            await refresh(at: activeRefresh)
        }
    }

    private var managementList: some View {
        List {
            ForEach(games) { game in
                NavigationLink {
                    GameDetailView(game: game)
                } label: {
                    HStack {
                        Text(game.name)
                        if !game.isActive {
                            Spacer()
                            Text("休止中").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onMove(perform: moveGames)
            .onDelete(perform: requestGameDeletion)
        }
    }

    private func todayList(_ cards: [TodayCardData]) -> some View {
        List {
            TodayHeader(date: completionTime, progresses: cards.map(\.progress))
                .modifier(TodayListRow(insets: EdgeInsets(top: 10, leading: 16, bottom: 14, trailing: 16)))

            if cards.isEmpty {
                if games.isEmpty {
                    ContentUnavailableView {
                        Label("ゲームを登録", systemImage: "gamecontroller")
                    } description: {
                        Text("ゲームを追加すると、今日のタスクをここで確認できます。")
                    } actions: {
                        Button("ゲームを追加") { isAddingGame = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .modifier(TodayListRow())
                } else {
                    ContentUnavailableView {
                        Label("有効なゲームがありません", systemImage: "gamecontroller")
                    } description: {
                        Text("ゲームを追加するか、「編集」から休止中のゲームを開けます。")
                    }
                    .modifier(TodayListRow())
                }
            }

            ForEach(cards) { card in
                TodayGameCard(
                    data: card,
                    date: completionTime,
                    isExpanded: !card.progress.isComplete || expandedCompletedGames.contains(card.id),
                    toggleExpansion: { toggleExpansion(for: card.id) },
                    toggleTask: { toggleCompletion($0) }
                )
                .modifier(TodayListRow())
                .swipeActions(allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deletionTarget = card.game
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(TodayAurora().ignoresSafeArea())
        .onChange(of: cards.filter { $0.progress.isComplete }.map(\.id)) { _, completeIDs in
            expandedCompletedGames.formIntersection(completeIDs)
        }
    }

    private func makeCards() -> [TodayCardData] {
        let tasksByGame = Dictionary(grouping: tasks, by: { $0.game.id })
        let recordsByTask = Dictionary(grouping: records, by: { $0.task.id })
        let cards = games.compactMap { game in
            TodayCardData(
                game: game,
                tasks: tasksByGame[game.id, default: []],
                recordsByTask: recordsByTask,
                date: completionTime
            )
        }
        return cards.filter { !$0.progress.isComplete } + cards.filter { $0.progress.isComplete }
    }

    private func toggleExpansion(for id: UUID) {
        if expandedCompletedGames.remove(id) == nil {
            expandedCompletedGames.insert(id)
        }
    }

    private func refresh(at boundary: Date) async {
        do {
            // 画面を離れるか次の境界が変わると、待機が取り消される。
            var remaining = boundary.timeIntervalSinceNow
            while remaining > 0 {
                try await Task.sleep(for: .seconds(remaining))
                remaining = boundary.timeIntervalSinceNow
            }
            try Task.checkCancellation()
            completionTime = .now
        } catch is CancellationError {
            return
        } catch {
            completionError = error.localizedDescription
        }
    }

    private func toggleCompletion(_ row: TodayTaskData) {
        let now = Date.now
        defer { completionTime = now }
        guard row.task.isEnabled, row.task.game.isActive else { return }
        do {
            try TaskCompletion.toggleDisplayedPeriod(row.periodKey, for: row.task, context: modelContext, now: now)
        } catch {
            completionError = error.localizedDescription
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
