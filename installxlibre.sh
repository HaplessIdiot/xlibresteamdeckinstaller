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

## Ensure XLibre launcher exists and forces pure X session
install_xlibre_launcher() {
    local XLIBRE_LAUNCHER="/usr/local/bin/xlibre-session-launcher"
    echo "[+] Creating XLibre session launcher..."
    sudo tee "$XLIBRE_LAUNCHER" > /dev/null <<'EOF'
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
        echo "[+] Removing $pkg..."
        sudo pacman -Rns --noconfirm "$pkg"
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
    git
