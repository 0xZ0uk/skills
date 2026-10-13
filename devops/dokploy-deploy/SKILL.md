---
name: dokploy-deploy
description: "Deploy and operate services on Pedro's self-hosted Dokploy (Docker + Traefik in LXC 100 on the Proxmox homelab) through its REST API: create raw compose apps, attach domains, set env, read deployment logs, size against the LXC's memory, and fix known traps (sourceType defaults to github, env not reaching containers, lost bind mounts, GHCR 'denied: denied', no container-logs API). Use for any Dokploy deploy/redeploy, compose.* / domain.* API call, or app hosted there (Paperclip, Firecrawl, Executor, CLIProxyAPI, Rakazo, OmniRoute, Pyrodactyl)."
version: 2.0.0
author: Hermes
tags: [devops, dokploy, deploy, docker]
---

# Dokploy Deploy

Dokploy runs in LXC 100 (`192.168.1.42`) on the Proxmox host `192.168.1.5` (`proxmox-homelab-ops` covers general PVE operations).

## Access (verified 2026-10-04)

- **API:** `http://192.168.1.42:3000/api/<resource>.<action>`, header **`x-api-key: <token>`** (not `x-dokploy-token`; wrong header → `{"message":"Unauthorized"}`).
- **Domains:** `blugg.pt` is no longer owned and has no DNS — every `*.blugg.pt` name in older notes is dead, including the CLI's stored `https://dash.blugg.pt`. The public base is now `blugg.duckdns.org`; confirm a new hostname resolves (`dig +short <host>`) before relying on it.
- **Token:** the CLI (`/root/.local/share/pnpm/bin/dokploy`) stores `{url, token}` in `/root/.local/share/pnpm/store/v11/links/@dokploy/cli/*/node_modules/@dokploy/cli/config.json`. Read it in Python and pass it via a variable — never inline it in a shell command (redaction, history).
- When a CLI call 400s, call the REST endpoint directly to see the real error.
- Any route that goes through Cloudflare blocks non-browser User-Agents (`Python-urllib/3.x` → `403 error code: 1010`; OpenAI SDK UA → `403 Your request was blocked`). Scripted clients send a browser-like UA.

**Discover IDs, don't guess:** `GET /api/project.all` (environments → `compose[]` with `composeId`, `domains[]`), `GET /api/compose.one?composeId=` (includes `env` — the service's secrets), `GET /api/domain.byComposeId?composeId=`. `project.all` returns `appName`/`sourceType`/`composeType` as `null`; read those from `compose.one`. Last known IDs: `references/inventory.md`.

## Size before you deploy

The API has no metrics endpoint (`/api/monitoring.*`, `/api/metrics.*` 404; `docker.getConfig` is a per-container inspect where `HostConfig.Memory: 0` means unlimited). Use:

- `GET /api/cluster.getNodes` → `[0].Description.Resources.MemoryBytes` / `.NanoCPUs` — this is the **LXC's cgroup cap**, which is the real budget.
- Authoritative, from pve over SSH: `pct config 100` and `pct exec 100 -- docker stats --no-stream`. A probe container's `/proc/meminfo` shows the *host's* RAM (no lxcfs) and is misleading.

Never size from upstream docs alone. Total the new service's memory floor against current usage; anything that doesn't fit OOM-kills neighbours. **Always set `deploy.resources.limits`** on new services so a runaway can't starve prod.

## How compose apps actually run

| | `composeType: docker-compose` (the default here) | `composeType: stack` (Swarm) |
|---|---|---|
| Containers | plain `docker compose`, names `appName-service-1`, own bridge network `appName_default` | Swarm services |
| `depends_on` | works | **ignored** — services must self-heal startup order (e.g. bounded retry loop around migrations before `exec`) |
| Memory limits | `deploy.resources.limits` honoured (verified via `docker inspect`) | `deploy.resources.limits` honoured; `mem_limit` silently ignored |

Use `deploy.resources.limits` in both. Other facts that hold for both:

