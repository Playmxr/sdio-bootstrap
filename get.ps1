<#
get.ps1 - Bootstrap SDI Tools with 7-Zip check
Usage: irm https://raw.githubusercontent.com/Playmxr/sdio-bootstrap/main/get.ps1 | iex
#>

param()

# -----------------------------
$githubUser = "Playmxr"
$githubRepo = "sdio-bootstrap"
$installDir = Join-Path $env:ProgramData 'SDI'
$toolsDir   = Join-Path $installDir 'tools'
$driversDir = Join-Path $installDir 'drivers'
$sevenZipExe = Join-Path $toolsDir '7z.exe'
# -----------------------------

function ThrowIfNoAdmin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) {
        throw "Run PowerShell as Administrator!"
    }
}

function Install-7Zip {
    param([string]$toolsDir)

    Write-Host "`n[!] 7-Zip not found in $toolsDir" -ForegroundColor Yellow
    $choice = Read-Host "Would you like to download and install portable 7-Zip now? (Y/N)"
    if ($choice -notin @('Y','y','Yes','yes')) {
        throw "7-Zip is required for SDI Tools. Exiting."
    }

    $sevenZipUrl = "https://www.7-zip.org/a/7zr.exe"
    $sevenZipMini = Join-Path $env:TEMP "7zr.exe"
    $sevenZipFull = "https://www.7-zip.org/a/7z2408-extra.7z"   # latest extra package with 7z.exe + 7z.dll
    $temp7z = Join-Path $env:TEMP "7z_extra.7z"

    Write-Host "Downloading minimal 7-Zip extractor..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $sevenZipUrl -OutFile $sevenZipMini -UseBasicParsing

    Write-Host "Downloading 7-Zip portable package..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $sevenZipFull -OutFile $temp7z -UseBasicParsing

    Write-Host "Extracting 7-Zip binaries to $toolsDir ..." -ForegroundColor Cyan
    New-Item -Path $toolsDir -ItemType Directory -Force | Out-Null
    & $sevenZipMini x $temp7z -o"$toolsDir" -y | Out-Null

    if (-not (Test-Path (Join-Path $toolsDir "7z.exe"))) {
        throw "Failed to extract 7-Zip binaries."
    }

    Write-Host "7-Zip installed successfully in $toolsDir" -ForegroundColor Green

    # Cleanup
    Remove-Item $sevenZipMini, $temp7z -Force -ErrorAction SilentlyContinue
}

try {
    ThrowIfNoAdmin

    # Check 7-Zip before proceeding
    if (-not (Test-Path $sevenZipExe)) {
        Install-7Zip -toolsDir $toolsDir
    }

    # Query GitHub API for the latest release
    $releaseApi = "https://api.github.com/repos/$githubUser/$githubRepo/releases/latest"
    Write-Host "Fetching latest SDI release info..." -ForegroundColor Cyan
    $latestRelease = Invoke-RestMethod -Uri $releaseApi -UseBasicParsing

    $asset = $latestRelease.assets | Where-Object { $_.name -like '*.7z' } | Select-Object -First 1
    if (-not $asset) { throw "No .7z asset found in the latest release of $githubRepo" }
    $sdiUrl = $asset.browser_download_url

    # Prepare folders
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
    New-Item -Path $driversDir -ItemType Directory -Force | Out-Null

    # Download SDI Tools
    $tempFile = Join-Path $env:TEMP ("sdi_" + [System.Guid]::NewGuid().ToString() + ".7z")
    Write-Host "Downloading SDI Tools..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $sdiUrl -OutFile $tempFile -UseBasicParsing -ErrorAction Stop

    # Extract SDI Tools
    Write-Host "Extracting to $installDir ..." -ForegroundColor Yellow
    & $sevenZipExe x $tempFile -o"$installDir" -y | Out-Null

    # Detect exe (prefer 64-bit)
    $exe = Get-ChildItem -Path $installDir -Filter 'SDI64-drv.exe' -Recurse -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $exe) {
        $exe = Get-ChildItem -Path $installDir -Filter 'SDI-drv.exe' -Recurse -ErrorAction SilentlyContinue |
               Select-Object -First 1
    }
    if (-not $exe) { throw "Could not find SDI executable in $installDir" }

    Write-Host "Launching SDI Tools: $($exe.FullName)" -ForegroundColor Cyan
    Start-Process -FilePath $exe.FullName -WorkingDirectory $installDir
}
catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}
