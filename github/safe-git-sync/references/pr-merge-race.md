# PR Merge Race and Branch-Ref Verification

Use this when a last-minute push races a PR merge.

## What happened in the session

A commit was pushed to a feature branch moments before the PR merged. GitHub's PR view still showed the older head/commit set, while the remote branch ref had already advanced. The missing commit did not land in the target branch and had to be recovered with a follow-up PR.

## Verification sequence

1. Check the remote ref directly:
   - `git ls-remote origin <branch>`
   - `gh api repos/<owner>/<repo>/branches/<branch> --jq .commit.sha`
2. Compare branch tips:
   - `gh api repos/<owner>/<repo>/compare/<base>...<head>`
3. Inspect the PR object separately:
   - `gh pr view <number> --json state,mergedAt,mergeCommit,headRefOid,headRefName`
   - `gh api repos/<owner>/<repo>/pulls/<number>/commits`
4. If the PR merged before the final push landed, cherry-pick the missing commit onto a fresh copy of the base branch and open a follow-up PR.

## Rule

Treat the branch ref and compare API as the source of truth for what is actually on the remote branch. Treat PR state as a separate signal that can lag or reflect a closed/merged snapshot.
