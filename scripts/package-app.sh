#!/bin/zsh
set -euo pipefail

script_directory=${0:A:h}
project_directory=${script_directory:h}
release_directory="$project_directory/.build/release-apps"
distribution_directory="$project_directory/dist"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_directory/Support/Info.plist")
architecture=$(uname -m)
image_path="$distribution_directory/QuietLens-$version-$architecture.dmg"

APP_OUTPUT_DIRECTORY="$release_directory" "$script_directory/build-app.sh" release
codesign --verify --deep --strict "$release_directory/QuietLens.app"
mkdir -p "$distribution_directory"
staging_directory=$(mktemp -d "$project_directory/.build/dmg-staging.XXXXXX")
trap 'rm -rf "$staging_directory"' EXIT
ditto "$release_directory/QuietLens.app" "$staging_directory/QuietLens.app"
ln -s /Applications "$staging_directory/Applications"
hdiutil create -volname QuietLens -srcfolder "$staging_directory" -format UDZO -ov "$image_path"
hdiutil verify "$image_path"
shasum -a 256 "$image_path" > "$image_path.sha256"
print -r -- "Installer: $image_path"
