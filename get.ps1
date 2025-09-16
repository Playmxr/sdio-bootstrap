<#
get.ps1 - Bootstrap SDI Tools from GitHub Releases (Menu-driven CLI)
Usage: irm https://driver2.netlify.app/get.ps1 | iex
#>

param()

# -----------------------------
# CONFIGURATION
$githubUser  = "Playmxr"        # GitHub username
$githubRepo  = "sdio-bootstrap" # GitHub repo
$installDir  = Join-Path $env:ProgramData 'SDI'
$driversDir  = Join-Path $installDir 'drivers'
$indexDir    = Join-Path $installDir 'index'
$offlineDir  = Join-Path $installDir 'offline'
$autoClose   = $true   # true = SDI closes after manual driver install
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
    $sevenZip = "7z.exe"
    & $sevenZip x $temp7z "-o$installDir" -y
    if ($LASTEXITCODE -ne 0) { throw "Extraction failed. Make sure 7-Zip is installed and in PATH." }

    Remove-Item -Path $temp7z -ErrorAction SilentlyContinue
}

function Download-Indexes {
    Write-Host "`nDownloading indexes (online mode)..." -ForegroundColor Cyan
    $sdiExe = Get-SDIExecutable
    Start-Process -FilePath $sdiExe -ArgumentList "-online -update -index_dir:`"$indexDir`"" -Wait
    Write-Host "Indexes download complete." -ForegroundColor Green
}

function Scan-Hardware {
    Write-Host "`nScanning hardware for missing/outdated drivers..." -ForegroundColor Cyan
    $sdiExe = Get-SDIExecutable
    Start-Process -FilePath $sdiExe -ArgumentList "-online -drp_dir:`"$driversDir`"" -Wait
}

function Auto-Install-Drivers {
    $batFile = Join-Path $installDir "SDI_auto.bat"
    if (Test-Path $batFile) {
        Write-Host "`nRunning automatic driver installer..." -ForegroundColor Yellow
        Start-Process -FilePath $batFile -Wait
    } else {
        Write-Warning "SDI_auto.bat not found!"
    }
}

function Download-Offline-Packs {
    Write-Host "`nDownloading full offline packs..." -ForegroundColor Cyan
    $sdiExe = Get-SDIExecutable
    Start-Process -FilePath $sdiExe -ArgumentList "-offline -drp_dir:`"$offlineDir`"" -Wait
    Write-Host "Offline pack download complete." -ForegroundColor Green
}

function Run-FullGUI {
    Write-Host "`nLaunching full SDI GUI..." -ForegroundColor Cyan
    $sdiExe = Get-SDIExecutable
    Start-Process -FilePath $sdiExe -Wait
}

# -----------------------------
# Main Menu
ThrowIfNoAdmin
$sdiExe = Get-SDIExecutable
if (-not (Test-Path $sdiExe)) {
    Download-LatestRelease
}

do {
    Clear-Host
    Write-Host "====== SDI Tools Menu ======" -ForegroundColor Cyan
    Write-Host "1) Download indexes and scan hardware (online-only)"
    Write-Host "2) Download full offline packs"
    Write-Host "3) Run full SDI GUI"
    Write-Host "4) Exit"
    $choice = Read-Host "Enter choice"

    switch ($choice) {
        1 {
            Download-Indexes
            Scan-Hardware

            # Post-scan menu
            do {
                Write-Host "`nSelect an action after scan:" -ForegroundColor Cyan
                Write-Host "1) Download all missing drivers automatically"
                Write-Host "2) Select specific drivers to download/install"
                Write-Host "3) Go back"
                $postChoice = Read-Host "Enter choice"

                switch ($postChoice) {
                    1 { Auto-Install-Drivers }
                    2 { Scan-Hardware } # opens GUI to select specific drivers
                    3 { break }
                    default { Write-Host "Invalid choice." -ForegroundColor Red }
                }
            } while ($postChoice -ne 3)
        }
        2 { Download-Offline-Packs }
        3 { Run-FullGUI }
        4 { break }
        default { Write-Host "Invalid choice." -ForegroundColor Red }
    }
} while ($choice -ne 4)

Write-Host "`nSDI Tools session ended." -ForegroundColor Green
