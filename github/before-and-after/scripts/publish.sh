#!/usr/bin/env bash
# Put before/after media into a PR body's marked block and upload it with gh --attach.
# Usage: bash publish.sh <pr> --before <file> --after <file> [--label <text>] [--attribution <name>] ...
# Run from the directory the media paths are relative to (usually the worktree root).
# Requires node and gh 2.99+.
set -euo pipefail

pr=${1:?usage: publish.sh <pr> --before <file> --after <file> [...]}
shift
fmt="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/format.mjs"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Collect the media paths: '#' is gh's alt-text separator, and pairs should match in height.
befores=() afters=()
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case ${args[i]} in
    --before) befores+=("${args[i + 1]:-}") ;;
    --after) afters+=("${args[i + 1]:-}") ;;
    --before=* | --after=*) echo "error: write '--before <file>', not '--before=<file>'" >&2; exit 1 ;;
  esac
done
for f in ${befores[@]+"${befores[@]}"} ${afters[@]+"${afters[@]}"}; do
  case $f in *'#'*) echo "error: media path contains '#', which gh --attach reads as alt text: $f" >&2; exit 1 ;; esac
done
if [ ${#befores[@]} -gt 0 ] && [ ${#befores[@]} -eq ${#afters[@]} ]; then  # mismatched counts: format.mjs reports it
  for ((i = 0; i < ${#afters[@]}; i++)); do
    node -e '
      const fs = require("fs");
      const h = (f) => { const b = fs.readFileSync(f); return b.toString("ascii", 1, 4) === "PNG" ? b.readUInt32BE(20) : null; };
      const [a, b] = process.argv.slice(1).map(h);
      if (a && b && a !== b) console.error(`warning: ${process.argv[1]} is ${a}px tall, ${process.argv[2]} is ${b}px; GitHub will center the shorter one`);
    ' "${befores[i]}" "${afters[i]}" || true
  done
fi

gh pr view "$pr" --json body --jq .body > "$tmp/body.md"
# Asset URLs already in the body: a re-run whose edit silently didn't apply would still show these.
grep -o 'user-attachments/assets/[A-Za-z0-9-]*' "$tmp/body.md" | sort -u > "$tmp/old-assets" || true
node "$fmt" --body-file "$tmp/body.md" "$@" > "$tmp/next.md"

attach=()
while IFS= read -r file; do
  attach+=(--attach "$file")
done < <(node "$fmt" --attach-list "$@")

# On a partial upload failure gh still edits the PR, then exits non-zero; the check below decides.
gh pr edit "$pr" --body-file "$tmp/next.md" "${attach[@]}" >/dev/null || echo "warning: gh pr edit exited non-zero; checking what landed" >&2

# Some gh versions skip the edit silently (see github-gh-pitfalls), so check the block itself.
gh pr view "$pr" --json body --jq .body | sed -n '/before-and-after:start/,/before-and-after:end/p' > "$tmp/block.md"
grep -o 'user-attachments/assets/[A-Za-z0-9-]*' "$tmp/block.md" | sort -u > "$tmp/new-assets" || true
if [ ! -s "$tmp/new-assets" ] || [ -n "$(comm -12 "$tmp/old-assets" "$tmp/new-assets")" ]; then
  echo "error: the PR body doesn't show freshly uploaded media; the edit did not apply" >&2
  exit 1
fi
if grep -q '](\./' "$tmp/block.md"; then
  echo "error: some local media references remain (upload partly failed); re-run to retry" >&2
  exit 1
fi
gh pr view "$pr" --json url --jq .url
