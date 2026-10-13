# CLIProxyAPI (CPA) + OpenCode Go

Clients reaching CPA through Cloudflare need an explicit User-Agent (the OpenAI SDK's default is blocked — see SKILL.md Access).

## Config editing (watcher race)

- **Never write config.yaml into the running CPA container with `docker.uploadFileToContainer`** — the config watcher sees the external write, rewrites its own in-memory state over it, and the upload is lost. Also: uploads keep the SOURCE filename unless multipart `;filename=config.yaml` is appended.
- Correct path: `PUT /v0/management/config.yaml` with full YAML (`Content-Type: application/yaml`) — server-side write + hot reload + persisted.
- `GET /v0/management/config.yaml` (disk) vs `GET /v0/management/config` (runtime) — compare both when config seems lost; disk empty + runtime alive = in-memory-only state.

## Header injection / OpenCode Go integration (2026-09-11)

- `openai-compatibility` providers CANNOT inject headers: per-entry `headers` are accepted in YAML but silently dropped; provider-level PATCH with `headers` → `400 invalid body`. Native provider types (`gemini-api-key` etc.) DO support `headers`.
- Go REQUIRES `x-opencode-session` on every request → 400 `MissingSessionID` otherwise. Solution deployed: nginx sidecar `go-injector` in the same stack that sets Host/User-Agent/x-opencode-session and proxies to opencode.ai; CPA's `openai-compatibility` entry points at `http://go-injector/zen/go/v1`.
  - nginx gotchas: DELETE `/etc/nginx/conf.d/default.conf` (static server wins port 80 → 404s); use `set $up opencode.ai; proxy_pass https://$up;` + `resolver 1.1.1.1` (container DNS can't resolve hosts in a static proxy_pass).
- OpenCode Go facts (probed live): base `https://opencode.ai/zen/go/v1`, Bearer auth on `/chat/completions` and `/models`; `/messages` needs `x-api-key` (Anthropic-style) not Bearer; `/responses` returns HTTP 200 `error: null` (dead upstream) — grok-4.6/gpt-5.6-luna/muse-spark unreachable via API. Despite docs splitting models by protocol, `/chat/completions` serves ALL model families (qwen/minimax included).
- Cooldowns: upstream failures put compat keys in `auth_unavailable` with the stale error cached in the message. Fix: `POST /v0/management/reset-quota` per key — **auth-indexes change on provider reloads; always fetch fresh via `GET /v0/management/openai-compatibility`** (`auth-index` per entry; `auth-files` does NOT list compat keys).

## opencode-go-pool plugin (installed 2026-09-11, v0.2.0)

- Store-installed from custom source (hrz6976's registry.json). Status: `GET /v0/management/plugins/opencode-go-pool/status`.
- **PITFALL: its default `cpa-config-path: config.yaml` is relative to `/CLIProxyAPI` and ours lives at `/CLIProxyAPI/data/config.yaml` → status shows `config_error: no such file or directory` with zero accounts until you set `plugins.configs.opencode-go-pool.cpa-config-path: /CLIProxyAPI/data/config.yaml`.**
- Required companions (from plugin's config.example.yaml): `save-cooldown-status: true` + `routing: {strategy: round-robin, session-affinity: true, session-affinity-ttl: 24h}`.
- The plugin does NOT inject `x-opencode-session` (verified: zero hits in repo) — the go-injector sidecar remains required; provider stays pointed at `http://go-injector/zen/go/v1`.
- Plugin accounts (`go-1`/`go-2`) pair the two key-entries automatically; per-account success/fail counters in status. Quota dashboard (`usage_percent`) needs per-account OpenCode workspace_id + auth cookie via `POST /v0/management/plugins/opencode-go-pool/account-config` — not configured as of 2026-09-11.
