---
name: isolated-worktree
description: Start a task in its own Git worktree and branch off the latest default branch, so several agents can work in one repo without colliding. Use at the start of every feature, fix, or ticket, before writing any code, or when asked to work in a worktree.
metadata:
  hermes:
    related_skills: [verification, safe-git-sync, github-issue-to-pr]
---

# Isolated worktree

Every task gets its own worktree and branch, created from the latest default branch. Never build on the default branch, and never reuse another agent's worktree, branch, or uncommitted work.

## Steps

1. **Find the main checkout.** Run `git worktree list` — the first line is the main checkout, even when you're inside another worktree. Call its absolute path `<main>`; every command below runs against it, so new worktrees never nest inside an existing one.

2. **Sync and find the default branch:**

   ```bash
   git -C <main> fetch origin
   git -C <main> symbolic-ref --short refs/remotes/origin/HEAD
   ```

   It prints e.g. `origin/main` or `origin/master` — that's `<base>`. If it errors, run `git -C <main> remote set-head origin --auto` and retry.

3. **Scope check.** List what the open PRs touch in one call:

   ```bash
   cd <main> && gh pr list --state open --limit 200 --json number,headRefName,files --jq '.[] | "#\(.number) \(.headRefName): \([.files[].path] | join(" "))"'
   ```

   If your task needs files another open PR is editing, **stop and ask for direction**. Also run `git -C <main> status --short` — dirty files there may be another agent mid-task; leave them alone.

4. **Name the task:** lowercase-with-hyphens plus a short unique suffix, e.g. `user-auth-0816a`. If the branch or path already exists, pick a new name — never force or reuse.

5. **Create the worktree** in a directory git ignores. Follow the repo's conventions if it defines a directory or branch prefix; otherwise use `.worktrees/` and `agent/`:

   ```bash
   grep -qxF '.worktrees/' "$(git -C <main> rev-parse --path-format=absolute --git-common-dir)/info/exclude" || echo '.worktrees/' >> "$(git -C <main> rev-parse --path-format=absolute --git-common-dir)/info/exclude"
   git -C <main> worktree add --no-track <main>/.worktrees/<task-name> -b agent/<task-name> <base>
   ```

   `info/exclude` keeps the directory out of git without committing a `.gitignore` change. It doesn't hide it from tools with their own file globbing (Jest's haste map, `tsc` with `**/*`, file watchers) — if those pick up the worktree's duplicate files, exclude `.worktrees` in that tool's config or put worktrees outside the repo.

   `--no-track` stops the branch from tracking `<base>`, so a bare `git push` can't land on the default branch — push with `git push -u origin agent/<task-name>`.

6. **Work only through the worktree's absolute path,** `<wt>` = `<main>/.worktrees/<task-name>`. Agent shells often reset the working directory between commands, so a `cd` from an earlier command can silently put you back in the main checkout. Prefix commands with `cd <wt> &&` or use `git -C <wt>`, and confirm before the first edit and before every commit:

   ```bash
   git -C <wt> branch --show-current   # must print agent/<task-name>
   ```

7. **Install dependencies inside the worktree** (worktrees don't share `node_modules` or virtualenvs) with the repo's package manager and its pinned runtime version (`.nvmrc`, `.tool-versions`, `packageManager` in `package.json`).

## Remember

- Worktrees don't isolate shared resources: dev-server ports, databases, caches. Before trusting a running server, do the port-ownership check ("Capture hygiene" in the `verification` skill). Never run schema experiments against a shared database.
- Resolve lockfile conflicts by regenerating the lockfile, never by hand-merging.
- Keep the worktree until the PR is merged or closed, then clean up:

  ```bash
  git -C <main> worktree remove <wt>
  git -C <main> branch -D agent/<task-name>
  ```

  `-D` is expected: after a squash or rebase merge, `-d` refuses even though the work is merged.
