# Flathub as a system-wide flatpak remote (shipped in /etc, nothing written to /var)
mkdir -p /etc/flatpak/remotes.d
curl -fsSL -o /etc/flatpak/remotes.d/flathub.flatpakrepo \
    https://dl.flathub.org/repo/flathub.flatpakrepo
