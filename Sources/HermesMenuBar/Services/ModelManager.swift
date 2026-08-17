import Foundation
import AppKit

public final class ModelManager: @unchecked Sendable {
    public static let shared = ModelManager()

    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Model Discovery

    public struct ModelCatalog: Sendable {
        public let activeModel: ModelInfo?
        public let configuredModels: [ModelInfo]
        public let providerPresets: [String: [ModelInfo]]
    }

    public func discoverModels(for profile: HermesProfile) -> ModelCatalog {
        let configFileURL = profile.configFileURL
        let profileEnvURL = profile.directoryURL.appendingPathComponent(".env")
        let globalEnvURL = ProfileDiscovery.shared.hermesHomeURL.appendingPathComponent(".env")

        var activeModelName: String?
        var activeProvider: String = "custom"
        var activeBaseURL: String?
        var configured = [ModelInfo]()

        // 1. Parse config.yaml
        if let configContent = try? String(contentsOf: configFileURL, encoding: .utf8) {
            // Active default model
            if let match = regexFirstCapture(#"(?m)^\s*default:\s*['"]?([a-zA-Z0-9_\-\.\/]+)['"]?"#, in: configContent) {
                activeModelName = match
            }
            if let providerMatch = regexFirstCapture(#"(?m)^\s*provider:\s*['"]?([a-zA-Z0-9_\-\.\/]+)['"]?"#, in: configContent) {
                activeProvider = providerMatch
            }
            if let baseMatch = regexFirstCapture(#"(?m)^\s*base_url:\s*['"]?([a-zA-Z0-9_\-\.\:\/]+)['"]?"#, in: configContent) {
                activeBaseURL = baseMatch
            }

            // Fallback providers models
            let fallbackPattern = #"(?m)-\s*provider:\s*([^\n\r]+)[\s\S]*?model:\s*['"]?([a-zA-Z0-9_\-\.\/]+)['"]?(?:[\s\S]*?base_url:\s*['"]?([a-zA-Z0-9_\-\.\:\/]+)['"]?)?(?:[\s\S]*?key_env:\s*['"]?([a-zA-Z0-9_]+)['"]?)?"#
            if let regex = try? NSRegularExpression(pattern: fallbackPattern) {
                let matches = regex.matches(in: configContent, range: NSRange(configContent.startIndex..., in: configContent))
                for m in matches {
                    if let modelRange = Range(m.range(at: 2), in: configContent) {
                        let modelId = String(configContent[modelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        var prov = "custom"
                        var base: String?
                        var keyEnv: String?

                        if let provRange = Range(m.range(at: 1), in: configContent) {
                            prov = String(configContent[provRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        if m.numberOfRanges > 3, let baseRange = Range(m.range(at: 3), in: configContent) {
                            base = String(configContent[baseRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        if m.numberOfRanges > 4, let keyRange = Range(m.range(at: 4), in: configContent) {
                            keyEnv = String(configContent[keyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }

                        if !modelId.isEmpty && !configured.contains(where: { $0.identifier == modelId }) {
                            let isCur = (modelId == activeModelName)
                            configured.append(ModelInfo(
                                identifier: modelId,
                                displayName: modelId,
                                provider: prov,
                                category: .configured,
                                isCurrent: isCur,
                                baseURL: base,
                                keyEnv: keyEnv
                            ))
                        }
                    }
                }
            }
        }

        let activeModel: ModelInfo? = activeModelName.map {
            ModelInfo(
                identifier: $0,
                displayName: $0,
                provider: activeProvider,
                category: .active,
                isCurrent: true,
                baseURL: activeBaseURL
            )
        }

        // 2. Discover available API Keys from .env
        var envKeys = Set<String>()
        loadEnvKeys(from: globalEnvURL, into: &envKeys)
        loadEnvKeys(from: profileEnvURL, into: &envKeys)

        // 3. Populate Provider Presets based on active keys
        var presets = [String: [ModelInfo]]()

        if envKeys.contains("ANTHROPIC_API_KEY") {
            presets["Anthropic"] = [
                ModelInfo(identifier: "anthropic/claude-3-7-sonnet", displayName: "Claude 3.7 Sonnet (Latest)", provider: "anthropic", category: .providerPreset, isCurrent: activeModelName?.contains("claude-3-7-sonnet") == true),
                ModelInfo(identifier: "anthropic/claude-3-5-sonnet-latest", displayName: "Claude 3.5 Sonnet", provider: "anthropic", category: .providerPreset, isCurrent: activeModelName?.contains("claude-3-5-sonnet") == true),
                ModelInfo(identifier: "anthropic/claude-3-5-haiku-latest", displayName: "Claude 3.5 Haiku", provider: "anthropic", category: .providerPreset, isCurrent: activeModelName?.contains("claude-3-5-haiku") == true)
            ]
        }

        if envKeys.contains("OPENAI_API_KEY") {
            presets["OpenAI"] = [
                ModelInfo(identifier: "openai/gpt-4o", displayName: "GPT-4o (Omni)", provider: "openai", category: .providerPreset, isCurrent: activeModelName?.contains("gpt-4o") == true),
                ModelInfo(identifier: "openai/gpt-4o-mini", displayName: "GPT-4o Mini", provider: "openai", category: .providerPreset, isCurrent: activeModelName?.contains("gpt-4o-mini") == true),
                ModelInfo(identifier: "openai/o3-mini", displayName: "o3-mini (Reasoning)", provider: "openai", category: .providerPreset, isCurrent: activeModelName?.contains("o3-mini") == true)
            ]
        }

        if envKeys.contains("GOOGLE_API_KEY") || envKeys.contains("GOOGLE_API_TWO") {
            presets["Google Gemini"] = [
                ModelInfo(identifier: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash", provider: "custom", category: .providerPreset, isCurrent: activeModelName?.contains("gemini-2.5-flash") == true, baseURL: "https://generativelanguage.googleapis.com/v1beta/openai/", keyEnv: "GOOGLE_API_TWO"),
                ModelInfo(identifier: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro", provider: "custom", category: .providerPreset, isCurrent: activeModelName?.contains("gemini-2.5-pro") == true, baseURL: "https://generativelanguage.googleapis.com/v1beta/openai/", keyEnv: "GOOGLE_API_TWO")
            ]
        }

        if envKeys.contains("NVIDIA_API_KEY") {
            presets["NVIDIA NIM"] = [
                ModelInfo(identifier: "nvidia/nemotron-3-ultra-550b-a55b", displayName: "Nemotron 3 Ultra 550B", provider: "custom", category: .providerPreset, isCurrent: activeModelName == "nvidia/nemotron-3-ultra-550b-a55b", baseURL: "https://integrate.api.nvidia.com/v1", keyEnv: "NVIDIA_API_KEY"),
                ModelInfo(identifier: "nvidia/nemotron-3-super-120b-a12b", displayName: "Nemotron 3 Super 120B", provider: "custom", category: .providerPreset, isCurrent: activeModelName == "nvidia/nemotron-3-super-120b-a12b", baseURL: "https://integrate.api.nvidia.com/v1", keyEnv: "NVIDIA_API_KEY")
            ]
        }

        if envKeys.contains("OPENROUTER_API_KEY") {
            presets["OpenRouter / DeepSeek"] = [
                ModelInfo(identifier: "deepseek/deepseek-r1", displayName: "DeepSeek R1", provider: "openrouter", category: .providerPreset, isCurrent: activeModelName?.contains("deepseek-r1") == true),
                ModelInfo(identifier: "deepseek/deepseek-chat", displayName: "DeepSeek V3", provider: "openrouter", category: .providerPreset, isCurrent: activeModelName?.contains("deepseek-chat") == true),
                ModelInfo(identifier: "openrouter/auto", displayName: "OpenRouter Auto Router", provider: "openrouter", category: .providerPreset, isCurrent: activeModelName == "openrouter/auto")
            ]
        }

        if envKeys.contains("GROQ_API_KEY") {
            presets["Groq"] = [
                ModelInfo(identifier: "groq/llama-3.3-70b-versatile", displayName: "Llama 3.3 70B Versatile", provider: "groq", category: .providerPreset, isCurrent: activeModelName?.contains("llama-3.3-70b") == true),
                ModelInfo(identifier: "groq/llama-3.1-8b-instant", displayName: "Llama 3.1 8B Instant", provider: "groq", category: .providerPreset, isCurrent: activeModelName?.contains("llama-3.1-8b") == true)
            ]
        }

        if envKeys.contains("CEREBRAS_API_KEY") {
            presets["Cerebras"] = [
                ModelInfo(identifier: "zai-glm-4.7", displayName: "ZAI GLM 4.7 (Ultra-Fast)", provider: "custom", category: .providerPreset, isCurrent: activeModelName == "zai-glm-4.7", baseURL: "https://api.cerebras.ai/v1", keyEnv: "CEREBRAS_API_KEY")
            ]
        }

        if envKeys.contains("ZENMUX_API_KEY") {
            presets["ZenMux"] = [
                ModelInfo(identifier: "z-ai/glm-4.7-flash-free", displayName: "GLM 4.7 Flash Free", provider: "custom", category: .providerPreset, isCurrent: activeModelName == "z-ai/glm-4.7-flash-free", baseURL: "https://zenmux.ai/api/v1", keyEnv: "ZENMUX_API_KEY")
            ]
        }

        return ModelCatalog(activeModel: activeModel, configuredModels: configured, providerPresets: presets)
    }

    // MARK: - Model Switching & Atomic YAML Mutation

    public func setModel(
        _ model: ModelInfo,
        for profile: HermesProfile,
        restartIfRunning: Bool = true,
        completion: (@Sendable (Bool) -> Void)? = nil
    ) {
        let configFileURL = profile.configFileURL
        guard fileManager.fileExists(atPath: configFileURL.path),
              var content = try? String(contentsOf: configFileURL, encoding: .utf8) else {
            completion?(false)
            return
        }

        // 1. Update default model
        let defaultPattern = #"(?m)^(\s*default:\s*)['"]?[a-zA-Z0-9_\-\.\/]+['"]?"#
        if let regex = try? NSRegularExpression(pattern: defaultPattern) {
            content = regex.stringByReplacingMatches(
                in: content,
                range: NSRange(content.startIndex..., in: content),
                withTemplate: "$1\(model.identifier)"
            )
        }

        // 2. Update provider if specified
        if model.provider != "custom" {
            let providerPattern = #"(?m)^(\s*provider:\s*)['"]?[a-zA-Z0-9_\-\.\/]+['"]?"#
            if let regex = try? NSRegularExpression(pattern: providerPattern) {
                content = regex.stringByReplacingMatches(
                    in: content,
                    range: NSRange(content.startIndex..., in: content),
                    withTemplate: "$1\(model.provider)"
                )
            }
        }

        // 3. Update base_url if model specifies a custom endpoint
        if let base = model.baseURL {
            let basePattern = #"(?m)^(\s*base_url:\s*)['"]?[a-zA-Z0-9_\-\.\:\/]+['"]?"#
            if let regex = try? NSRegularExpression(pattern: basePattern) {
                content = regex.stringByReplacingMatches(
                    in: content,
                    range: NSRange(content.startIndex..., in: content),
                    withTemplate: "$1\(base)"
                )
            }
        }

        // 4. Atomic Write
        guard let data = content.data(using: .utf8),
              (try? data.write(to: configFileURL, options: .atomic)) != nil else {
            completion?(false)
            return
        }

        // 5. Restart Gateway if active
        Task { @MainActor in
            if restartIfRunning && profile.status.isRunning {
                ProfileMonitor.shared.setTransitionState(for: profile.name, action: "Switching Model")
                ProcessRunner.shared.restartGateway(for: profile) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        ProfileMonitor.shared.refreshNow()
                        completion?(true)
                    }
                }
            } else {
                ProfileMonitor.shared.refreshNow()
                completion?(true)
            }
        }
    }

    // MARK: - Helpers

    private func loadEnvKeys(from url: URL, into set: inout Set<String>) {
        guard fileManager.fileExists(atPath: url.path),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if let eqIdx = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<eqIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                let val = String(trimmed[trimmed.index(after: eqIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !val.isEmpty {
                    set.insert(key)
                }
            }
        }
    }

    private func regexFirstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let result = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
