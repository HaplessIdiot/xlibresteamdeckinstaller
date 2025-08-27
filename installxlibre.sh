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
sudo pacman-key --recv-keys 73580DE2EDDFA6D6
sudo pacman-key --finger 73580DE2EDDFA6D6
sudo pacman-key --lsign-key 73580DE2EDDFA6D6

echo "[+] Updating /etc/pacman.conf with xlibre repo..."

# If the [xlibre] section doesn't exist, append it
if ! grep -Eq '^[[:space:]]*

\[xlibre\]

' /etc/pacman.conf; then
    {
        echo ""
        echo "[xlibre]"
        echo "Server = https://github.com/X11Libre/binpkg-arch-based/raw/refs/heads/main/"
        echo "SigLevel = Optional TrustAll"
    } | sudo tee -a /etc/pacman.conf >/dev/null
fi

echo "[+] Syncing pacman databases..."
sudo pacman -Sy

echo "[-] Removing old Xorg packages..."
XORG_PKGS=(
    xorg-server
    xorg-server-common
    xorg-apps
    xorg-xinit
    xorg-xinput
    xorg-xev
    xorg-xhost
)

for pkg in "${XORG_PKGS[@]}"; do
    if ! pacman -Qq "$pkg" &>/dev/null; then
        echo "[i] Package not found: $pkg"
        continue
    fi

    # Look for reverse deps — omit the package itself from the results
    REQS=$(pactree -r "$pkg" 2>/dev/null | tail -n +2 | awk '{print $1}' | sort -u)

    if [[ -n "$REQS" ]]; then
        echo "[i] Skipping $pkg — required by: $REQS"
        continue
    fi

    echo "[+] Removing $pkg..."
    sudo pacman -Rns --noconfirm --nodeps "$pkg" || \
        echo "[!] Failed to remove $pkg, continuing..."
done

echo "[+] Installing XLibre packages..."
sudo pacman -S --noconfirm xlibre-xserver xlibre-xserver-common xlibre-xserver-devel xlibre-xf86-input-libinput xlibre-xf86-video-amdgpu

echo "[+] Installing gamescope-session-git from AUR..."
cd
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
