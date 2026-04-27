# Write iwd main config
sudo mkdir -p /etc/iwd
sudo tee /etc/iwd/main.conf > /dev/null << 'EOF'
[General]
EnableNetworkConfiguration=true

[Network]
EnableIPv6=true
EOF

sudo mkdir -p /var/lib/iwd

# Migrate wifi credentials from /etc/network/interfaces to iwd PSK profiles
_write_iwd_profile() {
  local ssid="$1" psk="$2" profile

  if [[ "$ssid" =~ ^[A-Za-z0-9_-]+$ ]]; then
    profile="/var/lib/iwd/${ssid}.psk"
  else
    profile="/var/lib/iwd/=$(printf '%s' "$ssid" | od -A n -t x1 | tr -d ' \n').psk"
  fi

  {
    printf '%s\n' "[Security]"
    if [[ "$psk" =~ ^[0-9a-fA-F]{64}$ ]]; then
      printf '%s\n' "PreSharedKey=${psk}"
    else
      printf '%s\n' "Passphrase=${psk}"
    fi
    printf '%s\n' "" "[Settings]" "AutoConnect=true"
  } | sudo tee "$profile" > /dev/null

  sudo chmod 600 "$profile"
  echo "Migrated: $ssid -> $profile"
}

if [[ -f /etc/network/interfaces ]]; then
  ssid=$(sudo sed -n 's/^[[:space:]]*wpa-ssid[[:space:]]\+//p' /etc/network/interfaces | head -n1)
  psk=$(sudo sed -n 's/^[[:space:]]*wpa-psk[[:space:]]\+//p' /etc/network/interfaces | head -n1)

  ssid="${ssid#\"}"; ssid="${ssid%\"}"

  if [[ -n "$ssid" && -n "$psk" ]]; then
    _write_iwd_profile "$ssid" "$psk"
  fi
fi

# Identify wifi interfaces
wifi_ifaces=""
for p in /sys/class/net/*/wireless; do
  [[ -d "$p" ]] || continue
  iface="${p%/wireless}"
  iface="${iface##*/}"
  wifi_ifaces="$wifi_ifaces $iface"
done

# Remove wifi stanzas from /etc/network/interfaces
if [[ -f /etc/network/interfaces && -n "$wifi_ifaces" ]]; then
  sudo cp /etc/network/interfaces /etc/network/interfaces.bak

  sudo awk -v list="$wifi_ifaces" '
    BEGIN { split(list, a); for(i in a) w[a[i]]=1 }
    /^(allow-hotplug|auto)[[:space:]]/ { if(w[$2]) next }
    /^iface[[:space:]]/ { skip=(w[$2]?1:0); if(skip) next }
    skip && (/^[[:space:]]/ || /^$/) { next }
    { skip=0; print }
  ' /etc/network/interfaces | sudo tee /etc/network/interfaces.tmp > /dev/null
  sudo mv /etc/network/interfaces.tmp /etc/network/interfaces
fi

# Disable wpa_supplicant
sudo systemctl disable wpa_supplicant 2>/dev/null || true
sudo systemctl mask wpa_supplicant 2>/dev/null || true

for p in /sys/class/net/*/wireless; do
  [[ -d "$p" ]] || continue
  iface="${p%/wireless}"
  iface="${iface##*/}"
  sudo systemctl mask "wpa_supplicant@${iface}.service" 2>/dev/null || true
done

# Enable iwd
sudo systemctl unmask iwd 2>/dev/null || true
sudo systemctl enable iwd 2>/dev/null || true

# Enable resolved only if installed
if systemctl cat systemd-resolved &>/dev/null; then
  sudo systemctl unmask systemd-resolved 2>/dev/null || true
  sudo systemctl enable systemd-resolved 2>/dev/null || true

  if [[ -L /etc/resolv.conf ]] || [[ -f /etc/resolv.conf ]]; then
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null || true
  fi
fi

sudo systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
sudo systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true