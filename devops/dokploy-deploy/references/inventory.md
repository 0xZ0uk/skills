# Dokploy instance inventory — volatile state

Re-discover before use: `GET /api/project.all`, `GET /api/compose.one?composeId=`. IDs survive redeploys but not delete/recreate. Host sizing is never recorded here — read `cluster.getNodes` / `pct config 100` live.

## Endpoints (2026-10-04)

- API: `http://192.168.1.42:3000` (LXC 100 on pve `192.168.1.5`). Public base domain: `blugg.duckdns.org`.
- Game panel: `games.blugg.duckdns.org` (compose `pyrodactyl`, project Apps).

## Projects and composes (2026-09-14 unless noted)

- Org `fAgDJjS1Pj29JLER2vfVS`.
- Project `Apps` = `fXPop9_QpllwoCKOs8XKa`; environment `production` = `Osg7u2MPzWB4-HITEPUaw`.
- Composes in Apps: `cli-proxy-api` `a0-YaLsswF5wVCbfLlLTr` · `executor` `3hf8YTp03yKx9bkPcSI00` · `stash` `MCLxZItEqgiOWdvk3Yja1` · `pyrodactyl` `wcULAeJ6Hi8fgcPhI6PYb` · `litellm` `CKGo3xYZtTzPH92yZfeI6`.
- `rakazo` = `loiW7P2UTKzpUaT3w5_NN`, appName `rakazo-6vnete`, domain → `web:5173`; build files and secrets under `/root/rakazo/` (2026-09-17).
- `paperclip` = `xEX4ZMnS3l_bMmGenAN7u`, appName `apps-paperclip-xh89vz` (2026-09-28) — details below.
- Project `Projects` = `hSd1i74G7eEz4VH2IRPZW`, env `production` = `CH5swN4AczGiQDW_w9U47` (compose `ztube`, app `studyquest-api`).

## Paperclip (2026-09-28)

- Image reported version `2026.916.1`, commit `d554c4789ed3930f8a53ac9fdf6503b3187097da`, digest `sha256:a02ac35ac41df911af477422ea0e781cf41d2b2c600c66f0a5ac9d8c63f52c2c`; running `:latest`, no resource limits, no healthcheck.
- Volumes `apps-paperclip-xh89vz_paperclip-data` (`/paperclip`) and `apps-paperclip-xh89vz_postgres-data`.
- Tailnet-only: `https://paperclip.taile58db.ts.net` (tailnet `0xz0uk.github`, node IP `100.88.77.2`), sidecar container `apps-paperclip-xh89vz-tailscale-1`; public `paperclip.blugg.duckdns.org` route deleted. LAN fallback allow-listed as `apps-paperclip-5bcb61-192-168-1-42.sslip.io` — the `5bcb61` suffix doesn't match the appName; verify which hostname actually resolves before relying on it.
- Open issue: three setup-token lease-release failures every 30 s — five timed-out adapter auth sessions (`claude_local` 3, `codex_local` 2) with blank `provider_lease_id` while `environment_leases` is empty, so PostgreSQL rejects empty-string UUID lookups. Resolve before treating logs as healthy.
