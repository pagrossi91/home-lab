# Homelab Network Stack - TODO

This file tracks pending improvements, security hardening, and configuration tasks for the network services stack.

## 🔒 Security Hardening

### High Priority

#### Remove External Pi-hole Admin Access
**Risk Level**: HIGH - Pi-hole admin currently exposed to internet via SWAG

**Current State**: 
- Pi-hole accessible via `https://pihole.<subdomain>.duckdns.org`
- Exposes DNS logs, network topology, and admin controls to internet
- Single password protects entire network DNS control

**Security Impact**:
- **DNS Query Exposure**: Attackers can view all DNS queries from your network, revealing browsing habits, internal services, and network topology
- **Network Reconnaissance**: Pi-hole logs show internal device names, IP addresses, and service discovery attempts
- **DNS Manipulation**: Compromised admin access allows redirecting any domain to malicious servers (banking sites → phishing, software updates → malware)
- **Persistent Network Control**: DNS control enables long-term persistent access - redirect security updates, block security tools, etc.
- **Data Exfiltration**: Can redirect internal services to external servers to capture credentials and sensitive data
- **Lateral Movement**: Knowledge of internal network structure facilitates attacks on other services

**Recommended Action**: Remove external access entirely
```bash
# Disable external Pi-hole access
mv ./swag/config/nginx/proxy-confs/pihole.subdomain.conf ./swag/config/nginx/proxy-confs/pihole.subdomain.conf.disabled

# Restart SWAG to apply changes
docker compose restart swag

# Verify external access is blocked
curl -I https://pihole.<subdomain>.duckdns.org
# Should return: HTTP 404 or connection refused
```

**Alternative for Remote Access**:
```bash
# Option 1: SSH tunnel (recommended)
ssh -L 8181:localhost:81 user@your-server-ip
# Then access: http://localhost:8181/admin

# Option 2: VPN access to local network
# Configure WireGuard/OpenVPN, then use: http://server-local-ip:81/admin
```

#### Implement Local Access Restrictions
**Purpose**: Restrict Pi-hole admin to local network only

**Security Impact**:
- **Attack Surface Reduction**: Eliminates direct internet access to Pi-hole, forcing attackers to first compromise local network
- **Insider Threat Mitigation**: Restricts access to physically present or VPN-connected users only
- **Brute Force Prevention**: External automated password attacks become impossible
- **Network Boundary Enforcement**: Aligns with network security best practice of internal-only admin interfaces
- **Audit Trail**: Local access attempts are easier to monitor and correlate with physical presence

```bash
# Method 1: Firewall-based (recommended)
sudo ufw allow from 192.168.0.0/16 to any port 81 comment 'Pi-hole admin - local only'
sudo ufw deny 81 comment 'Block external Pi-hole direct access'

# Method 2: Docker port binding (more restrictive)
# In docker-compose.yml, change Pi-hole ports to:
ports:
  - "192.168.50.X:81:80/tcp"    # Replace X with your server's IP
  - "192.168.50.X:444:443/tcp"  # HTTPS interface
```

**Verification**:
```bash
# Test local access works
curl -I http://192.168.50.X:81/admin

# Test external access blocked
nmap -p 81 your-external-ip
# Should show: 81/tcp filtered
```

### Medium Priority

#### Add Security Headers to SWAG Proxy Configs
**Purpose**: Implement browser-side security protections

**Security Impact**:
- **HSTS (Strict-Transport-Security)**: Forces browsers to use HTTPS only, preventing SSL stripping attacks and accidental HTTP access
- **X-Content-Type-Options**: Prevents MIME type confusion attacks where browsers incorrectly interpret file types, blocking XSS via file uploads
- **X-Frame-Options**: Prevents clickjacking attacks by blocking your site from being embedded in malicious iframes
- **X-XSS-Protection**: Enables browser's built-in XSS filtering (legacy browsers), provides defense against reflected XSS attacks
- **Content-Security-Policy**: Prevents code injection by controlling which resources (scripts, styles, images) browsers can load
- **Referrer-Policy**: Controls what referrer information is sent to external sites, reducing information leakage about your internal URLs

**Attack Scenarios Prevented**:
- **SSL Downgrade**: Attacker forces HTTP connection → HSTS prevents this
- **Malicious File Upload**: User uploads "image" containing script → X-Content-Type-Options blocks execution
- **Clickjacking**: Malicious site embeds your admin panel in invisible iframe → X-Frame-Options blocks embedding
- **Script Injection**: Attacker injects malicious JavaScript → CSP blocks unauthorized script execution

**Implementation**: Update existing proxy configs in `./swag/config/nginx/proxy-confs/`

