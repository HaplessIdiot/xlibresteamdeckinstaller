# XLibre Steam Deck Installer

⚡ A modular, community-driven installer for XLibre on Steam Deck.  
Streamline your display server swap, session override, and binary repo integration with robust error handling and GUI prompts.

---

## 🚀 Project Goals

- Simplify XLibre installation and configuration on Steam Deck
- Automate session hijacking and display server overrides
- Provide reproducible, maintainable install scripts for the modding community
- Enable binary repo integration and persistent updates
- Build consensus for XLibre as a first-class alternative during Wayland's transition

---

## 📦 Features

- ✅ Automated install with GUI prompts for user choices
- ✅ Robust error handling for missing packages and session conflicts
- ✅ Binary repo support for XLibre and Gamescope builds
- ✅ Session override and atomic persistence
- ✅ Modular script structure for easy community contributions
- ✅ Uses ChimeraOS GameScope to use XLibre in Portable and Desktop mode

---

## 🛠 Requirements

- Steam Deck (SteamOS 3.x or later)
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
