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

    npx skills add 0xZ0uk/skills --skill blender-fps-rigging

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

- **devops/dokploy-deploy** — deploying services on Dokploy (dash.blugg.pt): API quirks, compose pitfalls, GHCR pull fix
- **devops/proxmox-homelab-ops** — operating the Proxmox host (pve)
- **engineering/agent-router** — T3 Code orchestrator discipline: route agents to Opus 5.5 / Sonnet 5.5 / Pi GLM-5.3-flash by decision density, escalate on signals not vibes
- **game-dev/blender-fps-rigging** — rig/skin FPS arms & guns in Blender, animate idle/walk/fire/reload, FBX export to Unity/UE5 (source: David Stenfors' 25-part course)
- **github/** — gh CLI workflows: auth, PRs, issues, repo management, code review, safe-git-sync
- **seo/** — seo-audit, seo-report, keyword-research, competitor-analysis (Porta443 SEO pipeline)

## Repo layout

    category/skill-name/
    ├── SKILL.md               # required entrypoint
    ├── references/            # detailed docs, loaded on demand
    ├── scripts/               # helper scripts
    └── templates/             # boilerplate files
