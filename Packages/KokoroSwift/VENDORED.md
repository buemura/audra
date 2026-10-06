# Vendored KokoroSwift

Source: https://github.com/mlalma/kokoro-ios at 4d6d1d8ff8cd012014180c9cd4cf0151e7682354 (MIT, see LICENSE).
Copied: Package.swift (test target removed), LICENSE, Resources/, Sources/.

Local patches:
1. `KokoroTTS.generateAudio(voice:phonemes:speed:)` — synthesize from phonemes, skipping G2P.
2. `Tokenizer.tokenize` maps Unicode scalars instead of Characters (fixes dropped nasal vowels).
