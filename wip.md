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

## ✅ 2026-06-08 — #353 (`openrpsee`) rebased onto main + pushed

PR https://github.com/zcash/wallet/pull/353 — yours, `docs(openrpc): Use common crate`, was
`CONFLICTING/DIRTY` (16 behind main). Rebased `openrpsee` onto current main; new head `d0a1fb2`
(force-pushed `efe9e5b…d0a1fb2`), 0 behind. Build + `cargo fmt --check` + `cargo clippy -p zallet` green.

**Conflicts (dependency machinery):**
- `Cargo.lock` (2 hunks) — branch pinned **`orchard 0.13.1`**; main is now on `orchard` 0.14. Did NOT
  hand-merge — took main's lock wholesale (`git checkout origin/main -- Cargo.lock`) then `cargo build`
  to add `openrpsee` incrementally. Net lock diff vs main = **+1 line** (openrpsee added to zallet's dep
  list; main's lock already carried openrpsee's package entries). No `orchard 0.13` remains.
- `supply-chain/config.toml` — main added an `openssl-probe` 0.2.1 exemption at the same spot; kept it.
  The `openrpsee` exemption (line 1015) auto-merged fine.
- `Cargo.toml`/`zallet/Cargo.toml`/`methods.rs` auto-merged.

This is the **updated re-confirmation of the RESUME "Cargo.lock rebase trick"** — now that main runs
orchard 0.14 (not the yanked ^0.13), taking main's lock + `cargo build` resolves cleanly; no need for the
old `cargo metadata`-only dance.

**Still needs:** a reviewer (REVIEW_REQUIRED). str4d helped in March; no reviewer pinged this round.

---

## ✅ 2026-06-08 — #400 (`z_importkey`/`z_exportkey`) rebased onto main + API break fixed + pushed

PR https://github.com/zcash/wallet/pull/400 — yours, APPROVED (nullcopy), was `CONFLICTING/DIRTY`
(16 behind main). Rebased `z_importexportkey` onto current main; new head `368ec79` (force-pushed
`1804337…368ec79`), 0 behind. Build + `cargo fmt --check` + `cargo clippy -p zallet` all green.

**Conflicts (both "both sides added different things at same spot", not logic clashes):**
- `CHANGELOG.md` — main added `z_shieldcoinbase`, branch added `z_importkey`/`z_exportkey` to the same
  sorted list. Kept all, alphabetical.
- `utils.rs` — main added `collect_standalone_transparent_keys` (z_shieldcoinbase signing), branch added
  `fetch_account_birthday` (imported-key accounts). Two distinct fns at same insertion point → kept both.

**NOT purely mechanical — an API break surfaced from main's orchard-0.14/zebra-9.0 bump:**
`fetch_account_birthday` used `chain.fetcher.get_treestate(...)`, but `FetchServiceSubscriber.fetcher`
is now **private**. Adapted to the public `chain.z_get_treestate(...)` (the `ZcashIndexer` trait method)
+ its accessor API (`.hash()/.height()/.time()/.sapling()/.orchard()`), matching the live idiom already
in `methods/get_new_account.rs` / `recover_accounts.rs`. Added `ZcashIndexer` to the `zaino_state`
import in utils.rs. Kept the branch's richer error message. Amended into the single commit.

**Still needs:** a maintainer to merge (it's approved + now mergeable + CI should be green since the
workspace orchard-^0.13 blocker is cleared on main).

---

## 🔁 2026-06-08 — #455 RECLASSIFIED (zit-hub handoff): robustness fix, NOT a live-crash blocker

**Supersedes** the 2026-06-04 framing of #455 ("genuine zallet bug, permanent fix, nothing for zaino
to do"). New info from **zit-hub** + cross-checks against current `zcash/wallet` main this session.

PR https://github.com/zcash/wallet/pull/455 — yours, `fix/empty-shielded-tree-state`, OPEN, +21/−28,
touches `zallet/src/components/sync/steps.rs` `fetch_chain_state`. Closes #454.

