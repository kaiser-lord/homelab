# Design Principles & Lessons Learned

This document captures the reasoning behind architectural decisions and hard-won lessons from building this homelab. Read this before deploying anything.

---

## Core Principles

### 1. Privacy & Local-First
Avoid third-party cloud services where avoidable. Local LLM inference (Ollama) is preferred over cloud APIs. Cloud APIs (Groq) are used only as fallback or where local hardware cannot sustain the workload.

### 2. Read-Only Audit
The monitoring and automation system must **never make automated changes**. n8n workflows only collect, analyze, and report. All remediation is manual. This prevents automation from causing cascading failures.

### 3. Island-Mode Resilience
Every server must function independently if NetBird or internet connectivity is lost. This shapes every architecture decision:
- NUT runs in `netserver` mode so each node manages its own UPS
- Each node has its own Ntfy instance (planned)
- Monitoring data is stored locally, not only in a central location

### 4. VPN-Only Access
No services are exposed to the LAN or internet. All remote access routes through NetBird mesh VPN. This eliminates an entire class of attack surface.

### 5. LXC over VM
For lightweight services (AdGuard, Ollama, n8n), LXC containers are preferred over VMs. Lower overhead matters on constrained hardware like the t620 and RV510.

---

## Lessons Learned

### NUT (UPS Monitoring)

- **`netserver` mode, not `standalone`** — Use `netserver` when `upsd` must serve data to multiple cluster nodes. `standalone` only works for single-host setups.
- **Serial vs. USB HID** — Some UPS units use serial-to-USB converters (CH340 chip) and require `blazer_ser` driver, not `usbhid-ups`. Always test before assuming HID compatibility. `lsusb` will show CH340 if that's what you have.
- **logrotate ownership** — NUT logs written by the `nut` user must use `create 644 nut nut` in logrotate, not `root:root`. Otherwise the process can't write to the rotated file.

### Proxmox

- **TLS fingerprint auth in PDM** — When adding nodes across different networks in Proxmox Datacenter Manager, certificate verification errors require entering the SHA256 fingerprint, not bypassing with `-k`.
- **PBS username format** — Always use `root@pam` realm syntax. Address-style usernames don't work.
- **Snapshot vs Stop backup mode** — Snapshot mode is suitable for most VM workloads. Stop mode causes unnecessary downtime on modest hardware and should be reserved for workloads that absolutely require consistent disk state.
- **PDM ≠ PBS** — These are distinct Proxmox products. PDM is a management dashboard; PBS is the backup server. Don't conflate them.

### Docker / Compose

- **Version-pin Meilisearch** — Always pin a specific version tag (e.g. `v1.41.0`). Meilisearch uses a versioned database format; updating the container image without migrating the data will break the index. Use `latest` only for stateless services.
- **rclone remote reuse** — Never create new remotes or OAuth app registrations when an existing working remote can be reused with different path arguments. One `media_backup_prod` remote covers all backup destinations.

### n8n + SSH Audit

- **SSH hop architecture** — n8n runs in Docker inside an LXC. SSH commands must hop: Docker container → LXC host → target node. This requires SSH keys at each hop level.
- **awk latency parsing** — When parsing `ping` output for average latency with awk, floating-point handling can return `0.0`. Use Python for reliable float parsing: `python3 -c "import sys; print(float(sys.argv[1].split('/')[4]))" <<< "$ping_output"`.

### NetBird

- **Server-to-server tunnels persist independently** of desktop client sessions. Never assume a node is unreachable just because your laptop's NetBird client is disconnected.

### Karakeep

- **AI env var names** — Karakeep requires `OPENAI_API_KEY`, `OPENAI_BASE_URL`, and `INFERENCE_TEXT_MODEL` specifically. Generic `AI_*` variable names don't work.
- **`INFERENCE_OUTPUT_SCHEMA=plain`** — Required for models that don't support structured JSON output (e.g. Qwen3 via Groq). Without it, tagging will fail with 400 errors.
- **Reasoning models produce `<think>` tags** — Don't use reasoning models (Qwen3, DeepSeek R1) for Karakeep tagging. Their chain-of-thought output appears verbatim in summaries. Use instruction-tuned models like `llama-3.3-70b-versatile`.
