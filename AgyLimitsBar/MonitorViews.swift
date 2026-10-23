import SwiftUI
import AppKit

// Claude card section fed by claude-monitor: session cost/tokens, burn rate,
// pace against the 5-hour window, forecast, model mix and 7-day history.
struct MonitorAnalyticsView: View {
    @EnvironmentObject var model: AgyStatusModel
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accentColor)
                Text("Аналитика сессии")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                if let snapshot = model.monitorSnapshot {
                    ConfidenceBadge(isOfficial: snapshot.isOfficial)
                }
            }

            if model.monitorCLIPath == nil {
                MonitorMissingView()
            } else if let snapshot = model.monitorSnapshot {
                content(snapshot)
            } else {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Считаю расход…")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func content(_ snapshot: MonitorSnapshot) -> some View {
        if let local = snapshot.local, local.isActive {
            HStack(spacing: 6) {
                StatTile(value: Fmt.usd(local.costUsd ?? 0), caption: "стоимость", tint: accentColor)
                StatTile(value: Fmt.tokens(local.tokens?.totalTokens ?? 0), caption: "токенов", tint: .blue)
                StatTile(value: "\(local.sentMessages ?? 0)", caption: "сообщений", tint: .purple)
            }

            if let pace = snapshot.pace, let used = pace.usedPercentage, let elapsed = pace.elapsedPercentage {
                PaceRow(label: pace.label ?? "unknown", used: used, elapsed: elapsed)
            }

            if let tpm = local.burnRateTokensPerMinute {
                InfoRow(icon: "flame.fill", tint: .orange, title: "Расход",
                        value: "\(Fmt.tokens(Int(tpm)))/мин · \(Fmt.usd(local.burnRateCostPerHour ?? 0))/ч")
            }

            if let forecast = snapshot.forecast, let text = Fmt.forecast(forecast) {
                InfoRow(icon: "hourglass", tint: .teal, title: "Прогноз", value: text)
            }

            if let models = local.modelDistribution, !models.isEmpty {
                ModelMixBar(models: models)
            }
        } else {
            Text("Нет активной 5-часовой сессии")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }

        if !model.dailyUsage.isEmpty {
            DailyHistoryChart(days: model.dailyUsage, accentColor: accentColor)
        } else if let history = snapshot.localHistory, let cost = history.totalCostUsd {
            InfoRow(icon: "clock.arrow.circlepath", tint: .secondary, title: "За период",
                    value: "\(Fmt.usd(cost)) · \(Fmt.tokens(history.totalTokens ?? 0))")
        }
    }
}

// MARK: - Pieces

private struct ConfidenceBadge: View {
    let isOfficial: Bool

    var body: some View {
        Text(isOfficial ? "официально" : "оценка")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(isOfficial ? Color.green : Color.orange)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background((isOfficial ? Color.green : Color.orange).opacity(0.15))
            .clipShape(Capsule())
            .help(isOfficial
                  ? "Лимиты получены от Anthropic (через Claude Code)"
                  : "Лимиты оценены по локальным логам Claude Code")
    }
}

private struct StatTile: View {
    let value: String
    let caption: String
    let tint: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.system(size: 8.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .animation(.easeOut(duration: 0.4), value: value)
    }
}

private struct InfoRow: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(tint)
                .frame(width: 12)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// Used share of the 5-hour window vs time elapsed in it: a bar ahead of the
/// time marker means usage is outpacing the window.
private struct PaceRow: View {
    let label: String
    let used: Double
    let elapsed: Double

    private var tint: Color {
        switch label {
        case "slow down": return .red
        case "speed up": return .green
        default: return .blue
        }
    }

