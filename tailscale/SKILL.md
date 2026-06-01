---
name: tailscale
description: Diagnose and fix Tailscale connectivity between homelab/boat hosts. Covers subnet routing architecture, the asymmetric-routing trap, the LAN-VPN path-selection trap, docker bridge MTU, key expiry management, and per-node config reference.
---

# Tailscale (homelab / cross-site)

Tailscale provides seamless remote access to both the home LAN (`192.168.20.0/24`) and boat LAN (`192.168.22.0/24`) from anywhere in the world. When configured correctly, you connect to any device on either network using its normal LAN IP — no special routing needed.

**Last full audit: 2026-05-14**

---

## How it works (architecture)

Three always-on home nodes advertise both subnets as Tailscale subnet routes:
- `192.168.20.0/24` — home LAN (directly attached)
- `192.168.22.0/24` — boat LAN (reachable via TP-Link static route → Peplink .5 → SpeedFusion)

Any Tailscale client (Mac, phone) that has **"Use Tailscale subnets"** enabled can then reach any device on either LAN by IP — Synology, Victron, SignalK, everything.

**Why the boat subnet works from home nodes:** The TP-Link home router has a static route `192.168.22.0/24 → 192.168.20.5 (Peplink)`. So from any home node, 192.168.22.x is just a routable destination. The home nodes act as gateways for both subnets — no Tailscale configuration needed on centralsk for subnet routing.

**Redundancy:** Three home nodes advertise the same routes. Tailscale picks the best available. If dockerserver is down, blackhole55 or pihole-backup continues serving.

---

## Tailnet members (audited 2026-05-14)

| Node | Tailscale IP | LAN IP | Role | Advertises routes | Key expiry |
|---|---|---|---|---|---|
| m1-pro (Mac) | 100.106.183.54 | varies | Client | No | 2026-06-25 ⚠️ |
| dockerserver | 100.121.19.37 | 192.168.20.19 | **Subnet gateway** | 20.0/24 + 22.0/24 | None (disabled) ✅ |
| blackhole55 (Synology) | 100.89.94.104 | 192.168.20.16 | **Subnet gateway (redundant)** | 20.0/24 + 22.0/24 | None (disabled) ✅ |
| pihole-backup (Pi) | 100.126.220.45 | 192.168.20.3 | **Subnet gateway (redundant)** | 20.0/24 + 22.0/24 | None (disabled) ✅ |
| centralsk | 100.74.130.57 | 192.168.22.15 | Server node | Nothing | 2026-11-01 ⚠️ |
| maggies-macbook-air | 100.78.4.51 | — | Client | No | — |
| ipad-pro-11-gen-3 | 100.67.91.70 | — | Client | No | — |

---

## Per-node configuration reference

### dockerserver (100.121.19.37)

