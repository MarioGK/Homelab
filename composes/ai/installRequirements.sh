#!/usr/bin/env bash
set -euo pipefail

# Idempotent installer for Arch-based containers.
# - Safe to run multiple times (uses a sentinel file)
# - Waits for network + pacman lock
# - Installs openssh if missing and adds SSH key only if not present
# - Installs paru only if missing
# - Starts sshd (uses systemctl if available; otherwise runs sshd in background)
#
# Usage:
#   Provide SSH_PUBLIC_KEY env var to set the key to add (optional).
#   Run this as root inside the container at startup (entrypoint or docker-compose command).

SENTINEL="/var/lib/installRequirements.done"
SSH_AUTH="/root/.ssh/authorized_keys"
SSH_KEY="${SSH_PUBLIC_KEY:-your_public_ssh_key_here}"
PARU_BIN="/usr/bin/paru"
MAX_WAIT=60
# Default flags for non-interactive paru usage
PARU_FLAGS="--noconfirm --needed --noprogressbar"
# Optional environment flags to skip specific installers (set to 1 to skip)
SKIP_DOTNET=${SKIP_DOTNET:-0}
SKIP_NODE=${SKIP_NODE:-0}
SKIP_BUN=${SKIP_BUN:-0}
SKIP_CLAUDE=${SKIP_CLAUDE:-0}
SKIP_OPENCODE=${SKIP_OPENCODE:-0}
SKIP_AIDER=${SKIP_AIDER:-0}

