# lap-binaries

Prebuilt sidecar binaries for Lap (ffmpeg, ffprobe, etc.).

This repository hosts versioned, cross-platform binaries used during CI and release packaging.
It ensures reproducible builds without requiring users to install external dependencies.

---

## 📦 Purpose

This repository exists to:

- Keep the main Lap repository clean (no large binaries in git history)
- Provide versioned and reproducible builds
- Simplify CI and cross-platform packaging
- Avoid requiring users to manually install dependencies like ffmpeg

---

## 📁 Contents

Each release contains prebuilt binaries for multiple platforms:

### macOS
- `ffmpeg-aarch64-apple-darwin`
- `ffprobe-aarch64-apple-darwin`
- `ffmpeg-x86_64-apple-darwin`
- `ffprobe-x86_64-apple-darwin`

### Windows
- `ffmpeg-x86_64-pc-windows-msvc.exe`
- `ffprobe-x86_64-pc-windows-msvc.exe`

### Linux
- `ffmpeg-x86_64-unknown-linux-gnu`
- `ffprobe-x86_64-unknown-linux-gnu`

> File names follow the Rust target triple convention.

---

## 🚀 Usage

### 1. Download in CI

Example (macOS arm64):

```bash
curl -L \
https://github.com/<owner>/lap-binaries/releases/download/<version>/ffmpeg-aarch64-apple-darwin \
-o src-tauri/binaries/ffmpeg
