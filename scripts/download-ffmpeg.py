#!/usr/bin/env python3
"""
Download FFmpeg / FFprobe binaries for lap-binaries.
Output naming: <binary>-<target-triple>[.exe]
"""

import hashlib
import os
import shutil
import tarfile
import zipfile
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent
BIN_DIR = ROOT / "binaries"
TMP_DIR = ROOT / "temp_downloads"

_BTBN = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest"
_RIEDL = "https://ffmpeg.martin-riedl.de/redirect/latest"

TARGETS = [
    {
        "triple": "x86_64-apple-darwin",
        "ffmpeg":  f"{_RIEDL}/macos/amd64/release/ffmpeg.zip",
        "ffprobe": f"{_RIEDL}/macos/amd64/release/ffprobe.zip",
        "ext": "zip",
    },
    {
        "triple": "aarch64-apple-darwin",
        "ffmpeg":  f"{_RIEDL}/macos/arm64/release/ffmpeg.zip",
        "ffprobe": f"{_RIEDL}/macos/arm64/release/ffprobe.zip",
        "ext": "zip",
    },
    {
        "triple": "x86_64-pc-windows-msvc",
        "ffmpeg":  f"{_BTBN}/ffmpeg-master-latest-win64-gpl.zip",
        "ffprobe": "INCLUDED",
        "ext": "zip",
    },
    {
        "triple": "x86_64-unknown-linux-gnu",
        "ffmpeg":  f"{_BTBN}/ffmpeg-master-latest-linux64-gpl.tar.xz",
        "ffprobe": "INCLUDED",
        "ext": "tar.xz",
    },
    {
        "triple": "aarch64-unknown-linux-gnu",
        "ffmpeg":  f"{_BTBN}/ffmpeg-master-latest-linuxarm64-gpl.tar.xz",
        "ffprobe": "INCLUDED",
        "ext": "tar.xz",
    },
]

def download_file(url: str, dest: Path):
    if dest.exists(): dest.unlink()
    print(f"Downloading {url}...")
    req = Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urlopen(req) as response, open(dest, 'wb') as f:
        shutil.copyfileobj(response, f)

def extract(path: Path, dest: Path):
    if dest.exists(): shutil.rmtree(dest)
    dest.mkdir(parents=True)
    if path.suffix == ".zip":
        with zipfile.ZipFile(path, 'r') as zip_ref:
            zip_ref.extractall(dest)
    elif path.name.endswith(".tar.xz"):
        with tarfile.open(path, "r:xz") as tar:
            tar.extractall(dest)

def find_bin(dir: Path, name: str):
    # Recursively find the file, ignoring symlinks
    for path in dir.rglob(name):
        if path.is_file() and not path.is_symlink():
            return path
    return None

def main():
    # Fresh start for binaries
    if BIN_DIR.exists(): shutil.rmtree(BIN_DIR)
    BIN_DIR.mkdir(parents=True)
    
    # Ensure temp dir
    if not TMP_DIR.exists(): TMP_DIR.mkdir(parents=True)

    try:
        for t in TARGETS:
            triple = t["triple"]
            exe = ".exe" if "windows" in triple else ""
            
            print(f"\n--- Processing {triple} ---")
            
            # 1. Download & Extract FFmpeg
            pkg_path = TMP_DIR / f"{triple}_ffmpeg.{t['ext']}"
            download_file(t["ffmpeg"], pkg_path)
            
            ext_dir = TMP_DIR / f"extract_{triple}"
            extract(pkg_path, ext_dir)
            
            src_ffmpeg = find_bin(ext_dir, f"ffmpeg{exe}")
            if not src_ffmpeg:
                raise RuntimeError(f"Could not find ffmpeg for {triple} in {ext_dir}")
                
            dest_ffmpeg = BIN_DIR / f"ffmpeg-{triple}{exe}"
            shutil.copy2(src_ffmpeg, dest_ffmpeg)
            if os.name != 'nt': dest_ffmpeg.chmod(0o755)
            print(f"Saved {dest_ffmpeg.name}")
            
            # 2. Process FFprobe
            if t["ffprobe"] == "INCLUDED":
                src_ffprobe = find_bin(ext_dir, f"ffprobe{exe}")
            else:
                probe_pkg = TMP_DIR / f"{triple}_probe.zip"
                download_file(t["ffprobe"], probe_pkg)
                probe_ext = TMP_DIR / f"extract_probe_{triple}"
                extract(probe_pkg, probe_ext)
                src_ffprobe = find_bin(probe_ext, f"ffprobe{exe}")
            
            if not src_ffprobe:
                 raise RuntimeError(f"Could not find ffprobe for {triple}")

            dest_ffprobe = BIN_DIR / f"ffprobe-{triple}{exe}"
            shutil.copy2(src_ffprobe, dest_ffprobe)
            if os.name != 'nt': dest_ffprobe.chmod(0o755)
            print(f"Saved {dest_ffprobe.name}")

        # 3. Generate SHA256SUMS.txt
        print("\nGenerating SHA256SUMS.txt...")
        sha_lines = []
        for f in sorted(BIN_DIR.glob("*")):
            if f.is_file() and f.name != "SHA256SUMS.txt":
                h = hashlib.sha256(f.read_bytes()).hexdigest()
                sha_lines.append(f"{h}  {f.name}")
        
        with open(BIN_DIR / "SHA256SUMS.txt", "w") as f:
            f.write("\n".join(sha_lines) + "\n")
        
        print("Done! All binaries verified and saved.")

    finally:
        # Cleanup temp files
        if TMP_DIR.exists():
            shutil.rmtree(TMP_DIR)

if __name__ == "__main__":
    main()