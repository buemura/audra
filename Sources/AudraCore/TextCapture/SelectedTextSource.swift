import Foundation

/// Something that can fetch the text the user currently has selected in the frontmost app.
@MainActor
public protocol SelectedTextSource {
    func selectedText() async -> String?
}

/// Tries each source in order and returns the first non-blank result.
@MainActor
public struct FirstAvailableTextSource: SelectedTextSource {
    private let sources: [any SelectedTextSource]

    public init(_ sources: [any SelectedTextSource]) {
        self.sources = sources
    }

    public func selectedText() async -> String? {
        for source in sources {
            if let text = await source.selectedText(),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }
        return nil
    }
}
