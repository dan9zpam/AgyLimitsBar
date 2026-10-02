import Foundation
import Combine

struct QuotaEntry: Identifiable {
    let id = UUID()
    let model: String
    let limitType: String
    let percent: Int
    let resetDate: String
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
}

@MainActor
class AgyStatusModel: ObservableObject {
    @Published var profilesData: [ProfileData] = []
    @Published var availableProfiles: [AgyProfile] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil
    @Published var lastUpdated: Date? = nil

    private var timer: Timer?
    private let agyCLIPath: String

    init() {
        // Try common locations for agy binary
        let candidates = [
            "/Users/\(NSUserName())/.local/bin/agy",
            "/usr/local/bin/agy",
            "/opt/homebrew/bin/agy"
        ]
        self.agyCLIPath = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? "/usr/local/bin/agy"
        
        Task { await self.refresh() }
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        // Refresh every 60 seconds
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
        
        let profilesToFetch = Array(availableProfiles.prefix(3))
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

    nonisolated private static func runAgy(args: [String], homePath: String, cliPath: String) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: cliPath)
                process.arguments = args
                
                // Pass through the user environment so agy finds its config
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

    // Parses output like:
    // Quota:
    // Gemini Models          Weekly Limit Remaining     82%  2026-10-07T08:32:47Z
    // Gemini Models          Five Hour Limit Remaining  0%   2026-10-01T11:23:38Z
    nonisolated private static func parseQuota(_ output: String) -> [QuotaEntry] {
        var entries: [QuotaEntry] = []
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.lowercased().hasPrefix("quota") else { continue }
            
            // agy outputs TSV when piped/non-TTY
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
            
            // Fallback for space-padded TTY output
            let pattern = #"^(.+?)\s{2,}(.+?)\s{2,}(\d+)%\s+(\S+)\s*$"#
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

    // Parses:
    // Model credits
    // Remaining credits  0
    // Upgrade  https://...
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

    /// The "worst" remaining quota across all 5-hour limits (for menu bar icon)
    var criticalPercent: Int? {
        let allEntries = profilesData.flatMap { $0.quotaEntries }
        let fiveHour = allEntries.filter { $0.limitType.lowercased().contains("five hour") || $0.limitType.lowercased().contains("5 hour") }
        return fiveHour.map { $0.percent }.min()
    }
}