log() { printf '%s %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }

# If already ran, exit quickly
if [[ -f "$SENTINEL" ]]; then
  log "installRequirements: sentinel found ($SENTINEL). Nothing to do."
  exit 0
fi

# Wait for (optional) network connectivity
wait_for_network() {
  local i=0
  log "Waiting for network..."
  while true; do
    if command -v curl >/dev/null 2>&1; then
      if curl -fsS --connect-timeout 3 https://archlinux.org >/dev/null 2>&1; then
        break
      fi
    elif command -v ping >/dev/null 2>&1; then
      if ping -c1 -W1 archlinux.org >/dev/null 2>&1; then
        break
      fi
    else
      # No reliable network check tools; assume network may be present
      break
    fi
    i=$((i+1))
    if (( i >= MAX_WAIT )); then
      log "Network wait timed out after ${MAX_WAIT}s, continuing anyway."
      break
    fi
    sleep 1
  done
}

# Wait for pacman DB lock to be released
wait_for_pacman_lock() {
  local lock="/var/lib/pacman/db.lck"
  local i=0
  if [[ -e "$lock" ]]; then
    log "pacman lock detected, waiting..."
    while [[ -e "$lock" ]]; do
      sleep 1
      i=$((i+1))
      if (( i >= MAX_WAIT )); then
        log "pacman lock not released after ${MAX_WAIT}s, exiting."
        return 1
      fi
    done
  fi
  return 0
}

add_ssh_key() {
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
  touch "$SSH_AUTH"
  chmod 600 "$SSH_AUTH"
  if [[ -z "$SSH_KEY" ]]; then
    log "No SSH key provided (SSH_PUBLIC_KEY empty). Skipping authorized_keys modification."
    return
  fi
  if grep -Fxq "$SSH_KEY" "$SSH_AUTH" >/dev/null 2>&1; then
    log "SSH key already present in $SSH_AUTH"
  else
    log "Adding SSH key to $SSH_AUTH"
    printf '%s\n' "$SSH_KEY" >> "$SSH_AUTH"
    chown root:root "$SSH_AUTH" || true
    chmod 600 "$SSH_AUTH"
  fi
}

install_package_if_missing() {
  local pkg="$1"
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    log "Package $pkg already installed"
    return 0
  fi
  log "Installing package: $pkg"
  pacman -S --noconfirm "$pkg"
}

install_paru() {
  if command -v paru >/dev/null 2>&1 || [[ -x "$PARU_BIN" ]]; then
    log "paru already installed"
    return 0
  fi

  # Ensure base-devel and git present
  install_package_if_missing git || true
  install_package_if_missing base-devel || true

  tmpdir="$(mktemp -d)"
  log "Building paru in $tmpdir"
  git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
  pushd "$tmpdir/paru" >/dev/null
  # makepkg may require a TTY; use --noconfirm and --needed if available
  makepkg -si --noconfirm || {
    log "paru build failed"
    popd >/dev/null
    rm -rf "$tmpdir"
    return 1
  }
  popd >/dev/null
  rm -rf "$tmpdir"
  log "paru installed"
}

# Configure /etc/paru.conf: backup and set BottomUp and SkipReview
configure_paru_conf() {
  local conf="/etc/paru.conf"
  local ts
  ts=$(date +%Y%m%d%H%M%S)

  if [[ ! -e "$conf" ]]; then
    log "$conf not found; skipping paru.conf modification"
    return 0
  fi

  if [[ ! -w "$conf" ]]; then
    # Try to create backup with sudo if current user cannot write; fail gracefully
    cp "$conf" "$conf.bak.$ts" 2>/dev/null || sudo cp "$conf" "$conf.bak.$ts" || {
      log "Failed to create backup of $conf; skipping modifications"
      return 0
    }
  else
    cp "$conf" "$conf.bak.$ts" || log "Failed to create backup of $conf"
  fi
  log "Backup created: $conf.bak.$ts"

  # If '#BottomUp' exists, replace it with 'BottomUp' and add 'SkipReview' on the next line.
  # If 'BottomUp' already present and SkipReview missing, ensure SkipReview is present.
  if grep -q '^[[:space:]]*#\s*BottomUp' "$conf"; then
    sed -i 's/^[[:space:]]*#\s*BottomUp/BottomUp\nSkipReview/' "$conf" || true
    log "Replaced commented '#BottomUp' with 'BottomUp and SkipReview' in $conf"
  else
    # If BottomUp is present but SkipReview missing, append SkipReview after BottomUp
    if grep -q '^[[:space:]]*BottomUp' "$conf" && ! grep -q '^[[:space:]]*SkipReview' "$conf"; then
      sed -i '/^[[:space:]]*BottomUp/a SkipReview' "$conf" || true
      log "Added 'SkipReview' after existing 'BottomUp' in $conf"
    fi
  fi
}

# Installers for additional developer tools (idempotent / best-effort)
install_dotnet() {
  if [[ "$SKIP_DOTNET" == "1" ]]; then
    log "Skipping dotnet install due to SKIP_DOTNET=1"
    return 0
  fi
  if command -v dotnet >/dev/null 2>&1; then
    log "dotnet already installed: $(dotnet --version 2>/dev/null || echo installed)"
    return 0
  fi
  log "Attempting to install dotnet preview packages (best-effort)"
  # Preferred package list (AUR names / common packaging for preview builds)
  local pkgs=(
    dotnet-targeting-pack-preview-bin
    dotnet-sdk-preview-bin
    dotnet-host-preview-bin
    aspnet-targeting-pack-preview-bin
    dotnet-runtime-preview-bin
    aspnet-runtime-preview-bin
  )

  # If any preview package is already installed, skip install step for that package
  local to_install=()
  for p in "${pkgs[@]}"; do
    if pacman -Q "$p" >/dev/null 2>&1; then
      log "Package $p already installed"
    else
      to_install+=("$p")
    fi
  done

  if [[ ${#to_install[@]} -eq 0 ]]; then
    log "All requested dotnet preview packages already installed"
  else
    # Try pacman first for any package that might exist in repos
    for p in "${to_install[@]}"; do
      if pacman -Si "$p" >/dev/null 2>&1; then
        log "Installing $p via pacman"
        pacman -S --noconfirm "$p" || true
      else
        # Fall back to AUR via paru
        if command -v paru >/dev/null 2>&1; then
          log "Installing $p via paru (AUR)"
          paru -S ${PARU_FLAGS} "$p" || log "paru failed to install $p"
        else
          log "Package $p not in repos and paru unavailable; skipping $p"
        fi
      fi
    done
  fi
  if command -v dotnet >/dev/null 2>&1; then
    log "dotnet installed: $(dotnet --version 2>/dev/null || echo installed)"
  else
    log "dotnet installation not detected after attempts"
  fi
}

install_node_and_npm() {
  if [[ "$SKIP_NODE" == "1" ]]; then
    log "Skipping node/npm install due to SKIP_NODE=1"
    return 0
  fi
  if command -v node >/dev/null 2>&1; then
    log "node already installed: $(node --version 2>/dev/null || echo installed)"
  else
    log "Installing nodejs and npm via pacman"
    pacman -S --noconfirm nodejs npm || true
  fi
  if command -v npm >/dev/null 2>&1; then
    log "npm available: $(npm --version 2>/dev/null || echo installed)"
  else
    log "npm not found after pacman install; trying AUR via paru"
    if command -v paru >/dev/null 2>&1; then
      paru -S ${PARU_FLAGS} npm || true
    fi
  fi
}

install_bun() {
  if [[ "$SKIP_BUN" == "1" ]]; then
    log "Skipping bun install due to SKIP_BUN=1"
    return 0
  fi
  if command -v bun >/dev/null 2>&1; then
    log "bun already installed: $(bun --version 2>/dev/null || echo installed)"
    return 0
  fi
  log "Installing bun using official installer"
  # Install to root home (idempotent if run multiple times)
  if curl -fsSL https://bun.sh/install | bash -s -- --no-check || true; then
    # Installer typically places bun under /root/.bun/bin/bun, add a system symlink
    if [[ -x "/root/.bun/bin/bun" ]]; then
      ln -sf /root/.bun/bin/bun /usr/local/bin/bun || true
      log "bun installed and symlinked to /usr/local/bin/bun"
    else
      log "bun installer ran but expected binary not found; check /root/.bun/bin"
    fi
  else
    log "bun installer failed"
  fi
}

install_claude_code_cli() {
  if [[ "$SKIP_CLAUDE" == "1" ]]; then
    log "Skipping Claude Code CLI install due to SKIP_CLAUDE=1"
    return 0
  fi
  # There are multiple community CLIs for Anthropic/Claude — try a few common install methods
  if command -v claude >/dev/null 2>&1 || command -v "claude-code" >/dev/null 2>&1; then
    log "Claude CLI already present"
    return 0
  fi
  log "Attempting to install Claude Code CLI (best-effort)."
  # Try npm global package (community packages may exist)
  if command -v npm >/dev/null 2>&1; then
    npm install -g @anthropic/claude || npm install -g claude-code || true
  fi
  # Try pip as fallback
  if command -v pip >/dev/null 2>&1; then
    pip install claude || pip install claude-cli || true
  fi
  # If still not available, attempt to clone a likely GitHub repo (best-effort, no guarantees)
  if ! command -v claude >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    log "Cloning potential Claude CLI repos to $tmp (best-effort)"
    git clone https://github.com/anthropic/claude.git "$tmp/claude" >/dev/null 2>&1 || true
    # No reliable install step is guaranteed here; user may need to adjust.
    rm -rf "$tmp"
  fi
  if command -v claude >/dev/null 2>&1; then
    log "Claude CLI installed"
  else
    log "Claude CLI not found after attempts — manual install may be required"
  fi
}

install_opencode() {
  if [[ "$SKIP_OPENCODE" == "1" ]]; then
    log "Skipping opencode install due to SKIP_OPENCODE=1"
    return 0
  fi
  if command -v opencode >/dev/null 2>&1; then
    log "opencode already installed"
    return 0
  fi
  log "Attempting to install opencode (best-effort)"
  # Prefer paru opencode-bin if paru is available, otherwise try npm global install
  if command -v paru >/dev/null 2>&1; then
    log "Installing opencode via paru (opencode-bin)"
    paru -S ${PARU_FLAGS} opencode-bin || log "paru failed to install opencode-bin; falling back"
  else
    if command -v npm >/dev/null 2>&1; then
      npm i -g opencode-ai@latest || true
    fi
  fi
  if command -v opencode >/dev/null 2>&1; then
    log "opencode installed"
  else
    log "opencode not detected after attempts"
  fi
}

install_avahi() {
  # Install avahi (mDNS) and nss-mdns so the container can be discovered as <name>.local on the LAN.
  if pacman -Q avahi >/dev/null 2>&1; then
    log "avahi already installed"
  else
    log "Installing avahi and nss-mdns"
    pacman -S --noconfirm avahi nss-mdns || true
  fi

  # Ensure nsswitch.conf includes mdns lookup for hosts (idempotent)
  if [[ -w /etc/nsswitch.conf ]]; then
    if grep -q 'mdns_minimal' /etc/nsswitch.conf; then
      log "/etc/nsswitch.conf already contains mdns_minimal entry"
    else
      log "Adding mdns_minimal entry to /etc/nsswitch.conf"
      # Insert mdns_minimal before 'hosts:' lookups fallback to files dns
      sed -i 's/^hosts:\s*/hosts: files mdns_minimal [NOTFOUND=return] /' /etc/nsswitch.conf || true
    fi
  else
    log "/etc/nsswitch.conf not writable; skipping mdns config"
  fi

  # Start avahi-daemon (use systemctl if available, otherwise run in background)
  if command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1; then
    log "Enabling and starting avahi-daemon via systemctl"
    systemctl enable avahi-daemon || true
    systemctl start avahi-daemon || true
  else
    # Ensure dbus is available and running (avahi requires dbus)
    if pacman -Q dbus >/dev/null 2>&1; then
      log "dbus already installed"
    else
      log "Installing dbus"
      pacman -S --noconfirm dbus || true
    fi

    # Start dbus-daemon in background if not running
    if pgrep -f dbus-daemon >/dev/null 2>&1; then
      log "dbus-daemon already running"
    else
      log "Starting dbus-daemon in background"
      # Create runtime dir if missing
      mkdir -p /var/run/dbus || true
      dbus-daemon --system --fork >/dev/null 2>&1 || true
    fi

    # Try to run avahi-daemon in background if binary exists
    if command -v avahi-daemon >/dev/null 2>&1; then
      # If already running, skip
      if pgrep -f avahi-daemon >/dev/null 2>&1; then
        log "avahi-daemon already running"
      else
        log "Starting avahi-daemon in background"
        /usr/sbin/avahi-daemon --no-chroot >/dev/null 2>&1 &
      fi
    else
      log "avahi-daemon not found after install attempts"
    fi
  fi
}

set_container_hostname() {
  # If CONTAINER_DOMAIN is provided (e.g., ai1.local), set the system hostname accordingly
  local domain=${CONTAINER_DOMAIN:-}
  if [[ -z "$domain" ]]; then
    log "CONTAINER_DOMAIN not set; skipping hostname change"
    return 0
  fi

  # strip .local suffix if present
  local hostonly
  hostonly=${domain%%.local}
  # If hostonly equals domain it didn't contain .local; try strip after last '.' anyway
  if [[ "$hostonly" == "$domain" && "$domain" == *.* ]]; then
    hostonly=${domain%%.*}
  fi

  if [[ -z "$hostonly" ]]; then
    log "Derived empty hostname from CONTAINER_DOMAIN ($domain); skipping"
    return 0
  fi

  # Set /etc/hostname (idempotent)
  if [[ -w /etc/hostname ]] || [[ ! -e /etc/hostname ]]; then
    if [[ "$(cat /etc/hostname 2>/dev/null || echo)" == "$hostonly" ]]; then
      log "Hostname already set to $hostonly"
    else
      log "Setting hostname to $hostonly"
      printf '%s\n' "$hostonly" > /etc/hostname
      hostname "$hostonly" || true
    fi
  else
    log "/etc/hostname not writable; skipping hostname file write"
  fi
}

install_aider() {
  if [[ "$SKIP_AIDER" == "1" ]]; then
    log "Skipping aider install due to SKIP_AIDER=1"
    return 0
  fi
  if command -v aider >/dev/null 2>&1; then
    log "aider already installed"
    return 0
  fi

  log "Attempting to install aider via 'python -m pip install aider-install'"
  # Prefer python -m pip install aider-install, then run aider-install
  if command -v python3 >/dev/null 2>&1; then
    python3 -m pip install --upgrade pip || true
    if python3 -m pip install aider-install; then
      log "aider-install package installed via pip"
      if command -v aider-install >/dev/null 2>&1; then
        log "Running 'aider-install' to complete installation"
        aider-install || log "aider-install command failed"
      else
        # Some packages expose console entry points differently; try running module as script
        python3 -m aider_install || true
      fi
    fi
  fi
  if command -v aider >/dev/null 2>&1; then
    log "aider installed: $(aider --version 2>/dev/null || echo installed)"
  else
    log "aider not found after attempts"
  fi
}

start_sshd() {
  if command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1; then
    log "Using systemctl to enable/start sshd"
    systemctl enable sshd || true
    systemctl start sshd || true
  elif command -v sshd >/dev/null 2>&1; then
    # Try run sshd in background (non-daemonize flag may vary). Use -D to stay in foreground if desired.
    log "Starting sshd in background"
    /usr/sbin/sshd -D >/dev/null 2>&1 &
  else
    log "sshd binary not found; skipping sshd start"
  fi
}

# Configure /etc/pacman.conf: backup, uncomment Color, and set ParallelDownloads = 50
configure_pacman() {
  local conf="/etc/pacman.conf"
  local ts
  ts=$(date +%Y%m%d%H%M%S)

  if [[ ! -w "$conf" ]]; then
    log "${conf} not writable or missing; skipping pacman.conf modification"
    return 0
  fi

  # Create a timestamped backup
  cp "$conf" "$conf.bak.$ts" || log "Failed to create backup of $conf"
  log "Backup created: $conf.bak.$ts"

  # Uncomment a leading '#Color' (idempotent)
  if grep -q '^[[:space:]]*#\s*Color' "$conf"; then
    sed -i 's/^[[:space:]]*#\s*Color/Color/' "$conf" || true
    log "Uncommented 'Color' in $conf"
  else
    log "'Color' already uncommented or not present in $conf"
  fi

  # Set ParallelDownloads = 50 (handle commented, uncommented, or missing cases idempotently)
  if grep -q '^[[:space:]]*ParallelDownloads' "$conf"; then
    sed -i 's/^[[:space:]]*ParallelDownloads.*$/ParallelDownloads = 50/' "$conf" || true
    log "Set existing ParallelDownloads to 50 in $conf"
  elif grep -q '^[[:space:]]*#\s*ParallelDownloads' "$conf"; then
    sed -i 's/^[[:space:]]*#\s*ParallelDownloads.*$/ParallelDownloads = 50/' "$conf" || true
    log "Uncommented and set ParallelDownloads = 50 in $conf"
  else
    # If [options] exists, add the setting immediately after it; otherwise append to end of file
    if grep -q '^\[options\]' "$conf"; then
      if ! grep -q '^[[:space:]]*ParallelDownloads' "$conf"; then
        sed -i '/^\[options\]/a ParallelDownloads = 50' "$conf" || true
        log "Added ParallelDownloads = 50 under [options] in $conf"
      fi
    else
      echo -e "\n# Added by installRequirements.sh\nParallelDownloads = 50" >> "$conf" || true
      log "Appended ParallelDownloads = 50 to end of $conf"
    fi
  fi
}

main() {
  wait_for_network

  if ! wait_for_pacman_lock; then
    log "pacman lock unresolved, exiting."
    exit 1
  fi

  # Configure pacman settings (backup + set Color and ParallelDownloads)
  configure_pacman || log "configure_pacman failed (continuing)"

  # Update package database + system (safe to run repeatedly)
  log "Updating system packages (pacman -Syu)"
  pacman -Syu --noconfirm

  # Install openssh if missing
  install_package_if_missing openssh

  # Manage SSH key
  add_ssh_key

  # Install paru from AUR if missing
  install_paru || log "paru installation failed (continuing)"

  # Configure paru.conf (backup + set BottomUp and SkipReview)
  configure_paru_conf || log "configure_paru_conf failed (continuing)"

  # Clean pacman cache (optional, idempotent)
  log "Cleaning pacman cache"
  pacman -Scc --noconfirm || true

  # Start sshd
  start_sshd

  # Set hostname based on CONTAINER_DOMAIN env var (used for mDNS name)
  set_container_hostname || log "set_container_hostname failed (continuing)"

  # Install and start avahi so the container announces <hostname>.local on the LAN
  install_avahi || log "install_avahi failed (continuing)"

  # Install developer tools (best-effort)
  install_dotnet || true
  install_node_and_npm || true
  install_bun || true
  install_claude_code_cli || true
  install_opencode || true
  install_aider || true

  # Create sentinel to mark completion
  mkdir -p "$(dirname "$SENTINEL")"
  printf '%s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ') installed" > "$SENTINEL"
  log "installRequirements completed; sentinel created at $SENTINEL"

  # Keep the container running indefinitely
  log "Keeping container running indefinitely..."
  while true; do sleep 30; done
}

main "$@"