# Audit Scripts — n8n Workflow Tools

These scripts run on **pve-node2** inside the n8n Docker container, executing via SSH hops to reach all three nodes.

## SSH Hop Architecture

```
n8n Docker → LXC host (pve-node2) → target node (spartan / pbs-pdm-node3)
```

Each hop requires SSH keys deployed at the appropriate level.

## Scripts

| Script | Description | Output |
|--------|-------------|--------|
| `connectivity_matrix.sh` | Ping latency + SSH reachability for all nodes | JSON |
| `speedtest_audit.sh` | Internet quality via speedtest-cli | JSON |
| `ssh_metrics.sh` | Auth attempts, key usage, anomaly indicators | JSON |
| `prometheus_audit.sh` | PromQL health checks via HTTP API | JSON |

## Output Location

All reports are written to `/var/log/n8n-audit/<workflow>/<YYYY-MM-DD>.json` on the n8n host.

## Notes

- Scripts are read-only audit tools. They never modify system state.
- Latency parsing uses Python for reliable float handling:
  ```bash
  python3 -c "import sys; print(float(sys.argv[1].split('/')[4]))" <<< "$ping_stats"
  ```
- All scripts exit 0 on success with structured JSON; non-zero on fatal errors.
