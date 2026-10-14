# Rebuild the initramfs so Plymouth (graphical passphrase prompt) is included
kver=$(cd /usr/lib/modules && echo *)
dracut -vf "/usr/lib/modules/${kver}/initramfs.img" "${kver}"
