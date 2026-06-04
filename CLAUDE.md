# Zallet Maintenance Hub — Claude Code

Maintainer-assist hub for **`zcash/wallet`** (the zallet wallet). Its job is to help steward the
repo's **pull requests and issues** — review incoming PRs, drive your own PRs to merge (address
review comments, resolve conflicts), triage issues — and to **receive cross-repo work handed off
from sibling hubs** (integration-tests, zebra) and turn it into zallet PRs/issues.

The `zcash/wallet` checkout this hub operates on lives at `../wallet`
(`/home/alfredo/zallet/wallet`).

## Scope — what this hub owns vs. consumes

- **Owns (work lands here):** zallet source changes, `zcash/wallet` PRs and issues. Anything that
  becomes a commit/PR to `zcash/wallet` is this hub's deliverable.
- **Consumes / hands off:** this hub does NOT steward integration-tests or zebra. If work here
  surfaces a bug in those repos, hand it off to the owning hub (see **Sibling hubs** below) — don't
  fix another repo from here.

## Sibling hubs (awareness + handoff)

This hub knows its siblings exist and where they are. It does **not** read their live working state
(no reaching into another hub's `wip.md`/tree). Cross-hub work travels through **GitHub** — issues,
PRs, and the `ZIT-Revision:` interop line — which is the durable bus that survives any hub being
offline.

| Hub | Path | Owns repo |
|---|---|---|
| **zit-hub** (integration-tests) | `/home/alfredo/integration-tests/hub/zit-hub` | `zcash/integration-tests` |
| **zebra-hub** | `/home/alfredo/zf-eng-team-agent/zebra-hub` | `zcash/zebra` |
| **zallet-hub** (this) | `/home/alfredo/zallet/zallet-hub` | `zcash/wallet` |

**Handoff protocol.** When a sibling hub root-causes a zallet bug, the durable artifact is a
`zcash/wallet` **issue or PR** (with the evidence + reproducer), not a shared file. This hub picks it
up from the repo on its next `sync.sh`. While a handoff is still pre-issue (e.g. a validated local
patch not yet PR'd), track it in this hub's `wip.md` under the **📥 INBOX** section so `sync.sh`
surfaces it. The first action on an inbox item is usually: open the upstream PR/issue, then drop the
local note once it's durable on GitHub.

## Session start

1. **Read `RESUME.md` first** (if present) — the prior session's "start here": headline, ready items,
   and a *Suggested first action*. It may be more current than `sync.sh` and often sets the priority.
2. Run `bash sync.sh`.
3. Present the dashboard (below), reconciling it with `RESUME.md`. Don't ask what to do first —
   brief, then offer the top-priority action. Full detail lives in `wip.md`.

## Dashboard presentation

Present `sync.sh` output in two parts.

**Always show in full:**
- The summary headline (open PRs / open issues / your-PRs-needing-action / CI-failing count)
- 📥 **INBOX** — work handed off from sibling hubs. Highest-signal; never collapse it.
- 👀 **Your PRs needing action** (changes-requested, or approved+green = ready to merge, or conflicts)
- 🔗 **Cross-repo interop** — any zallet PR carrying a `ZIT-Revision:` line (testing against an
  integration-tests ref)

**Summarize as one-line counts with an offer to expand:**
- Incoming PRs awaiting review (one line, expandable — say "show review queue")
- Dependabot PRs (say "show deps")
- Untriaged issues (142+ — far too many to list; show count, say "show issues" for recent)
- Recently merged / closed

## Formatting rules

- Use emoji in headers/status: ❌ CI failure, ✅ passing/approved/merged, 🔗 cross-repo, 📝 draft,
  👀 review request, 🚀 ready to merge, ⚠️ warning, 🐛 issue, 📌 untriaged, 🤖 dependabot, 📥 inbox.
- Every PR/issue reference MUST include a **bare URL on its own line** (e.g.
  `https://github.com/zcash/wallet/pull/400`). Do NOT use `[text](url)` markdown — not clickable in
  the terminal. Put the URL after the title.

## Workflow

### This session is the orchestrator

Run `sync.sh`, decide priorities, do quick actions (review, comment, label, push a fixup, merge when
you have the rights and a reviewer signed off), and track what's in flight in `wip.md`. Keep this
session lean.

### Driving your own PRs (the common maintenance task)

For a PR of yours with review feedback (e.g. an APPROVED PR with minor comments + merge conflicts):
1. Pull the review comments (`gh pr view <n> --repo zcash/wallet --json reviews,comments`).
2. Work the diff in the `../wallet` checkout on the PR's head branch.
3. Address each comment; resolve conflicts against `main`.
4. Build/test locally before pushing (zallet is a Rust workspace — `cargo build` / `cargo test` /
   `cargo clippy` as appropriate; check the PR's CI for the exact required checks).
5. Push fixups, re-request review if the changes are substantive.

### Sub-agents for bounded tasks

Spawn a sub-agent (Agent tool) for focused work that completes in minutes: deep review of a specific
PR's diff, investigating a CI failure, checking an incoming contribution against the repo's
conventions, or implementing a self-contained review comment. When working several PRs, spawn
sub-agents **in parallel** (all Agent calls in one message).

### Cross-repo failures

zallet drives interop CI in integration-tests via the `ZIT-Revision:` PR-body line. When a zallet
change breaks an interop run, first determine **which side changed** — a real zallet regression vs. a
test that needs updating in integration-tests. Don't paper over a real zallet bug; and don't "fix"
zallet to satisfy a stale test — hand the latter to **zit-hub**. Record the determination in `wip.md`.

## Tracking state

Record anything that should survive the session in `wip.md`: in-flight PR work, decisions + rationale,
inbox handoffs and their status, interop failures and which side they implicate. Convert relative
dates to absolute. Supersede stale entries explicitly rather than deleting them silently. When a
session pauses mid-task, refresh `RESUME.md` with the headline + suggested first action.
