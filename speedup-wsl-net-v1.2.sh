#!/bin/bash
# ===========================================================
# 🚀 WSL Network Speed Booster v1.2 (Ubuntu)
# Author: Md Nawab Ali Khan | Optimized by ChatGPT GPT-5
# ===========================================================

set -e

echo "⚙️ Starting WSL network optimization..."

# --- Step 1: Ensure WSL config disables auto resolv.conf ---
sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[network]
generateResolvConf = false
EOF

# --- Step 2: Safely replace resolv.conf ---
sudo chattr -i /etc/resolv.conf 2>/dev/null || true
sudo rm -f /etc/resolv.conf
sudo tee /etc/resolv.conf >/dev/null <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 1.0.0.1
EOF
sudo chattr +i /etc/resolv.conf 2>/dev/null || true
echo "✅ DNS optimized (Cloudflare + Google)."

# --- Step 3: Clean packages ---
sudo apt clean -y && sudo apt autoremove -y
echo "🧹 System cleaned."

# --- Step 4: Restart resolver if available ---
sudo systemctl restart systemd-resolved 2>/dev/null || true
echo "🔁 DNS resolver restarted."

# --- Step 5: Generate PowerShell script in WSL home folder ---
PS_LINUX_PATH="$HOME/wsl-tcp-opt.ps1"
PS_WIN_PATH=$(wslpath -w "$PS_LINUX_PATH")

cat > "$PS_LINUX_PATH" <<'EOF'
Write-Host "⚙️ Applying Windows TCP optimizations (Administrator required)..."
netsh interface tcp set global autotuninglevel=normal
netsh interface tcp set global rss=enabled
netsh interface tcp set global ecncapability=enabled
Write-Host "✅ TCP tuning attempted. If you see 'requires elevation',"
Write-Host "   please run PowerShell *as Administrator* and execute:"
Write-Host "   netsh interface tcp set global autotuninglevel=normal rss=enabled ecncapability=enabled"
EOF

echo "💻 Running TCP tuning from PowerShell..."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS_WIN_PATH" || true

# --- Step 6: Show current network interfaces ---
echo "🌐 Current network interfaces:"
ip -4 addr show | awk '/inet /{print $2}' | cut -d/ -f1

# --- Step 7: Optional speed test ---
read -rp "Do you want to run a speed test now? (y/n): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  sudo apt install -y speedtest-cli
  speedtest
fi

echo "✅ Done!"
echo "➡️ Run 'wsl --shutdown' in Administrator PowerShell, then reopen Ubuntu."
echo "🚀 Your WSL internet speed and responsiveness are now optimized!"

