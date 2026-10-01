import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Reads the selection aloud, or stops if already speaking. Default: ⌥⇧S.
    static let readSelection = Self("readSelection", default: .init(.s, modifiers: [.option, .shift]))
}
