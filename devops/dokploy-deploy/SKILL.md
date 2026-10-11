---
name: dokploy-deploy
description: "Use when deploying services on Dokploy (dash.blugg.pt)."
version: 1.0.0
author: Hermes
tags: [devops, dokploy, deploy, docker]
---

# Dokploy Deploy

> **Domain correction:** Pedro no longer owns `blugg.pt`. Every `*.blugg.pt` hostname below is historical and must not be used for new configuration. The current public base is `blugg.duckdns.org`; discover and verify the live Dokploy dashboard hostname before API work instead of assuming `dash.blugg.pt`.

> **Verified 2026-10-04:** `https://dash.blugg.pt` has **no DNS record** any more, so the CLI's stored `url` is dead and `dokploy auth` against it fails. The API is reachable directly at **`http://192.168.1.42:3000`** (`x-api-key` header, token read from the CLI `config.json`) and works for everything used below. Also: LXC 100 is now **10 GiB / 6 cores** (was 6 GiB / 4 cores when the sizing section below was written) — re-read `api/cluster.getNodes` rather than trusting either number. The game panel is at **`games.blugg.duckdns.org`** (compose `pyrodactyl`, project Apps).

Dokploy (Docker Swarm + Traefik) in LXC 100. Historical notes below were verified while the old `blugg.pt` domain was active.

## Access

