#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -eEo pipefail

# Define Omari locations
export SCRIPT_PATH="$HOME/wpa_supplicant-to-iwd"

# Install
source "$SCRIPT_PATH/scripts/mask_network.sh"
source "$SCRIPT_PATH/scripts/install_packages.sh"
source "$SCRIPT_PATH/scripts/migrate_network.sh"