- **OS:** Ubuntu, tailscale v1.96.4
- **Advertises:** `192.168.20.0/24`, `192.168.22.0/24`
- **AcceptRoutes:** false (prevents asymmetric routing)
- **AcceptDNS:** true (safe — home uses systemd-resolved symlink pattern, Tailscale doesn't take over resolv.conf)
- **iptables rule:** `DROP OUTPUT -d 192.168.22.15 -p udp --dport 41641` — forces Tailscale away from LAN-VPN path to centralsk
- **Persistence:** `/etc/systemd/system/tailscale-route-fix.service` enabled, active
- **Docker MTU:** 1280 (`default-network-opts.bridge.com.docker.network.driver.mtu`)
- **Docker DNS:** `["192.168.20.16", "192.168.20.3", "8.8.8.8"]`
- **tailscaled:** systemd, enabled, active
- **Key expiry:** disabled ✅
- **Path to centralsk:** DERP(mia) ~90ms (direct path blocked by iptables — correct)

### centralsk (100.74.130.57)

- **OS:** Ubuntu 24.04, tailscale v1.96.4
- **Advertises:** nothing
- **AcceptRoutes:** false
- **AcceptDNS:** false ← explicitly disabled 2026-05-14 (MagicDNS caused SERVFAIL — no upstream resolvers in tailnet admin)
- **iptables rule:** `DROP OUTPUT -d 192.168.20.19 -p udp --dport 41641` — forces Tailscale away from LAN-VPN path to dockerserver
- **Persistence:** `/etc/systemd/system/tailscale-route-fix.service` enabled, active
- **Docker MTU:** 1280
- **tailscaled:** systemd, enabled, active
- **Key expiry:** 2026-11-01 ⚠️ — needs to be disabled in admin console before that date
- **Path to dockerserver:** DERP(tor) ~110ms (correct)

### blackhole55 / Synology NAS (100.89.94.104)

- **OS:** Synology DSM (Linux 4.4), tailscale v1.92.3 ⚠️ (4 minor versions behind — update via Synology Package Center)
- **Binary:** `/opt/tailscale/tailscale`
- **Socket:** `/var/run/tailscale/tailscaled.sock`
- **All tailscale commands must use:** `sudo /opt/tailscale/tailscale --socket=/var/run/tailscale/tailscaled.sock <cmd>`
- **Advertises:** `192.168.20.0/24`, `192.168.22.0/24`
- **AcceptRoutes:** false
- **AcceptDNS:** false
- **Key expiry:** disabled ✅
- **tailscaled:** running as background process — started by rc.d script, not systemd (Synology doesn't use systemd).
- **Startup:** `/usr/local/etc/rc.d/tailscale.sh` → symlink to `/opt/tailscale/start-tailscale.sh`. Runs on DSM boot: enables IP forwarding, starts tailscaled, runs `tailscale up --advertise-routes=192.168.20.0/24,192.168.22.0/24 --accept-dns=false`. To restart manually: `sudo /opt/tailscale/start-tailscale.sh`
- **NOT in DSM Package Center** — manually installed binary. Update procedure:
  ```bash
  # Find latest version at https://pkgs.tailscale.com/stable/#linux
  VER=1.96.4  # substitute current stable
  curl -L "https://pkgs.tailscale.com/stable/tailscale_${VER}_amd64.tgz" -o /tmp/ts.tgz
  tar -xzf /tmp/ts.tgz -C /tmp/
  sudo kill $(pgrep tailscaled)
  sudo cp /tmp/tailscale_${VER}_amd64/tailscale /opt/tailscale/tailscale
  sudo cp /tmp/tailscale_${VER}_amd64/tailscaled /opt/tailscale/tailscaled
  sudo /opt/tailscale/start-tailscale.sh
  # Verify
  sudo /opt/tailscale/tailscale --socket=/var/run/tailscale/tailscaled.sock version
  ```
- **Path to dockerserver:** direct via LAN 192.168.20.19:xxx, ~2ms (correct — same LAN, no SpeedFusion in the way)
- **No iptables rule needed:** blackhole55 and dockerserver are on the same LAN, so Tailscale's LAN-direct path is fine here

### pihole-backup (100.126.220.45)

- **OS:** Raspberry Pi OS (Linux), tailscale v1.96.4
- **Advertises:** `192.168.20.0/24`, `192.168.22.0/24`
- **AcceptRoutes:** false
- **AcceptDNS:** true ⚠️ — should verify DNS is working (same risk as centralsk had before fix)
- **iptables rule:** none — reaches centralsk via LAN-VPN path (192.168.22.15:41641, ~200ms). Fine for subnet routing; only a problem if doing high-throughput direct Tailscale flows to centralsk.
- **tailscale-route-fix.service:** not installed
- **Docker:** not running Docker
- **Key expiry:** disabled ✅
- **Path to dockerserver:** direct via LAN 192.168.20.19:41641, ~1ms

---

## Client setup (Mac / iPhone / iPad)

For a Tailscale client to use subnet routes:
- **Mac:** Tailscale menubar → Preferences → enable **"Use Tailscale subnets"**
- **iPhone/iPad:** Tailscale app → account → enable **"Use Tailscale subnets"**

Once enabled: `ssh doug@192.168.20.19`, `ping 192.168.22.15`, browser to `http://192.168.22.25` — all work from anywhere.

**Mac key expiry:** disabled 2026-05-14.

---

## Admin console checklist

URL: **https://login.tailscale.com/admin/machines**

| Action | Status |
|---|---|
| dockerserver subnet routes approved (both /24s) | ✅ Done 2026-05-14 |
| blackhole55 subnet routes approved | ✅ Active |
| pihole-backup subnet routes approved | ✅ Active |
| dockerserver key expiry disabled | ✅ |
| blackhole55 key expiry disabled | ✅ |
| pihole-backup key expiry disabled | ✅ |
| centralsk key expiry disabled | ✅ Done 2026-05-14 |
| Mac (m1-pro) key expiry disabled | ✅ Done 2026-05-14 |

---

## Install flags — what to use

**For a homelab/boat host that shares a LAN with another tailnet member:**

```bash
sudo tailscale up --hostname=<name> --accept-routes=false
```

**For a subnet gateway node (in addition to above):**

```bash
sudo tailscale set --advertise-routes=192.168.20.0/24,192.168.22.0/24
```

⚠️ **Critical:** `--advertise-routes=X` **replaces the full list**. Always specify ALL routes at once. Running `--advertise-routes=192.168.20.0/24` on a node that was advertising both will silently drop the boat subnet.

After setting routes: approve them in the admin console (they don't activate until approved).

---

## Diagnostic commands

| Command | Use |
|---|---|
| `tailscale status` | All tailnet peers, online/offline, path type |
| `tailscale netcheck` | This node's NAT type, nearest DERP, port mapping |
| `tailscale ping -c 3 <peer>` | **Most diagnostic** — shows actual path as `via <addr>:<port>`. LAN-IP = LAN-VPN trap. Public-IP = good. DERP = relay fallback. |
| `tailscale ping --tsmp <peer>` | App-layer ping; works even when ICMP blocked |
| `sudo tailscale debug prefs` | Show exactly what's configured locally (AdvertiseRoutes, AcceptRoutes, AcceptDNS, etc.) |
| `ip link show tailscale0` | MTU should be 1280 |
| `sudo iptables -L OUTPUT -n \| grep 41641` | Verify LAN-VPN blocking rule is active |

**For Synology (blackhole55), prefix every tailscale command with:**
```bash
sudo /opt/tailscale/tailscale --socket=/var/run/tailscale/tailscaled.sock <cmd>
```

---

## Failure modes seen in practice

### 1. `--accept-routes` asymmetric-routing trap (2026-05-05)

- **Symptom:** After installing Tailscale on a host that shares LAN with other tailnet members, LAN-direct connections from those peers time out. Tailscale-IP-direct still works.
- **Cause:** With `--accept-routes`, the host routes LAN peers via `tailscale0`. Inbound SYN arrives on `eth0`; SYN-ACK leaves on `tailscale0`. TCP stacks see asymmetry and drop.
- **Fix:** `sudo tailscale up --accept-routes=false --reset`. Verify `ip route get <peer-lan-ip>` doesn't go through `tailscale0`.

### 2. LAN-VPN path-selection trap (2026-05-05)

- **Symptom:** Sustained throughput between two tailnet hosts stalls at ~100 KB. Latency fine; small responses fine; large payloads stall (TCP back-pressure).
- **Cause:** Two tailnet hosts connected by a site-to-site VPN. Tailscale discovers the peer's LAN IP as "direct" (low latency). The VPN tunnel has packet loss that doesn't show in latency but kills sustained throughput.
- **Diagnose:** `tailscale ping -c 3 <peer>` shows `via <peer-LAN-IP>:41641` — that's the LAN-VPN path.
- **Fix:** Block outbound Tailscale UDP to the peer's LAN IP on BOTH nodes:

  ```bash
  sudo iptables -I OUTPUT -d <peer-LAN-IP> -p udp --dport 41641 -j DROP
  ```

  **Must be applied on both peers** — fixing only one causes asymmetric direct attempts that Tailscale rejects, falling back to DERP.

- **Persist** (Linux/systemd):

  ```ini
  # /etc/systemd/system/tailscale-route-fix.service
  [Unit]
  Description=Force Tailscale to use public path (block LAN-VPN UDP 41641)
  After=network-online.target tailscaled.service
  Wants=network-online.target

  [Service]
  Type=oneshot
  RemainAfterExit=yes
  ExecStart=/bin/sh -c 'iptables -C OUTPUT -d <peer-LAN-IP> -p udp --dport 41641 -j DROP 2>/dev/null || iptables -I OUTPUT -d <peer-LAN-IP> -p udp --dport 41641 -j DROP'
  ExecStop=/bin/sh -c 'iptables -D OUTPUT -d <peer-LAN-IP> -p udp --dport 41641 -j DROP 2>/dev/null || true'

  [Install]
  WantedBy=multi-user.target
  ```

  ```bash
  sudo systemctl daemon-reload
  sudo systemctl enable --now tailscale-route-fix.service
  ```

### 3. Docker bridge ↔ Tailscale MTU mismatch

- **Symptom:** Inside a docker container, small HTTP responses work; anything >~4 KB stalls.
- **Cause:** Tailscale MTU is 1280; docker bridges default to 1500. PMTUD often broken upstream, so MSS doesn't adjust.
- **Fix:** Set docker daemon bridge MTU to 1280. The `mtu` key only affects `docker0`; user bridges need `default-network-opts`:

  ```json
  {
    "default-network-opts": {
      "bridge": {
        "com.docker.network.driver.mtu": "1280"
      }
    }
  }
  ```

  Then: `docker compose down` all stacks → remove all user bridges → `systemctl restart docker` → recreate networks → `docker compose up -d`. Then `sudo ip route flush cache` on both ends.

### 4. Stale PMTU cache after MTU change

- **Symptom:** After fixing MTU, existing connections still stall.
- **Fix:** `sudo ip route flush cache` on both ends. Restart long-running connection holders.

### 5. MagicDNS / AcceptDNS breaks public lookups

- **Symptom:** `git pull` fails; `getent hosts github.com` returns nothing; `/etc/resolv.conf` shows `nameserver 100.100.100.100` only.
- **Cause:** Tailscale's `--accept-dns=true` rewrites resolv.conf to MagicDNS. If no upstream resolvers are configured in the tailnet admin, public lookups return SERVFAIL.
- **Diagnose:** `dig @100.100.100.100 github.com +time=3 +tries=1` returns empty.
- **Fix:** `sudo tailscale set --accept-dns=false`, then restore a working `/etc/resolv.conf`:

  ```bash
  sudo tee /etc/resolv.conf <<'EOF'
  nameserver <local-router-IP>
  nameserver 1.1.1.1
  nameserver 8.8.8.8
  options edns0 timeout:2 attempts:2
  EOF
  ```

- **Why centralsk hit this:** Tailscale install pre-empted systemd-resolved's symlink; `/etc/resolv.conf` became a static Tailscale-managed file. Home (dockerserver) was already using the systemd-resolved symlink pattern when Tailscale was installed, so it was immune.
- **Current state:** centralsk has `--accept-dns=false` (fixed 2026-05-14). dockerserver has `--accept-dns=true` but is safe due to systemd-resolved symlink.

### 6. NAT mapping flap blocks direct-path establishment

- **Symptom:** After fixing the LAN-VPN trap, Tailscale still falls back to DERP. `tailscale ping` shows `via DERP(...)`.
- **Diagnose:** `journalctl -u tailscaled` shows multiple different STUN-mapped ports in quick succession — NAT is giving inconsistent mappings.
- **Cause:** Consumer routers (TP-Link TL-R600VPN observed 2026-05-07) re-map NAT ports under load or per-destination even when `MappingVariesByDestIP` reports false.
- **Fix:** Two-hop port-forward (Rogers gateway sits in front of TP-Link — home has double NAT). Step 1: Rogers gateway (http://10.0.0.1) → UDP 41641 → 10.0.0.8. Step 2: TP-Link (http://192.168.20.1) → Forwarding → Virtual Servers → UDP 41641 → 192.168.20.19. **Not yet applied as of 2026-05-14.**
- **Current impact:** cross-site flows between dockerserver and centralsk use DERP(mia) relay (~90ms, ~2 Mbps max). Direct would be ~4.4 Mbps. Works fine, just slower.

### 7. Key expiry kills subnet routing silently

- **Symptom:** Subnet routing stops working (can't reach LAN devices); tailnet peer still shows as connected. No obvious error.
- **Cause:** Gateway node's Tailscale key expired. The node stays in the tailnet but stops relaying subnet routes.
- **Fix:** Re-authenticate (`sudo tailscale up`) or proactively disable key expiry in admin console.
- **Affected nodes:** centralsk expires 2026-11-01; Mac expires 2026-06-25.

### 8. `--advertise-routes` silently drops routes

- **Symptom:** After running `tailscale set --advertise-routes=192.168.20.0/24`, the boat subnet (192.168.22.0/24) stops working. Admin console shows "approved but not advertised anymore."
- **Cause:** `tailscale set --advertise-routes=X` replaces the full list, not adds to it.
- **Fix:** Always specify all routes: `sudo tailscale set --advertise-routes=192.168.20.0/24,192.168.22.0/24`
- **Verify:** `sudo tailscale debug prefs | grep -A5 AdvertiseRoutes`

---

## Quick decision flow

1. Can you ping the tailscale IP of the gateway? `ping 100.121.19.37` — if no, tailnet itself is broken.
2. Can you reach a LAN device? `ping 192.168.20.19` — if no, check: (a) Mac has "Use Tailscale subnets" on, (b) routes approved in admin console, (c) gateway node is online and advertising.
3. What path is the gateway using? `tailscale ping -c 3 100.121.19.37` — DERP is normal; LAN-IP means LAN-VPN trap.
4. Slow throughput to cross-site? Check DERP vs direct. TP-Link port-forward would help.
5. Subnet gateway stopped working suddenly? Check key expiry.

---

## Outstanding known gaps (as of 2026-05-14)

| Gap | Impact | Fix |
|---|---|---|
| ~~Synology Tailscale on v1.92.3~~ | ~~Version skew~~ | ✅ Updated to 1.96.4 via manual binary replacement 2026-05-14 |
| pihole-backup AcceptDNS=true | Potential DNS failure if tailnet admin has no upstream resolvers | Check `dig @100.100.100.100 github.com`; fix with `sudo tailscale set --accept-dns=false` if needed |

## Completed (2026-05-14)

- ✅ Subnet routing working — home + boat LANs reachable from anywhere
- ✅ All key expiries disabled (dockerserver, blackhole55, pihole-backup, centralsk, Mac)
- ✅ Direct path established — dockerserver `via 99.224.54.250:41641`, no DERP relay
- ✅ Port forwards: Rogers app UDP 41641 → 10.0.0.8; TP-Link Virtual Server UDP 41641 → 192.168.20.19
- ✅ centralsk DNS fixed (`--accept-dns=false`)
