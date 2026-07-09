# zallet-hub

A private Claude Code **maintainer-assist workspace** for stewarding the
[zcash/zallet](https://github.com/zcash/zallet) wallet — reviewing PRs, driving
my own PRs to merge, and triaging issues.

> Not the wallet source. The zallet code lives at `zcash/zallet` (checked out at
> `../wallet`).

## Quick start

1. Read `RESUME.md` — the prior session's "start here" (headline + first action).
2. Run `bash sync.sh` — pulls the live PR/issue dashboard from GitHub.
3. Work the top-priority item; record anything that should outlive the session
   in `wip.md`, and refresh `RESUME.md` when pausing mid-task.

## Files

- `CLAUDE.md` — the operating manual (scope, workflow, dashboard rules)
- `RESUME.md` — prior session's "start here"
- `wip.md` — cross-session state (newest on top)
- `sync.sh` — live PR/issue dashboard
- `patches/` — standalone patches not yet upstreamed

Part of a set of sibling hubs (integration-tests, zebra) that hand work to each
other through GitHub.
