import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var model: AgyStatusModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.circle.fill")
                .foregroundStyle(iconColor)
            if let pct = model.criticalPercent {
                Text("\(pct)%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            } else {
                Text("...")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
        }
    }

    private var iconColor: Color {
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
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.blue)
                Text("AGY Limits")
                    .font(.headline)
                Spacer()
                if model.isLoading {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Button(action: { Task { await model.refresh() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            if model.profilesData.isEmpty && !model.isLoading {
                Text("No data available")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding()
            } else {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(model.profilesData) { profileData in
                        ProfileColumnView(profileData: profileData)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Divider()

            // Footer
            HStack {
                if let updated = model.lastUpdated {
                    Text("Updated \(updated, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: CGFloat(max(320, model.profilesData.count * 240)))
    }
}

struct ProfileColumnView: View {
    let profileData: ProfileData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.secondary)
                Text(profileData.profile.name)
                    .font(.subheadline)
                    .bold()
            }
            
            if profileData.quotaEntries.isEmpty {
                Text("No quota available")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(profileData.quotaEntries) { entry in
                    QuotaRow(entry: entry)
                }
            }
            
            Divider()
            
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(.purple)
                    .font(.caption2)
                Text("Credits")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(profileData.credits.remaining)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(profileData.credits.remaining == 0 ? .red : .primary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuotaRow: View {
    let entry: QuotaEntry

    private var isFiveHour: Bool {
        entry.limitType.lowercased().contains("five hour") || entry.limitType.lowercased().contains("5 hour")
    }

    private var barColor: Color {
        if entry.percent == 0 { return .red }
        if entry.percent < 20 { return .orange }
        if entry.percent < 50 { return .yellow }
        return .green
    }

    private var resetDateFormatted: String {
        // Parse ISO8601 date and show friendly time
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: entry.resetDate) {
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .abbreviated
            return "resets " + rel.localizedString(for: date, relativeTo: Date())
        }
        return entry.resetDate
    }

    private var statusText: String {
        if entry.percent < 20 { return "\(entry.percent)%" }
        if entry.percent < 50 { return "\(entry.percent)%" }
        return "\(entry.percent)%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.model)
                        .font(.system(size: 12, weight: .medium))
                    HStack(spacing: 4) {
                        Text(entry.limitType)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if isFiveHour {
                            Text("⏱")
                                .font(.caption2)
                        }
                    }
                }
                Spacer()
                Text(statusText)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(barColor)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * CGFloat(entry.percent) / 100), height: 5)
                }
            }
            .frame(height: 5)

            Text(resetDateFormatted)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
