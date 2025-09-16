<#
get.ps1 - Bootstrap SDIO from GitHub Releases (Interactive mode)
Usage: irm https://driver2.netlify.app/get.ps1 | iex
#>

param()

# -----------------------------
# CONFIGURATION
$githubUser  = "Playmxr"       # your GitHub username
$githubRepo  = "sdio-bootstrap" # your GitHub repo
$installDir  = Join-Path $env:ProgramData 'SDIO'
$driversDir  = Join-Path $installDir 'drivers'
$autoClose   = $true   # true = SDIO closes after you manually finish installs
# -----------------------------

function ThrowIfNoAdmin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) {
        throw "Run PowerShell as Administrator!"
    }
}

try {
    ThrowIfNoAdmin

    # -----------------------------
    # Get latest release from GitHub
    $releaseApi = "https://api.github.com/repos/$githubUser/$githubRepo/releases/latest"
    $headers = @{ "User-Agent" = "PowerShell" } # GitHub requires a User-Agent
    Write-Host "Fetching latest release info..." -ForegroundColor Cyan
    $latestRelease = Invoke-RestMethod -Uri $releaseApi -Headers $headers -UseBasicParsing

    $asset = $latestRelease.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
    if (-not $asset) { throw "No .zip asset found in latest release." }
    $sdioUrl = $asset.browser_download_url

    Write-Host "Latest SDIO release: $($asset.name)" -ForegroundColor Green
    Write-Host "Download URL: $sdioUrl" -ForegroundColor Gray

    # -----------------------------
    # Prepare folders
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
    New-Item -Path $driversDir -ItemType Directory -Force | Out-Null

    $tempZip = Join-Path $env:TEMP ("sdio_" + [System.Guid]::NewGuid().ToString() + ".zip")

    # Download SDIO zip
    Write-Host "Downloading SDIO..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $sdioUrl -OutFile $tempZip -UseBasicParsing -ErrorAction Stop

    # Extract
    Write-Host "Extracting to $installDir ..." -ForegroundColor Yellow
    Expand-Archive -Path $tempZip -DestinationPath $installDir -Force

    # -----------------------------
    # Choose correct executable based on system architecture
    if ([Environment]::Is64BitOperatingSystem) {
        $sdioExe = Get-ChildItem -Path $installDir -Filter 'SDIO_x64_*.exe' -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    } else {
        $sdioExe = Get-ChildItem -Path $installDir -Filter 'SDIO_*.exe' -Recurse | Where-Object { $_.Name -notlike 'SDIO_x64*' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }

    if (-not $sdioExe) { throw "Could not find SDIO executable in $installDir" }
    Write-Host "Launching SDIO: $($sdioExe.FullName)" -ForegroundColor Green

    # -----------------------------
    # Build arguments (interactive mode)
    $args = @()
    $args += "-drp_dir:`"$driversDir`""
    if ($autoClose) { $args += "-autoclose" }

    $argumentString = $args -join ' '

    # Start SDIO GUI (manual driver selection)
    $proc = Start-Process -FilePath $sdioExe.FullName -ArgumentList $argumentString -PassThru
    $proc.WaitForExit()

    Write-Host "SDIO session finished." -ForegroundColor Green

    # Cleanup temporary zip
    Remove-Item -Path $tempZip -ErrorAction SilentlyContinue

}
catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}
