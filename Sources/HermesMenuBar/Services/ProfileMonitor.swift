import Foundation

public final class ProfileMonitor: @unchecked Sendable {
    public static let shared = ProfileMonitor()

    public var onProfilesUpdated: (([HermesProfile]) -> Void)?

    private var currentProfiles: [HermesProfile] = []
    private var fileWatchSources: [DispatchSourceFileSystemObject] = []
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "ai.hermes.menubar.monitor", qos: .utility)
    private let discovery = ProfileDiscovery.shared

    private init() {}

    public func start() {
        queue.async { [weak self] in
            self?.refresh()
            self?.setupTimer()
            self?.setupDirectoryWatchers()
        }
    }

    public func stop() {
        queue.async { [weak self] in
            self?.timer?.cancel()
            self?.timer = nil
            self?.clearFileWatchers()
        }
    }

    public func refreshNow() {
        queue.async { [weak self] in
            self?.refresh()
        }
    }

    public func setTransitionState(for profileName: String, action: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            for i in 0..<self.currentProfiles.count {
                if self.currentProfiles[i].name == profileName {
                    self.currentProfiles[i].status = .transitioning(action: action)
                }
            }
            let updated = self.currentProfiles
            DispatchQueue.main.async {
                self.onProfilesUpdated?(updated)
            }
        }
    }

    private func refresh() {
        let profiles = discovery.discoverProfiles()
        self.currentProfiles = profiles
        DispatchQueue.main.async { [weak self] in
            self?.onProfilesUpdated?(profiles)
        }
        setupFileWatchers(for: profiles)
    }

    private func setupTimer() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 4.0, repeating: 4.0)
        t.setEventHandler { [weak self] in
            self?.refresh()
        }
        t.resume()
        self.timer = t
    }

    private func setupDirectoryWatchers() {
        let hermesDir = discovery.hermesHomeURL
        let profilesDir = discovery.profilesHomeURL

        watchDirectory(at: hermesDir)
        watchDirectory(at: profilesDir)
    }

    private func watchDirectory(at url: URL) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .link],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.refresh()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        fileWatchSources.append(source)
    }

    private func setupFileWatchers(for profiles: [HermesProfile]) {
        // Watch individual state files
        for profile in profiles {
            let statePath = profile.stateFileURL.path
            if FileManager.default.fileExists(atPath: statePath) {
                let fd = open(statePath, O_EVTONLY)
                guard fd >= 0 else { continue }

                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd,
                    eventMask: [.write, .extend, .delete, .rename],
                    queue: queue
                )

                source.setEventHandler { [weak self] in
                    self?.refresh()
                }

                source.setCancelHandler {
                    close(fd)
                }

                source.resume()
                fileWatchSources.append(source)
            }
        }
    }

    private func clearFileWatchers() {
        for source in fileWatchSources {
            source.cancel()
        }
        fileWatchSources.removeAll()
    }
}
