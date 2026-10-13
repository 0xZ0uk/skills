# Rakazo (deployed 2026-09-17)

IDs and paths: `../inventory.md`. Image `ghcr.io/elie222/rakazo/app` publishes only `edge` — no `v*` tags, no `latest`.

## Sizing

Upstream prod compose declares postgres 2g + api 1536m + worker 2g + web 512m + caddy 256m ≈ 6.25 GiB of ceilings, plus a 512m supervisor and **2g per bot-computer container** in the images variant. It runs comfortably at api/worker/web/postgres caps of roughly 1024/1280/896/448M — check current LXC headroom first (SKILL.md "Size before you deploy"). Cap `RAKAZO_COMPUTER_MEMORY`, `RAKAZO_COMPUTER_CPUS` and `SANDBOX_MAX_COMPUTERS_PER_SPACE` — each bot is a Chromium desktop.

## Dokploy adaptations

- Drop the bundled Caddy (it binds 80/443, which Traefik owns) and point the domain at `web:5173`.
- Wrap the api command in a bounded retry loop around `prisma migrate deploy` before `exec`ing the server, so startup doesn't depend on postgres being ready first.

## Sandbox provider

Never mount `/var/run/docker.sock` (root-equivalent) into the api or worker.

- **Without computers:** `SANDBOX_PROVIDER=none` (or `e2b`). Setting `docker` here, with no supervisor, would require the socket in the api.
- **With the in-stack Docker computer provider:** the supervisor owns Docker access and the api talks to it. Mirror the services from upstream `docker-compose.images.yml` (`computer` pull-only stub, `data-init`, `supervisor`), copy the `SANDBOX_*` variables for api/worker exactly as that file sets them, and **set `SANDBOX_SUPERVISOR_TOKEN` on the api and worker too, not just the supervisor.** Without it, `resolveSandboxProvider` (packages/adapters) silently returns `none` in production and the UI shows "Computers are off" with no error.
- Bot containers are created by the supervisor outside the Dokploy stack, so a Docker prune can remove them; their state lives in appdata subdirs and they get recreated.

## Verifying

The api's `/health` is not reachable through the web proxy (only `/api/*` and `/rpc/*` are proxied; `/health` falls through to the SPA). Check it from inside the stack network (Rakazo's compose defines its own `app` network, hence `<appName>_app` rather than `_default`):

```bash
ssh root@<pve> "pct exec 100 -- docker run --rm --network <appName>_app curlimages/curl -s http://api:3100/health"
```

Expect `"sandbox":"docker"` when computers are enabled; the supervisor's own `/health` reports the computer image it will use.
