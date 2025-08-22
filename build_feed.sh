#!/usr/bin/env bash
set -euo pipefail

URL="${URL:-https://app.igel.com/api/applications}"
OUT_DIR="${OUT_DIR:-feed}"
SNAP_DIR="$OUT_DIR/snapshots"
TODAY="$(date -u +%F)"
UA='IGEL-Catalog-Watcher/1.0'

mkdir -p "$SNAP_DIR"

echo "[info] Fetching $URL"
curl -fsSL "$URL" -H 'Accept: application/json' -A "$UA" > "$SNAP_DIR/$TODAY.json"

# latest.json as copy of today's snapshot
cp "$SNAP_DIR/$TODAY.json" "$OUT_DIR/latest.json"

# latest.min.json (pruned view for quick scans)
jq '[ .[] | {name, version, publishedAt, displayName:(.displayName.en // .displayName // .name)} ]'   "$SNAP_DIR/$TODAY.json" > "$OUT_DIR/$TODAY.min.json"

PREV_MIN="$OUT_DIR/latest.min.json"
if [[ -f "$PREV_MIN" ]]; then
  echo "[info] Computing diff vs previous min"
  PREV="$PREV_MIN"
  CURR="$OUT_DIR/$TODAY.min.json"

  TOTAL=$(jq 'length' "$OUT_DIR/latest.json")
  SUMMARY="$OUT_DIR/summary_latest.txt"
  {
    echo "IGEL App Portal daily check • $TODAY"
    echo "Total apps: $TOTAL"

    # Added
    ADDED_NAMES=$(jq -s ' (.[1]//[]) as $c | (.[0]//[]) as $p | 
      ( ($c|map(.name)|unique) - ($p|map(.name)|unique) ) ' "$PREV" "$CURR")
    if [[ $(echo "$ADDED_NAMES" | jq 'length') -gt 0 ]]; then
      echo
      echo "New apps:"
      jq -r --argjson names "$ADDED_NAMES" '
        map(select($names|index(.name)!=null)) 
        | sort_by(.displayName // .name) 
        | .[] | "  + \(.displayName // .name)  v\(.version // "n/a")  (\(.name))"
      ' "$CURR"
    fi

    # Removed
    REMOVED_NAMES=$(jq -s ' (.[1]//[]) as $c | (.[0]//[]) as $p | 
      ( ($p|map(.name)|unique) - ($c|map(.name)|unique) ) ' "$PREV" "$CURR")
    if [[ $(echo "$REMOVED_NAMES" | jq 'length') -gt 0 ]]; then
      echo
      echo "Removed apps:"
      jq -r --argjson names "$REMOVED_NAMES" '
        map(select($names|index(.name)!=null)) 
        | sort_by(.displayName // .name) 
        | .[] | "  - \(.displayName // .name)  v\(.version // "n/a")  (\(.name))"
      ' "$PREV"
    fi

    # Version changes
    echo
    CHANGED=$(jq -s '
      (.[0]//[]) as $p | (.[1]//[]) as $c |
      # join by name
      [ foreach $c[] as $curr ({}; .;
          .[$curr.name] = $curr
        ) ] as $tmp |
      ( $p | map( select( .name as $n | any($c[]; .name==$n) and .version != ($tmp[0][$n].version) ) ) ) as $pc |
      $pc
    ' "$PREV" "$CURR")
    if [[ $(echo "$CHANGED" | jq 'length') -gt 0 ]]; then
      echo "Version changes:"
      # For each changed, print old -> new with ISO timestamp
      jq -r -s '
        (.[0]//[]) as $p | (.[1]//[]) as $c |
        def iso(t): (if (t|type)=="number" then (t|todate) else (t|tostring) end);
        # build index for current
        (reduce $c[] as $x ({}; .[$x.name]=$x)) as $idx |
        $p
        | map( select( .name as $n | ($idx[$n]|.version) != .version ) )
        | sort_by(.displayName // .name)
        | .[]
        | . as $old
        | $idx[$old.name] as $new
        | "  ~ \((($new.displayName // $new.name)))  \($old.version) → \($new.version)  (published: \((iso($new.publishedAt))))"
      ' "$PREV" "$CURR"
    else
      echo "No version changes."
    fi
  } > "$SUMMARY"
  echo "[info] Wrote $SUMMARY"
else
  echo "[info] First run; establishing baseline"
fi

# Rotate latest pointers
cp "$OUT_DIR/$TODAY.min.json" "$OUT_DIR/latest.min.json"

echo "[ok] Snapshot: $SNAP_DIR/$TODAY.json"
echo "[ok] Latest:   $OUT_DIR/latest.json"
echo "[ok] Min:      $OUT_DIR/latest.min.json"
