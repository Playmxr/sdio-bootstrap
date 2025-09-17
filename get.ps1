<#
get.ps1 - Fully Silent SDI Bootstrapper with Auto-Update
Usage: irm https://driver2.netlify.app/get.ps1 | iex
#>

param()

$installDir = Join-Path $env:ProgramData 'SDI'
$toolsDir   = Join-Path $installDir 'tools'
$tempDir    = $env:TEMP
$sdiArchive = "SDI_1.25.3.7z"
$tempArchive = Join-Path $tempDir $sdiArchive
$sevenZipSys = "C:\Program Files\7-Zip\7z.exe"
$sevenZipInstallerUrl = "https://www.7-zip.org/a/7z2408-x64.exe"
$versionFile = Join-Path $installDir "version.txt"

function ThrowIfNoAdmin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) { throw "Run PowerShell as Administrator!" }
}

function Ensure-7Zip {
    if (Test-Path $sevenZipSys) { return $sevenZipSys }

    $installerPath = Join-Path $tempDir "7zInstaller.exe"
    Invoke-WebRequest -Uri $sevenZipInstallerUrl -OutFile $installerPath -UseBasicParsing
    Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
    Remove-Item $installerPath -Force

    if (-not (Test-Path $sevenZipSys)) { throw "7-Zip installation failed" }
    return $sevenZipSys
}

function Get-LatestRelease {
    $apiUrl = "https://api.github.com/repos/Playmxr/sdio-bootstrap/releases/latest"
    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
    $asset = $release.assets | Where-Object { $_.name -eq $sdiArchive } | Select-Object -First 1
    if (-not $asset) { throw "SDI archive not found in latest release" }
    return @{ Version = $release.tag_name; Url = $asset.browser_download_url }
}

function Download-And-Extract($url, $dest, $sevenZipExe) {
    Write-Host "[*] Downloading SDI archive ..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile $tempArchive -UseBasicParsing

    Write-Host "[*] Extracting SDI archive ..." -ForegroundColor Cyan
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
    & $sevenZipExe x -y -o"$dest" $tempArchive | Out-Null

    # Ensure tools folder has 7z.exe + 7z.dll
    if (-not (Test-Path (Join-Path $toolsDir "7z.exe"))) {
        Copy-Item $sevenZipExe -Destination $toolsDir -Force
        $dllSource = Join-Path (Split-Path $sevenZipExe) "7z.dll"
        if (Test-Path $dllSource) { Copy-Item $dllSource -Destination $toolsDir -Force }
    }

    # Write version file
    $latestRelease.Version | Out-File -FilePath $versionFile -Encoding UTF8

    # Auto-clean TEMP archive
    Remove-Item $tempArchive -Force -ErrorAction SilentlyContinue
}

try {
    ThrowIfNoAdmin

    # Step 0: Ensure 7-Zip installed
    $sevenZipExe = Ensure-7Zip

    # Step 1: Get latest release info
    $latestRelease = Get-LatestRelease
    $latestVersion = $latestRelease.Version
    $needsUpdate = $true

    if (Test-Path $versionFile) {
        $installedVersion = Get-Content $versionFile -Raw
        if ($installedVersion -eq $latestVersion) {
            Write-Host "[*] SDI is up-to-date ($latestVersion)." -ForegroundColor Green
            $needsUpdate = $false
        }
    }

    # Step 2: Download & extract if needed
    if ($needsUpdate) {
        Download-And-Extract $latestRelease.Url $installDir $sevenZipExe
        Write-Host "[*] SDI updated to $latestVersion." -ForegroundColor Green
    }

    # Step 3: Run correct SDI exe
    if ([Environment]::Is64BitOperatingSystem) {
        $sdiExe = Join-Path $installDir "SDI64-drv.exe"
    } else {
        $sdiExe = Join-Path $installDir "SDI-drv.exe"
    }

    if (-not (Test-Path $sdiExe)) { throw "Could not find SDI executable" }

    Start-Process -FilePath $sdiExe -WorkingDirectory $installDir

} catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}
