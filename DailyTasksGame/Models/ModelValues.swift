import Foundation

// 日付やタイムゾーンを含めず、設定された時・分だけを保存する。
nonisolated struct ResetTime: Codable, Equatable, Sendable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        precondition((0...23).contains(hour) && (0...59).contains(minute))
        self.hour = hour
        self.minute = minute
    }
}

nonisolated enum TaskKind: String, Codable, Sendable {
    case daily
    case weekly
}

nonisolated enum ModelInputError: Error, Equatable {
    case emptyName
}

// 空白を除くのは判定時だけとし、保存する名前は加工しない。
func validateModelName(_ name: String) throws {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw ModelInputError.emptyName
    }
}
