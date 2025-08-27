# XLibre Steam Deck Installer

⚡ A modular, community‑driven installer for XLibre on Steam Deck.  
Streamline your display server swap, session override, and binary repo integration with robust error handling and GUI prompts.

> **New in the latest update:** Fully compatible with the OLED Steam Deck. On HDR‑capable models, XLibre is now used automatically **only** for SDR content, preserving HDR rendering paths when available.

---

## 🚀 Project Goals

- Simplify XLibre installation and configuration on Steam Deck (LCD and OLED models)
- Automate session hijacking and display server overrides
- Provide reproducible, maintainable install scripts for the modding community
- Enable binary repo integration and persistent updates
- Build consensus for XLibre as a first‑class alternative during Wayland’s transition

---

## 📦 Features

- ✅ Automated install with GUI prompts for user choices  
- ✅ Robust error handling for missing packages and session conflicts  
- ✅ Binary repo support for XLibre and Gamescope builds
- ✅ Modular script structure for easy community contributions  
- ✅ Uses ChimeraOS Gamescope to run XLibre in Portable and Desktop mode  
- ✅ **OLED‑aware HDR handling** – HDR content uses Wayland/XWayland, SDR content uses XLibre for optimal performance  

---

## 🛠 Requirements

- Steam Deck (SteamOS 3.x or later – LCD or OLED)  
- Root access or sudo privileges  
- Internet connection for repo sync  
- Optional: familiarity with shell scripting and mod workflows  

---

## 📥 Installation

Clone the repo and run the installer:

```bash
git clone https://github.com/HaplessIdiot/xlibresteamdeckinstaller.git
cd xlibresteamdeckinstaller
chmod +x installxlibre.sh
./installxlibre.sh
```

---

## 🎮 Usage

Once installed, the script provides a new **HDR‑aware Gamescope launcher**:

- **On HDR‑capable OLED Decks**  
  - **HDR content** runs in native Gamescope Wayland/XWayland mode, keeping full HDR pipeline support.  
  - **SDR content** automatically launches through a full XLibre X11 session for reduced latency and improved SDR presentation.
- **On LCD Decks (or non‑HDR displays)**  
  - All content will run through XLibre by default.

### Launching HDR‑aware Gamescope manually:
```bash
/usr/local/bin/gamescope-hdr-aware
```

### Boot into HDR‑aware Gamescope automatically:
If you chose “enable on boot” during install, your system will start with HDR‑aware Gamescope each time. You can change this later by:
```bash
systemctl --user disable gamescope-session.target
```
or removing the `.desktop` autostart file in:
```
~/.config/autostart/gamescope-session.desktop
```

You can always revert to the default SteamOS session by switching your SteamOS beta branch or updating the Deck from Desktop Mode.
