# 🏠 Homelab Infrastructure

> A self-hosted, privacy-first home server network built for resilience, automation, and local AI inference — without relying on third-party cloud services where avoidable.

---

## 📐 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    NetBird Mesh VPN                          │
│         (all nodes interconnected, always-on tunnels)        │
│                                                               │
│  ┌──────────────────────┐    ┌──────────────────────────┐   │
│  │   Network A          │    │   Network B              │   │
│  │                      │    │                           │   │
│  │  pve-node1 (t620)    │    │  pve-node2 (ProDesk G3)   │   │
│  │  • Proxmox VE        │    │  • Proxmox VE             │   │
│  │  • AdGuard Home      │    │  • Ollama                 │   │
│  │  • Karakeep + stack  │    │  • n8n / AnythingLLM      │   │
│  │  • Prometheus/Grafana│    │  • NUT (secondary)        │   │
│  │  • NUT (APC UPS)     │    │  LAN-isolated (nftables)  │   │
│  │  • Wazuh SIEM (LXC)  │    │  VPN-only access          │   │
│  │  • PBS ZFS pool (NFS)│    │                           │   │
│  │                      │    └───────────────────────────┘   │
│  │  pbs-pdm-node3       │                                    │
│  │  • Proxmox BS        │                                    │
│  │  • Proxmox DM        │                                    │
│  └──────────────────────┘                                    │
└───────────────────────────────────────────────────────────────┘
```

---

## 🖥️ Nodes

| Node | Hardware | Network | Role |
|------|----------|---------|------|
| **pve-node1** | HP Thinclient t620 | A | Primary Proxmox host, NUT server, monitoring stack, SIEM |
| **pbs-pdm-node3** | Samsung RV510 | A | Proxmox Backup Server + Datacenter Manager (bare-metal) |
| **pve-node2** | HP ProDesk 600 G3 DM (24GB RAM) | B | Compute node — Ollama LLM inference, n8n automation |

Networks A and B have no direct IP-layer route between them — all cross-network traffic flows through NetBird tunnels. The Karakeep VM on pve-node1 is itself a NetBird peer, since NetBird on a Proxmox host does not expose the mesh to its hosted VMs/LXCs — each one needing mesh access runs its own client.

---

## 🧩 Services

### pve-node1 (Network A — Primary Host)

| Service | Type | Description |
|---------|------|-------------|
| Proxmox VE | Bare-metal | Hypervisor |
| AdGuard Home | LXC | DNS filtering & ad-blocking |
| Wazuh (all-in-one) | LXC (Debian 13) | SIEM / host-based security monitoring |
| Karakeep | Docker (VM) | Self-hosted bookmark manager |
| Meilisearch | Docker (VM) | Full-text search for Karakeep |
| Prometheus | Docker (VM) | Metrics collection (1yr retention) |
| Grafana | Docker (VM) | Metrics visualization |
| node-exporter | Docker (VM) | Hardware metrics |
| nut-exporter | Docker (VM) | UPS metrics |
| blackbox-exporter | Docker (VM) | Internet/uptime probes (ICMP + HTTP) |
| smokeping-prober | Docker (VM) | Continuous latency/jitter/packet-loss histograms |
| NUT (upsd) | Host | APC UPS monitoring — netserver mode |

### pbs-pdm-node3 (Network A — Backup Node)

| Service | Type | Description |
|---------|------|-------------|
| Proxmox Backup Server | Bare-metal | VM/LXC backups from pve-node1 and pve-node2 |
| Proxmox Datacenter Manager | Bare-metal | Unified cluster view |
| ZFS `pbspool` (NFS) | Imported via NFS | Backup storage exported from pve-node1 |

### pve-node2 (Network B — Compute Node)

| Service | Type | Description |
|---------|------|-------------|
| Proxmox VE | Bare-metal | Hypervisor |
| Ollama | LXC | Local LLM inference (`gemma3:4b`, `llama3.2:3b`, `nomic-embed-text-8k`) |
| n8n | Docker (LXC) | Workflow automation & audit orchestration |
| AnythingLLM | LXC | RAG pipeline (notes Q&A); also serves as NFS server for notes |
| NUT (netclient) | LXC | Secondary UPS monitoring via `blazer_ser` |

---

## 🔒 Security & Access Principles

- **All services are VPN-only.** No services are exposed to the LAN or internet directly. Access exclusively via NetBird mesh VPN.
- **LXC over VM** for lightweight services on constrained hardware.
- **Read-only audit principle:** the monitoring/automation system never makes automated changes — only analyzes, reports, and suggests.
- **Island-mode resilience:** each node is designed to function independently if NetBird or internet connectivity is lost. Acceptable to compromise for specific cases (e.g. Wazuh reachable via NetBird), but single-host-per-service remains the default — splitting one service across nodes introduces fragile inter-host coupling.
- **Private delivery only** for security alerts; self-hosted notification tooling preferred over third-party services (e.g. ntfy over Telegram/Discord).

---

## 🛡️ Security Stack (in progress)

A 3-tool security stack is being built out:

| Tool | Status | Role |
|------|--------|------|
| **Wazuh** | 🔄 Deploying | Host-based monitoring & SIEM. All-in-one, privileged Debian 13 LXC on pve-node1, NetBird-connected for remote dashboard access and Network B reachability. Agent enrollment for pve-node1/pve-node2 in progress. |
| **OpenVAS/Greenbone** | 📋 Planned | Weekly authenticated vulnerability scanning, hosted on pve-node2 |
| **Nmap** | 📋 Planned | Periodic network inventory |

Vulnerability detection inside Wazuh itself is disabled — the CTI/vulnerability feed is a heavy, non-negotiable disk consumer, so that role is delegated to OpenVAS instead.

---

## 🤖 AI Infrastructure

Local AI inference via **Ollama** on pve-node2, with **Groq cloud** as fallback:

| Model | Purpose | Location |
|-------|---------|----------|
| `gemma3:4b` | Primary local model — RAG / notes Q&A (preferred over llama3.2:3b for accuracy) | Ollama / pve-node2 |
| `llama3.2:3b` | Secondary local model | Ollama / pve-node2 |
| `nomic-embed-text-8k` | Custom embedding model (chunk size 6000) | Ollama / pve-node2 |
| `llama-3.3-70b-versatile` | Karakeep text tagging & summarization | Groq (cloud fallback) |
| `meta-llama/llama-4-scout-17b-16e-instruct` | Karakeep image inference | Groq (cloud fallback) |

A full local RAG pipeline is operational: **Capacities (notes) → Syncthing → n8n → AnythingLLM**, using Chat mode rather than Agent mode — small local models (3–4B) are prone to hallucinating tool-call schemas in Agent mode.

**Planned:** LiteLLM as a routing layer between local Ollama and Groq, to automate cloud fallback rather than switching manually.

---

## 📊 Monitoring & Automation

### Metrics & Dashboards (pve-node1)
- **Prometheus** — metrics aggregation, 1-year TSDB retention
- **Grafana** — dashboards for all nodes
- **node-exporter** — CPU, RAM, disk, network per host (run bare-metal via systemd, not in Docker, since containerized node-exporter only sees VM-level resources)
- **nut-exporter** — UPS battery, load, runtime (one exporter container scrapes multiple UPS targets via per-scrape `server` params)

### Network Performance Monitoring
Four complementary tools cover reachability, latency, and throughput across both networks and ISPs:

| Tool | Measures | Feeds Grafana via |
|------|----------|--------------------|
| `blackbox-exporter` | Reachability, HTTP status, single-sample latency | Prometheus scrape job |
| `smokeping-prober` | Continuous latency, jitter, packet loss | Prometheus scrape job |
| `speedtest-cli` | Real ISP download/upload throughput (Network A vs B, different ISPs) | node_exporter textfile collector, cron every 2h |
| `iperf3` | LAN and cross-network TCP throughput + retransmits | node_exporter textfile collector, cron every 2h |

Key baselines: LAN (pve-node1 ↔ pbs-pdm-node3) ~94 Mbit/s (100 Mbps switch); NetBird cross-network (pve-node1 ↔ pve-node2) ~55 Mbit/s throughput, with noticeably higher latency than LAN.

### Audit Workflows (n8n on pve-node2)

| Workflow | Status | Description |
|----------|--------|-------------|
| Connectivity Matrix | ✅ Complete | SSH hop audit — all 3 nodes, latency, reachability |
| Internet Quality | 🔄 In progress | speedtest-cli metrics per node |
| SSH Metrics | 📋 Planned | Auth attempts, key usage, anomaly detection |
| Prometheus Query Audit | 📋 Planned | Automated health checks via PromQL |

### On the horizon
- Unified network dashboard (custom Node.js/Express + React SPA): cAdvisor per Docker host → Prometheus, PBS REST API collector; resource model Node/Service/Container/BackupJob/Vuln/Alert
- LiteLLM as a routing layer for automated Ollama → Groq fallback
- Normalize vulnerability scanner output via n8n into Prometheus textfiles
- Offsite PBS backups via rclone to Backblaze B2 (draft script, not finalized)
- NetBird Network Route to expose Karakeep to the Android app via subnet advertisement
- UPS notifications (Telegram/ntfy), Authelia for internal dashboard auth, Vaultwarden for secrets, NetBox for IPAM/DCIM

---

## 🔋 UPS & Power Management

Two UPS units managed by NUT:

| UPS | Node | Driver | Mode |
|-----|------|--------|------|
| APC Back-UPS BX-1600MI | pve-node1 | `usbhid-ups` | netserver (primary) |
| Generic 600VA (CH340 serial) | pve-node2 | `blazer_ser` (megatec protocol) | netclient (secondary) |

The NUT notify script handles graceful VM/container shutdown on power loss, with a configurable countdown before initiating host shutdown. A persistent udev symlink is required for the CH340 serial UPS — `usbhid-ups` will not work with it.

---

## 💾 Backups

- **VM/LXC backups:** PBS on pbs-pdm-node3 ← snapshots from pve-node1 and pve-node2
- **Backup storage:** ZFS `pbspool` exported via NFS from pve-node1 to pbs-pdm-node3; ZFS ARC capped to 1GB on pve-node1 to avoid starving live VM/LXC memory
- **Media backups:** rclone sync of media directory → OneDrive
- **Offsite backups (planned):** rclone sync of PBS datastore to Backblaze B2 (~$6/TB/month)

---

## 📄 License

MIT — use freely, adapt to your own homelab.
