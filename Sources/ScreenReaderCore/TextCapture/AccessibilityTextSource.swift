import ApplicationServices

/// Reads the selection of the focused UI element via the Accessibility API.
/// Works in most native apps; returns nil in apps that don't expose it (many browsers, Electron).
@MainActor
public struct AccessibilityTextSource: SelectedTextSource {
    public init() {}

    public func selectedText() async -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 0.5)

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }

        var selected: CFTypeRef?
        let element = focused as! AXUIElement
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success else {
            return nil
        }
        return selected as? String
    }
}
