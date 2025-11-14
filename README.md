# WSL Ultra Mode A (Safe) - README

# 📄 README — WSL Ultra Mode A (Safe)

## Overview

**WSL Ultra Mode A — Safe & Stable** is a conservative network optimization script for WSL1 and WSL2. It optimizes DNS resolution, TCP buffers, backlog sizes, and safe network parameters without risking system stability.

The script also generates a **Windows PowerShell helper** for optional Windows-side TCP tuning.

---

## 🛠 Features

* Auto-detects WSL version (1 or 2).
* Safely replaces `/etc/resolv.conf` with fastest DNS available (Cloudflare, Google, Quad9).
* Applies **conservative sysctl network tuning**.
* Enables BBR congestion control if available.
* Provides a revert helper (`wsl-ultra-revert`) to restore backups.
* Optional speed test integration.
* Non-destructive Windows TCP tuning via PowerShell helper.

---

## ⚙️ Sysctl Tuning Lines Explained

The script adds a file: `/etc/sysctl.d/99-wsl-ultra.conf` with the following conservative tuning:

| Key                               | Description                                                                             |
| --------------------------------- | --------------------------------------------------------------------------------------- |
| `net.core.rmem_max`               | Max receive buffer size per socket (bytes). Helps large downloads.                      |
| `net.core.wmem_max`               | Max send buffer size per socket (bytes). Improves upload efficiency.                    |
| `net.core.netdev_max_backlog`     | Maximum packets queued on NIC before kernel drops them. Helps under bursty traffic.     |
| `net.core.somaxconn`              | Max number of pending TCP connections. Useful for server workloads.                     |
| `net.ipv4.tcp_rmem`               | TCP receive buffer min/auto/max (bytes). Conservative values for WSL.                   |
| `net.ipv4.tcp_wmem`               | TCP send buffer min/auto/max (bytes). Matches receive buffer.                           |
| `net.ipv4.tcp_fin_timeout`        | Time to wait for FIN (closing TCP sockets). Lower value frees sockets faster.           |
| `net.ipv4.tcp_keepalive_time`     | Time before sending keepalive packets. Reduces stale connections.                       |
| `net.ipv4.tcp_mtu_probing`        | Enable MTU probing (1=conservative). Helps avoid fragmentation issues.                  |
| `net.core.default_qdisc`          | Default queuing discipline for packets (`fq` = fair queue). Improves latency.           |
| `net.ipv4.tcp_congestion_control` | TCP congestion control algorithm. Set to `bbr` if kernel supports. Enhances throughput. |

**Note:** All values are conservative defaults to ensure stability inside WSL and avoid conflicts with Windows networking.

---

## 🖥 Windows TCP Helper

* Path created in WSL home: `~/wsl-ultra-tcp.ps1`
* Requires **Administrator PowerShell** to fully apply.
* Applies conservative Windows-side TCP optimizations:

  * Autotuning level: `normal`
  * RSS (Receive Side Scaling) enabled
  * Chimney offload enabled
* Safe: Will not break Windows networking if run without admin.

---

## ⚡ Usage Instructions

1. **Run Ultra Mode A script** inside WSL as root:

```bash
sudo bash wsl-ultra-safe.sh
```

2. **Run Windows TCP helper (optional but recommended)**:

```powershell
# Open Windows PowerShell as Administrator
powershell -ExecutionPolicy Bypass -File "C:\Users\<username>\wsl-ultra-tcp.ps1"
```

3. **Shutdown WSL** to apply DNS and network settings fully:

```powershell
wsl --shutdown
```

4. **Reopen WSL distro**.

5. **Optional:** Run speedtest inside WSL when prompted by the script.

6. **Revert changes** (if needed):

```bash
sudo wsl-ultra-revert
```

Backups of `/etc/resolv.conf` and `/etc/sysctl.conf` are stored in `/var/backups/wsl-ultra-<timestamp>`.

---

## ✅ Safety Notes

* Script uses **conservative defaults only**.
* Won’t force MTU changes, aggressive backlog, or risky kernel hacks.
* Safe for WSL1 and WSL2.
* BBR enabled only if supported by kernel.
* All modifications are **reversible**.

---

## 🔹 Optional Diagram (Networking Overview)

```
Windows Host Networking
      |
      | <-- TCP/UDP / MTU / Buffers
      v
WSL Virtual NIC (vEthernet)
      |
      | <-- sysctl tuning applied
      v
WSL Distro (Ubuntu/Debian)
      |-- DNS optimized (resolv.conf)
      |-- TCP buffers tuned
      |-- netdev_max_backlog increased
      |-- BBR congestion control if available
```
