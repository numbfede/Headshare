import AppKit
import SwiftUI

// Liquid Glass on macOS 26+, tasteful material fallback on macOS 14–15.
// `#if compiler` keeps the project building with older Xcode versions too.

extension View {
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.materialCard(cornerRadius)
        }
        #else
        self.materialCard(cornerRadius)
        #endif
    }

    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            if prominent { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.glass) }
        } else {
            self.legacyButton(prominent)
        }
        #else
        self.legacyButton(prominent)
        #endif
    }

    @ViewBuilder
    private func legacyButton(_ prominent: Bool) -> some View {
        if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
    }

    private func materialCard(_ radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(shape.fill(Color.primary.opacity(0.055)))
            .overlay(shape.strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
    }
}

struct SectionTitle: View {
    let title: LocalizedStringKey
    var trailing: String?

    var body: some View {
        HStack {
            Text(title)
                .textCase(.uppercase)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Spacer()
            if let trailing {
                Text(trailing).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

enum AppIcon {
    static var isBundled: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    /// When Xcode runs the bare SwiftPM executable there is no bundle and macOS would show a
    /// generic folder. Use the icon that build.sh compiled from Resources/AppIcon.icon instead.
    static let devIcon: NSImage? = {
        let app = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Headshare
            .deletingLastPathComponent()   // Sources
            .deletingLastPathComponent()   // package root
            .appendingPathComponent("build/Headshare.app")
        guard FileManager.default.fileExists(atPath: app.path) else { return nil }
        return NSWorkspace.shared.icon(forFile: app.path)
    }()

    static var image: NSImage {
        if isBundled { return NSApp.applicationIconImage }
        return devIcon ?? NSApp.applicationIconImage
    }
}

struct AppIconView: View {
    var size: CGFloat = 36
    var body: some View {
        if AppIcon.isBundled || AppIcon.devIcon != nil {
            Image(nsImage: AppIcon.image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            // Running from Xcode before ./build.sh has produced build/Headshare.app.
            Image(systemName: "headphones")
                .font(.system(size: size * 0.5, weight: .semibold))
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .fill(Color.primary.opacity(0.1)))
        }
    }
}
