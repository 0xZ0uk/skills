# GHCR pulls failing host-wide from a stale stored credential

A compose deploy can die in the pull phase with `Head "https://ghcr.io/v2/<owner>/<repo>/manifests/<tag>": denied: denied` even though the package is public and pulls fine anonymously from another host. The deploy log shows **no `docker login` step**, and Docker Hub images pull normally — so it is not networking and not the package.

Cause: the Dokploy container (which runs `docker compose` against the host socket) keeps a **persistent `~/.docker/config.json`** from an older registry login. `GET /api/registry.all` exposes the org's registry entries (`registryName`, `username`, masked `password`) — a June-created `ghcr.io` entry whose PAT has since been revoked makes Docker send dead credentials on *every* ghcr pull, and GHCR answers 401, surfaced as `denied: denied`. Note the entry can be attached to **no** service (`registryId: null` everywhere) and still poison pulls.

**Diagnose, don't assume**: deploy a throwaway one-service compose pulling an unrelated, definitely-public ghcr image (e.g. `ghcr.io/jqlang/jq:latest`), read the log, then `compose.delete`. Verified 2026-09-17: `jqlang/jq` failed identically to the target image → host-wide, not package-specific. Also worth knowing: the org registry entry is **not** the only possibility — confirm whether the denial also hits public images before blaming the package.

**Fix WITHOUT host access (verified 2026-09-17): `POST /api/registry.testRegistry` performs a real `docker login` inside the Dokploy container, overwriting the poisoned entry.** Body: `{username, password, registryUrl: "ghcr.io", registryType: "cloud"}` (all four required; `registryType` must be exactly `cloud`). Pass a credential GHCR accepts — a plain `gh auth token` (`gho_…`, even without `read:packages`) is enough for public images: the token endpoint returns 200. Redeploy immediately after; the pull then succeeds. Note this does **not** update the stored registry entry (`registry.all` still shows the old masked password), so the entry must still be re-saved with a real PAT in the UI or an app that later attaches it will re-break pulls.

Host-side alternatives (`docker logout` alone suffices — anonymous ghcr pulls work). Run inside LXC 100 (`ssh root@<pve> "pct exec 100 -- …"`); no `-it`, since an agent shell has no TTY:

```bash
D=$(docker ps --format '{{.Names}}' | grep -E '^dokploy(\.|$)' | head -1)   # the Dokploy container itself, not dokploy-postgres etc.
docker exec "$D" sh -c 'grep -o "\"[^\"]*\": *{" ~/.docker/config.json'   # registry keys only, no creds
docker exec "$D" docker logout ghcr.io                  # stale entry gone -> anonymous pulls
# or re-auth with a PAT that has read:packages (never echo it):
printf '%s' "$PAT" | docker exec -i "$D" docker login ghcr.io -u <user> --password-stdin
```

Docker Hub pulls are unaffected, so a mirror to a reachable registry is a workaround when no PAT/host access is available. Compose has no `registryId` field (unlike applications), so a compose deploy never triggers the login that would refresh this credential — which is exactly why the stale entry persists unnoticed.
