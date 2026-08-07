# homelab — conventions

Unraid server running four Docker Compose stacks: `cloud/`, `homeassistant/`,
`media-services/`, `network-services/`. This repo is **public**
(`github.com/pagrossi91/home-lab`). Treat every commit as a publication.

Two systems of record, and they are not the same thing:

| | Holds | Purpose |
|---|---|---|
| **This git repo** | Hand-authored configuration only | Documentation, history, portability |
| **Time Capsule backup** | Complete 1:1 server state, including every secret | Bare-metal restore |

If a file is needed to *rebuild* the server but must not be *published*, it
belongs in the backup and nowhere else. Never add something to git just because
a restore would want it.

---

## 1. Never expose real WAN/LAN addresses or secrets

Real WAN hostnames, LAN IPs, credentials, API keys, and tokens must not appear
in tracked files. Hide them using the **first** method that works:

**1. `.env` (preferred).** The stack's gitignored `.env` holds the real value;
the tracked file references it. Works anywhere Compose or the app itself does
variable substitution.

```yaml
# homeassistant/docker-compose.yml  (tracked)
environment:
  FRIGATE_CAM_FRONT_DOOR_IP: ${amcrest_ip_frontdoorbell}

# homeassistant/.env  (gitignored)
amcrest_ip_frontdoorbell=192.168.X.X
```

Frigate substitutes any `FRIGATE_`-prefixed env var into its own `config.yml`,
so camera addresses stay out of the tracked Frigate config too. Before adding a
new variable, check whether one already holds the value — the camera IPs were
already in `amcrest_ip_*`, and a parallel `CAM_*` set would have been one more
place to forget to update.

**2. Secrets file.** For apps with a native secrets mechanism — Home Assistant's
`secrets.yaml` (gitignored) referenced via `!secret`:

```yaml
# automations.yaml  (tracked)
base_url: !secret ha_external_url
```

> ⚠️ Editing an automation through the HA UI resolves `!secret` back to the
> literal value and rewrites `automations.yaml`. After any UI automation edit,
> re-check `automations.yaml` for leaked hostnames before committing.

**3. Obfuscate.** Only when the file supports neither — e.g. plain TOML that has
no substitution. Replace with a placeholder and say where the real value lives:

```toml
# dnscrypt-proxy.toml — stamp base64-encodes the real DuckDNS hostname
# [static.'self-hosted']
#   stamp = 'sdns://REDACTED'
```

Use `192.168.X.X`, `<LAN_IP>`, or `yourdomain.duckdns.org` in docs and examples.

**Not secret, keep them readable:** Docker bridge addresses (`172.18.0.0/16`,
`172.19.0.0/16`, `172.21.0.0/16`) and container names (`mosquitto-mqtt`,
`sonarr`). They describe internal topology, reveal nothing about the network,
and the config is unreadable without them.

### `.env.example` files

Every `.env` has a tracked `.env.example` beside it — that pairing is what makes
the repo replicable:

```
cloud/.env.example
homeassistant/.env.example
homeassistant/secure-remote-access/.env.example
media-services/.env.example
network-services/.env.example
network-services/pi-hole/piholeconfig.env.example
```

Rules for an example file: **same keys, same order, same comments** as the live
file. Carry real values through for anything non-secret (timezones, paths,
UIDs, Docker bridge IPs, service usernames, SMTP host/port) — a template full of
`changeme` for things that never change is just friction. Replace only
credentials (`changeme-<what-it-is>`), real LAN/WAN addresses (`192.168.X.X`,
`yourdomain.duckdns.org`), and personal emails (`you@example.com`).

When you add a key to a `.env`, add it to the example in the same edit. To
verify parity and catch a live value that slipped into a template:

```bash
# keys present live but missing from the example
comm -23 <(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' .env      | tr -d = | sort -u) \
         <(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' .env.example | tr -d = | sort -u)
```

---

## 2. `.gitignore` is deny-by-default

The root pattern is `/*`. **Nothing is tracked unless explicitly allow-listed.**
A new service directory is ignored the moment it appears — that is the intended
behaviour, not a bug to fix.

