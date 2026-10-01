import AppKit

/// `PasteboardAccessing` backed by a real `NSPasteboard` (the general clipboard by default).
@MainActor
public final class SystemPasteboard: PasteboardAccessing {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public var changeCount: Int { pasteboard.changeCount }

    public func snapshot() -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(
                item.types.compactMap { type in item.data(forType: type).map { (type.rawValue, $0) } },
                uniquingKeysWith: { first, _ in first }
            )
        }
        return PasteboardSnapshot(items: items)
    }

    public func restore(_ snapshot: PasteboardSnapshot) {
        pasteboard.clearContents()
        let items = snapshot.items.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entries {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    public func readString() -> String? {
        pasteboard.string(forType: .string)
    }
}
