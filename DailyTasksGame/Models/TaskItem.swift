import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    var game: Game
    var title: String
    var kind: TaskKind
    var isEnabled: Bool
    var sortOrder: Int

    // 削除の連鎖に必要な、CompletionRecord.task の逆参照。
    @Relationship(deleteRule: .cascade, inverse: \CompletionRecord.task)
    var completionRecords: [CompletionRecord] = []

    init(
        title: String,
        game: Game,
        sortOrder: Int,
        kind: TaskKind = .daily,
        isEnabled: Bool = true
    ) throws {
        try validateModelName(title)
        self.id = UUID()
        self.game = game
        self.title = title
        self.kind = kind
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
    }
}
