# Paperclip

IDs, URLs and the last observed version: `../inventory.md`.

## Shape

Raw compose, two services: `ghcr.io/paperclipai/paperclip` (internal port 3100) and `postgres:17-alpine`, each with a named volume. **Preserve both volumes** — the `/paperclip` volume also holds the local secret master key. App-native PostgreSQL backups run hourly, keep 7 days, under `/paperclip/instances/default/data/backups`. Observed steady usage ~600 MiB app + ~95 MiB Postgres; add `deploy.resources.limits` and a healthcheck (upstream ships neither) and pin a tag rather than `latest`.

`/api/health` returns `status: ok` even when logs are noisy; anonymous calls to auth-gated APIs return 401/403.

## Private-mode hostname guard

`authenticated` + `private` mode 403s any request whose Host is not allow-listed: `{"error":"This hostname is not allowed for this Paperclip instance..."}`. `/api/health` and loopback are exempt; the UI and other paths are not.

The allow set is `PAPERCLIP_ALLOWED_HOSTNAMES` (comma-separated; **replaces** the config-file list when set) + the hostname of `PAPERCLIP_PUBLIC_URL` + localhost/loopback. No wildcards. Moving to a new hostname needs both `PAPERCLIP_PUBLIC_URL=https://<new-host>` and `PAPERCLIP_ALLOWED_HOSTNAMES=<new-host>,<lan-fallback-host>`. `npx paperclipai allowed-hostname <host>` only edits `PAPERCLIP_CONFIG` and needs a restart.

Don't expose a `private`-mode instance on a public route — either keep ingress private (Tailscale, below) or switch to `authenticated` + `public` and pass its stricter checks.

## Behind Tailscale

Use the sidecar pattern in `../tailscale-sidecar.md`. To prove the whole chain without a second tailnet device, run a throwaway container in the sidecar's network namespace and pin the name to the node's tailnet IP:

```bash
docker run --rm --network container:<appName>-tailscale-1 alpine:3.20 sh -c \
  'apk add --no-cache curl >/dev/null; curl -sS --resolve <host>.<tailnet>.ts.net:443:<tailnet-ip> -o /dev/null -w "%{http_code} tls=%{ssl_verify_result}\n" https://<host>.<tailnet>.ts.net/'
```

Expect 200 with `tls=0` (cert verifies), `/api/health` 200, and `/api/companies` 403 `Board access required` — a different 403 text from the hostname guard's.
