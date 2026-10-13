# A second Hermes Agent as its own Dokploy app

Pattern for running another Hermes agent (a scoped, different-audience agent — see the `hermes-agent` skill bundled with Hermes, `references/multi-profile-and-distributions.md`) beside the main one, as an independent Dokploy compose app rather than a second profile in the same container.

Verified 2026-10-04 by deploying an agent for a panel's tenants.

## Why its own app, not a second profile

The main `hermes` container mounts `/var/run/docker.sock` — inside it, the agent can drive the whole Docker daemon, which is effectively root on the LXC. A second profile in that same container inherits that. A separate compose app gives the new agent its own filesystem, its own `.env`, and its own resource limits. That is the isolation boundary; `terminal.backend: docker` is neither available (no socket) nor wanted there — inside its own container, `backend: local` already means "sandboxed".

Corollary: do **not** mount the docker socket into a chat-facing agent's container.

## Layout: flat home, not a nested profile

A profile directory under `profiles/` is a *secondary* profile: `hermes -p <name> gateway run` refuses to start, because a secondary profile is expected to be served by the default profile's gateway ("Starting a separate gateway for this profile would double-bind its platforms").

For a dedicated single-agent container, lay the agent out **flat at the home root** — it becomes the default profile and plain `gateway run` works:

```
/srv/<app>/root/.hermes/          <- HERMES_HOME=/opt/data
  config.yaml  SOUL.md  profile.yaml  distribution.yaml  .gitignore  README.md
  skills/<category>/...           <- the pruned set only
```

`command: ["gateway", "run"]`, no `-p`. (The image's `main-wrapper.sh` does support a leading `-p <profile>` if you ever do want the nested form.)

## Compose file that works

```yaml
services:
  <app>:
    image: nousresearch/hermes-agent@sha256:<same digest as the main stack>
    restart: unless-stopped
    command: ["gateway", "run"]
    working_dir: /root
    environment:
      HERMES_HOME: /opt/data
      HOME: /root
      PUID: "10000"
      PGID: "10000"
      PATH: /root/.hermes/node/bin:/root/.local/bin:/opt/hermes/bin:/opt/hermes/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
      PANEL_URL: ${PANEL_URL}
      # ...one line per secret
    volumes:
      - /srv/<app>/root/.hermes:/opt/data
      - /srv/<app>/root:/root
    shm_size: 512mb
    deploy:
      resources:
        limits:
          memory: 1536M
          cpus: "1.0"
```

- No `ports:` — a Discord/Telegram bot is outbound-only. Nothing to route through Traefik.
- `PUID`/`PGID` 10000 matches the host dir ownership after `chown -R 10000:10000`.
- Sizing: an idle single-profile gateway sits around **250 MB**; a busy one with sessions can pass 700 MB. 1536M leaves real headroom. Check `docker stats` and `cluster.getNodes` before picking the number.
- Dokploy interpolates saved env into the service `environment:`, so **secrets live in Dokploy's env store**, not in an on-disk `.env` inside the mounted home. Read an existing secret out of the host `.env` in Python and write it into Dokploy without printing it.

## Deploy sequence (API)

Follow the raw-compose recipe in SKILL.md. Specific to this app:

- `appName` is effectively immutable after `compose.create`: omit it and Dokploy generates `compose-generate-…`; pass one and it still gets a random suffix. Container names follow it (`<appName>-<service>-1`), so pass a meaningful `appName` at create time.
- No domain step — nothing is served.
- Read back with `compose.one`: `sourceType=raw`, the `composeFile` contains your service, and `env` is non-empty.
- Idempotency: scan `project.all` for the compose `name` first and reuse its `composeId` rather than creating a duplicate.

## Seeding the home from inside another container

You usually author the agent in one container and need its files at a host path the new app will mount. It's easier than it looks: bind both host paths into a throwaway `alpine` and copy between them, since the docker daemon resolves the sources.

```bash
docker run --rm -v /srv/main/root/.hermes:/src:ro -v /srv/<app>:/x alpine sh -c '
  D=/x/root/.hermes; rm -rf $D; mkdir -p $D
  for f in SOUL.md config.yaml profile.yaml distribution.yaml .gitignore README.md; do cp -a /src/profiles/<name>/$f $D/; done
  mkdir -p $D/skills
  cp -a /src/profiles/<name>/skills/gaming $D/skills/
  mkdir -p $D/workspace
  chown -R 10000:10000 /x/root'
```

Do **not** `rm -rf` the source tree in the same script — copy from `/src` (a separate mount) or you can delete your only copy of the authored files.

## Bundled skills come back at every boot

`stage2-hook.sh` runs `tools/skills_sync.py` on container start, so a manually pruned `skills/` is re-populated with the ~58 stock skills and your prune silently evaporates. The supported fix is `hermes skills opt-out`:

```bash
docker exec <container> hermes skills opt-out --remove --yes
```

`--remove` deletes unmodified bundled skills (user-edited and hub skills are kept) and writes `/opt/data/.no-bundled-skills`, which the installer, `hermes update` and the boot sync all honour. Equivalent to `hermes profile create --no-skills`, applied after the fact.

## Deploying before the secrets exist is safe

`gateway run` with no platform token configured stays up and idles (verified: still alive at a 50 s cap, exit 124) — it does not exit and therefore does not restart-loop. So you can create the app, hand the owner a Dokploy env with the two or three blanks to fill, and deploy immediately; a restart picks up the tokens.

Probe before promising this: `timeout 50 docker run --rm -v <home>:/opt/data -e HERMES_HOME=/opt/data <image> gateway run`.

## Verify afterwards

```bash
docker ps -a --format '{{.Names}}\t{{.Status}}' | grep <app>
docker inspect -f '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' <container>
docker stats --no-stream <container>       # idle ~250 MB
docker logs --tail 40 <container>          # expect "Hermes Gateway Starting..."
docker exec <container> sh -c 'for v in A B C; do eval "x=\$$v"; [ -z "$x" ] && echo "$v EMPTY" || echo "$v set"; done'
```

Confirm the home is the one you seeded (`ls /opt/data/SOUL.md`) and that no ports are published.
