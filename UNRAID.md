# Unraid host

How the Unraid server around these four stacks is set up: what lives on the
flash drive, the User Scripts that start, stop and back up the stacks, and how
to update the OS. Backup contents and restore steps are in
[CLAUDE.md §3](CLAUDE.md#3-backups-live-in-unraid-not-here).

Nothing on `/boot` is tracked here. It is backed up weekly to the Time Capsule
(`unraid-backups/usb-config/`) along with everything else.

---

## Layout

| Path | What |
|---|---|
| `/boot` | USB flash drive, FAT. Unraid config, plugins, User Scripts, the files below |
| `/mnt/user/appdata/homelab` | This repo, and Docker's appdata path (Settings → Docker) |
| `/mnt/user/appdata/<service>` | Service data, outside the repo |
| `/mnt/user/appdata/root-home` | Parts of `/root` that must survive a reboot, see [below](#root-is-a-ram-disk) |
| `/mnt/user/system/docker/docker.img` | Docker image file |

### Files on `/boot` that matter

| File | Purpose |
|---|---|
| `config/go` | Boot script. Starts the webGUI; installs the `gh` CLI from `config/gh/` (see FAT below); links the persistent parts of `/root` back in (see RAM disk below) |
| `config/homelab-backup.conf` | Real values for the backup: Time Capsule host/share/credentials, `PI_DNS_HOST`, `PI_SSH_USER`. `chmod 600`, never in git |
| `config/homelab-stacks.sh` | Shared stack functions, see [below](#shared-stack-functions) |
| `config/plugins/user.scripts/scripts/<name>/script` | Each User Script |
| `config/plugins/user.scripts/schedule.json` | User Scripts schedules |
| `config/ssh/root/` | Root's `~/.ssh` (symlinked) |

### `/boot` is FAT

- **No executable bit.** It is mounted `fmask=0177`, so every file is
  `rw-------`. Anything that must run is copied elsewhere first: `go` installs
  `gh` into `/usr/local/bin`, and User Scripts copies each script to `/tmp`.
- **No hard links.** ssh can't rewrite `~/.ssh/known_hosts` in place and logs
  `hostfile_replace_entries … Operation not permitted`. Harmless.
- **Edit with LF line endings.** A file saved with Windows CRLF breaks bash.

### Boot device

Unraid boots from the USB flash drive. 7.3 added **Internal Boot**
(Settings → Wizards), which moves `/boot` onto a formatted internal pool; it
was considered and declined (2026-10-18): it formats whole drives, the NVMe
holds appdata, and the weekly `/boot` backup already covers a flash failure.
Restoring onto a new stick also needs a license transfer
(Tools → Registration).

### `/root` is a RAM disk

`/` is rebuilt from the flash drive on every boot, so anything written under
`/root` is lost on reboot. What must persist lives in
`/mnt/nvme-cache/appdata/root-home/`, and `go` symlinks it back in at boot:

| `/root/…` | Holds |
|---|---|
| `.claude/` | Claude Code chat history, memory, credentials, settings |
| `.claude.json` | Claude Code global config |
| `.gitconfig` | Git commit identity, `safe.directory` for this repo |
| `.vscode-server/` | VS Code remote server and its extensions |

```bash
# end of /boot/config/go
for p in .claude .claude.json .gitconfig .vscode-server; do
  ln -sfn /mnt/nvme-cache/appdata/root-home/$p /root/$p
done
```

- The links dangle until the array starts; nothing uses them before then.
- They target the pool path, not `/mnt/user`, so the VS Code server's sockets
  and binaries skip the user-share layer. appdata is cache-only on
  `nvme-cache`, so it is the same directory. Renaming the pool means updating
  `go`.
- To persist another `/root` path: stop what uses it, move it into
  `root-home/`, add it to the loop, and symlink it by hand once.
- The backup keeps `root-home/` but excludes `root-home/.vscode-server/`
  (~1.1G, reinstalled on first connect).
- Claude Code writes `.claude.json` through the symlink without replacing it
  (verified across a reboot, 2026-10-18).

---

## Docker stacks

The four stacks are plain `docker compose` projects, run from their directories
in this repo. The Compose Manager plugin is installed but manages none of them.

- **Order:** up `network-services` → `cloud` → `homeassistant` →
  `media-services`; down in reverse. `network-services` creates the SWAG
  network the others join.
- **The array does not auto-start** after boot (Main → Array Operation).
  Start it by hand, then start the stacks.
- **Restart policies** are `always` / `unless-stopped`, so containers that were
  only stopped come back on their own, in no particular order, when the array
  starts. Containers removed with `docker compose down` do not; start them with
  **Docker Stacks Up**.

### DNS: never both hosts down

Unraid and the Raspberry Pi are the LAN's only DNS servers, each running
Pi-hole in its `network-services` stack. Before stopping Unraid's
`network-services` (or rebooting Unraid), make sure the Pi's Pi-hole answers;
don't take the Pi down at the same time. The stack scripts check this for you.

---

## User Scripts

Plugin: **User Scripts**. Scripts are under
`/boot/config/plugins/user.scripts/scripts/`, one folder each (`script` plus
`name`, optional `description`).

| Script | Schedule | Does |
|---|---|---|
| Backup to Time Capsule | Weekly, Sun 04:30 | Stops the stacks, copies `/boot`, appdata, the Immich DB dump and the Pi's `network-services` to the Time Capsule, restarts the stacks. Log: `/var/log/unraid_backup.log` |
| Docker Stacks Down | Manual | Stops all four stacks in order |
| Docker Stacks Up | Manual | Starts all four stacks in order |
| Copy from Time Capsule, Copy files with Clean File Paths and Names, Clean up dirs | Manual | One-off file migration helpers, not part of the stack setup |
| delete.ds_store, delete_dangling_images, viewDockerLogSize | Disabled | Stock examples |

**How the plugin runs a script:** it copies `script` to
`/tmp/user.scripts/tmpScripts/<name>/script`, strips `\r`, adds `#!/bin/bash`
if missing, makes it executable, and runs the copy. The run's output goes to
`log.txt` beside it. That copy is why scripts on FAT can run at all, and why
editing a script doesn't affect a run already in progress.

**Schedules:** change them in the UI (Settings → User Scripts). If editing
`schedule.json` by hand, also copy it to `/tmp/user.scripts/schedule.json`;
the runtime reads that cached copy and only refreshes it when it is missing.

### Shared stack functions

Stopping and starting the stacks lives in one file,
`/boot/config/homelab-stacks.sh`, that the three stack-related scripts load
and call:

```bash
. /boot/config/homelab-stacks.sh
start_stacks
```

| Function | Does |
|---|---|
| `stop_stacks [--watchdog]` | Stops the dependent stacks, then `network-services` only once the Pi's Pi-hole answers (waits `DNS_WAIT_MINUTES`, default 10; otherwise leaves it running). `--watchdog` also starts a background check that restarts `network-services` if the Pi stops answering |
| `start_stacks` | Stops the watchdog, starts `network-services`, waits 30 s, starts the rest |
| `log "msg"` | Timestamped line to stdout, and to `$LOG_FILE` if set |

Both stack functions return non-zero if any stack failed.

| Caller | Calls |
|---|---|
| Backup to Time Capsule | `stop_stacks --watchdog` … `start_stacks` |
| Docker Stacks Down | `stop_stacks`, with `DNS_WAIT_MINUTES=2` (no watchdog: it would outlive the script) |
| Docker Stacks Up | `start_stacks` |

Change stack behaviour in the shared file, not in the scripts, so all three
stay in step. The file sits outside `user.scripts/scripts/` so it isn't listed
in the UI as a runnable script. `PI_DNS_HOST` comes from
`homelab-backup.conf`.

---

## Plugins

| Plugin | Use |
|---|---|
| User Scripts | Backup and stack scripts above |
| Community Applications | App/plugin installs |
| Compose Manager | Installed; not used for these stacks |
| Appdata Backup | Installed; not configured (the User Scripts backup replaces it) |
| NUT | UPS monitoring |

---

## Updating Unraid OS

Point releases (e.g. 7.3.2 → 7.3.3): read the release notes at
[docs.unraid.net](https://docs.unraid.net/unraid-os/release-notes/) for
breaking changes first.

1. Check the Pi's Pi-hole answers: `dig @<pi> example.com`.
2. **Plugins → Check for Updates**; update plugins first.
3. **User Scripts → Docker Stacks Down** (foreground).
4. **Tools → Update OS**; install the new version. Don't reboot from there yet.
5. **Main → Stop** the array (optional; surfaces a stuck unmount before the
   reboot).
6. Reboot.
7. Confirm the version, then **Main → Start** the array.
8. **User Scripts → Docker Stacks Up**.
9. `docker ps`: every container up. Check DNS, Home Assistant and SWAG.

Docker Stacks Up deploys whatever is in the working tree, uncommitted edits
included. The previous OS version is kept for rollback (Tools → Update OS).
The next Sunday backup confirms the Time Capsule mount still works on the new
kernel.