    private var title: String {
        switch label {
        case "slow down": return "Притормозите"
        case "speed up": return "Есть запас"
        case "on track": return "В темпе"
        default: return "Темп неизвестен"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "speedometer")
                    .font(.system(size: 9))
                    .foregroundStyle(tint)
                    .frame(width: 12)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
                Text("\(Int(used.rounded()))% из \(Int(elapsed.rounded()))% окна")
                    .font(.system(size: 9.5, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(NSColor.separatorColor).opacity(0.2))
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: max(4, geo.size.width * min(used, 100) / 100))
                    // Time marker: where usage "should" be at an even pace.
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.primary.opacity(0.7))
                        .frame(width: 2, height: 9)
                        .offset(x: max(0, geo.size.width * min(elapsed, 100) / 100 - 1))
                }
            }
            .frame(height: 5)
            .animation(.easeOut(duration: 0.6), value: used)
        }
    }
}

private struct ModelMixBar: View {
    let models: [MonitorSnapshot.ModelShare]

    private func color(_ family: String) -> Color {
        switch family {
        case "opus": return Color(red: 0.85, green: 0.44, blue: 0.28)
        case "sonnet": return .purple
        case "haiku": return .teal
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(models) { m in
                        Rectangle()
                            .fill(color(m.family))
                            .frame(width: max(2, geo.size.width * m.percentage / 100))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 5)

            HStack(spacing: 8) {
                ForEach(models) { m in
                    HStack(spacing: 3) {
                        Circle().fill(color(m.family)).frame(width: 6, height: 6)
                        Text("\(m.family.capitalized) \(Int(m.percentage.rounded()))%")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct DailyHistoryChart: View {
    let days: [DailyUsage]
    let accentColor: Color
    @State private var appeared = false

    private var maxCost: Double { max(days.map(\.totalCost).max() ?? 0, 0.01) }
    private var total: Double { days.reduce(0) { $0 + $1.totalCost } }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("За \(days.count) \(Fmt.days(days.count))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Fmt.usd(total))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(days) { day in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(accentColor.gradient)
                            .frame(height: appeared ? max(2, 26 * day.totalCost / maxCost) : 2)
                        Text(day.shortLabel)
                            .font(.system(size: 7.5))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: 30)
                    .frame(maxWidth: .infinity)
                    .help("\(day.date): \(Fmt.usd(day.totalCost)), \(Fmt.tokens(day.totalTokens)) токенов")
                }
            }
            .frame(height: 38, alignment: .bottom)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { appeared = true }
        }
    }
}

private struct MonitorMissingView: View {
    private let command = "uv tool install claude-monitor"

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Установите claude-monitor, чтобы видеть стоимость, расход и прогноз.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            } label: {
                Label(command, systemImage: "doc.on.doc")
                    .font(.system(size: 9.5, design: .monospaced))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help("Скопировать команду установки")
        }
    }
}

// MARK: - Formatting

enum Fmt {
    static func tokens(_ n: Int) -> String {
        let v = Double(n)
        if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        if v >= 1_000 { return String(format: "%.1fK", v / 1_000) }
        return "\(n)"
    }

    static func days(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "день" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "дня" }
        return "дней"
    }

    static func usd(_ v: Double) -> String {
        v >= 100 ? String(format: "$%.0f", v) : String(format: "$%.2f", v)
    }

    /// The snapshot's `display` is formatted in UTC; rebuild it in local time.
    static func forecast(_ f: MonitorSnapshot.Forecast) -> String? {
        switch f.display {
        case "within limit until reset": return "хватит до сброса"
        case "limit hit": return "лимит исчерпан"
        default: break
        }
        guard let epoch = f.predictedTokensExhaustedEpoch else { return nil }
        let date = Date(timeIntervalSince1970: epoch)
        let time = date.formatted(date: .omitted, time: .shortened)
        let cal = Calendar.current
        let day = cal.isDateInToday(date) ? "сегодня" : cal.isDateInTomorrow(date) ? "завтра"
            : date.formatted(.dateTime.day().month())
        let estimate = f.confidence == "local_estimate" ? " (оценка)" : ""
        return "лимит \(day) в \(time)\(estimate)"
    }
}
