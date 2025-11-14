#!/usr/bin/env bash
# ============================================================
# 🚀 WSL Ultra Mode A — Safe & Stable (Universal)
# Author: Md Nawab Ali Khan | Optimized by NAKORG
# Version: 1.0
# Purpose: Safe, conservative network tuning for WSL (1/2).
# IMPORTANT: Run as root (sudo). This script is conservative
# and creates backups so you can revert easily.
# ============================================================

set -euo pipefail

TIME="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/var/backups/wsl-ultra-$TIME"
mkdir -p "$BACKUP_DIR"

info(){ printf "\e[1;34m[INFO]\e[0m %s\n" "$*"; }
ok(){ printf "\e[1;32m[OK]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[ERR]\e[0m %s\n" "$*"; }

info "Starting WSL Ultra Mode A — Safe & Stable"
info "Backup directory: $BACKUP_DIR"

# -------------------------
# Detect WSL version
# -------------------------
WSL_VER="unknown"
if grep -qi "microsoft" /proc/version 2>/dev/null; then
    if grep -qi "WSL2" /proc/version 2>/dev/null || (uname -r | grep -q "microsoft-standard"); then
        WSL_VER="WSL2"
    else
        WSL_VER="WSL1"
    fi
else
    WSL_VER="not-WSL"
fi
info "Detected: $WSL_VER"

# -------------------------
# Back up important files
# -------------------------
info "Backing up /etc/sysctl.conf and /etc/resolv.conf if present..."
[ -f /etc/sysctl.conf ] && sudo cp /etc/sysctl.conf "$BACKUP_DIR/sysctl.conf.$TIME" && ok "Backed up /etc/sysctl.conf"
[ -f /etc/resolv.conf ] && sudo cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.$TIME" && ok "Backed up /etc/resolv.conf"

# -------------------------
# Helper: choose fastest DNS
# -------------------------
DNS_CANDIDATES=(
  "1.1.1.1"   # Cloudflare
  "8.8.8.8"   # Google
  "1.0.0.1"   # Cloudflare alt
  "9.9.9.9"   # Quad9
  "8.26.56.26" # Comodo (fallback)
)

pick_fastest_dns() {
  info "Probing DNS candidates for lowest ping (fast but safe)..."
  local best="" best_rt=99999
  for ip in "${DNS_CANDIDATES[@]}"; do
    # ping once, small timeout; some networks block ICMP so treat failures carefully
    rt=$(ping -c 1 -W 2 "$ip" 2>/dev/null | awk -F'/' '/rtt/ {print $5}' || true)
    if [[ -n "$rt" ]]; then
      # convert to integer ms-ish
      rt_int=$(printf "%.0f" "$rt")
      info "  $ip → ${rt_int}ms"
      if (( rt_int < best_rt )); then
        best_rt=$rt_int; best=$ip
      fi
    else
      info "  $ip → no response"
    fi
  done

  if [[ -z "$best" ]]; then
    warn "All DNS probes failed (ICMP blocked?) — using safe default 1.1.1.1"
    best="1.1.1.1"
  fi
  printf "%s\n" "$best"
}

FAST_DNS="$(pick_fastest_dns)"
info "Selected DNS primary: $FAST_DNS"

# -------------------------
# Write /etc/wsl.conf to stop auto overwrites (WSL2)
# -------------------------
info "Ensuring /etc/wsl.conf disables auto-generated resolv.conf"
sudo mkdir -p /etc
sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[network]
generateResolvConf = false
EOF

# -------------------------
# Safely replace resolv.conf
# -------------------------
RESOLV="/etc/resolv.conf"
sudo chattr -i "$RESOLV" 2>/dev/null || true

# If /etc is symlinked or locked, try best-effort and fallbacks
if sudo rm -f "$RESOLV" 2>/dev/null; then
  info "Writing new $RESOLV (primary + fallback entries)..."
  sudo tee "$RESOLV" >/dev/null <<EOF
# wsl-ultra-safe generated - backup at $BACKUP_DIR
nameserver $FAST_DNS
nameserver 8.8.8.8
nameserver 1.0.0.1
options edns0 trust-ad
EOF
  sudo chattr +i "$RESOLV" 2>/dev/null || true
  ok "Updated $RESOLV"
else
  warn "Could not overwrite $RESOLV — leaving existing configuration in place and attempting systemd-resolved config."
  # attempt to set systemd resolved config (safe)
  sudo mkdir -p /etc/systemd >/dev/null 2>&1 || true
  sudo tee /etc/systemd/resolved.conf >/dev/null <<EOF
