# Work In Progress — zallet-hub

Cross-session state for `zcash/wallet` (zallet) maintenance. Newest entries on top. Convert relative
dates to absolute. Supersede stale entries explicitly rather than deleting them silently.

The **## 📥 INBOX** section (kept directly below, ending at the next `---`) is parsed by `sync.sh`
and shown at the top of the dashboard. Put cross-hub handoffs there until they become a durable
`zcash/wallet` issue/PR, then move them down into a normal dated entry.

## 📥 INBOX

_(empty — the "Missing Orchard tree state" handoff shipped as zcash/wallet #454 + PR #455 on
2026-06-04; see the dated entry below.)_

---

## 🔧 2026-06-04 — #367 (str4d's `getwalletstatus`): review threads addressed + rebased + pushed

PR https://github.com/zcash/wallet/pull/367 — str4d's, **DRAFT**, cross-repo interop
(`ZIT-Revision: 5f84b1fa…` → integration-tests #56). User (oxarbitrage, a maintainer) is driving it
toward merge.

Reviewed all 4 pending review threads vs the code; user decisions (via AskUserQuestion): **named
`Progress` struct** (not raw tuple) for the progress fraction; **keep** the progress fields but **mark
approximate** (→ #237). Implemented + pushed:
- Added commit `8bf1db9` (author: oxarbitrage, co-author Claude) **on top of** str4d's commit (NOT
  squashed into it — separate-commit choice). Then **rebased both onto current `main`** (`4cb71b6`,
  branch was ~2 months behind) and **force-pushed** `ed76270…8bf1db9`.
- Changes: `Progress{numerator,denominator}` struct replacing the two flat fields; field docs (progress
  marked approximate w/ #237 ref; documented `unscanned_blocks`); added missing CHANGELOG entry for
  `getwalletstatus`. fmt + clippy `--all-features --all-targets` clean against current main (str4d's
  2-mo-old code still compiles).
- Threads 1 (name) & 2 (`fully_synced_height: Option`) need NO code change (settled by discussion /
  already documented). Threads NOT resolved in GitHub UI (left for str4d/reviewer).
- Posted review-response comment: https://github.com/zcash/wallet/pull/367#issuecomment-4626568577

**Update 2026-06-04 (str4d away → proceeded as maintainer):** replied to thread 3 with the
keep+document rationale, **resolved all 4 review threads** (0 unresolved), and **marked the PR Ready
for Review** (`gh pr ready` — no longer a draft). PR state now: isDraft=false, MERGEABLE,
reviewDecision=REVIEW_REQUIRED, mergeState=BLOCKED (CI re-running).

**REMAINING to merge:**
1. **Needs a separate reviewer** + approval (oxarbitrage is now a co-author → can't be sole reviewer;
   str4d is away). Find another maintainer to review.
2. **Interop:** integration-tests **#56 still OPEN** (zit-hub domain) — must land + `ZIT-Revision`
   resolved before/with merge. User: "we will tackle that soon." See memory `it56-interop-for-wallet367`.
3. CI: expect pre-existing `Test NU7` / `Latest build` reds (zebra-chain Nu7 / orchard `^0.13` dep
   issues) — not this PR.

---

## ✅ 2026-06-04 — #3 handoff SHIPPED: "Missing Orchard tree state" → issue #454 + PR #455

Was the INBOX item from **zit-hub** (integration-tests issue #3). Now durable on GitHub.
- **Issue:** https://github.com/zcash/wallet/issues/454  (labels: C-bug, A-sync)
- **PR:** https://github.com/zcash/wallet/pull/455  (`fix/empty-shielded-tree-state` → main, commit
  `3ab7bc7`, OPEN + MERGEABLE, body says `Closes #454`)

**Determination (verified by full stack trace this session — supersedes the original handoff notes):**
- **Genuine zallet bug** in `sync/steps.rs::fetch_chain_state`; fix is **proper & permanent, NOT a
  stopgap.** Trace: zallet → zaino `z_get_treestate` (pure pass-through of `final_state()`) → zebra-rpc
  `tree.map(|t| t.to_rpc_bytes())` → zebra-state `read::orchard_tree()` returns `None` when no tree is
  stored at that height. `None` ⟺ empty tree (an empty incremental-Merkle tree has no frontier); real
  fetch errors take a separate `?` path. So mapping `None → Frontier::empty()` is semantically exact.
- ⛔ **Corrected the original "could fix in zaino" hypothesis — it's WRONG.** Nothing for zaino to do
  (relay only); the `None` originates in zebra. zebra *could* optionally serialize an empty tree to
  mirror zcashd, but that's a separate non-blocking **zebra** question (→ zebra-hub if ever pursued),
  not zaino, and not required for this fix. No zaino issue filed.
- Fixed **both** Sapling + Orchard paths symmetrically. (The old
  `patches/zallet-3-empty-orchard-tree.patch` fixed Orchard only — now superseded by the branch; patch
  can be deleted.)
- fmt + clippy `--all-features --all-targets` clean; CHANGELOG (Fixed) entry; AI co-author trailer. No
  unit test (needs a live indexer); validated via zit-hub integration-tests (`wallet.py` 3/3,
  `wallet_orchard_init.py`).
- Expect the pre-existing `Latest build` / `Test NU7` red CI checks on #455 (`orchard ^0.13` /
  `zebra-chain` Nu7 dep issues) — same as #400, not from this change.
- Cross-links: integration-tests issue #3; zit companions — framework fail-fast (zit PR #102),
  `wallet.py` race fix (zit branch `fix/wallet-py-sync-race`), owned by zit-hub.

---

## 🔧 2026-06-04 — #400 IN PROGRESS: conflict resolved + review comments addressed (not yet pushed)

Working branch `z_importexportkey` in `../wallet`. **Rebased onto `origin/main`** (main was 58 commits
ahead). Conflict was in `zallet/src/components/keystore.rs`:
- main's migration work (PR #430 family) converted the age encrypt helpers into **gated `Encryptor`
  methods** (`encrypt_legacy_seed_bytes`/`encrypt_standalone_sapling_key`/`encrypt_standalone_transparent_privkey`,
  each `#[cfg(feature = …)]`); the branch had them as **unconditional free functions**.
- Resolution: dropped the 3 now-duplicated free fns; kept only the genuinely-new free fn
  `decrypt_standalone_sapling_extsk`; **ungated** `Encryptor::encrypt_standalone_sapling_key` (z_importkey
  is always built and calls it via the ungated `encrypt_and_store_standalone_sapling_key`).
- Builds clean: default, `--no-default-features`, and (pending) `--all-features` (CI uses `--all-features`).

nullcopy inline comments addressed:
- utils.rs `fetch_account_birthday`: treestate-fetch failure now `RpcErrorCode::InternalError` (was
  `InvalidParameter`), message preserved via `ErrorObjectOwned::owned`.
- import_key.rs: skip the `start_height > tip` check when `rescan="no"` (start_height unused there).
- import_key.rs: `tracing::warn!` when `rescan="no"` falls back to genesis (no chain tip known).
- import_key.rs: refined the existing-key-rescan TODO to name `WalletWrite::rewind_to_height` (deferred —
  it rewinds the *whole* wallet, not just this key).

OPEN QUESTIONS to raise with the user / in PR thread (NOT auto-resolved):
- nullcopy: "Should [genesis ChainState] include the real genesis hash?" (utils.rs:68) — left as
  `BlockHash([0;32])`; trees are empty at a genesis birthday so arguably moot. Defer to maintainer.
- nuttycom (earlier): skeptical of `z_exportkey` (fund-loss footgun — Orchard funds under same spend
  authority). PR approved by nullcopy regardless. User offered to drop export or keep w/ docs. **Decision
  needed before merge.**

STATUS 2026-06-04 (later): all green — build (default / `--no-default-features` / `--all-features`),
`clippy --all-features --all-targets`, `cargo test --all-features` (12/12 import/export). Review fixups
**amended into the single commit** (local `8126ae3`, message preserved — it already credits Claude). Also
added per user: z_exportkey fund-loss **warning in RPC help text** (methods.rs); inline comment in
utils.rs documenting why the genesis ChainState uses `BlockHash([0;32])` (no block before genesis →
zero parent hash is correct; left unchanged).

✅ **PUSHED 2026-06-04** — `git push --force-with-lease origin z_importexportkey` succeeded
(`532371e...1804337`, forced update). Final commit `1804337` conforms to CONTRIBUTING.md + AGENTS.md:
CHANGELOG.md updated (z_exportkey/z_importkey under `[0.1.0-alpha.4]` Added), dual AI `Co-Authored-By`
(Opus 4.6 original + Opus 4.8 1M-context for rebase/fixups), `cargo fmt` clean, clippy `--all-features
--all-targets` clean, single semantic commit (no WIP).

Post-push PR state: **mergeable=MERGEABLE** (conflict gone), **reviewDecision=APPROVED**,
mergeState=BLOCKED (CI re-running on new head). PR body already references `Close #69` and `Close #79`
(MUST-reference-issue convention satisfied — no body edit needed).

⚠️ CI watch: 3 **"Latest build on {ubuntu,macOS,windows}-latest"** jobs failed fast (~17s) — likely
pre-existing/infra (matches the pre-session "#400 CI FAIL"), NOT the code (compiles + clippy clean
locally). Confirm via job logs once the run finishes. Rustfmt/Shellcheck/zizmor/Hadolint already pass;
Clippy (MSRV/beta), Test default/NU7/merchant_terminal, Intra-doc links still pending.

✅ Posted **6 inline replies** to nullcopy's review threads (one per comment; threads left UNRESOLVED per
user). Reply IDs 3355952339/475/575/686/822/958. No nuttycom standalone reply (his concern answered via
the z_exportkey help-text warning, referenced in reply ⑥/PR). No separate summary comment posted.

