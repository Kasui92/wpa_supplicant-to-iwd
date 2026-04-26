# Write iwd main config - always overwrite to guarantee EnableNetworkConfiguration.
sudo mkdir -p /etc/iwd
sudo tee /etc/iwd/main.conf > /dev/null << 'EOF'
[General]
EnableNetworkConfiguration=true

[Network]
EnableIPv6=true
EOF

sudo mkdir -p /var/lib/iwd

# Migrate wifi credentials from /etc/network/interfaces to iwd PSK profiles.
_write_iwd_profile() {
  local ssid="$1" psk="$2" profile

  if [[ "$ssid" =~ ^[A-Za-z0-9_-]+$ ]]; then
    profile="/var/lib/iwd/${ssid}.psk"
  else
    profile="/var/lib/iwd/=$(printf '%s' "$ssid" | od -A n -t x1 | tr -d ' \n').psk"
  fi

  {
    echo "[Security]"
    if [[ "$psk" =~ ^[0-9a-fA-F]{64}$ ]]; then
      echo "PreSharedKey=${psk}"
    else
      echo "Passphrase=${psk}"
    fi
    echo ""
    echo "[Settings]"
    echo "AutoConnect=true"
  } | sudo tee "$profile" > /dev/null

  sudo chmod 600 "$profile"
  echo "Migrated: $ssid -> $profile"
}

if [[ -f /etc/network/interfaces ]]; then
  ssid=$(sed -n 's/^[[:space:]]*wpa-ssid[[:space:]]\+//p' /etc/network/interfaces | head -n1)
  psk=$(sed -n 's/^[[:space:]]*wpa-psk[[:space:]]\+//p' /etc/network/interfaces | head -n1)

  # Strip surrounding quotes if present
  ssid="${ssid#\"}"; ssid="${ssid%\"}"

  [[ -n "$ssid" && -n "$psk" ]] && _write_iwd_profile "$ssid" "$psk"
fi

# Identify wifi interfaces.
wifi_ifaces=""
for p in /sys/class/net/*/wireless; do
  [[ -d "$p" ]] || continue
  iface="${p%/wireless}"
  iface="${iface##*/}"
  wifi_ifaces="$wifi_ifaces $iface"
done

# Remove wifi stanzas from /etc/network/interfaces.
if [[ -f /etc/network/interfaces && -n "$wifi_ifaces" ]]; then
  sudo awk -v list="$wifi_ifaces" '
    BEGIN { split(list, a); for(i in a) w[a[i]]=1 }
    /^(allow-hotplug|auto)[[:space:]]/ { if(w[$2]) next }
    /^iface[[:space:]]/ { skip=(w[$2]?1:0); if(skip) next }
    skip && (/^[[:space:]]/ || /^$/) { next }
    { skip=0; print }
  ' /etc/network/interfaces | sudo tee /etc/network/interfaces.tmp > /dev/null
  sudo mv /etc/network/interfaces.tmp /etc/network/interfaces
fi

# Disable wpa_supplicant, enable iwd.
sudo systemctl disable wpa_supplicant 2>/dev/null || true
sudo systemctl mask wpa_supplicant

for p in /sys/class/net/*/wireless; do
  [[ -d "$p" ]] || continue
  iface="${p%/wireless}"
  iface="${iface##*/}"
  sudo systemctl mask "wpa_supplicant@${iface}.service" 2>/dev/null || true
done

sudo systemctl unmask iwd
sudo systemctl enable iwd

if systemctl cat systemd-resolved &>/dev/null; then
  sudo systemctl unmask systemd-resolved
  sudo systemctl enable systemd-resolved
fi

sudo systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
sudo systemctl mask systemd-networkd-wait-online.service