To publish a file from a new service, add a `!` rule, and only when it is both
**safe** (contains no secret, real address, or key material) and **necessary for
replication** (a restore genuinely needs it, and it is not reconstructible from
the app itself).

Allow-listing a nested path requires un-ignoring each parent directory — git
does not descend into an excluded directory, so a `!` rule under an ignored
parent silently does nothing:

```gitignore
network-services/*
!network-services/dnscrypt/
network-services/dnscrypt/*
!network-services/dnscrypt/proxy/
network-services/dnscrypt/proxy/*
!network-services/dnscrypt/proxy/config/
network-services/dnscrypt/proxy/config/*
!network-services/dnscrypt/proxy/config/dnscrypt-proxy.toml
```

The backstop block at the bottom of `.gitignore` (secrets, `*.db`, archives,
logs, `MediaCover/`) is re-asserted **last** so no `!` rule above can override
it. Git applies the last matching pattern. Do not add `!` rules below it.

### Never allow-list

Service data directories wholesale. `*arr` `config.xml` (holds `<ApiKey>`),
`sabnzbd.ini`, `recyclarr.yml`, Overseerr/Seerr `settings.json`, anything under
`network-services/wireguard/`, HA `.storage/`, and HACS-managed
`custom_components/` + `www/community/` (reinstalled by HACS; ~3,000 files of
pure bloat).

### Before committing

```bash
git status                                   # nothing unexpected staged
git ls-files                                 # should stay ~30 files
git check-ignore -v --no-index <path>        # confirm a path is covered
```

`git check-ignore` skips already-tracked files unless you pass `--no-index` —
without it a tracked secret looks clean.

---

## 3. Backups live in Unraid, not here

The backup job is a **User Scripts** plugin entry, scheduled **weekly**
(Sundays 04:30 via `/etc/cron.weekly`):

```
/boot/config/plugins/user.scripts/scripts/Backup to Time Capsule/script
/boot/config/plugins/user.scripts/schedule.json          # frequency: weekly
/boot/config/homelab-backup.conf                         # real LAN target, chmod 600
```

This is deliberately **not** mirrored into the repo — the plugin owns it, and
`/boot` is itself backed up. Do not re-add `backup_script.sh` here.

Change the schedule in the Unraid UI. If editing `schedule.json` by hand, also
copy it to `/tmp/user.scripts/schedule.json` — the runtime reads the cached copy
and only refreshes it when missing.

It rsyncs `/boot/` and `/mnt/user/appdata/` to the Time Capsule, excluding
regenerable bulk (`.git`, `MediaCover/`, `pihole-FTL.db`, `gravity*.db`,
Immich ML cache, logs, Plex cache). Plex `Metadata/` and `Plug-in Support/` are
**kept** — the latter holds watch history and is not regenerable.

**Accepted risk:** the Time Capsule only speaks SMBv1, so it is mounted
`vers=1.0,sec=none` — unauthenticated, readable by any LAN device, and it holds
every secret on the server. This is a known trade-off; the LAN is trusted.
Re-evaluate if the LAN's trust boundary changes (guest Wi-Fi bridged, IoT VLAN
merged, a device compromised).

---

## 4. Stack conventions

`network-services` creates the SWAG network, so it starts first and stops last.
Order: **up** `network-services` → `cloud` → `homeassistant` → `media-services`;
**down** in reverse.

Databases (Plex, `*arr` sqlite, MariaDB, InfluxDB, Nextcloud) are copied live by
default. For a consistent backup set `STOP_STACKS=1` in the backup script, which
brings the stacks down first.

---

## 5. Outstanding

A history rewrite is **pending**: earlier commits on `master`, `unraid`, and
`pihole` carry service config files that predate this policy, plus ~1.6 GB of
Home Assistant backup tarballs. Untracking them stopped the bleeding; it did not
remove them from GitHub.

Sequence, in order — rotation first, because a force-push does not un-leak
anything already scraped:

1. Rotate every credential that ever appeared in a tracked file.
2. `git clone --mirror`, `git filter-repo --invert-paths` the offending paths.
3. `git push --force --mirror`, then re-clone anywhere else the repo exists.

The working rotation checklist is kept **out of this repo** — it names live
systems and belongs with the secrets, not next to them. Until step 3 lands,
assume anything committed before this policy is public.
