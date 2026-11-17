import AppKit
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, audio, devices, shortcuts, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return String(localized: "General")
        case .audio: return String(localized: "Audio")
        case .devices: return String(localized: "Devices")
        case .shortcuts: return String(localized: "Shortcuts")
        case .about: return String(localized: "About")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .audio: return "waveform"
        case .devices: return "headphones"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
        }
    }
}

final class SettingsNavigation: ObservableObject {
    static let shared = SettingsNavigation()
    @Published var tab: SettingsTab = .general
}

struct SettingsView: View {
    @EnvironmentObject private var nav: SettingsNavigation

    var body: some View {
        NavigationSplitView {
            List(selection: Binding<SettingsTab?>(
                get: { nav.tab },
                set: { if let tab = $0 { nav.tab = tab } }
            )) {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.symbol).tag(tab)
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 230)
        } detail: {
            Group {
                switch nav.tab {
                case .general: GeneralSettings()
                case .audio: AudioSettings()
                case .devices: DevicesSettings()
                case .shortcuts: ShortcutSettings()
                case .about: AboutSettings()
                }
            }
            .navigationTitle(nav.tab.title)
        }
        .frame(minWidth: 680, minHeight: 460)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Open Headshare at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                Toggle("Show icon in the Dock", isOn: $model.showDockIcon)
            } footer: {
                Text("Headshare keeps running in the menu bar when you close this window.")
            }

            Section("Sharing") {
                Toggle("Start sharing automatically when selected devices connect", isOn: $model.autoShare)
                Toggle("Show notifications", isOn: $model.notificationsEnabled)
            }

            Section("Help") {
                LabeledContent("Welcome tour") {
                    Button("Show again") { WindowManager.shared.showOnboarding(restart: true) }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Audio

private struct AudioSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Use the Mac's microphone while sharing", isOn: $model.keepBuiltInMic)
            } footer: {
                Text("When a Bluetooth headset is used as a microphone, macOS switches it to a low-quality call mode. Keeping the Mac's mic avoids that.")
            }

            Section {
                Toggle("Restore the previous output when sharing stops", isOn: $model.restoreOutputOnStop)
                Toggle("Hide virtual devices (Teams, Zoom, BlackHole…)", isOn: $model.hideVirtualDevices)
            }

            Section {
                LabeledContent("Sync") {
                    Button("Reset all delays") { model.resetDelays() }
                        .disabled(model.delays.values.allSatisfy { $0 == 0 })
                }
                LabeledContent("Advanced") {
                    Button("Open Audio MIDI Setup") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Audio MIDI Setup.app"))
                    }
                }
            } footer: {
                Text("Headshare uses only public macOS audio APIs: no drivers, no kernel extensions, no admin password.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Devices

private struct DevicesSettings: View {
    @EnvironmentObject private var model: AppModel

    private var selectedDevices: [OutputDevice] { model.devices.filter { model.selected.contains($0.uid) } }

    var body: some View {
        Form {
            Section("Outputs") {
                if model.devices.isEmpty {
                    Text("No outputs found").foregroundStyle(.secondary)
                }
                ForEach(model.devices) { device in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { model.selected.contains(device.uid) },
                            set: { _ in model.toggle(device.uid) }
                        )) {
                            Label {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(device.name)
                                    Text(device.transportName).font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: device.symbol)
                            }
                        }
                        if model.selected.contains(device.uid) {
                            DeviceControls(device: device).padding(.leading, 28)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if !selectedDevices.isEmpty {
                Section {
                    Picker("Sync reference", selection: Binding(
                        get: { model.effectiveClockUID ?? "" },
                        set: { model.setClock($0) }
                    )) {
                        ForEach(selectedDevices) { Text($0.name).tag($0.uid) }
                    }
                } footer: {
                    Text("The other outputs follow this device's clock. A wired or built-in output is usually the steadiest.")
                }
            }

            Section("Paired Bluetooth devices") {
                if model.paired.isEmpty {
                    Text("Every paired audio device is already connected.").foregroundStyle(.secondary)
                }
                ForEach(model.paired) { device in
                    LabeledContent(device.name) {
                        if model.connecting.contains(device.id) {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Connect") { model.connect(device) }
                        }
                    }
                }
                Button("Refresh") { model.refreshPaired(); model.refreshDevices() }
            }
        }
        .formStyle(.grouped)
        .task { model.refreshPaired() }
    }
}

// MARK: - Shortcuts

private struct ShortcutSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Picker("Start or stop sharing", selection: $model.hotKey) {
                    ForEach(HotKeyOption.allCases) { Text($0.label).tag($0) }
                }
            } footer: {
                Text("Works from any app. No Accessibility permission needed.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About

private struct AboutSettings: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return String(localized: "Version \(v) (\(b))")
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            AppIconView(size: 112).shadow(color: .black.opacity(0.3), radius: 16, y: 8)
            Text(verbatim: "Headshare").font(.system(size: 28, weight: .bold))
            Text(version).foregroundStyle(.secondary)
            Text("Free and open source. No subscriptions, ever.")
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Link(destination: URL(string: "https://github.com/numbfede/Headshare")!) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .glassButton()
                Link(destination: URL(string: "https://github.com/numbfede/Headshare/issues")!) {
                    Label("Report a problem", systemImage: "exclamationmark.bubble")
                }
                .glassButton()
            }
            .padding(.top, 6)
            Spacer()
            VStack(spacing: 4) {
                Text("Made by numbfede").font(.caption).foregroundStyle(.tertiary)
                Link("Headphones glyph by Icons8", destination: URL(string: "https://icons8.com")!)
                    .font(.caption)
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
