param(
    [ValidateSet('build','test','check','android-test','live-test','doctor')][string]$Task = 'build',
    [string]$LoginUsername = ''
)
$ErrorActionPreference = 'Stop'
$mobileTaskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$mobileTaskTools = [IO.Path]::GetFullPath((Join-Path $mobileTaskRoot '..\.android-tools'))

function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program exited with code $LASTEXITCODE" }
}

Push-Location -LiteralPath $mobileTaskRoot
try {
    if ($Task -eq 'test') { Invoke-Checked 'flutter' @('test'); return }
    $mobileTaskJdk = Get-ChildItem -LiteralPath $mobileTaskTools -Directory -Filter 'jdk-17*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($mobileTaskJdk) { $env:JAVA_HOME = $mobileTaskJdk.FullName }
    if (Test-Path -LiteralPath (Join-Path $mobileTaskTools 'sdk\platforms\android-36\android.jar')) {
        $env:ANDROID_HOME = Join-Path $mobileTaskTools 'sdk'
        # Flutter also discovers SDKs through adb when an older configured SDK no longer exists.
        $env:PATH = "$(Join-Path $env:ANDROID_HOME 'platform-tools');$env:PATH"
    }
    if (-not $env:JAVA_HOME -or -not (Test-Path -LiteralPath "$env:JAVA_HOME\bin\java.exe")) {
        throw 'Set JAVA_HOME to a compatible JDK (17 recommended), or run prepare-android.ps1.'
    }
    $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
    switch ($Task) {
        'doctor' { Invoke-Checked 'flutter' @('doctor', '-v') }
        'build' {
            Invoke-Checked 'flutter' @('pub', 'get')
            $mobileTaskBuildArgs = @('build', 'apk', '--release', '--no-pub')
            if ($LoginUsername) { $mobileTaskBuildArgs += "--dart-define=BCMUSIC_LOGIN_USERNAME=$LoginUsername" }
            Invoke-Checked 'flutter' $mobileTaskBuildArgs
        }
        'check' {
            Invoke-Checked 'flutter' @('analyze')
            Invoke-Checked 'flutter' @('test')
            $mobileTaskProperties = Join-Path $mobileTaskRoot 'android\local.properties'
            if (Test-Path -LiteralPath $mobileTaskProperties) {
                # Flutter's Windows properties writer escapes backslashes, but Android lint also checks drive colons.
                $mobileTaskPropertiesText = [IO.File]::ReadAllText($mobileTaskProperties)
                $mobileTaskEscaped = $mobileTaskPropertiesText -replace '(?m)^((?:flutter\.sdk|sdk\.dir)=[A-Za-z]):(?=[\\/])', '$1\:'
                if ($mobileTaskEscaped -ne $mobileTaskPropertiesText) {
                    [IO.File]::WriteAllText($mobileTaskProperties, $mobileTaskEscaped)
                }
            }
            Push-Location android
            try { Invoke-Checked '.\gradlew.bat' @(':app:testDebugUnitTest', ':app:lintDebug', '--console=plain') }
            finally { Pop-Location }
        }
        'android-test' {
            Push-Location android
            try { Invoke-Checked '.\gradlew.bat' @(':app:testDebugUnitTest', '--console=plain') }
            finally { Pop-Location }
        }
        'live-test' {
            Push-Location android
            try { Invoke-Checked '.\gradlew.bat' @(':app:testDebugUnitTest','--tests','*LiveSourcesTest','-PliveSources=true','--console=plain') }
            finally { Pop-Location }
        }
    }
} finally { Pop-Location }
