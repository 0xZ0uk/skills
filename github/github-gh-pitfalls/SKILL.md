---
name: github-gh-pitfalls
description: "Known gh CLI / GitHub API traps and their workarounds. Use when a gh command (pr edit, pr create, api, run) silently does nothing, errors with GraphQL/Projects (classic) messages, or when working without gh via curl, or when porting a feature between diverged forks with multiple upstream remotes."
---

# GitHub CLI pitfalls

Plain `gh` usage is not covered here — only the places where `gh` or the API misbehaves. For auth setup and the gh → `GITHUB_TOKEN` fallback chain, see `github-auth` (`source <github-auth>/scripts/gh-env.sh` sets `GH_AUTH_METHOD`, `GITHUB_TOKEN`, `GH_OWNER`, `GH_REPO`).

## `gh pr edit --title` / `--body-file` can fail silently

Some `gh` versions build the PR-edit GraphQL mutation with `repository.pullRequest.projectCards`, which errors with `GraphQL: Projects (classic) is being deprecated...` — and the edit is **not applied**. `gh pr create` is usually fine; `gh pr edit` trips it.

Workaround — PATCH through REST, which never touches the deprecated field:

```bash
python3 -c '
import json, pathlib
body = pathlib.Path("/tmp/pr-body.md").read_text()
json.dump({"title": "feat: ...", "body": body}, open("/tmp/pr-payload.json", "w"))
'
# GH_OWNER / GH_REPO come from github-auth's gh-env.sh
gh api --method PATCH repos/$GH_OWNER/$GH_REPO/pulls/$PR_NUMBER \
  --input /tmp/pr-payload.json --jq '{title, state, mergeable}'
```

Read the PR back and confirm the title changed before moving on; on the buggy `gh` the old title persists with no error you'd notice.

## Without gh

- Check out a PR: `git fetch origin pull/<N>/head:pr-<N> && git switch pr-<N>`.
- Auto-merge has no REST endpoint; it needs the GraphQL `enablePullRequestAutoMerge` mutation, and only works if the repo has auto-merge enabled in settings.
- Actions secrets must be encrypted with the repo's public key (`GET /repos/{o}/{r}/actions/secrets/public-key`, libsodium sealed box) before `PUT`; a plaintext value is rejected.

## References

- `references/cross-fork-feature-porting.md` — three-remote setup (origin / upstream-fork / upstream-original) and porting a feature across diverged forks: adapter points, import rewiring, display-only `***` redaction, and the `initDb()` data-wipe trap.