✅ CI determination (2026-06-04): the two PR #400 CI failures are **PRE-EXISTING / dependency-level, NOT
this PR's code**:
  - "Test NU7 on Linux/Windows": `error[E0004]` — `zebra-chain` lib doesn't cover
    `NetworkUpgrade::Nu7` (dependency compile error under the NU7 feature). Affects the whole workspace.
  - "Latest build on {ubuntu,macOS,windows}": `failed to select a version for orchard = "^0.13"`
    (dependency resolution in the build-against-latest job).
  Both fail on any branch right now. PR #400's own code: Rustfmt ✅; clippy `--all-features` + tests 12/12
  green locally; default-features test + MSRV clippy were still pending at hand-off. → these failures are
  NOT a regression from the import/export work; do not "fix zallet" to satisfy them. If a green required
  set is needed for merge, the NU7/orchard dep issues are a separate workspace concern (candidate handoff).

---

## 🟢 2026-06-04 — #400 transferred in: address review + resolve conflicts

**PR #400 — Implement `z_importkey` and `z_exportkey` for Sapling** (yours; +609/-10, branch
`z_importexportkey`, base `main`).
https://github.com/zcash/wallet/pull/400

State: **OPEN, APPROVED** by nullcopy (2026-05-04, `utACK 532371eb`): *"Looks good to me! I left a
few minor comments, but nothing blocking (modulo merge conflicts)."*

