# Putting a Dokploy compose app behind Tailscale (verified pattern)

Goal: a service reachable only from the tailnet, no public Traefik route. Add a Tailscale sidecar service to the same compose, on the compose default network, and proxy with `tailscale serve`.

```yaml
  tailscale:
    image: tailscale/tailscale:latest
    restart: unless-stopped
    # no `hostname:` — see pitfalls
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

`serve.json` goes in `/etc/dokploy/compose/<appName>/tailscale/` on the LXC — writing it needs host access (`pct exec 100 -- sh -c 'mkdir -p … && cat > …/serve.json'`); there's no Dokploy API for files outside the container. That directory sits beside `code/` (which Dokploy regenerates each deploy) and survived the redeploys in the verified setup. Contents (containerboot substitutes `${TS_CERT_DOMAIN}`, and the mount must be a **directory**, not a single file, or fsnotify change detection breaks):

```json
{"TCP":{"443":{"HTTPS":true}},"Web":{"${TS_CERT_DOMAIN}:443":{"Handlers":{"/":{"Proxy":"http://<compose-service>:<port>"}}}},"AllowFunnel":{"${TS_CERT_DOMAIN}:443":false}}
```

The proxy target resolves through Docker DNS on the shared compose network, so the sidecar must join that network (it does by default) and the target is the compose *service* name.

### Pitfalls that cost real time

- Adding the sidecar via `compose.update` + `compose.deploy` doesn't restart the app container; a domain change does (labels change). To drop the public route, `domain.delete` **and** redeploy (SKILL.md).
- **Never give the sidecar a `hostname:` that matches the app's service name.** Docker registers a container's hostname as a network alias, so `hostname: paperclip` on the sidecar plus a service named `paperclip` makes DNS return two A records for `paperclip` — the app *and the sidecar itself*. `serve` then dials itself and every request 502s with `dial tcp <sidecar-ip>:<port>: connect: connection refused`. Use `TS_HOSTNAME` for the tailnet name and leave the compose `hostname` unset.
- **`/dev/net/tun` does not survive a CT restart** (`/dev` is tmpfs in the guest). Persist it inside the LXC with `/etc/tmpfiles.d/<name>.conf`: `c /dev/net/tun 0666 root root - 10:200` (the `-` age column is required; `10:200` in the age slot or `10 200` both fail). Kernel mode then works with no PVE config change and no container restart. Without an auth key, containerboot just logs an interactive login URL (`https://login.tailscale.com/a/...`) — hand that to the operator rather than pasting a key anywhere.
- **Never put `tailscale status` in a healthcheck.** While logged out, each probe asks the control plane for a fresh interactive login URL, rotating the link you are about to send. `pgrep -x tailscaled` is the safe liveness check.
- **Tailnet prerequisites** (admin console): MagicDNS on, and HTTPS certificates on for the `<app>.<tailnet>.ts.net` cert `serve` uses for port 443.
