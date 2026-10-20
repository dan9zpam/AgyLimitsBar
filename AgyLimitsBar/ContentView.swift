import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var model: AgyStatusModel

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(statusColor)
                .font(.system(size: 13, weight: .semibold))
            
            if let pct = model.criticalPercent {
                Text("\(pct)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
            } else {
                Text("...")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var iconName: String {
        guard let pct = model.criticalPercent else { return "gauge.with.dots.needle.bottom.50percent" }
        if pct == 0 { return "exclamationmark.triangle.fill" }
        if pct < 20 { return "bolt.trianglebadge.exclamationmark.fill" }
        return "bolt.circle.fill"
    }

    private var statusColor: Color {
        guard let pct = model.criticalPercent else { return .secondary }
        if pct == 0 { return .red }
        if pct < 20 { return .orange }
        if pct < 50 { return .yellow }
        return .green
    }
}

struct ContentView: View {
    @EnvironmentObject var model: AgyStatusModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("AGY Limits")
                        .font(.system(size: 13, weight: .bold))
                    Text("Antigravity Quota Monitor")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: $model.selectedProfileForMenuBar) {
                    Text("Все профили").tag("All")
                    ForEach(model.availableProfiles, id: \.name) { profile in
                        Text(profile.name).tag(profile.name)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                
                Button(action: {
                    Task { await model.refresh() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(model.isLoading ? 360 : 0))
                        .animation(model.isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: model.isLoading)
                }
                .buttonStyle(.plain)
                .help("Обновить квоты")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

            Divider()

            // Profiles Content
            if model.profilesData.isEmpty && !model.isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("Данные лимитов недоступны")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Button("Проверить снова") {
                        Task { await model.refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(model.profilesData) { profileData in
                            ProfileCardView(profileData: profileData)
                        }
                    }
                    .padding(14)
                }
            }

            Divider()

            // Footer
            HStack(spacing: 12) {
                Button(action: {
                    model.openTerminal()
                }) {
                    Label("CLI Терминал", systemImage: "terminal.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Открыть agy в Terminal")

                Spacer()

                if let updated = model.lastUpdated {
                    Text("Обновлено \(updated, style: .relative) назад")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Button("Выход") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
        .frame(width: CGFloat(max(340, min(700, model.profilesData.count * 280))))
    }
}

struct ProfileCardView: View {
    let profileData: ProfileData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Profile Title Bar
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text(profileData.profile.name)
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text("активен")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if profileData.quotaEntries.isEmpty {
                Text("Квоты не найдены")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                // Group by Models
                if !profileData.geminiEntries.isEmpty {
                    ModelSectionView(
                        title: "Gemini Models",
                        icon: "sparkles",
                        accentColor: Color.blue,
                        entries: profileData.geminiEntries
                    )
                }

                if !profileData.claudeAndGptEntries.isEmpty {
                    ModelSectionView(
                        title: "Claude & GPT",
                        icon: "brain.head.profile",
                        accentColor: Color.purple,
                        entries: profileData.claudeAndGptEntries
                    )
                }
            }

            // Credits Card
            HStack(spacing: 8) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.purple)
                Text("Кредиты")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(profileData.credits.remaining)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(profileData.credits.remaining == 0 ? .secondary : .primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.separatorColor).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(12)
        .frame(width: 260)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(NSColor.separatorColor).opacity(0.2), lineWidth: 1)
        )
    }
}

struct ModelSectionView: View {
    let title: String
    let icon: String
    let accentColor: Color
    let entries: [QuotaEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            ForEach(entries) { entry in
                QuotaBarRow(entry: entry)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct QuotaBarRow: View {
    let entry: QuotaEntry

    private var barGradient: LinearGradient {
        if entry.percent <= 15 {
            return LinearGradient(colors: [Color.red, Color.pink], startPoint: .leading, endPoint: .trailing)
        } else if entry.percent <= 40 {
            return LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [Color.green, Color.teal], startPoint: .leading, endPoint: .trailing)
        }
    }

    private var pillBackground: Color {
        if entry.percent <= 15 { return Color.red.opacity(0.18) }
        if entry.percent <= 40 { return Color.orange.opacity(0.18) }
        return Color.green.opacity(0.18)
    }

    private var pillTextColor: Color {
        if entry.percent <= 15 { return .red }
        if entry.percent <= 40 { return .orange }
        return .green
    }

    private var labelIcon: String {
        entry.isFiveHour ? "clock.arrow.circlepath" : "calendar"
    }

    private var labelName: String {
        entry.isFiveHour ? "5-часовой лимит" : "Недельный лимит"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Image(systemName: labelIcon)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(labelName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Percentage Pill Badge
                Text("\(entry.percent)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(pillTextColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(pillBackground)
                    .clipShape(Capsule())
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(NSColor.separatorColor).opacity(0.2))
                        .frame(height: 6)

                    Capsule()
                        .fill(barGradient)
                        .frame(width: max(4, geo.size.width * CGFloat(entry.percent) / 100), height: 6)
                }
            }
            .frame(height: 6)

            // Friendly Reset Countdown
            HStack {
                Spacer()
                Text("сброс \(entry.friendlyReset)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
