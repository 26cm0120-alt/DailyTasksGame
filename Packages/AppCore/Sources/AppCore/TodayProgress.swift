public struct TodayProgress {
    public enum TaskStatus {
        case disabled
        case pending
        case completed
    }

    public let remaining: Int
    public let total: Int

    // タスク未登録と全件完了を区別する。
    public var isComplete: Bool { total > 0 && remaining == 0 }

    public init?(isActive: Bool, tasks: [TaskStatus]) {
        guard isActive else { return nil }
        remaining = tasks.count { $0 == .pending }
        total = tasks.count { $0 != .disabled }
    }

    public static func totalRemaining(in games: [TodayProgress]) -> Int {
        games.reduce(0) { $0 + $1.remaining }
    }
}
