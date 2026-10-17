# NFZ-OS-KDE changelog

Custom bootc image: Fedora 44 minimal base + bare KDE Plasma 6 (Wayland).
Image: `quay.io/<username>/nfz-os-kde:latest-<arch>` (plus a tag per release:
`:<VERSION>-<arch>`, e.g. `:3-x86_64`). Built with `./build.sh`.

Releases are numbered. The number lives in the `VERSION` file and appears in the
GRUB entry ("NFZ Fedora 44 KDE 3") and the image tag. To start a new release:
bump `VERSION`, add a section at the top of this file, and tag the commit in git.

---

## Version 7 — 2026-10-17

### Added
- `scripts/90-var-tmpfiles.sh` (runs last): writes
  `/usr/lib/tmpfiles.d/nfz-var.conf`, a boot-time rule for every folder the
  packages created in `/var` that no existing rule covers (same mode and
  owner), and deletes dnf's `countme` files. bootc copies the image's `/var`
  only on the first install, so without these rules a package added in a later
  version could find its `/var` folders missing on an existing machine
  (bootc lint "var-tmpfiles").
- Bluetooth (`packages/desktop.txt`): `bluez` (the `bluetoothd` service,
  enabled in `scripts/50-services.sh`), `bluedevil` (Plasma's tray icon,
  pairing wizard and System Settings page), `bluez-obexd` (file transfer).
  The adapter, its driver and firmware already worked, and PipeWire's
  Bluetooth audio plugin is part of `pipewire-libs`; only the service and the
  Plasma side were missing (weak deps are off).

### Changed
- `Containerfile` steps 2 and 4 run with a throwaway `/run`
  (`--mount=type=tmpfs,target=/run`), so work folders left there by packages
  (`/run/dnf`, `/run/lvm`, `/run/mdadm`, ...) no longer end up in the image
  (bootc lint "nonempty-run-tmp").

---

## Version 6 — 2026-10-16

### Added
- `xterm` (`packages/system.txt`, PIA group): PIA 3.8's installer requires it
  (its GUI opens commands in xterm). Without it the installer falls back to
  `yum install`, which bootc refuses ("configured to be read-only"), and stops.
- `glibc-langpack-en` (`packages/system.txt`) and
  `system_files/etc/locale.conf` (`LANG=en_US.UTF-8`): the minimal base only
  had `glibc-minimal-langpack` (C/POSIX), so `locale`, Qt and PIA's installer
  warned "Failed to set locale". A machine's own `/etc/locale.conf` keeps
  priority (`/etc` 3-way merge).

---

## Version 5 — 2026-10-16

### Added
- Disk tools (`packages/apps.txt`): `partitionmanager` + `kpmcore` (KDE
  Partition Manager: partitions, usage per partition, SMART view),
  `plasma-disks` (desktop notification when a disk's SMART health goes bad,
  plus a SMART page in Info Center), `filelight` (what's using the space).
- Disks and filesystems (`packages/system.txt`): `udisks2`, `smartmontools`,
  `btrfs-progs`, `ntfs-3g`, `ntfsprogs`, `exfatprogs`, `cryptsetup`, `lvm2`.
  All were missing (weak deps are off): without `udisks2`, Plasma's Device
  Notifier and Krusader can't mount USB sticks or external drives; without
  `smartmontools`, Partition Manager and `plasma-disks` have no SMART data;
  without the filesystem tools, Partition Manager shows those filesystems as
  unsupported.
- `system_files/usr/lib/tmpfiles.d/nfz-usrlocal.conf`: creates
  `/var/usrlocal/bin`, `sbin`, `share` and `share/applications` on new machines.

### Changed
- `/opt` and `/usr/local` are now links to `/var/opt` and `/var/usrlocal`
  (`scripts/25-opt-usrlocal.sh`), like Fedora Kinoite. The minimal base ships
  them as read-only folders inside the image, so PIA's installer (which writes
  to `/opt/piavpn` and `/usr/local/bin`) failed on version 4. The build fails if
  a package ever puts files there (the generated `mimeinfo.cache` index is
  ignored).

### Fixed
- `Containerfile` step 4: a failing script now stops the build
  (`|| exit 1`). Before, the loop ignored every script's failure except the
  last one's, so the first version 5 build was pushed although
  `25-opt-usrlocal.sh` had stopped with an error (and `/opt` was unchanged).

---

## Version 4 — 2026-10-16

### Added
- `iptables-nft`, `iproute`, `libnsl` (`packages/system.txt`): needed by Private
  Internet Access's own app, which is installed per machine from PIA's `.run`
  file. Its installer can't add them itself (no dnf on a bootc system); all
  three were missing on version 3.
