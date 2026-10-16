import ESpeakNG
import Foundation
import AudraCore

/// eSpeak NG phonemes post-processed for Kokoro the way misaki's `EspeakG2P` does, punctuation kept.
/// eSpeak is a process-wide C library, so every call goes through one lock.
public final class ESpeakPhonemizer: Phonemizer, @unchecked Sendable {
    public enum Failure: Error, Equatable {
        case dataNotFound
        case initializationFailed
        case languageNotFound(String)
    }

    private static let lock = NSLock()
    /// Guarded by `lock`.
    private static var initialized = false

    private let language: String

    /// - Parameter language: eSpeak language tag, e.g. "es", "pt-br", "fr-fr", "it", "hi", "ja", "cmn".
    public init(language: String) throws {
        self.language = language
        try Self.lock.withLock {
            try Self.initializeIfNeeded()
            guard Self.select(language: language) else { throw Failure.languageNotFound(language) }
        }
    }

    /// misaki's `E2M` for `EspeakG2P` (Kokoro v1.0).
    private static let replacements: [(String, String)] = [
        ("a^ɪ", "I"), ("a^ʊ", "W"), ("d^z", "ʣ"), ("d^ʒ", "ʤ"), ("e^ɪ", "A"), ("o^ʊ", "O"), ("ə^ʊ", "Q"),
        ("s^s", "S"), ("t^s", "ʦ"), ("t^ʃ", "ʧ"), ("ɔ^ɪ", "Y"),
    ]

    /// phonemizer's default punctuation marks; they are kept in the output like misaki does.
    private static let marks = try! NSRegularExpression(pattern: "\\s*[;:,.!?¡¿—…\"«»“”(){}\\[\\]]+\\s*")

    public func phonemize(_ text: String) throws -> String {
        // misaki maps «» to curly quotes and parentheses to «», then back at the end.
        let prepared = text
            .replacingOccurrences(of: "«", with: "“").replacingOccurrences(of: "»", with: "”")
            .replacingOccurrences(of: "(", with: "«").replacingOccurrences(of: ")", with: "»")
        let ns = prepared as NSString
        var output = ""
        var cursor = 0
        try Self.lock.withLock {
            guard Self.select(language: language) else { throw Failure.languageNotFound(language) }
            for match in Self.marks.matches(in: prepared, range: NSRange(location: 0, length: ns.length)) {
                output += Self.rawPhonemes(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
                let mark = ns.substring(with: match.range)
                if mark.first?.isWhitespace == true, !output.isEmpty, output.last != " " { output += " " }
                output += mark.trimmingCharacters(in: .whitespaces)
                if mark.last?.isWhitespace == true { output += " " }
                cursor = match.range.location + match.range.length
            }
            output += Self.rawPhonemes(ns.substring(from: cursor))
        }
        var result = output.trimmingCharacters(in: .whitespaces)
        for (old, new) in Self.replacements {
            result = result.replacingOccurrences(of: old, with: new)
        }
        return result
            .replacingOccurrences(of: "^", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "«", with: "(").replacingOccurrences(of: "»", with: ")")
    }

    // MARK: - eSpeak (call with `lock` held)

    /// `espeak-ng-data` ships inside the vendored ESpeakNG.framework.
    private static func initializeIfNeeded() throws {
        guard !initialized else { return }
        guard let dataPath = Bundle(identifier: "com.kokoro.espeakng")?
            .url(forResource: "espeak-ng-data", withExtension: "bundle")?.path
        else { throw Failure.dataNotFound }
        guard espeak_Initialize(AUDIO_OUTPUT_RETRIEVAL, 0, dataPath, 0) > 0 else { throw Failure.initializationFailed }
        initialized = true
    }

    /// Selects the voice for a language tag, as phonemizer does.
    private static func select(language: String) -> Bool {
        language.withCString { tag in
            var properties = espeak_VOICE()
            properties.languages = tag
            return espeak_SetVoiceByProperties(&properties) == EE_OK
        }
    }

    /// eSpeak IPA for text without punctuation, ties written as "^", clauses joined by spaces.
    private static func rawPhonemes(_ text: String) -> String {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return "" }
        // espeakPHONEMES_IPA | espeakPHONEMES_TIE, with U+0361 as the tie character.
        let mode = Int32(0x02 | 0x80 | (0x0361 << 8))
        var clauses: [String] = []
        text.withCString { cString in
            var pointer: UnsafeRawPointer? = UnsafeRawPointer(cString)
            while pointer != nil {
                guard let phonemes = espeak_TextToPhonemes(&pointer, espeakCHARS_UTF8, mode) else { break }
                clauses.append(String(cString: phonemes))
            }
        }
        return clauses.joined(separator: " ")
            // Language-switch flags such as "(en)", removed like phonemizer's "remove-flags".
            .replacingOccurrences(of: "\\(.+?\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\u{0361}", with: "^")
            .trimmingCharacters(in: .whitespaces)
    }
}
