import Foundation
import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = ProfileMonitor.shared
    private let manager = StatusItemManager.shared

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app runs purely in the menu bar without a Dock icon
        NSApp.setActivationPolicy(.accessory)

        // Bind monitor updates to UI status items
        monitor.onProfilesUpdated = { [weak self] profiles in
            Task { @MainActor in
                self?.manager.updateProfiles(profiles)
            }
        }

        // Start monitoring
        monitor.start()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }
}
