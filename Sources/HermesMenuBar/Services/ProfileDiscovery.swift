import Foundation

public final class ProfileDiscovery: @unchecked Sendable {
    public static let shared = ProfileDiscovery()

    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()

    public var hermesHomeURL: URL {
        if let customHome = ProcessInfo.processInfo.environment["HERMES_HOME"],
           !customHome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: customHome)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".hermes")
    }

    public var profilesHomeURL: URL {
        hermesHomeURL.appendingPathComponent("profiles")
    }

    private init() {}

    public func discoverProfiles() -> [HermesProfile] {
        var profiles = [HermesProfile]()

        // 1. Default profile
        let defaultURL = hermesHomeURL
        if fileManager.fileExists(atPath: defaultURL.path) {
            var profile = HermesProfile(name: "default", directoryURL: defaultURL)
            profile.status = readState(for: profile)
            profile.modelName = readModelName(from: profile.configFileURL)
            profiles.append(profile)
        }

        // 2. Extra profiles in ~/.hermes/profiles/
        if fileManager.fileExists(atPath: profilesHomeURL.path) {
            do {
                let items = try fileManager.contentsOfDirectory(at: profilesHomeURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                let sortedItems = items.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false }
                    .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

                for item in sortedItems {
                    let name = item.lastPathComponent
                    var profile = HermesProfile(name: name, directoryURL: item)
                    profile.status = readState(for: profile)
                    profile.modelName = readModelName(from: profile.configFileURL)
                    profiles.append(profile)
                }
            } catch {
                print("Error scanning profiles: \(error.localizedDescription)")
            }
        }

        return profiles
    }

    public func readState(for profile: HermesProfile) -> ProfileStatus {
        let stateFileURL = profile.stateFileURL
        let pidFileURL = profile.pidFileURL

        // 1. Try reading and decoding gateway_state.json
        if fileManager.fileExists(atPath: stateFileURL.path),
           let data = try? Data(contentsOf: stateFileURL),
           let stateFile = try? decoder.decode(GatewayStateFile.self, from: data) {

            if let pid = stateFile.pid, pid > 1 {
                let isAlive = HermesProfile.isPIDAlive(pid)
                if isAlive {
                    let tgState = stateFile.platforms?["telegram"]?.state?.lowercased() ?? "unknown"
                    let tgError = stateFile.platforms?["telegram"]?.errorMessage
                    let isConnected = (tgState == "connected")
                    let detail = tgError ?? tgState
                    return .running(pid: pid, telegramConnected: isConnected, telegramDetail: detail)
                }
            }
        }

        // 2. Fallback: check gateway.pid if gateway_state.json was missing or mid-write
        if fileManager.fileExists(atPath: pidFileURL.path),
           let pidString = try? String(contentsOf: pidFileURL, encoding: .utf8),
           let pid = Int(pidString.trimmingCharacters(in: .whitespacesAndNewlines)),
           pid > 1 {
            if HermesProfile.isPIDAlive(pid) {
                return .running(pid: pid, telegramConnected: true, telegramDetail: "active (PID valid)")
            }
        }

        return .stopped
    }

    private func readModelName(from configFileURL: URL) -> String? {
        guard fileManager.fileExists(atPath: configFileURL.path),
              let content = try? String(contentsOf: configFileURL, encoding: .utf8) else {
            return nil
        }

        // Quick regex match for default model
        let patterns = [
            #"(?m)^\s*default:\s*['"]?([a-zA-Z0-9_\-\.\/]+)['"]?"#,
            #"(?m)^\s*model:\s*['"]?([a-zA-Z0-9_\-\.\/]+)['"]?"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content) {
                let found = String(content[range])
                if !found.isEmpty && !found.hasPrefix("#") {
                    return found
                }
            }
        }
        return nil
    }
}