Example for any `*.subdomain.conf` file:
```nginx
server {
    listen 443 ssl http2;
    server_name servicename.*;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;

    include /config/nginx/ssl.conf;

    location / {
        include /config/nginx/proxy.conf;
        resolver 127.0.0.11 valid=30s;
        set $upstream_app servicename;
        set $upstream_port 80;
        set $upstream_proto http;
        proxy_pass $upstream_proto://$upstream_app:$upstream_port;
    }
}
```

#### Implement Rate Limiting
**Purpose**: Prevent brute force and DoS attacks

**Security Impact**:
- **Brute Force Prevention**: Limits login attempts, making password attacks impractical (10 attempts/minute vs 1000s/minute)
- **DoS Mitigation**: Prevents attackers from overwhelming your services with excessive requests
- **Resource Protection**: Limits CPU/memory consumption from automated attacks
- **Bandwidth Conservation**: Prevents bandwidth exhaustion from malicious traffic
- **Service Availability**: Ensures legitimate users can access services during attack attempts

**Attack Scenarios Prevented**:
- **Credential Stuffing**: Automated login attempts using leaked passwords → Limited to 5-10 attempts per minute
- **Application DoS**: Overwhelming service with requests → Rate limiting prevents resource exhaustion
- **Reconnaissance**: Automated scanning of endpoints → Slows down attacker reconnaissance
- **API Abuse**: Excessive automated API calls → Protects backend services from overload

**Real-World Impact**: 
- **Before**: Attacker could attempt 10,000 passwords in 10 minutes
- **After**: Attacker limited to 100-150 attempts in same timeframe
- **Detection**: Rate limiting triggers provide early warning of attack attempts

**Implementation**: Add to SWAG's main nginx configuration

Create `./swag/config/nginx/rate-limiting.conf`:
```nginx
# Rate limiting zones
limit_req_zone $binary_remote_addr zone=admin:10m rate=10r/m;
limit_req_zone $binary_remote_addr zone=general:10m rate=60r/m;
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
```

Include in `./swag/config/nginx/nginx.conf` within `http {}` block:
```nginx
include /config/nginx/rate-limiting.conf;
```

Then add to proxy configs as needed:
```nginx
location /admin {
    limit_req zone=admin burst=5 nodelay;
    # ... rest of config
}

location /login {
    limit_req zone=login burst=2 nodelay;
    # ... rest of config
}
```

### Low Priority

#### Enhance Backup Security
**Current**: Basic file backups
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

#### Monitor Failed Access Attempts
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

#### Implement Automated Certificate Monitoring
**Purpose**: Alert before certificate expiration

```bash
# Add to crontab for weekly certificate checks
0 2 * * 1 openssl x509 -in ./swag/config/etc/letsencrypt/live/${DUCKDNS}.duckdns.org/cert.pem -text -noout | grep "Not After" | mail -s "SSL Certificate Status" admin@domain.com
```

## 🛠️ Configuration Improvements

### Environment Variable Consolidation
**Current**: Some IPs hardcoded in configurations
**Goal**: All IPs use environment variables

**Files to update**:
- `./pi-hole/etc-pihole/pihole.toml` - Use `${DNSCRYPTPROXY_STATIC_IP}`
- Various documentation examples - Use variable substitution

### DNSCrypt Server Configuration
**Status**: Currently not functional
**Issue**: Requires additional configuration in encrypted-dns.toml

**Investigation needed**:
- Check if DNSCrypt server keys are properly generated
- Verify unbound configuration
- Test if server responds to queries
- Document working configuration

### Container Health Checks
**Purpose**: Better monitoring and auto-restart capabilities

Add to docker-compose.yml:
```yaml
services:
  pihole:
    healthcheck:
      test: ["CMD", "dig", "@127.0.0.1", "google.com"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  dnscrypt-proxy:
    healthcheck:
      test: ["CMD", "dig", "@127.0.0.1", "-p", "5053", "google.com"]
      interval: 30s
      timeout: 10s
      retries: 3
```

## 📊 Monitoring and Alerting

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
- [ ] Update README with actual security implementation steps
- [ ] Add troubleshooting section for common security issues
- [ ] Document remote access alternatives
- [ ] Create security assessment checklist

---

## Priority Order
1. **CRITICAL**: Remove external Pi-hole access
2. **HIGH**: Fix DNSCrypt permissions, implement local access restrictions
3. **MEDIUM**: Add security headers, implement rate limiting
4. **LOW**: Enhanced monitoring, automated backups

**Estimated Time**: 2-3 hours for critical and high priority items