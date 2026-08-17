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

        button.title = "Hermes [\(runningCount)/\(totalCount)]"
        button.image = sfImage("paperplane.fill", pointSize: 12, color: runningCount > 0 ? .systemGreen : .secondaryLabelColor)
        button.imagePosition = .imageLeft

        // Build combined menu
        let menu = NSMenu()
        menu.autoenablesItems = false

        let header = NSMenuItem(title: "Hermes Agent Profiles (\(runningCount)/\(totalCount) Active)", action: nil, keyEquivalent: "")
        header.image = sfImage("cpu", pointSize: 13)
        header.attributedTitle = NSAttributedString(
            string: "Hermes Agent Profiles",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        for profile in profiles {
            let profileItem = NSMenuItem(title: profile.displayName, action: nil, keyEquivalent: "")
            profileItem.image = statusCircleImage(for: profile.status)
            let sub = NSMenu()

            let pHeader = NSMenuItem(title: "Status: \(profile.status.statusText)", action: nil, keyEquivalent: "")
            pHeader.image = statusCircleImage(for: profile.status)
            pHeader.isEnabled = false
            sub.addItem(pHeader)
            if let model = profile.modelName {
                let mItem = NSMenuItem(title: "Model: \(model)", action: nil, keyEquivalent: "")
                mItem.image = sfImage("brain", pointSize: 12)
                mItem.isEnabled = false
                sub.addItem(mItem)
            }
            sub.addItem(NSMenuItem.separator())

            if profile.status.isRunning {
                let stop = NSMenuItem(title: "Stop", action: #selector(MenuActions.stopProfile(_:)), keyEquivalent: "")
                stop.image = sfImage("stop.fill", pointSize: 12, color: .systemRed)
                stop.target = MenuActions.shared
                stop.representedObject = profile
                sub.addItem(stop)

                let restart = NSMenuItem(title: "Restart", action: #selector(MenuActions.restartProfile(_:)), keyEquivalent: "")
                restart.image = sfImage("arrow.clockwise", pointSize: 12, color: .systemOrange)
                restart.target = MenuActions.shared
                restart.representedObject = profile
                sub.addItem(restart)
            } else {
                let start = NSMenuItem(title: "Start", action: #selector(MenuActions.startProfile(_:)), keyEquivalent: "")
                start.image = sfImage("play.fill", pointSize: 12, color: .systemGreen)
                start.target = MenuActions.shared
                start.representedObject = profile
                sub.addItem(start)
            }

            let tg = NSMenuItem(title: "Open Telegram App", action: #selector(MenuActions.openTelegram), keyEquivalent: "")
            tg.image = sfImage("paperplane.fill", pointSize: 12, color: .systemBlue)
            tg.target = MenuActions.shared
            sub.addItem(tg)

            let chat = NSMenuItem(title: "Open Terminal Chat", action: #selector(MenuActions.openChat(_:)), keyEquivalent: "")
            chat.image = sfImage("terminal.fill", pointSize: 12)
            chat.target = MenuActions.shared
            chat.representedObject = profile
            sub.addItem(chat)

            let logs = NSMenuItem(title: "Tail Logs", action: #selector(MenuActions.openLogs(_:)), keyEquivalent: "")
            logs.image = sfImage("doc.text.fill", pointSize: 12)
            logs.target = MenuActions.shared
            logs.representedObject = profile
            sub.addItem(logs)

            profileItem.submenu = sub
            menu.addItem(profileItem)
        }

        menu.addItem(NSMenuItem.separator())

        let openTgAll = NSMenuItem(title: "Open Telegram App", action: #selector(MenuActions.openTelegram), keyEquivalent: "")
        openTgAll.image = sfImage("paperplane.fill", pointSize: 12, color: .systemBlue)
        openTgAll.target = MenuActions.shared
        menu.addItem(openTgAll)

        let startAll = NSMenuItem(title: "Start All Profiles", action: #selector(MenuActions.startAllProfiles), keyEquivalent: "")
        startAll.image = sfImage("play.fill", pointSize: 12, color: .systemGreen)
        startAll.target = MenuActions.shared
        menu.addItem(startAll)

        let stopAll = NSMenuItem(title: "Stop All Profiles", action: #selector(MenuActions.stopAllProfiles), keyEquivalent: "")
        stopAll.image = sfImage("stop.fill", pointSize: 12, color: .systemRed)
        stopAll.target = MenuActions.shared
        menu.addItem(stopAll)

        menu.addItem(NSMenuItem.separator())

        let toggle = NSMenuItem(title: "Switch to Multi-Icon Mode", action: #selector(MenuActions.toggleDisplayMode), keyEquivalent: "")
        toggle.image = sfImage("rectangle.grid.1x2.fill", pointSize: 12)
        toggle.target = MenuActions.shared
        menu.addItem(toggle)

        let quit = NSMenuItem(title: "Quit Hermes Menu Bar", action: #selector(MenuActions.quitApp), keyEquivalent: "q")
        quit.image = sfImage("power", pointSize: 12, color: .systemRed)
        quit.target = MenuActions.shared
        menu.addItem(quit)

        singleStatusItem?.menu = menu
    }
}
