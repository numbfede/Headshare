import AppKit
import CoreAudio
import Foundation
import ServiceManagement

final class AppModel: ObservableObject {
    static let shared = AppModel()
    static let aggregateUID = "com.numbfede.headshare.aggregate"

    // MARK: Devices
    @Published private(set) var allDevices: [OutputDevice] = []
    @Published private(set) var volumes: [String: Float] = [:]
    @Published private(set) var settable: Set<String> = []
    @Published private(set) var paired: [PairedDevice] = []
    @Published private(set) var connecting: Set<String> = []
    @Published var pairedExpanded = false

    // MARK: Sharing state
    @Published private(set) var isSharing = false
    @Published private(set) var sharedUIDs: [String] = []
    @Published private(set) var masterVolume: Float = 1
    @Published var message: String?

    // MARK: Persisted selection
    @Published private(set) var selected: Set<String> = []
    @Published private(set) var clockUID: String?
    @Published private(set) var delays: [String: Double] = [:]

    // MARK: Settings
    /// True while init restores saved values: property observers must not run then.
    private var isLoading = true

    @Published var autoShare = false { didSet { guard !isLoading else { return }; persist(); if autoShare { autoStartIfPossible() } } }
    @Published var keepBuiltInMic = true { didSet { guard !isLoading else { return }; persist() } }
    @Published var hideVirtualDevices = true { didSet { guard !isLoading else { return }; persist() } }
    @Published var restoreOutputOnStop = true { didSet { guard !isLoading else { return }; persist() } }
    @Published var notificationsEnabled = true {
        didSet { guard !isLoading else { return }; persist(); if notificationsEnabled { Notifier.requestAuthorization() } }
    }
    @Published var showDockIcon = false { didSet { guard !isLoading else { return }; persist(); WindowManager.shared.updateActivationPolicy() } }
    @Published var hotKey: HotKeyOption = .ctrlOptCmdH { didSet { guard !isLoading else { return }; persist(); HotKeyCenter.shared.register(hotKey) } }
    @Published var onboardingCompleted = false { didSet { guard !isLoading else { return }; persist() } }
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var aggregateID: AudioDeviceID = 0
    private var previousOutputUID: String?
    private var previousInputUID: String?
    private var transitioning = false
    private var transitionToken = 0
    private var knownUIDs: Set<String> = []
    private var rebuildWork: DispatchWorkItem?
    private let defaults = UserDefaults.standard
    private let bluetooth = BluetoothManager()

    private init() {
        selected = Set(defaults.stringArray(forKey: "selected") ?? [])
        clockUID = defaults.string(forKey: "clock")
        delays = (defaults.dictionary(forKey: "delays") as? [String: Double]) ?? [:]
        autoShare = bool("autoShare", false)
        keepBuiltInMic = bool("keepBuiltInMic", true)
        hideVirtualDevices = bool("hideVirtualDevices", true)
        restoreOutputOnStop = bool("restoreOutputOnStop", true)
        notificationsEnabled = bool("notificationsEnabled", true)
        showDockIcon = bool("showDockIcon", false)
        onboardingCompleted = bool("onboardingCompleted", false)
        hotKey = HotKeyOption(rawValue: defaults.string(forKey: "hotKey") ?? "") ?? .ctrlOptCmdH
        isLoading = false

        removeStaleAggregates()
        refreshDevices()
        knownUIDs = Set(allDevices.map(\.uid))

        AudioSystem.listen(AudioSystem.system, kAudioHardwarePropertyDevices) { [weak self] in self?.devicesChanged() }
        AudioSystem.listen(AudioSystem.system, kAudioHardwarePropertyDefaultOutputDevice) { [weak self] in self?.defaultOutputChanged() }

        HotKeyCenter.shared.action = { [weak self] in self?.toggleFromHotKey() }
        HotKeyCenter.shared.register(hotKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.autoStartIfPossible() }
    }

    private func bool(_ key: String, _ fallback: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? fallback
    }

    private func persist() {
        defaults.set(Array(selected), forKey: "selected")
        defaults.set(clockUID, forKey: "clock")
        defaults.set(delays, forKey: "delays")
        defaults.set(autoShare, forKey: "autoShare")
        defaults.set(keepBuiltInMic, forKey: "keepBuiltInMic")
        defaults.set(hideVirtualDevices, forKey: "hideVirtualDevices")
        defaults.set(restoreOutputOnStop, forKey: "restoreOutputOnStop")
        defaults.set(notificationsEnabled, forKey: "notificationsEnabled")
        defaults.set(showDockIcon, forKey: "showDockIcon")
        defaults.set(onboardingCompleted, forKey: "onboardingCompleted")
        defaults.set(hotKey.rawValue, forKey: "hotKey")
    }

    // MARK: Derived

    /// Outputs shown in the UI.
    var devices: [OutputDevice] {
        guard hideVirtualDevices else { return allDevices }
        return allDevices.filter { !$0.isVirtual || selected.contains($0.uid) }
    }

