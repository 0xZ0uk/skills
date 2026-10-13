---
name: proxmox-homelab-ops
description: "Operate a single-node Proxmox VE host safely: VM/LXC memory budgeting and OOM avoidance, ballooning, vzdump backups to dir storage, pve-firewall changes with a dead-man auto-rollback, LVM thin pools, retiring a damaged storage, apt repositories and upgrades, and Docker housekeeping inside guests. Use for anything touching qm, pct, pvesm, vzdump, pve-firewall, /etc/pve, guest RAM sizing, or Proxmox host health."
---

# Proxmox VE host operations

Pitfalls verified on a single-node PVE 9.x homelab. Always read the live state before acting — `pveversion`, `qm list`, `pct list`, `qm config <id>`, `pct config <id>`, `pvesm status`, `free -h` — never a remembered layout.

## Access

- Key auth only on the host (`PasswordAuthentication no`); verify any sshd change with the dead-man pattern below.
- The host's root key is **not** automatically authorized on guests. Nested `ssh pve 'ssh guest ...'` fails with `Permission denied (publickey)` unless the host's key was added to the guest; for LXC, `pct exec <id> -- <cmd>` from the host needs no guest SSH at all.

## Memory budgeting

The classic failure: guest RAM ceilings totalling far more than physical RAM, with **no balloon devices**, ends in OOM kills.

- A VM can grow to its full `memory` and, without a balloon device, the host has no way to take it back (QEMU allocates lazily, but guest page cache fills it over time). Budget VM ceilings as if fully used. LXC `memory` is a cgroup ceiling, not a reservation.
- Host-usable RAM is less than the DIMM-label total (firmware/iGPU reservations) — budget against `free -h` on the host, and leave headroom for PVE/QEMU.
- `balloon: N` gives the host a reclaim range of `N .. memory`, but the balloon device exists only from VM start — add it, then stop/start the VM. Requires the balloon driver in the guest.
- Check pressure with `/proc/pressure/memory` and `Committed_AS` vs `CommitLimit` in `/proc/meminfo` — not `load`.
- Before starting a stopped guest or raising a ceiling, total the active guests' ceilings against host-usable RAM.
- Inside an LXC without lxcfs, `/proc/meminfo` shows the **host's** totals; the enforceable budget is `pct config <id>` `memory`.
- For OOM evidence use `dmesg | grep -ci 'out of memory: killed process'` — instant. `journalctl --since '24 hours ago'` can take minutes and blow a monitoring timeout.

## Backups (vzdump to a dir storage)

- **`pvesm add dir` does not create `<path>/dump`.** vzdump then dies instantly with `cp: cannot create regular file '<path>/dump/...log': No such file or directory`. Always `mkdir -p <path>/dump` after registering a dir storage.
- Mount the backup filesystem by UUID and set `is_mountpoint 1` on the storage so a failed mount fails the job instead of filling the root disk.
- **Failure notifications can be silent.** vzdump logs `notified via target mail-to-root`, but a default postfix (`inet_interfaces = loopback-only`, no relayhost) delivers nowhere. Verify alerting end-to-end, not from the log line.
- Jobs live in `/etc/pve/jobs.cfg`.

## Firewall

Classic `pve-firewall` drives `/etc/pve/firewall/cluster.fw`. PVE 9 also ships `proxmox-firewall` (nftables), inert until `/etc/proxmox-firewall/config.yaml` exists — do not run both.

- `IN ACCEPT -source +alias` fails with *no such ipset* — use a literal CIDR (or a real ipset).
- `log_level_in: nolog` failed to parse in `OPTIONS`.
- Validate with `pve-firewall compile 2>&1 | grep -i error` **before** `pve-firewall restart`.
- Allow at least 22 and 8006 from your management network before setting `policy_in: DROP`.

### Dead-man switch (for anything that can lock you out)

```bash
cat > /root/fw-rollback.sh <<'EOF'
#!/bin/sh
sed -i 's/^enable: 1/enable: 0/' /etc/pve/firewall/cluster.fw; pve-firewall restart
EOF
chmod +x /root/fw-rollback.sh
systemd-run --on-active=480 --unit=fw-deadman /root/fw-rollback.sh   # auto-reverts in 8 min
# ... apply, then verify from a FRESH connection ...
systemctl stop fw-deadman.timer                                       # cancel once verified
```

The shebang is required: `systemd-run` execs the file directly. The same shape works for sshd hardening (rollback = remove the drop-in and reload sshd). Always verify with a **new** connection — established sessions survive a bad ruleset and hide the lockout.

## Thin pools

If a VG is entirely consumed by its thin pool (`vgs` shows ~0 free), you **cannot** create a normal LV there. Create a thin volume instead: `lvcreate -V <size> --thin -n <name> <vg>/<thinpool>`. A fixed virtual size is a natural cap: the filesystem fills before the pool is exhausted, so a runaway backup fails loudly instead of corrupting live guests.

## Retiring a damaged dir storage

```bash
pvesm set <storage> --disable 1            # pvesm status shows 'disabled'
sync; umount /mnt/pve/<storage>
systemctl list-unit-files 'mnt-pve-*'      # find the exact unit name
systemctl disable "$(systemd-escape --path --suffix=mount /mnt/pve/<storage>)"
```

A storage created through the GUI (*Disks → Directory*) gets a generated systemd mount unit (`/etc/systemd/system/mnt-pve-<name>.mount`, hyphens escaped as `\x2d`) enabled via `multi-user.target.wants`. That unit — not `/etc/fstab` — remounts it at boot, so an empty fstab does not mean "no boot persistence". Disable the unit too, or the storage comes back mounted while PVE reports it disabled. A storage registered with `pvesm add dir` on a path you mounted yourself has no such unit; remove its fstab entry instead.

A disk that drops off the SATA bus can sometimes be revived with a SCSI rescan (`echo '- - -' > /sys/class/scsi_host/hostN/scan`) — useful only to read SMART before retiring it.

## Updates

- Without a subscription, `pve-enterprise` (and `ceph` enterprise) repos fail and the host silently gets **no** PVE updates. Disable them and add the no-subscription repo (PVE 9: `/etc/apt/sources.list.d/pve-no-subscription.sources`, deb822 format).
- After `apt full-upgrade`, confirm the intended kernel (`proxmox-boot-tool kernel list`) and ask the operator before rebooting the host — every guest goes down with it.

## Docker inside guests

- `docker system df`'s RECLAIMABLE for images **overcounts**: it ignores layers shared with in-use images ("12 GB reclaimable" returned 2.88 GB). Quote the number `docker image prune -a` actually reports.
- `docker image prune -a` removes only images no container (running or stopped) references; plain `prune` only drops dangling layers. Never add `--volumes` on a host whose named volumes back databases.
- `docker ps` showing `Up Less than a second` for a long-running container can be a timezone artifact (local-time `StartedAt` labelled `Z`), not a crash loop. Check `docker inspect -f '{{.State.StartedAt}} {{.RestartCount}}'`; `RestartCount` 0 means it's fine.
