<#
get.ps1 - Bootstrap SDIO from GitHub Releases
Usage: irm https://raw.githubusercontent.com/<youruser>/<yourrepo>/main/get.ps1 | iex
#>

param()

# -----------------------------
# CONFIGURE THIS ONCE
$githubUser = "Playmxr"       # <-- change this to your GitHub username/org
$githubRepo = "sdio-bootstrap"   # <-- change this to your repo name
$installDir = Join-Path $env:ProgramData 'SDIO'
$driversDir = Join-Path $installDir 'drivers'
$autoInstall = $false  # true = auto-install drivers, false = open UI
$autoClose   = $true   # true = auto-close when done
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

    # Query GitHub API for the latest release
    $releaseApi = "https://api.github.com/repos/$githubUser/$githubRepo/releases/latest"
    Write-Host "Fetching latest release info from $releaseApi ..." -ForegroundColor Cyan
    $headers = @{ "User-Agent" = "PowerShell" }
$latestRelease = Invoke-RestMethod -Uri $releaseApi -Headers $headers -UseBasicParsing

    # Find first .zip asset
    $asset = $latestRelease.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
    if (-not $asset) { throw "No .zip asset found in the latest release of $githubRepo" }
    $sdioUrl = $asset.browser_download_url

    Write-Host "Latest SDIO release asset: $($asset.name)" -ForegroundColor Green
    Write-Host "Download URL: $sdioUrl" -ForegroundColor Gray

    # Prepare folders
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
    New-Item -Path $driversDir -ItemType Directory -Force | Out-Null

    # Temp zip path
    $tempZip = Join-Path $env:TEMP ("sdio_" + [System.Guid]::NewGuid().ToString() + ".zip")

    # Download asset
    Write-Host "Downloading SDIO..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $sdioUrl -OutFile $tempZip -UseBasicParsing -ErrorAction Stop

    # Extract
    Write-Host "Extracting to $installDir ..." -ForegroundColor Yellow
    Expand-Archive -Path $tempZip -DestinationPath $installDir -Force

    # Locate exe
    $sdioExe = Get-ChildItem -Path $installDir -Filter 'SDIO*.exe' -Recurse -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $sdioExe) {
        $sdioExe = Get-ChildItem -Path $installDir -Include 'sdio.exe','sdi.exe' -Recurse -ErrorAction SilentlyContinue |
                   Select-Object -First 1
    }
    if (-not $sdioExe) { throw "Could not find SDIO executable in $installDir" }

    Write-Host "Found SDIO: $($sdioExe.FullName)" -ForegroundColor Green

    # Build args
    $args = @()
    $args += "-drp_dir:`"$driversDir`""
    if ($autoInstall) { $args += "-autoinstall" }
    if ($autoClose)   { $args += "-autoclose" }
    $argumentString = $args -join ' '

    # Run
    Write-Host "Launching SDIO with args: $argumentString" -ForegroundColor Cyan
    $proc = Start-Process -FilePath $sdioExe.FullName -ArgumentList $argumentString -PassThru
    $proc.WaitForExit()

    Write-Host "SDIO finished (exit code $($proc.ExitCode))" -ForegroundColor Green

    # Cleanup
    Remove-Item -Path $tempZip -ErrorAction SilentlyContinue
}
catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}
