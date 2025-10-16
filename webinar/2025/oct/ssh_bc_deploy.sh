#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Multi-user SSH Breadcrumb dropper (single key, per-user placement, no-clobber)
# - Collects server host keys via ssh-keyscan
# - Adds them to each user's ~/.ssh/known_hosts
# - Generates a single shared keypair once, reuses it for all users
# - Copies that key into each user's ~/.ssh/ (only if missing)
# - Writes per-user ~/.ssh/config entries pointing to the per-user key
# -----------------------------------------------------------------------------

set -euo pipefail

##### ======= CONFIGURE ME ======= #####
# Canary SSH server details
CANARY_HOST="172.31.50.145"      # hostname or IP to connect to 
CANARY_SSH_PORT="22"              # SSH port
CANARY_HOST_ALIAS="MYSQLDBPROD2"  # users will: ssh jumpbox-prod 

# Key generation (this is the one key we reuse for all users)
KEY_TYPE="ed25519"                          # ed25519 or rsa
KEY_BITS="4096"                             # only used if KEY_TYPE=rsa
KEY_COMMENT="$CANARY_HOST_ALIAS-login-key"  # appears in the .pub file
KEY_PASSPHRASE=""                           # leave empty for no passphrase
KEY_BASENAME="id_$CANARY_HOST_ALIAS"        # filename placed in each user's ~/.ssh/

# Known-hosts behavior
KEYSCAN_TIMEOUT="5"               # seconds for ssh-keyscan -T
KEYSCAN_TYPES="ed25519"           # which host key types to fetch

# Which users to configure
INCLUDE_ROOT="yes"               # add entries for root as well

##### ===== END OF CONFIG ===== #####

# --- Helpers ---
log()  { echo "[*] $*"; }
warn() { echo "[!] $*" >&2; }
die()  { echo "[x] $*" >&2; exit 1; }

require_cmd() {
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "Required command not found: $c"
  done
}

# --- Preconditions ---
[ "$(id -u)" -eq 0 ] || die "Please run as root (sudo)."
require_cmd ssh-keyscan ssh-keygen getent awk grep install chmod chown mktemp


# --- Get server host keys ---

log "Fetching host keys for ${CANARY_HOST}:${CANARY_SSH_PORT} (types: ${KEYSCAN_TYPES})"
HOSTKEYS="$(ssh-keyscan -T "$KEYSCAN_TIMEOUT" -p "$CANARY_SSH_PORT" -t "$KEYSCAN_TYPES" "$CANARY_HOST" 2>/dev/null || true)"

if [[ -z "$HOSTKEYS" ]]; then
  die "No host keys retrieved from ssh-keyscan. Check host/port/connectivity."
fi

# --- Build user list: all users with a real home dir (optionally include root) ---
select_users() {
  uid_min=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs 2>/dev/null)
  uid_max=$(awk '/^\s*UID_MAX/{print $2}' /etc/login.defs 2>/dev/null)
  : "${uid_min:=1000}" : "${uid_max:=60000}"

  getent passwd | while IFS=: read -r user _ uid _ _ home _; do
    [ "$uid" -ge "$uid_min" ] && [ "$uid" -le "$uid_max" ] && [ -d "$home" ] &&
      printf '%s:%s\n' "$user" "$home"
  done
}

USERS="$(select_users)"
if [[ "$INCLUDE_ROOT" == "yes" ]]; then
  ROOT_HOME="$(getent passwd root | awk -F: '{print $6}')"
  if [[ -n "$ROOT_HOME" && -d "$ROOT_HOME" ]]; then
    USERS=$(printf "root:%s\n%s\n" "$ROOT_HOME" "$USERS")
  fi
fi
[[ -n "$USERS" ]] || die "No eligible users found to configure."

# --- Locate an existing canonical key among users ---
CANON_PRIV=""
CANON_PUB=""
while IFS=: read -r U H _; do
  CAND_PRIV="${H}/.ssh/${KEY_BASENAME}"
  CAND_PUB="${CAND_PRIV}.pub"
  if [[ -f "$CAND_PRIV" || -f "$CAND_PUB" ]]; then
    die "Existing key ($KEY_BASENAME) found with same name - exit"
  fi
done <<< "$USERS"