- `gh` (GitHub CLI) + `openssh-clients` (`packages/dev.txt`): `gh auth login`
  signs in to GitHub through the browser and sets up git to push without typing
  a token; `openssh-clients` (`ssh`, `ssh-keygen`) was only present as a
  dependency, now listed so git over SSH keeps working.
- `ksshaskpass` (`packages/dev.txt`): KDE dialog for SSH key passphrases, which
  can remember them in KWallet. Without it, anything that isn't a terminal
  (VS Code's Source Control, Claude Code) can't unlock a key
  ("ssh-askpass: No such file or directory").

### Changed
- `build.sh`: the registry login is kept in `AUTH_FILE`
  (`/root/.config/containers/auth.json`), so it survives reboots; a plain
  `sudo podman login` is stored under `/run` and was lost on every reboot.
  The setting `QUAY_USER` is renamed `REGISTRY_USER`.

### Removed
- `kio-gdrive` + `kaccounts-integration-qt6` (commented out in
  `packages/apps.txt` for possible later use): Google's consent screen for KDE
  Online Accounts doesn't offer Drive access, so listing files failed with
  "Requested resource is forbidden".

---

## Version 3 — 2026-10-16

### Added
- `packages/firmware.txt`: the same firmware set as Fedora Kinoite (GPU, Wi-Fi,
  audio, CPU microcode), plus `wireless-regdb` and Mesa (`mesa-dri-drivers`,
  `mesa-vulkan-drivers`). Version 2 on a real x86_64 machine had no Wi-Fi and
  a low screen resolution because this firmware was missing.
- `build.sh`: builds for the current machine's architecture; tags
  `:latest-<arch>` and `:<VERSION>-<arch>`; `--push` to push; `--pull=newer`
  so the base image's kernel matches the repos.

### Changed
- `scripts/05-usb-serial.sh` replaced by `scripts/05-kernel-modules.sh`: always
  installs `kernel-modules` and `kernel-modules-extra` for the image's own kernel
  (like Kinoite); fails the build if USB-serial drivers (and on x86_64
  `amdgpu`, `i915`, `xe`, `nouveau`, `iwlwifi`) are missing.
- Image tags now include the architecture (`:latest-x86_64`, `:3-x86_64`).
  Older aarch64 builds keep their tags `:latest` and `:1` (renamed on
  2026-10-17 to `:latest-aarch64` and `:1-aarch64`; the Parallels VM was
  switched to `:latest-aarch64`).

---

## Version 2 — 2026-10-15

First x86_64 build (`:latest-x86_64`, `:2-x86_64`), built as-is. Booted to the
desktop, but Wi-Fi didn't work and the display stayed at a low resolution
(missing firmware; fixed in version 3). Rolled back to Kinoite.

### Added
- `chrony` (time sync), enabled in `scripts/50-services.sh`. The minimal base had no
  time service, so the clock drifted (e.g. after the VM was suspended) and apt inside
  the ESP-IDF dev container rejected Ubuntu's repository as "not valid yet".
- `CLAUDE.md`: project notes and conventions, read automatically by Claude Code
  (not part of the image).
---

## Version 1 — 2026-10-13

First numbered release. Everything below this section is the history that led to it.

### Changed
- Project folder is now numbered: `nfz-os-kde-1`.
- `VERSION` file (contains `1`) holds the release number.
- GRUB entry is now "NFZ Fedora <release> KDE <VERSION>", e.g. "NFZ Fedora 44 KDE 1"
  (`scripts/20-branding.sh`; also sets `IMAGE_ID` and `IMAGE_VERSION` in os-release).
- `Containerfile` fully commented: what each stage and step does and why.

### Added
- `.gitignore` (ignores `build.log`); the project is now kept in git.
- `kio-gdrive` + `kaccounts-integration-qt6`: Google Drive at `gdrive:/` in Krusader
  and other KDE apps, signed in via System Settings → Online Accounts.
- `system_files/etc/containers/registries.conf.d/50-docker-hub-aliases.conf`:
  maps `espressif/idf` to Docker Hub, so podman doesn't stop to ask which
  registry to use (Espressif's dev container uses the short name).
- `scripts/05-usb-serial.sh`: makes sure the USB-serial drivers `cp210x`, `ch341`,
  `ftdi_sio`, `pl2303` and `cdc_acm` are in the image (installs `kernel-modules`
  for the same kernel version only if needed; the build fails if any is missing).
- `usbutils` (`lsusb`).

---

## 2026-10-12

### Changed
- Split the single Containerfile into a project folder:
  - `packages/*.txt`: package lists (one per line, `#` for comments)
  - `repos/*.repo`: extra package repositories, copied to `/etc/yum.repos.d/`
  - `system_files/`: static files copied onto `/` as-is
  - `scripts/*.sh`: configuration steps, run in number order
- Package installs now cache separately from scripts, so editing a script
  doesn't re-download every package.
- GRUB entry renamed from "MyOS KDE 44" to "NFZ-OS-KDE 44".

### Added
- `repos/vscode.repo`: Microsoft's Visual Studio Code repository.
- `packages/dev.txt`: `code` (Visual Studio Code), `neovim`, `tmux`.
- `git` (required by Oh My Zsh's installer).
- `krename` (batch renamer) and `kdiff3` (diff tool); both are used by Krusader.
- `NetworkManager-openvpn` + `plasma-nm-openvpn` (OpenVPN in Plasma's network
  settings, for Private Internet Access).
- `podman-docker` + `podman-compose` for VS Code Dev Containers;
  `system_files/etc/containers/nodocker` silences podman-docker's notice.
- `kwallet-pam`: unlocks KWallet at login, so apps stop prompting for the wallet password.
- Archiving: `ark` (GUI), and `tar`, `gzip`, `bzip2`, `xz`, `zstd`, `zip`, `unzip`, `7zip`.
- `wireguard-tools` + `jq` (WireGuard for PIA, via PIA's manual-connections scripts).
- Tried and dropped: baking PIA's own app into the image (needed a hand-downloaded
  `.run` installer and a re-implemented install script); VPN stays OpenVPN/WireGuard.

---

## 2026-10-11

### Initial image
- Two-stage build: `fedora-bootc:44` builder runs
  `bootc-base-imagectl build-rootfs --manifest=minimal`, copied into `scratch`.
- Bare Plasma 6 installed with weak dependencies off:
  `plasma-desktop`, `plasma-workspace`, `kwin-wayland`, `kde-settings-plasma`,
  `xdg-desktop-portal-kde`, `kscreen`, `powerdevil`, `breeze-icon-theme`.
- NetworkManager + Wi-Fi + `plasma-nm`; PipeWire + WirePlumber + `plasma-pa`.
- Boot target set to `graphical.target`; `bootc container lint` at the end.

### Changes during the day
- Login manager: SDDM replaced with Plasma Login Manager
  (`plasma-login-manager`, `kcm-plasmalogin`, `plasmalogin.service`).
- File manager: Dolphin replaced with Krusader.
- Fonts: Noto dropped at first, then restored as Plasma's standard set
  (`google-noto-sans`, `-serif`, `-sans-mono`, `-color-emoji`).
- Shell: `zsh` is the default for new users (`/etc/default/useradd`); config lives in
  `~/.config/zsh` (`ZDOTDIR` set in `/etc/zshenv`). No `.zshrc` is shipped, so
  the first-login wizard runs.
- Flatpak: `flatpak`, Flathub added system-wide via
  `/etc/flatpak/remotes.d/flathub.flatpakrepo`, plus `plasma-discover`,
  `plasma-discover-flatpak`, `flatpak-kcm`.
- Apps: `firefox`, `emacs`.
- Container tools: `podman`, `buildah`, `skopeo`, `ostree`.
- Cleanup: package install and cache/log/tmp removal merged into one layer.
- Boot fixes after the first rebase:
  - `plymouth` + `plymouth-system-theme`, initramfs rebuilt with `dracut`,
    and `rhgb quiet` kernel arguments (`/usr/lib/bootc/kargs.d/10-splash.toml`)
    for the graphical LUKS passphrase prompt.
  - `ncurses` added (provides `clear`).
  - `PRETTY_NAME` in `/usr/lib/os-release` changed to rename the GRUB entry.

---

## Not in the image (installed or done per machine)
- Thunderbird, LibreOffice, VLC: install from Flathub.
- Fedora Flatpak remote: `sudo flatpak remote-add --if-not-exists fedora oci+https://registry.fedoraproject.org`
- Existing user's shell: `sudo usermod -s /usr/bin/zsh $USER && mkdir -p ~/.config/zsh`
- Oh My Zsh: installed in `~/.local/share/oh-my-zsh`.
- PIA's own app (needs version 5 for `/opt` and `/usr/local`, the version 4
  packages `iptables-nft`, `iproute`, `libnsl`, and for PIA 3.8+ `xterm`
  (version 6). On version 5, add xterm until the next reboot first:
  `sudo bootc usr-overlay && sudo dnf install -y xterm`):
  1. Check: `readlink /opt /usr/local` prints `var/opt` and `../var/usrlocal`.
  2. Extract the installer: `sh pia-linux-<ver>.run --noexec --target pia-linux-<ver>`.
  3. In that folder: `sed -i -e s,/usr/share,/usr/local/share,g install.sh`
     (`/usr/share` is read-only).
  4. Run `./install.sh` as your normal user (it asks for sudo itself).
  5. Check: `systemctl status piavpn` is active; start Private Internet Access
     from the app menu.
  - Updates: decline PIA's built-in updater (it runs an unpatched installer);
    repeat steps 2–4 with the new `.run`. The uninstaller in `/opt/piavpn/bin`
    needs the same `sed`.
- PIA over OpenVPN: import PIA's `.ovpn` files in System Settings → Wi-Fi & Networking → + → Import VPN connection.
- PIA over WireGuard: generate a config with PIA's `manual-connections` scripts (github.com/pia-foss/manual-connections).
- VS Code Dev Containers: install the Dev Containers extension; set
  `"dev.containers.dockerComposePath": "podman-compose"`; per project use
  `"runArgs": ["--userns=keep-id", "--security-opt", "label=disable"]`.
  If `podman run` fails, add subuids/subgids:
  `sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER`.
- ESP-IDF in a dev container: Espressif's config (**ESP-IDF: Add Docker Container
  Configuration**) with `"runArgs": ["--privileged", "--group-add=keep-groups"]`.
  Serial access: `grep '^dialout:' /usr/lib/group | sudo tee -a /etc/group`, then
  `sudo usermod -aG dialout $USER`; attach the board to the VM in Parallels.
  Full notes: project doc `esp-idf-devcontainer.md`.
- GitHub over SSH, on a brand-new machine or for a new user (needs version 4 for
  `ksshaskpass`; one SSH key per machine, so a lost machine's key can be removed alone):
  1. Git identity: `git config --global user.name "Nicola Zabatta"` and
     `git config --global user.email "nicolazabatta@gmail.com"`.
  2. Create a key: `ssh-keygen -t ed25519 -C "nicolazabatta@gmail.com"` (default
     location; set a passphrase).
  3. Add it on GitHub: copy the line from `cat ~/.ssh/id_ed25519.pub`, then GitHub →
     Settings → SSH and GPG keys → New SSH key (name it after the machine).
  4. Test: `ssh -T git@github.com` (the user is literally `git`); expect
     "Hi nicolazabatta! You've successfully authenticated".
  5. Use SSH for the repo: `git clone git@github.com:nicolazabatta/nfz-os-kde.git`,
     or in an existing HTTPS clone:
     `git remote set-url origin git@github.com:nicolazabatta/nfz-os-kde.git`.
  6. Passphrase dialog for apps without a terminal (VS Code, Claude Code): create
     `~/.config/plasma-workspace/env/askpass.sh` with
     `export SSH_ASKPASS=/usr/bin/ksshaskpass` and `export SSH_ASKPASS_REQUIRE=prefer`.
  7. Unlock the key at login: create `~/.config/autostart/ssh-add.desktop` with
     `[Desktop Entry]`, `Type=Application`, `Name=ssh-add`, `Exec=ssh-add -q`
     (one per line; with no file name, `ssh-add` loads the standard `~/.ssh/id_*` keys).
  8. Log out and back in; in the passphrase dialog tick "Remember password" (stored
     in KWallet). From then on the key unlocks silently at login.
  - Alternative to steps 2–5 over HTTPS: `gh auth login` (GitHub.com → HTTPS →
    authenticate Git: yes → login with a web browser).
- Claude: use the web app at claude.ai (Firefox, or a Chromium-based browser's
  "Install page as app" for its own window). The desktop app's Linux beta is Debian/Ubuntu only.
- Google Drive: nothing in the image for now (KDE's `kio-gdrive` was removed in
  version 4 because Google no longer grants it Drive access). A better option
  is still to be chosen; see Pending.
- `/etc/fstab`: comment out the `/` line (fixes the `systemd-remount-fs` failure on the composefs root).

## Pending / ideas
- `plasma-discover-notifier` for Flatpak update notifications.
- Check whether the `systemd-remount-fs` error predates the in-image `dracut` rebuild.
- dracut logs `ERROR: installing '/root'` during the build (harmless: `/root`
  links to `/var/roothome`, which doesn't exist at build time). Possible fix:
  `mkdir -p /var/roothome` before dracut, `rmdir` after.
- Google Drive: choose a replacement for `kio-gdrive` (removed in version 4).
  One candidate: `rclone` + `fuse3` (`~/GoogleDrive`, user service `rclone-gdrive`).
