# /opt and /usr/local point into /var (writable, kept across upgrades), like
# Fedora Kinoite, so per-machine installs (e.g. PIA's .run installer, which
# writes to /opt/piavpn and /usr/local/bin) work. The minimal base ships them
# as read-only folders in the image instead.
# Refuse if a package has put real content there (it would be lost).
[ -z "$(ls -A /opt)" ] || { echo "ERROR: /opt is not empty" >&2; exit 1; }
[ -z "$(find /usr/local -mindepth 1 -not -type d)" ] || {
    echo "ERROR: /usr/local contains files" >&2
    exit 1
}
rm -rf /opt /usr/local
ln -s var/opt /opt
ln -s ../var/usrlocal /usr/local
echo "/opt -> $(readlink /opt), /usr/local -> $(readlink /usr/local)"
