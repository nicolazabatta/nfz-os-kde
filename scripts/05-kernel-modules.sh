# Full kernel module sets, like Fedora Kinoite:
#   kernel-modules        most hardware: GPU, Wi-Fi, audio, USB-serial
#   kernel-modules-extra  rarer drivers
# Installed for the *same* version as the image's kernel, never a second kernel
# (a plain `dnf install kernel-modules` could pull a newer kernel alongside).
kver=$(cd /usr/lib/modules && echo *)

dnf -y install --setopt=install_weak_deps=False \
    "kernel-modules-$kver" \
    "kernel-modules-extra-$kver"

# Drivers this image must have; the build fails if any is missing.
#   USB-serial (all architectures): cp210x ch341 ftdi_sio pl2303 cdc_acm
#   Graphics and Wi-Fi (x86_64 only; i915/xe don't exist on aarch64):
#     amdgpu i915 xe nouveau iwlwifi
DRIVERS="cp210x ch341 ftdi_sio pl2303 cdc_acm"
if [ "$(uname -m)" = "x86_64" ]; then
    DRIVERS="$DRIVERS amdgpu i915 xe nouveau iwlwifi"
fi

missing=""
for m in $DRIVERS; do
    modinfo -k "$kver" "$m" >/dev/null 2>&1 || missing="$missing $m"
done
if [ -n "$missing" ]; then
    echo "ERROR: drivers not available:$missing" >&2
    exit 1
fi
echo "Drivers present: $DRIVERS"
dnf clean all
