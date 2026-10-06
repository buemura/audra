import Foundation

/// The model files the app downloads, built by scripts/prepare-kokoro-assets.py and published as
/// release `kokoro-model-v1` of the public repo buemura/screen-reader-models.
public enum KokoroModelAssets {
    public static let modelFileName = "kokoro-v1_0-fp16.safetensors"
    public static let voicesFileName = "voices.npz"

    private static let releaseURL = URL(string: "https://github.com/buemura/screen-reader-models/releases/download/kokoro-model-v1/")!

    public static let all: [KokoroModelStore.Asset] = [
        KokoroModelStore.Asset(
            fileName: modelFileName,
            url: releaseURL.appendingPathComponent(modelFileName),
            sha256: "67d4b879ce0f0bc6d30169cca8dc424f192cbed5be811078d8ef7c4a34a34b1f",
            byteCount: 163_587_908
        ),
        KokoroModelStore.Asset(
            fileName: voicesFileName,
            url: releaseURL.appendingPathComponent(voicesFileName),
            sha256: "9555acb689b3856bb58215b42e0ce65bcc228e1b6286df9c7d92d205e795d3dc",
            byteCount: 26_645_914
        ),
    ]
}