- CLI: `/root/.local/share/pnpm/bin/dokploy` (pnpm global). Auth: `dokploy auth -u https://dash.blugg.pt -t <token>`.
- Token also persisted at `/root/.local/share/pnpm/store/v11/links/@dokploy/cli/*/node_modules/@dokploy/cli/config.json` (json: `{url, token}`). Read it in Python, never inline in shell (redaction).
- **REST header is `x-api-key: <token>`** — NOT `x-dokploy-token` (CLI dist, `auth.js` line 16). Wrong header = `{"message":"Unauthorized"}`.
- CLI wraps the REST API (`/api/<resource>.<action>`); when a CLI call 400s, curl the API directly for the real error.
- Projects: "Projects" (studyquest) and "Apps" (executor, stash, pyrodactyl, litellm-idle, cli-proxy-api). Apps/production environmentId `Osg7u2MPzWB4-HITEPUaw`, org `fAgDJjS1Pj29JLER2vfVS`.
- Discover compose ids/domains without guessing: `GET /api/project.all` (nested environments → `compose[]` with `composeId`, `domains[]`) and `GET /api/domain.byComposeId?composeId=`, `GET /api/compose.one?composeId=` (returns `env` — the service's runtime secrets). Read the token from the CLI `config.json` in Python and pass it via a variable; never inline it in a shell command.
- Deployed app URL is `<appName>.blugg.pt` behind the Cloudflare wildcard; the compose service port is the container port (cli-proxy-api → `cliproxy.blugg.pt` → 8317).
- **Cloudflare in front blocks the OpenAI SDK User-Agent** (`OpenAI/Python x.y.z`) and any request with an empty UA → `403 Your request was blocked`. Agent/SDK clients need an explicit UA; see `local-ai-proxy` → `references/cliproxy.md`.
- **Cloudflare also blocks non-browser UAs on the Dokploy API itself** — `urllib` default `Python-urllib/3.x` returns `HTTP 403 error code: 1010`. Any scripted API client must send a browser-like `User-Agent`, or every call fails before auth is even evaluated.

## Host sizing — check BEFORE choosing a deploy target

**Never size a service from upstream docs alone.** The Dokploy API exposes no metrics endpoint (`/api/server.all` is empty here, `/api/monitoring.all` and `/api/metrics.*` 404, `/api/docker.getConfig` needs a `containerId` and is a *container* inspect — `HostConfig.Memory: 0` means unlimited, not host total).

Use the Swarm node description instead:

```
GET /api/cluster.getNodes → [0].Description.Resources.MemoryBytes / .NanoCPUs
```

**Read it as the LXC's cgroup cap, not the host's RAM.** 2026-09-20: `cluster.getNodes` reported 6.44 GB for a host whose `/proc/meminfo` said 21.4 GiB — the 6.44 GB is *correct*: the Dokploy node is LXC 100 `dokploy.homelab.local` (`192.168.1.42`) on pve `192.168.1.5` (Ryzen 5 PRO 3400G, 21.9 GiB, 8 threads) with `pct config 100` showing `memory: 6144` / `cores: 4`. Without lxcfs the container's `/proc/meminfo` leaks the **host's** totals, so a probe container reports 21.4 GiB while the enforceable budget is 6 GiB. Authoritative reads: `pct config 100` (and `pct exec 100 -- docker stats --no-stream`) from pve over SSH — far better than a probe container. Verified 2026-09-20 live: LXC 100 had ~4.2 GiB used by 20 containers (dokploy 858M, omniroute 831M, postiz 715M, rakazo api/worker 477M/417M…), leaving ~1.8 GiB, and `host.docker.internal:3000` / `dokploy:3000` API callbacks from a probe container produced **no** report (the `compose.one` description stayed empty) — see "Reading data OUT".

Verified 2026-09-14: the `Apps` host is a **single-node swarm, 3 GiB RAM / 4 cores**

**Measurement channel that works** (temp compose + a live HTTP service): `python:3.12-alpine` serving `/proc/meminfo`, `/proc/loadavg`, `/proc/pressure/{memory,cpu,io}` on port 8000, plus `POST /api/domain.create {host: "memprobe.blugg.pt", path: "/", port: 8000, https: true, certificateType: "letsencrypt", domainType: "compose", composeId, serviceName: <svc>}` — readable at `https://memprobe.blugg.pt/` within ~10 s of the deploy, which also proves a new compose is routable. Delete the domain (`domain.byComposeId` → `domain.delete`) **and** the compose afterwards: temp composes keep the API token in `env`. Note this is also the only reliable way to read container output — see "Reading data OUT".

Verified 2026-09-14: the `Apps` host is a **single-node swarm, 3 GiB RAM / 4 cores** (Dokploy v0.30.5, Engine 28.5.0), already running ~13 containers (postiz + postgres/redis, listmonk + postgres, pyrodactyl panel + mariadb + redis, stash, executor, cli-proxy-api ×2, postgres 18).

Consequence: **anything with a ≥2 GiB floor cannot go here** — it OOM-kills neighbours. Prefer Go/Rust/Python statics over Next.js apps on this box, and always set a Swarm memory limit on new services so a runaway can't starve prod.

Services evaluated and rejected for capacity (check the node spec FIRST, then answer):
- **Rakazo** (2026-09-17, **deployed**): prod Compose declares postgres 2g + api 1536m + worker 2g + web 512m + caddy 256m ≈ 6.25 GiB of ceilings; the images variant adds a 512m supervisor plus **2g per bot-computer container**. Postgres + 3 always-on Node processes cannot coexist with the 12 live containers on 3 GiB — Pedro scaled the node to 6 GiB / 8 cores and it then ran comfortably at 1024/1280/896/448M caps. Extra Dokploy frictions, all handled: its Caddy binds 80/443 (Traefik owns those) so drop Caddy and point the domain at the web service port; Swarm ignores `depends_on`, so wrap the api command as a bounded retry loop around `prisma migrate deploy` before `exec`ing the server; `SANDBOX_PROVIDER=docker` needs `/var/run/docker.sock` (root-equivalent) inside a Swarm task spawning sibling non-Swarm containers, so deploy `none`/`e2b` instead. Compose `rakazo` = `loiW7P2UTKzpUaT3w5_NN`, appName `rakazo-6vnete`, origin `rakazo.blugg.pt` → `web:5173`; build files and secrets under `/root/rakazo/`. Note `ghcr.io/elie222/rakazo/app` publishes only `edge` — no `v*` tags and no `latest`. To enable the in-stack Docker computer provider, mirror the services from `docker-compose.images.yml` (`computer` pull-only stub, `data-init`, `supervisor`) and **set `SANDBOX_SUPERVISOR_TOKEN` on the api and worker too — not just the supervisor.** Miss it and `resolveSandboxProvider` (packages/adapters) silently returns `none` in production rather than failing, so the UI shows "Computers are off" with no error anywhere. Verify the way upstream docs prescribe, but note the API's `/health` is NOT reachable through the web proxy (`/api/*` and `/rpc/*` are the only proxied prefixes, and `/health` falls through to the SPA): run a one-shot container on the stack's `app` network that fetches `http://api:3100/health` and reports back through the Dokploy-API channel. Expect `"sandbox":"docker"`; the supervisor's own `/health` returns the computer image it will use. Cap `RAKAZO_COMPUTER_MEMORY`/`CPUS`/`SANDBOX_MAX_COMPUTERS_PER_SPACE` on a small host — each bot is a Chromium desktop. Note bot containers are created by the supervisor outside the Dokploy stack, so a Dokploy Docker prune can remove them (their state lives in appdata subdirs, so they get recreated).

## Swarm deploy details (verified 2026-09-14, OmniRoute)

- **`deploy.resources.limits.memory` IS honoured** by Dokploy's Swarm deploy — verified via `GET /api/docker.getConfig?containerId=` → `HostConfig.Memory` (exactly 1280 MiB / 128 MiB as written). Use it to cage a new service so it cannot OOM-kill neighbours; `mem_limit` is silently ignored in Swarm mode.
- **`compose.create` auto-suffixes `appName`** even when `randomize: false` (`omniroute` became `omniroute-ruy81r`). Container and volume names follow the suffixed appName; the domain still resolves via `serviceName`. Read the real appName back from `compose.one` before matching containers.
- A Traefik-fronted service is placed on **`dokploy-network`** — visible in the container's `NetworkSettings.Networks`. No `ports:` needed; the domain's target port is the container port.
- **An app that binds loopback gets a 502 from Traefik**, because ingress arrives from another namespace. For Next.js standalone images set `HOSTNAME=0.0.0.0` explicitly (OmniRoute ships loopback-first since #12568) — confirmed working.
- Behind TLS termination also set `AUTH_COOKIE_SECURE=true`, else the session cookie isn't marked Secure and dashboard auth misbehaves; and prefer explicit `NEXT_PUBLIC_BASE_URL` over `OMNIROUTE_TRUST_PROXY` (forwarded headers come from Traefik, not a token-stamped loopback peer, so trust mode won't match).
- Deploy of a 1.2 GB image: pull + start took ~65 s end to end. Logs: `GET /api/deployment.readLogs?deploymentId=&tail=200` — the `deploymentId` is NOT in the `compose.deploy` response (only `{composeId,message,success}`); read it back from `deployment.allByCompose`.

## Compose stacks deploy as standalone compose, NOT Swarm services (verified 2026-09-20)

A `composeType: docker-compose` stack lands as plain `docker compose` containers inside LXC 100: names are `appName-service-1`, each stack gets its **own bridge network** (`appName_default`), `docker service ls` stays empty for it, and the Traefik ingress story still applies when a domain is attached. Consequences that matter:

- `depends_on` **does** work here (unlike the Swarm path), and `deploy.resources.limits` **is** applied — verified with `docker inspect --format '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}} {{.HostConfig.RestartPolicy.Name}}'` → exactly `1342177280` / `2000000000` / `on-failure` as written. So the documented `mem_limit`/`cpus` keys are still wrong (Compose-2 legacy) but `deploy.resources.limits` is honoured.
- Service-name collisions across stacks are not a real risk while every stack owns a bridge network; prefix anyway (`fc-redis`, `fc-postgres`) so logs and `docker stats` stay readable.
- **`compose.saveEnvironment` only feeds `${VAR}` interpolation.** A variable that must reach a *container* has to be listed in that service's `environment:` block. Putting `NUQ_WORKER_COUNT=1` in the stack env alone changed nothing in the container and cost a deploy cycle — check with `docker exec <c> env | grep NAME` or `docker inspect --format '{{range .Config.Env}}...'` (mask secrets, compare sha256 of the value instead of printing it).
- Reach a stack's port from another LAN host with long-syntax `mode: host` publishing (`target/published/protocol/mode`); verified working from the pve network to LXC 100 on 3002/8080 and inside the LXC via `curl localhost:PORT`.

### Self-hosted Firecrawl + SearXNG (the pattern that works)

Images: `ghcr.io/firecrawl/firecrawl:<semver>` (semver tags only — no `latest`; `2.10.19` verified), `ghcr.io/firecrawl/playwright-service:latest`, `ghcr.io/firecrawl/nuq-postgres:latest`, `redis:alpine`, `rabbitmq:3-management`, `searxng/searxng:latest`. `USE_DB_AUTHENTICATION=false` needs no key, and Hermes' firecrawl provider accepts a **keyless** self-hosted URL (`firecrawl-py` only demands a key when `api_url` contains `api.firecrawl.dev`), so `FIRECRAWL_API_URL` is the whole integration — but the API is unauthenticated, so publish it on LAN only, never behind a public domain.

Pitfalls that cost real time:

1. **`fc-api` OOM-kills against a tight cap (exit 137), and trimming workers is NOT enough.** `harness.js` fans out ~10 node children (`api`, `worker`, `extract-worker`, `nuq-worker-0..4`, `nuq-prefetch-worker`, `nuq-reconciler`). `NUQ_WORKER_COUNT` (config default **5**) is the knob and belongs in the service `environment:` block, not the stack `.env` — but even at `1` the tree peaked at *exactly* the 1280M cap (`/sys/fs/cgroup/memory.peak` = 1342177280, `memory.events max 17742`) and the kernel killed the `api` child before it ever bound port 3002. Measured per-process RSS at startup: api 268M, nuq-worker 248M, extract-worker 241M, queue-worker 221M, reconciler 210M, prefetch 52M.
   **Working design: don't run the harness at all.** Give the same image two services with explicit commands — `fc-api` = `["node","dist/src/index.js"]` (640M limit, publishes 3002) and `fc-worker` = `["node","dist/src/services/worker/nuq-worker.js"]` (768M, `NUQ_WORKER_PORT=3006`) — and drop extract/prefetch/reconciler (they serve `/v2/extract` and crawl housekeeping, which a scrape-only client never touches). Steady state for the whole 7-container stack: api 297M, worker 242M, playwright 366M, rabbit 146M, searxng 115M, postgres 84M, redis 6M ≈ **1.25 GiB**, leaving the LXC at 4.35/6 GiB used. Verify with `docker stats --no-stream` and confirm Playwright is really in the path by grepping its log for `Navigating to <url>` after a JS-heavy scrape (HN proved it).
2. **A failed child kills the whole container**: any child exiting non-zero makes the harness shut everything down, so the surfaced error is just `X failed with exit code N`. Fix the child, don't chase the harness.
3. **Postgres auth: never trust a loopback test.** The official postgres image trusts loopback (`host all all 127.0.0.1/32 trust`), so `psql -h 127.0.0.1` succeeding inside the container proves nothing about credentials. A role/volume password mismatch presents as `28P01 password authentication failed for user "postgres"`. Verify over TCP (`psql -h <service-name>`) and repair in place with `ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD'` run through the container's own env (never echo the secret).
4. Pin the queue URL yourself: set `NUQ_DATABASE_URL` **and** `NUQ_DATABASE_URL_LISTEN` to `postgres://postgres:${POSTGRES_PASSWORD}@fc-postgres:5432/postgres` so the harness's "Setting up NUQ PostgreSQL connection for docker-compose" step doesn't re-derive it (it logs `NUQ_DATABASE_URL is already set, respect it` and moves on).
5. SearXNG needs `search.formats: [html, json]` or `/search?format=json` answers 403, and `limiter: false` for container clients. Write `settings.yml` at container start (`entrypoint: ["/bin/sh","-c"]` + `printf … > /etc/searxng/settings.yml` + `exec /usr/local/searxng/entrypoint.sh`) — do **not** bind-mount it, since relative binds are lost on recreate. Set `GRANIAN_HOST=0.0.0.0` because the image defaults to `::`.
6. Force the whole script through SSH+`pct exec`+`docker exec` without quote hell by base64-ing the inner script: `ssh pve "pct exec 100 -- sh -c 'echo <b64> | base64 -d | docker exec -i <ctr> sh'"`.

## Apps project IDs (verified 2026-09-14)

- Project `Apps` = `fXPop9_QpllwoCKOs8XKa`; environment `production` = `Osg7u2MPzWB4-HITEPUaw`.
- Compos es: `cli-proxy-api` a0-YaLsswF5wVCbfLlLTr · `executor` 3hf8YTp03yKx9bkPcSI00 · `stash` MCLxZItEqgiOWdvk3Yja1 · `pyrodactyl` wcULAeJ6Hi8fgcPhI6PYb · `litellm` CKGo3xYZtTzPH92yZfeI6.
- Project `Projects` = `hSd1i74G7eEz4VH2IRPZW`, env `production` = `CH5swN4AczGiQDW_w9U47` (compose `ztube`, app `studyquest-api`).
- `project.all` compose entries do **not** carry `appName`/`sourceType`/`composeType` — those come back `null`; don't key off them.

## Management boundary: host Docker is not Dokploy-managed

A stack started with `docker compose` directly on the Dokploy LXC is **not** a Dokploy app. It will run on the same Docker daemon but remain absent from the dashboard, deployment history, and Dokploy lifecycle controls. When the user asks to put something "in Dokploy," create a raw Compose record through `compose.create`, set `sourceType: raw` with `compose.update`, deploy through `compose.deploy`, and verify the exact `composeId` through both `compose.one` and `deployment.allByCompose`. Docker containers alone are insufficient proof.

Dokploy invokes `docker compose` from inside the Dokploy container. Absolute host paths work for service `volumes:` because the Docker daemon resolves bind sources, but an absolute `env_file:` is read client-side and can fail as "not found" even when the file exists on the LXC host. Store secrets with `compose.saveEnvironment` and reference `env_file: .env`, or explicitly interpolate saved variables into each service's `environment:` block. Verify `compose.one.env` is non-empty without printing its secret contents.

When converting an existing direct stack to Dokploy ownership, preserve explicit named volumes, create/update the Dokploy record before downtime, stop the direct project to release ports and container names, deploy the managed record, then read back the Dokploy deployment and Docker Compose project labels before removing rollback artifacts.

## Deploy recipe (compose, raw source)

1. `POST /api/compose.create` body: `{name, appName, description, composeType: "docker-compose", composeFile, environmentId}`.
   - **PITFALL: sourceType defaults to github → deploy fails in ~35ms with `❌ Github Provider not found`.** Always follow with `POST /api/compose.update {composeId, sourceType: "raw"}` (include composeFile again) before deploying.
2. Env: `POST /api/compose.saveEnvironment {composeId, env: "KEY=v\n..."}`. Referenced in compose as `${KEY}` (escape `$$` for shell literals).
3. Domain: `POST /api/domain.create {host, path: "/", port: <container port>, https: true, certificateType: "letsencrypt", domainType: "compose", composeId, serviceName: <service name>}`. *.blugg.pt is a Cloudflare-proxied wildcard — DNS needs no changes.
4. Deploy: `POST /api/compose.deploy {composeId, title, description}` → response has `deploymentId` (if missing, GET `deployment.allByCompose`).
5. Poll `GET /api/deployment.allByCompose?composeId=` → `status` running|done|error. On error: `GET /api/deployment.readLogs?deploymentId=&tail=200`.

## GHCR pulls can fail host-wide from a stale stored credential

A compose deploy can die in the pull phase with `Head "https://ghcr.io/v2/<owner>/<repo>/manifests/<tag>": denied: denied` even though the package is public and pulls fine anonymously from another host. The deploy log shows **no `docker login` step**, and Docker Hub images pull normally — so it is not networking and not the package.

Cause: the Dokploy container (which runs `docker compose` against the host socket) keeps a **persistent `~/.docker/config.json`** from an older registry login. `$GET /api/registry.all` exposes the org's registry entries (`registryName`, `username`, masked `password`) — a June-created `ghcr.io` entry whose PAT has since been revoked makes Docker send dead credentials on *every* ghcr pull, and GHCR answers 401, surfaced as `denied: denied`. Note the entry can be attached to **no** service (`registryId: null` everywhere) and still poison pulls.

**Diagnose, don't assume**: deploy a throwaway one-service compose pulling an unrelated, definitely-public ghcr image (e.g. `ghcr.io/jqlang/jq:latest`), read the log, then `compose.delete`. Verified 2026-09-17: `jqlang/jq` failed identically to the target image → host-wide, not package-specific. Also worth knowing: the org registry entry is **not** the only possibility — confirm whether the denial also hits public images before blaming the package.

**Fix WITHOUT host access (verified 2026-09-17): `POST /api/registry.testRegistry` performs a real `docker login` inside the Dokploy container, overwriting the poisoned entry.** Body: `{username, password, registryUrl: "ghcr.io", registryType: "cloud"}` (all four required; `registryType` must be exactly `cloud`). Pass a credential GHCR accepts — a plain `gh auth token` (`gho_…`, even without `read:packages`) is enough for public images: the token endpoint returns 200. Redeploy immediately after; the pull then succeeds. Note this does **not** update the stored registry entry (`registry.all` still shows the old masked password), so the entry must still be re-saved with a real PAT in the UI or an app that later attaches it will re-break pulls.

Host-side alternatives (`docker logout` alone suffices, anonymous ghcr pulls work):

```bash
docker exec -it dokploy sh -c 'cat ~/.docker/config.json'   # inspect
docker exec -it dokploy sh -c 'docker logout ghcr.io'       # stale entry gone -> anon pull
# or re-auth with a PAT that has read:packages:
docker exec -it dokploy sh -c 'docker login ghcr.io -u <user>'
```

Docker Hub pulls are unaffected, so a mirror to a reachable registry is a workaround when no PAT/host access is available. Compose has no `registryId` field (unlike applications), so a compose deploy never triggers the login that would refresh this credential — which is exactly why the stale entry persists unnoticed.

## Reading data OUT of a one-shot container (verified 2026-09-17)

There is **no container-logs API** (`docker.getContainerLogs`, `docker.getLogs`, `docker.getContainerConfig` all 404 on v0.30.5) and a raw compose's Traefik **labels are inert** — Dokploy routes only via its own `domain.create` records, and a freshly created domain still 404s at Traefik even after a redeploy. So a one-shot container's stdout is unreadable by every passive route.

What works, and what doesn't:

- ✗ Container stdout/stderr — nothing exposes it.
- ✗ Compose deploy log for a post-start failure — `up -d` reports `Container X Started` and nothing more; the daemon's exec error never reaches the log.
- ✓ **Dependency failure IS logged** — but only the exit code: `service "doctor" didn't complete successfully: exit 4`. That is a 1-byte channel (exit codes are readable from `docker.getContainersByAppNameMatch` as `Exited (N)`), useful for pass/fail, not for payloads.
- ✓ **The container calls the Dokploy API itself.** Mount the volume, do the work, then `POST /api/compose.update {composeId, description: report}` (and `compose.saveEnvironment` as a second sink). The container has outbound network, so it reaches `https://dash.blugg.pt` with `x-api-key` + a browser UA, and you read the report back via `compose.one`. This is how the Executor reset was diagnosed.
  **2026-09-20 caveat: this can fail silently.** A one-shot `curlimages/curl` probe posting to `http://host.docker.internal:3000`, `http://dokploy:3000` (with `networks: [dokploy-network]` + `extra_hosts` host-gateway) and `https://dash.blugg.pt` left the description untouched on every attempt, and the container still exited 0 (each `curl` behind `$(...)` swallows its own status), so the failure is invisible. When you need container-side data, don't fight this channel: run a **long-lived** HTTP service in the temp compose and read it back through a Traefik domain (recipe in "Host sizing") — end-to-end readable in under a minute. Keep exit codes as a 1-byte fallback (`Exited (N)`), and make diagnostic containers exit 0 so `depends_on: service_completed_successfully` dependents still run.

Gotchas found the hard way:
- Escape `$` as `$$` in any compose-embedded script (Compose interpolates `${...}` inside `entrypoint`/`command`, silently gutting JS template literals).
- A service that exits non-zero blocks anything with `depends_on: condition: service_completed_successfully`, and the blocked dependent never runs — so make diagnostic containers always exit 0 and encode state in the report, not the exit code.
- **`new Database(path, { create: false })` throws `bad parameter or other API misuse` (SQLITE_MISUSE) in bun:sqlite 1.3.14.** Open with no options. This masqueraded as a lock/BUSY problem for several runs because it only reproduces inside the container's bun version.
- Writing an app's SQLite file requires the app **stopped** (`compose.stop` → write → `compose.start`); `stop` returns true immediately and the container shows `Exited (137)` within ~4 s. Always `fs.copyFileSync` a timestamped backup before writing.
- Temp composes that carry secrets (API tokens, app passwords) must be **deleted**, not just stopped — the values persist in the compose `env`/`description` otherwise.

### Executor self-host specifics

Single container, whole product over one libSQL file: DB at `/data/data.db` in named volume `<appName>_executor-data` (e.g. `apps-executor-dnn2oh_executor-data`). Users/passwords are better-auth's `account` table (`providerId='credential'`) as `${salt}:${hex(scrypt(pw, salt))}` with salt = 16 random bytes hex, `N=16384, r=16, p=1, dkLen=64`, and the salt is used as its **hex string** (UTF-8 bytes), not decoded. Node's `crypto.scryptSync` reproduces it exactly — verify against `verifyPassword` from `@better-auth/utils` before writing anything. `EXECUTOR_BOOTSTRAP_ADMIN_EMAIL/PASSWORD` are **first-boot only**: `seedOrgAndAdmin` returns early once an `organization` row exists, so they cannot reset an existing account. There is no self-serve password reset in the UI and no email provider configured by default.

## Paperclip instance (verified 2026-09-28)

Dokploy raw compose `paperclip`: composeId `xEX4ZMnS3l_bMmGenAN7u`, appName `apps-paperclip-xh89vz`, URL `https://paperclip.blugg.duckdns.org`, sourceType `raw`, composeType `docker-compose`. Two services: `ghcr.io/paperclipai/paperclip:latest` on internal port 3100 and `postgres:17-alpine`; named volumes `apps-paperclip-xh89vz_paperclip-data` (`/paperclip`) and `apps-paperclip-xh89vz_postgres-data`. Running image reports version `2026.916.1`, commit `d554c4789ed3930f8a53ac9fdf6503b3187097da`, digest `sha256:a02ac35ac41df911af477422ea0e781cf41d2b2c600c66f0a5ac9d8c63f52c2c`. App-native PostgreSQL backups run every 60 minutes, retain 7 days, and live under `/paperclip/instances/default/data/backups`; preserve both named volumes because the `/paperclip` volume also holds the local secret master key.

Operational cautions: the app is configured `authenticated` + `private` while its public DNS/TLS route is reachable from the internet; external IPs have already hit auth endpoints. Either make ingress private or switch to `authenticated` + `public` and pass Paperclip's stricter checks. The compose uses mutable `latest`, has no CPU/memory limits, and the Paperclip service has no Docker healthcheck; observed steady usage was ~603 MiB app + ~93 MiB Postgres. A current upstream defect/noisy stale state emits three setup-token lease-release failures every 30 seconds: five timed-out adapter auth sessions (`claude_local` 3, `codex_local` 2) all have blank `provider_lease_id`, while `environment_leases` is empty; PostgreSQL rejects the resulting empty-string UUID lookups. Diagnose/fix this before treating logs as healthy. The app `/api/health` still reports `status: ok`, auth-gated APIs return 401/403 anonymously, and automatic DB backup status is healthy.

## Putting a Dokploy compose app behind Tailscale (verified pattern)

Goal: a service reachable only from the tailnet, no public Traefik route. Add a Tailscale sidecar service to the same compose, on the compose default network, and proxy with `tailscale serve`.

```yaml
  tailscale:
    image: tailscale/tailscale:latest
    restart: unless-stopped
    hostname: <app>
    environment:
      TS_HOSTNAME: <app>            # becomes <app>.<tailnet>.ts.net
      TS_STATE_DIR: /var/lib/tailscale
      TS_USERSPACE: "false"          # kernel TUN; better perf than the userspace default
      TS_SERVE_CONFIG: /config/serve.json
    volumes:
      - tailscale-state:/var/lib/tailscale
      - /etc/dokploy/compose/<appName>/tailscale:/config:ro   # ABSOLUTE path
    devices:
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
    healthcheck:
      test: ["CMD-SHELL", "pgrep -x tailscaled >/dev/null || exit 1"]
```

`serve.json` (containerboot substitutes `${TS_CERT_DOMAIN}`, and the mount must be a **directory**, not a single file, or fsnotify change detection breaks):

```json
{"TCP":{"443":{"HTTPS":true}},"Web":{"${TS_CERT_DOMAIN}:443":{"Handlers":{"/":{"Proxy":"http://<compose-service>:<port>"}}}},"AllowFunnel":{"${TS_CERT_DOMAIN}:443":false}}
```

The proxy target resolves through Docker DNS on the shared compose network, so the sidecar must join that network (it does by default) and the target is the compose *service* name.

### Pitfalls that cost real time

- **Raw compose lives in the Dokploy DB, not on disk.** `sourceType=raw` means Dokploy regenerates `code/docker-compose.yml` from the `compose` table on every deploy, so hand-editing that file is lost. Update via `POST /api/compose.update` `{composeId, name, sourceType:"raw", composeType:"docker-compose", composeFile}` then `POST /api/compose.deploy {composeId}`. Adds/removes of unrelated services do not restart the app container; a domain change does (labels change).
- **Removing a public domain takes two steps.** `POST /api/domain.delete {domainId}` clears the row, but the Traefik router comes from the labels Dokploy writes at deploy time — the route survives until the next deploy. Verify with an external curl (expect Traefik 404) after redeploying.
- **Never give the sidecar a `hostname:` that matches the app's service name.** Docker registers a container's hostname as a network alias, so `hostname: paperclip` on the sidecar plus a service named `paperclip` makes DNS return two A records for `paperclip` — the app *and the sidecar itself*. `serve` then dials itself and every request 502s with `dial tcp <sidecar-ip>:<port>: connect: connection refused`. Use `TS_HOSTNAME` for the tailnet name and leave the compose `hostname` unset.
- **Dokploy compose env values only reach a container if the service's `environment:` block references them.** Setting a key in the Dokploy Environment tab without a matching `${KEY}` line silently leaves the variable unset inside the container (caught here by comparing the env inside the app against the API's stored env).
- **`/dev/net/tun` does not survive a CT restart** (`/dev` is tmpfs in the guest). Persist it inside the LXC with `/etc/tmpfiles.d/<name>.conf`: `c /dev/net/tun 0666 root root - 10:200` (the `-` age column is required; `10:200` in the age slot or `10 200` both fail). Kernel mode then works with no PVE config change and no container restart. Without an auth key, containerboot just logs an interactive login URL (`https://login.tailscale.com/a/...`) — hand that to the operator rather than pasting a key anywhere.
- **Never put `tailscale status` in a healthcheck.** While logged out, each probe asks the control plane for a fresh interactive login URL, rotating the link you are about to send. `pgrep -x tailscaled` is the safe liveness check.
- **Tailnet prerequisites** (admin console): MagicDNS on, and HTTPS certificates on for the `<app>.<tailnet>.ts.net` cert `serve` uses for port 443.

