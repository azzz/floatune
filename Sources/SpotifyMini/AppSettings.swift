import AppKit
import Carbon.HIToolbox
import Observation
import ServiceManagement

/// User settings persisted in UserDefaults. Every change calls `onChange`.
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let dimDelay = "dimDelay"
        static let dimAlpha = "dimAlpha"
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
    }

    /// Seconds without interaction before the panel dims.
    var dimDelay: TimeInterval {
        didSet { save(dimDelay, Key.dimDelay) }
    }

    /// Panel opacity in the dimmed state, 0–1.
    var dimAlpha: Double {
        didSet { save(dimAlpha, Key.dimAlpha) }
    }

    /// Global show/hide hotkey.
    var hotKey: KeyCombo {
        didSet {
            defaults.set(Int(hotKey.keyCode), forKey: Key.hotKeyCode)
            save(Int(hotKey.modifiers), Key.hotKeyModifiers)
        }
    }

    /// Set by the owner when the hotkey could not be registered.
    var hotKeyError: String?

    private(set) var launchAtLogin: Bool

    func setLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            Key.dimDelay: 4.0,
            Key.dimAlpha: 0.35,
            Key.hotKeyCode: Int(KeyCombo.default.keyCode),
            Key.hotKeyModifiers: Int(KeyCombo.default.modifiers),
        ])
        dimDelay = defaults.double(forKey: Key.dimDelay)
        dimAlpha = defaults.double(forKey: Key.dimAlpha)
        hotKey = KeyCombo(
            keyCode: UInt32(defaults.integer(forKey: Key.hotKeyCode)),
            modifiers: UInt32(defaults.integer(forKey: Key.hotKeyModifiers))
        )
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
        onChange?()
    }
}

/// Key code plus Carbon modifier mask, the form `RegisterEventHotKey` takes.
struct KeyCombo: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = KeyCombo(
        keyCode: UInt32(kVK_ANSI_S),
        modifiers: UInt32(controlKey | optionKey | cmdKey)
    )

    /// Builds a combo from a key-down event. Returns nil when the event cannot serve as a global
    /// hotkey: no ⌘/⌃/⌥ modifier and not a function key.
    init?(event: NSEvent) {
        let flags = event.modifierFlags
        var mask = 0
        if flags.contains(.command) { mask |= cmdKey }
        if flags.contains(.option) { mask |= optionKey }
        if flags.contains(.control) { mask |= controlKey }
        if flags.contains(.shift) { mask |= shiftKey }

        let keyCode = UInt32(event.keyCode)
        let hasMainModifier = mask & (cmdKey | optionKey | controlKey) != 0
        guard hasMainModifier || Self.functionKeys.contains(Int(keyCode)) else { return nil }
        self.init(keyCode: keyCode, modifiers: UInt32(mask))
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Text like "⌃⌥⌘S", with the key named as on the ASCII keyboard layout.
    var displayString: String {
        let mask = Int(modifiers)
        var text = ""
        if mask & controlKey != 0 { text += "⌃" }
        if mask & optionKey != 0 { text += "⌥" }
        if mask & shiftKey != 0 { text += "⇧" }
        if mask & cmdKey != 0 { text += "⌘" }
        return text + Self.keyName(Int(keyCode))
    }

    private static let functionKeys: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ]

    private static let specialKeyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15",
        kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    // Uses the ASCII-capable layout so a combo recorded under a Cyrillic layout reads "S", not "Ы".
    private static func keyName(_ keyCode: Int) -> String {
        if let name = specialKeyNames[keyCode] { return name }
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return "#\(keyCode)" }

        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = layoutData.withUnsafeBytes { buffer in
            UCKeyTranslate(
                buffer.baseAddress!.assumingMemoryBound(to: UCKeyboardLayout.self),
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }
        guard status == noErr, length > 0 else { return "#\(keyCode)" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}
