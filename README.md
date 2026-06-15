# 🏠 Homelab Infrastructure

> A self-hosted, privacy-first home server network built for resilience, automation, and local AI inference — without relying on third-party cloud services where avoidable.

---

## 📐 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    NetBird Mesh VPN                         │
│         (all nodes interconnected, always-on tunnels)       │
│                                                             │
│  ┌──────────────────────┐    ┌──────────────────────────┐  │
│  │   Network A          │    │   Network B              │  │
│  │   IP_A               │    │   IP_B                   │  │
│  │                      │    │                          │  │
│  │  spartan (t620)      │    │  pve-node2 (ProDesk G3)  │  │
│  │  netbird_A1          │    │  netbird_B               │  │
│  │  • Proxmox VE        │    │  • Proxmox VE            │  │
│  │  • AdGuard Home      │    │  • Ollama (LLM)          │  │
│  │  • Karakeep + stack  │    │  • n8n (automation)      │  │
│  │  • Prometheus/Grafana│    │  LAN-isolated (nftables) │  │
│  │  • NUT (APC UPS)     │    │  VPN-only access         │  │
│  │  • PBS ZFS pool (NFS)│    │                          │  │
│  │                      │    └──────────────────────────┘  │
│  │  pbs-pdm-node3       │                                  │
│  │  netbird_A2          │                                  │
│  │  • Proxmox BS        │                                  │
│  │  • Proxmox DM        │                                  │
│  │  (suspend-to-RAM)    │                                  │
│  └──────────────────────┘                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🖥️ Nodes

| Node | Hardware | Role | NetBird IP |
|------|----------|------|------------|
| **spartan** | HP Thinclient t620 | Primary Proxmox host, NUT server, monitoring stack | `netbird_A1` |
| **pbs-pdm-node3** | Samsung RV510 | Proxmox Backup Server + Datacenter Manager (bare-metal) | `netbird_A2` |
| **pve-node2** | HP ProDesk 600 G3 DM | Compute node — Ollama LLM inference, n8n automation | `netbird_B` |

---

## 🧩 Services

### spartan (Network A — Primary Host)

| Service | Type | Port | Description |
|---------|------|------|-------------|
| Proxmox VE | Bare-metal | 8006 | Hypervisor |
| AdGuard Home | LXC | 3000/80/53 | DNS filtering & ad-blocking |
| Karakeep | Docker (VM) | 3000 | Self-hosted bookmark manager |
| Meilisearch | Docker (VM) | 7700 | Full-text search for Karakeep |
| Prometheus | Docker (VM) | 9090 | Metrics collection (1yr retention) |
| Grafana | Docker (VM) | 3001 | Metrics visualization |
| node-exporter | Docker (VM) | — | Hardware metrics |
| nut-exporter | Docker (VM) | 9199 | UPS metrics |
| blackbox-exporter | Docker (VM) | 9115 | Internet/uptime probes |
| NUT (upsd) | Host | 3493 | APC UPS monitoring — netserver mode |

### pbs-pdm-node3 (Network A — Backup Node)

| Service | Type | Description |
|---------|------|-------------|
| Proxmox Backup Server | Bare-metal | VM/LXC backups from spartan and pve-node2 |
| Proxmox Datacenter Manager | Bare-metal | Unified cluster view |
| ZFS `pbspool` (NFS) | Imported via NFS | Backup storage exported from spartan |

### pve-node2 (Network B — Compute Node)

| Service | Type | Description |
|---------|------|-------------|
| Proxmox VE | Bare-metal | Hypervisor |
| Ollama | LXC | Local LLM inference (`qwen2.5:14b-q4_K_M`) |
| n8n | Docker (LXC) | Workflow automation & audit orchestration |
| LiteLLM | LXC | Routes between Ollama and Groq cloud fallback |
| NUT (netclient) | LXC | Secondary UPS monitoring via blazer_ser |
| Ntfy | LXC | Self-hosted push notifications |

---

## 🔒 Security & Access Principles

- **All services are VPN-only.** No services are exposed to the LAN or internet directly. Access exclusively via NetBird mesh VPN.
- **LXC over VM** for lightweight services on constrained hardware.
- **Read-only audit principle:** the monitoring/automation system never makes automated changes — only analyzes, reports, and suggests.
- **Island-mode resilience:** each node is designed to function independently if NetBird or internet connectivity is lost.

