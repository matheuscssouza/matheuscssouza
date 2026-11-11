#!/bin/bash
# Rewrites the "Latest activity" block of README.md with the newest commits across my public repos.
# Usage: GH_TOKEN=... scripts/update-recent.sh   (gh CLI and jq required)
set -euo pipefail

USER_LOGIN="${GITHUB_REPOSITORY_OWNER:-matheuscssouza}"
README="$(cd "$(dirname "$0")/.." && pwd)/README.md"

items=$(
  gh repo list "$USER_LOGIN" --visibility public --source --json name --jq '.[].name' |
  grep -vx "$USER_LOGIN" |
  while read -r repo; do
    gh api "repos/$USER_LOGIN/$repo/commits?per_page=3" 2>/dev/null |
      jq -c --arg repo "$repo" '.[] | {repo: $repo, date: .commit.author.date, msg: (.commit.message | split("\n")[0])}' || true
  done | jq -s 'sort_by(.date) | reverse | .[:5]'
)

block=$(echo "$items" | jq -r '.[] | "- `\(.repo)` · \(.msg) · \(.date[:10])"')

python3 - "$README" "$block" <<'PY'
import re, sys
path, block = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
new = f"<!-- RECENT:START -->\n{block}\n<!-- RECENT:END -->"
text = re.sub(r"<!-- RECENT:START -->.*?<!-- RECENT:END -->", lambda _: new, text, flags=re.S)
open(path, "w", encoding="utf-8").write(text)
PY
