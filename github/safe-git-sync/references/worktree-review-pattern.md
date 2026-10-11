# Worktree Review Pattern

Use this when upstream changed and the local branch is already dirty.

## Minimal recipe

```bash
# 1) inspect
git status -sb
git fetch origin --prune
git rev-list --left-right --count HEAD...origin/$(git branch --show-current)
git log --oneline HEAD..origin/$(git branch --show-current) -10

# 2) compare local-vs-remote touched files
git diff --name-only | sort > /tmp/local-files.txt
git diff --name-only HEAD..origin/$(git branch --show-current) | sort > /tmp/remote-files.txt
comm -12 /tmp/local-files.txt /tmp/remote-files.txt

# 3) review remote branch in isolation
git worktree add --detach /tmp/review-branch origin/$(git branch --show-current)
cd /tmp/review-branch

# 4) run verification here, with explicit env/services
pnpm install --frozen-lockfile
pnpm build
```

## Baseline rule

If `build`, `lint`, or `test` fails in the review worktree, compare against the pre-sync base commit before calling it a regression:

```bash
git worktree add --detach /tmp/base-branch <pre-sync-commit>
```

If the same command fails there too, report it as pre-existing.

## Integration options

### Stash path
```bash
git stash push -u -m 'descriptive-sync-stash'
git pull --ff-only
```

### WIP branch path
```bash
git switch -c wip/<topic>
git add -A
git commit -m 'wip: save local state before sync'
```

## Session-specific note from Block8

A clean review worktree made it possible to:
- review 7 incoming commits without touching the user's dirty branch
- prove the remote branch built successfully once temporary env vars and local Mongo were supplied
- show that `pnpm lint` failure was pre-existing by reproducing it on the pre-sync base commit
- stash local work only after review confidence was established, then fast-forward safely

## Why this pattern matters

It turns a risky "pull and pray" task into a reversible workflow:
- inspect
- isolate
- verify
- protect local work
- integrate
- re-verify