    var selectedConnected: [String] { allDevices.filter { selected.contains($0.uid) }.map(\.uid) }
    var canStart: Bool { selectedConnected.count >= 2 }
    var firstSelectedUID: String? { devices.first { selected.contains($0.uid) }?.uid }

    var effectiveClockUID: String? { resolvedClock(in: isSharing ? sharedUIDs : selectedConnected) }

    var statusText: String {
        if isSharing { return String(localized: "Sharing to \(sharedUIDs.count) devices") }
        let n = selectedConnected.count
        switch n {
        case 0: return String(localized: "Pick at least 2 outputs")
        case 1: return String(localized: "Pick 1 more output")
        default: return String(localized: "Ready to share to \(n) outputs")
        }
    }

    func name(of uid: String) -> String { allDevices.first { $0.uid == uid }?.name ?? uid }

    private func resolvedClock(in uids: [String]) -> String? {
        if let c = clockUID, uids.contains(c) { return c }
        let wired = allDevices.first { uids.contains($0.uid) && !$0.isBluetooth }
        return wired?.uid ?? uids.first
    }

    // MARK: Refresh

    func refreshDevices() {
        let list = AudioSystem.outputDevices()
        var vols: [String: Float] = [:]
        var canSet = Set<String>()
        for d in list {
            if let v = AudioSystem.volume(d.id) { vols[d.uid] = v }
            if AudioSystem.isVolumeSettable(d.id) { canSet.insert(d.uid) }
        }
        allDevices = list
        volumes = vols
        settable = canSet
    }

    func refreshPaired() {
        let list = bluetooth.pairedAudioDevices().filter { !$0.isConnected }
        let counts = Dictionary(grouping: list, by: \.name).mapValues(\.count)
        paired = list.map { p in
            (counts[p.name] ?? 0) > 1
                ? PairedDevice(id: p.id, name: "\(p.name) (…\(p.id.suffix(5)))", isConnected: false)
                : p
        }
    }

    private func devicesChanged() {
        refreshDevices()
        let present = Set(allDevices.map(\.uid))
        let appeared = present.subtracting(knownUIDs)
        knownUIDs = present
        refreshPaired()
        guard !transitioning else { return }

        if isSharing {
            let wanted = selectedConnected
            if Set(wanted) != Set(sharedUIDs) {
                if wanted.count >= 2 {
                    scheduleRebuild(after: 0.4)
                } else {
                    stop(message: String(localized: "A device disconnected, so sharing stopped."))
                    notify(String(localized: "Sharing stopped"), String(localized: "A device disconnected."))
                }
            }
        } else if !appeared.isDisjoint(with: selected) {
            autoStartIfPossible()
        }
    }

    private func defaultOutputChanged() {
        guard isSharing, !transitioning else { return }
        if AudioSystem.defaultDevice(kAudioHardwarePropertyDefaultOutputDevice) != aggregateID {
            stop(message: String(localized: "You switched output elsewhere, so sharing stopped."), restore: false)
        }
    }

    private func autoStartIfPossible() {
        guard autoShare, !isSharing, canStart else { return }
        start()
        if isSharing { notify(String(localized: "Sharing started"), String(localized: "Audio is playing on \(sharedUIDs.count) devices.")) }
    }

    // MARK: Actions

    func toggleSharing() { isSharing ? stop() : start() }

    private func toggleFromHotKey() {
        toggleSharing()
        if isSharing {
            notify(String(localized: "Sharing on"), String(localized: "Audio is playing on \(sharedUIDs.count) devices."))
        } else if let message {
            notify(String(localized: "Couldn't start sharing"), message)
        } else {
            notify(String(localized: "Sharing off"), String(localized: "Audio is back on a single output."))
        }
    }

    func toggle(_ uid: String) {
        if selected.contains(uid) { selected.remove(uid) } else { selected.insert(uid) }
        persist()
        message = nil
        if isSharing {
            if canStart { scheduleRebuild(after: 0.1) } else { stop() }
        }
    }

    func setClock(_ uid: String) {
        clockUID = uid
        persist()
        if isSharing { scheduleRebuild(after: 0.1) }
    }

    func setVolume(_ value: Float, for uid: String) {
        guard let id = AudioSystem.deviceID(forUID: uid) else { return }
        AudioSystem.setVolume(id, value)
        volumes[uid] = value
    }

    func setMasterVolume(_ value: Float) {
        let delta = value - masterVolume
        masterVolume = value
        for uid in sharedUIDs where settable.contains(uid) {
            setVolume(max(0, min(1, (volumes[uid] ?? 1) + delta)), for: uid)
        }
    }

    func setDelay(_ ms: Double, for uid: String) {
        delays[uid] = ms
        persist()
        guard isSharing, sharedUIDs.contains(uid) else { return }
        let frames = ms / 1000 * AudioSystem.sampleRate(aggregateID)
        if AudioSystem.setSubDeviceLatency(aggregate: aggregateID, uid: uid, frames: frames) { return }
        scheduleRebuild(after: 0.6)
    }

