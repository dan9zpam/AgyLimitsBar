import Foundation
import Combine
import AppKit

struct QuotaEntry: Identifiable {
    let id = UUID()
    let model: String
    let limitType: String
    let percent: Int
    let resetDate: String

    var isFiveHour: Bool {
        limitType.lowercased().contains("five hour") || limitType.lowercased().contains("5 hour")
    }

    var friendlyReset: String {
        AgyStatusModel.friendlyReset(resetDate)
    }
}

struct CreditsInfo {
    var remaining: Int
    var upgradeURL: String
}

struct AgyProfile: Hashable, Equatable, Identifiable {
    var id: String { name }
    let name: String
    let homePath: String
}

struct ProfileData: Identifiable {
    var id: String { profile.id }
    let profile: AgyProfile
    var quotaEntries: [QuotaEntry]
    var credits: CreditsInfo

    var geminiEntries: [QuotaEntry] {
        quotaEntries.filter { $0.model.localizedCaseInsensitiveContains("gemini") }
    }

    var claudeAndGptEntries: [QuotaEntry] {
        quotaEntries.filter { !$0.model.localizedCaseInsensitiveContains("gemini") }
    }
}

@MainActor
class AgyStatusModel: ObservableObject {
    @Published var profilesData: [ProfileData] = []
    @Published var availableProfiles: [AgyProfile] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil
    @Published var lastUpdated: Date? = nil

    @Published var selectedProfileForMenuBar: String {
        didSet {
            UserDefaults.standard.set(selectedProfileForMenuBar, forKey: "selectedProfileForMenuBar")
        }
    }

    private var timer: Timer?
    private let agyCLIPath: String

    init() {
        self.selectedProfileForMenuBar = UserDefaults.standard.string(forKey: "selectedProfileForMenuBar") ?? "All"
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/agy",
            "/usr/local/bin/agy",
            "/opt/homebrew/bin/agy"
        ]
        self.agyCLIPath = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? "\(NSHomeDirectory())/.local/bin/agy"
        
        Task { await self.refresh() }
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    func loadProfiles() {
        var profiles: [AgyProfile] = []
        let fm = FileManager.default
        let homeDir = URL(fileURLWithPath: NSHomeDirectory())
        
        // 1. Default profile
        profiles.append(AgyProfile(name: "agy", homePath: homeDir.path))
        
        // 2. Additional profiles
        if let contents = try? fm.contentsOfDirectory(at: homeDir, includingPropertiesForKeys: nil) {
            for url in contents {
                if url.lastPathComponent.hasPrefix(".agy-profile-") {
                    let geminiDir = url.appendingPathComponent(".gemini")
                    if fm.fileExists(atPath: geminiDir.path) {
                        let num = url.lastPathComponent.replacingOccurrences(of: ".agy-profile-", with: "")
                        let name = "agy" + num
                        profiles.append(AgyProfile(name: name, homePath: url.path))
                    }
                }
            }
        }
        
        self.availableProfiles = profiles.sorted { $0.name < $1.name }
    }

    func refresh() async {
        isLoading = true
        lastError = nil
        
        loadProfiles()
        
        let profilesToFetch = Array(availableProfiles.prefix(4))
        var newProfilesData: [ProfileData] = []
        
        await withTaskGroup(of: ProfileData?.self) { group in
            for p in profilesToFetch {
                group.addTask {
                    async let usageResult = Self.runAgy(args: ["--dangerously-skip-permissions", "-p", "/usage"], homePath: p.homePath, cliPath: self.agyCLIPath)
                    async let creditsResult = Self.runAgy(args: ["--dangerously-skip-permissions", "-p", "/credits"], homePath: p.homePath, cliPath: self.agyCLIPath)
                    
                    let (usageOut, creditsOut) = await (usageResult, creditsResult)
                    
                    var data = ProfileData(profile: p, quotaEntries: [], credits: CreditsInfo(remaining: 0, upgradeURL: ""))
                    if let u = usageOut { data.quotaEntries = Self.parseQuota(u) }
                    if let c = creditsOut { data.credits = Self.parseCredits(c) }
                    
                    return data
                }
            }
            
            for await result in group {
                if let data = result {
                    newProfilesData.append(data)
                }
            }
        }
        
        self.profilesData = newProfilesData.sorted { $0.profile.name < $1.profile.name }
        lastUpdated = Date()
        isLoading = false
    }

