#!/usr/bin/env bash
# Batch-stage candidates from a folder of resume PDFs.
#
# Usage: score_all.sh <resumes-folder> [clone_limit]
#
# For each PDF in the folder:
#   1. Extracts GitHub links (extract_pdf_links.py)
#   2. Picks the candidate's own profile URL: prefers a bare profile link
#      (github.com/<user>, one path segment); falls back to the first GitHub link
#   3. Clones their top [clone_limit] original repos (clone_candidate.sh)
#   4. Skips candidates already staged under candidates/<username>/
#
# After staging, an agent reads the code locally and produces scorecards.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <resumes-folder> [clone_limit]" >&2
  exit 1
fi

FOLDER="$1"
LIMIT="${2:-3}"

if [[ ! -d "$FOLDER" ]]; then
  echo "Error: folder not found: $FOLDER" >&2
  exit 1
fi

STAGED=0
SKIPPED=0
NO_LINK=0

for PDF in "$FOLDER"/*.pdf; do
  [[ -e "$PDF" ]] || { echo "No PDFs in $FOLDER"; exit 0; }
  NAME="$(basename "$PDF")"

  LINKS="$(python3 "$DIR/extract_pdf_links.py" "$PDF" 2>/dev/null \
    | sed -n '/=== LINKS ===/,/=== TEXT ===/p' \
    | grep -io 'https\?://github.com/[^ ]*' | sort -u || true)"

  if [[ -z "$LINKS" ]]; then
    echo "SKIP (no GitHub link): $NAME"
    NO_LINK=$((NO_LINK + 1))
    continue
  fi

  # Prefer a bare profile link: exactly one path segment, not a known non-profile host.
  PROFILE="$(echo "$LINKS" | grep -Eiv '/(topics|features|pricing|about|settings|orgs)' \
    | awk -F/ 'NF==4 {print; exit}')"
  [[ -z "$PROFILE" ]] && PROFILE="$(echo "$LINKS" | head -1)"

  USERNAME="${PROFILE#*github.com/}"
  USERNAME="${USERNAME%%/*}"
  USERNAME="${USERNAME%%.*}"   # strip trailing '.git' if any

  if [[ -d "$DIR/candidates/$USERNAME" ]] && [[ -n "$(ls -A "$DIR/candidates/$USERNAME" 2>/dev/null)" ]]; then
    echo "SKIP (already staged): $NAME -> $USERNAME"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo
  echo "=== $NAME -> github.com/$USERNAME ==="
  if "$DIR/clone_candidate.sh" "$USERNAME" "$LIMIT"; then
    STAGED=$((STAGED + 1))
  else
    echo "FAILED cloning for $USERNAME (resume: $NAME)"
  fi
done

echo
echo "=== Summary ==="
echo "Staged: $STAGED   Already staged: $SKIPPED   No GitHub link: $NO_LINK"
