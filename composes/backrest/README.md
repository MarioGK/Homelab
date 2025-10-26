# Backrest Backup Stack

Backrest is a web-accessible backup solution built on restic. This stack backs up all configuration files in `/mnt/ssd/configs` to a Hetzner Storage Box (or other storage backend supported by rclone/restic).

## Features

- **Web Interface**: Access at `http://localhost:9898` to manage backups
- **Multi-Backend Support**: Compatible with S3, B2, Azure, GCS, SFTP, and all rclone remotes
- **Scheduled Backups**: Cron-based backup scheduling
- **Repository Management**: Browse snapshots, restore files, manage retention policies
- **Notifications**: Configurable alerts via Discord, Slack, Gotify, Healthchecks, etc.
- **Pre/Post Hooks**: Execute scripts before/after backups

## Quick Start

### 1. Deploy the Stack

```bash
# The stack will be deployed automatically by Komodo
# Or manually deploy with:
docker-compose -f composes/backrest/compose.yaml up -d
```

### 2. Access the Web UI

- **Local Access**: http://localhost:9898
- **Remote Access**: Uncomment `BACKREST_PORT=0.0.0.0:9898` in `stacks/backrest.toml` to allow remote connections

### 3. Initial Setup

1. Open http://localhost:9898 in your browser
2. Create username and password on first-time setup
3. Configure a backup repository (see below)

## Configuring Hetzner Storage Box

### Option A: SFTP Backend (Recommended)

1. **Generate SSH Keys** (inside the container):
```bash
docker exec backrest mkdir -p /root/.ssh
docker exec backrest ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -C "backrest-backup-key" -N ""
docker exec backrest cat /root/.ssh/id_ed25519.pub
```

2. **Add to Hetzner Storage Box**:
   - Log in to your Hetzner account
   - Go to Storage Box > SSH Keys
   - Add the public key from step 1

3. **In Backrest UI**:
   - Create new repository
   - Type: SFTP
   - Repository URL: `sftp:backrest-hetzner:/backup` (adjust path as needed)
   - Host: `your-storage-box.your-domain.com`
   - Port: `22`
   - Username: Your Hetzner username
   - Identity file: `/root/.ssh/id_ed25519`

### Option B: Rclone Backend

1. **Configure rclone** in the Backrest UI:
   - Type: Rclone
   - Remote: Create a new rclone remote or use existing one
   - Path: `/backup` or your desired path

2. **Use the template** at `rclone.conf.template` for reference

## Backup Configuration

### What Gets Backed Up

All files in `/mnt/ssd/configs` are mounted as `/userdata` in the container and can be included in backup plans.

### Create a Backup Plan

In the Backrest Web UI:

1. **Repositories** → Create repository (SFTP or Rclone)
2. **Plans** → Create plan
   - Plan name: e.g., "ssd-configs-backup"
   - Repository: Select your configured repository
   - Backup paths: `/userdata` (this is `/mnt/ssd/configs` on host)
   - Schedule: e.g., `0 2 * * *` (daily at 2 AM)
   - Retention: Configure as needed (e.g., keep last 7 daily, 4 weekly, 12 monthly)

### Run Manual Backup

In the Backrest Web UI:
- **Plans** → Select your plan → Click "Backup Now"

## Environment Variables

- `TZ`: Timezone (set to `America/Sao_Paulo`)
- `BACKREST_DATA`: Data directory (`/data`)
- `BACKREST_CONFIG`: Config file path (`/config/config.json`)
- `XDG_CACHE_HOME`: Cache directory (`/cache`)
- `TMPDIR`: Temporary directory (`/tmp`)
- `BACKREST_PORT`: Listen address (default: `127.0.0.1:9898`)

## Volumes

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `/mnt/ssd/configs/backrest/data` | `/data` | Backrest data and restic binary |
| `/mnt/ssd/configs/backrest/config` | `/config` | Backrest configuration |
| `/mnt/ssd/configs/backrest/cache` | `/cache` | Restic cache (improves performance) |
| `/mnt/ssd/configs/backrest/tmp` | `/tmp` | Temporary files |
| `/mnt/ssd/configs/backrest/rclone` | `/root/.config/rclone` | Rclone configuration |
| `/mnt/ssd/configs` | `/userdata` | Files to backup (read-only) |

## Hooks and Notifications

Configure hooks in the Backrest UI to:
- Send notifications on backup success/failure
- Run custom scripts before/after backups
- Integrate with Discord, Slack, Gotify, Healthchecks, etc.

Example: Discord webhook
```
Service: Discord
Conditions: CONDITION_SNAPSHOT_SUCCESS, CONDITION_SNAPSHOT_ERROR
Webhook URL: https://discordapp.com/api/webhooks/...
```

## Troubleshooting

### Port 9898 Already in Use
Change `BACKREST_PORT` in `stacks/backrest.toml` to a different port (e.g., `127.0.0.1:9899`)

### Cannot Connect to Hetzner Storage Box
1. Verify SSH key is added to Hetzner account
2. Test SSH connection from container: `docker exec backrest ssh -i /root/.ssh/id_ed25519 your-username@your-storage-box.your-domain.com`
3. Check firewall rules on Hetzner side

### Backup Fails
1. Check operation logs in Backrest UI
2. Verify repository credentials
3. Ensure `/mnt/ssd/configs` is mounted and accessible

## References

- [Backrest GitHub](https://github.com/garethgeorge/backrest)
- [Backrest Documentation](https://garethgeorge.github.io/backrest/)
- [Restic Documentation](https://restic.readthedocs.io/)
- [Rclone Documentation](https://rclone.org/)
- [Hetzner Storage Box](https://www.hetzner.com/storage/storage-box)
