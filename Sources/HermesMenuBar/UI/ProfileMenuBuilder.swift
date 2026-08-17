import Foundation
import AppKit

@MainActor
public final class ProfileMenuBuilder {
    private let runner = ProcessRunner.shared
    private let monitor = ProfileMonitor.shared

    public init() {}

    public func buildMenu(for profile: HermesProfile) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // 1. Profile Title & Header
        let titleItem = NSMenuItem(title: "Hermes Profile: \(profile.name.uppercased())", action: nil, keyEquivalent: "")
        let titleFont = NSFont.boldSystemFont(ofSize: 13)
        titleItem.attributedTitle = NSAttributedString(string: "🤖 Hermes: \(profile.displayName)", attributes: [.font: titleFont])
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        // Status Line
        let statusEmoji: String
        switch profile.status {
        case .running(_, let connected, _):
            statusEmoji = connected ? "🟢" : "🟡"
        case .stopped:
            statusEmoji = "⚪"
        case .transitioning:
            statusEmoji = "⏳"
        case .error:
            statusEmoji = "🔴"
        }
        let statusItem = NSMenuItem(title: "  Status: \(statusEmoji) \(profile.status.statusText)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        // Model Selector Submenu
        let currentModel = profile.modelName ?? "Unknown"
        let modelMenuItem = NSMenuItem(title: "  Model: 🧠 \(currentModel)", action: nil, keyEquivalent: "")
        
        let modelSubmenu = NSMenu()
        let submenuDelegate = ModelSubmenuDelegate(profile: profile)
        modelSubmenu.delegate = submenuDelegate
        // Retain delegate via representedObject so it stays alive while menu is open
        modelMenuItem.representedObject = submenuDelegate
        modelMenuItem.submenu = modelSubmenu
        menu.addItem(modelMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Main Process Controls for this profile
        switch profile.status {
        case .running:
            let stopItem = NSMenuItem(title: "🛑 Stop Gateway", action: #selector(MenuActions.stopProfile(_:)), keyEquivalent: "s")
            stopItem.target = MenuActions.shared
            stopItem.representedObject = profile
            menu.addItem(stopItem)

            let restartItem = NSMenuItem(title: "🔄 Restart Gateway", action: #selector(MenuActions.restartProfile(_:)), keyEquivalent: "r")
            restartItem.target = MenuActions.shared
            restartItem.representedObject = profile
            menu.addItem(restartItem)

        case .stopped, .error:
            let startItem = NSMenuItem(title: "🚀 Start Gateway", action: #selector(MenuActions.startProfile(_:)), keyEquivalent: "s")
            startItem.target = MenuActions.shared
            startItem.representedObject = profile
            menu.addItem(startItem)

        case .transitioning:
            let transItem = NSMenuItem(title: "⏳ Action in progress...", action: nil, keyEquivalent: "")
            transItem.isEnabled = false
            menu.addItem(transItem)
        }

        menu.addItem(NSMenuItem.separator())

        // 3. Quick Launchers
        let tgAppItem = NSMenuItem(title: "📱 Open Telegram App", action: #selector(MenuActions.openTelegram), keyEquivalent: "m")
        tgAppItem.target = MenuActions.shared
        menu.addItem(tgAppItem)

        let chatItem = NSMenuItem(title: "💬 Open Chat in Terminal", action: #selector(MenuActions.openChat(_:)), keyEquivalent: "t")
        chatItem.target = MenuActions.shared
        chatItem.representedObject = profile
        menu.addItem(chatItem)

        let logItem = NSMenuItem(title: "📜 Tail Live Logs (gateway.log)", action: #selector(MenuActions.openLogs(_:)), keyEquivalent: "l")
        logItem.target = MenuActions.shared
        logItem.representedObject = profile
        menu.addItem(logItem)

        let folderItem = NSMenuItem(title: "📁 Open Profile Folder in Finder", action: #selector(MenuActions.openFolder(_:)), keyEquivalent: "o")
        folderItem.target = MenuActions.shared
        folderItem.representedObject = profile
        menu.addItem(folderItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Batch Actions (All Profiles)
        let allSubmenu = NSMenu()
        let batchMenuItem = NSMenuItem(title: "⚡️ All Profiles Actions", action: nil, keyEquivalent: "")
        batchMenuItem.submenu = allSubmenu

        let startAll = NSMenuItem(title: "🚀 Start All Gateways", action: #selector(MenuActions.startAllProfiles), keyEquivalent: "")
        startAll.target = MenuActions.shared
        allSubmenu.addItem(startAll)

        let restartAll = NSMenuItem(title: "🔄 Restart All Gateways", action: #selector(MenuActions.restartAllProfiles), keyEquivalent: "")
        restartAll.target = MenuActions.shared
        allSubmenu.addItem(restartAll)

        let stopAll = NSMenuItem(title: "🛑 Stop All Gateways", action: #selector(MenuActions.stopAllProfiles), keyEquivalent: "")
        stopAll.target = MenuActions.shared
        allSubmenu.addItem(stopAll)

        menu.addItem(batchMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Settings / Tools
        let refreshItem = NSMenuItem(title: "🔄 Refresh Status Now", action: #selector(MenuActions.refreshNow), keyEquivalent: "")
        refreshItem.target = MenuActions.shared
        menu.addItem(refreshItem)

        let isMulti = StatusItemManager.shared.isMultiIconMode
        let toggleModeItem = NSMenuItem(
            title: isMulti ? "Mode: Multi-Icon (Click for Single Icon)" : "Mode: Single Icon (Click for Multi-Icon)",
            action: #selector(MenuActions.toggleDisplayMode),
            keyEquivalent: ""
        )
        toggleModeItem.target = MenuActions.shared
        menu.addItem(toggleModeItem)

        menu.addItem(NSMenuItem.separator())

        // 6. Quit
        let quitItem = NSMenuItem(title: "❌ Quit Hermes Menu Bar", action: #selector(MenuActions.quitApp), keyEquivalent: "q")
        quitItem.target = MenuActions.shared
        menu.addItem(quitItem)

        return menu
    }
}

// MARK: - Lazy Model Submenu Delegate

@MainActor
public final class ModelSubmenuDelegate: NSObject, NSMenuDelegate {
    public let profile: HermesProfile

    public init(profile: HermesProfile) {
        self.profile = profile
        super.init()
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let catalog = ModelManager.shared.discoverModels(for: profile)

        // 1. Current Active Model Section
        let currentHeader = NSMenuItem(title: "CURRENT MODEL", action: nil, keyEquivalent: "")
        currentHeader.isEnabled = false
        menu.addItem(currentHeader)

        if let active = catalog.activeModel {
            let item = NSMenuItem(
                title: "  🧠 \(active.identifier) (Active)",
                action: #selector(MenuActions.selectModel(_:)),
                keyEquivalent: ""
            )
            item.target = MenuActions.shared
            item.state = .on
            item.representedObject = (profile: profile, model: active)
            menu.addItem(item)
        } else {
            let item = NSMenuItem(title: "  (None configured)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        // 2. Configured & Fallback Models from config.yaml
        if !catalog.configuredModels.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let confHeader = NSMenuItem(title: "CONFIGURED IN CONFIG.YAML", action: nil, keyEquivalent: "")
            confHeader.isEnabled = false
            menu.addItem(confHeader)

            for m in catalog.configuredModels {
                let item = NSMenuItem(
                    title: "  🧠 \(m.displayName)",
                    action: #selector(MenuActions.selectModel(_:)),
                    keyEquivalent: ""
                )
                item.target = MenuActions.shared
                item.state = m.isCurrent ? .on : .off
                item.representedObject = (profile: profile, model: m)
                menu.addItem(item)
            }
        }

        // 3. Provider Presets from .env API keys
        if !catalog.providerPresets.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let presetHeader = NSMenuItem(title: "AVAILABLE VIA .ENV API KEYS", action: nil, keyEquivalent: "")
            presetHeader.isEnabled = false
            menu.addItem(presetHeader)

            let sortedProviders = catalog.providerPresets.keys.sorted()
            for prov in sortedProviders {
                if let models = catalog.providerPresets[prov] {
                    let provItem = NSMenuItem(title: "  ▶ \(prov)", action: nil, keyEquivalent: "")
                    let provSub = NSMenu()
                    for pm in models {
                        let subItem = NSMenuItem(
                            title: "🧠 \(pm.displayName)",
                            action: #selector(MenuActions.selectModel(_:)),
                            keyEquivalent: ""
                        )
                        subItem.target = MenuActions.shared
                        subItem.state = pm.isCurrent ? .on : .off
                        subItem.representedObject = (profile: profile, model: pm)
                        provSub.addItem(subItem)
                    }
                    provItem.submenu = provSub
                    menu.addItem(provItem)
                }
            }
        }

        // 4. Custom Model Prompt
        menu.addItem(NSMenuItem.separator())
        let customItem = NSMenuItem(
            title: "✏️ Enter Custom Model Name...",
            action: #selector(MenuActions.promptCustomModel(_:)),
            keyEquivalent: ""
        )
        customItem.target = MenuActions.shared
        customItem.representedObject = profile
        menu.addItem(customItem)
    }
}

// MARK: - Menu Actions Coordinator

@MainActor
public final class MenuActions: NSObject {
    public static let shared = MenuActions()

    private let runner = ProcessRunner.shared
    private let monitor = ProfileMonitor.shared

    private override init() {
        super.init()
    }

    @objc public func startProfile(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? HermesProfile else { return }
        monitor.setTransitionState(for: profile.name, action: "Starting")
        runner.startGateway(for: profile) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self?.monitor.refreshNow()
            }
        }
    }

    @objc public func stopProfile(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? HermesProfile else { return }
        monitor.setTransitionState(for: profile.name, action: "Stopping")
        runner.stopGateway(for: profile) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.monitor.refreshNow()
            }
        }
    }

    @objc public func restartProfile(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? HermesProfile else { return }
        monitor.setTransitionState(for: profile.name, action: "Restarting")
        runner.restartGateway(for: profile) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self?.monitor.refreshNow()
            }
        }
    }

    @objc public func selectModel(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? (profile: HermesProfile, model: ModelInfo) else { return }
        let profile = data.profile
        let model = data.model

        ModelManager.shared.setModel(model, for: profile, restartIfRunning: true) { success in
            if success {
                print("Successfully switched \(profile.name) to model \(model.identifier)")
            }
        }
    }

    @objc public func promptCustomModel(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? HermesProfile else { return }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Select Model for \(profile.displayName)"
        alert.informativeText = "Enter the model identifier (e.g. anthropic/claude-3-7-sonnet, openai/gpt-4o, ollama/llama3.2):"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Set Model & Apply")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        input.stringValue = profile.modelName ?? ""
        alert.accessoryView = input

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let entered = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !entered.isEmpty {
                let customModel = ModelInfo(
                    identifier: entered,
                    displayName: entered,
                    provider: "custom",
                    category: .custom,
                    isCurrent: true
                )
                ModelManager.shared.setModel(customModel, for: profile, restartIfRunning: true)
            }
        }
    }

    @objc public func openTelegram() {
        runner.openTelegramApp()
    }

    @objc public func openChat(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? HermesProfile else { return }
        runner.openTerminalChat(for: profile)
    }

    @objc public func openLogs(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? HermesProfile else { return }
        runner.openLogs(for: profile)
    }

    @objc public func openFolder(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? HermesProfile else { return }
        runner.openFolder(for: profile)
    }

    @objc public func startAllProfiles() {
        let profiles = ProfileDiscovery.shared.discoverProfiles()
        for p in profiles {
            monitor.setTransitionState(for: p.name, action: "Starting")
            runner.startGateway(for: p)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.monitor.refreshNow()
        }
    }

    @objc public func stopAllProfiles() {
        let profiles = ProfileDiscovery.shared.discoverProfiles()
        for p in profiles {
            monitor.setTransitionState(for: p.name, action: "Stopping")
            runner.stopGateway(for: p)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.monitor.refreshNow()
        }
    }

    @objc public func restartAllProfiles() {
        let profiles = ProfileDiscovery.shared.discoverProfiles()
        for p in profiles {
            monitor.setTransitionState(for: p.name, action: "Restarting")
            runner.restartGateway(for: p)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.monitor.refreshNow()
        }
    }

    @objc public func refreshNow() {
        monitor.refreshNow()
    }

    @objc public func toggleDisplayMode() {
        StatusItemManager.shared.toggleDisplayMode()
    }

    @objc public func quitApp() {
        NSApp.terminate(nil)
    }
}
