---
name: proxmox-homelab-ops
description: Use when operating Pedro's Proxmox host (pve).
---

# Proxmox homelab operations (pve @ 192.168.1.5)

Single-node PVE host running Pedro's homelab. Root SSH from the `hermes` container works with the
container's ed25519 key. Everything below was verified against the live host — re-verify before
assuming (`pveversion`, `qm list`, `pct list`) because the layout changes.

## Access

```bash
ssh root@192.168.1.5                 # key auth only (PasswordAuthentication no since 2026-09-17)
ssh -o StrictHostKeyChecking=no root@192.168.1.102   # from the hermes container, NOT from the pve host
```

**Trap:** the pve host's own root key is NOT authorized on the guests. Run guest SSH from the Hermes
container; nested `ssh pve 'ssh guest ...'` fails with `Permission denied (publickey)`.

## Host inventory (as built)

| | |
|---|---|
| CPU / RAM | Ryzen 5 PRO 3400G, 4c/8t / 32 GB installed (29.28 GiB host-usable) + 8 GiB swap |
| Boot disk | `nvme0n1` KIOXIA 119 GB → VG `pve`: root 39.6G, swap 8G, thin `local-lvm` 54G |
| Guest disk | `nvme1n1` WD SN550 465 GB → VG `vm-storage`: thin pool 456G (+ `backup` LV) |
| Dead disk | `sda` 2 TB WD20EURS — drops off the SATA bus; SMART 60,666 h, 843 reallocated sectors, corrupt ext4 journal. **Never store data on it.** A SCSI rescan (`echo '- - -' > /sys/class/scsi_host/hostN/scan`) can briefly revive it, which is only useful for reading SMART. |

Guests: VM 104 `pyro-elytra` (game node — Pyrodactyl `elytra` wings on :8080/SFTP :2022), VM 106
`hermes` (this agent's own VM), CT 100 `dokploy` (14 containers: dokploy, traefik, executor,
pyrodactyl panel, omniroute, postiz, listmonk), CT 103 `cloudflare-ddns`, CT 105 `cloudflared`.

Panel truth: the pyrodactyl panel lives in CT 100 and knows exactly **one** node — `BLU` at
192.168.1.102. A wings daemon pointing anywhere else is an orphan; CT 102 was one (retired).

## Memory budgeting

The failure mode here is the July OOM kills: guest RAM ceilings totalling far more than physical RAM
with **no balloon devices**. When re-cutting:

- VM ceilings are hard reservations; LXC `memory` is a cgroup ceiling, not a reservation.
- `balloon: N` must be added at VM start (device exists only from boot) and gives the host a
  reclaim range of `N .. memory`. 8 GiB VM + `balloon: 4096` worked well for both VMs.
- Check headroom with `free -h`, `/proc/pressure/memory`, and `Committed_AS` vs `CommitLimit` in
  `/proc/meminfo` — not `load`.
- Reduce a VM's reserved RAM in a window when its workload is idle (e.g. game servers stopped).
- Current post-Hermes-migration layout: VM 106 `hermes` is retained as a stopped rollback image with `onboot: 0`; CT 100 Dokploy is `memory: 10240`, `swap: 4096`, `cores: 6`; VM 104 pyro-elytra is `memory: 16384`, `balloon: 0`. The two active workload ceilings total 26 GiB, leaving about 3.28 GiB of the host-visible 29.28 GiB for PVE/QEMU. Do not start VM 106 without first re-budgeting RAM, and do not treat the DIMM-label total as guest-allocatable RAM.

## Backups

Target is the `backup` dir storage at `/mnt/backup` (thin LV `vm-storage/backup`, 120 GiB, ext4,
fstab by-UUID, `is_mountpoint 1` so it fails closed). Jobs live in `/etc/pve/jobs.cfg`.

**Pitfall that cost a whole backup round:** `pvesm add dir` creates the datastore but NOT the
`<path>/dump` subdirectory. vzdump then dies instantly with:
`cp: cannot create regular file '/mnt/backup/dump/...log': No such file or directory`.
Always `mkdir -p <path>/dump` after registering a dir storage.

**Pitfall: failures are silent.** vzdump reports `notified via target mail-to-root`, but postfix on
this host is `inet_interfaces = loopback-only` with no relayhost, so the mail evaporates. Any
alerting you rely on must be verified end-to-end, not assumed from the log line.

