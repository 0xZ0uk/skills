# skills

Personal skills for my Hermes agent. Layout mirrors `~/.skills/` — `category/skill-name/{SKILL.md,references/}`.

> **This repository is private.** One-time setup for local clones *and* the skills CLI: `gh auth setup-git` (requires `gh auth login`). See [Private repo auth](#private-repo-auth) and [Troubleshooting](#troubleshooting-endless-spinner).

## Install (recommended: skills CLI)

Always current instructions: https://github.com/vercel-labs/skills . Package manager for agent skills; works with any GitHub repo and target agent (claude-code, cursor, opencode, hermes-agent, …).

List what's in here without installing anything (after the one-time auth setup below):

    npx skills add 0xZ0uk/skills --list

Install everything, interactively pick agent targets:

    npx skills add 0xZ0uk/skills

Install a specific skill only:

    npx skills add 0xZ0uk/skills --skill safe-git-sync

Install several skills at once, all agents, no prompts:

    npx skills add 0xZ0uk/skills --skill 'dokploy-deploy' 'proxmox-homelab-ops' --agent '*' --copy --yes

Global (user-level, not project-level) install:

    npx skills add 0xZ0uk/skills -g

Other useful commands:

    npx skills ls                 # list installed skills
    npx skills update             # update to latest
    npx skills remove             # interactively remove installed skills

*Tip: these all assume the one-time `gh auth setup-git` from the next section. Once installed, skills symlink (or `--copy`) into each agent's skills directory (e.g. `~/.skills/`, `.claude/skills/`).*

One-time setup (required for private repos, works for everything else too):

    gh auth setup-git

This wires git to use your `gh` credentials for github.com. `skills add` on a private repo clones via your local git credentials — `GH_TOKEN` alone is NOT enough and is the reason the commands used to hang.

See [Troubleshooting: endless spinner](#troubleshooting-endless-spinner) if `npx skills` still hangs after this.

## Private repo auth

The repo is private — `npx skills` clones it over your local git credentials (vercel-labs/skills#1318: the CLI's fetch path never consumes `GH_TOKEN` for private repos). What actually works:

1. **gh CLI (recommended, works).** Run once per machine:

       gh auth setup-git

   Then plain `npx skills add 0xZ0uk/skills` works with no `GH_TOKEN` prefix. `gh auth login` must have been run first.

2. **Local-path install (always works, bypasses git entirely).**

       gh repo clone 0xZ0uk/skills ~/z0uk-skills
       npx skills add ~/z0uk-skills --list
       npx skills add ~/z0uk-skills --skill agent-router -g --copy --yes

   Updating this way: `git -C ~/z0uk-skills pull` then re-run the `add` line.

3. **Fine-grained PAT (env var only helps public-API paths — mostly NOT effective here).** Known CLI defect (vercel-labs/skills#1318): the fetch code only attaches a token after a 403 rate-limit response; a private repo's 404 never triggers it. Listed for completeness:

       export GH_TOKEN=«redacted token»
       npx skills add 0xZ0uk/skills

Do **not** commit or paste tokens anywhere, and prefer not to put them in `.bashrc`/shell profile files.

## Troubleshooting: endless spinner

If `npx skills add 0xZ0uk/skills ...` loads forever (spinner that won't even Ctrl+C cleanly), git is stuck waiting for credentials *behind the spinner* (vercel-labs/skills#12, #910). Fix in order:

1. `gh auth setup-git` (see above) — the proven fix.
2. Sanity-check SSH out of the way: `git ls-remote git@github.com:0xZ0uk/skills.git` should return immediately. If it hangs, it's your SSH agent, not the skills CLI.
3. Fallback: first-run `-y` (`npx -y skills add ...`) in case the npm proceed-prompt is being swallowed.
4. Nuclear option: local-path install (auth option 2 above) — no git subprocess, no credential wait.

## Manual install (no CLI)

Clone and copy the categories/skills you want into your skills directory:

    git clone git@github.com:0xZ0uk/skills.git ~/tmp-skills
    cp -r ~/tmp-skills/devops ~/.skills/
    rm -rf ~/tmp-skills

## Contents

Skills are either **user-invoked** (run only when you ask, e.g. `/seo-audit`) or **model-invoked** (the agent reaches for them when the task fits). Conventions for writing and changing skills: [AGENTS.md](AGENTS.md).

**User-invoked**

- **seo/seo-audit** — audit a site and report the one to three changes most likely to grow organic traffic
- **seo/keyword-research** — find and prioritize keyword opportunities for a site or topic
- **seo/competitor-analysis** — analyze one competitor's organic footprint and where it's vulnerable
- **engineering/to-spec** — turn the current conversation into a spec and publish it as a GitHub issue
- **engineering/to-tickets** — break a plan or spec into dependency-ordered GitHub issues
- **engineering/improve-codebase-architecture** — survey a codebase for deepening opportunities and present them as an HTML report

The three SEO skills spend OpenSEO credits.

**Model-invoked**

- **devops/dokploy-deploy** — deploying and operating services on the homelab Dokploy (LXC 100) via its REST API; per-app notes in `references/apps/`
- **devops/proxmox-homelab-ops** — general Proxmox VE host operations: memory budgeting, backups, firewall with dead-man rollback, thin pools, storage, updates
- **engineering/agent-router** — route spawned agents to the right model tier (Opus / Sonnet / Pi + GLM) by decision count
- **engineering/diagnosing-bugs** — disciplined loop for hard bugs and performance regressions: reproduce, minimise, hypothesise, instrument, fix, regression-test
- **engineering/verification** — generate a per-app verify skill, then gate every change on captured before/after evidence
- **engineering/two-axis-review** — review a diff against the repo's coding standards and against its spec, as two separate passes
- **engineering/codebase-design** — *building block:* vocabulary and discipline for designing deep modules
- **github/github-auth** — *building block:* detect and set up GitHub auth for git and gh, including headless device-flow login
- **github/github-gh-pitfalls** — gh CLI / GitHub API traps and workarounds, cross-fork porting
- **github/github-issue-to-pr** — carry an issue to a verified PR with honest CI state
- **github/isolated-worktree** — start each task in its own worktree and branch off the default branch, so parallel agents don't collide
- **github/before-and-after** — put before/after screenshots into a PR body, uploaded through GitHub (`gh --attach`), never a public host
- **github/safe-git-sync** — fetch, review and integrate upstream changes without damaging local work
- **seo/seo-report** — *building block:* report format and shared OpenSEO access notes; the three SEO skills above load it
- **productivity/grilling** — *building block:* interview the user about a plan until every branch of the decision tree is resolved
- **productivity/writing-for-agents** — how to write skills, AGENTS.md/CLAUDE.md, and other docs agents read

`verification`, `isolated-worktree` and `before-and-after` come from the porta443-skills OpenCode setup; `before-and-after` adapts [vercel-labs/before-and-after](https://github.com/vercel-labs/before-and-after) (PolyForm Shield 1.0.0, licence in the skill folder). The other engineering and productivity skills above (except agent-router) are adapted from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT, see `THIRD_PARTY_LICENSE-mattpocock-skills.txt`); [AGENTS.md](AGENTS.md) lists what changed.

Claude Code honours the user-invoked flag (`disable-model-invocation: true`). Hermes doesn't, so those skills also carry a guard line telling the agent to run them only on an explicit request.

## Agent compatibility

Written for Hermes, but tool-neutral where possible, so they also work in Claude Code, Cursor, etc. Hermes-specific parts: `$HERMES_HOME` fallbacks in `github-auth`, the Executor MCP route in the SEO skills, and homelab-specific IPs, IDs and paths in `dokploy-deploy`.

## Repo layout

    category/skill-name/
    ├── SKILL.md               # required entrypoint
    ├── references/            # detailed docs, loaded on demand
    ├── scripts/               # helper scripts
    └── templates/             # boilerplate files
