#!/bin/zsh
set -euo pipefail
script_directory=${0:A:h}
project_directory=${script_directory:h}
export CLANG_MODULE_CACHE_PATH="$project_directory/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_directory/.build/ModuleCache"
if ! /usr/bin/swift --version >/dev/null 2>&1 && [[ -x /Library/Developer/CommandLineTools/usr/bin/swift ]]; then
    export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
if [[ "${DEVELOPER_DIR:-}" == /Library/Developer/CommandLineTools && -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
    export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi
testing_plugin_directory="$(xcrun --find swiftc)"
testing_plugin_directory="${testing_plugin_directory:h}/../lib/swift/host/plugins/testing"
plugin_options=()
if [[ -d "$testing_plugin_directory" ]]; then
    plugin_options=(-Xswiftc -plugin-path -Xswiftc "$testing_plugin_directory")
fi
swift test --disable-sandbox --manifest-cache local --disable-xctest \
    --package-path "$project_directory" --jobs 2 "${plugin_options[@]}" "$@"
