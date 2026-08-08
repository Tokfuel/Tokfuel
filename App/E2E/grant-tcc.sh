#!/usr/bin/env bash
# Grant Accessibility (TCC) to the given client binaries on GitHub-hosted macOS runners.
# Do not run this on a locked-down personal Mac; use System Settings instead.
set -euo pipefail

if [[ "$#" -lt 1 ]]; then
  echo "usage: $0 <absolute-binary-path> [more paths...]" >&2
  exit 2
fi

DB="/Library/Application Support/com.apple.TCC/TCC.db"
NOW="$(date +%s)"

for CLIENT in "$@"; do
  CLIENT="$(cd "$(dirname "$CLIENT")" && pwd)/$(basename "$CLIENT")"
  if [[ ! -x "$CLIENT" ]]; then
    echo "not an executable: $CLIENT" >&2
    exit 1
  fi
  echo "granting kTCCServiceAccessibility to $CLIENT"
  sudo sqlite3 "$DB" \
    "INSERT OR REPLACE INTO access(service,client,client_type,auth_value,auth_reason,auth_version,csreq,policy_id,indirect_object_identifier_type,indirect_object_identifier,indirect_object_code_identity,flags,last_modified) VALUES('kTCCServiceAccessibility','${CLIENT}',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,${NOW});" \
    || sudo sqlite3 "$DB" \
    "INSERT OR REPLACE INTO access(service,client,client_type,auth_value,auth_reason,auth_version,flags,last_modified) VALUES('kTCCServiceAccessibility','${CLIENT}',1,2,4,1,0,${NOW});"
done

sudo launchctl kickstart -k system/com.apple.tccd 2>/dev/null \
  || sudo killall tccd 2>/dev/null \
  || true
sleep 1
