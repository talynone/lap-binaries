#!/usr/bin/env python3
import hashlib
import os
import shutil
import zipfile
import tarfile
from pathlib import Path
from urllib.request import Request, urlopen

# --- Stable & Reliable FFmpeg 8.1 Sources ---
# Based on industry standards used by projects like LosslessCut and yt-dlp.
_RIEDL = "https://ffmpeg.martin-riedl.de/redirect/latest"
_GYAN = "https://www.gyan.dev/ffmpeg/builds"
_BTBN = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest"

TARGETS = [
    {
        "triple": "x86_64-apple-darwin",
        "ffmpeg": "https://evermeet.cx/ffmpeg/getrelease/zip",
        "ffprobe": "https://evermeet.cx/ffprobe/getrelease/zip",
        "ext": "zip"
    },
    {
        "triple": "aarch64-apple-darwin",
        "ffmpeg": f"{_RIEDL}/macos/arm64/release/ffmpeg.zip",
        "ffprobe": f"{_RIEDL}/macos/arm64/release/ffprobe.zip",
        "ext": "zip"
    },
    {
        "triple": "x86_64-pc-windows-msvc",
        "ffmpeg": f"{_GYAN}/ffmpeg-release-essentials.zip",
        "ffprobe": "INCLUDED",
        "ext": "zip"
    },
    {
        "triple": "x86_64-unknown-linux-gnu",
        "ffmpeg": f"{_BTBN}/ffmpeg-master-latest-linux64-gpl.tar.xz",
        "ffprobe": "INCLUDED",
        "ext": "tar.xz"
    },
    {
        "triple": "aarch64-unknown-linux-gnu",
        "ffmpeg": f"{_BTBN}/ffmpeg-master-latest-linuxarm64-gpl.tar.xz",
        "ffprobe": "INCLUDED",
        "ext": "tar.xz"
    }
]

ROOT = Path(__file__).resolve().parent.parent
BIN_DIR = ROOT / "binaries"
TMP_ROOT = ROOT / "temp_downloads"

def safe_extract(archive: Path, dest: Path):
    if dest.exists(): shutil.rmtree(dest, ignore_errors=True)
    dest.mkdir(parents=True, exist_ok=True)
    if archive.suffix == ".zip":
        with zipfile.ZipFile(archive, 'r') as zf:
            zf.extractall(dest)
    elif ".tar" in archive.name:
        with tarfile.open(archive, "r:*") as tf:
            tf.extractall(dest)

def find_binary(dir_path: Path, name: str):
    # Crucial: Strictly search only within the provided triple-specific directory
    for p in dir_path.rglob(name):
        if p.is_file() and not p.is_symlink():
            return p
    return None

def download(url: str, dest: Path):
    print(f"  Downloading: {url}")
    req = Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urlopen(req, timeout=60) as resp, open(dest, "wb") as f:
        shutil.copyfileobj(resp, f)

def main():
    # Fresh start: Ensure clean directories for each run
    if BIN_DIR.exists(): shutil.rmtree(BIN_DIR)
    BIN_DIR.mkdir()
    if TMP_ROOT.exists(): shutil.rmtree(TMP_ROOT)
    TMP_ROOT.mkdir()

    for t in TARGETS:
        triple = t["triple"]
        print(f"\n>>>> Starting: {triple}")
        exe = ".exe" if "windows" in triple else ""
        
        # 1. Download to unique path
        pkg = TMP_ROOT / f"{triple}_pkg.{t['ext']}"
        download(t["ffmpeg"], pkg)
        
        # 2. Extract to unique triple-isolated directory
        ext_dir = TMP_ROOT / f"ext_{triple}"
        safe_extract(pkg, ext_dir)
        
        # 3. Find and copy ffmpeg
        f_bin = find_binary(ext_dir, f"ffmpeg{exe}")
        if not f_bin:
            raise RuntimeError(f"Failed to find ffmpeg for {triple}")
        
        target_f = BIN_DIR / f"ffmpeg-{triple}{exe}"
        shutil.copy2(f_bin, target_f)
        if os.name != 'nt': target_f.chmod(0o755)
        print(f"  Saved: {target_f.name}")

        # 4. Handle ffprobe
        if t["ffprobe"] == "INCLUDED":
            p_bin = find_binary(ext_dir, f"ffprobe{exe}")
        else:
            p_pkg = TMP_ROOT / f"{triple}_probe_pkg.zip"
            download(t["ffprobe"], p_pkg)
            p_ext = TMP_ROOT / f"ext_probe_{triple}"
            safe_extract(p_pkg, p_ext)
            p_bin = find_binary(p_ext, f"ffprobe{exe}")
            if not p_bin:
                p_bin = find_binary(p_ext, f"ffmpeg{exe}")
            
        if not p_bin:
            raise RuntimeError(f"Failed to find ffprobe for {triple}")
            
        target_p = BIN_DIR / f"ffprobe-{triple}{exe}"
        shutil.copy2(p_bin, target_p)
        if os.name != 'nt': target_p.chmod(0o755)
        print(f"  Saved: {target_p.name}")

    # Generate Checksums for verification
    print("\nFinalizing: Generating SHA256SUMS.txt")
    lines = []
    for f in sorted(BIN_DIR.glob("*")):
        if f.is_file() and f.name != "SHA256SUMS.txt":
            h = hashlib.sha256(f.read_bytes()).hexdigest()
            lines.append(f"{h}  {f.name}")
    (BIN_DIR / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n")
    
    print("\nAll platforms processed successfully.")
    print(f"Results located in: {BIN_DIR}")

if __name__ == "__main__":
    main()