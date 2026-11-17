import AppKit
import SwiftUI

/// The menu bar panel. Also embedded live in the Welcome tour.
struct MenuContent: View {
    @EnvironmentObject private var model: AppModel
    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(spacing: 10) {
            HeaderCard()
            OutputsCard(expanded: $expanded)
            if !model.paired.isEmpty {
                ConnectCard()
            }
            if let message = model.message {
                MessageBanner(text: message) { withAnimation { model.message = nil } }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            FooterBar()
        }
        .padding(12)
        .frame(width: 360)
        .animation(.snappy(duration: 0.22), value: model.isSharing)
        .animation(.snappy(duration: 0.22), value: model.message)
        .task {
            // Runs after the first render: refreshing inside onAppear would publish during a view update.
            model.refreshDevices()
            model.refreshPaired()
        }
    }
}

// MARK: - Header

private struct HeaderCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AppIconView(size: 40)
                if model.isSharing {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 1))
                        .offset(x: 2, y: 2)
                        .transition(.scale)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Headshare").font(.system(size: 15, weight: .semibold))
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 8)
            Toggle("Share audio", isOn: Binding(
                get: { model.isSharing },
                set: { _ in model.toggleSharing() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.large)
            .disabled(!model.isSharing && !model.canStart)
            .help(model.canStart || model.isSharing ? String(localized: "Start or stop sharing") : String(localized: "Pick at least 2 outputs first"))
            .tourAnchor(.toggle)
        }
        .padding(12)
        .glassCard()
    }
}

// MARK: - Outputs

private struct OutputsCard: View {
    @EnvironmentObject private var model: AppModel
    @Binding var expanded: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionTitle(title: "Outputs",
                         trailing: model.selectedConnected.isEmpty ? nil : String(localized: "\(model.selectedConnected.count) selected"))
            if model.devices.isEmpty {
                Text("No outputs found")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
            ForEach(model.devices) { device in
                DeviceRow(
                    device: device,
                    expanded: Binding(
                        get: { expanded.contains(device.uid) },
                        set: { if $0 { expanded.insert(device.uid) } else { expanded.remove(device.uid) } }
                    ),
                    isTourRow: device.uid == model.firstSelectedUID
                )
            }
            if model.isSharing && model.sharedUIDs.contains(where: model.settable.contains) {
                Divider().padding(.horizontal, 10).padding(.vertical, 6)
                MasterVolume().padding(.horizontal, 10).padding(.bottom, 4)
            }
        }
        .padding(6)
        .glassCard()
        .tourAnchor(.outputs)
    }
}

struct DeviceRow: View {
    @EnvironmentObject private var model: AppModel
    let device: OutputDevice
    @Binding var expanded: Bool
    var isTourRow = false
    @State private var hovering = false

    private var isSelected: Bool { model.selected.contains(device.uid) }
    private var isClock: Bool { isSelected && model.effectiveClockUID == device.uid }
    private var isLive: Bool { model.sharedUIDs.contains(device.uid) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                // The whole row is the selection button.
                Button {
                    withAnimation(.snappy(duration: 0.2)) { model.toggle(device.uid) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .contentTransition(.symbolEffect(.replace))
                        Image(systemName: device.symbol)
                            .font(.system(size: 14))
                            .frame(width: 20)
                            .foregroundStyle(Color.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(device.name).lineLimit(1).truncationMode(.tail)
                            Text(subtitle).font(.caption2).foregroundStyle(Color.secondary)
                                .lineLimit(1).truncationMode(.tail)
                        }
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(device.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])

                if isLive {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(Color.green)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                        .help("Playing")
                }
                if isSelected {
                    IconButton(symbol: isClock ? "crown.fill" : "crown",
                               tint: isClock ? .yellow : .secondary,
                               help: "Make this the sync reference") { model.setClock(device.uid) }
                    IconButton(symbol: "slider.horizontal.3",
                               tint: expanded ? .accentColor : .secondary,
                               help: "Volume and delay") {
                        withAnimation(.snappy(duration: 0.2)) { expanded.toggle() }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            if isSelected && expanded {
                DeviceControls(device: device)
                    .padding(.leading, 40)
                    .padding(.trailing, 10)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(rowFill))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .tourAnchor(.row, enabled: isTourRow)
    }

    private var rowFill: Color {
        if isSelected { return Color.accentColor.opacity(hovering ? 0.24 : 0.16) }
        return Color.primary.opacity(hovering ? 0.07 : 0)
    }

    private var subtitle: String {
        var parts = [device.transportName]
        if isClock { parts.append(String(localized: "Sync reference")) }
        if isLive { parts.append(String(localized: "Playing")) }
        return parts.joined(separator: " · ")
    }
}

struct IconButton: View {
    let symbol: String
    var tint: Color = .secondary
    var help: LocalizedStringKey = ""
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.primary.opacity(hovering ? 0.1 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(Text(help))
    }
}

/// Per-device volume and delay. Shared by the menu and Settings.
struct DeviceControls: View {
    @EnvironmentObject private var model: AppModel
    let device: OutputDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .frame(width: 16)
                    .foregroundStyle(.secondary)
                if model.settable.contains(device.uid) {
                    Slider(value: Binding(
                        get: { Double(model.volumes[device.uid] ?? 1) },
                        set: { model.setVolume(Float($0), for: device.uid) }
                    ), in: 0...1)
                    .controlSize(.small)
                } else {
                    Label("Change volume on the device itself", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.caption)
                    .frame(width: 16)
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { model.delays[device.uid] ?? 0 },
                    set: { model.setDelay($0, for: device.uid) }
                ), in: 0...500, step: 5)
                .controlSize(.small)
                Text("\(Int(model.delays[device.uid] ?? 0)) ms")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 46, alignment: .trailing)
            }
            .help("Delay this output to line it up with the others")
        }
    }
}

private struct MasterVolume: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill").font(.caption).foregroundStyle(.secondary)
            Slider(value: Binding(
                get: { Double(model.masterVolume) },
                set: { model.setMasterVolume(Float($0)) }
            ), in: 0...1)
            .controlSize(.small)
            Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundStyle(.secondary)
        }
        .help("Master volume for every output that allows it")
    }
}

// MARK: - Connect

private struct ConnectCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.snappy(duration: 0.22)) { model.pairedExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.accentColor)
                    Text("Connect a device").font(.system(size: 13, weight: .medium))
                    Text("\(model.paired.count)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.1)))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(model.pairedExpanded ? 90 : 0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if model.pairedExpanded {
                ForEach(model.paired) { device in
                    PairedRow(device: device)
                }
                .transition(.opacity)
            }
        }
        .padding(6)
        .glassCard()
        .tourAnchor(.connect)
    }
}

private struct PairedRow: View {
    @EnvironmentObject private var model: AppModel
    let device: PairedDevice
    @State private var hovering = false

    private var isConnecting: Bool { model.connecting.contains(device.id) }

    var body: some View {
        Button { if !isConnecting { model.connect(device) } } label: {
            HStack(spacing: 10) {
                Image(systemName: "headphones")
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                Text(device.name).lineLimit(1)
                Spacer()
                if isConnecting {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Connect")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(hovering ? Color.white : Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentColor.opacity(hovering ? 1 : 0.15)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.06 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

// MARK: - Footer & banner

private struct MessageBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.orange)
            Text(text).font(.caption).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.orange.opacity(0.14)))
    }
}

private struct FooterBar: View {
    var body: some View {
        HStack(spacing: 8) {
            Button {
                StatusItemController.shared.close()
                WindowManager.shared.showSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .glassButton()
            .tourAnchor(.settings)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .glassButton()
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 2)
    }
}
