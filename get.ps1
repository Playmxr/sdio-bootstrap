# get.ps1 - Smart Driver Installer Bootstrapper (fixed flow)

$baseDir   = "$PSScriptRoot\SDI"
$toolsDir  = "$baseDir\tools"
$sdiArchive = "$PSScriptRoot\sdi.7z"
$sdiUrl    = "https://sdi-tool.org/releases/sdi.7z"   # main package

function Ensure-7Zip {
    param([string]$targetDir)

    $sevenZipExe = Join-Path $targetDir "7z.exe"
    if (Test-Path $sevenZipExe) { return $sevenZipExe }

    Write-Host "[!] 7-Zip not found, installing portable version..." -ForegroundColor Yellow
    $sevenZipMini = Join-Path $env:TEMP "7zr.exe"
    $temp7z       = Join-Path $env:TEMP "7z_extra.7z"
    $sevenZipFull = "https://www.7-zip.org/a/7z2408-extra.7z"

    Invoke-WebRequest -Uri "https://www.7-zip.org/a/7zr.exe" -OutFile $sevenZipMini -UseBasicParsing
    Invoke-WebRequest -Uri $sevenZipFull -OutFile $temp7z -UseBasicParsing

    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
    & $sevenZipMini x $temp7z -o"$targetDir" -y | Out-Null

    if (-not (Test-Path $sevenZipExe)) {
        throw "Failed to extract 7-Zip binaries into $targetDir"
    }

    Remove-Item $sevenZipMini, $temp7z -Force -ErrorAction SilentlyContinue
    return $sevenZipExe
}

# Step 1: Download SDI archive if missing
if (-not (Test-Path $sdiArchive)) {
    Write-Host "[+] Downloading SDI package..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $sdiUrl -OutFile $sdiArchive -UseBasicParsing
}

# Step 2: Ensure we have 7-Zip available
$sevenZipExe = Ensure-7Zip -targetDir $toolsDir

# Step 3: Extract SDI archive
if (-not (Test-Path $baseDir)) {
    Write-Host "[+] Extracting SDI package..." -ForegroundColor Cyan
    & $sevenZipExe x $sdiArchive -o"$baseDir" -y | Out-Null
}

# Step 4: Ensure tools\7z.exe exists in extracted SDI folder
if (-not (Test-Path (Join-Path $toolsDir "7z.exe"))) {
    Write-Host "[!] Copying 7-Zip into SDI tools folder..." -ForegroundColor Yellow
    Copy-Item $sevenZipExe $toolsDir -Force
    Copy-Item (Join-Path $toolsDir "7z.dll") $toolsDir -Force -ErrorAction SilentlyContinue
}

# Step 5: Run correct SDI executable
$arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
$exe  = Join-Path $baseDir "SDI_${arch}.exe"

if (Test-Path $exe) {
    Write-Host "[+] Launching SDI for $arch..." -ForegroundColor Green
    & $exe
} else {
    throw "SDI executable not found: $exe"
}
