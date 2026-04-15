# FFmpeg & FFprobe download script for lap-binaries
# Downloads platform-specific binaries and renames them to match
# Tauri sidecar naming: <binary>-<target-triple>[.exe]

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BinDir = Join-Path $ScriptDir "../binaries"
$TempDir = Join-Path $ScriptDir "../temp_downloads"

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

$Targets = @(
    "x86_64-apple-darwin|https://evermeet.cx/ffmpeg/getrelease/zip|https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip|zip",
    "aarch64-apple-darwin|https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/ffmpeg.zip|https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/ffprobe.zip|zip",
    "x86_64-pc-windows-msvc|https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip|INCLUDED|zip",
    "x86_64-unknown-linux-gnu|https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz|INCLUDED|tar.xz",
    "aarch64-unknown-linux-gnu|https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linuxarm64-gpl.tar.xz|INCLUDED|tar.xz"
)

function Download-File {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutFile
    )

    if ((Test-Path $OutFile) -and ((Get-Item $OutFile).Length -gt 0)) {
        Write-Host "Using cached file: $OutFile"
        return
    }

    Write-Host "Downloading $Url ..."
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -MaximumRetryCount 5 -RetryIntervalSec 5
}

function Extract-File {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Ext
    )

    New-Item -ItemType Directory -Force -Path $Dir | Out-Null

    if ($Ext -eq "zip") {
        Expand-Archive -Path $File -DestinationPath $Dir -Force
    }
    elseif ($Ext -eq "tar.xz") {
        tar -xf $File -C $Dir
    }
    else {
        throw "Unsupported archive type: $Ext"
    }
}

function Find-Binary {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return Get-ChildItem -Path $Root -Recurse -File | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
}

function Save-Binary {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestPath
    )

    Copy-Item -Path $SourcePath -Destination $DestPath -Force
    Write-Host "Saved: $DestPath"
}

function Verify-Binary {
    param(
        [Parameter(Mandatory = $true)][string]$BinaryPath,
        [Parameter(Mandatory = $true)][string]$ExpectedName
    )

    if (-not (Test-Path $BinaryPath)) {
        throw "Binary not found: $BinaryPath"
    }

    $Output = & $BinaryPath -version 2>&1
    if (-not $Output) {
        throw "Failed to execute: $BinaryPath"
    }

    $FirstLine = $Output[0].ToString().Trim()

    if (-not $FirstLine.StartsWith("$ExpectedName version ")) {
        throw "Invalid $ExpectedName binary: $BinaryPath`nActual: $FirstLine"
    }

    Write-Host "Verified: $ExpectedName -> $FirstLine"
}

try {
    foreach ($Target in $Targets) {
        $Parts = $Target.Split("|")
        $Triple = $Parts[0]
        $FfmpegUrl = $Parts[1]
        $FfprobeUrl = $Parts[2]
        $Ext = $Parts[3]

        Write-Host ""
        Write-Host "=== Processing $Triple ==="

        $ExeExt = if ($Triple -like "*windows*") { ".exe" } else { "" }

        $FfmpegArchive = Join-Path $TempDir "ffmpeg_$Triple.$Ext"
        $FfprobeArchive = Join-Path $TempDir "ffprobe_$Triple.$Ext"

        $FfmpegExtractDir = Join-Path $TempDir "extract_ffmpeg_$Triple"
        $FfprobeExtractDir = Join-Path $TempDir "extract_ffprobe_$Triple"

        if (Test-Path $FfmpegExtractDir) { Remove-Item -Recurse -Force $FfmpegExtractDir }
        if (Test-Path $FfprobeExtractDir) { Remove-Item -Recurse -Force $FfprobeExtractDir }

        Download-File -Url $FfmpegUrl -OutFile $FfmpegArchive
        Extract-File -File $FfmpegArchive -Dir $FfmpegExtractDir -Ext $Ext

        $SrcFfmpeg = Find-Binary -Root $FfmpegExtractDir -Name "ffmpeg$ExeExt"
        if (-not $SrcFfmpeg) {
            throw "Could not find ffmpeg for $Triple"
        }

        $DestFfmpeg = Join-Path $BinDir "ffmpeg-$Triple$ExeExt"
        Save-Binary -SourcePath $SrcFfmpeg.FullName -DestPath $DestFfmpeg
        Verify-Binary -BinaryPath $DestFfmpeg -ExpectedName "ffmpeg"

        if ($FfprobeUrl -eq "INCLUDED") {
            $SrcFfprobe = Find-Binary -Root $FfmpegExtractDir -Name "ffprobe$ExeExt"
            if (-not $SrcFfprobe) {
                throw "Could not find ffprobe in included archive for $Triple"
            }

            $DestFfprobe = Join-Path $BinDir "ffprobe-$Triple$ExeExt"
            Save-Binary -SourcePath $SrcFfprobe.FullName -DestPath $DestFfprobe
            Verify-Binary -BinaryPath $DestFfprobe -ExpectedName "ffprobe"
        }
        else {
            Download-File -Url $FfprobeUrl -OutFile $FfprobeArchive
            Extract-File -File $FfprobeArchive -Dir $FfprobeExtractDir -Ext $Ext

            $SrcFfprobe = Find-Binary -Root $FfprobeExtractDir -Name "ffprobe$ExeExt"
            if (-not $SrcFfprobe) {
                throw "Could not find ffprobe for $Triple"
            }

            $DestFfprobe = Join-Path $BinDir "ffprobe-$Triple$ExeExt"
            Save-Binary -SourcePath $SrcFfprobe.FullName -DestPath $DestFfprobe
            Verify-Binary -BinaryPath $DestFfprobe -ExpectedName "ffprobe"
        }
    }

    Write-Host ""
    Write-Host "Done! Binaries are in $BinDir"
    Get-ChildItem $BinDir | Select-Object Name, Length
}
finally {
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force $TempDir
    }
}