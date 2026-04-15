#!/usr/bin/env bash

# FFmpeg & FFprobe download script for lap-binaries
# Downloads platform-specific binaries and renames them to match
# Tauri sidecar naming: <binary>-<target-triple>[.exe]

set -Eeuo pipefail

BIN_DIR="./binaries"
TEMP_DIR="./temp_downloads"

# Format:
#   "target_triple|ffmpeg_url|ffprobe_url|archive_ext"
# If ffprobe_url is "INCLUDED", ffprobe is expected in the same archive as ffmpeg.
TARGETS=(
  "x86_64-apple-darwin|https://evermeet.cx/ffmpeg/getrelease/zip|https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip|zip"
  "aarch64-apple-darwin|https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/ffmpeg.zip|https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/ffprobe.zip|zip"
  "x86_64-pc-windows-msvc|https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip|INCLUDED|zip"
  "x86_64-unknown-linux-gnu|https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz|INCLUDED|tar.xz"
  "aarch64-unknown-linux-gnu|https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linuxarm64-gpl.tar.xz|INCLUDED|tar.xz"
)

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$TEMP_DIR"

download_file() {
  local url="$1"
  local out="$2"

  if [[ -s "$out" ]]; then
    echo "Using cached file: $out"
    return 0
  fi

  echo "Downloading: $url"
  curl -fL \
    -A "Mozilla/5.0" \
    --retry 3 \
    --retry-delay 3 \
    --connect-timeout 20 \
    "$url" \
    -o "$out"
}

extract_archive() {
  local archive="$1"
  local ext="$2"
  local dest="$3"

  mkdir -p "$dest"

  case "$ext" in
    zip)
      unzip -qo "$archive" -d "$dest"
      ;;
    tar.xz)
      tar -xJf "$archive" -C "$dest"
      ;;
    *)
      echo "Error: unsupported archive type: $ext"
      return 1
      ;;
  esac
}

find_binary() {
  local root="$1"
  local name="$2"

  find "$root" -type f -name "$name" | head -n 1
}

verify_binary() {
  local path="$1"
  local expected_name="$2"

  if [[ ! -f "$path" ]]; then
    echo "Error: binary not found: $path"
    return 1
  fi

  local first_line
  first_line="$("$path" -version 2>&1 | head -n 1 || true)"

  if [[ "$first_line" != "$expected_name version "* ]]; then
    echo "Error: invalid $expected_name binary: $path"
    echo "Expected first line to start with: '$expected_name version '"
    echo "Actual: $first_line"
    return 1
  fi
}

save_binary() {
  local src="$1"
  local dest="$2"

  cp "$src" "$dest"
  chmod +x "$dest"
  echo "Saved: $dest"
}

process_target() {
  local target="$1"
  IFS='|' read -r triple ffmpeg_url ffprobe_url ext <<< "$target"

  echo
  echo "=== Processing $triple ==="

  local exe_ext=""
  if [[ "$triple" == *"windows"* ]]; then
    exe_ext=".exe"
  fi

  local ffmpeg_archive="$TEMP_DIR/ffmpeg_${triple}.${ext}"
  local ffprobe_archive="$TEMP_DIR/ffprobe_${triple}.${ext}"
  local ffmpeg_extract_dir="$TEMP_DIR/extract_ffmpeg_${triple}"
  local ffprobe_extract_dir="$TEMP_DIR/extract_ffprobe_${triple}"

  rm -rf "$ffmpeg_extract_dir" "$ffprobe_extract_dir"

  # Download and extract ffmpeg
  download_file "$ffmpeg_url" "$ffmpeg_archive"
  extract_archive "$ffmpeg_archive" "$ext" "$ffmpeg_extract_dir"

  local src_ffmpeg
  src_ffmpeg="$(find_binary "$ffmpeg_extract_dir" "ffmpeg${exe_ext}")"

  if [[ -z "${src_ffmpeg:-}" ]]; then
    echo "Error: ffmpeg binary not found for $triple"
    return 1
  fi

  local out_ffmpeg="$BIN_DIR/ffmpeg-${triple}${exe_ext}"
  save_binary "$src_ffmpeg" "$out_ffmpeg"
  verify_binary "$out_ffmpeg" "ffmpeg"

  # Download/extract ffprobe
  local out_ffprobe="$BIN_DIR/ffprobe-${triple}${exe_ext}"

  if [[ "$ffprobe_url" == "INCLUDED" ]]; then
    local src_ffprobe
    src_ffprobe="$(find_binary "$ffmpeg_extract_dir" "ffprobe${exe_ext}")"

    if [[ -z "${src_ffprobe:-}" ]]; then
      echo "Error: ffprobe binary not found in included archive for $triple"
      return 1
    fi

    save_binary "$src_ffprobe" "$out_ffprobe"
    verify_binary "$out_ffprobe" "ffprobe"
  else
    download_file "$ffprobe_url" "$ffprobe_archive"
    extract_archive "$ffprobe_archive" "$ext" "$ffprobe_extract_dir"

    local src_ffprobe
    src_ffprobe="$(find_binary "$ffprobe_extract_dir" "ffprobe${exe_ext}")"

    if [[ -z "${src_ffprobe:-}" ]]; then
      echo "Error: ffprobe binary not found for $triple"
      return 1
    fi

    save_binary "$src_ffprobe" "$out_ffprobe"
    verify_binary "$out_ffprobe" "ffprobe"
  fi

  echo "Verified binaries for $triple"
}

main() {
  for target in "${TARGETS[@]}"; do
    process_target "$target"
  done

  echo
  echo "Done! Binaries are in $BIN_DIR"
  echo
  ls -lh "$BIN_DIR"
}

main "$@"