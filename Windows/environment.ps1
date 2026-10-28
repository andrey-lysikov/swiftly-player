# The environment for a build: MSVC and Swift.
#
# **Why this is here and not in the system environment.** Swift needs the
# headers and link libraries of MSVC (`INCLUDE`, `LIB`), and only
# `vcvars64.bat` sets them. Skipping it produces a list of missing symbols at
# link time that looks like an error in our own code.
#
# Dot-source it:  . .\environment.ps1

param(
    [string]$SwiftWurzel = $env:SWIFT_ROOT,
    [string]$SwiftFassung = $env:SWIFT_VERSION,
    [string]$BuildTools = $env:VSINSTALLDIR
)

# **Found, not assumed.** Paths and versions differ from machine to machine:
# Build Tools or a full Visual Studio, 2022 or newer, Swift installed for the
# user or for the machine. A fixed path works on one computer and fails
# everywhere else with "vcvars64.bat fehlt". Parameters and the variables above
# still win; the search only fills what is left empty.
if (-not $BuildTools) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $BuildTools = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    }
}
if (-not $SwiftWurzel) {
    $SwiftWurzel = @("$env:LOCALAPPDATA\Programs\Swift", "$env:ProgramFiles\Swift", 'C:\Swift') |
        Where-Object { Test-Path (Join-Path $_ 'Toolchains') } | Select-Object -First 1
}
if (-not $SwiftWurzel) { throw 'Swift fehlt: weder SWIFT_ROOT noch eine Installation unter Programs\Swift' }
# The newest installed toolchain; its folder is called `<version>+Asserts`.
if (-not $SwiftFassung) {
    $SwiftFassung = Get-ChildItem (Join-Path $SwiftWurzel 'Toolchains') -Directory |
        ForEach-Object { $_.Name -replace '\+.*$', '' } |
        Sort-Object { [version]$_ } -Descending | Select-Object -First 1
}

$vcvars = Join-Path $BuildTools 'VC\Auxiliary\Build\vcvars64.bat'
if (-not (Test-Path $vcvars)) { throw "vcvars64.bat fehlt: $vcvars" }

# `cmd` runs the batch script and prints the environment afterwards; the lines
# are read back here. There is no other way to get at the result of a batch
# script.
cmd /c "`"$vcvars`" >nul 2>&1 && set" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        Set-Item -Path "env:$($matches[1])" -Value $matches[2] -ErrorAction SilentlyContinue
    }
}

$toolchain = Join-Path $SwiftWurzel "Toolchains\$SwiftFassung+Asserts\usr\bin"
$laufzeit  = Join-Path $SwiftWurzel "Runtimes\$SwiftFassung\usr\bin"
$sdk       = Join-Path $SwiftWurzel "Platforms\$SwiftFassung\Windows.platform\Developer\SDKs\Windows.sdk"
if (-not (Test-Path $toolchain)) { throw "Swift fehlt: $toolchain" }

$env:SDKROOT = $sdk
$env:Path = "$toolchain;$laufzeit;" + $env:Path
# For `build.ps1` and `Install\package.ps1`: the runtime DLLs that ship with the app.
$env:SWIFTLY_SWIFT_RUNTIME = $laufzeit