---

## 🤖 AI Infrastructure

Local AI inference via **Ollama** on pve-node2, with **Groq cloud** as a fallback:

| Model | Purpose | Location |
|-------|---------|----------|
| `qwen2.5:14b-q4_K_M` | Primary LLM (audit analysis, reasoning) | Ollama / pve-node2 |
| `llama-3.3-70b-versatile` | Karakeep text tagging | Groq (cloud fallback) |
| `meta-llama/llama-4-scout-17b-16e-instruct` | Karakeep image inference | Groq (cloud fallback) |
| DeepSeek R1 Distill | Audit reasoning fallback | Groq (free tier) |

**LiteLLM** routes between local Ollama and Groq transparently, prioritizing local inference.

---

## 📊 Monitoring & Automation

### Monitoring Stack (spartan)
- **Prometheus** — metrics aggregation with 1-year TSDB retention
- **Grafana** — dashboards for all nodes
- **node-exporter** — CPU, RAM, disk, network per host
- **nut-exporter** — UPS battery, load, runtime
- **blackbox-exporter** — external URL and internet reachability probes

### Audit Workflows (n8n on pve-node2)
Automated security and infrastructure auditing via n8n + OpenClaw:

| Workflow | Status | Description |
|----------|--------|-------------|
| Connectivity Matrix | ✅ Complete | SSH hop audit — all 3 nodes, latency, reachability |
| Internet Quality | 🔄 In progress | speedtest-cli metrics per node |
| SSH Metrics | 📋 Planned | Auth attempts, key usage, anomaly detection |
| Prometheus Query Audit | 📋 Planned | Automated health checks via PromQL |

---

## 🔋 UPS & Power Management

Two UPS units managed by NUT:

| UPS | Node | Driver | Mode |
|-----|------|--------|------|
| APC Back-UPS BX-1600MI | spartan | `usbhid-ups` | netserver (primary) |
| VPC/Generic 600VA | pve-node2 | `blazer_ser` (CH340) | netserver (primary) |

NUT notify script at `/usr/local/bin/notify.sh` handles graceful VM/container shutdown on power loss, with configurable countdown before initiating host shutdown.

---

## 💾 Backups

- **VM/LXC backups:** PBS on pbs-pdm-node3 ← snapshots from spartan and pve-node2
- **Backup storage:** ZFS `pbspool` exported via NFS from spartan to pbs-pdm-node3
- **Media backups:** `media-to-cloud.sh` — rclone sync of `/mnt/media` → OneDrive via `media_backup_prod` remote

---

## 📁 Repository Structure

```
homelab/
├── README.md
├── docs/
│   ├── architecture.md          # Detailed network & service diagrams (PLANNED)
│   ├── principles.md            # Design decisions & lessons learned
│   └── services/                # Per-service setup summaries
│       └── karakeep.md
├── nodes/
│   ├── spartan/
│   │   ├── nut/                 # NUT UPS config (spartan — APC)
│   │   ├── logrotate/           # Log rotation configs
│   │   └── docker/              # Docker Compose for Karakeep + monitoring stack
│   ├── pbs-pdm-node3/           # PBS/PDM notes and config snippets
│   └── pve-node2/
│       ├── n8n/                 # Audit workflow scripts
│       └── ollama/              # Model and inference config notes (PLANNED)
├── scripts/
│   ├── media/                   # rclone backup scripts
│   └── audit/                   # SSH-based audit scripts (n8n tools) (PLANNED)
└── monitoring/
    └── prometheus.yml.example   # Prometheus scrape config template (PLANNED)
```

---

## ⚙️ Getting Started

> This repo documents a specific homelab environment. It is not a one-click deployment. Use it as a reference architecture and adapt configs to your hardware.

1. **Clone the repo**
2. Copy all `.example` files, remove the `.example` suffix, and fill in your values
3. Read `docs/principles.md` before deploying anything — several non-obvious lessons learned are documented there
4. Deploy services in order: NUT → Prometheus/Grafana → Karakeep → n8n → audit workflows

---

## 📄 License

MIT — use freely, adapt to your own homelab.