    func openTerminal() {
        let script = "tell application \"Terminal\" to do script \"agy\" activate"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    nonisolated private static func runAgy(args: [String], homePath: String, cliPath: String) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: cliPath)
                process.arguments = args
                
                var env = ProcessInfo.processInfo.environment
                env["HOME"] = homePath
                process.environment = env

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    nonisolated private static func parseQuota(_ output: String) -> [QuotaEntry] {
        var entries: [QuotaEntry] = []
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.lowercased().hasPrefix("quota") else { continue }
            
            let parts = trimmed.components(separatedBy: "\t")
            if parts.count >= 4 {
                let model = parts[0].trimmingCharacters(in: .whitespaces)
                let limitType = parts[1].trimmingCharacters(in: .whitespaces)
                let pctString = parts[2].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")
                let percent = Int(pctString) ?? 0
                let date = parts[3].trimmingCharacters(in: .whitespaces)
                entries.append(QuotaEntry(model: model, limitType: limitType, percent: percent, resetDate: date))
                continue
            }
            
            let pattern = #"^(.+?)\s{2,}(.+?)\s{2,}(\d+)%\s+(.+)$"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                
                func group(_ i: Int) -> String {
                    guard let range = Range(match.range(at: i), in: trimmed) else { return "" }
                    return String(trimmed[range]).trimmingCharacters(in: .whitespaces)
                }
                
                let model = group(1)
                let limitType = group(2)
                let percent = Int(group(3)) ?? 0
                let date = group(4)
                
                entries.append(QuotaEntry(model: model, limitType: limitType, percent: percent, resetDate: date))
            }
        }
        return entries
    }

    nonisolated private static func parseCredits(_ output: String) -> CreditsInfo {
        var remaining = 0
        var url = ""
        
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().contains("remaining credits") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let last = parts.last, let val = Int(last) {
                    remaining = val
                }
            } else if trimmed.lowercased().contains("upgrade") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let last = parts.last, last.hasPrefix("http") {
                    url = last
                }
            }
        }
        return CreditsInfo(remaining: remaining, upgradeURL: url)
    }

    nonisolated static func friendlyReset(_ str: String) -> String {
        let f1 = ISO8601DateFormatter()
        if let d = f1.date(from: str) {
            return formatRelative(d)
        }
        let parts = str.components(separatedBy: " ")
        if parts.count >= 2 {
            let dtPart = "\(parts[0]) \(parts[1])"
            let f2 = DateFormatter()
            f2.locale = Locale(identifier: "en_US_POSIX")
            f2.dateFormat = "yyyy-MM-dd HH:mm"
            if parts.count >= 3 && parts[2] == "MSK" {
                f2.timeZone = TimeZone(identifier: "Europe/Moscow")
            }
            if let d = f2.date(from: dtPart) {
                return formatRelative(d)
            }
        }
        return str
    }

    nonisolated static func formatRelative(_ targetDate: Date) -> String {
        let now = Date()
        let diff = targetDate.timeIntervalSince(now)
        if diff <= 0 { return "сейчас" }
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        if hours > 24 {
            let days = hours / 24
            return "\(days)д \(hours % 24)ч"
        } else if hours > 0 {
            return "\(hours)ч \(minutes)м"
        } else {
            return "\(max(1, minutes))м"
        }
    }

    var criticalPercent: Int? {
        let entries: [QuotaEntry]
        if selectedProfileForMenuBar == "All" {
            entries = profilesData.flatMap { $0.quotaEntries }
        } else {
            entries = profilesData.first(where: { $0.profile.name == selectedProfileForMenuBar })?.quotaEntries ?? []
        }
        let fiveHour = entries.filter { $0.isFiveHour }
        return fiveHour.map { $0.percent }.min()
    }
}
