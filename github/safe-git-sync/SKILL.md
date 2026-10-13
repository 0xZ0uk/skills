---
name: safe-git-sync
description: "Safely fetch, review, and integrate remote Git changes when the local working tree may already contain edits: inspect before pulling, measure file overlap, review the incoming head in an isolated worktree, baseline failing checks, protect local work, then fast-forward. Use for 'pull the latest/weekend changes', 'sync this repo but I have local changes', 'review what changed upstream', or 'did my last commit make it into the merged PR'."
---

# Safe Git Sync

Prevents the classic mistake: pulling into a dirty tree and turning a review task into a recovery task. Keep three concerns separate and do them in order:

1. **discover** what changed upstream
2. **review** whether the incoming changes are sound
3. **integrate** them without damaging local work

`BR` below means the branch being synced — `$(git branch --show-current)` unless the user names a deployed branch, in which case use that one and don't assume the checked-out branch is what runs in production.

## 1. Inspect — do not pull yet

```bash
git status -sb
git remote -v
git fetch origin --prune
git rev-list --left-right --count HEAD...origin/$BR    # ahead / behind
git log --oneline HEAD..origin/$BR -10                 # incoming commits
```

## 2. Measure overlap risk

If local edits exist, compare touched files (staged, unstaged and untracked) with the incoming ones:

```bash
{ git diff --name-only HEAD; git ls-files --others --exclude-standard; } | sort -u > /tmp/local-files.txt
git diff --name-only HEAD...origin/$BR | sort > /tmp/remote-files.txt
comm -12 /tmp/local-files.txt /tmp/remote-files.txt
```

Any overlap means conflict risk is real until proven otherwise.

## 3. Review the incoming head in an isolated worktree

```bash
git worktree add --detach /tmp/review-$BR origin/$BR
```

There, not in the dirty tree: read the commit list, diff stat and changed files; install dependencies; run build/lint/tests/smoke checks. Supply whatever the branch needs explicitly — temporary env vars, Docker services started from that worktree, real routes hit after the app starts. The point is to verify the remote branch, not your memory of the setup.

## 4. Baseline failures before calling them regressions

If a check fails in the review worktree, run the same command on the pre-sync commit:

```bash
git worktree add --detach /tmp/base-$BR HEAD
```

Fails there too → report it as **pre-existing**, not introduced upstream. Matters most for noisy lint and template-era build problems.

## 5. Protect local work

Pick one, and tell the user which:

- **Stash** — local edits aren't worth a commit yet: `git stash push -u -m 'sync-<date>-<topic>'` (`-u` keeps untracked files). Stash before switching branches too.
- **WIP branch** — local state is meaningful and will be resumed: `git switch -c wip/<topic> && git add -A && git commit -m 'wip: save local state before sync'`, then switch back.
- **Leave it** — branch is messy or conflict-heavy: keep working in the review worktree until the user decides.

## 6. Integrate conservatively

```bash
git switch $BR            # if not already on it (after step 5 protected local work)
git merge --ff-only origin/$BR
```

This uses the already-reviewed `origin/$BR` — not whatever the checked-out branch's upstream happens to be, and without a second fetch that could pull in commits you didn't review. If fast-forward is impossible, stop and ask whether to merge, rebase, or keep the work isolated longer. No improvised history surgery on a branch the user is actively using.

## 7. Re-verify and clean up

- Rerun `git status -sb` and the key build/test command from step 3 on the real branch.
- `git worktree remove /tmp/review-$BR` (and the base worktree); stop any servers or Docker services you started.

## PR merge races

When the user asks whether a commit made it into a merged PR, the PR object can lag the branch ref. Compare the remote branch tip with the PR's `headRefOid` and commit list before answering; if the merge beat the final push, cherry-pick the missing commit onto a fresh copy of the PR's base branch and open a follow-up PR. Commands: `references/pr-merge-race.md`.

## Report

Repo path · branch and new HEAD · where local work lives (stash name / WIP branch / untouched) · what you reviewed · what passed · what failed, split into pre-existing vs introduced · conflict risk if the stash is re-applied later.

## Pitfalls

- **Fetching is not pulling.** Say which one you did.
- Don't pull "just to see".
- Don't review upstream changes inside a dirty tree.
- If a stash pop or recovery step conflicts, stop and inspect `git reflog` and `git stash list` before touching the tree — another worker may have committed, reverted, or rewritten the same area while you were syncing.