REMAINING WORK to merge:
1. Address nullcopy's **minor inline comments** (non-blocking). Pull them with:
   `gh pr view 400 --repo zcash/wallet --json reviews,comments`
   and the inline review comments via the PR's review threads.
2. **Resolve merge conflicts** against `main` (the PR last updated 2026-05-04; main has moved).
3. Rebuild/test locally in `../wallet` on branch `z_importexportkey` before pushing
   (`cargo build` / relevant `cargo test`; confirm the PR's required CI checks).
4. Push fixups; re-request review only if changes are substantive (it's already approved).

Cross-link: this is the **zallet side of integration-tests #76** (oxarbitrage: "Add `z_importkey` and
`z_exportkey` test"). Once #400 merges, the test in #76 can validate against it.

---

## 🧭 2026-06-04 — zallet-hub created

Created this hub to steward `zcash/wallet` PRs/issues and receive cross-repo handoffs, separating
**wallet development** from the **integration-tests** maintenance done in zit-hub. Patterned on
zit-hub (lean orchestrator + sub-agents + `wip.md`/`RESUME.md` + `sync.sh`), minus the framework-
binary build section (that's integration-tests' job). Sibling hubs registered in `CLAUDE.md`;
cross-hub handoffs flow through GitHub (issues/PRs/`ZIT-Revision`), with a local **📥 INBOX** for
pre-issue items. First two inbox/transferred items: **#3** (Orchard tree-state fix, ready to PR) and
**#400** (review + conflict resolution).
