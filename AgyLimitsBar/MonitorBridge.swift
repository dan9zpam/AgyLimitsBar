import Foundation

// MARK: - claude-monitor snapshot (`claude-monitor --once --output json`)

struct MonitorSnapshot: Decodable {
    struct Source: Decodable {
        let kind: String?
    }

    struct Limit: Decodable {
        let usedPercentage: Double?
        let resetsAtEpoch: Double?
        let confidence: String?
        let source: Source?
    }

    struct Limits: Decodable {
        let fiveHour: Limit?
        let sevenDay: Limit?
    }

    struct Tokens: Decodable {
        let inputTokens: Int?
        let outputTokens: Int?
        let cacheCreationInputTokens: Int?
        let cacheReadInputTokens: Int?
        let totalTokens: Int?
    }

    struct ModelShare: Decodable, Identifiable {
        var id: String { family }
        let family: String
        let percentage: Double
        let costUsd: Double?
    }

    struct Local: Decodable {
        let isActive: Bool
        let sessionStart: String?
        let sessionEnd: String?
        let tokens: Tokens?
        let costUsd: Double?
        let sentMessages: Int?
        let burnRateTokensPerMinute: Double?
        let burnRateCostPerHour: Double?
        let modelDistribution: [ModelShare]?
    }

    struct History: Decodable {
        let totalTokens: Int?
        let totalCostUsd: Double?
    }

    struct Pace: Decodable {
        let label: String?
        let usedPercentage: Double?
        let elapsedPercentage: Double?
    }

    struct Forecast: Decodable {
        let display: String?
        let predictedTokensExhaustedEpoch: Double?
        let minutesRemaining: Double?
        let confidence: String?
    }

    struct Status: Decodable {
        let code: Int
        let label: String
    }

    let confidence: String?
    let plan: String?
    let limits: Limits?
    let local: Local?
    let localHistory: History?
    let pace: Pace?
    let forecast: Forecast?
    let status: Status?

    var isOfficial: Bool { confidence == "official" }
}

// MARK: - claude-monitor daily history (`--once --view daily --output json`)

struct DailyUsage: Decodable, Identifiable {
    var id: String { date }
    let date: String
    let totalCost: Double
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let entriesCount: Int

    var totalTokens: Int { inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens }

    /// "2026-10-23" -> "23.10"
    var shortLabel: String {
        let parts = date.split(separator: "-")
        guard parts.count == 3 else { return date }
        return "\(parts[2]).\(parts[1])"
    }
}

private struct DailyReport: Decodable {
    let periods: [DailyUsage]
}

// MARK: - Bridge

enum MonitorBridge {
    /// Where `claude-monitor` usually lives: `uv tool install`, pipx, Homebrew, or the
    /// project's own virtualenv. Can be overridden with
    /// `defaults write dev.agy.limits-bar claudeMonitorPath /path/to/claude-monitor`.
    static func locateCLI() -> String? {
        let home = NSHomeDirectory()
        var candidates: [String] = []
        if let custom = UserDefaults.standard.string(forKey: "claudeMonitorPath"), !custom.isEmpty {
            candidates.append((custom as NSString).expandingTildeInPath)
        }
        candidates += [
            "\(home)/.local/bin/claude-monitor",
            "/opt/homebrew/bin/claude-monitor",
            "/usr/local/bin/claude-monitor",
            "\(home)/Projects/Claude-Code-Usage-Monitor/.venv/bin/claude-monitor",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func fetchSnapshot(cliPath: String) async -> MonitorSnapshot? {
        // --view realtime: a last-used warehouse view (sessions/entries) would
        // otherwise turn --once into a report. --once never rewrites last_used.json.
        guard let result = await ProcessRunner.run(
            cliPath, ["--once", "--output", "json", "--view", "realtime"], timeout: 20
        ) else { return nil }
        return decode(MonitorSnapshot.self, from: result.output)
    }

    static func fetchDaily(cliPath: String) async -> [DailyUsage]? {
        guard let result = await ProcessRunner.run(
            cliPath, ["--once", "--output", "json", "--view", "daily"], timeout: 30
        ) else { return nil }
        return decode(DailyReport.self, from: result.output)?.periods
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // Exit codes 10/11/20 are statuses, not failures: always try the payload.
        guard let start = data.firstIndex(of: UInt8(ascii: "{")) else { return nil }
        return try? decoder.decode(type, from: data[start...])
    }
}

// MARK: - Process runner

enum ProcessRunner {
    struct Result {
        let status: Int32
        let output: Data
        var text: String { String(data: output, encoding: .utf8) ?? "" }
    }

    static var defaultEnvironment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        env["HOME"] = home
        // Claude Code looks up its keychain item by $USER; without it `/usage`
        // silently falls back to the API-key `/cost` output.
        if env["USER"] == nil { env["USER"] = NSUserName() }
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\(home)/.local/bin"
        return env
    }

    /// Runs a command off the main thread, killing it after `timeout`. stdout and
    /// stderr are drained while the process runs, so large output cannot fill
    /// the pipe and deadlock `waitUntilExit`.
    static func run(
        _ path: String,
        _ args: [String],
        environment: [String: String]? = nil,
        mergeStderr: Bool = false,
        timeout: TimeInterval
    ) async -> Result? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = args
                process.environment = environment ?? defaultEnvironment
                process.currentDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
                process.standardInput = FileHandle.nullDevice

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = mergeStderr ? pipe : FileHandle.nullDevice

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }

                let timer = DispatchSource.makeTimerSource(queue: .global())
                timer.schedule(deadline: .now() + timeout)
                timer.setEventHandler {
                    if process.isRunning { process.terminate() }
                }
                timer.resume()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                timer.cancel()
                continuation.resume(returning: Result(status: process.terminationStatus, output: data))
            }
        }
    }
}
