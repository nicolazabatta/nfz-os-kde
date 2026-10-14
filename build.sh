#!/usr/bin/env bash
# =============================================================================
#  NFZ-OS-KDE — build.sh
# =============================================================================
#  Builds the image for the architecture of the machine it runs on, and
#  optionally pushes it to the registry.
#
#  Usage (from anywhere; the script always works in its own folder):
#    ./build.sh           build only
#    ./build.sh --push    build, then push both tags
#
#  Tags produced (ARCH = this machine's architecture, e.g. x86_64 or aarch64):
#    <IMAGE>:latest-<ARCH>
#    <IMAGE>:<VERSION>-<ARCH>
#
#  The full build output is saved to build.log (ignored by git).
# =============================================================================
set -euo pipefail

# --- Settings ----------------------------------------------------------------
REGISTRY="quay.io"
USER="quizzical0902"
OSNAME="nfz-kde-os"

# Set your quay user here, or run with: IMAGE=quay.io/<user>/myos-kde ./build.sh
IMAGE="${IMAGE:-$REGISTRY/$USER/$OSNAME}"
LOG_FILE="build.log"

# --- Arguments ----------------------------------------------------------------
case "${1:-}" in
    "")     PUSH=0 ;;
    --push) PUSH=1 ;;
    *)      echo "Usage: $0 [--push]" >&2; exit 2 ;;
esac

# --- Checks -------------------------------------------------------------------
cd "$(dirname "$(readlink -f "$0")")"     # run from the project folder

if [[ "$IMAGE" == *"<"* ]]; then
    echo "ERROR: set your quay user in IMAGE at the top of $0 (or export IMAGE=...)" >&2
    exit 1
fi

[[ -f VERSION && -f Containerfile ]] || {
    echo "ERROR: VERSION or Containerfile not found in $(pwd)" >&2
    exit 1
}

VERSION=$(tr -d '[:space:]' < VERSION)
[[ "$VERSION" =~ ^[0-9]+$ ]] || {
    echo "ERROR: VERSION must be a whole number, got '$VERSION'" >&2
    exit 1
}

ARCH=$(uname -m)
TAG_LATEST="$IMAGE:latest-$ARCH"
TAG_VERSION="$IMAGE:$VERSION-$ARCH"

echo "==> Building $TAG_VERSION (also tagged $TAG_LATEST)"
echo "==> Log: $(pwd)/$LOG_FILE"

# --- Build --------------------------------------------------------------------
# Extra privileges: stage 1 assembles a full root filesystem (see Containerfile).
sudo podman build \
    --cap-add=all \
    --security-opt=label=type:unconfined_t \
    --device=/dev/fuse \
    -t "$TAG_LATEST" \
    -t "$TAG_VERSION" \
    . 2>&1 | tee "$LOG_FILE"

# --- Check the result ---------------------------------------------------------
echo
echo "=== Build summary ==="
grep -E '^==>|USB-serial|PRETTY_NAME' "$LOG_FILE" || true

grep -q "PRETTY_NAME=\"NFZ Fedora .* KDE ${VERSION}\"" "$LOG_FILE" || {
    echo "ERROR: branding line for version $VERSION not found in $LOG_FILE" >&2
    exit 1
}
echo "Build OK: $TAG_VERSION"

# --- Push ---------------------------------------------------------------------
if (( PUSH )); then
    # Log in only if root isn't already logged in to the registry
    sudo podman login --get-login "$REGISTRY" >/dev/null 2>&1 \
        || sudo podman login "$REGISTRY"
    sudo podman push "$TAG_LATEST"
    sudo podman push "$TAG_VERSION"
    echo "Pushed: $TAG_LATEST and $TAG_VERSION"
else
    echo
    echo "Not pushed. To push this build:"
    echo "  sudo podman push $TAG_LATEST"
    echo "  sudo podman push $TAG_VERSION"
fi
