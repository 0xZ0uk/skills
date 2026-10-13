# Debugging containers: getting data out, measuring the host

Dokploy v0.30.5 has **no container-logs API** (`docker.getContainerLogs`, `docker.getLogs`, `docker.getContainerConfig` all 404), and the compose deploy log stops at `Container X Started` — a post-start failure never reaches it. So a container's stdout is unreadable through the API. Pick a channel:

## 1. With host access (best): go through pve

```bash
ssh root@<pve> "pct exec 100 -- docker logs --tail 100 <appName>-<service>-1"
```

For anything with quotes, base64 the inner script to avoid three layers of escaping:
`ssh <pve> "pct exec 100 -- sh -c 'echo <b64> | base64 -d | docker exec -i <ctr> sh'"`.

## 2. API only: a temporary HTTP service behind a Dokploy domain (verified 2026-09-14)

Deploy a temp compose whose service serves what you need over HTTP — e.g. `python:3.12-alpine` serving `/proc/meminfo`, `/proc/loadavg`, `/proc/pressure/{memory,cpu,io}` on port 8000 — and attach `POST /api/domain.create {host: "<probe>.<base-domain>", path: "/", port: 8000, https: true, certificateType: "letsencrypt", domainType: "compose", composeId, serviceName: <svc>}`. It was readable within ~10 s of the deploy, which also proves a new compose is routable.

One run (2026-09-17) saw a fresh domain still 404 after a redeploy — if that happens, re-check the domain's `serviceName` and container port before assuming the channel is broken.

Clean up both the domain (`domain.byComposeId` → `domain.delete`) **and** the compose afterwards.

## 3. Fallback: exit codes (1-byte channel)

`docker.getContainersByAppNameMatch` shows `Exited (N)`, and a failed dependency is logged as `service "doctor" didn't complete successfully: exit 4`. Good for pass/fail, not payloads. A service that exits non-zero blocks anything with `depends_on: condition: service_completed_successfully` — make diagnostic containers exit 0 unless you are deliberately using the code as the signal.

## Not recommended: the container posting back to the Dokploy API

Writing a report into `compose.update {description}` from inside the container worked once, but a 2026-09-20 retry against `host.docker.internal:3000`, `dokploy:3000` (on `dokploy-network`) and the public URL left the description untouched every time — while the container exited 0, because `$(curl …)` swallows curl's status. Use channel 1 or 2.

## SQLite and bun gotchas

- Writing an app's SQLite file requires the app **stopped**: `compose.stop` (returns immediately; `Exited (137)` within ~4 s) → back up with a timestamped `fs.copyFileSync` → write → `compose.start`.
- `new Database(path, { create: false })` throws `bad parameter or other API misuse` (SQLITE_MISUSE) in bun:sqlite 1.3.14 — open with no options. It masqueraded as a lock/BUSY problem because it only reproduced with the container's bun version.
