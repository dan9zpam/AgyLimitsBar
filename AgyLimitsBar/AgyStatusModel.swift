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
        let low = limitType.lowercased()
        return low.contains("five hour") || low.contains("5 hour") || low.contains("сессия") || low.contains("session")
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
    var isClaude: Bool = false

    var displayName: String {
        if isClaude { return "Claude Code" }
        return name
    }
}

struct ProfileData: Identifiable {
    var id: String { profile.id }
    let profile: AgyProfile
    var quotaEntries: [QuotaEntry]
    var credits: CreditsInfo
    var isAuthenticated: Bool = true
    var tier: String = ""

    var isClaude: Bool { profile.isClaude }

    var geminiEntries: [QuotaEntry] {
        quotaEntries.filter { $0.model.localizedCaseInsensitiveContains("gemini") }
    }

    var claudeAndGptEntries: [QuotaEntry] {
        quotaEntries.filter { !$0.model.localizedCaseInsensitiveContains("gemini") && !profile.isClaude }
    }
}

@MainActor
class AgyStatusModel: ObservableObject {
    @Published var profilesData: [ProfileData] = []
    @Published var availableProfiles: [AgyProfile] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil
    @Published var lastUpdated: Date? = nil
    @Published var activeAgentState: AgentState = .idle

    @Published var selectedProfileForMenuBar: String {
        didSet {
            UserDefaults.standard.set(selectedProfileForMenuBar, forKey: "selectedProfileForMenuBar")
            updateAgentState()
        }
    }

    private var timer: Timer?
    private var stateTimer: Timer?
    private let agyCLIPath: String
    private let claudeCLIPath: String

    init() {
        // Automatically default to claude on launch as requested
        let saved = UserDefaults.standard.string(forKey: "selectedProfileForMenuBar")
        if saved == nil || saved == "All" {
            self.selectedProfileForMenuBar = "claude"
        } else {
            self.selectedProfileForMenuBar = saved ?? "claude"
        }
        
        let agyCandidates = [
            "\(NSHomeDirectory())/.local/bin/agy",
            "/usr/local/bin/agy",
            "/opt/homebrew/bin/agy"
        ]
        self.agyCLIPath = agyCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? "\(NSHomeDirectory())/.local/bin/agy"

        let claudeCandidates = [
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(NSHomeDirectory())/.local/bin/claude"
        ]
        self.claudeCLIPath = claudeCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) ?? "/opt/homebrew/bin/claude"

