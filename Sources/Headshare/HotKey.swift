import Carbon.HIToolbox
import Foundation

enum HotKeyOption: String, CaseIterable, Identifiable {
    case none
    case ctrlOptCmdH
    case optCmdS
    case ctrlOptS
    case optShiftH

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return String(localized: "None")
        case .ctrlOptCmdH: return "⌃⌥⌘H"
        case .optCmdS: return "⌥⌘S"
        case .ctrlOptS: return "⌃⌥S"
        case .optShiftH: return "⌥⇧H"
        }
    }

    fileprivate var combo: (keyCode: UInt32, modifiers: UInt32)? {
        switch self {
        case .none: return nil
        case .ctrlOptCmdH: return (UInt32(kVK_ANSI_H), UInt32(controlKey | optionKey | cmdKey))
        case .optCmdS: return (UInt32(kVK_ANSI_S), UInt32(optionKey | cmdKey))
        case .ctrlOptS: return (UInt32(kVK_ANSI_S), UInt32(controlKey | optionKey))
        case .optShiftH: return (UInt32(kVK_ANSI_H), UInt32(optionKey | shiftKey))
        }
    }
}

/// Global shortcut via Carbon's RegisterEventHotKey: works in any app, needs no Accessibility permission.
final class HotKeyCenter {
    static let shared = HotKeyCenter()
    var action: (() -> Void)?

    private var ref: EventHotKeyRef?
    private var handlerInstalled = false

    func register(_ option: HotKeyOption) {
        unregister()
        guard let combo = option.combo else { return }
        installHandler()
        let id = EventHotKeyID(signature: OSType(0x4853_4853), id: 1) // 'HSHS'
        RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKeyCenter.shared.action?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
