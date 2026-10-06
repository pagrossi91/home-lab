# Homelab Network Stack - TODO

This file tracks pending improvements, security hardening, and configuration tasks for the network services stack.

## 🔒 Security Hardening

### High Priority

#### ~~1. Remove External Pi-hole Admin Access~~ ✅ Done (2026-10-05)
Pi-hole admin — along with Portainer and the Unraid web UI — is now restricted to LAN/WireGuard at the SWAG level. Each proxy-conf starts with an `if ($remote_addr !~ ...) { return 444; }` rule, so internet clients get a silently dropped connection while the same `https://<service>.<subdomain>.duckdns.org` URLs keep working at home and over VPN. Unknown hostnames are refused at the TLS handshake (`ssl_reject_handshake on` in `default.conf`). See **README → SWAG Reverse Proxy → Access Restrictions**.

#### ~~2. Implement Local Access Restrictions~~ ✅ Done (2026-10-05)
The gap as written didn't exist: over IPv4 the router forwards only 443 and the WireGuard port, so Pi-hole's port 81 was never reachable from the internet. The real exposure was IPv6 — Docker publishes every port on `[::]` and the server has a public IPv6 address — and the router's IPv6 firewall was confirmed to drop inbound connections. The suggested `ufw` method doesn't apply (Unraid has no `ufw`, and Docker bypasses it). Instead, host-published ports that only other containers used were removed: Pi-hole 444, dnscrypt-proxy 5053, MariaDB 3306/3307, Mosquitto 9001, Nextcloud 8079. See **README → SWAG Reverse Proxy → Host Port Exposure**.

### Medium Priority

#### ~~1. Add Security Headers to SWAG Proxy Configs~~ ✅ Done (2026-10-05)
HSTS (two years, `includeSubDomains`, no preload) is set in `ssl.conf`, so it covers every service. `nosniff` and `X-Frame-Options: SAMEORIGIN` are added through `map` fallbacks only where an app sends none, so apps that set their own keep their values. The suggested generic CSP (it would break Plex, Immich and Nextcloud) and `X-XSS-Protection` (obsolete) were deliberately left out. Nextcloud's proxy-conf no longer hides its own headers. The stale `overseerr` vhost (container long gone) was removed. See **README → SWAG Reverse Proxy → Security Headers**.

#### ~~2. Implement Rate Limiting~~ ✅ Done (2026-10-05)
Every internet-facing login already had protection, from the app itself or from SWAG's fail2ban (5 × HTTP 401 → banned on all ports), except Seerr. Its failed logins return 403, which fail2ban doesn't count, so Seerr's local sign-in was turned off (everyone uses Plex). A `recidive` jail now bans repeat offenders for a week. The suggested nginx `limit_req` was not adopted: its `/admin` and `/login` paths don't exist in these apps, a 60 r/m "general" zone would break Home Assistant and Immich, and per-IP limits would throttle the whole household, which shares the router's IP. Home Assistant's own ban on the router IP (`ip_bans.yaml`) is now documented under Troubleshooting. See **README → SWAG Reverse Proxy → Brute-Force Protection**.

### Deferred: Needs Planning

#### 1. Restrict Container → LAN/Host Traffic (Network Segmentation Stage 2)
**Gap (verified 2026-10-05):** a container compromised from the internet can open connections to every host-published port through the host's LAN IP or the bridge gateway: Portainer `:9000` (Docker socket behind a login), Frigate's unauthenticated `:5000`, MQTT, InfluxDB, the *arrs, and the Unraid UI. It can also reach the rest of the LAN, such as the router's admin page. Docker networks can't stop this, because the traffic leaves through the host's normal routing. This is the main remaining path from an internet-facing breach into the LAN.

