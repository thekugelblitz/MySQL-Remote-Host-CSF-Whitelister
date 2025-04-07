#!/bin/bash
set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# === CONFIG ===
TMP_DIR="/tmp/mysql_csf_ips"
ERROR_LOG="/var/log/mysql_csf_whitelist_errors.log"
SCRIPT_LOG="/var/log/mysql_csf_whitelist.log"
DEBUG_LOG="/var/log/mysql_csf_debug.log"
TAG="Auto-whitelist:mysql:$(date +%F)"
DRY_RUN=false

# === Log Cron Trigger Time ===
echo "Cron script triggered: $(date)" >> "$DEBUG_LOG"

mkdir -p "$TMP_DIR"
MYSQL_HOSTS="$TMP_DIR/mysql_hosts.txt"
CSF_ALLOW="$TMP_DIR/csf_allow.txt"
TO_ADD="$TMP_DIR/to_add.txt"

exec 2>>"$ERROR_LOG"

# === Handle --dry-run mode ===
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[$(date)] [DRY-RUN] Mode enabled" >> "$SCRIPT_LOG"
fi

echo "[$(date)] Starting MySQL CSF whitelist sync" >> "$SCRIPT_LOG"

# === Fetch current CSF allow list (IPs & hostnames) ===
csf -l | awk '/^Allow:/ {print $2}' | sort -u > "$CSF_ALLOW"

# === Get all distinct MySQL Host entries, excluding private/reserved ===
mysql -N -B -e "SELECT DISTINCT Host FROM mysql.user WHERE Host NOT IN ('localhost', '127.0.0.1', '::1', '') ORDER BY Host;" \
| grep -v -E '^(localhost|127\.|::1|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' \
| grep -v -e "$(hostname)" -e "$(hostname -f)" \
| sort -u > "$MYSQL_HOSTS"

# === Determine entries not yet in CSF ===
comm -23 "$MYSQL_HOSTS" "$CSF_ALLOW" > "$TO_ADD"

# === Process new entries ===
mapfile -t entries < "$TO_ADD"

if [[ ${#entries[@]} -eq 0 ]]; then
  echo "[$(date)] No new entries to whitelist." >> "$SCRIPT_LOG"
else
  for entry in "${entries[@]}"; do
    if [[ "$entry" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      valid=true
    elif getent hosts "$entry" >/dev/null 2>&1; then
      valid=true
    else
      valid=false
      echo "[$(date)] [WARNING] Skipped (unresolvable): $entry" >> "$ERROR_LOG"
    fi

    if [[ "$valid" == true ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        echo "[$(date)] [DRY-RUN] Would whitelist: $entry [$TAG]" >> "$SCRIPT_LOG"
      else
        if csf -a "$entry" "$TAG" 2>>"$ERROR_LOG"; then
          echo "[$(date)] [+] Whitelisted: $entry [$TAG]" >> "$SCRIPT_LOG"
        else
          echo "[$(date)] [ERROR] Failed to whitelist: $entry" >> "$ERROR_LOG"
        fi
      fi
    fi
  done
fi

# === Clean up ===
rm -rf "$TMP_DIR"
