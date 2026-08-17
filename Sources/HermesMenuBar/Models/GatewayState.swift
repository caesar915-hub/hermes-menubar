import Foundation

public struct GatewayPlatformState: Codable, Sendable {
    public let state: String?
    public let errorCode: String?
    public let errorMessage: String?
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case state
        case errorCode = "error_code"
        case errorMessage = "error_message"
        case updatedAt = "updated_at"
    }
}

public struct GatewayStateFile: Codable, Sendable {
    public let pid: Int?
    public let kind: String?
    public let gatewayState: String?
    public let exitReason: String?
    public let restartRequested: Bool?
    public let activeAgents: Int?
    public let platforms: [String: GatewayPlatformState]?
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case pid
        case kind
        case gatewayState = "gateway_state"
        case exitReason = "exit_reason"
        case restartRequested = "restart_requested"
        case activeAgents = "active_agents"
        case platforms
        case updatedAt = "updated_at"
    }
}
