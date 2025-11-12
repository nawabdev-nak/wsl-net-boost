#!/bin/bash
# ===========================================================
# 🚀 WSL Network Speed Booster (Ubuntu)
# Author: Md Nawab Ali Khan (nawabdev-nak)
# Optimized by ChatGPT GPT-5
# ===========================================================

echo "⚙️ Starting WSL network optimization..."

# Step 1: Ensure WSL config is correct
echo "[network]" | sudo tee /etc/wsl.conf > /dev/null
echo "generateResolvConf = false" | sudo tee -a /etc/wsl.conf > /dev/null

# Step 2: DNS Optimization (Cloudflare + Google)
sudo rm -f /etc/resolv.conf
cat <<EOF | sudo tee /etc/resolv.conf > /dev/null
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 1.0.0.1
EOF
sudo chattr +i /etc/resolv.conf
echo "✅ DNS optimized (Cloudflare + Google)."

# Step 3: Clean package cache
sudo apt clean -y && sudo apt autoremove -y
echo "🧹 System cleaned."

# Step 4: Restart resolver
sudo systemctl restart systemd-resolved 2>/dev/null || true
echo "🔁 DNS resolver restarted."

# Step 5: TCP optimizations using PowerShell
cat <<'EOF' > /tmp/wsl-tcp-opt.ps1
Write-Host "⚙️ Applying Windows TCP optimizations..."
netsh interface tcp set global autotuninglevel=normal
netsh interface tcp set global rss=enabled
netsh interface tcp set global dca=enabled
netsh interface tcp set global chimney=enabled
Write-Host "✅ Windows TCP tuning complete."
EOF

echo "💻 Running TCP tuning in PowerShell..."
powershell.exe -ExecutionPolicy Bypass -File /tmp/wsl-tcp-opt.ps1

# Step 6: Display network info
echo "🌐 Current network interfaces:"
ip addr show | grep "inet " | awk '{print $2}' | sed 's#/.*##'

# Step 7: Speedtest (optional)
read -p "Do you want to run a speed test now? (y/n): " ans
if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
  sudo apt install -y speedtest-cli
  speedtest
fi

echo "✅ Done! Please run 'wsl --shutdown' in PowerShell and reopen Ubuntu to apply changes."
echo "🚀 Your WSL internet speed and responsiveness should now be significantly improved!"

