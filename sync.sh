#!/usr/bin/env bash
#
# sync.sh — Session briefing for zallet (zcash/wallet) maintenance.
#
# Fetches live GitHub data for zcash/wallet and prints a prioritized, maintainer-
# assist dashboard to stdout: your PRs needing action, the inbox of cross-hub
# handoffs, the review queue, cross-repo interop, CI-failing PRs, issue counts.
#
# Usage: bash sync.sh [--no-fetch]
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

REPO="zcash/wallet"
WALLET_PATH="$PARENT_DIR/wallet"
PR_URL="https://github.com/$REPO/pull"
ISSUE_URL="https://github.com/$REPO/issues"

# Your login — PRs authored by this user are surfaced in the "your PRs" section.
ME="${GH_ME:-oxarbitrage}"

NO_FETCH=false
for arg in "$@"; do
  case $arg in
    --no-fetch) NO_FETCH=true ;;
  esac
done

for tool in gh jq git; do
  command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: '$tool' not found." >&2; exit 1; }
done

hr() { printf '%s\n' "------------------------------------------------------------------------"; }

# Pull latest hub state, if this hub is itself a git repo
(cd "$SCRIPT_DIR" && git rev-parse --git-dir >/dev/null 2>&1 && git pull --rebase --quiet 2>/dev/null) || true

# Fetch the wallet checkout (used when you work a PR branch locally)
if [ -d "$WALLET_PATH/.git" ] && [ "$NO_FETCH" = false ]; then
  echo "Fetching $REPO ..." >&2
  (cd "$WALLET_PATH" && git fetch --all --quiet 2>/dev/null) || true
fi

echo ""
echo "========================================================================"
echo "  ZALLET HUB — $REPO"
echo "========================================================================"

# ----------------------------------------------------------------------------
# Pull open PRs once (CI rollup + review decision), reuse via jq
# ----------------------------------------------------------------------------
PRS_JSON="$(gh pr list -R "$REPO" --state open --limit 200 \
  --json number,title,author,isDraft,reviewDecision,mergeable,updatedAt,statusCheckRollup,labels \
  2>/dev/null || echo '[]')"

