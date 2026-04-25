# Mask iwd and systemd-resolved before packages are installed.
# This prevents them from auto-starting when apt installs them, which would
# interfere with the current wpa_supplicant-managed wifi connection and break
# the rest of the installation.
# network.sh (config phase) will unmask and enable them for the next boot.
sudo systemctl mask iwd 2>/dev/null || true
sudo systemctl mask systemd-resolved 2>/dev/null || true
echo "network: iwd and systemd-resolved masked until config phase"