[Resolve]
DNS=$FAST_DNS 8.8.8.8 1.0.0.1
FallbackDNS=9.9.9.9
EOF
fi

# restart resolver if systemd is present (many WSL distros lack systemd)
if command -v systemctl >/dev/null 2>&1; then
  info "Restarting systemd-resolved (if present)..."
  sudo systemctl try-restart systemd-resolved.service 2>/dev/null || warn "systemd-resolved restart failed or not in use"
else
  info "systemctl not available — resolver restart skipped"
fi

# -------------------------
# Conservative sysctl tuning (safe defaults)
# -------------------------
SYSCTL_TMP="$BACKUP_DIR/sysctl.conf.$TIME"
info "Appending conservative sysctl network tuning to /etc/sysctl.d/99-wsl-ultra.conf"
sudo tee /etc/sysctl.d/99-wsl-ultra.conf >/dev/null <<'EOF'
# wsl-ultra-safe tuning (conservative)
# Backups stored in $BACKUP_DIR
net.core.rmem_max = 2621440
net.core.wmem_max = 2621440
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 1024
net.ipv4.tcp_rmem = 4096 262144 2621440
net.ipv4.tcp_wmem = 4096 262144 2621440
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_mtu_probing = 1
# Conservative qdisc and congestion control defaults (may be overridden if not available)
net.core.default_qdisc = fq
# net.ipv4.tcp_congestion_control = bbr   # enabled below only when available
EOF

ok "Wrote /etc/sysctl.d/99-wsl-ultra.conf"

# Apply sysctl settings now (best-effort)
info "Applying sysctl settings..."
sudo sysctl --system >/dev/null 2>&1 || warn "sysctl apply had warnings (some keys may not be supported)"

# -------------------------
# Enable BBR if available (safe check)
# -------------------------
if [[ -f /proc/sys/net/ipv4/tcp_available_congestion_control ]]; then
  avail_cc=$(cat /proc/sys/net/ipv4/tcp_available_congestion_control || true)
  info "Available TCP congestion control algorithms: $avail_cc"
  if echo "$avail_cc" | grep -qw bbr; then
    info "BBR available — enabling conservatively..."
    sudo sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
    sudo sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1 || true
    ok "Set tcp_congestion_control=bbr (if supported by kernel)"
  else
    info "BBR not available. Keeping default congestion control."
  fi
else
  warn "Cannot read available congestion controls — skipping BBR enable."
fi

# -------------------------
# MTU: detect primary interface and show suggestion (no forced destructive change)
# -------------------------
info "Detecting primary network interface (safe check)..."
PRIMARY_IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1); exit}}}')
if [[ -n "$PRIMARY_IFACE" ]]; then
  cur_mtu=$(cat /sys/class/net/"$PRIMARY_IFACE"/mtu 2>/dev/null || echo "unknown")
  info "Primary interface: $PRIMARY_IFACE (current MTU: $cur_mtu)"
  # Suggest but don't force change. Offer to set to 1500 if lower than 1500.
  if [[ "$cur_mtu" =~ ^[0-9]+$ ]] && (( cur_mtu < 1500 )); then
    warn "MTU is <$cur_mtu> (less than 1500). Leaving untouched — changing MTU may disrupt connectivity."
  else
    info "MTU looks normal. No MTU changes performed (safe default)."
  fi
else
  warn "Could not determine primary interface — skipping MTU suggestions."
fi

# -------------------------
# Increase default socket backlog for NICs (try safe methods)
# -------------------------
info "Attempting to tune netdev backlog (safe max 5000)..."
sudo sysctl -w net.core.netdev_max_backlog=5000 >/dev/null 2>&1 || warn "Could not set netdev_max_backlog"

# -------------------------
# apt housekeeping (non-blocking)
# -------------------------
info "Cleaning APT caches (best-effort)..."
sudo apt-get update -y >/dev/null 2>&1 || warn "apt-get update failed"
sudo apt-get install -y --no-install-recommends ethtool >/dev/null 2>&1 || true
sudo apt-get clean -y >/dev/null 2>&1 || true
ok "APT housekeeping done (if available)."

# -------------------------
# Create Windows PowerShell helper script for TCP tuning (non-destructive)
# -------------------------
PS_LINUX_PATH="$HOME/wsl-ultra-tcp.ps1"
PS_WIN_PATH="$(wslpath -w "$PS_LINUX_PATH" 2>/dev/null || true)"
info "Creating Windows PowerShell helper at $PS_LINUX_PATH (run as Admin for Windows-side tuning)"
cat > "$PS_LINUX_PATH" <<'PSHEREDOC'
Write-Host "WSL Ultra Mode A — Windows TCP tuning helper"
Write-Host "This script will attempt conservative Windows TCP tweaks (requires Administrator)."

