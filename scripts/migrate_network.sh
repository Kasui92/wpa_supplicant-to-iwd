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

  # Write iwd profile with appropriate permissions
  {
    printf '%s\n' "[Security]"
    if [[ "$psk" =~ ^[0-9a-fA-F]{64}$ ]]; then
      printf '%s\n' "PreSharedKey=${psk}"
    else
      printf '%s\n' "Passphrase=${psk}"
    fi
    printf '%s\n' "" "[Settings]" "AutoConnect=true" ""
  } | sudo tee "$profile" > /dev/null

  sudo chmod 600 "$profile"
  sync "$profile" # Ensure data is written to disk
  echo "Migrated: $ssid -> $profile"
}

if [[ -f /etc/network/interfaces ]]; then
  ssid=""; psk=""

  # Read /etc/network/interfaces line by line, looking for wifi stanzas and credentials
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^(auto|allow-hotplug|iface|mapping|source)[[:space:]] ]]; then
      [[ -n "$ssid" && -n "$psk" ]] && _write_iwd_profile "$ssid" "$psk"
      ssid=""; psk=""
    fi

    if [[ "$line" =~ ^[[:space:]]+wpa-ssid[[:space:]]+\"([^\"]+)\" ]]; then
      ssid="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]+wpa-ssid[[:space:]]+([^[:space:]#]+) ]]; then
      ssid="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]+wpa-psk[[:space:]]+([^[:space:]#]+) ]]; then
      psk="${BASH_REMATCH[1]}"
    fi
  done < /etc/network/interfaces

  # Handle last profile if file doesn't end with a blank line
  [[ -n "$ssid" && -n "$psk" ]] && _write_iwd_profile "$ssid" "$psk"
fi

# Identify wifi interfaces to remove from /etc/network/interfaces and disable wpa_supplicant services
wifi_ifaces=()
for p in /sys/class/net/*/wireless; do
  [[ -d "$p" ]] || continue
  iface="${p%/wireless}"
  iface="${iface##*/}"
  wifi_ifaces+=("$iface")
done

# Remove wifi stanzas from /etc/network/interfaces to prevent conflicts with iwd.
# We only do this if we found wifi interfaces and the file exists, to avoid unnecessary modifications.
if [[ -f /etc/network/interfaces && ${#wifi_ifaces[@]} -gt 0 ]]; then
  awk_script='BEGIN { for(i=2;i<ARGC;i++) w[ARGV[i]]=1; ARGC=2 }
    /^(allow-hotplug|auto)[[:space:]]/ { if(w[$2]) next }
    /^iface[[:space:]]/ { skip=(w[$2]?1:0); if(skip) next }
    skip && (/^[[:space:]]/ || /^$/) { next }
    { skip=0; print }'

  sudo awk "$awk_script" /etc/network/interfaces "${wifi_ifaces[@]}" | \
    sudo tee /etc/network/interfaces.tmp > /dev/null
  sudo mv /etc/network/interfaces.tmp /etc/network/interfaces
fi

# Disable wpa_supplicant services to prevent conflicts with iwd.
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