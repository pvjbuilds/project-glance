#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app="$project_root/build/ProjectOverview.app"
if [ ! -d "$app" ]; then
    printf '%s\n' 'Glance is not built. Run scripts/build.sh from the project folder first.' >&2
    exit 1
fi
open "$app" --args --show
