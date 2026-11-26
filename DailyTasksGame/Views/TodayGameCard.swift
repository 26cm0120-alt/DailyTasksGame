import AppCore
import SwiftUI

struct TodayTaskData: Identifiable {
    let task: TaskItem
    let periodKey: String?
    let isCompleted: Bool

    var id: UUID { task.id }
}

struct TodayCardData: Identifiable {
    let game: Game
    let tasks: [TodayTaskData]
    let progress: TodayProgress
    let nextReset: (kind: TaskKind, end: Date)?

    var id: UUID { game.id }

    init?(game: Game, tasks: [TaskItem], recordsByTask: [UUID: [CompletionRecord]], date: Date) {
        let periods = game.isActive ? TaskCompletion.periods(for: game, now: date) : nil
        let rows = tasks.filter(\.isEnabled).map { task in
            let key = TaskCompletion.periodKey(for: task.kind, in: periods)
            return TodayTaskData(
                task: task,
                periodKey: key,
                isCompleted: TaskCompletion.isCompleted(in: recordsByTask[task.id, default: []], periodKey: key)
            )
        }
        let statuses: [TodayProgress.TaskStatus] = rows.map { $0.isCompleted ? .completed : .pending }
        let disabled = Array(repeating: TodayProgress.TaskStatus.disabled, count: tasks.count - rows.count)
        guard let progress = TodayProgress(isActive: game.isActive, tasks: statuses + disabled) else { return nil }

        self.game = game
        self.tasks = rows
        self.progress = progress
        nextReset = periods.map { periods in
            if periods.daily.end <= periods.weekly.end {
                return (.daily, periods.daily.end)
            }
            return (.weekly, periods.weekly.end)
        }
    }
}

struct TodayHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize = 48
    let date: Date
    let progresses: [TodayProgress]

    private var remaining: Int { TodayProgress.totalRemaining(in: progresses) }
    private var total: Int { progresses.reduce(0) { $0 + $1.total } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 12) {
                    title
                    Spacer(minLength: 8)
                    count
                }
                VStack(alignment: .leading, spacing: 10) {
                    title
                    count
                }
            }
            if total > 0 {
                ProgressView(value: Double(total - remaining), total: Double(total))
                    .tint(colorScheme == .dark ? Color.teal : Color.indigo)
                    .accessibilityLabel("全体の進捗")
                    .accessibilityValue("\(total - remaining)件完了、全\(total)件")
            }
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(date, format: .dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP")))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("今日のタスク")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var count: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("全体の残り")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(remaining, format: .number)
                    .font(.system(size: numberSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("件").font(.subheadline.weight(.semibold))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct TodayGameCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .title2) private var numberSize = 32
    let data: TodayCardData
    let date: Date
    let isExpanded: Bool
    let toggleExpansion: () -> Void
    let toggleTask: (TodayTaskData) -> Void

    private var accent: Color { GamePaletteColors.color(at: data.game.colorPaletteIndex, scheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                GameDetailView(game: data.game)
            } label: {
                HStack(spacing: 9) {
                    Circle().fill(accent).frame(width: 9, height: 9)
                        .accessibilityHidden(true)
                    Text(data.game.name)
                        .font(.headline)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("ゲームの詳細を開く")

            resetLabel

            if isExpanded {
                if data.tasks.isEmpty {
                    Text("有効なタスクがありません")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(data.tasks) { row in
                            taskRow(row)
                        }
                    }
                }
            }

            if data.progress.isComplete {
                Button(action: toggleExpansion) {
                    HStack {
                        Label("完了", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("残り0件／全\(data.progress.total)件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(isExpanded ? "展開中" : "折りたたみ中")
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("残り").foregroundStyle(.secondary)
                    Text(data.progress.remaining, format: .number)
                        .font(.system(size: numberSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(accent)
                    Text("件／全\(data.progress.total)件").foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(14)
        .background {
            let shape = RoundedRectangle(cornerRadius: 23)
            shape.fill(.thinMaterial)
                .overlay {
                    shape.fill(colorScheme == .dark ? Color.white.opacity(0.035) : Color.white.opacity(0.62))
                }
                .overlay {
                    shape.fill(RadialGradient(
                        colors: [accent.opacity(colorScheme == .dark ? 0.20 : 0.13), .clear],
                        center: .topTrailing, startRadius: 0, endRadius: 135
                    ))
                }
                .overlay {
                    shape.strokeBorder(.white.opacity(colorScheme == .dark ? 0.14 : 0.8))
                }
        }
    }

    @ViewBuilder
    private var resetLabel: some View {
        if let reset = data.nextReset {
            let kind = reset.kind == .daily ? "日次" : "週次"
            let format: Date.FormatStyle = reset.kind == .daily
                ? .dateTime.hour().minute()
                : .dateTime.weekday(.abbreviated).hour().minute()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) {
                    Text("\(kind)リセット \(reset.end.formatted(format))")
                    Spacer()
                    countdown(to: reset.end)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(kind)リセット \(reset.end.formatted(format))")
                    countdown(to: reset.end)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func countdown(to end: Date) -> some View {
        HStack(spacing: 4) {
            Text("あと")
            Text(timerInterval: date...end, countsDown: true, showsHours: true)
                .monospacedDigit()
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }

    private func taskRow(_ row: TodayTaskData) -> some View {
        Button {
            toggleTask(row)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: row.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(row.isCompleted ? accent : Color.secondary)
                    .accessibilityHidden(true)
                Text(row.task.title)
                    .font(.subheadline)
                    .strikethrough(row.isCompleted)
                    .foregroundStyle(row.isCompleted ? .secondary : .primary)
                Spacer(minLength: 6)
                Text(row.task.kind == .daily ? "デイリー" : "ウィークリー")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(row.isCompleted ? "完了" : "未完了")
    }
}

struct TodayListRow: ViewModifier {
    var insets = EdgeInsets(top: 0, leading: 16, bottom: 10, trailing: 16)

    func body(content: Content) -> some View {
        content
            .listRowInsets(insets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

struct TodayAurora: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        ZStack {
            isDark ? Color(red: 0.065, green: 0.07, blue: 0.12) : Color(red: 0.96, green: 0.96, blue: 0.94)
            RadialGradient(colors: [.purple.opacity(isDark ? 0.42 : 0.19), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 340)
            RadialGradient(colors: [.cyan.opacity(isDark ? 0.24 : 0.18), .clear],
                           center: UnitPoint(x: 1, y: 0.28), startRadius: 0, endRadius: 275)
            RadialGradient(colors: [.mint.opacity(isDark ? 0.20 : 0.22), .clear],
                           center: .bottom, startRadius: 0, endRadius: 310)
        }
        .accessibilityHidden(true)
    }
}
