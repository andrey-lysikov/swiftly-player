#!/bin/bash
# Fetches the VLCKit XCFramework into Vendor/. Not in git, because it is 2 GB.
#
# Version 4.0.0-a23. Only available from VideoLAN (the GitHub mirror ends at
# a21), and VideoLAN throttles to ~40 KB/s per connection. A single download
# would take hours, so fetching in parallel pieces is advisable.
set -euo pipefail
cd "$(dirname "$0")/.."
# **WARNING: this version has a known bug.**
#
# VLC 4 discards the index of MKV files over HTTP in
# `matroska_segment_seeker.cpp` -- seeks then read from the start of the file
# and take 30 to 90 seconds. VLC 3 does not have that restriction.
#
# The patch is in `Werkzeuge/vlckit-patches/`. Building the app with working
# seeking needs a patched VLCKit -- this script fetches the **unpatched**
# official version.
#
# See the README, section "Building".

URL="https://download.videolan.org/cocoapods/unstable/VLCKit-4.0-20260805-1123.zip"
SHA="c0c3ae1665053db5898581efc8ee920f526643526297f7fc643599532dc2ccf5"

# **The archive can be kept outside the checkout** (`VLCKIT_ZIP`), so a CI cache
# or a second clone does not download 861 MB again. It is checked either way.
ZIP="${VLCKIT_ZIP:-${TMPDIR:-/tmp}/vlckit.zip}"

if [ ! -d Vendor/VLCKit.xcframework ]; then
    mkdir -p Vendor "$(dirname "$ZIP")"
    if [ ! -f "$ZIP" ] || ! echo "$SHA  $ZIP" | shasum -a 256 -c - >/dev/null 2>&1; then
        echo "Lade VLCKit (861 MB)…"
        curl -fsSL --retry 5 -o "$ZIP" "$URL"
    fi
    echo "Pruefsumme…"
    ACTUAL=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
    [ "$ACTUAL" = "$SHA" ] || { echo "PRUEFSUMME FALSCH: $ACTUAL"; exit 1; }
    unpacked=$(mktemp -d)
    unzip -q -o "$ZIP" -d "$unpacked"
    mv "$unpacked/VLCKit.xcframework" Vendor/
    rm -rf "$unpacked"
    [ -n "${VLCKIT_ZIP:-}" ] || rm -f "$ZIP"
    echo "Fertig: Vendor/VLCKit.xcframework"
else
    echo "Schon da: Vendor/VLCKit.xcframework"
fi

# **`project.yml` links the patched build.** Without it the official one stands
# in under the same name, so a fresh checkout builds and runs in Xcode, only
# with the slow MKV seeking described above. A real patched build is never
# replaced.
if [ ! -e Vendor/VLCKit-gepatcht.xcframework ]; then
    ln -s VLCKit.xcframework Vendor/VLCKit-gepatcht.xcframework
    echo "Vendor/VLCKit-gepatcht.xcframework -> VLCKit.xcframework (ungepatcht)"
fi
