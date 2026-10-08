#!/bin/bash
# Cross-builds Milan.app for the Pi (Darwin arm64) with the iokit repo's
# toolchain; this checkout is built as-is.
#
#   ./build.sh                 build; output lands in iokit's libc_build/gnustep/root
#   ./build.sh deploy          build, then copy Milan.app to the Pi
#
# IOKIT_DIR   the iokit checkout (default ..)
# DEPLOY_HOST ssh target for "deploy" (default root@10.0.0.142)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd -P)"
IOKIT_DIR="${IOKIT_DIR:-$HERE/..}"
STAGING="$IOKIT_DIR/tools/userland_staging"
[ -x "$STAGING/build_milan.sh" ] || { echo "error: $STAGING/build_milan.sh not found; set IOKIT_DIR" >&2; exit 1; }

MILAN_SRC="$HERE" "$STAGING/build_milan.sh"

[ "${1:-}" = deploy ] || exit 0
HOST="${DEPLOY_HOST:-root@10.0.0.142}"
GSROOT="$(cd "$STAGING/libc_build/gnustep/root/usr/GNUstep/System" && pwd -P)"
tar -C "$GSROOT/Applications" -cf - Milan.app |
    ssh "$HOST" 'rm -rf /Applications/Milan.app && tar -C /Applications -xf -'
echo "deployed Milan.app to $HOST"
