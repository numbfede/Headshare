import AppKit
import SwiftUI

private enum StepKind: Int, CaseIterable {
    case connect, select, reference, start, menuBar, settings
}

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var started = false
    @State private var step: StepKind = .connect

    var body: some View {
        ZStack {
            if started {
                tour.transition(.opacity)
            } else {
                WelcomePage(
                    onStart: { withAnimation(.easeInOut(duration: 0.35)) { started = true }; prepare(.connect) },
                    onSkip: finish
                )
                .transition(.opacity)
            }
        }
        .frame(width: 900, height: 640)
    }

    // MARK: Tour layout

    private var tour: some View {
        HStack(spacing: 0) {
            StepPanel(
                kind: step,
                hint: hint,
                canContinue: canContinue,
                onBack: step == .connect ? nil : { go(-1) },
                onNext: { step == .settings ? finish() : go(1) },
                onSkip: finish
            )
            .frame(width: 340)

            ZStack {
                Backdrop()
                if step == .menuBar {
                    MenuBarIllustration(hotKey: model.hotKey)
                        .transition(.opacity)
                } else {
                    ScrollView(showsIndicators: false) {
                        MenuContent()
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(.regularMaterial)
                                    .shadow(color: .black.opacity(0.35), radius: 30, y: 14)
                            )
                            .padding(.vertical, 48)
                            .frame(maxWidth: .infinity)
                    }
                    .overlayPreferenceValue(TourAnchorKey.self) { anchors in
                        SpotlightOverlay(anchors: anchors, target: target)
                    }
                    .transition(.opacity)
                }
            }
            .clipped()
        }
        .onChange(of: model.isSharing) { _, sharing in
            if sharing && step == .start {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { if step == .start { go(1) } }
            }
        }
    }

    // MARK: Step logic

    private var target: TourTarget? {
        switch step {
        case .connect: return model.paired.isEmpty ? .outputs : .connect
        case .select: return .outputs
        case .reference: return model.firstSelectedUID == nil ? .outputs : .row
        case .start: return .toggle
        case .menuBar: return nil
        case .settings: return .settings
        }
    }

    private var canContinue: Bool {
        step == .select ? model.selectedConnected.count >= 2 : true
    }

    private var hint: StepHint? {
        switch step {
        case .connect:
            let n = model.allDevices.filter(\.isBluetooth).count
            return StepHint(done: n >= 1, text: n == 0 ? String(localized: "No Bluetooth headphones connected yet") : String(localized: "Bluetooth outputs connected: \(n)"))
        case .select:
            let n = model.selectedConnected.count
            return StepHint(done: n >= 2, text: n >= 2 ? String(localized: "Outputs selected: \(n)") : String(localized: "Selected: \(n) of 2"))
        case .start:
            return StepHint(done: model.isSharing, text: model.isSharing ? String(localized: "Sharing is on. Enjoy!") : String(localized: "Waiting for the switch…"))
        default:
            return nil
        }
    }

    private func go(_ delta: Int) {
        guard let next = StepKind(rawValue: step.rawValue + delta) else { return }
        prepare(next)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step = next }
    }

    private func prepare(_ kind: StepKind) {
        model.refreshPaired()
        if kind == .connect { withAnimation { model.pairedExpanded = true } }
        if kind == .select { withAnimation { model.pairedExpanded = false } }
    }

    private func finish() {
        model.onboardingCompleted = true
        if model.notificationsEnabled { Notifier.requestAuthorization() }
        WindowManager.shared.closeOnboarding()
    }
}

// MARK: - Step copy

private extension StepKind {
    var number: Int { rawValue + 1 }
    static var total: Int { allCases.count }

    var symbol: String {
        switch self {
        case .connect: return "dot.radiowaves.left.and.right"
        case .select: return "checklist"
        case .reference: return "crown.fill"
        case .start: return "power"
        case .menuBar: return "menubar.rectangle"
        case .settings: return "gearshape.fill"
        }
    }

    var title: String {
        switch self {
        case .connect: return String(localized: "Connect your headphones")
        case .select: return String(localized: "Pick where the sound goes")
        case .reference: return String(localized: "Fine-tune each output")
        case .start: return String(localized: "Start sharing")
        case .menuBar: return String(localized: "Always one click away")
        case .settings: return String(localized: "Make it yours")
        }
    }

    var body: String {
        switch self {
        case .connect:
            return String(localized: "Turn on the headphones or speakers you want to use. If they're already paired with this Mac, open “Connect a device” and click them. Headshare connects them for you.")
        case .select:
            return String(localized: "Click anywhere on an output to select it. Pick at least two: for example your AirPods and a friend's headphones, or headphones plus the Mac speakers.")
        case .reference:
            return String(localized: "The crown marks the sync reference. A wired or built-in output keeps the steadiest timing. Click the sliders button to set each output's volume, or add a few milliseconds of delay if one is behind.")
        case .start:
            return String(localized: "Flip the switch. Everything your Mac plays now comes out of every selected output at the same time.")
        case .menuBar:
            return String(localized: "Headshare lives in your menu bar and keeps running in the background. Click the headphones icon anytime, or use the keyboard shortcut from any app.")
        case .settings:
            return String(localized: "Open Settings to start at login, share automatically when your devices connect, change the shortcut, and more.")
        }
    }
}

