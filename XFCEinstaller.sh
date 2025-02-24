#!/bin/bash

# Fancy Colors
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RED="\e[31m"
BOLD="\e[1m"
RESET="\e[0m"

# Function to print status
function status() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

function success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

function warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

function error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

echo -e "${BOLD}${BLUE}=== XFCE + LightDM Installation Script for Fedora ===${RESET}"

# Step 1: Update Fedora System
status "Updating system packages..."
sudo dnf update -y && sudo dnf upgrade -y
success "System updated successfully!"

# Step 2: Install XFCE Desktop Environment
status "Installing XFCE desktop environment..."
sudo dnf groupinstall -y "Xfce Desktop"
success "XFCE installation complete!"

# Step 3: Install LightDM Display Manager
status "Installing LightDM and dependencies..."
sudo dnf install -y lightdm lightdm-gtk lightdm-gtk-greeter-settings
success "LightDM installed successfully!"

# Step 4: Enable LightDM as the default display manager
status "Setting LightDM as the default display manager..."
sudo systemctl disable gdm
sudo systemctl enable lightdm
success "LightDM is now the default display manager!"

# Step 5: Install XFCE Goodies & Themes
status "Installing additional XFCE themes and enhancements..."
sudo dnf install -y arc-theme papirus-icon-theme xfce4-terminal
success "XFCE customization installed!"

# Step 6: Restart System (Prompt User)
echo -e "${YELLOW}[PROMPT]${RESET} XFCE installation complete. Would you like to restart now? (y/n)"
read -r restart_choice
if [[ $restart_choice == "y" || $restart_choice == "Y" ]]; then
    status "Restarting system..."
    sudo reboot
else
    success "Installation complete! You can reboot manually to start XFCE."
fi
