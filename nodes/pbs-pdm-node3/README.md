# pbs-pdm-node3 — Backup & Management Node

## Hardware
Samsung RV510 (consumer laptop) — used as a dedicated backup server.

## Software
- **Proxmox Backup Server** (bare-metal, Debian 13 package)
- **Proxmox Datacenter Manager** (bare-metal, Debian 13 package)

## Power Management
This node uses **suspend-to-RAM** rather than full shutdown for Wake-on-LAN compatibility. The laptop's WoL from full shutdown is unreliable; suspend-to-RAM resumes reliably.

Planned: automated PBS shutdown + WoL wake via n8n when a backup job is due.

## Backup Storage
The ZFS pool `pbspool` is **not local** — it lives on **spartan** and is exported via NFS to pbs-pdm-node3. PBS is configured to use this NFS mount as its datastore.

## Adding Nodes to PDM
When adding nodes across different networks (Network A ↔ Network B), the certificate verification step requires the **SHA256 fingerprint** of the target node's TLS cert. Look it up with:

```bash
openssl s_client -connect TARGET_IP:8006 </dev/null 2>/dev/null | openssl x509 -fingerprint -sha256 -noout
```

## PBS Username Format
Always use `root@pam` — the full realm syntax is required. Address-style usernames fail silently.