**What zit-hub reported (new):** integration-tests **PR #104** aligns regtest **NU5 activation to
height 1** across both zebrad + zallet. With that alignment, `wallet.py`/the wallet suite sync to
completion on **stock zallet (no #455)** — #104's CI is fully green and **no longer reproduces
"Missing Orchard tree state."** So #455 is **no longer a blocker for IT CI**.

**Cross-checks run this session (against current main + the #455 branch):**
1. **Both pools covered.** ✓ #455 rewrites both `ok_or_else` sites — "Missing Sapling tree state"
   (main line 316) and "Missing Orchard tree state" (main line 332) — into symmetric `match` arms:
   `Some(t) if nu_active => read_frontier`, `_ => Frontier::empty()`. None ⟺ empty, both pools.
2. **Rebase is clean for the fix.** Branch is **16 commits behind main**, but main's *only* steps.rs
   change since fork is at line 262 (`txid: ctx.hash → ctx.txid`, the orchard-0.14 cascade), which
   does NOT overlap the `fetch_chain_state` hunk. Rebase risk is `Cargo.lock` + orchard-0.14 cascade,
   not the fix. (Side note: main bumped to **orchard 0.14 / zebra 9.0** on 2026-06-06, commit
   `9be3d6e` — likely clears the workspace "orchard ^0.13 yanked" CI blocker too; check on next rebase.)
3. **Reachability / Some(empty) vs None.** #104's green CI on stock zallet is **empirical proof that
   zebra returns `Some(empty)` — not `None` — at an activated-but-empty tree height.** The original
   crash was therefore a **NU5 activation-height MISALIGNMENT artifact** (zallet thought NU5 active at
   a height where zebra returned no orchard treestate), now fixed upstream by #104 — NOT a genuine
   empty-tree-at-active-height event. The `None` path is **not reached via zebra under aligned params.**

**Verdict on zit-hub's 3 decisions:**
1. **Still worth merging? Yes — but reclassified** from "blocker" to **defensive robustness**. None⟺empty
   is semantically correct on any chain; the test no longer firing ≠ bug gone. One caveat: it converts a
   loud crash into a silent empty-tree substitution *if* None were ever returned erroneously at an active
   height with a real non-empty tree — acceptable given the None=empty contract; the PR comment documents
   intent. No longer urgent.
2. **Needs its own test? Yes.** Since the IT suite no longer exercises this path, #455 should carry a
   **zallet-side unit test** for `fetch_chain_state` (None tree state + NU active ⟹ empty frontier, both
   pools). Owned here.
3. **#367 decoupling? Yes.** #104 makes stock zallet sync, so **#367 no longer depends on #455**;
   integration-tests **#56 needs only #367**, not #367+#455. Decouple them. (Memory `it56` updated.)

**Decided to SKIP the unit test** (2026-06-08): the `None` path isn't reachable via zebra under aligned
params, the `sync` module has zero test precedent, and `fetch_chain_state` is coupled to
`FetchServiceSubscriber` (no mock infra) — a real test would force a pure-helper refactor. Not worth it
for a 6-line defensive branch; the PR comment already documents the None=empty intent.

**✅ Rebased + pushed (2026-06-08):** rebased `fix/empty-shielded-tree-state` onto current main
(`b034cf7`), **zero conflicts** (single commit touches only `steps.rs`; no Cargo.lock conflict).
New head `00ef236` (force-pushed `3ab7bc7…00ef236`). `cargo build -p zallet` **green** + `cargo fmt
--check` clean — notably this also confirms **main's orchard-0.14/zebra-9.0 bump cleared the workspace
"orchard ^0.13 yanked" CI blocker** that was red on #400/#455/#367. `../wallet` left on branch
`fix/empty-shielded-tree-state` (was `316-wallet-status`), tree clean.

**Status:** (a) ~~rebase~~ DONE; (b) ~~post reclassification comment~~ **DONE** — posted
`#issuecomment-4653238011` (FYI: not blocking IT after `zcash/integration-tests#104`, but still worth
landing as a small robustness fix; None⟺empty holds on any chain; no internal hub/tool references since
those repos are private). (c) **PENDING:** confirm #56 re-validates against #367 alone.

---

## ⏸️ 2026-06-05 — #359 (`signmessage`, emersonian) reviewed: HOLD, needs contributor rebase

PR https://github.com/zcash/wallet/pull/359 — emersonian's, fork `zecrocks/be/signmessage`, single
commit `446d71bd`. APPROVED by you 2026-02-06, MERGEABLE but mergeState **BLOCKED**, last touched
2026-03-02. Reviewed in full this session. **Decision: HOLD — user will decide next session whether to
nudge emersonian.** Did NOT comment, did NOT re-request review.

**Why it's stuck (not a quick win after all):**
1. **Stale `verify_message.rs` duplicate.** When approved (Feb), the PR added BOTH `signmessage` +
   `verifymessage`. Since then **`verifymessage` landed on `main` independently via #92 (`14eee71`)**
   with 3 follow-up fixes the branch lacks: `916d506` (use `zcash_primitives` for hashing), `5669657`
   (rustfmt), `d364c47` (sha256d from new `zcash_transparent` location). PR still carries its older
   `verify_message.rs` (differs from main by 4 lines) → merging as-is **regresses** main. Must DROP the
   verify_message changes on rebase, keep only the new `signmessage` (`sign_message.rs` +20 lines in
   `methods.rs`).
2. **88 commits behind main** (forked 2026-02-26) — needs rebase regardless.
3. **CI never ran** — fork PR, `check-runs total=0`, status pending. Needs a maintainer to approve the
   fork workflow + a fresh push.
4. Open review threads all **optional/deferred** (mod tests reorg, zcashd test vectors → future
   integration framework, `found`/`break` simplification emersonian pushed back on). Non-blocking.

**signmessage code itself = good** (already approved): rejects P2SH (P2PKH-only, matches zcashd);
handles HD-derived + standalone-imported keys; sig header `31 + recovery_id` for compressed pubkeys
(cites zcashd `pubkey.cpp`); reuses `verify_message::message_hash`; self-contained roundtrip tests.

**Next-session action if pursuing:** post the drafted comment (saved below) asking emersonian to rebase
onto main + drop verify_message.rs, then approve fork CI. Can't do it myself — it's a fork branch and
dropping verify_message is a contributor decision.

<details><summary>Drafted comment for #359 (not yet posted)</summary>

Thanks for this @emersonian — the `signmessage` implementation looks good and is approved. One thing
has changed underneath the PR since February that needs a small untangle before it can land:

**`verifymessage` has since landed on `main` independently** (via #92, commit `14eee71`), and it's
picked up three follow-up fixes there that this branch doesn't have:
- `916d506` — refactor to use `zcash_primitives` for hashing
- `5669657` — rustfmt for `verifymessage`
- `d364c47` — use `sha256d` from its new location in `zcash_transparent`

Because this branch still carries its own older copy of `verify_message.rs`, merging as-is would
regress those fixes. Could you **rebase onto current `main` and drop the `verify_message.rs` changes**
— keeping `main`'s version — so the PR contains only the new `signmessage` pieces (`sign_message.rs` +
its registration in `methods.rs`)? The branch is ~88 commits behind, so a rebase is needed regardless.

Once that's pushed, a maintainer can approve the CI run (it hasn't run yet since this is a fork PR —
there are currently no checks on the branch), and assuming it's green it should be ready to merge.

The open review threads (test vectors, `mod tests` organization) are all optional/deferred and don't
block this — no need to address them here.

</details>

---

## ✅ 2026-06-05 — #353 (`openrpsee`) REVIVED: rebased onto main, mergeable again

PR https://github.com/zcash/wallet/pull/353 — yours, `docs(openrpc): Use common crate`. Was
CONFLICTING (39 commits behind `main`). Net cleanup: +31 / −357, swapping hand-rolled
`build.rs`/`openrpc.rs` openrpc machinery for the `openrpsee` crate.

- Rebased `openrpsee` branch onto `origin/main`; **only conflict was `Cargo.lock`**. Resolved by
  keeping `main`'s lock and adding `openrpsee v0.1.1` **incrementally** (`cargo metadata`) — a full
  `generate-lockfile` re-resolves and dies on the **yanked `orchard 0.13`** (the workspace blocker;
  note main's lock actually pins orchard 0.10.2/0.11.0, so it's a transitive `^0.13` requirement that
  hits the yank only on fresh resolve).
- Build clean against current `main`; `cargo fmt`/`clippy` pass. Force-pushed `e725146…efe9e5b`.
- Now **MERGEABLE**, mergeState BLOCKED only on REVIEW_REQUIRED. Posted a status comment
  (`#issuecomment-4631312199`). **Did NOT re-request review** (per user). str4d helped on this in March
  but no reviewer pinged this round — needs someone to review.
- `../wallet` restored to branch `316-wallet-status`, tree clean.

**Reusable trick:** to rebase any stale branch whose only conflict is `Cargo.lock`, take `main`'s lock
(`git checkout origin/main -- Cargo.lock`) then `cargo metadata` to add just the new dep — never
`generate-lockfile` while orchard 0.13 is yanked.

---

## ✅ 2026-06-05 — #36 (`gettransaction`) CLOSED as superseded

PR https://github.com/zcash/wallet/pull/36 — str4d's, draft, CHANGES_REQUESTED, CONFLICTING. User
(oxarbitrage) had taken it over in Aug 2025 (commits `8aca24f…90cb282`, minor query/doc fixes) but it
stalled. Researched whether it still had value → **no**; closed it with a summary comment
(`#issuecomment-4630939015`).

**Why it was a zombie, not a backlog item:**
- **Deliberate maintainer call, not staleness.** nuttycom (lead) ruled twice (2025-08-20) that
  `gettransaction` will **not** be in Zallet: it inherits zcashd's balance/`IsMine` semantics that
  can't be made reliable in zallet (you don't always hold the full input txs) — a known **loss-of-funds
  footgun**. Agreed replacement: extend `z_viewtransaction` to cover its use cases non-buggily.
- **Replacement shipped.** That `z_viewtransaction` work landed: #147 (transparent-equivalent details),
  #228 (per-account balance-effect map), #233 (account UUID per entry) — all closed. `z_viewtransaction`
  lives on `main` (`methods/view_transaction.rs`); active follow-ups: #156, #440, #450.
- **PR's own goal gone.** Issue #38 (which #36 "Closes") was edited to drop `gettransaction`; now only
  covers `z_viewtransaction`, and is closed.
- **Drift:** ~359 commits behind `main`, CONFLICTING/DIRTY. Reviving = full rebase + re-litigating a
  settled design decision. Not worth it.

Anyone wanting per-tx detail → use `z_viewtransaction`. No further action.

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
