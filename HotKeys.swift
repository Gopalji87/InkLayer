import AppKit
import Carbon.HIToolbox

/// Global hotkeys via Carbon's RegisterEventHotKey (no Accessibility permission required).
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef?] = []
    private var nextID: UInt32 = 1
    private var installed = false

    func register(keyCode: Int, modifiers: UInt32, handler: @escaping () -> Void) {
        installIfNeeded()
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x494E4B4C), id: nextID) // 'INKL'
        RegisterEventHotKey(UInt32(keyCode), modifiers, id, GetApplicationEventTarget(), 0, &ref)
        handlers[nextID] = handler
        refs.append(ref)
        nextID += 1
    }

    private func installIfNeeded() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            HotKeyCenter.shared.handlers[hk.id]?()
            return noErr
        }, 1, &spec, nil, nil)
    }
}
