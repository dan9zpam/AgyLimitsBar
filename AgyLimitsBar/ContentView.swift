import SwiftUI

enum ViewFilter: String, CaseIterable, Identifiable {
    case claude = "Claude"
    case agy = "Antigravity"
    case all = "Все"

    var id: String { rawValue }
}

struct MenuBarLabel: View {
    @ObservedObject var model: AgyStatusModel

    var body: some View {
        HStack(spacing: 5) {
            AnimatedAgentIcon(model: model, animator: model.animator)
            
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

    private var statusColor: Color {
        guard let pct = model.criticalPercent else { return .secondary }
        if pct == 0 { return .red }
        if pct < 20 { return .orange }
        if pct < 50 { return .yellow }
        return .green
    }
}

/// The only views subscribed to animation ticks, so a frame change redraws
/// just the icon and not the popover around it.
struct AnimatedAgentIcon: View {
    let model: AgyStatusModel
    @ObservedObject var animator: AgentAnimator
    var fallback: NSImage? = nil
    var animated: Bool = true

    var body: some View {
        Image(nsImage: animated || fallback == nil ? model.menuBarIcon : fallback!)
    }
}

private struct CardsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ContentView: View {
    @EnvironmentObject var model: AgyStatusModel
    @State private var selectedFilter: ViewFilter = .claude

    private var filteredProfiles: [ProfileData] {
        switch selectedFilter {
        case .claude:
            return model.profilesData.filter { $0.isClaude }
        case .agy:
            return model.profilesData.filter { !$0.isClaude }
        case .all:
            return model.profilesData
        }
    }

    private var headerTitle: String {
        switch selectedFilter {
        case .claude: return "Claude Limits"
        case .agy: return "AGY Limits"
        case .all: return "AI Limits Bar"
        }
    }

    private var headerSubtitle: String {
        switch selectedFilter {
        case .claude: return "Claude Code Subscription Monitor"
        case .agy: return "Gemini Quota Monitor"
        case .all: return "Claude & Antigravity Quota Monitor"
        }
    }

    private var headerGradientColors: [Color] {
        switch selectedFilter {
        case .claude:
            return [Color(red: 0.92, green: 0.48, blue: 0.28), Color.orange]
        case .agy:
            return [Color.blue, Color(red: 0.35, green: 0.55, blue: 0.95)]
        case .all:
            return [Color.blue, Color(red: 0.85, green: 0.44, blue: 0.28)]
        }
    }

    /// Keep the popover on screen: header, tabs and footer take ~150pt.
    private static var maxContentHeight: CGFloat {
        max(300, (NSScreen.main?.visibleFrame.height ?? 900) - 190)
    }

    private static var maxContentWidth: CGFloat {
        max(340, min(900, (NSScreen.main?.visibleFrame.width ?? 1200) - 40))
    }

    private static let cardWidth: CGFloat = 260
    private static let cardSpacing: CGFloat = 14

    private var gridColumns: Int {
        let fit = Int((Self.maxContentWidth - 28 + Self.cardSpacing) / (Self.cardWidth + Self.cardSpacing))
        return max(1, min(filteredProfiles.count, fit))
    }

    private var gridWidth: CGFloat {
        let n = CGFloat(gridColumns)
        return max(340, n * Self.cardWidth + (n - 1) * Self.cardSpacing + 28)
    }

    // Estimate for the first frame until the grid is measured.
    @State private var cardsHeight: CGFloat = 560

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: headerGradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    // Static inside the popover: continuously animating views here
                    // break scrolling and clicks; the menu bar icon carries the animation.
                    Image(nsImage: selectedFilter == .claude ? BrandIcons.clawdIdle : BrandIcons.geminiIdle)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(headerTitle)
                        .font(.system(size: 13, weight: .bold))
                    Text(headerSubtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Profile selector for Menu Bar
                Picker("", selection: $model.selectedProfileForMenuBar) {
                    ForEach(model.availableProfiles, id: \.name) { profile in
                        Text(profile.displayName).tag(profile.name)
                    }
                    Text("Все (минимум)").tag("All")
                }
                .pickerStyle(.menu)
                .frame(width: 140)
                .help("Выберите, чей процент показывать в меню-баре")
                
                // Native spinner while loading: a repeatForever SwiftUI rotation kept
                // re-rendering the popover for the whole refresh.
                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                        .help("Обновление…")
                } else {
                    Button(action: {
                        Task { await model.refresh() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 16, height: 16)
                    .help("Обновить квоты")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

            // Provider Switcher Tabs (Claude first by default)
            Picker("Провайдер", selection: $selectedFilter) {
                ForEach(ViewFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            // Profiles Content
            if filteredProfiles.isEmpty && !model.isLoading {
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
                .frame(maxWidth: .infinity, minHeight: 180)
                .padding(.vertical, 32)
            } else {
                // Cards wrap into a grid that fits the screen width, so only vertical
                // scrolling is ever needed (works with a plain mouse wheel too).
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(minimum: Self.cardWidth), spacing: Self.cardSpacing, alignment: .top),
                            count: gridColumns
                        ),
                        alignment: .leading,
                        spacing: Self.cardSpacing
                    ) {
                        ForEach(filteredProfiles) { profileData in
                            ProfileCardView(profileData: profileData)
                        }
                    }
                    .padding(14)
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: CardsHeightKey.self, value: geo.size.height)
                    })
                }
                // A vertical ScrollView has no height of its own and would collapse
                // the popover: use the measured grid height, capped to the screen.
                .frame(
                    width: gridWidth,
                    height: min(max(cardsHeight, 200), Self.maxContentHeight)
                )
                .onPreferenceChange(CardsHeightKey.self) { cardsHeight = $0 }
            }

