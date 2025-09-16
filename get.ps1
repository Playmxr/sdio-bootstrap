<#
get.ps1 - Bootstrap SDI Tools from GitHub Releases
Usage: irm https://driver2.netlify.app/get.ps1 | iex
#>

param()

# -----------------------------
# CONFIGURATION
$githubUser  = "Playmxr"        # GitHub username
$githubRepo  = "sdio-bootstrap" # GitHub repo
$installDir  = Join-Path $env:ProgramData 'SDI'
# -----------------------------

function ThrowIfNoAdmin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) { throw "Run PowerShell as Administrator!" }
}

function Get-SDIExecutable {
    if ([Environment]::Is64BitOperatingSystem) {
        return Join-Path $installDir "SDI64-drv.exe"
    } else {
        return Join-Path $installDir "SDI-drv.exe"
    }
}

function Ensure-7Zip {
    Write-Host "Checking for 7-Zip..." -ForegroundColor Cyan
    $sevenZip = Get-Command 7z.exe -ErrorAction SilentlyContinue

    if (-not $sevenZip) {
        Write-Host "7-Zip is not installed." -ForegroundColor Yellow
        $response = Read-Host "This application requires 7-Zip. Would you like to install it now? (Y/N)"
        if ($response -match '^[Yy]$') {
            $installerUrl = "https://www.7-zip.org/a/7z2408-x64.exe"  # latest 7-Zip for Windows x64
            $tempExe = Join-Path $env:TEMP "7zip_installer.exe"
            Write-Host "Downloading 7-Zip installer..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $installerUrl -OutFile $tempExe -UseBasicParsing
            Write-Host "Installing 7-Zip..." -ForegroundColor Yellow
            Start-Process -FilePath $tempExe -ArgumentList "/S" -Wait
            Remove-Item $tempExe -Force
            Write-Host "7-Zip installed successfully." -ForegroundColor Green
        }
        else {
            throw "7-Zip is required. Exiting."
        }
    }
}

function Download-LatestRelease {
    Write-Host "Fetching latest SDI Tools release..." -ForegroundColor Cyan
    $releaseApi = "https://api.github.com/repos/$githubUser/$githubRepo/releases/latest"
    $headers = @{ "User-Agent" = "PowerShell" }
    $latestRelease = Invoke-RestMethod -Uri $releaseApi -Headers $headers -UseBasicParsing

    $asset = $latestRelease.assets | Where-Object { $_.name -like '*.7z' } | Select-Object -First 1
    if (-not $asset) { throw "No .7z asset found in latest release." }

    $sdiUrl = $asset.browser_download_url
    Write-Host "Latest SDI Tools release: $($asset.name)" -ForegroundColor Green
    Write-Host "Download URL: $sdiUrl" -ForegroundColor Gray

    # Download
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
    $temp7z = Join-Path $env:TEMP ("sdi_" + [System.Guid]::NewGuid().ToString() + ".7z")
    Write-Host "Downloading SDI Tools..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $sdiUrl -OutFile $temp7z -UseBasicParsing -ErrorAction Stop

    # Extract
    Write-Host "Extracting to $installDir ..." -ForegroundColor Yellow
    & 7z.exe x $temp7z "-o$installDir" -y
    if ($LASTEXITCODE -ne 0) { throw "Extraction failed. Check 7-Zip installation." }

    Remove-Item -Path $temp7z -ErrorAction SilentlyContinue
}

# -----------------------------
# Main
ThrowIfNoAdmin
Ensure-7Zip

$sdiExe = Get-SDIExecutable
if (-not (Test-Path $sdiExe)) {
    Download-LatestRelease
    $sdiExe = Get-SDIExecutable
}

Write-Host "Launching SDI Tools GUI..." -ForegroundColor Cyan
Start-Process -FilePath $sdiExe -Wait
Write-Host "SDI Tools session finished." -ForegroundColor Green