**Direction:** host firewall rules that drop *new* connections from Docker bridge subnets to the LAN and to host ports, with an explicit allow-list by source container. Replies to connections the LAN starts (`ESTABLISHED,RELATED`) stay allowed, so LAN access to every service is unchanged.
- `DOCKER-USER` (FORWARD) covers container → LAN and container → *published* ports, which are DNAT'd to another container. Match on `--ctorigdst` to see the pre-DNAT target.
- `INPUT` covers container → services on the host itself, such as the Unraid web UI (SWAG's `unraid` proxy-conf needs an allow rule).

**Plan before implementing:**
1. Inventory every container's legitimate LAN/host destinations. Known so far:
   - Home Assistant: IoT devices, cameras, Pi-holes `:81`, the *arrs and SABnzbd by LAN IP, Plex via `plex.direct`, and `matterjs-server` (host network).
   - Frigate: cameras.
   - SWAG: the Pi (Pi-hole, Portainer) and the Unraid UI.
   - Seerr: Plex via `plex.direct`, which resolves to the LAN IP.
   - Plex: GDM/DLNA discovery.
   - Nebula-Sync runs on the Pi, so it's out of scope here.
   - WireGuard: peers' LAN access goes through `wg_network`, and must be allowed.
2. Decide the default per network: deny for `nginx_network`, `vpn` and `immich`/`nextcloud` backends; allow-list for `homeassistant_network`.
3. Persistence: Unraid has no firewall manager. Apply the rules from a User Scripts entry at array start (or the `go` file), make them idempotent, and confirm Docker doesn't flush `DOCKER-USER` when it restarts.
4. Rollout: start with `LOG` rules only for a week to catch real traffic that an allow-list would miss, then switch to `DROP`.
5. Verify with the throwaway-container probe from README → Network Segmentation, extended to host ports and the router, plus a check of every HA integration and the Plex clients.

**Risks:** a missing allow rule fails quietly (an HA device goes unavailable, Plex discovery stops working). Also, a rule that matches LAN *replies* instead of new connections would cut LAN access to services.

## 🛠️ Configuration Improvements

### High Priority

#### ~~1. Environment Variable Consolidation~~ ✅ Done (2026-10-05)
The named gap didn't exist. `pihole.toml` is generated by FTL and untracked, it can't do `${}` substitution, and its upstream already comes from `.env` through `FTLCONF_dns_upstreams` (marked `### CHANGED (env)`). Hardcoded Docker bridge IPs in the compose files are each defined once and used once, and `CLAUDE.md` keeps them readable on purpose, so they weren't moved into `.env`. All six `.env`/`.env.example` pairs have matching keys, and no real LAN IPs appear in tracked files. The real drift was the README's own copy of the `.env` template, which was missing 10 keys, including `WG_*` (the stack wouldn't start without them). It now points to `.env.example` as the single template and documents the missing keys. `172.XX` placeholders became the real `172.18.x` addresses, and the commented `dhcp-helper` target now uses `${PIHOLE_STATIC_IP}` instead of a stale IP. See **README → Environment Configuration**.

#### ~~2. Container Health Checks~~ ✅ Done (2026-10-05)
Pi-hole and Watchtower already had built-in checks. Added `dnscrypt-proxy` (`dnsprobe` in exec form, since the image has no shell or `dig`) and `swag` (`curl` against port 80, since HTTPS to `localhost` fails on the certificate and on `ssl_reject_handshake`). The proposed commands would have left both permanently unhealthy. The stated "auto-restart" purpose was a misconception: Docker never restarts unhealthy containers, so this is status only. Not adopted: `depends_on: service_healthy` (Pi-hole wouldn't start at all if the server boots during an internet outage) and `autoheal` (needs `docker.sock`). Measured overhead is about 0.1 s per probe per minute. Alerting on health status is deferred to **Monitoring and Alerting**. Also corrected README Pi-hole step 6: the router's secondary DNS is the second Pi-hole, not a public resolver. See **README → Health Checks**.

### Medium Priority

#### ~~1. Network Segmentation~~ ✅ Done (2026-10-05), Stage 1
A container on `nginx_network` could reach Immich's Redis (no password), Postgres and ML API, and Nextcloud's MariaDB. Those now sit on private `immich_backend` and `nextcloud_backend` networks; only `immich_server` and `nextcloud` remain on `nginx_network` for SWAG. The proposed management/DNS/external split was not adopted: Portainer, Pi-hole and the *arrs are published on host ports for LAN access, so a compromised container reaches them through the LAN IP whichever Docker network they're on. Closing that path is Stage 2: **Security Hardening → Restrict Container → LAN/Host Traffic**. See **README → Network Configuration Deep Dive → Network Segmentation**.

#### ~~2. High Availability Setup~~ ✅ Done (2026-10-05), not adopted
Redundancy already exists, and at a better level than proposed. Unraid and the Pi each run a full Pi-hole → DNSCrypt-Proxy chain, and the router hands out both. DNSCrypt-Proxy already balances across seven servers by latency and drops failed ones, which covers the "geographic load balancing" idea for a single site. A second `dnscrypt-proxy` on the same host would only cover a crash, which `restart: always` handles. Cross-host upstreams would need 5053 back on the LAN. The remaining gap (Pi-hole up, `dnscrypt-proxy` down) is detected by the health check and depends on the alerting decision. See **README → Architecture Overview → Redundancy**.

#### 3. Performance Scaling

##### Pi-hole Performance Tuning
```yaml
# In docker-compose.yml environment section
FTLCONF_dns_cache_size: 10000  # Increase from default
FTLCONF_dns_cache_insert_strategy: LRU  # Optimize cache strategy
```

##### Resource Monitoring Integration
Consider integrating with monitoring systems:
- Prometheus + Grafana for metrics
- ELK stack for log analysis
- Alerting for service failures

#### 4. Back Up the Raspberry Pi
**Gap (verified 2026-10-05)**: The Time Capsule job copies only Unraid's `/boot` and `appdata`. The Pi has no backup at all: no cron jobs, nothing pulling from it. If its SD card dies, these are lost:
- `~/homelab/network-services/.env`
- WireGuard server keys and peer configs (`wireguard/config/`). Every client would need a new config for the Pi endpoint.
- Portainer data

Pi-hole settings are not at risk (Nebula-Sync recreates them from Unraid). The SWAG config is a copy of Unraid's.

**Direction**: Unraid pulls from the Pi using the Unraid root SSH key, which is already authorized for `rpi3@`. Add a step to the existing **Backup to Time Capsule** User Script that rsyncs the Pi's `~/homelab/` (excluding logs and the dnscrypt resolver caches) into a folder under `appdata` before the Time Capsule copy runs. The Pi then rides along in the existing weekly backup with no new schedule.

**To decide**:
- whether to use `--rsync-path='sudo rsync'`. `rpi3` has passwordless sudo, and the top two levels of `wireguard/` and `pi-hole/` are readable as `rpi3`, but deeper container-owned files may not be;
- whether the pull should keep running when the Pi is unreachable, and log that it was skipped.

**Verify**: after one run, check the copy holds `wireguard/config/wg_confs/` and `.env`, then do a dry restore by diffing against the Pi.

### Low Priority

#### 1. Enhanced Backup Security
**Current**: Basic, manual file backups
**Goal**: Encrypted, automated backups

```bash
# Create encrypted backup script
cat > backup-homelab.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d)
BACKUP_NAME="homelab-backup-$DATE"

# Create backup
tar -czf - \
  ./pi-hole/etc-pihole/ \
  ./dnscrypt/server/keys/ \
  ./swag/config/nginx/proxy-confs/ \
  .env | \
gpg --cipher-algo AES256 --compress-algo 1 --symmetric \
--output $BACKUP_NAME.tar.gz.gpg

echo "Encrypted backup created: $BACKUP_NAME.tar.gz.gpg"

# Optional: Upload to cloud storage
# rclone copy $BACKUP_NAME.tar.gz.gpg remote:backups/
EOF

chmod +x backup-homelab.sh
```

#### 2. Monitor Failed Access Attempts
**Purpose**: Detect potential attacks

```bash
# Create monitoring script for SWAG logs
cat > monitor-access.sh << 'EOF'
#!/bin/bash
# Monitor for suspicious access patterns
tail -f ./swag/config/log/nginx/access.log | \
grep -E "(40[1-4]|50[0-5])" | \
while read line; do
  echo "[$(date)] Suspicious access: $line"
done
EOF
```

#### 3. Implement Automated Certificate Monitoring
**Purpose**: Alert before certificate expiration

```bash
# Add to crontab for weekly certificate checks
0 2 * * 1 openssl x509 -in ./swag/config/etc/letsencrypt/live/${DUCKDNS}.duckdns.org/cert.pem -text -noout | grep "Not After" | mail -s "SSL Certificate Status" admin@domain.com
```

## 📊 Monitoring and Alerting

### Alerting (decision pending)
Docker health status (README → Health Checks) is recorded but nothing reads it. Decide how alerts reach a person, and use the same channel for the items below. Candidates, from least to most added attack surface:
1. A User Scripts job on a schedule: `docker ps --filter health=unhealthy` plus certificate expiry, emailed via the existing SMTP settings. No new container, no new privileges.
2. A Home Assistant integration (Docker/Portainer), using HA's existing notifications. HA gains API access to a root-equivalent tool.
3. Uptime Kuma. Its probes work without `docker.sock`; reading container health needs `docker.sock`.

### DNS Performance Monitoring
**Goal**: Track DNS resolution times and failures

```bash
# Create DNS performance monitoring script
cat > monitor-dns.sh << 'EOF'
#!/bin/bash
PIHOLE_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' pihole)

# Test DNS performance
echo "Testing DNS performance..."
for domain in google.com cloudflare.com github.com; do
  response_time=$(dig @$PIHOLE_IP $domain | grep "Query time" | awk '{print $4}')
  echo "[$domain] Response time: ${response_time}ms"
done
EOF
```

### Container Resource Monitoring
**Goal**: Alert on high resource usage

```bash
# Add resource monitoring
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | \
awk 'NR>1 && ($2+0 > 80 || $3 ~ /[0-9]+\.[0-9]+GiB/) {print "High resource usage: " $0}'
```

## 📋 Testing and Validation

### Automated Security Testing
**Purpose**: Regular validation of security configurations

```bash
# Create security test suite
cat > security-tests.sh << 'EOF'
#!/bin/bash
echo "=== Security Test Suite ==="

# Test 1: Verify Pi-hole not externally accessible
echo "1. Testing external Pi-hole access..."
curl -m 5 -s https://pihole.${DUCKDNS}.duckdns.org && echo "❌ Pi-hole externally accessible!" || echo "✅ Pi-hole blocked externally"

# Test 2: Verify DNS filtering
echo "2. Testing DNS filtering..."
PIHOLE_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' pihole)
dig @$PIHOLE_IP doubleclick.net | grep "0.0.0.0" > /dev/null && echo "✅ DNS filtering works" || echo "❌ DNS filtering failed"

# Test 3: Verify HTTPS security headers
echo "3. Testing security headers..."
curl -I https://${DUCKDNS}.duckdns.org 2>/dev/null | grep -i "strict-transport-security" > /dev/null && echo "✅ HSTS header present" || echo "❌ Missing security headers"

# Test 4: Verify rate limiting
echo "4. Testing rate limiting..."
for i in {1..20}; do curl -s https://${DUCKDNS}.duckdns.org > /dev/null; done
echo "Rate limiting test completed (check logs for 429 errors)"
EOF

chmod +x security-tests.sh
```

## 🔄 Maintenance Tasks

### Regular Update Schedule
- **Weekly**: Check container logs for errors
- **Monthly**: Run security test suite
- **Quarterly**: Update DNSCrypt server list, review blocked domain lists
- **Annually**: Rotate Pi-hole admin password, review security configurations

### Documentation Updates
- [ ] Add troubleshooting section for common security issues
- [ ] Document remote access alternatives
- [ ] Create security assessment checklist
- [ ] Add monitoring setup guides

---

## Priority Order
1. **HIGH**: Environment variable consolidation, container health checks
2. **MEDIUM**: Advanced security features, high availability setup
3. **LOW**: Enhanced monitoring, automated backups

**Estimated Time**: 3-4 hours for high priority items
