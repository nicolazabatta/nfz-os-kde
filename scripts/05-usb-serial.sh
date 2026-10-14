# USB-serial drivers for UART programmers/dev boards:
#   cp210x (Silicon Labs CP210x), ch341 (WCH CH340/CH341), ftdi_sio (FTDI),
#   pl2303 (Prolific), cdc_acm (native USB: ESP32-S2/S3/C3/C6, RP2040, ...)
# The minimal base may ship only kernel-modules-core; if a driver is missing,
# install kernel-modules for the *same* kernel version (never a second kernel).
DRIVERS="cp210x ch341 ftdi_sio pl2303 cdc_acm"
kver=$(cd /usr/lib/modules && echo *)

missing() {
    local m out=""
    for m in $DRIVERS; do
        modinfo -k "$kver" "$m" >/dev/null 2>&1 || out="$out $m"
    done
    echo "$out"
}

if [ -n "$(missing)" ]; then
    echo "Missing USB-serial drivers:$(missing), installing kernel-modules-$kver"
    dnf -y install --setopt=install_weak_deps=False "kernel-modules-$kver"
fi
if [ -n "$(missing)" ]; then
    echo "Still missing:$(missing), installing kernel-modules-extra-$kver"
    dnf -y install --setopt=install_weak_deps=False "kernel-modules-extra-$kver"
fi
if [ -n "$(missing)" ]; then
    echo "ERROR: USB-serial drivers not available:$(missing)" >&2
    exit 1
fi
echo "USB-serial drivers present: $DRIVERS"
dnf clean all
