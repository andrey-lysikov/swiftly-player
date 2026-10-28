# Build rlottie for Windows -- the same library as on Linux, but with MSVC
# instead of g++ and as a static library instead of a DLL.
#
# **No threads, for the same reason as on Linux.** With LOTTIE_THREAD_SUPPORT
# rlottie creates a thread pool that keeps spinning idle forever. For a mark
# of 360 points that plays once at startup, one thread is enough.
#
#     .\Werkzeuge\rlottie-build.ps1 [-Ziel C:\Werkzeuge\rlottie] [-Quelle ...]
#
# `-Ziel` is what `Windows\build.ps1 -Rlottie` expects.
param(
    [string]$Ziel = 'C:\Werkzeuge\rlottie',
    [string]$Quelle = ''
)
$ErrorActionPreference = 'Continue'
# PowerShell names are case-insensitive: `$quelle` and `$ziel` below are these parameters.
if (-not $Quelle) { $Quelle = "$Ziel-quelle" }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Ziel) | Out-Null
$log = "$Ziel.log"
function Sag($t) { "$(Get-Date -Format HH:mm:ss)  $t" | Tee-Object -FilePath $log -Append }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { $env:Path = 'C:\Program Files\Git\cmd;' + $env:Path }

if (-not (Test-Path $quelle)) {
    Sag 'rlottie holen'
    git clone --depth 1 https://github.com/Samsung/rlottie.git $quelle 2>&1 | Out-Null
}

# `RLOTTIE_BUILD` switches the interface from dllimport to dllexport.
# Without it rlottie declares its own functions as imported and rejects
# their definition -- whoever uses the static library later needs the same
# define.
Sag 'config.h schreiben'
@'
#define LOTTIE_IMAGE_MODULE_PLUGIN ""
#define LOTTIE_CACHE
#define LOTTIE_CACHE_SUPPORT
'@ | Set-Content "$quelle\src\vector\config.h" -Encoding ascii

. "$PSScriptRoot\..\Windows\environment.ps1"
Set-Location $quelle
$obj = "$quelle\obj"
Remove-Item -Recurse -Force $obj -EA SilentlyContinue
New-Item -ItemType Directory -Force -Path $obj | Out-Null

$inc = @('inc','src\vector','src\vector\freetype','src\vector\pixman','src\vector\stb','src\lottie','src\binding') |
       ForEach-Object { "/I$quelle\$_" }
$quellen = Get-ChildItem "$quelle\src" -Recurse -Filter *.cpp |
           Where-Object { $_.FullName -notmatch 'wasm' } | ForEach-Object { $_.FullName }
Sag ("$($quellen.Count) Quelldateien")

Push-Location $obj
$ErrorActionPreference = 'Continue'
& cl /nologo /c /std:c++14 /O2 /EHsc /MD /W0 /DNDEBUG /D_CRT_SECURE_NO_WARNINGS /DRLOTTIE_BUILD @inc @quellen 2>&1 |
    Select-Object -Last 3
Sag "Uebersetzt mit $LASTEXITCODE"
$objekte = Get-ChildItem "$obj\*.obj" | ForEach-Object { $_.FullName }
Sag ("$($objekte.Count) Objekte")
New-Item -ItemType Directory -Force -Path "$ziel\lib","$ziel\include" | Out-Null
& lib /nologo /OUT:"$ziel\lib\rlottie.lib" @objekte 2>&1 | Select-Object -Last 2
Sag "Archiv mit $LASTEXITCODE"
Pop-Location
Copy-Item "$quelle\inc\rlottie_capi.h","$quelle\inc\rlottiecommon.h" "$ziel\include" -Force
Sag ('rlottie.lib: ' + (Test-Path "$ziel\lib\rlottie.lib"))
if (-not (Test-Path "$ziel\lib\rlottie.lib")) { throw "rlottie.lib fehlt, siehe $log" }
