# Name shown in the GRUB menu (and in "About this System"):
#   "NFZ Fedora <Fedora release> KDE <our VERSION>"   e.g. "NFZ Fedora 44 KDE 1"
# GRUB builds each menu entry from PRETTY_NAME in /usr/lib/os-release, and adds
# "(ostree:0)" / "(ostree:1)" for the current and rollback deployments.
# NAME, ID and VERSION_ID are left untouched, so dnf, Flatpak and other tools
# still recognise the system as Fedora.
. /usr/lib/os-release                     # provides VERSION_ID (e.g. 44)
NFZ_VERSION=$(tr -d '[:space:]' < /tmp/VERSION)
test -n "$NFZ_VERSION" || { echo "VERSION file is empty" >&2; exit 1; }

sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"NFZ Fedora ${VERSION_ID} KDE ${NFZ_VERSION}\"|" /usr/lib/os-release

# Standard os-release fields for image-based systems
grep -q '^IMAGE_ID=' /usr/lib/os-release \
    && sed -i 's|^IMAGE_ID=.*|IMAGE_ID="nfz-os-kde"|' /usr/lib/os-release \
    || echo 'IMAGE_ID="nfz-os-kde"' >> /usr/lib/os-release
grep -q '^IMAGE_VERSION=' /usr/lib/os-release \
    && sed -i "s|^IMAGE_VERSION=.*|IMAGE_VERSION=\"${NFZ_VERSION}\"|" /usr/lib/os-release \
    || echo "IMAGE_VERSION=\"${NFZ_VERSION}\"" >> /usr/lib/os-release

grep -E '^(PRETTY_NAME|IMAGE_ID|IMAGE_VERSION)=' /usr/lib/os-release
