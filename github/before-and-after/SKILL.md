---
name: before-and-after
description: "Put before/after screenshots or recordings into a GitHub PR description, uploaded through GitHub itself (gh --attach), never a public host. Use when a PR changes something visible and needs visual proof, or the user asks for before/after, PR screenshots, or a visual comparison."
license: PolyForm-Shield-1.0.0
compatibility: "Needs gh 2.99+ (for --attach), node, and agent-browser for capture."
metadata:
  source: "vercel-labs/before-and-after@8306d34 (PolyForm Shield 1.0.0, see LICENSE), adapted"
  hermes:
    related_skills: [verification, isolated-worktree, github-gh-pitfalls]
---

# Before and after in a PR

This skill owns getting media into the PR. Capturing it belongs to `agent-browser`; uploading belongs to `gh --attach`, which stores files as GitHub attachments that inherit the repo's visibility. Never upload captures to a third-party host — screenshots of a private app leak whatever is on screen.

`<skill-dir>` below is this skill's base directory.

## 1. Get the two captures

- **Already captured** (e.g. by the `verification` skill, under `.artifacts/<task>/`): use those files. Don't ask the user anything.
- **Need to capture**: load `agent-browser skills get core --full` and follow it. For a protected Vercel Preview, load `agent-browser skills get protected-vercel-deployments --full` instead of improvising auth. The "before" is the default branch's behavior — captured before the code changed (`verification`, "Before you touch code"), or from a URL the user names (production, an older preview). Don't switch branches, stash, or start servers in someone else's checkout to get it; if there's no before available, ask.

Rules for the files:

- Inside the directory you'll run `publish.sh` from (the worktree root), no whitespace in paths. PNG, JPEG, GIF, WebP, MP4, MOV or WebM; before and after must be the same type.
- Same viewport and state for both. For full-page shots, make both the same pixel height or GitHub centers the shorter one in its table cell: read `document.documentElement.scrollHeight` in both, pad the shorter page at the **bottom** (`agent-browser eval`) until they match, then capture. For a component, capture the same scoped region instead.
- Never capture or publish anything showing tokens, bypass secrets, authenticated query strings, or browser state files.

Recordings: read `references/video.md` — they have a recording-context auth trap and need a two-step publish for side-by-side tables.

## 2. Place the block

The media goes in a marked block, `<!-- before-and-after:start -->` … `<!-- before-and-after:end -->`. If the PR body has no block, it's appended at the end. To put it near the top (after the short summary, before Changes/Testing), add the two empty marker lines there when you write the PR body. Never rewrite other prose to make room.

## 3. Publish

From the worktree root, in the same command (agent shells may reset the working directory between commands):

```bash
cd <worktree> && bash <skill-dir>/scripts/publish.sh <pr> \
  --before .artifacts/<task>/before.png --after .artifacts/<task>/after.png
```

- Several pairs: repeat `--before`/`--after` in order and add one `--label` per pair (`--label Desktop --label Mobile`).
- New screen with no before: pass only `--after`; it renders as "Preview".
- `--attribution "<name>"` adds a "Before/after by" line.

The script reads the current body, replaces only the marked block (re-running replaces it again — it never duplicates), uploads the files and rewrites their `./` paths to GitHub URLs. It then re-reads the PR and fails if the block didn't land (some `gh` versions skip `pr edit` silently — see `github-gh-pitfalls`) or a local path is left (partial upload — re-run). It warns when a PNG pair differs in height, and rejects paths containing `#` (gh's alt-text separator). On success it prints the PR URL. Open the rendered PR once to confirm the images show and sit where you meant.

`scripts/format.mjs` is upstream's formatter with one patched line (paths in dot-directories like `.artifacts/` now get the `./` prefix `gh --attach` matches on); `publish.sh` wraps it so the steps work in any shell (the bash array plumbing breaks in fish).
