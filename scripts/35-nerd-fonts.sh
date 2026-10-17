# Nerd Fonts: coding fonts with extra icons (for kitty, zsh themes such as
# Powerlevel10k, editors). Not packaged by Fedora, so downloaded from the
# official releases at github.com/ryanoasis/nerd-fonts.
# Installed in /usr/share/fonts/nerd-fonts/<Family>, so every app's font
# picker lists them; they are not made the default font.
# The checksums are pinned here, so a changed or broken download fails the
# build. To update: change NF_VERSION and both checksums (from that
# release's SHA-256.txt).
NF_VERSION=v3.5.1
declare -A NF_SHA256=(
    [JetBrainsMono]=04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf
    [Meslo]=6b6624632dc6873dfb7681c3f818e7c01ab601ab707690b6440933bbe57e2b11
)
FONT_DIR=/usr/share/fonts/nerd-fonts

tmp=$(mktemp -d)
for family in $(printf '%s\n' "${!NF_SHA256[@]}" | sort); do
    archive="$tmp/$family.tar.xz"
    curl -fsSL -o "$archive" \
        "https://github.com/ryanoasis/nerd-fonts/releases/download/$NF_VERSION/$family.tar.xz"
    echo "${NF_SHA256[$family]}  $archive" | sha256sum -c --quiet -
    mkdir -p "$FONT_DIR/$family"
    # fonts + license file (named differently per family); skip the readme
    tar -xJf "$archive" -C "$FONT_DIR/$family" --no-same-owner \
        --exclude='README.md'
done
rm -rf "$tmp"
find "$FONT_DIR" -type d -exec chmod 755 {} +
find "$FONT_DIR" -type f -exec chmod 644 {} +

fc-cache -f "$FONT_DIR"
echo "Nerd Fonts $NF_VERSION: $(find "$FONT_DIR" -name '*.ttf' | wc -l) font files"
