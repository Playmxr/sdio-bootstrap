<#
get.ps1 - Fully Silent SDI Bootstrapper
Usage: irm https://driver2.netlify.app/get.ps1 | iex
#>

param()

$installDir = Join-Path $env:ProgramData 'SDI'
$toolsDir   = Join-Path $installDir 'tools'
$tempDir    = $env:TEMP
$sdiArchive = "SDI_1.25.3.7z"
$tempArchive = Join-Path $tempDir $sdiArchive
$sevenZipSys = "C:\Program Files\7-Zip\7z.exe"
$sevenZipInstallerUrl = "https://www.7-zip.org/a/7z2408-x64.exe"  # official silent installer

function ThrowIfNoAdmin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) {
        throw "Run PowerShell as Administrator!"
    }
}

function Ensure-7Zip {
    if (Test-Path $sevenZipSys) {
        return $sevenZipSys
    }

    # Download silent installer
    $installerPath = Join-Path $tempDir "7zInstaller.exe"
    Invoke-WebRequest -Uri $sevenZipInstallerUrl -OutFile $installerPath -UseBasicParsing

    # Silent install
    Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait

    if (-not (Test-Path $sevenZipSys)) {
        throw "7-Zip installation failed"
    }

    Remove-Item $installerPath -Force
    return $sevenZipSys
}

try {
    ThrowIfNoAdmin

    # Step 1: Download SDI archive silently
    if (-not (Test-Path $tempArchive)) {
        $releaseApi = "https://api.github.com/repos/Playmxr/sdio-bootstrap/releases/latest"
        $latestRelease = Invoke-RestMethod -Uri $releaseApi -UseBasicParsing
        $asset = $latestRelease.assets | Where-Object { $_.name -eq $sdiArchive } | Select-Object -First 1
        if (-not $asset) { throw "SDI archive not found in latest release" }
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempArchive -UseBasicParsing
    }

    # Step 2: Ensure 7-Zip installed
    $sevenZipExe = Ensure-7Zip

    # Step 3: Extract SDI archive silently
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
    & $sevenZipExe x -y -o"$installDir" $tempArchive | Out-Null

    # Step 4: Ensure tools folder has 7z.exe + 7z.dll
    if (-not (Test-Path (Join-Path $toolsDir "7z.exe"))) {
        Copy-Item $sevenZipExe -Destination $toolsDir -Force
        $dllSource = Join-Path (Split-Path $sevenZipExe) "7z.dll"
        if (Test-Path $dllSource) { Copy-Item $dllSource -Destination $toolsDir -Force }
    }

    # Step 5: Run correct SDI exe silently
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