### Paperclip-specific: private-mode hostname guard

`authenticated` + `private` mode 403s any request whose Host is not allow-listed: `{"error":"This hostname is not allowed for this Paperclip instance..."}`. `/api/health` and loopback are exempt; the UI and other paths are not. The allow set is `PAPERCLIP_ALLOWED_HOSTNAMES` (comma-separated, **replaces** the config-file list when set) plus the hostname of `PAPERCLIP_PUBLIC_URL`, plus localhost/loopback. There is no wildcard support. Moving an instance to a new hostname therefore needs both `PAPERCLIP_PUBLIC_URL=https://<new-host>` and `PAPERCLIP_ALLOWED_HOSTNAMES=<new-host>,<lan-fallback-host>` before it is usable. `npx paperclipai allowed-hostname <host>` only edits `PAPERCLIP_CONFIG` and needs a server restart.

### Paperclip behind Tailscale — verified end state

`https://paperclip.taile58db.ts.net` (tailnet `0xz0uk.github`, node IP `100.88.77.2`), sidecar on kernel TUN, `authenticated` + `private` unchanged, public `paperclip.blugg.duckdns.org` route deleted (Traefik 404), LAN fallback `apps-paperclip-5bcb61-192-168-1-42.sslip.io` allow-listed. Verification that proves the whole chain without a second tailnet node: run a throwaway container in the sidecar's netns and pin the name to the tailnet IP —

