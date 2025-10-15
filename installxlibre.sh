#!/usr/bin/env bash
set -e

# --- Ensure XLibre launcher exists and forces pure X session ---
install_xlibre_launcher() {
    local XLIBRE_LAUNCHER="/usr/local/bin/xlibre-session-launcher"
    echo "[+] Creating XLibre session launcher..."
    sudo tee "$XLIBRE_LAUNCHER" > /dev/null <<EOF
#!/bin/bash
# Force-launch a full XLibre X server session without XWayland

# Environment to force X11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
unset WAYLAND_DISPLAY

# Start XLibre X server
exec /usr/bin/X -nolisten tcp vt1
EOF
    sudo chmod +x "$XLIBRE_LAUNCHER"
    if [ -x "$XLIBRE_LAUNCHER" ]; then
        echo "[✓] XLibre launcher ready at $XLIBRE_LAUNCHER"
    else
        echo "[!] Failed to create $XLIBRE_LAUNCHER" >&2
        exit 1
    fi
}

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

## HDR PATCH: Function to create HDR-aware launcher
create_hdr_launcher() {
    local LAUNCHER_PATH="/usr/local/bin/gamescope-hdr-aware"
    sudo tee "$LAUNCHER_PATH" > /dev/null <<'EOF'
#!/bin/bash
HDR_ENABLED=$(cat /sys/class/drm/card0-HDMI-A-1/status 2>/dev/null | grep -q "connected" && echo "yes" || echo "no")

if [ "$HDR_ENABLED" = "yes" ]; then
    echo "Launching Gamescope in HDR mode (Wayland/XWayland)..."
    exec gamescope --hdr --xwayland-session
else
    echo "Launching Gamescope in SDR mode (XLibre)..."
    exec /usr/local/bin/xlibre-session-launcher
fi
EOF
    sudo chmod +x "$LAUNCHER_PATH"
    echo "[✓] HDR-aware Gamescope launcher created at $LAUNCHER_PATH"
}


sudo steamos-readonly disable

echo "[+] Adding XLibre binary repo to pacman..."
sudo pacman-key --init
sudo pacman-key --recv-keys 73580DE2EDDFA6D6
sudo pacman-key --finger 73580DE2EDDFA6D6
sudo pacman-key --lsign-key 73580DE2EDDFA6D6
sudo pacman-key --recv-keys AF1D2199EF0A3CCF
sudo pacman-key --export AF1D2199EF0A3CCF > steamos-ci.pub
sudo pacman-key --add steamos-ci.pub
sudo pacman-key --lsign-key AF1D2199EF0A3CCF
sudo pacman-key --populate archlinux
sudo pacman-key --lsign-key AF1D2199EF0A3CCF
sudo pacman -Syy archlinux-keyring

echo "[+] Updating /etc/pacman.conf with xlibre repo..."

ARCH=$(uname -m)   # usually x86_64 on Steam Deck

if curl -sI "https://x11libre.net/repo/arch_based/${ARCH}/xlibre.db" | grep -q "200 OK"; then
    {
        echo ""
        echo "[xlibre]"
        echo "Server = https://x11libre.net/repo/arch_based/\$arch"
        echo "SigLevel = Optional TrustAll"
    } | sudo tee -a /etc/pacman.conf >/dev/null
    echo "[✓] XLibre repo added for $ARCH"
else
    echo "[!] No valid XLibre pacman repo found — falling back to source build."
fi

echo "[+] Syncing pacman databases..."
sudo pacman -Sy
echo "[+] Removing Xorg..."
sudo pacman -Rdd xorg-server xorg-server-common xf86-input-libinput xf86-video-amdgpu
# Install XLibre first, replacing Xorg in-place with --overwrite
echo "[+] Installing XLibre packages with overwrite (in-place replace)..."

sudo pacman -S --noconfirm \
  --overwrite "usr/bin/X" \
  --overwrite "usr/bin/Xorg" \
  --overwrite "usr/lib/Xorg" \
  --overwrite "usr/lib/xorg/*" \
  --overwrite "usr/include/xorg/*" \
  --overwrite "usr/lib/pkgconfig/xorg-server.pc" \
  --overwrite "usr/share/X11/*" \
  --overwrite "usr/share/man/man1/Xorg.1*" \
  xlibre-xserver xlibre-xserver-common xlibre-xserver-devel \
  xlibre-xf86-input-libinput xlibre-xf86-video-amdgpu

echo "[+] Installing build dependencies for AUR packages..."
sudo pacman -S --needed base-devel fakeroot debugedit git

echo "[+] Preparing kwin-x11-lite build..."
cd ~
if [ -d kwin-x11-lite ]; then
    echo "[i] kwin-x11-lite directory already exists."
    read -p "[?] Rebuild from scratch? (y/N): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        rm -rf kwin-x11-lite
        git clone https://aur.archlinux.org/kwin-x11-lite.git
    fi
else
    git clone https://aur.archlinux.org/kwin-x11-lite.git
fi

cd kwin-x11-lite

# Backup PKGBUILD only if not already backed up
[ ! -f PKGBUILD.orig ] && cp PKGBUILD PKGBUILD.orig

sed -i \
  -e 's/aurorae//g' \
  -e 's/plasma-x11-session//g' \
  -e 's/libplasma=6\.[0-9]\+\(\.[0-9]\+\)\?/libplasma/g' \
  -e 's/libplasma>=6\.[0-9]\+\(\.[0-9]\+\)\?/libplasma/g' \
  PKGBUILD

# Clean up whitespace
sed -i 's/  / /g' PKGBUILD

# Regenerate .SRCINFO so makepkg sees patched deps
makepkg --printsrcinfo > .SRCINFO

echo "[✓] PKGBUILD patched — proceeding with build..."
makepkg -si --noconfirm --needed || {
    echo "[!] kwin-x11-lite build failed — continuing without it."
}
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

# Install the pure-X launcher before HDR-aware wrapper
install_xlibre_launcher

# Create HDR-aware launcher after XLibre launcher exists
create_hdr_launcher

if ask_enable_boot; then
    if ! systemctl --user enable gamescope-session.target 2>&1 | grep -q "no installation config"; then
        echo "[✓] Gamescope session will start on boot via systemd."
    else
        echo "[i] gamescope-session.target has no [Install] section — creating autostart entry..."
        mkdir -p ~/.config/autostart
        cat <<EOF > ~/.config/autostart/gamescope-session.desktop
[Desktop Entry]
Type=Application
Name=Gamescope Session (HDR-Aware)
Exec=/usr/local/bin/gamescope-hdr-aware
X-GNOME-Autostart-enabled=true
EOF
        echo "[✓] Autostart entry created at ~/.config/autostart/gamescope-session.desktop"
    fi
else
    echo "[i] You can manually start it with: /usr/local/bin/gamescope-hdr-aware"
fi

echo "[✓] Thanks for installing XLibre with HDR-aware fallback!"
