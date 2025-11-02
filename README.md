# pihole-doh-wireguard

A lightweight, self-hosted stack combining **Pi-hole**, **Cloudflared (DoH)**, and **WireGuard**
to give you **fast, private, ad-free DNS** anywhere — even outside your home network.

> Optimized for 2-core CPUs and 4 GB RAM — perfect for Raspberry Pi, small servers, and VMs.

---

## What’s Inside

| Component                           | Purpose                                                   |
| ----------------------------------- | --------------------------------------------------------- |
|    **Pi-hole**                      | Blocks ads, trackers, and malware at the DNS level        |
|    **Cloudflared (DoH)**            | Encrypts DNS queries with DNS-over-HTTPS                  |
|    **WireGuard (wg-easy)**          | Secure VPN that routes all traffic through Pi-hole        |
|   *Optional* **Power Saver Script** | Auto-pauses containers when offline and resumes instantly |

---

## Requirements

* Linux host (Ubuntu/Debian/Other distro not tested)
* Docker & Docker Compose
* Recommended: 2 vCPU + 4 GB RAM

---

## Setup

Clone this repository:

```bash
git clone https://github.com/yourusername/pihole-doh-wireguard.git
cd pihole-doh-wireguard/Pi-hole
```

Start everything:

```bash
sudo docker compose up -d
```

---

## Services Overview

### Cloudflared (DoH)

* Handles encrypted DNS-over-HTTPS queries
* Forwards to:

  * `https://pleaseusecloudflarezerotrust.cloudflare-gateway.com/dns-query`
  * `https://1.1.1.1/dns-query`
  * `https://1.0.0.1/dns-query`
* Listens on **port 5054**

### Pi-hole

* Uses Cloudflared as DNS upstream
* Web UI: [https://localhost:4443](https://localhost:4443)
* Default password: `passwordyoulikeidontcare` → *change it after setup!*

### WireGuard (wg-easy)

* Web UI: [http://localhost:51821](http://localhost:51821)
* Port 51820/udp for VPN connections
* Supports IPv4 and IPv6

---

## After First Run

```bash
docker exec -it pihole pihole -a -p
```

Change your Pi-hole password, and adjust upstream DoH or WireGuard settings as needed.

---

## Optional: Auto-Pause & Power Saver

An optional helper that automatically **pauses containers** (`Pi-hole`, `WireGuard`, `Cloudflared`) when the internet is down,
and **unpauses them instantly** when connectivity returns.
Also adjusts CPU power profiles and can suspend the system on battery.

---

### Installation

```bash
# Move the helper script
sudo cp scripts/power_saver.sh /usr/local/bin/power_saver.sh
sudo chmod +x /usr/local/bin/power_saver.sh

# Copy and enable the service
sudo cp scripts/power-saver.service /etc/systemd/system/
sudo systemctl enable --now power-saver.service
```

---

### Configuration

If your repo is elsewhere (e.g. `/home/pi/pihole-doh-wireguard`):

```bash
sudo nano /etc/systemd/system/power-saver.service
```

Change this line if needed:

```ini
ExecStart=/usr/local/bin/power_saver.sh
```

→ to:

```ini
ExecStart=/home/pi/pihole-doh-wireguard/scripts/power_saver.sh
```

Reload systemd:

```bash
sudo systemctl daemon-reload
sudo systemctl restart power-saver.service
```

---

### Monitoring

View logs:

```bash
sudo journalctl -u power-saver.service -f
```

Disable:

```bash
sudo systemctl disable --now power-saver.service
```

 *To include extra containers (like `hbbr`, `hbbs`), edit the `CONTAINERS=(...)` list in*
`scripts/power_saver.sh` — no rewrite needed.

---

## Folder Structure

```
pihole-doh-wireguard/
├── Pi-hole/
│   └── docker-compose.yml
├── scripts/
│   ├── power_saver.sh
│   └── power-saver.service
|   └── README.md
└── README.md
```

---

## Health Checks

| Service     | Check                              |
| ----------- | ---------------------------------- |
| Cloudflared | `cloudflared version`              |
| Pi-hole     | `dig +short @127.0.0.1 google.com` |
| WireGuard   | `wg show`                          |

---

## Maintenance

```bash
# Logs
docker logs pihole -f
docker logs cloudflared -f
docker logs wg-easy -f

# Restart all
docker compose restart
```

---

## Uninstall

```bash
docker compose down -v
sudo systemctl disable --now power-saver.service
sudo rm /usr/local/bin/power_saver.sh /etc/systemd/system/power-saver.service
```

## Tailscale as a Backup Option

If your ISP uses **CGNAT** or you can’t forward ports for WireGuard,  
you can optionally add **[Tailscale](https://tailscale.com)** as a backup for remote access.

**What it does:**  
Tailscale creates a secure, peer-to-peer **mesh VPN** between your devices — like a private LAN that works over the internet.  
It automatically handles NAT traversal, encryption, and device discovery, so you can reach your Pi-hole and network from anywhere  
without opening ports or needing a static IP.

> Think of Tailscale as a fallback connection when direct WireGuard access isn’t possible.

You can safely run both **Tailscale** and **WireGuard** together — Tailscale just ensures connectivity,  
while your Pi-hole + Cloudflared setup continues to handle DNS and filtering.

---

## Credits

* [Pi-hole](https://pi-hole.net)
* [Cloudflared](https://github.com/cloudflare/cloudflared)
* [WG-Easy](https://github.com/wg-easy/wg-easy)
* And you — for hosting your own privacy stack 

---

## License

## MIT License © 2025 — see [`LICENSE`](LICENSE)
