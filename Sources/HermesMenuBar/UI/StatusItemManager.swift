import Foundation
import AppKit

@MainActor
public final class StatusItemManager: NSObject {
    public static let shared = StatusItemManager()

    public private(set) var isMultiIconMode: Bool = true
    private var profileStatusItems: [String: ProfileStatusItem] = [:]
    private var singleStatusItem: NSStatusItem?
    private var lastProfiles: [HermesProfile] = []

    private override init() {
        super.init()
    }

    public func updateProfiles(_ profiles: [HermesProfile]) {
        self.lastProfiles = profiles

        if isMultiIconMode {
            updateMultiIconMode(profiles)
        } else {
            updateSingleIconMode(profiles)
        }
    }

    public func toggleDisplayMode() {
        isMultiIconMode.toggle()
        if isMultiIconMode {
            // Remove single item, build multi items
            if let single = singleStatusItem {
                NSStatusBar.system.removeStatusItem(single)
                singleStatusItem = nil
            }
            updateMultiIconMode(lastProfiles)
        } else {
            // Remove multi items, build single item
            for (_, item) in profileStatusItems {
                item.remove()
            }
            profileStatusItems.removeAll()
            updateSingleIconMode(lastProfiles)
        }
    }

    private func updateMultiIconMode(_ profiles: [HermesProfile]) {
        let activeProfileNames = Set(profiles.map { $0.name })

        // Remove status items for profiles that no longer exist
        for (name, item) in profileStatusItems where !activeProfileNames.contains(name) {
            item.remove()
            profileStatusItems.removeValue(forKey: name)
        }

        // Add or update status items
        for profile in profiles {
            let item: ProfileStatusItem
            if let existing = profileStatusItems[profile.name] {
                item = existing
            } else {
                item = ProfileStatusItem(profileName: profile.name)
                profileStatusItems[profile.name] = item
            }
            item.update(with: profile)
        }
    }

    private func updateSingleIconMode(_ profiles: [HermesProfile]) {
        if singleStatusItem == nil {
            singleStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        guard let button = singleStatusItem?.button else { return }

        let runningCount = profiles.filter { $0.status.isRunning }.count
        let totalCount = profiles.count
        let allRunning = (runningCount == totalCount && totalCount > 0)
        let anyRunning = (runningCount > 0)

        let dotColor = allRunning ? "🟢" : (anyRunning ? "🟡" : "⚪")
        button.title = "⚡️ Hermes \(dotColor) [\(runningCount)/\(totalCount)]"

        // Build combined menu
        let menu = NSMenu()
        menu.autoenablesItems = false

        let header = NSMenuItem(title: "Hermes Agent Profiles (\(runningCount)/\(totalCount) Active)", action: nil, keyEquivalent: "")
        header.attributedTitle = NSAttributedString(
            string: "🤖 Hermes Agent Gateways",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        for profile in profiles {
            let statusEmoji = profile.status.isRunning ? "🟢" : "⚪"
            let profileItem = NSMenuItem(title: "\(statusEmoji) \(profile.displayName)", action: nil, keyEquivalent: "")
            let sub = NSMenu()

            let pHeader = NSMenuItem(title: "Status: \(profile.status.statusText)", action: nil, keyEquivalent: "")
            pHeader.isEnabled = false
            sub.addItem(pHeader)
            if let model = profile.modelName {
                let mItem = NSMenuItem(title: "Model: \(model)", action: nil, keyEquivalent: "")
                mItem.isEnabled = false
                sub.addItem(mItem)
            }
            sub.addItem(NSMenuItem.separator())

            if profile.status.isRunning {
                let stop = NSMenuItem(title: "🛑 Stop", action: #selector(MenuActions.stopProfile(_:)), keyEquivalent: "")
                stop.target = MenuActions.shared
                stop.representedObject = profile
                sub.addItem(stop)

                let restart = NSMenuItem(title: "🔄 Restart", action: #selector(MenuActions.restartProfile(_:)), keyEquivalent: "")
                restart.target = MenuActions.shared
                restart.representedObject = profile
                sub.addItem(restart)
            } else {
                let start = NSMenuItem(title: "🚀 Start", action: #selector(MenuActions.startProfile(_:)), keyEquivalent: "")
                start.target = MenuActions.shared
                start.representedObject = profile
                sub.addItem(start)
            }

            let tg = NSMenuItem(title: "📱 Open Telegram App", action: #selector(MenuActions.openTelegram), keyEquivalent: "")
            tg.target = MenuActions.shared
            sub.addItem(tg)

            let chat = NSMenuItem(title: "💬 Open Terminal Chat", action: #selector(MenuActions.openChat(_:)), keyEquivalent: "")
            chat.target = MenuActions.shared
            chat.representedObject = profile
            sub.addItem(chat)

            let logs = NSMenuItem(title: "📜 Tail Logs", action: #selector(MenuActions.openLogs(_:)), keyEquivalent: "")
            logs.target = MenuActions.shared
            logs.representedObject = profile
            sub.addItem(logs)

            profileItem.submenu = sub
            menu.addItem(profileItem)
        }

        menu.addItem(NSMenuItem.separator())

        let openTgAll = NSMenuItem(title: "📱 Open Telegram App", action: #selector(MenuActions.openTelegram), keyEquivalent: "")
        openTgAll.target = MenuActions.shared
        menu.addItem(openTgAll)

        let startAll = NSMenuItem(title: "🚀 Start All Profiles", action: #selector(MenuActions.startAllProfiles), keyEquivalent: "")
        startAll.target = MenuActions.shared
        menu.addItem(startAll)

        let stopAll = NSMenuItem(title: "🛑 Stop All Profiles", action: #selector(MenuActions.stopAllProfiles), keyEquivalent: "")
        stopAll.target = MenuActions.shared
        menu.addItem(stopAll)

        menu.addItem(NSMenuItem.separator())

        let toggle = NSMenuItem(title: "Switch to Multi-Icon Mode", action: #selector(MenuActions.toggleDisplayMode), keyEquivalent: "")
        toggle.target = MenuActions.shared
        menu.addItem(toggle)

        let quit = NSMenuItem(title: "❌ Quit Hermes Menu Bar", action: #selector(MenuActions.quitApp), keyEquivalent: "q")
        quit.target = MenuActions.shared
        menu.addItem(quit)

        singleStatusItem?.menu = menu
    }
}
