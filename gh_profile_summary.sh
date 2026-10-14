#!/usr/bin/env bash
# Fetch GitHub profile metadata and commit histories without cloning.
#
# Usage: gh_profile_summary.sh <github-profile-url-or-username> [top_repos]
#
# Uses the authenticated `gh` CLI. Prints: profile header, an original-repos
# table (forks excluded), and per-repo commit histories (date, author,
# first line of message) for the <top_repos> most recently pushed originals.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <github-profile-url-or-username> [top_repos]" >&2
  exit 1
fi

USER_INPUT="$1"
TOP_REPOS="${2:-3}"

USERNAME="${USER_INPUT#https://github.com/}"
USERNAME="${USERNAME%%/*}"
USERNAME="${USERNAME%%\?*}"

echo "=== PROFILE: $USERNAME ==="
gh api "users/$USERNAME" \
  --jq '"login: \(.login)\nname: \(.name // "-")\nbio: \(.bio // "-")\nlocation: \(.location // "-")\npublic_repos: \(.public_repos)\nfollowers: \(.followers)\ncreated: \(.created_at)\nblog: \(.blog // "-")"'

echo
echo "=== ORIGINAL REPOS (most recently pushed) ==="
REPOS_JSON="$(gh api "users/$USERNAME/repos?per_page=100" --paginate \
  | jq -s 'add | [.[] | select(.fork == false)]')"

COUNT=$(echo "$REPOS_JSON" | jq 'length')
if [[ "$COUNT" -eq 0 ]]; then
  echo "Error: no original repositories found for '$USERNAME'." >&2
  exit 1
fi
echo "$COUNT original repos found; showing 15 most recent:"
echo
echo "$REPOS_JSON" \
  | jq -r 'sort_by(.pushed_at) | reverse | .[:15] | .[] | [.name, .pushed_at, .language // "-", (.stargazers_count|tostring), (.description // "-")] | @tsv' \
  | awk -F'\t' 'BEGIN{printf "%-28s %-12s %-12s %-6s %s\n","NAME","PUSHED","LANG","STARS","DESC"} {printf "%-28s %-12s %-12s %-6s %s\n",$1,substr($2,1,10),$3,$4,substr($5,1,60)}'

echo
echo "=== COMMIT HISTORIES (top $TOP_REPOS originals) ==="
echo "$REPOS_JSON" \
  | jq -r 'sort_by(.pushed_at) | reverse | .[:'"$TOP_REPOS"'] | .[].name' \
  | while read -r NAME; do
      echo
      echo "--- $NAME ---"
      gh api "repos/$USERNAME/$NAME/commits?per_page=100" \
        --jq '.[] | "\(.commit.author.date | split("T")[0])  \(.author.login // .commit.author.name)  \(.commit.message | split("\n")[0])"' \
        || echo "(no commits or API error)"
    done
