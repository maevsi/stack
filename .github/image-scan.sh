#!/usr/bin/env bash
# Scans every image the production stack deploys for HIGH and CRITICAL vulnerabilities that have a fix upstream.
# Writes a Markdown table of the affected images to the given path, which stays empty when there are none,
# followed by a comment listing all vulnerability IDs, which the workflow compares between runs.
set -euo pipefail

REPORT="${1:?usage: image-scan.sh <report path>}"
TRIVY_IMAGE="aquasec/trivy:${TRIVY_VERSION:?TRIVY_VERSION not set}"
CACHE="$(mktemp -d)"
ERROR="$(mktemp)"
trap 'rm -rf "$CACHE" "$ERROR"' EXIT
chmod 777 "$CACHE" # the Trivy image runs as a non-root user

# Mirrors dargstack's merge for the image key: production overrides development, and a pruned service is not deployed.
images() {
  local environment file
  for environment in development production; do
    for file in "src/$environment/compose.yaml" src/"$environment"/*/compose.yaml; do
      [ -f "$file" ] || continue
      yq --output-format json '.services // {}' "$file" | jq -r '
        to_entries[]
        | if .value == "(( prune ))" then "\(.key) -"
          elif (.value | type) == "object" and .value.image then "\(.key) \(.value.image)"
          else empty end'
    done
  done | awk '{ image[$1] = $2 } END { for (service in image) if (image[service] != "-") print image[service] }' | grep -v ':development$' | sort -u
}

rows=""
ids=""
while read -r image; do
  echo "Scanning $image"
  if ! result="$(docker run --rm --volume "$CACHE:/cache" --env TRIVY_PASSWORD --env TRIVY_USERNAME "$TRIVY_IMAGE" image \
    --cache-dir /cache --format json --ignore-unfixed --quiet --severity HIGH,CRITICAL "$image" 2>"$ERROR")"; then
    rows+="| \`$image\` | scan failed | $(grep -v '^[[:space:]]*$' "$ERROR" | tail -n 1 | cut -c 1-200 | tr '|' '/') |"$'\n'
    continue
  fi
  row="$(jq -r --arg image "$image" '
    [.Results[]?.Vulnerabilities[]?] as $found
    | select($found | length > 0)
    | ([$found[] | "\(.PkgName) \(.FixedVersion)"] | unique) as $updates
    | "| `\($image)` | \([$found[].VulnerabilityID] | unique | length) | \($updates[:10] | join(", "))\(if ($updates | length) > 10 then ", …" else "" end) |"
  ' <<<"$result")"
  if [ -n "$row" ]; then
    rows+="$row"$'\n'
    ids+="$(jq -r '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | join(" ")' <<<"$result") "
  fi
done < <(images)

if [ -z "$rows" ]; then
  : > "$REPORT"
  echo "No fixable HIGH or CRITICAL vulnerabilities found."
  exit 0
fi

cat > "$REPORT" <<EOF
The production stack deploys images with HIGH or CRITICAL vulnerabilities that already have a fix upstream, so a newer image or a rebuild of it can remove them.
The daily image scan keeps this table current, comments when new vulnerabilities appear, and closes the issue once nothing is left.

| Image | Vulnerabilities | Fixed in |
| --- | --- | --- |
${rows}
<!-- vulnerabilities: $(tr ' ' '\n' <<<"$ids" | sort -u | xargs) -->
EOF
cat "$REPORT"
