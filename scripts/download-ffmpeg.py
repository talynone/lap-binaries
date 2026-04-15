#!/usr/bin/env python3

import hashlib
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent
BIN_DIR = ROOT / "binaries"
TMP_DIR = ROOT / "temp"

TARGETS = [
    {
        "triple": "x86_64-apple-darwin",
        "ffmpeg": "https://evermeet.cx/ffmpeg/getrelease/zip",
        "ffprobe": "https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip",
        "ext": "zip",
    },
    {
        "triple": "aarch64-apple-darwin",
        "ffmpeg": "https://ffmpeg.martin-riedl.de/releases/macos/arm64/release/ffmpeg-8.1.zip",
        "ffprobe": "https://ffmpeg.martin-riedl.de/releases/macos/arm64/release/ffprobe-8.1.zip",
        "ext": "zip",
    },
    {
        "triple": "x86_64-pc-windows-msvc",
        "ffmpeg": "https://www.gyan.dev/ffmpeg/builds/ffmpeg-8.1-essentials_build.zip",
        "ffprobe": "INCLUDED",
        "ext": "zip",
    },
    {
        "triple": "x86_64-unknown-linux-gnu",
        "ffmpeg": "https://github.com/BtbN/FFmpeg-Builds/releases/download/n8.1/ffmpeg-n8.1-linux64-gpl.tar.xz",
        "ffprobe": "INCLUDED",
        "ext": "tar.xz",
    },
    {
        "triple": "aarch64-unknown-linux-gnu",
        "ffmpeg": "https://github.com/BtbN/FFmpeg-Builds/releases/download/n8.1/ffmpeg-n8.1-linuxarm64-gpl.tar.xz",
        "ffprobe": "INCLUDED",
        "ext": "tar.xz",
    },
]


def download(url, path):
    if path.exists():
        return
    print("Downloading:", url)
    req = Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urlopen(req) as r, open(path, "wb") as f:
        shutil.copyfileobj(r, f)


def extract(archive, ext, dest):
    if ext == "zip":
        with zipfile.ZipFile(archive) as z:
            z.extractall(dest)
    else:
        with tarfile.open(archive) as t:
            t.extractall(dest)


def find(root, name):
    for p in root.rglob(name):
        return p
    return None


def host_triple():
    sysname = platform.system()
    arch = platform.machine().lower()

    if arch in ("x86_64", "amd64"):
        arch = "x86_64"
    elif arch in ("arm64", "aarch64"):
        arch = "aarch64"

    if sysname == "Darwin":
        return f"{arch}-apple-darwin"
    if sysname == "Linux":
        return f"{arch}-unknown-linux-gnu"
    if sysname == "Windows":
        return f"{arch}-pc-windows-msvc"
    return None


def verify_exec(path, name, triple):
    if host_triple() != triple:
        print("Skip exec:", path.name)
        return

    out = subprocess.run([str(path), "-version"], capture_output=True, text=True)
    line = out.stdout.splitlines()[0]

    if not line.startswith(f"{name} version"):
        raise RuntimeError(f"{path} invalid: {line}")

    print("OK:", line)


def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()


def main():
    BIN_DIR.mkdir(exist_ok=True)
    TMP_DIR.mkdir(exist_ok=True)

    for t in TARGETS:
        triple = t["triple"]
        ext = t["ext"]
        exe = ".exe" if "windows" in triple else ""

        print("\n==", triple)

        a = TMP_DIR / f"{triple}.{ext}"
        d = TMP_DIR / triple

        if d.exists():
            shutil.rmtree(d)

        download(t["ffmpeg"], a)
        extract(a, ext, d)

        f = find(d, f"ffmpeg{exe}")
        if not f:
            raise RuntimeError("ffmpeg not found")

        out = BIN_DIR / f"ffmpeg-{triple}{exe}"
        shutil.copy2(f, out)
        out.chmod(0o755)

        verify_exec(out, "ffmpeg", triple)

        if t["ffprobe"] == "INCLUDED":
            p = find(d, f"ffprobe{exe}")
        else:
            a2 = TMP_DIR / f"{triple}_probe.{ext}"
            d2 = TMP_DIR / f"{triple}_probe"

            download(t["ffprobe"], a2)
            extract(a2, ext, d2)

            p = find(d2, f"ffprobe{exe}")

        if not p:
            raise RuntimeError("ffprobe not found")

        outp = BIN_DIR / f"ffprobe-{triple}{exe}"
        shutil.copy2(p, outp)
        outp.chmod(0o755)

        verify_exec(outp, "ffprobe", triple)

    # SHA256
    sums = []
    for f in sorted(BIN_DIR.iterdir()):
        if f.is_file():
            sums.append(f"{sha256(f)}  {f.name}")

    (BIN_DIR / "SHA256SUMS.txt").write_text("\n".join(sums))
    print("\nDone.")


if __name__ == "__main__":
    main()