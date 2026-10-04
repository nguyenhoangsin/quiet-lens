#!/bin/zsh
set -euo pipefail
script_directory=${0:A:h}
project_directory=${script_directory:h}
app_directory="$project_directory/.build/apps/QuietLens.app"
if [[ ! -d "$app_directory" ]]; then
    "$script_directory/build-app.sh" debug
fi
open "$app_directory"
