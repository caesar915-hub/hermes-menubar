import Foundation

public enum ProfileStatus: Equatable, Sendable {
    case running(pid: Int, telegramConnected: Bool, telegramDetail: String)
    case stopped
    case transitioning(action: String)
    case error(message: String)

    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    public var isTelegramConnected: Bool {
        if case .running(_, let connected, _) = self { return connected }
        return false
    }

    public var statusText: String {
        switch self {
        case .running(let pid, let connected, let detail):
            return connected ? "Running (PID \(pid), Telegram Connected)" : "Running (PID \(pid), Telegram: \(detail))"
        case .stopped:
            return "Stopped"
        case .transitioning(let action):
            return "\(action)..."
        case .error(let msg):
            return "Error: \(msg)"
        }
    }
}

public struct HermesProfile: Identifiable, Equatable, Sendable {
    public var id: String { name }
    public let name: String
    public let isDefault: Bool
    public let directoryURL: URL
    public var status: ProfileStatus
    public var modelName: String?

    public init(name: String, directoryURL: URL, status: ProfileStatus = .stopped, modelName: String? = nil) {
        self.name = name
        self.isDefault = (name == "default")
        self.directoryURL = directoryURL
        self.status = status
        self.modelName = modelName
    }

    public var displayName: String {
        if isDefault { return "default (main)" }
        return name
    }

    public var badgeLabel: String {
        switch name {
        case "default":
            return "DEF"
        case "my-man":
            return "MM"
        case "marketing":
            return "MKT"
        default:
            let parts = name.split(separator: "-")
            if parts.count >= 2 {
                return (String(parts[0].prefix(1)) + String(parts[1].prefix(1))).uppercased()
            }
            return String(name.prefix(3)).uppercased()
        }
    }

    public var stateFileURL: URL {
        directoryURL.appendingPathComponent("gateway_state.json")
    }

    public var pidFileURL: URL {
        directoryURL.appendingPathComponent("gateway.pid")
    }

    public var configFileURL: URL {
        directoryURL.appendingPathComponent("config.yaml")
    }

    public var logFileURL: URL {
        directoryURL.appendingPathComponent("logs/gateway.log")
    }

    public static func isPIDAlive(_ pid: Int) -> Bool {
        guard pid > 1 else { return false }
        return kill(pid_t(pid), 0) == 0
    }
}