- `compose.create` **auto-suffixes `appName`** even with `randomize: false` (`omniroute` → `omniroute-ruy81r`). Container and volume names follow the suffixed name; read it back from `compose.one`.
- **Raw compose lives in the Dokploy DB.** `code/docker-compose.yml` on disk is regenerated every deploy; edit via `compose.update`, never by hand.
- **Traefik ingress:** services with a domain join `dokploy-network`; no `ports:` needed; the domain's port is the *container* port. Dokploy owns host port 3000 — never map it. Raw-compose Traefik labels are inert; only `domain.create` records route.
- **An app that binds loopback gets a 502** from Traefik. Next.js standalone images need `HOSTNAME=0.0.0.0`.
- To reach a port from the LAN without a domain, use long-syntax publishing with `mode: host`.
- Prefix service names per stack (`fc-redis`) so logs and `docker stats` stay readable.

## Env and persistence traps

- **`compose.saveEnvironment` only feeds `${VAR}` interpolation.** A variable reaches a container only if that service's `environment:` block references it. Verify with `docker exec <c> env` (compare a sha256 of secret values, never print them).
- Escape `$` as `$$` in compose-embedded scripts — Compose interpolates `${...}` inside `entrypoint`/`command`.
- An absolute `env_file:` path is read client-side inside the Dokploy container and can fail "not found"; use `env_file: .env` with saved env, or interpolate into `environment:`.
- **Relative bind mounts (`./data:/x`) are lost when a service is recreated** by a compose change. Use named volumes with a top-level `volumes:` block. (This lost the CLIProxyAPI OAuth accounts once.) Check `Up <time>` via `GET /api/docker.getContainersByAppNameMatch?appName=<appName>&filterType=all` after deploys.
- Temp composes that carry secrets must be **deleted**, not stopped — values persist in the compose `env`/`description`.

## Deploy recipe (raw compose)

1. `POST /api/compose.create` `{name, appName, description, composeType: "docker-compose", composeFile, environmentId}`.
2. **`POST /api/compose.update` `{composeId, sourceType: "raw", composeFile}`** — `sourceType` defaults to `github`, and the deploy fails in ~35 ms with `❌ Github Provider not found`.
3. `POST /api/compose.saveEnvironment` `{composeId, env: "KEY=v\n..."}`, referenced as `${KEY}` in each service's `environment:`.
4. `POST /api/domain.create` `{host, path: "/", port: <container port>, https: true, certificateType: "letsencrypt", domainType: "compose", composeId, serviceName}`.
5. `POST /api/compose.deploy` `{composeId, title, description}` — the response has **no** `deploymentId`.
6. Poll `GET /api/deployment.allByCompose?composeId=` for `status` running|done|error; on error `GET /api/deployment.readLogs?deploymentId=&tail=200`.

Removing a domain takes `domain.delete` **and a redeploy** — the Traefik route comes from labels written at deploy time. Verify with an external curl (expect Traefik 404).

**Only API-created records are Dokploy apps.** A stack started with `docker compose` directly on the LXC runs on the same daemon but is invisible to the dashboard, history and lifecycle controls. When asked to put something "in Dokploy", create it through the recipe above and verify the `composeId` via `compose.one` and `deployment.allByCompose` — running containers alone are not proof. To adopt an existing direct stack: keep its named volumes, create the Dokploy record first, stop the direct project to free ports/names, deploy the record, check the Compose project labels, then remove rollback artifacts.

## When things break

- **Pull fails with `denied: denied` on a public `ghcr.io` image** → a stale stored registry credential inside the Dokploy container poisons every GHCR pull. Diagnose with an unrelated public image, fix with `POST /api/registry.testRegistry`: `references/ghcr-stale-credential.md`.
- **You need a container's output** → there is no container-logs API. Use `docker logs` via `pct exec` on pve, or (API only) a temporary HTTP service behind a domain: `references/debugging-containers.md`.
- **Writing an app's SQLite file** → stop the app first and back up: `references/debugging-containers.md`.

## References

- `references/inventory.md` — last known project/environment/compose IDs and appNames.
- `references/ghcr-stale-credential.md` — GHCR `denied: denied` diagnosis and fix.
- `references/debugging-containers.md` — getting data out of containers; the memprobe measurement service; SQLite/bun gotchas.
- `references/tailscale-sidecar.md` — tailnet-only access with a Tailscale sidecar and `tailscale serve`.
- `references/second-hermes-agent-app.md` — running a second Hermes agent as its own Dokploy app.
- Per-app notes in `references/apps/`: `paperclip.md`, `firecrawl-searxng.md`, `executor.md`, `cliproxyapi.md` (CLIProxyAPI, OpenCode Go, go-pool plugin), `rakazo.md`, `omniroute.md`.
