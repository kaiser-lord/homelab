# Karakeep Setup — Configuration Summary

## Infrastructure

Karakeep runs as a Docker container inside a Proxmox VE virtual machine on **spartan** (HP Thinclient t620, Network A).

- **RAM:** 4.5 GB
- **CPU:** Host + AES passthrough, 1 socket, 2 cores
- **Disk:** 50 GB
- **Machine type:** Q35 with CloudInit
- **Hypervisor:** Proxmox VE

---

## Deployment

```bash
cd /opt/karakeep
cp .env.example .env
# Fill in .env with your secrets
docker compose up -d
```

**Wizard / key settings:**

| Setting | Value |
|---------|-------|
| AI backend | Groq (OpenAI-compatible endpoint) |
| Text model | `llama-3.3-70b-versatile` |
| Image model | `meta-llama/llama-4-scout-17b-16e-instruct` |
| Search backend | Meilisearch (self-hosted, same VM) |
| Output schema | `plain` (required for non-structured models) |

---

## Configuration

### Search
- Backend: Meilisearch (self-hosted)
- After connecting Meilisearch, existing bookmarks require manual reindexing: Admin → Background Jobs → Reindex All Bookmarks.

### AI Tagging & Summarization

```
OPENAI_API_KEY=<groq_api_key>
OPENAI_BASE_URL=https://api.groq.com/openai/v1
INFERENCE_TEXT_MODEL=llama-3.3-70b-versatile
INFERENCE_IMAGE_MODEL=meta-llama/llama-4-scout-17b-16e-instruct
INFERENCE_OUTPUT_SCHEMA=plain
INFERENCE_ENABLE_AUTO_SUMMARIZATION=true
```

### Meilisearch Version Pinning
Always use a pinned version tag — never `latest`. Meilisearch uses a versioned database format; a container image update without data migration will corrupt the index.

---

## Issues Resolved During Setup

1. **Search not working on existing bookmarks** — Meilisearch only indexes new bookmarks on first connection. Fix: manual reindex from Admin panel.
2. **AI tagging not working** — Wrong environment variable names (`AI_API_KEY`, `AI_MODEL`). Karakeep requires `OPENAI_API_KEY`, `OPENAI_BASE_URL`, and `INFERENCE_TEXT_MODEL` specifically.
3. **Model not found (404)** — Incorrect Groq model ID. Always verify model IDs on console.groq.com.
4. **json_schema error (400)** — Model doesn't support structured output. Fix: `INFERENCE_OUTPUT_SCHEMA=plain`.
5. **`<think>` tags in summaries** — Caused by using a reasoning model (Qwen3). Fix: switched to `llama-3.3-70b-versatile` (non-reasoning).
6. **Summaries not running in bulk** — `INFERENCE_ENABLE_AUTO_SUMMARIZATION=true` was missing.

---

## Cost
Groq usage for a personal bookmark manager is minimal — estimated fractions of a cent per month. Both models are on Groq's free tier.
