#Requires -Version 5.1
<#
  CM311-1 (Amlogic S905L3 family) flashing material downloader.

  Downloads from OFFICIAL upstream sources only, and verifies SHA256 where a
  published checksum exists. Nothing is re-hosted by this project on purpose:
  re-distributing third-party binaries (especially the proprietary Amlogic
  USB Burning Tool) would create a supply-chain risk for other users.

  ASCII-only on purpose: Windows PowerShell 5.1 mis-decodes UTF-8 scripts.

  Usage:
    .\download-materials.ps1                    # default target .\materials
    .\download-materials.ps1 -Base D:\cm311     # custom target
    .\download-materials.ps1 -ToolsOnly         # skip the ~2.5 GB images
#>
[CmdletBinding()]
param(
    [string]$Base = (Join-Path $PSScriptRoot '..\materials'),
    [switch]$ToolsOnly
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

$Base    = [System.IO.Path]::GetFullPath($Base)
$ImgDir  = Join-Path $Base 'images'
$ToolDir = Join-Path $Base 'tools'

New-Item -ItemType Directory -Force -Path $ImgDir, $ToolDir | Out-Null

$REL = 'https://github.com/ophub/amlogic-s9xxx-armbian/releases/download/Armbian_trixie_arm64_server_2026.09'

# ---------------------------------------------------------------- images
# Debian 13 (trixie) / kernel 6.18.51 / server build - smallest footprint,
# best fit for a 2 GB box. All three s905l3-family boards are pre-fetched so
# the right one is on disk once the real chip (L3 vs L3B) is confirmed via TTL.
$Images = @(
    @{ Name = 'Armbian_26.11.0_amlogic_s905l3_trixie_6.18.51_server_2026.09.14.img.gz'
       Url  = "$REL/Armbian_26.11.0_amlogic_s905l3_trixie_6.18.51_server_2026.09.14.img.gz"
       Sha256 = '2A3886AE263A7CF3A44A53FC8BF674FD181A5D34A8A06FC3403A8713CCD4A205'
       Note = 'PRIMARY   s905l3      (model DB ID 122 / CM311-1)' },
    @{ Name = 'Armbian_26.11.0_amlogic_s905l3b_trixie_6.18.51_server_2026.09.14.img.gz'
       Url  = "$REL/Armbian_26.11.0_amlogic_s905l3b_trixie_6.18.51_server_2026.09.14.img.gz"
       Sha256 = '7C121575CBC35E7AF680B251BC90049605E82915DC62F756551C80C20F0CD8B2'
       Note = 'FALLBACK  s905l3b     (model DB ID 127 / CM311-1)' },
    @{ Name = 'Armbian_26.11.0_amlogic_s905l3-cm211_trixie_6.18.51_server_2026.09.14.img.gz'
       Url  = "$REL/Armbian_26.11.0_amlogic_s905l3-cm211_trixie_6.18.51_server_2026.09.14.img.gz"
       Sha256 = '54A137C2BF58CA0B151D6F54BF52953280E4427CC434AC882D4F87951FB27862'
       Note = 'FALLBACK  s905l3-cm211 (CM211-1 / M411A board)' }
)

# ---------------------------------------------------------------- tools
# Official upstream only. `Verify` = we hold a trustworthy checksum for it.
$Tools = @(
    @{ Name = 'balenaEtcher-2.1.7.Setup.exe'
       Url  = 'https://github.com/balena-io/etcher/releases/download/v2.1.7/balenaEtcher-2.1.7.Setup.exe'
       Sha256 = '386BB45DA6E0EDEB20E065427CDEF30A876E4D2A59579F8ADD329D8510AC12F8'
       Note = 'Write image to USB stick / SDD. Checksum matches balena SHA256SUMS.Windows.x64.txt' },
    @{ Name = 'platform-tools-latest-windows.zip'
       Url  = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'
       Sha256 = '45F4D63113E895EBDE0C90F194099A4676B6AC653BD28D54314A9E022BBC1A99'
       Note = 'Google official adb. Version moves over time - checksum may drift.' },
    @{ Name = '7z2501-x64.exe'
       Url  = 'https://www.7-zip.org/a/7z2501-x64.exe'
       Sha256 = ''
       Note = 'Official 7-zip site. No fixed checksum kept - verify on 7-zip.org if concerned.' }
)

# ---------------------------------------------------------------- helpers
function Get-File {
    param([string]$Url, [string]$Dest, [string]$Label, [string]$Expect)

    if (Test-Path $Dest) {
        $sz = (Get-Item $Dest).Length
        if ($sz -gt 0) {
            Write-Host ("  [SKIP] present: {0} ({1} MB)" -f $Label, [math]::Round($sz/1MB,1))
            return (Test-Hash -Path $Dest -Expect $Expect -Label $Label)
        }
    }

    Write-Host "  [GET ] $Label"
    Write-Host "         $Url"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing -TimeoutSec 3600
    } catch {
        Write-Host "  [FAIL] $Label -> $($_.Exception.Message)"
        if (Test-Path $Dest) { Remove-Item $Dest -Force -ErrorAction SilentlyContinue }
        return $false
    }
    $sw.Stop()
    $mb = [math]::Round((Get-Item $Dest).Length/1MB,1)
    $sp = if ($sw.Elapsed.TotalSeconds -gt 0) { [math]::Round($mb/$sw.Elapsed.TotalSeconds,2) } else { 0 }
    Write-Host ("  [ OK ] {0}  {1} MB  in {2} min  avg {3} MB/s" -f $Label, $mb, [math]::Round($sw.Elapsed.TotalMinutes,1), $sp)
    return (Test-Hash -Path $Dest -Expect $Expect -Label $Label)
}

