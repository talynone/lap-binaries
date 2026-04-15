#!/bin/bash

# FFmpeg & FFprobe download script for lap-binaries
# This script downloads FFmpeg and FFprobe for multiple platforms and renames them 
# to follow the Tauri sidecar naming convention: <binary>-<target-triple>

set -e

BIN_DIR="./binaries"
TEMP_DIR="./temp_downloads"

# Define targets
# Format: "triple|ffmpeg_url|ffprobe_url|archive_ext|extract_subdir"
# If ffprobe_url is "INCLUDED", it means ffprobe is in the same archive as ffmpeg.
TARGETS=(
    "x86_64-apple-darwin|https://evermeet.cx/ffmpeg/getrelease/zip|https://evermeet.cx/ffprobe/getrelease/zip|zip|."
    "aarch64-apple-darwin|https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/ffmpeg.zip|https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/ffprobe.zip|zip|."
    "x86_64-pc-windows-msvc|https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip|INCLUDED|zip|ffmpeg-*-essentials_build/bin"
    "x86_64-unknown-linux-gnu|https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz|INCLUDED|tar.xz|ffmpeg-master-latest-linux64-gpl/bin"
    "aarch64-unknown-linux-gnu|https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linuxarm64-gpl.tar.xz|INCLUDED|tar.xz|ffmpeg-master-latest-linuxarm64-gpl/bin"
)

mkdir -p "$BIN_DIR"
mkdir -p "$TEMP_DIR"

download_file() {
    local url=$1
    local out=$2
    if [[ -s "$out" ]]; then
        echo "File $out already exists, skipping download."
        return 0
    fi
    echo "Downloading $url..."
    curl -L -A "Mozilla/5.0" --retry 3 --retry-delay 5 "$url" -o "$out"
}

process_target() {
    IFS='|' read -r triple ffmpeg_url ffprobe_url ext subpath <<< "$1"
    
    echo "--- Processing $triple ---"
    
    local ffmpeg_archive="$TEMP_DIR/ffmpeg_$triple.$ext"
    local ffprobe_archive="$TEMP_DIR/ffprobe_$triple.$ext"
    local extract_dir="$TEMP_DIR/ext_$triple"
    mkdir -p "$extract_dir"

    # Download ffmpeg
    download_file "$ffmpeg_url" "$ffmpeg_archive"

    # Extract ffmpeg
    if [[ "$ext" == "zip" ]]; then
        unzip -qo "$ffmpeg_archive" -d "$extract_dir"
    else
        tar -xf "$ffmpeg_archive" -C "$extract_dir"
    fi

    # Handle ffmpeg binary
    local exe_ext=""
    if [[ "$triple" == *"windows"* ]]; then
        exe_ext=".exe"
    fi

    local src_ffmpeg=$(find "$extract_dir" -name "ffmpeg$exe_ext" -type f | head -n 1)

    if [[ -f "$src_ffmpeg" ]]; then
        mv "$src_ffmpeg" "$BIN_DIR/ffmpeg-$triple$exe_ext"
        chmod +x "$BIN_DIR/ffmpeg-$triple$exe_ext"
        echo "Saved ffmpeg-$triple$exe_ext"
    else
        echo "Error: ffmpeg binary not found in $ffmpeg_archive"
        return 1
    fi

    # Handle ffprobe
    if [[ "$ffprobe_url" == "INCLUDED" ]]; then
        local src_ffprobe=$(find "$extract_dir" -name "ffprobe$exe_ext" -type f | head -n 1)
        
        if [[ -f "$src_ffprobe" ]]; then
            mv "$src_ffprobe" "$BIN_DIR/ffprobe-$triple$exe_ext"
            chmod +x "$BIN_DIR/ffprobe-$triple$exe_ext"
            echo "Saved ffprobe-$triple$exe_ext"
        fi
    else
        # Download and extract separate ffprobe
        download_file "$ffprobe_url" "$ffprobe_archive"
        local ffprobe_ext_dir="$TEMP_DIR/ext_ffprobe_$triple"
        mkdir -p "$ffprobe_ext_dir"
        
        if [[ "$ext" == "zip" ]]; then
            unzip -qo "$ffprobe_archive" -d "$ffprobe_ext_dir"
        else
            tar -xf "$ffprobe_archive" -C "$ffprobe_ext_dir"
        fi

        local src_ffprobe=$(find "$ffprobe_ext_dir" -name "ffprobe$exe_ext" -type f | head -n 1)
        if [[ ! -f "$src_ffprobe" ]]; then
            # Evermeet sometimes names the binary 'ffmpeg' even in ffprobe.zip
            src_ffprobe=$(find "$ffprobe_ext_dir" -name "ffmpeg$exe_ext" -type f | head -n 1)
        fi

        if [[ -f "$src_ffprobe" ]]; then
            mv "$src_ffprobe" "$BIN_DIR/ffprobe-$triple$exe_ext"
            chmod +x "$BIN_DIR/ffprobe-$triple$exe_ext"
            echo "Saved ffprobe-$triple$exe_ext"
        else
            echo "Error: ffprobe binary not found in $ffprobe_archive"
        fi
    fi
}

# Main loop
for target in "${TARGETS[@]}"; do
    process_target "$target"
done

# Cleanup
rm -rf "$TEMP_DIR"

echo "Done! Binaries are in $BIN_DIR"