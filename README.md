# Homelab Infrastructure

This homelab consists of four main Docker stacks providing comprehensive home automation, media management, file services, and network security. Each docker stack can be deployed from their respective directory with `docker compose up -d`. Detailed configuration documentation and `TODO` items will be available in each Stack's project directory.

## 🗂️ Cloud Services Stack
**Directory:** `cloud/`

Self-hosted cloud storage and file management services:
- **Nextcloud** - Personal cloud storage and collaboration platform
- **Immich** - Photo and video backup solution with ML features
- **MariaDB** - Database backend for cloud applications

## 🏠 Home Assistant Stack  
**Directory:** `homeassistant/`

Complete smart home automation and monitoring platform:
- **Home Assistant** - Central home automation hub
- **Frigate** - AI-powered security camera system
- **Node-RED** - Visual programming for home automation
- **Grafana + InfluxDB** - Metrics visualization and time-series database
- **Mosquitto** - MQTT broker for IoT devices
- **Z-Wave/Matter** - Smart device protocol support

## 🎬 Media Services Stack (Arr Stack)
**Directory:** `media-services/`

Automated media acquisition and streaming services:
- **Plex** - Media server and streaming platform
- **Sonarr** - TV series management and automation
- **Radarr** - Movie management and automation  
- **Lidarr** - Music collection management
- **Bazarr** - Subtitle management for media
- **Prowlarr** - Indexer management for *arr applications
- **Overseerr** - Request management for media
- **qBittorrent** - Torrent client
- **SABnzbd** - Usenet downloader
- **Gluetun** - VPN container for secure downloading

## 🛡️ Network Services Stack
**Directory:** `network-services/`

Network security, filtering, and infrastructure services:
- **Pi-hole** - Network-wide ad blocking and DNS filtering
- **DNSCrypt** - Encrypted DNS resolution
- **SWAG** - Secure Web Application Gateway (reverse proxy with SSL)
- **Portainer** - Docker container management interface
- **DuckDNS** - Dynamic DNS service
- **DHCP Helper** - Network DHCP assistance