## Optional: Auto-Pause Containers & Power Saver

This optional helper automatically **pauses your Docker containers** (`Pi-hole`, `WireGuard`, `Cloudflared`, etc.) when the internet goes down —  
and **instantly unpauses them** when connectivity is restored.  

It can also:
- Adjust CPU power profiles (`performance`, `ondemand`, `powersave`).
- Suspend the system automatically if it’s on battery and offline.
- Resume services instantly when the network returns.

---

### Installation

To enable this feature, copy the helper script and service to your system:

```bash
# Move the helper script to a system-wide location
sudo cp scripts/power_saver.sh /usr/local/bin/power_saver.sh
sudo chmod +x /usr/local/bin/power_saver.sh

# Copy the systemd service unit
sudo cp scripts/power-saver.service /etc/systemd/system/

# Enable and start the service
sudo systemctl enable --now power-saver.service
