import Foundation
import SwiftData

@Model
final class CompletionRecord {
    var id: UUID
    var task: TaskItem
    var periodKey: String
    var completedAt: Date

    init(task: TaskItem, periodKey: String, completedAt: Date) {
        self.id = UUID()
        self.task = task
        self.periodKey = periodKey
        self.completedAt = completedAt
    }
}
