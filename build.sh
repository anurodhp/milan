#!/bin/bash
# Cross-builds Milan.app for the Pi (Darwin arm64) with the iokit repo's
# toolchain; this checkout is built as-is.
#
#   ./build.sh                 build; output lands in iokit's libc_build/gnustep/root
#   ./build.sh deploy          build, then copy Milan.app to the Pi
#
# IOKIT_DIR   the iokit checkout (default ../iokit next to this repo, else .. when this is iokit's third_party/milan)
# DEPLOY_HOST ssh target for "deploy" (default root@10.0.0.142)
# deploy stops Milan first: replacing a running app's files has taken the whole X session down on the Pi.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd -P)"
if [ -z "${IOKIT_DIR:-}" ]; then
    if [ -d "$HERE/../iokit/tools/userland_staging" ]; then IOKIT_DIR="$HERE/../iokit"; else IOKIT_DIR="$HERE/../.."; fi
fi
STAGING="$IOKIT_DIR/tools/userland_staging"
[ -x "$STAGING/build_milan.sh" ] || { echo "error: $STAGING/build_milan.sh not found; set IOKIT_DIR" >&2; exit 1; }

MILAN_SRC="$HERE" "$STAGING/build_milan.sh"

[ "${1:-}" = deploy ] || exit 0
HOST="${DEPLOY_HOST:-root@10.0.0.142}"
GSROOT="$(cd "$STAGING/libc_build/gnustep/root/usr/GNUstep/System" && pwd -P)"
tar -C "$GSROOT/Applications" -cf - Milan.app |
    ssh "$HOST" 'pkill -x Milan; sleep 1; rm -rf /Applications/Milan.app && tar -C /Applications -xf -'
echo "deployed Milan.app to $HOST"
