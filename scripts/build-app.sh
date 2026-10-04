#!/bin/zsh
set -euo pipefail

script_directory=${0:A:h}
project_directory=${script_directory:h}
configuration=${1:-debug}
app_directory="${APP_OUTPUT_DIRECTORY:-$project_directory/.build/apps}/QuietLens.app"
contents_directory="$app_directory/Contents"
signing_identity=${CODESIGN_IDENTITY:--}
export CLANG_MODULE_CACHE_PATH="$project_directory/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_directory/.build/ModuleCache"

# A working CLT installation can build the app even if Xcode setup is pending.
if ! /usr/bin/swift --version >/dev/null 2>&1 && [[ -x /Library/Developer/CommandLineTools/usr/bin/swift ]]; then
    export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
if [[ "${DEVELOPER_DIR:-}" == /Library/Developer/CommandLineTools && -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
    export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi

swift build --disable-sandbox --manifest-cache local --package-path "$project_directory" --configuration "$configuration" --jobs 2 --product QuietLens
binary_directory=$(swift build --disable-sandbox --manifest-cache local --package-path "$project_directory" --configuration "$configuration" --show-bin-path)
mkdir -p "$contents_directory/MacOS" "$contents_directory/Resources"
cp "$binary_directory/QuietLens" "$contents_directory/MacOS/QuietLens"
cp "$project_directory/Support/Info.plist" "$contents_directory/Info.plist"
cp "$project_directory/Support/AppIcon.icns" "$contents_directory/Resources/AppIcon.icns"
for resource_bundle in "$binary_directory"/QuietLens_QuietLens.bundle(N); do
    # Support both SwiftPM resource lookup layouts (native and swiftbuild).
    rm -rf "$contents_directory/MacOS/${resource_bundle:t}"
    cp -R "$resource_bundle" "$contents_directory/MacOS/"
    rm -rf "$contents_directory/Resources/${resource_bundle:t}"
    cp -R "$resource_bundle" "$contents_directory/Resources/"
    codesign --force --sign "$signing_identity" "$contents_directory/MacOS/${resource_bundle:t}"
    codesign --force --sign "$signing_identity" "$contents_directory/Resources/${resource_bundle:t}"
done
codesign --force --sign "$signing_identity" --identifier com.sinnguyen.QuietLens "$app_directory"
if [[ "$signing_identity" == "-" ]]; then
    print -u2 -r -- "Ad-hoc signing: after rebuilding, macOS may require Screen Recording permission again."
fi
print -r -- "Built: $app_directory"
