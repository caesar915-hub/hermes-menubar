import Foundation
import AppKit

@MainActor
public final class ProfileStatusItem: NSObject, NSMenuDelegate {
    public let profileName: String
    private(set) var statusItem: NSStatusItem
    private var currentProfile: HermesProfile?
    private let menuBuilder = ProfileMenuBuilder()

    public init(profileName: String) {
        self.profileName = profileName
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setupButton()
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(buttonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    public func update(with profile: HermesProfile) {
        self.currentProfile = profile
        guard let button = statusItem.button else { return }

        let badge = profile.badgeLabel

        // Generate combined status image
        let image = renderStatusImage(status: profile.status, badge: badge)
        button.image = image
        button.imagePosition = .imageLeft
        button.title = ""
        button.toolTip = "Hermes Profile: \(profile.displayName)\nStatus: \(profile.status.statusText)\nModel: \(profile.modelName ?? "Default")"
    }

    private func renderStatusImage(status: ProfileStatus, badge: String) -> NSImage {
        let font = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .bold)
        let badgeAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let badgeSize = (badge as NSString).size(withAttributes: badgeAttributes)

        let dotDiameter: CGFloat = 6.0
        let iconWidth: CGFloat = 13.0
        let iconHeight: CGFloat = 13.0
        let spacing: CGFloat = 3.5
        let totalWidth: CGFloat = iconWidth + spacing + dotDiameter + spacing + badgeSize.width + 4.0
        let height: CGFloat = 18.0

        let image = NSImage(size: NSSize(width: totalWidth, height: height))
        image.lockFocus()

        // 1. Draw Paperplane Icon
        var sfSymbolName = "paperplane.fill"
        var iconColor = NSColor.labelColor

        switch status {
        case .running(_, let connected, _):
            if connected {
                sfSymbolName = "paperplane.fill"
                iconColor = NSColor.controlAccentColor
            } else {
                sfSymbolName = "paperplane"
                iconColor = NSColor.secondaryLabelColor
            }
        case .stopped:
            sfSymbolName = "paperplane"
            iconColor = NSColor.tertiaryLabelColor
        case .transitioning:
            sfSymbolName = "paperplane.fill"
            iconColor = NSColor.systemYellow
        case .error:
            sfSymbolName = "exclamationmark.triangle.fill"
            iconColor = NSColor.systemRed
        }

        let baseConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        let colorConfig = NSImage.SymbolConfiguration(paletteColors: [iconColor])
        let config = baseConfig.applying(colorConfig)

        if let symbolImage = NSImage(systemSymbolName: sfSymbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let iconRect = NSRect(x: 1, y: (height - iconHeight) / 2, width: iconWidth, height: iconHeight)
            symbolImage.draw(in: iconRect)
        }

        // 2. Draw Status Dot
        let dotColor: NSColor
        switch status {
        case .running(_, let connected, _):
            dotColor = connected ? NSColor.systemGreen : NSColor.systemYellow
        case .stopped:
            dotColor = NSColor.systemGray.withAlphaComponent(0.6)
        case .transitioning:
            dotColor = NSColor.systemOrange
        case .error:
            dotColor = NSColor.systemRed
        }

        let dotRect = NSRect(x: iconWidth + spacing, y: (height - dotDiameter) / 2, width: dotDiameter, height: dotDiameter)
        let dotPath = NSBezierPath(ovalIn: dotRect)
        dotColor.setFill()
        dotPath.fill()

        // 3. Draw Badge Text (e.g. DEF, MM, MKT)
        let textX = iconWidth + spacing + dotDiameter + spacing
        let textY = (height - badgeSize.height) / 2 - 0.5
        (badge as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: badgeAttributes)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        guard let profile = currentProfile else { return }
        let menu = menuBuilder.buildMenu(for: profile)
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    public func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    public func remove() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
