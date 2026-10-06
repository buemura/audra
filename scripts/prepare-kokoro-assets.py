#!/usr/bin/env python3
"""Builds the Kokoro model files the app downloads (published as a GitHub Release asset).

Usage:
    uv run --python 3.12 --with numpy --with safetensors --with torch --with huggingface_hub \
        scripts/prepare-kokoro-assets.py build/kokoro-assets

Outputs, byte-for-byte reproducible:
    kokoro-v1_0-fp16.safetensors  KokoroSwift-format weights, converted to float16
    voices.npz                    style vectors for the voices in KokoroVoiceCatalog
and prints each file's size and SHA-256 for KokoroModelAssets.swift.
"""
import hashlib
import io
import sys
import urllib.request
import zipfile
from pathlib import Path

import numpy as np
import torch
from huggingface_hub import hf_hub_download
from safetensors.numpy import load, save

# KokoroSwift-format float32 weights (Apache-2.0, converted from hexgrad/Kokoro-82M by the KokoroSwift author).
MODEL_URL = ("https://media.githubusercontent.com/media/mlalma/KokoroTestApp/"
             "9dcd3b06468a3c1ecee6d09a33ca687c8e708566/Resources/kokoro-v1_0.safetensors")
MODEL_SHA256 = "4e9ecdf03b8b6cf906070390237feda473dc13327cb8d56a43deaa374c02acd8"
VOICES_REPO = "hexgrad/Kokoro-82M"
VOICES_REVISION = "f3ff3571791e39611d31c381e3a41a3af07b4987"

# Must match KokoroVoiceCatalog.swift.
VOICES = """
af_heart af_bella af_nicole af_aoede af_kore af_sarah af_nova af_sky af_alloy af_jessica af_river
am_michael am_fenrir am_puck am_echo am_eric am_liam am_onyx am_adam
bf_emma bf_isabella bf_alice bf_lily bm_george bm_fable bm_lewis bm_daniel
pf_dora pm_alex ef_dora em_alex ff_siwis if_sara im_nicola
hf_alpha hf_beta hm_omega hm_psi
jf_alpha jf_gongitsune jf_nezumi jf_tebukuro jm_kumo
zf_xiaobei zf_xiaoni zf_xiaoxiao zf_xiaoyi zm_yunjian zm_yunxi zm_yunxia zm_yunyang
""".split()


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def build_model(out: Path) -> Path:
    data = urllib.request.urlopen(MODEL_URL).read()
    if sha256(data) != MODEL_SHA256:
        sys.exit("Downloaded model checksum mismatch")
    weights = load(data)
    fp16 = {name: weights[name].astype(np.float16) for name in sorted(weights)}
    path = out / "kokoro-v1_0-fp16.safetensors"
    path.write_bytes(save(fp16))
    return path


def build_voices(out: Path) -> Path:
    path = out / "voices.npz"
    # A zip with fixed timestamps so the file (and its checksum) is reproducible.
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as archive:
        for voice in VOICES:
            pt = hf_hub_download(VOICES_REPO, f"voices/{voice}.pt", revision=VOICES_REVISION)
            array = torch.load(pt, weights_only=True).numpy().astype(np.float32)
            buffer = io.BytesIO()
            np.save(buffer, array)
            archive.writestr(zipfile.ZipInfo(f"{voice}.npy", date_time=(1980, 1, 1, 0, 0, 0)), buffer.getvalue())
    return path


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for path in (build_model(out), build_voices(out)):
        data = path.read_bytes()
        print(f"{path.name}\tsize={len(data)}\tsha256={sha256(data)}")


if __name__ == "__main__":
    main()
