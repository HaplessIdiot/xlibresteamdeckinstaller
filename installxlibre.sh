#!/usr/bin/env bash
set -e

# --- Ask GUI question for Gamescope session ---
ask_enable_boot() {
    if command -v zenity >/dev/null 2>&1; then
        zenity --question \
            --title="Enable Gamescope Session" \
            --text="Do you want to enable Gamescope session on boot?"
        return $?  # 0 = Yes, 1 = No
    elif command -v kdialog >/dev/null 2>&1; then
        kdialog --yesno "Do you want to enable Gamescope session on boot?"
        return $?
    else
        read -p "[?] Enable Gamescope session on boot? (y/N): " ans
        [[ "$ans" =~ ^[Yy]$ ]]
        return $?
    fi
}
sudo steamos-readonly disable
echo "[+] Adding XLibre binary repo to pacman..."
sudo pacman-key --recv-keys 73580DE2EDDFA6D6
sudo pacman-key --finger 73580DE2EDDFA6D6
sudo pacman-key --lsign-key 73580DE2EDDFA6D6

echo "[+] Updating /etc/pacman.conf with xlibre repo..."
if ! grep -q "^

\[xlibre\]

" /etc/pacman.conf; then
    echo -e "\n[xlibre]\nServer = https://github.com/X11Libre/binpkg-arch-based/raw/refs/heads/main/" \
        | sudo tee -a /etc/pacman.conf
fi

echo "[+] Syncing pacman databases..."
sudo pacman -Sy

echo "[-] Removing old Xorg packages..."
XORG_PKGS=(
    xorg-server
    xorg-server-common
    xorg-apps
    xorg-xinit
    xorg-xrandr
    xorg-xinput
    xorg-xset
    xorg-xprop
    xorg-xev
    xorg-xhost
)

for pkg in "${XORG_PKGS[@]}"; do
    if pacman -Qq "$pkg" &>/dev/null; then
        if sudo pacman -Rns --print "$pkg" &>/dev/null; then
            echo "[+] Removing $pkg..."
            sudo pacman -Rns --noconfirm "$pkg"
        else
            echo "[i] $pkg is listed but has no removable files (already gone)"
        fi
    else
        echo "[i] Package not found: $pkg"
    fi
done

echo "[+] Installing XLibre packages..."
sudo pacman -S --noconfirm xlibre-xserver xlibre-xserver-common xlibre-xserver-devel xlibre-xf86-input-libinput xlibre-xf86-video-amdgpu

echo "[+] Installing gamescope-session-git from AUR..."
cd ~
if [ -d gamescope-session-git ]; then
    echo "[i] gamescope-session-git directory already exists."
    read -p "[?] Rebuild from scratch? (y/N): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        rm -rf gamescope-session-git
        git clone https://aur.archlinux.org/gamescope-session-git.git
        cd gamescope-session-git
    else
        cd gamescope-session-git
        git pull --ff-only
    fi
else
    git clone https://aur.archlinux.org/gamescope-session-git.git
    cd gamescope-session-git
fi

makepkg -si --noconfirm --needed

echo "[+] Creating XLibre .desktop entry..."
mkdir -p ~/.local/share/gamescope-session
cat <<EOF > ~/.local/share/gamescope-session/xlibre.desktop
[Desktop Entry]
Name=XLibre
Exec=/usr/bin/X
Type=Application
EOF

echo "[+] Setting XLibre as default Gamescope session..."
mkdir -p ~/.config/gamescope-session
echo "xlibre.desktop" > ~/.config/gamescope-session/session

if ask_enable_boot; then
    if ! systemctl --user enable gamescope-session.target 2>&1 | grep -q "no installation config"; then
        echo "[✓] Gamescope session will start on boot via systemd."
    else
        echo "[i] gamescope-session.target has no [Install] section — creating autostart entry..."
        mkdir -p ~/.config/autostart
        cat <<EOF > ~/.config/autostart/gamescope-session.desktop
[Desktop Entry]
Type=Application
Name=Gamescope Session
Exec=systemctl --user start gamescope-session.target
X-GNOME-Autostart-enabled=true
EOF
        echo "[✓] Autostart entry created at ~/.config/autostart/gamescope-session.desktop"
    fi
else
    echo "[i] You can manually start it with: systemctl --user start gamescope-session.target"
fi
echo "[✓] Thanks for installing XLibre!"