private struct StepHint {
    let done: Bool
    let text: String
}

// MARK: - Left panel

private struct StepPanel: View {
    let kind: StepKind
    let hint: StepHint?
    let canContinue: Bool
    let onBack: (() -> Void)?
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 5) {
                ForEach(StepKind.allCases, id: \.self) { k in
                    Capsule()
                        .fill(k.rawValue <= kind.rawValue ? Color.accentColor : Color.primary.opacity(0.15))
                        .frame(width: k == kind ? 22 : 8, height: 8)
                }
            }
            .padding(.top, 36)

            Text("Step \(kind.number) of \(StepKind.total)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ZStack {
                Circle().fill(Color.accentColor.opacity(0.15)).frame(width: 56, height: 56)
                Image(systemName: kind.symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .contentTransition(.symbolEffect(.replace))
            }

            Text(kind.title)
                .font(.system(size: 24, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(kind.body)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let hint {
                Label(hint.text, systemImage: hint.done ? "checkmark.circle.fill" : "circle.dotted")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(hint.done ? Color.green : Color.secondary)
                    .contentTransition(.opacity)
                    .animation(.snappy, value: hint.done)
            }

            Spacer()

            HStack {
                if let onBack {
                    Button("Back", action: onBack)
                        .glassButton()
                        .controlSize(.large)
                }
                Spacer()
                Button(kind == .settings ? String(localized: "Finish") : String(localized: "Continue"), action: onNext)
                    .glassButton(prominent: true)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canContinue)
            }

            Button("Skip tutorial", action: onSkip)
                .buttonStyle(.link)
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 28)
        .animation(.snappy(duration: 0.25), value: kind)
    }
}

// MARK: - Welcome

private struct WelcomePage: View {
    let onStart: () -> Void
    let onSkip: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 22) {
                AppIconView(size: 128)
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Welcome to Headshare")
                        .font(.system(size: 34, weight: .bold))
                    Text("Play your Mac's audio on several headphones and speakers at once.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Feature(symbol: "headphones", title: "Any number of outputs", text: "AirPods, Bluetooth, USB, HDMI and the Mac speakers.")
                    Feature(symbol: "slider.horizontal.3", title: "Per-device control", text: "Volume and delay for each output, so they stay in sync.")
                    Feature(symbol: "gift.fill", title: "Free, for real", text: "No subscription, no limits, no account.")
                }
                .padding(22)
                .frame(width: 440)
                .glassCard(cornerRadius: 20)

                Button(action: onStart) {
                    Text("Show me how").frame(width: 200)
                }
                .glassButton(prominent: true)
                .controlSize(.extraLarge)
                .keyboardShortcut(.defaultAction)

                Button("Skip, I know what I'm doing", action: onSkip)
                    .buttonStyle(.link)
                    .font(.callout)
            }
            .padding(40)
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appeared = true } }
    }
}

private struct Feature: View {
    let symbol: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Visuals

private struct Backdrop: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.55, green: 0.42, blue: 1.0).opacity(0.55),
                     Color(red: 0.22, green: 0.13, blue: 0.62).opacity(0.75)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(colors: [.white.opacity(0.22), .clear], center: .topLeading, startRadius: 10, endRadius: 520)
        )
        .ignoresSafeArea()
    }
}

private struct MenuBarIllustration: View {
    let hotKey: HotKeyOption

    var body: some View {
        VStack(spacing: 28) {
            HStack(spacing: 18) {
                ForEach(["wifi", "battery.75percent", "magnifyingglass"], id: \.self) { s in
                    Image(systemName: s).foregroundStyle(.secondary)
                }
                Image(systemName: "headphones")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.primary.opacity(0.12)))
                    .overlay(PulsingCapsule())
                Text(Date.now, style: .time).font(.callout).foregroundStyle(.secondary)
            }
            .font(.system(size: 14))
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .frame(width: 440, alignment: .trailing)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)

            if hotKey != .none {
                VStack(spacing: 8) {
                    Text("Toggle sharing from anywhere")
                        .font(.headline)
                    Text(hotKey.label)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .glassCard(cornerRadius: 14)
                    Text("Change it in Settings › Shortcuts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .glassCard(cornerRadius: 20)
            }
        }
    }
}

private struct PulsingCapsule: View {
    @State private var pulse = false
    var body: some View {
        Capsule()
            .strokeBorder(Color.accentColor, lineWidth: 2)
            .shadow(color: Color.accentColor, radius: pulse ? 12 : 3)
            .scaleEffect(pulse ? 1.12 : 1.02)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}