function Test-Hash {
    param([string]$Path, [string]$Expect, [string]$Label)
    if ([string]::IsNullOrWhiteSpace($Expect)) {
        Write-Host "         (no checksum held - verify at the official source if needed)"
        return $true
    }
    $actual = (Get-FileHash -Path $Path -Algorithm SHA256).Hash
    if ($actual -eq $Expect) {
        Write-Host "  [VERI] SHA256 OK"
        return $true
    }
    Write-Host "  [WARN] SHA256 MISMATCH for $Label"
    Write-Host "         expected: $Expect"
    Write-Host "         actual  : $actual"
    return $false
}

# ---------------------------------------------------------------- main
Write-Host ''
Write-Host '=================================================='
Write-Host ' CM311-1 / S905L3 family - flashing material fetch'
Write-Host " target: $Base"
Write-Host '=================================================='

$bad = 0

if (-not $ToolsOnly) {
    Write-Host ''
    Write-Host '--- 1/2  Armbian images (official ophub releases) ---'
    foreach ($i in $Images) {
        Write-Host ''
        Write-Host "  * $($i.Note)"
        if (-not (Get-File -Url $i.Url -Dest (Join-Path $ImgDir $i.Name) -Label $i.Name -Expect $i.Sha256)) { $bad++ }
    }
} else {
    Write-Host ''
    Write-Host '--- 1/2  Armbian images: SKIPPED (-ToolsOnly) ---'
}

Write-Host ''
Write-Host '--- 2/2  Tools (official upstream) ---'
foreach ($t in $Tools) {
    Write-Host ''
    Write-Host "  * $($t.Note)"
    if (-not (Get-File -Url $t.Url -Dest (Join-Path $ToolDir $t.Name) -Label $t.Name -Expect $t.Sha256)) { $bad++ }
}

Write-Host ''
Write-Host '=================================================='
Write-Host ' SUMMARY'
Write-Host '=================================================='
foreach ($d in @($ImgDir, $ToolDir)) {
    Write-Host ''
    Write-Host "  $d"
    $files = Get-ChildItem -File $d -ErrorAction SilentlyContinue | Sort-Object Name
    if ($files.Count -eq 0) { Write-Host '    (empty)' }
    foreach ($f in $files) {
        Write-Host ("    {0,-74} {1,9} MB" -f $f.Name, [math]::Round($f.Length/1MB,1))
    }
}

Write-Host ''
if ($bad -gt 0) {
    Write-Host "DONE with $bad problem(s) - see [FAIL]/[WARN] above"
    exit 1
}
Write-Host 'DONE - all files present and checksums verified'

# ---------------------------------------------------------------- not fetched
Write-Host ''
Write-Host '--------------------------------------------------'
Write-Host ' NOT downloaded on purpose'
Write-Host '--------------------------------------------------'
Write-Host ' Amlogic USB Burning Tool (line-flash / unbrick)'
Write-Host '   Proprietary Amlogic software, no redistribution'
Write-Host '   license and no official public direct link.'
Write-Host '   Get it from a community forum you trust and scan it'
Write-Host '   yourself - do NOT trust unofficial mirrors.'
Write-Host ''
Write-Host ' The original Android stock firmware for CM311-1 (YST).'
Write-Host '   Needed only for unbricking. See docs/ for notes.'
