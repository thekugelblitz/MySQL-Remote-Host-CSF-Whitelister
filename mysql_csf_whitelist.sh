#!/bin/bash
set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# === CONFIG ===
TMP_DIR="/tmp/mysql_csf_ips"
ERROR_LOG="/var/log/mysql_csf_whitelist_errors.log"
SCRIPT_LOG="/var/log/mysql_csf_whitelist.log"
DEBUG_LOG="/var/log/mysql_csf_debug.log"
TAG="Auto-whitelist:mysql"
DRY_RUN=false

echo "Cron script triggered: $(date)" >> "$DEBUG_LOG"
mkdir -p "$TMP_DIR"
MYSQL_HOSTS="$TMP_DIR/mysql_hosts.txt"
CSF_ALLOW="$TMP_DIR/csf_allow.txt"
TO_ADD="$TMP_DIR/to_add.txt"
CSF_TAGGED="$TMP_DIR/csf_tagged.txt"
TO_REMOVE="$TMP_DIR/to_remove.txt"

exec 2>>"$ERROR_LOG"

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[$(date)] [DRY-RUN] Mode enabled" >> "$SCRIPT_LOG"
fi

echo "[$(date)] Starting MySQL CSF whitelist sync" >> "$SCRIPT_LOG"

# === Current CSF allow list
csf -l | awk '/^Allow:/ {print $2}' | sort -u > "$CSF_ALLOW"

# === Fetch MySQL IPs/hosts
mysql -N -B -e "SELECT DISTINCT Host FROM mysql.user WHERE Host NOT IN ('localhost', '127.0.0.1', '::1', '') ORDER BY Host;" | grep -v -E '^(localhost|127\.|::1|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' | grep -v -e "$(hostname)" -e "$(hostname -f)" | sort -u > "$MYSQL_HOSTS"

# === Whitelist new IPs
comm -23 "$MYSQL_HOSTS" "$CSF_ALLOW" > "$TO_ADD"
mapfile -t entries < "$TO_ADD"

if [[ ${#entries[@]} -eq 0 ]]; then
  echo "[$(date)] No new entries to whitelist." >> "$SCRIPT_LOG"
else
  for entry in "${entries[@]}"; do
    if [[ "$entry" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || getent hosts "$entry" >/dev/null 2>&1; then
      if [[ "$DRY_RUN" == true ]]; then
        echo "[$(date)] [DRY-RUN] Would whitelist: $entry [$TAG]" >> "$SCRIPT_LOG"
      else
        if csf -a "$entry" "$TAG" 2>>"$ERROR_LOG"; then
          echo "[$(date)] [+] Whitelisted: $entry [$TAG]" >> "$SCRIPT_LOG"
        else
          echo "[$(date)] [ERROR] Failed to whitelist: $entry" >> "$ERROR_LOG"
        fi
      fi
    else
      echo "[$(date)] [WARNING] Skipped (unresolvable): $entry" >> "$ERROR_LOG"
    fi
  done
fi

# === Delisting logic using direct csf.allow tag scan
grep "$TAG" /etc/csf/csf.allow | awk '{print $1}' | sort -u > "$CSF_TAGGED"
comm -23 "$CSF_TAGGED" "$MYSQL_HOSTS" > "$TO_REMOVE"
mapfile -t old_entries < "$TO_REMOVE"

if [[ ${#old_entries[@]} -eq 0 ]]; then
  echo "[$(date)] No stale entries to remove." >> "$SCRIPT_LOG"
else
  for old in "${old_entries[@]}"; do
    if [[ "$DRY_RUN" == true ]]; then
      echo "[$(date)] [DRY-RUN] Would remove: $old [$TAG]" >> "$SCRIPT_LOG"
    else
      if csf -ar "$old" 2>>"$ERROR_LOG"; then
        echo "[$(date)] [-] Removed stale whitelist: $old [$TAG]" >> "$SCRIPT_LOG"
      else
        echo "[$(date)] [ERROR] Failed to remove: $old" >> "$ERROR_LOG"
      fi
    fi
  done
fi

rm -rf "$TMP_DIR"
