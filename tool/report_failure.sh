#!/usr/bin/env bash
# Post the tail of the captured build log as a commit comment.
# The Actions log itself lives on storage this project's tooling cannot read,
# so a red build would otherwise give no clue what broke.
set -uo pipefail
JOB="${1:-build}"
LOG=/tmp/ci.log
[ -f "$LOG" ] || echo "(no log captured)" > "$LOG"

# Keep the end of the log: compiler errors come last.
TAIL=$(tail -c 55000 "$LOG")
python3 - "$JOB" "$TAIL" <<'PY' > /tmp/comment.json
import json, sys
job, tail = sys.argv[1], sys.argv[2]
body = f"### ❌ {job} failed\n\n```\n{tail}\n```"
print(json.dumps({"body": body}))
PY
gh api --method POST \
  "repos/${GITHUB_REPOSITORY}/commits/${GITHUB_SHA}/comments" \
  --input /tmp/comment.json > /dev/null && echo "posted failure log as a commit comment"
