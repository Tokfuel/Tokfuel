#!/usr/bin/env bash
# Grant Accessibility / Screen Recording (TCC) on GitHub-hosted macOS runners.
# Writes both system and user TCC.db, and handles macOS 15+ extra columns.
# Do not run this on a locked-down personal Mac; use System Settings instead.
set -euo pipefail

if [[ "$#" -lt 1 ]]; then
  echo "usage: $0 <absolute-binary-path> [more paths...]" >&2
  exit 2
fi

NOW="$(date +%s)"
SERVICES=(kTCCServiceAccessibility kTCCServiceScreenCapture)
DBS=(
  "/Library/Application Support/com.apple.TCC/TCC.db"
  "${HOME}/Library/Application Support/com.apple.TCC/TCC.db"
)

# runner / shell 経路も必ず Screen Recording 対象に含める。
EXTRA_CLIENTS=(
  /bin/bash
  /bin/zsh
  /bin/sh
  /usr/bin/osascript
  /usr/sbin/screencapture
  /usr/local/opt/runner/provisioner/provisioner
  /opt/off/opt/runner/provisioner/provisioner
)

clients=()
for CLIENT in "$@" "${EXTRA_CLIENTS[@]}"; do
  [[ -e "$CLIENT" ]] || continue
  if [[ -x "$CLIENT" ]]; then
    CLIENT="$(cd "$(dirname "$CLIENT")" && pwd)/$(basename "$CLIENT")"
  fi
  clients+=("$CLIENT")
done

# 重複除去
uniq_clients=()
for c in "${clients[@]}"; do
  skip=0
  for u in "${uniq_clients[@]:-}"; do
    [[ "$u" == "$c" ]] && skip=1 && break
  done
  [[ "$skip" -eq 1 ]] || uniq_clients+=("$c")
done

grant_one() {
  local db="$1"
  local service="$2"
  local client="$3"
  local cols
  cols="$(sudo sqlite3 "$db" "PRAGMA table_info(access);" 2>/dev/null | awk -F'|' '{print $2}' | tr '\n' ' ')" || return 0

  echo "granting ${service} → ${client} (${db})"

  # 列構成が世代で違うので、分かる範囲で INSERT を試す。
  if [[ "$cols" == *"boot_uuid"* ]]; then
    # macOS 14+ / 15: pid, pid_version, boot_uuid, last_reminded あり
    sudo sqlite3 "$db" \
      "INSERT OR REPLACE INTO access(service,client,client_type,auth_value,auth_reason,auth_version,csreq,policy_id,indirect_object_identifier_type,indirect_object_identifier,indirect_object_code_identity,flags,last_modified,pid,pid_version,boot_uuid,last_reminded) VALUES('${service}','${client}',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,${NOW},NULL,NULL,'UNUSED',${NOW});" \
      2>/dev/null || true
  fi

  sudo sqlite3 "$db" \
    "INSERT OR REPLACE INTO access(service,client,client_type,auth_value,auth_reason,auth_version,csreq,policy_id,indirect_object_identifier_type,indirect_object_identifier,indirect_object_code_identity,flags,last_modified) VALUES('${service}','${client}',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,${NOW});" \
    2>/dev/null \
    || sudo sqlite3 "$db" \
    "INSERT OR REPLACE INTO access(service,client,client_type,auth_value,auth_reason,auth_version,flags,last_modified) VALUES('${service}','${client}',1,2,4,1,0,${NOW});" \
    2>/dev/null \
    || true
}

for DB in "${DBS[@]}"; do
  [[ -f "$DB" ]] || continue
  for CLIENT in "${uniq_clients[@]}"; do
    for SERVICE in "${SERVICES[@]}"; do
      grant_one "$DB" "$SERVICE" "$CLIENT"
    done
  done
done

# replayd の ScreenCaptureApprovals（パス単位の許可キャッシュ）
APPROVALS="${HOME}/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist"
mkdir -p "$(dirname "$APPROVALS")" 2>/dev/null || true
for CLIENT in "${uniq_clients[@]}"; do
  defaults write "$APPROVALS" "$CLIENT" -date "3024-01-01 00:00:00 +0000" 2>/dev/null || true
done

sudo launchctl kickstart -k system/com.apple.tccd 2>/dev/null \
  || sudo killall tccd 2>/dev/null \
  || true
sleep 1

echo "TCC grant done for ${#uniq_clients[@]} clients"
