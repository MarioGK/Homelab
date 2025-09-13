Local Gateway (declarative DNS + HTTP host routing)

What this provides
- CoreDNS running locally serving the `homelab` zone from a zone file (`coredns/hosts.zone`).
- Traefik acting as a file-driven reverse proxy. Dynamic mappings live under `traefik/dynamic/*.yml`.

How it is declarative
- To add or change a DNS name: edit `coredns/hosts.zone` and update the A records.
- To route a hostname to an IP:port, add a router + service pair to a file inside `traefik/dynamic/` (see `hosts.yml`). Traefik watches that directory.

Example
- To map `jellyfin.homelab` to `192.168.5.10:8096`:
  - Add `jellyfin IN A 192.168.5.10` in `coredns/hosts.zone`.
  - Ensure `traefik/dynamic/hosts.yml` contains a service that points to `http://192.168.5.10:8096` with a router rule `Host(`jellyfin.homelab`)`.

Running
- Start the stack from `stacks/local-gateway`:
  docker compose up -d

Make your clients use the DNS
- Easiest: point your router DHCP DNS to the machine running this gateway (IP: 192.168.x.y) so all clients resolve `*.homelab` locally.
- Quick test on a single client: set the system DNS to the host running this stack.

Security notes
- The Traefik dashboard is enabled insecurely on port 8080 for convenience. If exposing to untrusted networks, secure it.

Next steps (optional)
- Add TLS: use Traefik's file provider to attach certificates (or enable ACME with a local CA).
- Add more dynamic examples and templating.
