#!/usr/bin/env bash
# Download a GitHub candidate's original (non-fork) repositories for code review.
#
# Usage: clone_candidate.sh <github-profile-url-or-username> [max_repos]
#
# Uses the authenticated `gh` CLI. Lists all public repos via the API,
# excludes forks, clones the <max_repos> most recently pushed originals
# (shallow) into ./candidates/<username>/ and prints a summary.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <github-profile-url-or-username> [max_repos]" >&2
  exit 1
fi

USER_INPUT="$1"
MAX_REPOS="${2:-5}"

USERNAME="${USER_INPUT#https://github.com/}"
USERNAME="${USERNAME%%/*}"
USERNAME="${USERNAME%%\?*}"

OUT_DIR="candidates/$USERNAME"
mkdir -p "$OUT_DIR"

REPOS_JSON="$(gh api "users/$USERNAME/repos?per_page=100" --paginate \
  | jq -s 'add | [.[] | select(.fork == false)]')"

TOTAL=$(gh api "users/$USERNAME/repos?per_page=100" --paginate | jq -s 'add | length')
FORKS=$((TOTAL - $(echo "$REPOS_JSON" | jq 'length')))

echo "Profile: $USERNAME — $TOTAL repos ($FORKS forks excluded)"
echo

echo "$REPOS_JSON" \
  | jq -r 'sort_by(.pushed_at) | reverse | .[:'"$MAX_REPOS"'] | .[] | [.name, .pushed_at, .language // "-", (.stargazers_count|tostring), (.description // "-")] | @tsv' \
  | while IFS=$'\t' read -r NAME PUSHED LANG STARS DESC; do
      if [[ -d "$OUT_DIR/$NAME/.git" ]]; then
        echo "SKIP (already cloned): $NAME"
      else
        echo "Cloning $NAME (pushed ${PUSHED:0:10}, $LANG, $STARS stars) — ${DESC}"
        gh repo clone "$USERNAME/$NAME" "$OUT_DIR/$NAME" -- --depth 50 --quiet
      fi
    done

echo
echo "Original repos cloned under: $OUT_DIR/"
ls -1 "$OUT_DIR" 2>/dev/null || true
