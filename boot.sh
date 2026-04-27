#!/bin/bash

set -eEo pipefail

export SCRIPT_PATH="$HOME/wpa_supplicant-to-iwd"
SCRIPT_REPO="Kasui92/wpa_supplicant-to-iwd"

echo -e "\e[32mStarting installation...\e[0m"

if [[ ! -d "$SCRIPT_PATH" ]]; then
  sudo apt-get update >/dev/null
  sudo apt-get install -y git >/dev/null
  echo -e "\nCloning from: https://github.com/${SCRIPT_REPO}.git"
  git clone "https://github.com/$SCRIPT_REPO.git" "$SCRIPT_PATH" >/dev/null
fi

source "$SCRIPT_PATH/scripts/mask_network.sh"
source "$SCRIPT_PATH/scripts/install_packages.sh"
source "$SCRIPT_PATH/scripts/migrate_network.sh"