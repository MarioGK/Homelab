# Caddy Reverse Proxy Gateway

This Caddy configuration provides a modern reverse proxy for your homelab, replacing Traefik with enhanced flexibility for both local and public access.

## What This Provides

- **Caddy** running as a reverse proxy with automatic HTTPS support
- **Local DNS routing** for `.ms01` domains (e.g., `jellyfin.ms01`)
- **Public domain routing** for internet-facing services (e.g., `media.mariogk.com`)
- **Flexible configuration** for exposing services to the internet

## Features

- ✅ Simple declarative configuration (Caddyfile)
- ✅ Automatic HTTPS support (can enable with `tls` directive)
- ✅ Admin API on port 2019 for dynamic configuration
- ✅ Load balancing support
- ✅ Health checks
- ✅ Header manipulation
- ✅ Path rewriting
- ✅ Reverse proxy to multiple backends

## Configuration

### Local Access (Private Network)

Access services locally using:
- `jellyfin.ms01` → `http://192.168.5.10:8096`
- `sonarr.ms01` → `http://192.168.5.10:8989`
- `radarr.ms01` → `http://192.168.5.10:7878`
- etc.

### Public Access (Internet)

Access services publicly using:
- `media.mariogk.com` → `http://192.168.5.10:8096`
- `home.mariogk.com` → `http://192.168.5.10:8123`

## How to Use

### 1. DNS Configuration

For local access (.ms01 domains):
- Configure your router's DHCP DNS to point to the machine running this gateway (192.168.5.10)
- Or set your system DNS manually to resolve *.ms01 locally

For public access (mariogk.com domains):
- Configure your external DNS or router port forwarding
- Point your domain's DNS records to your public IP

### 2. Adding New Routes

Edit the `Caddyfile` and add new entries:

```caddyfile
# Local route
newservice.ms01 {
  reverse_proxy 192.168.5.10:8000
}

# Public route
newservice.mariogk.com {
  reverse_proxy 192.168.5.10:8000
}
```

### 3. Enabling HTTPS (Optional)

For public services, add automatic HTTPS:

```caddyfile
media.mariogk.com {
  reverse_proxy 192.168.5.10:8096
  # HTTPS is automatic for domains
}
```

For local services without DNS:

```caddyfile
jellyfin.ms01 {
  reverse_proxy 192.168.5.10:8096
  tls internal  # Use internal self-signed certificate
}
```

## Caddy Admin API

Access the Caddy admin API at `http://localhost:2019/admin/`

Examples:
- Get current config: `GET http://localhost:2019/config/`
- Reload config: `POST http://localhost:2019/reload`

## Accessing the Dashboard

Visit `http://localhost:2019/admin/` (local only) to access the Caddy admin dashboard.

## Starting the Stack

```bash
docker compose up -d
```

## Logs

```bash
docker compose logs -f caddy
```

## Security Notes

- The Caddy Admin API is only accessible from localhost (port 2019)
- For public services, consider using authentication or firewalls
- Set up proper DNS records and port forwarding for public access
- Enable HTTPS for sensitive services

## Troubleshooting

### Services not accessible on .ms01 domains

1. Check if Blocky DNS is running and configured to resolve .ms01 → 192.168.5.10
2. Verify DNS resolution: `nslookup jellyfin.ms01 192.168.5.10`
3. Check Caddy logs: `docker compose logs caddy`

### HTTPS certificate errors

- For local domains: Use `tls internal` in the Caddyfile
- For public domains: Ensure DNS is properly configured before accessing

### Port conflicts

- Caddy uses ports 80, 443, and 2019
- Ensure these ports are not already in use

## Comparison with Traefik

| Feature | Caddy | Traefik |
|---------|-------|---------|
| Config Format | Caddyfile (simple) | YAML (complex) |
| HTTPS | Automatic | Manual/Plugin |
| Performance | Lightweight | Feature-rich |
| Learning Curve | Easy | Steep |
| Admin UI | Simple | Rich Dashboard |
| Dynamic Config | API | File-based/API |

## Next Steps

1. Stop and remove the old Traefik stack
2. Update your DNS configuration to use Caddy
3. Test local domain access (*.ms01)
4. Configure port forwarding for public access (optional)
5. Update firewall rules as needed