    func resetDelays() {
        delays = [:]
        persist()
        if isSharing { scheduleRebuild(after: 0.1) }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            message = String(localized: "Couldn't change Open at login: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func connect(_ device: PairedDevice) {
        connecting.insert(device.id)
        bluetooth.connect(address: device.id) { [weak self] ok in
            guard let self else { return }
            self.connecting.remove(device.id)
            if !ok { self.message = String(localized: "Couldn't connect to \(device.name). Make sure it's on and nearby.") }
            self.refreshPaired()
        }
    }

    private func notify(_ title: String, _ body: String) {
        guard notificationsEnabled else { return }
        Notifier.post(title: title, body: body)
    }

    // MARK: Sharing lifecycle

    func start() {
        let wanted = selectedConnected
        guard wanted.count >= 2 else { message = String(localized: "Pick at least two connected outputs."); return }
        if !isSharing {
            let current = AudioSystem.defaultDevice(kAudioHardwarePropertyDefaultOutputDevice)
            if let uid = AudioSystem.uid(current), uid != Self.aggregateUID { previousOutputUID = uid }
        }
        build(wanted)
    }

    func stop(message: String? = nil, restore: Bool? = nil) {
        rebuildWork?.cancel()
        beginTransition()
        if restore ?? restoreOutputOnStop {
            let target = previousOutputUID.flatMap(AudioSystem.deviceID(forUID:))
                ?? AudioSystem.builtInDevice(scope: kAudioObjectPropertyScopeOutput)
            if let target { AudioSystem.setDefaultDevice(kAudioHardwarePropertyDefaultOutputDevice, target) }
        }
        restoreMic()
        AudioSystem.destroyAggregate(aggregateID)
        aggregateID = 0
        isSharing = false
        sharedUIDs = []
        previousOutputUID = nil
        masterVolume = 1
        self.message = message
    }

    /// Called on quit: leave the system exactly as we found it.
    func shutdown() {
        if isSharing { stop(restore: true) }
        removeStaleAggregates()
    }

    private func scheduleRebuild(after delay: TimeInterval) {
        rebuildWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isSharing else { return }
            let wanted = self.selectedConnected
            if wanted.count >= 2 { self.build(wanted) } else { self.stop() }
        }
        rebuildWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func build(_ uids: [String]) {
        beginTransition()
        AudioSystem.destroyAggregate(aggregateID)
        aggregateID = 0

        guard let clock = resolvedClock(in: uids) else { return }
        let rate = AudioSystem.deviceID(forUID: clock).map(AudioSystem.sampleRate) ?? 48_000
        let subs = uids.map { AudioSystem.SubDevice(uid: $0, latencyFrames: Int((delays[$0] ?? 0) / 1000 * rate)) }

        guard let id = AudioSystem.createAggregate(uid: Self.aggregateUID, name: "Headshare", clockUID: clock, subdevices: subs) else {
            isSharing = false
            sharedUIDs = []
            message = String(localized: "Couldn't create the shared output. Try again or reconnect your devices.")
            return
        }
        aggregateID = id
        sharedUIDs = uids
        isSharing = true
        message = nil
        applyMicFix()

        // The HAL needs a moment before a freshly created aggregate can become the default.
        func activate(_ attempt: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self, self.aggregateID == id else { return }
                self.beginTransition()
                let ok = AudioSystem.setDefaultDevice(kAudioHardwarePropertyDefaultOutputDevice, id)
                if !ok && attempt < 4 { activate(attempt + 1) }
                if !ok && attempt >= 4 { self.message = String(localized: "macOS didn't accept the shared output.") }
            }
        }
        activate(0)
    }

    private func beginTransition() {
        transitioning = true
        transitionToken += 1
        let token = transitionToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.transitionToken == token else { return }
            self.transitioning = false
        }
    }

    private func removeStaleAggregates() {
        for id in AudioSystem.allDeviceIDs() where AudioSystem.uid(id) == Self.aggregateUID {
            AudioSystem.destroyAggregate(id)
        }
    }

    // MARK: Microphone (avoid Bluetooth "call mode", which degrades output quality)

    private func applyMicFix() {
        guard keepBuiltInMic else { return }
        let input = AudioSystem.defaultDevice(kAudioHardwarePropertyDefaultInputDevice)
        let t = AudioSystem.transport(input)
        guard t == kAudioDeviceTransportTypeBluetooth || t == kAudioDeviceTransportTypeBluetoothLE,
              let builtIn = AudioSystem.builtInDevice(scope: kAudioObjectPropertyScopeInput) else { return }
        if previousInputUID == nil { previousInputUID = AudioSystem.uid(input) }
        AudioSystem.setDefaultDevice(kAudioHardwarePropertyDefaultInputDevice, builtIn)
    }

    private func restoreMic() {
        if let uid = previousInputUID, let id = AudioSystem.deviceID(forUID: uid) {
            AudioSystem.setDefaultDevice(kAudioHardwarePropertyDefaultInputDevice, id)
        }
        previousInputUID = nil
    }
}