```bash
docker run --rm --network container:apps-paperclip-xh89vz-tailscale-1 alpine:3.20 sh -c \
  'apk add --no-cache curl >/dev/null; curl -sS --resolve paperclip.taile58db.ts.net:443:100.88.77.2 -o /dev/null -w "%{http_code} tls=%{ssl_verify_result}\n" https://paperclip.taile58db.ts.net/'
```

Expect 200 with `tls=0` (cert verifies), `/api/health` 200, and `/api/companies` 403 `Board access required` — a *different* 403 text from the hostname guard's message.

## Instance conventions (verified)

- Swarm-mode compose: no `container_name`, `restart: unless-stopped` fine, relative bind mounts (`./data:/x`) resolve under `/etc/dokploy/compose/<appName>/` on the VPS and persist across redeploys.
- Traefik reaches containers on the internal network: publish only ports that need host/LAN/SSH-tunnel access; the domain target port is the CONTAINER port.
- Dokploy UI itself owns host port 3000 — never map 3000 in a service.
- `depends_on` is ignored by Swarm; services must self-heal startup order.

## Persistence PITFALLS (cost us the OAuth accounts once — don't repeat)

- **Relative bind mounts (`./data:/x`) live in Dokploy's per-deploy dirs and are LOST when a service is recreated by a compose change.** Use NAMED volumes (`cpa_data:/CLIProxyAPI/data` + top-level `volumes:` block). Verified durable across redeploys.
- Adding a second service (sidecar) recreates only changed services — but any recreation of the main service re-seeds a fresh mount. Check container `Up <time>` via `GET /api/docker.getContainersByAppNameMatch?appName=<appName>&filterType=all` after deploys.

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
- Plugin accounts (`go-1`/`go-2`) pair the two key-entries automatically; per-account success/fail counters in status. Quota dashboard (`usage_percent`) needs per-account OpenCode workspace_id + auth cookie via `POST /v0/management/plugins/opencode-go-pool/account-config` — not yet configured.
