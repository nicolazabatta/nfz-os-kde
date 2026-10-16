# =============================================================================
#  NFZ-OS-KDE — Containerfile
# =============================================================================
#
#  What this is
#  ------------
#  The recipe for a bootable, image-based ("immutable") operating system:
#  Fedora's minimal bootc base + a bare KDE Plasma 6 desktop (Wayland).
#  `podman build` turns this recipe into a container image; `bootc` then
#  installs that image as the operating system and keeps it updated.
#
#  Project layout (everything is read relative to this folder)
#  ------------------------------------------------------------
#    VERSION         our release number (1, 2, 3, ...), shown in GRUB
#    repos/*.repo    extra package repositories     -> /etc/yum.repos.d/
#    packages/*.txt  packages to install, one per line, '#' starts a comment
#    system_files/   files copied onto / as-is (system_files/etc/x -> /etc/x)
#    scripts/*.sh    setup steps, run in file-name order (05, 10, 20, ...)
#    CHANGELOG.md    what changed in each release
#
#  How to build, publish and install (run from this folder)
#  --------------------------------------------------------
#    ./build.sh            build for this machine's architecture
#    ./build.sh --push     build and push
#  Tags: quay.io/<user>/nfz-os-kde:latest-<arch> and :<VERSION>-<arch>
#  (<arch> = x86_64 or aarch64). On the machine running the OS:
#    sudo bootc switch quay.io/<user>/nfz-os-kde:latest-<arch>   (first time)
#    sudo bootc upgrade && sudo systemctl reboot               (updates)
#
#  Where changes live on the installed system
#  ------------------------------------------
#    /usr        comes from this image; read-only; replaced on every update
#    /etc        starts from this image; your local edits are kept and merged
#    /var, /home never touched by updates (Flatpaks, containers, your files)
# =============================================================================


# -----------------------------------------------------------------------------
# Fedora release to build on. Change it here (or pass
# `--build-arg FEDORA_VERSION=45` to podman build) to move to a new release.
# The number is picked up automatically for the GRUB menu entry.
# -----------------------------------------------------------------------------
ARG FEDORA_VERSION=44


# =============================================================================
#  STAGE 1 — "builder": produce a minimal root filesystem
# =============================================================================
# Fedora's standard bootc image contains a ready-made tool,
# bootc-base-imagectl, that can assemble a fresh root filesystem from a chosen
# package set ("manifest"). We use the image only as a toolbox: nothing from it
# ends up in our OS except the minimal tree it builds into /target-rootfs.
#
#   --manifest=minimal   kernel, systemd, bootc, ostree, networking basics;
#                        no desktop, no extras (run `bootc-base-imagectl list`
#                        inside the image to see other manifests)
# -----------------------------------------------------------------------------
FROM quay.io/fedora/fedora-bootc:${FEDORA_VERSION} AS builder
RUN /usr/libexec/bootc-base-imagectl build-rootfs --manifest=minimal /target-rootfs


# =============================================================================
#  STAGE 2 — the actual OS image
# =============================================================================
# Start from an empty image ("scratch") and copy in only the minimal tree from
# stage 1. Everything after this line is what becomes NFZ-OS-KDE.
# -----------------------------------------------------------------------------
FROM scratch
COPY --from=builder /target-rootfs/ /


# -----------------------------------------------------------------------------
# Step 1 — Extra package repositories
# -----------------------------------------------------------------------------
# Repositories beyond Fedora's own, e.g. Microsoft's for Visual Studio Code.
# They must be in place *before* step 2 so dnf can find those packages.
# They stay in the image, which is harmless: dnf is only used at build time.
# -----------------------------------------------------------------------------
COPY repos/ /etc/yum.repos.d/


# -----------------------------------------------------------------------------
# Step 2 — Install all packages
# -----------------------------------------------------------------------------
# Every packages/*.txt file is read; `sed` strips '#' comments, `xargs` turns
# the remaining words into one `dnf install` command.
#
#   install_weak_deps=False   install only hard dependencies. Fedora packages
#                             "recommend" many extras; skipping them is what
#                             keeps this a *bare* Plasma desktop. If something
#                             is missing later, add it explicitly to a list.
#
# Cleanup happens in the same RUN so the downloaded package cache never gets
# stored in the image (each RUN creates a layer; deleting later doesn't shrink
# an earlier layer).
#
# Package lists are copied in their own COPY so this slow step is only re-run
# when a package list changes, not when a script or config file does.
# -----------------------------------------------------------------------------
COPY packages/ /tmp/packages/
RUN sed 's/#.*//' /tmp/packages/*.txt \
      | xargs dnf -y install --setopt=install_weak_deps=False \
 && dnf clean all \
 && rm -rf /tmp/packages /var/cache/* /var/log/*


# -----------------------------------------------------------------------------
# Step 3 — Static configuration files
# -----------------------------------------------------------------------------
# Copied onto / unchanged, mirroring their real path:
#   system_files/usr/lib/bootc/kargs.d/10-splash.toml   boot splash arguments
#   system_files/usr/lib/tmpfiles.d/nfz-usrlocal.conf   folders under /var/usrlocal
#   system_files/etc/containers/nodocker                silence podman-docker
#   system_files/etc/containers/registries.conf.d/...   short image names
# Copied after the packages so a package can't overwrite our versions.
# -----------------------------------------------------------------------------
COPY system_files/ /


# -----------------------------------------------------------------------------
# Step 4 — Setup scripts
# -----------------------------------------------------------------------------
# Each scripts/*.sh runs in file-name order with strict error handling
# (`-e` stop on any error, `-u` stop on unset variables, `-o pipefail` stop if
# any part of a pipe fails), so a broken step fails the build instead of
# producing a half-configured OS. The `==> name` line marks each script in the
# build log.
#
#   05-kernel-modules.sh  kernel-modules + -extra for the image's kernel; checks USB-serial (and on x86_64 GPU/Wi-Fi) drivers
#   10-initramfs.sh       rebuild the initramfs with Plymouth (graphical LUKS prompt)
#   20-branding.sh        GRUB name: "NFZ Fedora <release> KDE <VERSION>"
#   25-opt-usrlocal.sh    /opt and /usr/local as links into /var (writable, like Kinoite)
#   30-flatpak.sh         add Flathub as a system-wide Flatpak remote
#   40-shell.sh           zsh as default shell, config in ~/.config/zsh
#   50-services.sh        enable login screen, NetworkManager, chronyd; boot to desktop
#
# VERSION is copied alongside so 20-branding.sh can read our release number.
# Everything in /tmp is deleted afterwards, so none of it remains in the image.
# -----------------------------------------------------------------------------
COPY VERSION /tmp/VERSION
COPY scripts/ /tmp/scripts/
RUN for s in /tmp/scripts/*.sh; do \
        echo "==> ${s##*/}"; \
        bash -euo pipefail "$s"; \
    done \
 && rm -rf /tmp/* /var/cache/* /var/log/*


# -----------------------------------------------------------------------------
# Step 5 — Mark as a bootc image and verify
# -----------------------------------------------------------------------------
# The label tells bootc this container image is a bootable OS.
# `bootc container lint` checks for common mistakes (e.g. content in /var that
# would be ignored on upgrade, missing kernel). It must be the last step so it
# checks the final result; warnings are printed but don't fail the build.
# -----------------------------------------------------------------------------
LABEL containers.bootc=1
RUN bootc container lint