# --- If no existing key found, generate ONE new key in a secure temp dir ---
if [[ -z "$CANON_PRIV" ]]; then
  TMP_KEY_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_KEY_DIR"' EXIT
  umask 077
  CANON_PRIV="${TMP_KEY_DIR}/${KEY_BASENAME}"
  CANON_PUB="${CANON_PRIV}.pub"
  log "Generating new canonical keypair: $CANON_PRIV"
  if [[ "$KEY_TYPE" == "rsa" ]]; then
    ssh-keygen -t rsa -b "$KEY_BITS" -C "$KEY_COMMENT" -f "$CANON_PRIV" -N "$KEY_PASSPHRASE" -m PEM
  else
    ssh-keygen -t "$KEY_TYPE" -C "$KEY_COMMENT" -f "$CANON_PRIV" -N "$KEY_PASSPHRASE"
  fi
  chmod 0600 "$CANON_PRIV"
  chmod 0644 "$CANON_PUB"
fi

# --- For each user: ensure ~/.ssh, known_hosts, config; add alias ---
while IFS=: read -r USERNAME HOME_DIR USER_SHELL; do
  [[ -n "$USERNAME" && -n "$HOME_DIR" && -d "$HOME_DIR" ]] || { warn "Skipping invalid user/home: $USERNAME:$HOME_DIR"; continue; }

  UGRP="$(id -gn "$USERNAME")"
  SSH_DIR="${HOME_DIR}/.ssh"
  DEST_PRIV="${SSH_DIR}/${KEY_BASENAME}"
  DEST_PUB="${DEST_PRIV}.pub"
  KNOWN_HOSTS="${SSH_DIR}/known_hosts"
  CONFIG_FILE="${SSH_DIR}/config"

  # Create ~/.ssh only if missing (don't touch existing perms/owner)
  if [[ ! -d "$SSH_DIR" ]]; then
    mkdir -p -m 0700 "$SSH_DIR"
    chown "$USERNAME:$UGRP" "$SSH_DIR"
  fi

  # Ensure known_hosts exists; set perms only if we created it
  if [[ ! -f "$KNOWN_HOSTS" ]]; then
    install -m 0644 -o "$USERNAME" -g "$UGRP" /dev/null "$KNOWN_HOSTS"
  fi

  # Append host keys only if that exact key blob isn't already present
  NEW_LINES=0
  while IFS= read -r line; do
    keytype="$(echo "$line" | awk '{print $2}')"
    keyblob="$(echo "$line" | awk '{print $3}')"
    if grep -q " $keytype $keyblob\$" "$KNOWN_HOSTS"; then
      continue
    fi
    echo "$line" >> "$KNOWN_HOSTS"
    NEW_LINES=$((NEW_LINES+1))
  done <<< "$HOSTKEYS"
  [[ "$NEW_LINES" -gt 0 ]] && log "Added $NEW_LINES host key(s) to $USERNAME's known_hosts"

  # Copy canonical key into user's ~/.ssh ONLY IF MISSING (no overwrite)
  if [[ ! -f "$DEST_PRIV" && ! -f "$DEST_PUB" ]]; then
    install -m 0600 -o "$USERNAME" -g "$UGRP" "$CANON_PRIV" "$DEST_PRIV"
    install -m 0644 -o "$USERNAME" -g "$UGRP" "$CANON_PUB" "$DEST_PUB"
    log "Installed key for $USERNAME at $DEST_PRIV"
  else
    log "Key already present for $USERNAME, not overwriting: $DEST_PRIV"
  fi

  # Create config only if missing (do not touch perms/owner if it exists)
  if [[ ! -f "$CONFIG_FILE" ]]; then
    install -m 0600 -o "$USERNAME" -g "$UGRP" /dev/null "$CONFIG_FILE"
  fi

  # Append Host block only if header is not already present
  # modify below if you want to specify a static username for the IdentityFile
  # (optional)  Specify the server/endpoints hostname as the User to identify the
  #             location that the breadcrumb was found from
  if ! grep -qF "Host ${CANARY_HOST_ALIAS}" "$CONFIG_FILE" 2>/dev/null; then
    cat >>"$CONFIG_FILE" <<EOF
Host ${CANARY_HOST_ALIAS}
  HostName ${CANARY_HOST}
  Port ${CANARY_SSH_PORT}
  User ${USERNAME}
  IdentityFile ${DEST_PRIV}
EOF
    # ensure perms if we just created/modified
    chown "$USERNAME:$UGRP" "$CONFIG_FILE"
    chmod 0600 "$CONFIG_FILE"
    log "Configured SSH alias '${CANARY_HOST_ALIAS}' for user ${USERNAME}"
  else
    log "SSH alias '${CANARY_HOST_ALIAS}' already present for user ${USERNAME}"
  fi

done <<< "$USERS"

log "All done!"