            Divider()

            // Footer
            HStack(spacing: 10) {
                Text("CLI:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Button("claude") {
                    model.openTerminal(command: "claude")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Открыть claude в Terminal")

                Button("agy") {
                    model.openTerminal(command: "agy")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Открыть agy в Terminal")

                if model.monitorCLIPath != nil {
                    Button("monitor") {
                        model.openMonitor()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Открыть полный Claude Code Usage Monitor в Terminal")
                }

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
        // MenuBarExtra sizes its window from the content's fitting size. Flexible
        // content reports 0x0 and leaves the window stuck at 340x280 with the
        // header/footer pushed outside it, so pin the width and use ideal heights.
        .frame(width: gridWidth)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ProfileCardView: View {
    @EnvironmentObject var model: AgyStatusModel
    let profileData: ProfileData

    private var claudeAccent: Color {
        Color(red: 0.85, green: 0.44, blue: 0.28)
    }

    private var geminiAccent: Color {
        Color(red: 0.31, green: 0.51, blue: 0.93)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Profile Title Bar
            HStack(spacing: 6) {
                Circle()
                    .fill(profileData.isAuthenticated ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                
                Image(nsImage: profileData.isClaude ? BrandIcons.clawdIdle : BrandIcons.geminiIdle)

                Text(profileData.profile.displayName)
                    .font(.system(size: 13, weight: .bold))

                Spacer()

                Text(statusBadgeText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if !profileData.isAuthenticated {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Аккаунт еще не авторизован")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    
                    Button("Войти (\(profileData.profile.name))") {
                        model.openTerminal(command: profileData.profile.name)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.vertical, 8)
            } else if profileData.quotaEntries.isEmpty {
                Text("Квоты не найдены")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                if profileData.isClaude {
                    ModelSectionView(
                        title: "Claude Code Limits",
                        icon: "claude",
                        accentColor: claudeAccent,
                        entries: profileData.quotaEntries
                    )
                } else {
                    // For AGY: Strictly output only Gemini limits as requested
                    if !profileData.geminiEntries.isEmpty {
                        ModelSectionView(
                            title: "Gemini Models",
                            icon: "googlegemini",
                            accentColor: geminiAccent,
                            entries: profileData.geminiEntries
                        )
                    }
                }
            }

            // claude-monitor analytics: cost, tokens, burn rate, pace, forecast, models
            if profileData.isClaude && profileData.isAuthenticated {
                MonitorAnalyticsView(accentColor: claudeAccent)
            }

            // Info Card (Credits for AGY / Account link for Claude)
            if profileData.isClaude {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 11))
                        .foregroundStyle(claudeAccent)
                    Text("Тариф")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: {
                        if let url = URL(string: profileData.credits.upgradeURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Text(profileData.tier.isEmpty ? "Активен" : profileData.tier)
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 9))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(claudeAccent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.separatorColor).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(geminiAccent)
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
        }
        .padding(12)
        .frame(minWidth: 260, maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(profileData.isClaude ? claudeAccent.opacity(0.3) : geminiAccent.opacity(0.2), lineWidth: 1)
        )
    }

    private var statusBadgeText: String {
        if !profileData.isAuthenticated {
            return "требуется вход"
        }
        if profileData.isClaude && !profileData.tier.isEmpty {
            return profileData.tier
        }
        return "активен"
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
                if icon == "claude" {
                    Image(nsImage: BrandIcons.clawdIdle)
                } else if icon == "googlegemini" {
                    Image(nsImage: BrandIcons.geminiIdle)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accentColor)
                }

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
        let low = entry.limitType.lowercased()
        if low.contains("сессия") || low.contains("session") {
            return "Сессия (5 часов)"
        }
        return entry.isFiveHour ? "5-часовой лимит" : "Недельный лимит"
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
