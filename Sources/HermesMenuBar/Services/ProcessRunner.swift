import Foundation
import AppKit

public final class ProcessRunner: @unchecked Sendable {
    public static let shared = ProcessRunner()

    private let fileManager = FileManager.default
    public let hermesBinaryPath: String

    private init() {
        self.hermesBinaryPath = ProcessRunner.resolveHermesBinary()
    }

    public static func resolveHermesBinary() -> String {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path

        // 1. Check custom environment variable
        if let customBin = ProcessInfo.processInfo.environment["HERMES_BIN"],
           fileManager.isExecutableFile(atPath: customBin) {
            return customBin
        }

        // 2. Candidate locations across standard macOS installations
        let candidates = [
            "\(home)/.local/bin/hermes",
            "\(home)/.hermes/hermes-agent/venv/bin/hermes",
            "\(home)/.cargo/bin/hermes",
            "\(home)/.pixi/bin/hermes",
            "/opt/homebrew/bin/hermes",
            "/opt/homebrew/sbin/hermes",
            "/usr/local/bin/hermes",
            "/usr/bin/hermes"
        ]

        for candidate in candidates {
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        // 3. Fallback: query 'which hermes' via PATH
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["hermes"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        if (try? process.run()) != nil {
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty, fileManager.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }

        // Default fallback to standard ~/.local/bin/hermes
        return "\(home)/.local/bin/hermes"
    }

    private func defaultEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = fileManager.homeDirectoryForCurrentUser.path

        let customPaths = [
            "\(home)/.local/bin",
            "\(home)/.hermes/hermes-agent/venv/bin",
            "\(home)/.cargo/bin",
            "\(home)/.pixi/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        let currentPath = env["PATH"] ?? ""
        env["PATH"] = (customPaths + [currentPath]).joined(separator: ":")
        return env
    }

    public func executeHermes(arguments: [String], completion: (@Sendable (Bool, String) -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.hermesBinaryPath)
            process.arguments = arguments
            process.environment = self.defaultEnvironment()

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let success = (process.terminationStatus == 0)
                completion?(success, output)
            } catch {
                completion?(false, error.localizedDescription)
            }
        }
    }

    public func startGateway(for profile: HermesProfile, completion: (@Sendable (Bool) -> Void)? = nil) {
        var args = [String]()
        if !profile.isDefault {
            args += ["--profile", profile.name]
        }
        args += ["gateway", "start"]
        executeHermes(arguments: args) { success, _ in
            completion?(success)
        }
    }

    public func stopGateway(for profile: HermesProfile, completion: (@Sendable (Bool) -> Void)? = nil) {
        var args = [String]()
        if !profile.isDefault {
            args += ["--profile", profile.name]
        }
        args += ["gateway", "stop"]
        executeHermes(arguments: args) { success, _ in
            completion?(success)
        }
    }

    public func restartGateway(for profile: HermesProfile, completion: (@Sendable (Bool) -> Void)? = nil) {
        var args = [String]()
        if !profile.isDefault {
            args += ["--profile", profile.name]
        }
        args += ["gateway", "restart"]
        executeHermes(arguments: args) { success, _ in
            completion?(success)
        }
    }

    public func openTerminalChat(for profile: HermesProfile) {
        let cmd: String
        if profile.isDefault {
            cmd = "\(hermesBinaryPath)"
        } else {
            cmd = "\(hermesBinaryPath) --profile \(profile.name)"
        }
        let script = """
        tell application "Terminal"
            activate
            do script "\(cmd)"
        end tell
        """
        runAppleScript(script)
    }

    public func openLogs(for profile: HermesProfile) {
        let logPath = profile.logFileURL.path
        let script = """
        tell application "Terminal"
            activate
            do script "tail -f \\"\(logPath)\\""
        end tell
        """
        runAppleScript(script)
    }

    public func openFolder(for profile: HermesProfile) {
        NSWorkspace.shared.open(profile.directoryURL)
    }

    public func openTelegramApp() {
        let telegramAppURL = URL(fileURLWithPath: "/Applications/Telegram.app")
        let userTelegramAppURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/Telegram.app")

        if FileManager.default.fileExists(atPath: telegramAppURL.path) {
            NSWorkspace.shared.open(telegramAppURL)
        } else if FileManager.default.fileExists(atPath: userTelegramAppURL.path) {
            NSWorkspace.shared.open(userTelegramAppURL)
        } else if let tgURL = URL(string: "tg://") {
            NSWorkspace.shared.open(tgURL)
        } else if let webURL = URL(string: "https://web.telegram.org") {
            NSWorkspace.shared.open(webURL)
        }
    }

    private func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: source) {
                scriptObject.executeAndReturnError(&error)
            }
        }
    }
}
