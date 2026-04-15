# FFmpeg & FFprobe download script for lap-binaries
# This script downloads FFmpeg and FFprobe for multiple platforms and renames them 
# to follow the Tauri sidecar naming convention: <binary>-<target-triple>

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BinDir = New-Item -ItemType Directory -Force -Path (Join-Path $ScriptDir "../binaries")
$TempDir = New-Item -ItemType Directory -Force -Path (Join-Path $ScriptDir "../temp_downloads")

$Targets = @(
    "x86_64-apple-darwin|https://evermeet.cx/ffmpeg/getrelease/zip|https://evermeet.cx/ffprobe/getrelease/zip|zip|.",
    "aarch64-apple-darwin|https://evermeet.cx/ffmpeg/getrelease/zip|https://evermeet.cx/ffprobe/getrelease/zip|zip|.",
    "x86_64-pc-windows-msvc|https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip|INCLUDED|zip|ffmpeg-*-essentials_build/bin",
    "x86_64-unknown-linux-gnu|https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz|INCLUDED|tar.xz|ffmpeg-master-latest-linux64-gpl/bin",
    "aarch64-unknown-linux-gnu|https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linuxarm64-gpl.tar.xz|INCLUDED|tar.xz|ffmpeg-master-latest-linuxarm64-gpl/bin"
)

function Download-File {
    param([string]$Url, [string]$Out)
    Write-Host "Downloading $Url..."
    Invoke-WebRequest -Uri $Url -OutFile $Out -MaximumRetryCount 5 -RetryIntervalSec 5
}

function Extract-File {
    param([string]$File, [string]$Dir, [string]$Ext)
    if ($Ext -eq "zip") {
        Expand-Archive -Path $File -DestinationPath $Dir -Force
    } else {
        # Assuming tar is available (standard in modern Windows)
        tar -xf $File -C $Dir
    }
}

foreach ($Target in $Targets) {
    $Parts = $Target.Split("|")
    $Triple = $Parts[0]
    $FfmpegUrl = $Parts[1]
    $FfprobeUrl = $Parts[2]
    $Ext = $Parts[3]
    $SubPath = $Parts[4]

    Write-Host "--- Processing $Triple ---"
    
    $ExtractDir = New-Item -ItemType Directory -Force -Path (Join-Path $TempDir "ext_$Triple")
    $FfmpegArchive = Join-Path $TempDir "ffmpeg_$Triple.$Ext"
    
    Download-File $FfmpegUrl $FfmpegArchive
    Extract-File $FfmpegArchive $ExtractDir $Ext

    $ExeExt = if ($Triple -like "*windows*") { ".exe" } else { "" }
    
    # Locate ffmpeg
    $SrcFfmpeg = Get-ChildItem -Path $ExtractDir -Include "ffmpeg$ExeExt" -Recurse -File | Select-Object -First 1

    if ($SrcFfmpeg) {
        $DestFfmpeg = Join-Path $BinDir "ffmpeg-$Triple$ExeExt"
        Move-Item -Path $SrcFfmpeg.FullName -Destination $DestFfmpeg -Force
        Write-Host "Saved ffmpeg-$Triple$ExeExt"
    } else {
        Write-Error "Could not find ffmpeg in $FfmpegArchive"
        continue
    }

    # Handle ffprobe
    if ($FfprobeUrl -eq "INCLUDED") {
        $SrcFfprobe = Get-ChildItem -Path $ExtractDir -Include "ffprobe$ExeExt" -Recurse -File | Select-Object -First 1
        
        if ($SrcFfprobe) {
            $DestFfprobe = Join-Path $BinDir "ffprobe-$Triple$ExeExt"
            Move-Item -Path $SrcFfprobe.FullName -Destination $DestFfprobe -Force
            Write-Host "Saved ffprobe-$Triple$ExeExt"
        }
    } else {
        $FfprobeArchive = Join-Path $TempDir "ffprobe_$Triple.$Ext"
        $FfprobeExtDir = New-Item -ItemType Directory -Force -Path (Join-Path $TempDir "ext_ffprobe_$Triple")
        
        Download-File $FfprobeUrl $FfprobeArchive
        Extract-File $FfprobeArchive $FfprobeExtDir $Ext
        
        $SrcFfprobe = Get-ChildItem -Path $FfprobeExtDir -Include "ffprobe$ExeExt" -Recurse -File | Select-Object -First 1
        if (-not $SrcFfprobe) {
            $SrcFfprobe = Get-ChildItem -Path $FfprobeExtDir -Include "ffmpeg$ExeExt" -Recurse -File | Select-Object -First 1
        }

        if ($SrcFfprobe) {
            $DestFfprobe = Join-Path $BinDir "ffprobe-$Triple$ExeExt"
            Move-Item -Path $SrcFfprobe.FullName -Destination $DestFfprobe -Force
            Write-Host "Saved ffprobe-$Triple$ExeExt"
        }
    }
}

# Cleanup
Remove-Item -Recurse -Force $TempDir
Write-Host "Done! Binaries are in $($BinDir.FullName)"
