import Foundation

public enum ModelCategory: String, Sendable, CaseIterable {
    case active = "Active"
    case configured = "Configured in config.yaml"
    case providerPreset = "Available via .env API Keys"
    case custom = "Custom"
}

public struct ModelInfo: Identifiable, Hashable, Sendable {
    public var id: String { identifier }
    public let identifier: String
    public let displayName: String
    public let provider: String
    public let category: ModelCategory
    public let isCurrent: Bool
    public let baseURL: String?
    public let keyEnv: String?

    public init(
        identifier: String,
        displayName: String? = nil,
        provider: String = "custom",
        category: ModelCategory = .configured,
        isCurrent: Bool = false,
        baseURL: String? = nil,
        keyEnv: String? = nil
    ) {
        self.identifier = identifier
        self.displayName = displayName ?? identifier
        self.provider = provider
        self.category = category
        self.isCurrent = isCurrent
        self.baseURL = baseURL
        self.keyEnv = keyEnv
    }
}
