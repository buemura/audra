import CoreGraphics

/// Posts ⌘C to the frontmost app. Requires the Accessibility permission.
@MainActor
public struct CopyKeySender: CopyCommandSending {
    private static let cKeyCode: CGKeyCode = 0x08 // kVK_ANSI_C

    public init() {}

    public func sendCopyCommand() {
        // A private event source keeps the user's still-held hotkey modifiers (⌥⇧) out of the event.
        let source = CGEventSource(stateID: .privateState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Self.cKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Self.cKeyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
