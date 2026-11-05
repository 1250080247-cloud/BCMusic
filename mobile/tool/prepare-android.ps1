param([switch]$InstallSdk)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$androidTaskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\.android-tools'))
$androidTaskDownloads = Join-Path $androidTaskRoot 'downloads'
New-Item -ItemType Directory -Force -Path $androidTaskDownloads | Out-Null

function Get-VerifiedArchive([string]$Url, [string]$Path, [string]$Sha256) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Output "Downloading $([IO.Path]::GetFileName($Path))"
        Invoke-WebRequest -Uri $Url -OutFile $Path
    }
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Sha256) {
        throw "Checksum mismatch: $Path. Inspect and remove this exact archive before retrying."
    }
}

$androidTaskJdk = Get-ChildItem -LiteralPath $androidTaskRoot -Directory -Filter 'jdk-17*' | Select-Object -First 1
if (-not $androidTaskJdk) {
    $androidTaskAssets = Invoke-RestMethod 'https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse'
    $androidTaskPackage = $androidTaskAssets[0].binary.package
    $androidTaskJdkZip = Join-Path $androidTaskDownloads $androidTaskPackage.name
    Get-VerifiedArchive $androidTaskPackage.link $androidTaskJdkZip $androidTaskPackage.checksum
    Expand-Archive -LiteralPath $androidTaskJdkZip -DestinationPath $androidTaskRoot -Force
    $androidTaskJdk = Get-ChildItem -LiteralPath $androidTaskRoot -Directory -Filter 'jdk-17*' | Select-Object -First 1
}
if (-not $androidTaskJdk) { throw 'JDK 17 extraction failed.' }
$env:JAVA_HOME = $androidTaskJdk.FullName
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$env:ANDROID_HOME = Join-Path $androidTaskRoot 'sdk'

if ($InstallSdk) {
    $androidTaskSdkManager = Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin\sdkmanager.bat'
    if (-not (Test-Path -LiteralPath $androidTaskSdkManager)) {
        $androidTaskSdkZip = Join-Path $androidTaskDownloads 'commandlinetools-win-15859902_latest.zip'
        Get-VerifiedArchive 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip' $androidTaskSdkZip '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a'
        $androidTaskExtract = Join-Path $androidTaskRoot 'commandline-unpacked'
        Expand-Archive -LiteralPath $androidTaskSdkZip -DestinationPath $androidTaskExtract -Force
        New-Item -ItemType Directory -Force -Path (Split-Path $androidTaskSdkManager -Parent) | Out-Null
        Copy-Item -Path "$androidTaskExtract\cmdline-tools\*" -Destination (Join-Path $env:ANDROID_HOME 'cmdline-tools\latest') -Recurse -Force
    }
    & $androidTaskSdkManager "--sdk_root=$env:ANDROID_HOME" 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0'
    if ($LASTEXITCODE -ne 0) { throw 'SDK installation did not complete. Review SDK licenses with sdkmanager --licenses, then retry.' }
    if (-not (Test-Path -LiteralPath (Join-Path $env:ANDROID_HOME 'platforms\android-36\android.jar'))) {
        throw 'Android SDK platform was not installed. Review sdkmanager --licenses, then retry.'
    }
}
Write-Output "JAVA_HOME=$env:JAVA_HOME"
Write-Output "ANDROID_HOME=$env:ANDROID_HOME"
