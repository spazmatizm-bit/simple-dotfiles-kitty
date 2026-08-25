#!/usr/bin/env bash
# ============================================
#  Kitty Config Installer — TUI Version
#  Inspired by sddm-astronaut-theme
#  Author: spazmatizm
#  License: MIT
#  Shell: bash (runs fine in fish too)
# ============================================

set -e

VERSION="1.0.0"

# Colors for fallback (non-TUI output)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --------------------------------------------
# Helper functions
# --------------------------------------------
check_dep() {
    command -v "$1" &> /dev/null
}

detect_package_manager() {
    if check_dep pacman; then
        echo "pacman"
    elif check_dep dnf; then
        echo "dnf"
    elif check_dep zypper; then
        echo "zypper"
    elif check_dep xbps-install; then
        echo "xbps"
    elif check_dep apt-get; then
        echo "apt"
    else
        echo "unknown"
    fi
}

install_packages() {
    local pkgs=("$@")
    local pm=$(detect_package_manager)
    local cmd=""

    case $pm in
        pacman) cmd="sudo pacman -S --needed" ;;
        dnf)    cmd="sudo dnf install" ;;
        zypper) cmd="sudo zypper install" ;;
        xbps)   cmd="sudo xbps-install -S" ;;
        apt)    cmd="sudo apt-get install -y" ;;
        *)
            echo -e "${RED}❌ No supported package manager found. Install dependencies manually.${NC}"
            return 1
            ;;
    esac

    echo -e "${BLUE}📦 Using $pm: ${pkgs[*]}${NC}"
    $cmd "${pkgs[@]}"
}

# --------------------------------------------
# TUI Screens with error handling
# --------------------------------------------
show_welcome() {
    whiptail --title "Kitty Config Installer v$VERSION" \
        --msgbox "Welcome to the Kitty Config Installer!\n\nStyle: SweetWM / Polybar\nFeatures: Transparency, cursor trail, Powerline tabs\nFont: JetBrains Mono Nerd Font\n\nThe installer will check dependencies and let you choose font size." \
        14 60 3>&1 1>&2 2>&3 || return 1
}

check_and_install_deps() {
    local deps_to_install=()
    local all_deps=("kitty" "ttf-jetbrains-mono" "ttf-font-awesome" "ttf-nerd-fonts-symbols" "libnewt")

    echo -e "${BLUE}🔍 Checking dependencies...${NC}"

    for dep in "${all_deps[@]}"; do
        if ! check_dep "$dep" && ! pacman -Q "$dep" &> /dev/null 2>&1; then
            deps_to_install+=("$dep")
        fi
    done

    if [ ${#deps_to_install[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ All dependencies are already installed.${NC}"
        return 0
    fi

    local dep_list=$(printf "  • %s\n" "${deps_to_install[@]}")
    echo -e "${YELLOW}⚠️ Missing dependencies:${NC}\n$dep_list"

    if whiptail --title "Dependencies" --yesno "The following packages are missing:\n\n$dep_list\n\nInstall them now?" 14 60 3>&1 1>&2 2>&3; then
        install_packages "${deps_to_install[@]}"
    else
        echo -e "${RED}❌ Installation aborted.${NC}"
        exit 1
    fi
}

choose_font_size() {
    local size
    size=$(whiptail --title "Font Size" \
        --menu "Choose your Kitty font size:" 16 50 7 \
        "9.0" "Very small" \
        "9.5" "Small (recommended)" \
        "10.0" "Medium" \
        "10.5" "Large" \
        "11.0" "Larger" \
        "12.0" "Very large" \
        "13.0" "Huge" \
        3>&1 1>&2 2>&3)

    # Если пользователь нажал Cancel — возвращаем 9.5 по умолчанию
    if [ -z "$size" ] || [ $? -ne 0 ]; then
        echo "9.5"
    else
        echo "$size"
    fi
}

show_summary() {
    local font_size="$1"
    local backup_dir="$2"

    whiptail --title "Installation Complete" \
        --msgbox "✅ Kitty config has been installed!\n\n📏 Font size: $font_size\n📂 Backup saved to: $backup_dir\n\nRestart Kitty to apply changes." \
        12 60 3>&1 1>&2 2>&3 || true
}

# --------------------------------------------
# Main installation logic
# --------------------------------------------
main() {
    # Check for whiptail
    if ! check_dep whiptail; then
        echo -e "${RED}❌ whiptail not found. Install it: sudo pacman -S libnewt${NC}"
        echo -e "${YELLOW}💡 If you're using fish, run: sudo pacman -S libnewt${NC}"
        exit 1
    fi

    # Detect shell and show info
    local shell_name=$(basename "$SHELL")
    echo -e "${BLUE}🐚 Detected shell: $shell_name${NC}"

    # Step 1: Welcome screen
    show_welcome || {
        echo -e "${RED}❌ Installation cancelled.${NC}"
        exit 1
    }

    # Step 2: Check dependencies
    check_and_install_deps

    # Step 3: Choose font size
    FONT_SIZE=$(choose_font_size)
    echo -e "${BLUE}📏 Selected font size: $FONT_SIZE${NC}"

    # Step 4: Install config
    KITTY_CONFIG_DIR="$HOME/.config/kitty"
    BACKUP_DIR="$HOME/.config/kitty.bak.$(date +%Y%m%d_%H%M%S)"

    if [ -d "$KITTY_CONFIG_DIR" ]; then
        echo -e "${BLUE}📦 Creating backup: $BACKUP_DIR${NC}"
        mv "$KITTY_CONFIG_DIR" "$BACKUP_DIR"
    fi

    mkdir -p "$KITTY_CONFIG_DIR"
    cp "$(dirname "$0")/config/kitty/kitty.conf" "$KITTY_CONFIG_DIR/kitty.conf"
    sed -i "s/^font_size .*/font_size $FONT_SIZE/" "$KITTY_CONFIG_DIR/kitty.conf"

    echo -e "${GREEN}✅ Config installed with font size $FONT_SIZE${NC}"
    echo -e "${GREEN}📂 Backup: $BACKUP_DIR${NC}"

    # Step 5: Show summary and offer restart
    show_summary "$FONT_SIZE" "$BACKUP_DIR"

    if whiptail --title "Restart Kitty?" --yesno "Would you like to restart Kitty now?" 8 40 3>&1 1>&2 2>&3; then
        echo -e "${BLUE}🔄 Restarting Kitty...${NC}"
        pkill kitty 2>/dev/null || true
        kitty &
        echo -e "${GREEN}✅ Kitty restarted. Enjoy! 🚀${NC}"
    else
        echo -e "${BLUE}🔁 Restart Kitty later to apply changes.${NC}"
    fi
}

# --------------------------------------------
# Run
# --------------------------------------------
main "$@"
