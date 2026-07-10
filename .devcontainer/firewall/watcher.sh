#!/usr/bin/env bash
set -uo pipefail
TTL=/policy/ttl.tsv
OUT=/policy/allowlist.acl
PLACEHOLDER="invalid.invalid"

ALLOWALL_UNTIL=/policy/allow_all.until
ALLOWALL_ACL=/policy/allow_all.acl
ALLOWALL_EVENTS=/policy/allow_all_events.log

while true; do
  now=$(date +%s)
  reconfigure=0

  # Prune expired TTL entries before recompiling.
  if [ -s "$TTL" ]; then
    awk -v now="$now" -F'\t' '($1+0)>now' "$TTL" > "$TTL.new" 2>/dev/null || true
    mv -f "$TTL.new" "$TTL" 2>/dev/null || true
  fi

  # Recompile: placeholder + baseline + enabled features (dep-closed) + manual
  # permanent + live TTL, sorted/deduped. See build-acl.sh for the layering.
  {
    echo "$PLACEHOLDER"
    /usr/local/bin/build-acl.sh
  } 2>/dev/null | sort -u > "$OUT.next"

  if ! cmp -s "$OUT.next" "$OUT" 2>/dev/null; then
    mv -f "$OUT.next" "$OUT"
    reconfigure=1
  else
    rm -f "$OUT.next"
  fi

  # Temporary "allow all" override (see `fw allow-all`). /policy/allow_all.until
  # holds a single epoch expiry; while unexpired we write a match-everything
  # regex into the live dstdom_regex ACL file, otherwise we clear it (and drop
  # the marker once it has expired so `fw allow-all status` reports inactive).
  aa_active=0
  if [ -s "$ALLOWALL_UNTIL" ]; then
    until_ts="$(cat "$ALLOWALL_UNTIL" 2>/dev/null || echo 0)"
    if [[ "$until_ts" =~ ^[0-9]+$ ]] && [ "$until_ts" -gt "$now" ]; then
      aa_active=1
    else
      rm -f "$ALLOWALL_UNTIL"
      echo "$now $(date -Iseconds) off (expired)" >> "$ALLOWALL_EVENTS" 2>/dev/null || true
    fi
  fi
  if [ "$aa_active" = 1 ]; then
    echo '^.*$' > "$ALLOWALL_ACL.next"
  else
    : > "$ALLOWALL_ACL.next"
  fi
  if ! cmp -s "$ALLOWALL_ACL.next" "$ALLOWALL_ACL" 2>/dev/null; then
    mv -f "$ALLOWALL_ACL.next" "$ALLOWALL_ACL"
    reconfigure=1
  else
    rm -f "$ALLOWALL_ACL.next"
  fi

  if [ "$reconfigure" = 1 ]; then
    squid -k reconfigure 2>/dev/null || true
  fi
  sleep 5
done