try {
  # conservative settings - non destructive
  netsh interface tcp set global autotuninglevel=normal | Out-Null
  netsh interface tcp set global rss=enabled | Out-Null
  netsh interface tcp set global chimney=enabled | Out-Null
  Write-Host "✅ Windows TCP settings applied (or already set)."
} catch {
  Write-Host "⚠️ Could not apply Windows TCP settings. Run PowerShell as Administrator and run this file manually:"
  Write-Host "     $PS_LINUX_PATH (translate path to Windows form with wslpath -w if needed)"
}
PSHEREDOC

ok "PowerShell helper created."

# Try to run powershell.exe (best-effort, non-fatal)
if command -v powershell.exe >/dev/null 2>&1; then
  info "Attempting to run Windows PowerShell helper (non-admin attempt — may require elevation)"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS_WIN_PATH" >/dev/null 2>&1 || warn "powershell.exe call returned non-zero; you may need to run it manually as Administrator."
else
  info "powershell.exe not found — skip Windows-side auto-run. Run the script manually from Windows PowerShell as Admin:"
  info "    wslpath -w $PS_LINUX_PATH  # convert to Windows path then run with Admin PowerShell"
fi

# -------------------------
# Optional: speedtest (ask the user)
# -------------------------
echo
read -r -p "Run a quick speedtest from within WSL now? (y/N): " do_speed
if [[ "$do_speed" =~ ^[Yy]$ ]]; then
  info "Installing speedtest CLI (if needed) and running test..."
  sudo apt-get update -y >/dev/null 2>&1 || true
  sudo apt-get install -y --no-install-recommends speedtest-cli >/dev/null 2>&1 || warn "Could not install speedtest-cli"
  if command -v speedtest >/dev/null 2>&1; then
    speedtest || warn "speedtest ran but returned non-zero"
  else
    warn "speedtest CLI not available"
  fi
fi

# -------------------------
# Create an easy revert script
# -------------------------
REVERT_SCRIPT="/usr/local/bin/wsl-ultra-revert"
info "Creating revert helper at $REVERT_SCRIPT (will restore backups made by this run)"
sudo tee "$REVERT_SCRIPT" >/dev/null <<'REVERT'
#!/usr/bin/env bash
set -euo pipefail
BACKUP_DIR='"$BACKUP_DIR"'
echo "Reverting WSL Ultra changes from backup dir: $BACKUP_DIR"
if [[ -f "$BACKUP_DIR/sysctl.conf.*" || -f "$BACKUP_DIR/sysctl.conf.$TIME" ]]; then
    echo "Restoring sysctl and resolv backups if present..."
fi
# Restore sysctl.d file removal
sudo rm -f /etc/sysctl.d/99-wsl-ultra.conf 2>/dev/null || true
# Restore resolv if backup exists (last saved)
LAST_RESOLV="$(ls -1 $BACKUP_DIR/resolv.conf.* 2>/dev/null | tail -n1 || true)"
if [[ -n "$LAST_RESOLV" ]]; then
    sudo chattr -i /etc/resolv.conf 2>/dev/null || true
    sudo cp "$LAST_RESOLV" /etc/resolv.conf
    sudo chattr +i /etc/resolv.conf 2>/dev/null || true
    echo "Restored /etc/resolv.conf from $LAST_RESOLV"
else
    echo "No resolv.conf backup found in $BACKUP_DIR"
fi
echo "Removed /etc/sysctl.d/99-wsl-ultra.conf"
echo "IMPORTANT: After revert run: wsl --shutdown in Windows PowerShell and restart your distro."
REVERT
sudo chmod +x "$REVERT_SCRIPT"
ok "Revert helper created: $REVERT_SCRIPT"

# Final messages & guidance
echo
ok "Ultra Mode A applied (conservative settings)."
echo
cat <<EOF
Next recommended steps (please follow):
  1) In Windows (Administrator PowerShell): run the generated helper to apply Windows TCP tweaks:
       $(wslpath -w "$PS_LINUX_PATH" 2>/dev/null || echo "$PS_LINUX_PATH")
     If you prefer, open Admin PowerShell and run:
       powershell -ExecutionPolicy Bypass -File "$(wslpath -w "$PS_LINUX_PATH" 2>/dev/null || echo "$PS_LINUX_PATH")"

  2) Shutdown WSL for changes to fully take effect (Windows PowerShell):
       wsl --shutdown

  3) Reopen your WSL distro.

If something goes wrong, revert using:
    sudo wsl-ultra-revert

Backups were saved to: $BACKUP_DIR

EOF

exit 0

