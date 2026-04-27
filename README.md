# `wpa_supplicant` to `iwd`

Automated migration script for Debian/Ubuntu-based systems that replaces `wpa_supplicant` with [`iwd`](https://iwd.wiki.kernel.org/) as the WiFi management backend. Existing network credentials are migrated automatically, and `systemd-resolved` is configured as the DNS resolver.