## Firewall

Classic `pve-firewall` drives `/etc/pve/firewall/cluster.fw` (PVE 9.2 also ships
`proxmox-firewall`, which stays inert until `/etc/proxmox-firewall/config.yaml` exists — do not run
both). Current ruleset: LAN-only TCP 22/8006/3128/5900-5999/111 + ICMP, `policy_in: DROP`.

Syntax gotchas found the hard way: `IN ACCEPT -source +alias` fails with *no such ipset* — use a
literal CIDR; and `log_level_in: nolog` failed to parse in OPTIONS. Validate with
`pve-firewall compile 2>&1 | grep -i error` **before** `pve-firewall restart`.

### Dead-man switch pattern (use for anything that can lock you out)

```bash
cat > /root/fw-rollback.sh <<'EOF'
sed -i 's/^enable: 1/enable: 0/' /etc/pve/firewall/cluster.fw; pve-firewall restart
EOF
chmod +x /root/fw-rollback.sh
systemd-run --on-active=480 --unit=fw-deadman /root/fw-rollback.sh   # auto-reverts in 8 min
# ... apply + verify from a FRESH connection ...
systemctl stop fw-deadman.timer                                       # cancel once verified
```

The same shape works for sshd hardening (rollback = remove the drop-in and reload). Always verify
with a **new** connection: established sessions survive a bad ruleset and mask the lockout.

## Monitoring

`~/.hermes/scripts/pve-health.sh` (Hermes cron `PVE homelab watchdog`, daily 09:00, `no_agent`,
delivers to Discord). Prints nothing when healthy; a Sunday digest is the liveness signal.

When extending it: **do not scan the journal**. `journalctl --since '24 hours ago'` took over two
minutes and blew the timeout; `dmesg | grep -ci 'out of memory: killed process'` is instant. `dmesg`
for OOM, not journald.

## Thin pools

The `vm-storage` VG has ~120 MB free because the entire VG is inside the thin pool — you **cannot**
create a normal LV there. Use `lvcreate -V <size> --thin -n <name> vm-storage/vm-storage`. A fixed
virtual size acts as a natural cap: the filesystem fills before the pool is exhausted, so a runaway
backup fails loudly instead of corrupting live guests.

## Retiring a damaged dir storage

To take a storage out of service so nothing can select it — and to stop a damaged filesystem being
mounted read-write at every boot:

```bash
pvesm set <storage> --disable 1                       # adds 'disable' -> pvesm status shows 'disabled'
sync; umount /mnt/pve/<storage>
systemctl disable "mnt-pve-hdd\\x2ddata.mount"        # the escaped-hyphen unit name, see below
```

PVE generates a systemd mount unit per dir storage at `/etc/systemd/system/mnt-pve-<name>.mount`
(hyphens escaped as `\x2d`) and enables it via `multi-user.target.wants`. That unit is what remounts
the storage at boot — **`/etc/fstab` is not the whole story here**, so don't conclude a storage lacks
boot persistence just because fstab has no entry (I did, and was wrong). Disable the unit too, or the
storage comes back mounted even while PVE reports it disabled.

## Docker housekeeping on the hermes VM

- `docker system df`'s RECLAIMABLE figure for Images **overcounts**: it sums whole image sizes while
  ignoring layers shared with in-use images. Deleting "12 GB reclaimable" actually returned 2.88 GB.
  Quote the real number from `docker image prune -a` output, not from `df`'s estimate.
- `docker image prune -a` only removes images referenced by no container (running *or* stopped), so it
  is safe; plain `docker image prune` only drops untagged layers. Never add `--volumes` here — the
  named volumes back live databases.
- **Reading quirk:** `docker ps` can report `Up Less than a second` for containers that started minutes
  ago. Docker writes `StartedAt` using the host's local time but labels it `Z`, so against UTC `now`
  the delta goes negative. Verify with `docker inspect -f '{{.State.StartedAt}} {{.RestartCount}}'` and
  compare `RestartCount` to 0 before suspecting a crash loop.

## Update safety

Package upgrades need the no-subscription channel: `/etc/apt/sources.list.d/pve-no-subscription.sources`
(`pve-enterprise` ships disabled and there was no fallback, so the host received zero PVE updates).
After a full-upgrade, confirm the intended kernel, then flag the reboot to Pedro — **he** performs
reboots on this hardware.
