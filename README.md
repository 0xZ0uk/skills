# skills

Personal skills for my Hermes agent. Layout mirrors `~/.skills/` — `category/skill-name/{SKILL.md,references/}`.

> **This repository is private.** Any skill installation requires a GitHub token with repo read access (see [Private repo auth](#private-repo-auth)).

## Install (recommended: skills CLI)

Always current instructions: https://github.com/vercel-labs/skills . Package manager for agent skills; works with any GitHub repo and target agent (claude-code, cursor, opencode, hermes-agent, …).

List what's in here without installing anything:

    GH_TOKEN=$(gh auth token) npx skills add 0xZ0uk/skills --list

Install everything, interactively pick agent targets:

    GH_TOKEN=$(gh auth token) npx skills add 0xZ0uk/skills

Install a specific skill only:

    GH_TOKEN=$(gh auth token) npx skills add 0xZ0uk/skills --skill blender-fps-rigging

Install several skills at once, all agents, no prompts:

    GH_TOKEN=$(gh auth token) npx skills add 0xZ0uk/skills --skill 'dokploy-deploy' 'proxmox-homelab-ops' --agent '*' --copy --yes

Global (user-level, not project-level) install:

    GH_TOKEN=$(gh auth token) npx skills add 0xZ0uk/skills -g

Other useful commands:

    npx skills ls                 # list installed skills
    npx skills update             # update to latest
    npx skills remove             # interactively remove installed skills

*Tip: `GH_TOKEN=$(gh auth token)` requires `gh` CLI to be authenticated on the machine. Once installed, skills symlink (or `--copy`) into each agent's skills directory (e.g. `~/.skills/`, `.claude/skills/`).*

## Private repo auth

The repo is private — `npx skills` needs a token that can read it. Options, best first:

1. **gh CLI (recommended).** If `gh auth login` has been run on the machine, just prefix the command:
   
       GH_TOKEN=$(gh auth token) npx skills add 0xZ0uk/skills

2. **Fine-grained PAT.** Generate a token at https://github.com/settings/personal-access-tokens/new scoped to *Contents: Read* on this repo only.
   Then export it for the session:

       export GH_TOKEN=ghp_xxxxxxxxxxxxxx
       npx skills add 0xZ0uk/skills

3. **Inline just for one invocation** (least residue, still lands transiently in shell history — consider `HISTCONTROL=ignorespace` and leading space if that matters):

       GH_TOKEN=$(<path-to-token-file>) npx skills add 0xZ0uk/skills

Do **not** commit or paste the token anywhere, and prefer not to put it in `.bashrc`/shell profile files; every use re-authenticates from `gh auth token` if you use method 1.

## Manual install (no CLI)

Clone and copy the categories/skills you want into your skills directory:

    git clone git@github.com:0xZ0uk/skills.git ~/tmp-skills
    cp -r ~/tmp-skills/devops ~/.skills/
    rm -rf ~/tmp-skills

## Contents

- **devops/dokploy-deploy** — deploying services on Dokploy (dash.blugg.pt): API quirks, compose pitfalls, GHCR pull fix
- **devops/proxmox-homelab-ops** — operating the Proxmox host (pve)
- **game-dev/blender-fps-rigging** — rig/skin FPS arms & guns in Blender, animate idle/walk/fire/reload, FBX export to Unity/UE5 (source: David Stenfors' 25-part course)
- **github/** — gh CLI workflows: auth, PRs, issues, repo management, code review, safe-git-sync
- **seo/** — seo-audit, seo-report, keyword-research, competitor-analysis (Porta443 SEO pipeline)

## Repo layout

    category/skill-name/
    ├── SKILL.md               # required entrypoint
    ├── references/            # detailed docs, loaded on demand
    ├── scripts/               # helper scripts
    └── templates/             # boilerplate files