read -r -d '' CI_FN <<'JQ' || true
def ci:
  (.statusCheckRollup // []) as $c
  | if ($c | length) == 0 then "NONE"
    elif any($c[]; (.conclusion // .state) as $s | $s=="FAILURE" or $s=="TIMED_OUT" or $s=="CANCELLED" or $s=="ERROR" or $s=="ACTION_REQUIRED") then "FAIL"
    elif any($c[]; (.conclusion // .state) as $s | $s==null or $s=="" or $s=="PENDING" or $s=="IN_PROGRESS" or $s=="QUEUED") then "PENDING"
    else "PASS" end;
def isbot: (.author.login // "") | (test("dependabot"; "i"));
JQ

count() { echo "$PRS_JSON" | jq -r "$CI_FN $1 | length" 2>/dev/null || echo 0; }

TOTAL_OPEN=$(echo "$PRS_JSON" | jq -r 'length' 2>/dev/null || echo 0)
MINE=$(echo "$PRS_JSON" | jq -r --arg me "$ME" "$CI_FN"'[ .[] | select(.author.login==$me) ] | length' 2>/dev/null || echo 0)
FAILING=$(count '[ .[] | select((ci=="FAIL") and (isbot|not)) ]')
READY=$(count '[ .[] | select(ci=="PASS" and .reviewDecision=="APPROVED" and (.isDraft|not)) ]')
DEPS=$(count '[ .[] | select(isbot) ]')
ISSUES_OPEN=$(gh issue list -R "$REPO" --state open --limit 1000 --json number --jq 'length' 2>/dev/null || echo 0)

echo ""
echo "📊 SUMMARY"
hr
printf "  Open PRs: %s   (🤖 dependabot: %s)   👤 yours: %s\n" "$TOTAL_OPEN" "$DEPS" "$MINE"
printf "  ❌ CI failing (non-bot): %s    🚀 ready to merge: %s\n" "$FAILING" "$READY"
printf "  🐛 Open issues: %s\n" "$ISSUES_OPEN"

# ----------------------------------------------------------------------------
# 📥 INBOX — cross-hub handoffs tracked in wip.md (between "## 📥 INBOX" and next "---")
# ----------------------------------------------------------------------------
echo ""
echo "📥 INBOX  (work handed off from sibling hubs — see wip.md)"
hr
if [ -f "$SCRIPT_DIR/wip.md" ] && grep -q '^## 📥 INBOX' "$SCRIPT_DIR/wip.md"; then
  awk '/^## 📥 INBOX/{f=1} f{print} f&&/^---[[:space:]]*$/{exit}' "$SCRIPT_DIR/wip.md" \
    | grep -vE '^## 📥 INBOX|^---' | sed 's/^/  /' | sed '/^[[:space:]]*$/d'
else
  echo "  (none — durable handoffs become zcash/wallet issues; pre-issue ones go in wip.md)"
fi

# ----------------------------------------------------------------------------
# 👀 Your PRs needing action (approved+green=ready, conflicts, changes requested)
# ----------------------------------------------------------------------------
echo ""
echo "👀 YOUR PRs NEEDING ACTION  (author: $ME)"
hr
echo "$PRS_JSON" | jq -r --arg me "$ME" "$CI_FN"'
  [ .[] | select(.author.login==$me) ]
  | if length==0 then "  (none open)"
    else (.[] | "  #\(.number) [\(.reviewDecision // "—") | CI \(ci) | \(.mergeable // "?")] \(.title)\n  '"$PR_URL"'/\(.number)")
    end' 2>/dev/null

# ----------------------------------------------------------------------------
# 🔗 Cross-repo interop: zallet PRs carrying a ZIT-Revision line
# ----------------------------------------------------------------------------
echo ""
echo "🔗 CROSS-REPO INTEROP  (zallet PRs testing against an integration-tests ref)"
hr
ZIT="$(gh pr list -R "$REPO" --state open --search 'ZIT-Revision in:body' \
      --json number,title,url,body 2>/dev/null || echo '[]')"
if [ "$(echo "$ZIT" | jq -r 'length' 2>/dev/null || echo 0)" != "0" ]; then
  echo "$ZIT" | jq -r '.[] | "  [" + .title + "]\n  ref: " +
    ((.body | capture("ZIT-Revision:[ ]*(?<r>[^\\r\\n]+)").r) // "?") + "\n  " + .url' 2>/dev/null
else
  echo "  (none — no open zallet PR carries a ZIT-Revision line)"
fi

# ----------------------------------------------------------------------------
# 🚀 Ready to merge (approved + green CI, not yours-only)
# ----------------------------------------------------------------------------
echo ""
echo "🚀 READY TO MERGE  (approved + green CI)"
hr
echo "$PRS_JSON" | jq -r "$CI_FN"'
  [ .[] | select(ci=="PASS" and .reviewDecision=="APPROVED" and (.isDraft|not)) ]
  | if length==0 then "  (none)"
    else (.[] | "  #\(.number) \(.author.login): \(.title)\n  '"$PR_URL"'/\(.number)")
    end' 2>/dev/null

# ----------------------------------------------------------------------------
# ❌ CI failing (non-bot)
# ----------------------------------------------------------------------------
echo ""
echo "❌ CI FAILING  (non-dependabot)"
hr
echo "$PRS_JSON" | jq -r "$CI_FN"'
  [ .[] | select(ci=="FAIL" and (isbot|not)) ]
  | if length==0 then "  (none)"
    else (.[] | "  #\(.number) \(.author.login): \(.title)\n  '"$PR_URL"'/\(.number)")
    end' 2>/dev/null

# ----------------------------------------------------------------------------
# Collapsed one-liners
# ----------------------------------------------------------------------------
echo ""
echo "… say 'show review queue' for incoming PRs awaiting review, 'show deps' for the $DEPS"
echo "  dependabot PRs, or 'show issues' for recent untriaged issues ($ISSUES_OPEN open)."
echo ""
echo "📋 wip.md (newest entries):"
hr
if [ -f "$SCRIPT_DIR/wip.md" ]; then
  head -n 12 "$SCRIPT_DIR/wip.md" | sed 's/^/  /'
else
  echo "  (no wip.md yet)"
fi
echo ""
echo "========================================================================"