        Task {
            await self.refresh()
            self.updateAgentState()
        }
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }

        stateTimer?.invalidate()
        stateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAgentState()
            }
        }
    }

    func updateAgentState() {
        if isClaudeSelected {
            self.activeAgentState = Self.detectClaudeState()
        } else if selectedProfileForMenuBar.hasPrefix("agy") {
            self.activeAgentState = Self.detectAgyState()
        } else {
            let c = Self.detectClaudeState()
            let a = Self.detectAgyState()
            if c == .working || a == .working {
                self.activeAgentState = .working
            } else if c == .waiting || a == .waiting {
                self.activeAgentState = .waiting
            } else {
                self.activeAgentState = .idle
            }
        }
    }

    nonisolated private static func detectClaudeState() -> AgentState {
        let fm = FileManager.default
        let sessionsDir = "\(NSHomeDirectory())/.claude/sessions"
        guard let files = try? fm.contentsOfDirectory(atPath: sessionsDir) else {
            return .idle
        }
        
        var state: AgentState = .idle
        let nowMs = Date().timeIntervalSince1970 * 1000
        
        for f in files where f.hasSuffix(".json") {
            let path = "\(sessionsDir)/\(f)"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pid = json["pid"] as? Int32 else { continue }
            
            if kill(pid, 0) == 0 {
                let status = (json["status"] as? String ?? "idle").lowercased()
                let statusUpdated = json["statusUpdatedAt"] as? Double ?? 0
                let ageSec = (nowMs - statusUpdated) / 1000.0
                
                if status == "working" || status == "busy" || status == "running" {
                    return .working
                }
                if status == "idle" || status == "prompt" || status == "waiting" {
                    if ageSec < 75 {
                        state = .waiting
                    }
                }
            }
        }
        return state
    }

    nonisolated private static func detectAgyState() -> AgentState {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-eo", "pid,pcpu,comm"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let out = String(data: data, encoding: .utf8) else { return .idle }
            
            var foundAgy = false
            for line in out.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.contains("agy") && !trimmed.contains("AgyLimits") && !trimmed.contains("grep") {
                    foundAgy = true
                    let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 2, let cpu = Double(parts[1].replacingOccurrences(of: ",", with: ".")) {
                        if cpu > 1.5 {
                            return .working
                        }
                    }
                }
            }
            if foundAgy {
                return .waiting
            }
        } catch {
            return .idle
        }
        return .idle
    }

    func loadProfiles() {
        var profiles: [AgyProfile] = []
        let fm = FileManager.default
        let homeDir = URL(fileURLWithPath: NSHomeDirectory())
        
        // 1. Add Claude profile first
        let claudeConfig = "\(homeDir.path)/.claude.json"
        if fm.isExecutableFile(atPath: claudeCLIPath) || fm.fileExists(atPath: claudeConfig) {
            profiles.append(AgyProfile(name: "claude", homePath: homeDir.path, isClaude: true))
        }

        // 2. Default AGY profile
        profiles.append(AgyProfile(name: "agy", homePath: homeDir.path, isClaude: false))
        
        // 3. Additional AGY profiles
        if let contents = try? fm.contentsOfDirectory(at: homeDir, includingPropertiesForKeys: nil) {
            for url in contents {
                if url.lastPathComponent.hasPrefix(".agy-profile-") {
                    let geminiDir = url.appendingPathComponent(".gemini")
                    if fm.fileExists(atPath: geminiDir.path) {
                        let num = url.lastPathComponent.replacingOccurrences(of: ".agy-profile-", with: "")
                        let name = "agy" + num
                        profiles.append(AgyProfile(name: name, homePath: url.path, isClaude: false))
                    }
                }
            }
        }

        self.availableProfiles = profiles
    }

    func refresh() async {
        isLoading = true
        lastError = nil
        
        loadProfiles()
        
        let agyProfiles = availableProfiles.filter { !$0.isClaude }
        let profilesToFetch = Array(agyProfiles.prefix(4))
        var newProfilesData: [ProfileData] = []
        
        await withTaskGroup(of: ProfileData?.self) { group in
            for p in profilesToFetch {
                group.addTask {
                    let isAuthed = Self.isProfileAuthenticated(p)
                    guard isAuthed else {
                        return ProfileData(profile: p, quotaEntries: [], credits: CreditsInfo(remaining: 0, upgradeURL: ""), isAuthenticated: false)
                    }

                    let cli = Self.resolveCli(for: p, defaultCli: self.agyCLIPath)
                    async let usageResult = Self.runAgy(args: ["--dangerously-skip-permissions", "-p", "/usage"], homePath: p.homePath, cliPath: cli)
                    async let creditsResult = Self.runAgy(args: ["--dangerously-skip-permissions", "-p", "/credits"], homePath: p.homePath, cliPath: cli)
                    
                    let (usageOut, creditsOut) = await (usageResult, creditsResult)
                    
                    var data = ProfileData(profile: p, quotaEntries: [], credits: CreditsInfo(remaining: 0, upgradeURL: ""), isAuthenticated: true)
                    if let u = usageOut { data.quotaEntries = Self.parseQuota(u) }
                    if let c = creditsOut { data.credits = Self.parseCredits(c) }
                    
                    return data
                }
            }

            if availableProfiles.contains(where: { $0.isClaude }) {
                group.addTask {
                    await Self.fetchClaudeData(cliPath: self.claudeCLIPath)
                }
            }
            
            for await result in group {
                if let data = result {
                    newProfilesData.append(data)
                }
            }
        }
        
        self.profilesData = newProfilesData.sorted { a, b in
            if a.isClaude != b.isClaude {
                return a.isClaude // Claude first
            }
            return a.profile.name < b.profile.name
        }
        lastUpdated = Date()
        isLoading = false
        updateAgentState()
    }

    func openTerminal(command: String = "claude") {
        let script = "tell application \"Terminal\" to do script \"\(command)\" activate"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    nonisolated private static func resolveCli(for profile: AgyProfile, defaultCli: String) -> String {
        let profileCli = "\(NSHomeDirectory())/.local/bin/\(profile.name)"
        if FileManager.default.isExecutableFile(atPath: profileCli) {
            return profileCli
        }
        return defaultCli
    }

    nonisolated private static func isProfileAuthenticated(_ profile: AgyProfile) -> Bool {
        let fm = FileManager.default
        let tokenFile = "\(profile.homePath)/.gemini/antigravity-cli/antigravity-oauth-token"
        if fm.fileExists(atPath: tokenFile), (try? fm.attributesOfItem(atPath: tokenFile)[.size] as? Int ?? 0) ?? 0 > 0 {
            return true
        }

        let kcPath = "\(profile.homePath)/Library/Keychains/agy.keychain-db"
        if fm.fileExists(atPath: kcPath) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            proc.arguments = ["find-generic-password", "-s", "gemini", "-a", "antigravity", kcPath]
            proc.standardOutput = Pipe()
            proc.standardError = Pipe()
            do {
                try proc.run()
                proc.waitUntilExit()
                return proc.terminationStatus == 0
            } catch {
                return false
            }
        } else {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            proc.arguments = ["find-generic-password", "-s", "gemini", "-a", "antigravity"]
            proc.standardOutput = Pipe()
            proc.standardError = Pipe()
            do {
                try proc.run()
                proc.waitUntilExit()
                return proc.terminationStatus == 0
            } catch {
                return false
            }
        }
    }

    nonisolated private static func runAgy(args: [String], homePath: String, cliPath: String) async -> String? {
        let kcPath = "\(homePath)/Library/Keychains/agy.keychain-db"
        if FileManager.default.fileExists(atPath: kcPath) {
            let unlock = Process()
            unlock.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            unlock.arguments = ["unlock-keychain", "-p", "agy", kcPath]
            try? unlock.run()
            unlock.waitUntilExit()
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: cliPath)
                process.arguments = args
                
                var env = ProcessInfo.processInfo.environment
                env["HOME"] = homePath
                env["AGY_CLI_INTERACTIVE_HEADLESS"] = "1"
                process.environment = env

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()

                    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
                    timer.schedule(deadline: .now() + 12.0)
                    timer.setEventHandler {
                        if process.isRunning {
                            process.terminate()
                        }
                    }
                    timer.resume()

                    process.waitUntilExit()
                    timer.cancel()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)

                    if let out = output, (out.contains("Authentication required") || out.contains("not logged into Antigravity")) {
                        continuation.resume(returning: nil)
                        return
                    }

                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    nonisolated private static func fetchClaudeData(cliPath: String) async -> ProfileData {
        let claudeProfile = AgyProfile(name: "claude", homePath: NSHomeDirectory(), isClaude: true)
        let configPath = "\(NSHomeDirectory())/.claude.json"
        let fm = FileManager.default
        var isAuthed = false
        var tier = "Subscription"

        var cachedEntries: [QuotaEntry] = []
        if fm.fileExists(atPath: configPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            if let oauth = json["oauthAccount"] as? [String: Any], !oauth.isEmpty {
                isAuthed = true
                if let billing = oauth["billingType"] as? String {
                    tier = billing.capitalized
                }
            }

            if let cache = json["cachedUsageUtilization"] as? [String: Any],
               let util = cache["utilization"] as? [String: Any] {
                cachedEntries = parseClaudeJsonUtilization(util)
            }
        }

        var liveEntries: [QuotaEntry] = []
        if fm.isExecutableFile(atPath: cliPath) {
            if let output = await runClaudeUsage(cliPath: cliPath) {
                if output.contains("Please run /login") || output.contains("Not logged in") || output.contains("Authentication required") {
                    isAuthed = false
                } else {
                    let parsed = parseClaudeUsageOutput(output)
                    if !parsed.isEmpty {
                        liveEntries = parsed
                        isAuthed = true
                    }
                }
            }
        }

        let finalEntries = liveEntries.isEmpty ? cachedEntries : liveEntries
        let hasAuth = isAuthed || !finalEntries.isEmpty

        return ProfileData(
            profile: claudeProfile,
            quotaEntries: finalEntries,
            credits: CreditsInfo(remaining: 0, upgradeURL: "https://claude.ai/settings/billing"),
            isAuthenticated: hasAuth,
            tier: tier
        )
    }

    nonisolated private static func runClaudeUsage(cliPath: String) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: cliPath)
                process.arguments = ["-p", "/usage"]

                var env = ProcessInfo.processInfo.environment
                env["HOME"] = NSHomeDirectory()
                env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\(NSHomeDirectory())/.local/bin"
                process.environment = env

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()

                    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
                    timer.schedule(deadline: .now() + 10.0)
                    timer.setEventHandler {
                        if process.isRunning {
                            process.terminate()
                        }
                    }
                    timer.resume()

                    process.waitUntilExit()
                    timer.cancel()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    nonisolated private static func parseClaudeJsonUtilization(_ util: [String: Any]) -> [QuotaEntry] {
        var entries: [QuotaEntry] = []
        if let fiveHour = util["five_hour"] as? [String: Any],
           let utilization = fiveHour["utilization"] as? Int {
            let remaining = max(0, 100 - utilization)
            let resetsAt = fiveHour["resets_at"] as? String ?? ""
            entries.append(QuotaEntry(model: "Claude Code", limitType: "5-часовая сессия", percent: remaining, resetDate: resetsAt))
        }
        if let sevenDay = util["seven_day"] as? [String: Any],
           let utilization = sevenDay["utilization"] as? Int {
            let remaining = max(0, 100 - utilization)
            let resetsAt = sevenDay["resets_at"] as? String ?? ""
            entries.append(QuotaEntry(model: "Claude Code", limitType: "Недельный лимит", percent: remaining, resetDate: resetsAt))
        }
        return entries
    }

    nonisolated private static func parseClaudeUsageOutput(_ output: String) -> [QuotaEntry] {
        var entries: [QuotaEntry] = []
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().contains("current session:") {
                let pattern = #"current\s+session:\s*(\d+)%\s*used.*?resets\s+(.+)$"#
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                    if let r1 = Range(match.range(at: 1), in: trimmed),
                       let r2 = Range(match.range(at: 2), in: trimmed) {
                        let used = Int(trimmed[r1]) ?? 0
                        let remaining = max(0, 100 - used)
                        let reset = String(trimmed[r2]).trimmingCharacters(in: .whitespaces)
                        entries.append(QuotaEntry(model: "Claude Code", limitType: "5-часовая сессия", percent: remaining, resetDate: reset))
                    }
                }
            } else if trimmed.lowercased().contains("current week") {
                let pattern = #"current\s+week.*?:\s*(\d+)%\s*used.*?resets\s+(.+)$"#
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                    if let r1 = Range(match.range(at: 1), in: trimmed),
                       let r2 = Range(match.range(at: 2), in: trimmed) {
                        let used = Int(trimmed[r1]) ?? 0
                        let remaining = max(0, 100 - used)
                        let reset = String(trimmed[r2]).trimmingCharacters(in: .whitespaces)
                        entries.append(QuotaEntry(model: "Claude Code", limitType: "Недельный лимит", percent: remaining, resetDate: reset))
                    }
                }
            }
        }
        return entries
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
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: str) {
            return formatRelative(d)
        }
        let f1Std = ISO8601DateFormatter()
        if let d = f1Std.date(from: str) {
            return formatRelative(d)
        }

        let clean = str.replacingOccurrences(of: #"\s*\(.*?\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        let year = Calendar.current.component(.year, from: Date())
        let fClaude = DateFormatter()
        fClaude.locale = Locale(identifier: "en_US_POSIX")
        fClaude.dateFormat = "yyyy MMM d 'at' h:mma"
        if let d = fClaude.date(from: "\(year) \(clean)") {
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

    var isClaudeSelected: Bool {
        selectedProfileForMenuBar == "claude"
    }

    var criticalPercent: Int? {
        let entries: [QuotaEntry]
        if selectedProfileForMenuBar == "All" {
            // For AGY profiles, only count Gemini limits!
            entries = profilesData.filter { $0.isAuthenticated }.flatMap { p in
                p.isClaude ? p.quotaEntries : p.geminiEntries
            }
        } else if selectedProfileForMenuBar == "claude" {
            entries = profilesData.first(where: { $0.isClaude })?.quotaEntries ?? []
        } else {
            // AGY profile: strictly Gemini limits as requested
            entries = profilesData.first(where: { $0.profile.name == selectedProfileForMenuBar })?.geminiEntries ?? []
        }
        let fiveHour = entries.filter { $0.isFiveHour }
        if !fiveHour.isEmpty {
            return fiveHour.map { $0.percent }.min()
        }
        return entries.map { $0.percent }.min()
    }
}
