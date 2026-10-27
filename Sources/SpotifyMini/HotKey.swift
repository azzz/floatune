import Carbon.HIToolbox

/// Global hotkey registered through Carbon. Needs no Accessibility permission.
@MainActor
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            // Carbon delivers application events on the main thread.
            MainActor.assumeIsolated { hotKey.action() }
            return noErr
        }, 1, &eventType, userData, &handlerRef)
    }

    /// Registers `combo` in place of the current one. Returns false if the system refused it.
    @discardableResult
    func register(_ combo: KeyCombo) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x534D_4E49), id: 1) // 'SMNI'
        let status = RegisterEventHotKey(
            combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        return status == noErr
    }

    func unregister() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }
}
