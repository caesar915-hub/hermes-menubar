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

        // Model Line
        if let model = profile.modelName {
            let modelItem = NSMenuItem(title: "  Model: 🧠 \(model)", action: nil, keyEquivalent: "")
            modelItem.isEnabled = false
            menu.addItem(modelItem)
        }

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
