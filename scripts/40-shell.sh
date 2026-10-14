# zsh by default for new users, config under ~/.config/zsh
# (no .zshrc, so the first-login wizard runs)
sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' /etc/default/useradd
echo 'export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"' >> /etc/zshenv
mkdir -p /etc/skel/.config/zsh
