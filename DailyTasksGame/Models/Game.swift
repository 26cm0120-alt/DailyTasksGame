import Foundation
import SwiftData

@Model
final class Game {
    var id: UUID
    var name: String
    var resetTime: ResetTime
    var weeklyResetWeekday: Int
    var weeklyResetTime: ResetTime
    var isActive: Bool
    var sortOrder: Int
    var note: String

    // 削除の連鎖に必要な、TaskItem.game の逆参照。
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.game)
    var tasks: [TaskItem] = []

    init(
        name: String,
        sortOrder: Int,
        resetTime: ResetTime = ResetTime(hour: 5, minute: 0),
        weeklyResetWeekday: Int = 2,
        weeklyResetTime: ResetTime? = nil,
        isActive: Bool = true,
        note: String = ""
    ) throws {
        try validateModelName(name)
        precondition((1...7).contains(weeklyResetWeekday))
        self.id = UUID()
        self.name = name
        self.resetTime = resetTime
        self.weeklyResetWeekday = weeklyResetWeekday
        // 初期化後は独立した値として保持し、日次の変更には追従させない。
        self.weeklyResetTime = weeklyResetTime ?? resetTime
        self.isActive = isActive
        self.sortOrder = sortOrder
        self.note = note
    }
}
