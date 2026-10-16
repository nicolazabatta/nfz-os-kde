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
#    <REGISTRY>/<REGISTRY_USER>/<IMAGE_NAME>:latest-<ARCH>
#    <REGISTRY>/<REGISTRY_USER>/<IMAGE_NAME>:<VERSION>-<ARCH>
#
#  Any setting below can be overridden for one run, e.g.:
#    REGISTRY_USER=someone IMAGE_NAME=test-kde ./build.sh
#
#  The registry login is kept in AUTH_FILE, which survives reboots (a plain
#  `sudo podman login` is stored under /run and is lost on reboot). Log in
#  once per build machine, e.g. with a quay robot account:
#    echo '<token>' | sudo podman login quay.io -u '<user>+builder' \
#        --password-stdin --authfile /root/.config/containers/auth.json
#
#  The full build output is saved to build.log (ignored by git).
# =============================================================================
set -euo pipefail

# --- Settings ----------------------------------------------------------------
REGISTRY="${REGISTRY:-quay.io}"
REGISTRY_USER="${REGISTRY_USER:-quizzical0902}"   # your user/namespace on the registry
IMAGE_NAME="${IMAGE_NAME:-nfz-os-kde}"           # repository name on the registry
AUTH_FILE="${AUTH_FILE:-/root/.config/containers/auth.json}"  # persistent login
LOG_FILE="build.log"

IMAGE="$REGISTRY/$REGISTRY_USER/$IMAGE_NAME"

# --- Arguments ----------------------------------------------------------------
case "${1:-}" in
    "")     PUSH=0 ;;
    --push) PUSH=1 ;;
    *)      echo "Usage: $0 [--push]" >&2; exit 2 ;;
esac

# --- Checks -------------------------------------------------------------------
cd "$(dirname "$(readlink -f "$0")")"     # run from the project folder

if [[ "$REGISTRY_USER" == *"<"* || -z "$REGISTRY_USER" ]]; then
    echo "ERROR: set REGISTRY_USER at the top of $0 (or run: REGISTRY_USER=<name> $0)" >&2
    exit 1
fi

[[ -n "$IMAGE_NAME" ]] || {
    echo "ERROR: IMAGE_NAME is empty" >&2
    exit 1
}

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
# --pull=newer: always start from the current fedora-bootc base, so its kernel
# matches the kernel-modules packages in Fedora's repos.
sudo podman build \
    --pull=newer \
    --cap-add=all \
    --security-opt=label=type:unconfined_t \
    --device=/dev/fuse \
    -t "$TAG_LATEST" \
    -t "$TAG_VERSION" \
    . 2>&1 | tee "$LOG_FILE"

# --- Check the result ---------------------------------------------------------
echo
echo "=== Build summary ==="
grep -E '^==>|Drivers present|PRETTY_NAME' "$LOG_FILE" || true

# 20-branding.sh prints the PRETTY_NAME it set; it must end with this VERSION
grep -q "^PRETTY_NAME=\".* ${VERSION}\"" "$LOG_FILE" || {
    echo "ERROR: PRETTY_NAME for version $VERSION not found in $LOG_FILE" >&2
    exit 1
}
echo "Build OK: $TAG_VERSION"

# --- Push ---------------------------------------------------------------------
if (( PUSH )); then
    # Log in only if AUTH_FILE doesn't already hold a login for the registry
    sudo mkdir -p "$(dirname "$AUTH_FILE")"
    sudo podman login --authfile "$AUTH_FILE" --get-login "$REGISTRY" >/dev/null 2>&1 \
        || sudo podman login --authfile "$AUTH_FILE" "$REGISTRY"
    sudo podman push --authfile "$AUTH_FILE" "$TAG_LATEST"
    sudo podman push --authfile "$AUTH_FILE" "$TAG_VERSION"
    echo "Pushed: $TAG_LATEST and $TAG_VERSION"
else
    echo
    echo "Not pushed. To push this build:"
    echo "  sudo podman push --authfile $AUTH_FILE $TAG_LATEST"
    echo "  sudo podman push --authfile $AUTH_FILE $TAG_VERSION"
fi
