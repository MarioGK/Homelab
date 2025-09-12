# Copilot Instructions
ALWAYS use context7 to get the documentation for komodo to properly generate new komodo services.

ALWAYS search on the web for the documentation before creating a new stack.

Only create README.md for stacks and services only if necessary.

DO NOT add version to docker compose files.

# Context
This repository is for managing my home server using komodo. It includes configurations for various services and applications that I run on my home lab setup.

When I push this repo, github will send a webhook to my komodo instance and update the services accordingly.

# Tools used
- komodo
- docker
- docker compose

# Timezone
When creating new stacks, ALWAYS set the timezone to Sao Paulo (America/Sao_Paulo).

# Storage layout

## Media storage 16TB RAID0
Two 8TB drives are mounted in RAID0 at `/mnt/media`. This is the primary location for all media files.
It is using BTRFS filesystem with compression enabled.

All media should be stored in `/mnt/media`. This includes:
- Movies
- TV Shows
- Music
- Ebooks
- Audiobooks
- Comics
- Anime
- Photos
- Documents
- Other media types

## Big SSD 3.5TB called 'ssd'
A large SSD is mounted at `/mnt/ssd`. This is used for:
- Application's configuration files.
- App's databases that require more space.
- Virtual machines and containers.
- Docker volumes for applications that require more storage space.

## Small SSD 256GB called 'smol'
A small SSD is mounted at `/mnt/smol`.