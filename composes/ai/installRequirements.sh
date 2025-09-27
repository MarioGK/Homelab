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

main() {
  wait_for_network

  if ! wait_for_pacman_lock; then
    log "pacman lock unresolved, exiting."
    exit 1
  fi

  # Update package database + system (safe to run repeatedly)
  log "Updating system packages (pacman -Syu)"
  pacman -Syu --noconfirm

  # Install openssh if missing
  install_package_if_missing openssh

  # Manage SSH key
  add_ssh_key

  # Install paru from AUR if missing
  install_paru || log "paru installation failed (continuing)"

  # Clean pacman cache (optional, idempotent)
  log "Cleaning pacman cache"
  pacman -Scc --noconfirm || true

  # Start sshd
  start_sshd

  # Create sentinel to mark completion
  mkdir -p "$(dirname "$SENTINEL")"
  printf '%s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ') installed" > "$SENTINEL"
  log "installRequirements completed; sentinel created at $SENTINEL"

  # Keep the container running indefinitely
  log "Keeping container running indefinitely..."
  while true; do sleep 30; done
}

main "$@"