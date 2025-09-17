<#
get.ps1 - Bootstrap SDI Tools from GitHub Releases
Usage: irm https://driver2.netlify.app/get.ps1 | iex
#>

param()

# -----------------------------
$githubUser = "Playmxr"
$githubRepo = "sdio-bootstrap"
$installDir = Join-Path $env:ProgramData 'SDI'
$toolsDir   = Join-Path $installDir 'tools'
$sdiArchive = "SDI_1.25.3.7z"
# -----------------------------

function ThrowIfNoAdmin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) {
        throw "Run PowerShell as Administrator!"
    }
}

function Ensure-7Zip {
    param([string]$targetDir)

    $sevenZipExe = Join-Path $targetDir "7z.exe"
    if (Test-Path $sevenZipExe) { return $sevenZipExe }

    Write-Host "[!] 7-Zip not found in tools folder, downloading portable version..." -ForegroundColor Yellow
    $portableZip = Join-Path $env:TEMP "7zip-portable.zip"
    $portableUrl = "https://www.7-zip.org/a/7z2408-win64.zip"

    Invoke-WebRequest -Uri $portableUrl -OutFile $portableZip -UseBasicParsing
    Expand-Archive -Path $portableZip -DestinationPath $targetDir -Force

    Remove-Item $portableZip -Force -ErrorAction SilentlyContinue

    if (-not (Test-Path $sevenZipExe)) {
        throw "Failed to extract portable 7-Zip into $targetDir"
    }

    return $sevenZipExe
}

try {
    ThrowIfNoAdmin

    # Ensure directories
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
    New-Item -Path $toolsDir   -ItemType Directory -Force | Out-Null

    # Download SDI archive
    $releaseApi = "https://api.github.com/repos/$githubUser/$githubRepo/releases/latest"
    Write-Host "Fetching latest release info from $releaseApi ..." -ForegroundColor Cyan
    $latestRelease = Invoke-RestMethod -Uri $releaseApi -UseBasicParsing

    $asset = $latestRelease.assets | Where-Object { $_.name -eq $sdiArchive } | Select-Object -First 1
    if (-not $asset) { throw "Archive $sdiArchive not found in latest release" }
    $sdiUrl = $asset.browser_download_url

    $tempArchive = Join-Path $env:TEMP $sdiArchive
    if (-not (Test-Path $tempArchive)) {
        Write-Host "Downloading $sdiArchive ..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $sdiUrl -OutFile $tempArchive -UseBasicParsing
    }

    # Ensure 7-Zip
    $sevenZipExe = Ensure-7Zip -targetDir $toolsDir

    # Extract SDI
    Write-Host "Extracting SDI archive into $installDir ..." -ForegroundColor Yellow
    & $sevenZipExe x -y -o"$installDir" $tempArchive | Out-Null

    # Final check for 7-Zip in SDI tools
    if (-not (Test-Path (Join-Path $toolsDir "7z.exe"))) {
        Copy-Item (Join-Path $toolsDir "7z.exe") -Destination $toolsDir -Force
        Copy-Item (Join-Path $toolsDir "7z.dll") -Destination $toolsDir -Force
    }

    # Select correct EXE
    if ([Environment]::Is64BitOperatingSystem) {
        $sdiExe = Join-Path $installDir "SDI64-drv.exe"
    } else {
        $sdiExe = Join-Path $installDir "SDI-drv.exe"
    }

    if (-not (Test-Path $sdiExe)) { throw "Could not find SDI executable in $installDir" }

    Write-Host "Launching SDI: $sdiExe" -ForegroundColor Green
    Start-Process -FilePath $sdiExe -WorkingDirectory $installDir

} catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}
