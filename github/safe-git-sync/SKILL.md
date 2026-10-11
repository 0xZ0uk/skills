---
name: safe-git-sync
description: Safely fetch, review, and integrate remote Git changes when the local working tree may already contain edits.
---

# Safe Git Sync

Use when the user says things like:
- "pull the weekend changes"
- "review what's changed upstream"
- "sync this repo, but I already changed stuff locally"
- "check the remote branch before you integrate it"

This skill exists to prevent the dumbest Git mistake: pulling into a dirty tree and turning a review task into a recovery task.

## Goal

Separate three concerns that people often mash together:
1. **discover** what changed upstream
2. **review** whether those incoming changes are sound
3. **integrate** them into the user's real branch without damaging local work

Do them in that order.

## Workflow

### 1. Inspect the real branch first

Run:

```bash
git status -sb
git remote -v
git fetch origin --prune
git rev-list --left-right --count HEAD...origin/$(git branch --show-current)
git log --oneline HEAD..origin/$(git branch --show-current) -10
```

This gives you:
- whether the branch is dirty
- whether it is behind/ahead
- which commits are incoming

Do **not** pull yet.

If the user names a deployed branch explicitly, switch to that branch before you review or integrate. Do not assume the currently checked-out branch is the one in production. If the tree is dirty, stash untracked files too (`git stash push -u`) before changing branches or pulling.

### 2. Measure overlap risk

If local edits exist, compare changed-file sets:

```bash
git diff --name-only | sort > /tmp/local-files.txt
git diff --name-only HEAD..origin/$(git branch --show-current) | sort > /tmp/remote-files.txt
comm -12 /tmp/local-files.txt /tmp/remote-files.txt
```

If overlap exists, assume conflict risk is real until proven otherwise.

## 4. Review the remote state in an isolated worktree

Use a detached worktree rooted at the incoming remote head:

```bash
git worktree add --detach /tmp/review-branch origin/$(git branch --show-current)
```

Do the review there:
- inspect commit list and diff stat
- read changed files
- install dependencies if needed
- run build/lint/tests/smoke checks there, not in the dirty branch

This gives you a clean, reproducible view of the incoming branch.

### 4b. If the branch is a PR, verify the remote ref before trusting PR state

A branch can gain a last-minute push while its PR is being merged. If the user asks whether a commit made it in, do not trust the PR object alone.

Check the branch tip and compare endpoint first:

```bash
git ls-remote origin <branch>
gh api repos/$OWNER/$REPO/branches/<branch> --jq .commit.sha
gh api repos/$OWNER/$REPO/compare/<base>...<head> --jq '{ahead:.ahead_by, files:[.files[].filename]}'
```

Then inspect the PR object separately:

```bash
gh pr view <number> --json state,mergedAt,mergeCommit,headRefOid,headRefName
gh api repos/$OWNER/$REPO/pulls/<number>/commits
```

If the merge beat the final push, cherry-pick the missing commit onto fresh `main` and open a follow-up PR. See `references/pr-merge-race.md` for the recovery pattern.

### 5. Verify with the environment the remote branch actually needs

If the reviewed branch needs env vars, local services, or a database, supply them explicitly in the review worktree.

Examples:
- set temporary build env vars instead of assuming shell state
- start Docker services from that worktree if the branch depends on them
- hit real routes/endpoints after the app starts

The point is to verify the remote branch, not your memory of the setup.

### 5. Baseline failing checks before calling them regressions

If a quality gate fails in the remote worktree, compare against the pre-sync base commit in another clean worktree.

Use this when needed:

```bash
git worktree add --detach /tmp/base-branch <pre-sync-commit>
```

If the same command fails on the baseline, report it as **pre-existing**, not introduced by the incoming commits.

This matters for noisy checks like lint and template-era build problems.

### 6. Decide how to protect local work before integration

Once the review is done, choose one of these:

#### Option A — stash local work
```bash
git stash push -u -m 'descriptive-sync-stash'
git pull --ff-only
```

Use when the user wants the branch updated quickly and the local edits are not yet worth a commit.

#### Option B — commit to a WIP branch
```bash
git switch -c wip/<topic>
git add -A
git commit -m 'wip: save local state before sync'
```
Then return to the main branch and integrate.

Use when the local state is meaningful and likely to be resumed soon.

#### Option C — leave the real branch untouched
Keep working in the review worktree until the user chooses how to integrate.

Use when the branch is messy or conflict-heavy.

### 7. Integrate conservatively

Prefer:

```bash
git pull --ff-only
```

If fast-forward is impossible, stop and decide explicitly whether to:
- merge
- rebase
- keep work isolated longer

Don't improvise history surgery on a branch the user is actively using.

### 8. Verify on the actual branch after integration

After the real branch moves forward, rerun the relevant checks there.

At minimum:
- `git status -sb`
- the key build/test/smoke command used during review

Tell the user exactly where their protected local work now lives:
- stash name
- WIP branch name
- or untouched original branch

## Reporting format

When summarizing, keep it explicit:

- repo path
- branch and new HEAD
- whether local work was stashed/branched/left untouched
- what you reviewed
- what actually passed
- what failed
- which failures are pre-existing vs introduced
- overlap/conflict risk if the stash is later re-applied

## Pitfalls

- **Fetching is not pulling.** Say which one you did.
- **Don't pull first "just to see".** That's how you create unnecessary conflict recovery work.
- **Don't review upstream changes inside a dirty tree.** Use a worktree.
- **Don't call a failing check a regression without a baseline comparison.**
- Don't forget untracked files when stashing. Use `-u` when the local state includes new files.
- If a stash/pop or recovery step conflicts, stop and inspect reflog/stash state before touching the tree. A branch may have advanced under you because another worker committed, reverted, or rewrote the same area.
- Don't leave temporary review infrastructure running. Tear down background servers and Docker services when done.

## References

- `references/worktree-review-pattern.md` — compact pattern for fetch → isolated review → baseline check → safe integration.
- `references/pr-merge-race.md` — verify branch refs vs PR state when a last-minute push races a merge.
- `references/concurrent-repo-mutation.md` — recovery sequence when Git state changes unexpectedly during sync or stash recovery.
