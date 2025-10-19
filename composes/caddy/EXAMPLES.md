# Caddy Configuration Examples

This file contains various Caddy configuration examples that can be added to the `Caddyfile`.

## Basic Examples

### Simple Reverse Proxy
```caddyfile
service.ms01 {
  reverse_proxy 192.168.5.10:8080
}
```

### Multiple Services
```caddyfile
jellyfin.ms01 {
  reverse_proxy 192.168.5.10:8096
}

sonarr.ms01 {
  reverse_proxy 192.168.5.10:8989
}

radarr.ms01 {
  reverse_proxy 192.168.5.10:7878
}
```

## Advanced Examples

### With Custom Headers
```caddyfile
service.ms01 {
  reverse_proxy 192.168.5.10:8080 {
    header_up X-Forwarded-Host {host}
    header_up X-Forwarded-Proto {scheme}
    header_up X-Real-IP {remote_ip}
    header_up X-Forwarded-For {remote_ip}
  }
}
```

### Load Balancing
```caddyfile
api.ms01 {
  reverse_proxy 192.168.5.10:8080 192.168.5.11:8080 {
    lb_policy round_robin
    health_uri /health
    health_interval 10s
    health_timeout 5s
  }
}
```

### With Basic Authentication
```caddyfile
admin.ms01 {
  basicauth / {
    admin JDJhJDE0JHhGeXNnTFVWVWlwUk5tNnhCMEwwdQ==
  }
  reverse_proxy 192.168.5.10:3000
}
```

To generate a hashed password:
```bash
docker exec caddy_gateway caddy hash-password -p "your-password"
```

### With Request Headers Manipulation
```caddyfile
app.ms01 {
  reverse_proxy 192.168.5.10:3000 {
    header_up Host {http.request.host}
    header_up X-Real-IP {remote_ip}
    header_up X-Forwarded-For {remote_ip}
    header_up X-Forwarded-Proto http
    header_down -Server
    header_down -X-Powered-By
  }
}
```

### With Path-Based Routing
```caddyfile
example.ms01 {
  handle /api/* {
    reverse_proxy 192.168.5.10:5000
  }
  
  handle /static/* {
    root * /srv/static
    file_server
  }
  
  handle {
    reverse_proxy 192.168.5.10:3000
  }
}
```

### Path Rewriting
```caddyfile
service.ms01 {
  handle_path /oldpath/* {
    rewrite * /newpath{path}
    reverse_proxy 192.168.5.10:8080
  }
}
```

### With HTTPS (Internal Self-Signed)
```caddyfile
jellyfin.ms01 {
  reverse_proxy 192.168.5.10:8096
  tls internal
}
```

### With HTTPS (Public Domain - Auto Certificate)
```caddyfile
media.mariogk.com {
  reverse_proxy 192.168.5.10:8096
}

home.mariogk.com {
  reverse_proxy 192.168.5.10:8123
}
```

### Error Handling
```caddyfile
service.ms01 {
  reverse_proxy 192.168.5.10:8080 {
    health_uri /health
    health_interval 10s
  }
  
  handle_errors {
    rewrite * /{http.error.status_code}.html
    file_server
  }
}
```

### Compression
```caddyfile
service.ms01 {
  encode gzip
  reverse_proxy 192.168.5.10:8080
}
```

### Rate Limiting (with rate_limit plugin)
```caddyfile
api.ms01 {
  rate_limit * 100r/m
  reverse_proxy 192.168.5.10:5000
}
```

### Redirect
```caddyfile
old-domain.ms01 {
  redir https://new-domain.ms01{uri}
}
```

### Multiple Backends with Fallback
```caddyfile
service.ms01 {
  reverse_proxy 192.168.5.10:8080 192.168.5.11:8080 {
    lb_policy random
    health_uri /health
    health_interval 10s
  }
}
```

### With Request Timeout
```caddyfile
longrunning.ms01 {
  reverse_proxy 192.168.5.10:8080 {
    transport http {
      write_timeout 30s
      read_timeout 30s
      dial_timeout 10s
    }
  }
}
```

### WebSocket Support
```caddyfile
ws.ms01 {
  reverse_proxy 192.168.5.10:8080 {
    header_up Connection "upgrade"
    header_up Upgrade "websocket"
  }
}
```

### File Serving + Reverse Proxy
```caddyfile
app.ms01 {
  root * /srv/app
  
  try_files {path} /index.html
  
  handle /api/* {
    reverse_proxy 192.168.5.10:5000
  }
  
  file_server
}
```

### Response Header Manipulation
```caddyfile
service.ms01 {
  reverse_proxy 192.168.5.10:8080 {
    header_down -Server
    header_down -X-Powered-By
    header_down -X-AspNet-Version
  }
}
```

### CORS Configuration
```caddyfile
api.ms01 {
  reverse_proxy 192.168.5.10:5000 {
    header_up Origin {http.request.host}
    header_down Access-Control-Allow-Origin *
    header_down Access-Control-Allow-Methods *
    header_down Access-Control-Allow-Headers *
  }
}
```

### Multiple Domains Pointing to Same Backend
```caddyfile
service.ms01, service2.ms01, service3.ms01 {
  reverse_proxy 192.168.5.10:8080
}
```

### Wildcard Domain Routing
```caddyfile
*.apps.ms01 {
  reverse_proxy 192.168.5.10:8080
}
```

### Full Featured Example
```caddyfile
app.ms01 {
  encode gzip
  
  handle /api/* {
    reverse_proxy 192.168.5.10:5000 192.168.5.11:5000 {
      lb_policy least_conn
      health_uri /health
      health_interval 10s
      
      header_up X-Real-IP {remote_ip}
      header_up X-Forwarded-For {remote_ip}
      header_up X-Forwarded-Proto {scheme}
      
      header_down -Server
      header_down Access-Control-Allow-Origin *
    }
  }
  
  handle {
    reverse_proxy 192.168.5.10:3000 {
      header_up X-Real-IP {remote_ip}
    }
  }
}
```

## Docker Compose Network Example

If services are running in Docker on the same network:

```caddyfile
service.ms01 {
  reverse_proxy http://service-container:8080
}
```

Use the service's Docker container name instead of IP address.

## Testing Configurations

### Validate Caddyfile
```bash
docker exec caddy_gateway caddy validate
```

### Reload Configuration
```bash
curl -X POST http://localhost:2019/reload
```

### Check Configuration
```bash
curl http://localhost:2019/config/apps/http/servers/http/routes
```

### Test Service Access
```bash
curl -i -H "Host: service.ms01" http://192.168.5.10
```

## Common Patterns

### Redirect HTTP to HTTPS
```caddyfile
service.ms01 {
  redir http:// https://
  reverse_proxy 192.168.5.10:8080
}
```

### Compress Large Responses
```caddyfile
service.ms01 {
  encode {
    gzip
    brotli
  }
  reverse_proxy 192.168.5.10:8080
}
```

### Debug Headers
```caddyfile
service.ms01 {
  reverse_proxy 192.168.5.10:8080 {
    header_up X-Debug-Time {now}
    header_up X-Debug-Host {http.request.host}
  }
}
```

## References

- [Caddyfile Syntax](https://caddyserver.com/docs/caddyfile/concepts)
- [Reverse Proxy Directive](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [All Directives](https://caddyserver.com/docs/caddyfile/directives)
- [Placeholders](https://caddyserver.com/docs/caddyfile/concepts)
