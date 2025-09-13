Home Assistant stack

Files:
- docker-compose.yml - docker-compose for Home Assistant (host network, config volume)
- config stored on SSD at `/mnt/ssd/home-assistant/config` and mounted into Home Assistant

Quick start

1. Edit `docker-compose.yml` and change TZ if needed. This stack defaults to `America/Sao_Paulo`.
2. Ensure `/mnt/ssd/home-assistant/config` is owned by the user running Docker, or adjust permissions:

   sudo mkdir -p /mnt/ssd/home-assistant/config
   sudo chown -R 1000:1000 /mnt/ssd/home-assistant/config

3. Start the stack:

   docker compose up -d

Notes
- This stack uses host networking; Home Assistant will bind directly to the host network (recommended for discovery).
- The image used is the `ghcr.io/home-assistant/home-assistant:stable` release image. To run a specific version, change the `image` tag.
- The default timezone and coordinates in `config/configuration.yaml` are set for São Paulo (`America/Sao_Paulo`, lat: -23.5505, long: -46.6333). Change them if required.
- Back up the `/mnt/ssd/home-assistant/config` directory regularly (it contains your database, secrets, and config files).
- For more advanced setups (supervised, add-ons), consider the official Home Assistant OS or Supervisor installations.
