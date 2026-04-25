#!/bin/bash

set -o pipefail


echo -e "\e[32mStarting script installation...\e[0m"
sudo apt-get update >/dev/null
sudo apt-get install -y git >/dev/null

# Use custom repo if specified, otherwise use default
SCRIPT_REPO="Kasui92/wpa_supplicant-to-iwd"

echo -e "\nCloning script from: https://github.com/${SCRIPT_REPO}.git"
git clone https://github.com/$SCRIPT_REPO.git >/dev/null

cd ~/wpa_supplicant-to-iwd
cd -

echo -e "\nRunning install script..."
source ~/wpa_supplicant-to-iwd/install.sh