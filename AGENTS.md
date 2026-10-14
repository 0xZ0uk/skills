# Conventions for skills in this repo

Read this before adding or editing a skill.

## Layout

`category/skill-name/SKILL.md`, plus optional `references/`, `templates/`, `scripts/`. Every file in those folders must be linked from its `SKILL.md` with a one-line "read this when…" — an unlinked file is never loaded. Links to files that don't exist are bugs.

## Two invocation types

Every skill is one of these. Decide deliberately; it sets how the description is written.

- **Model-invoked** (default): the agent picks it up on its own when the task fits. The `description` is model-facing: what it does, then "Use when…" with the words a user would actually type. This is the only text in context before the skill loads, so it carries the triggering.
- **User-invoked**: runs only when the user asks for it (typed `/skill-name`, or an explicit request). Add `disable-model-invocation: true` to the frontmatter and keep the `description` to one human-facing line, no trigger list. Use it for skills that spend money or credits, act outward (publish, comment, deploy), or orchestrate a long flow the user should start on purpose.
  - Claude Code honours the flag. **Hermes ignores it** and still offers the skill by description, so also put a guard line at the top of the body ("Run only when the user explicitly asked for this…").

Current user-invoked skills: `seo-audit`, `keyword-research`, `competitor-analysis`, `to-spec`, `to-tickets`, `improve-codebase-architecture`, `interface-review`, `explain-interface`, `break`, `state-machine`, `variant`. Everything else is model-invoked.

## Building blocks and orchestrators

- A **building block** holds reusable knowledge other skills load: `seo-report` (report format + OpenSEO access), `github-auth` (auth detection, `gh-env.sh`), `grilling` (the interview loop), `codebase-design` (deep-module vocabulary). Put shared facts here once; other skills link to them instead of copying.
- An **orchestrator** runs a flow and loads building blocks: the SEO trio, `github-issue-to-pr`, `improve-codebase-architecture`, `to-spec`, `to-tickets`.
- A user-invoked skill may load model-invoked skills, never another user-invoked one — suggest it to the user instead.
- When skills compose, **test the whole chain**, not each skill alone: the caller's assumptions (variable names, file formats, what's committed, who answers questions) must match what the callee actually does.

## Content

- Only what the model wouldn't know or do by default: verified pitfalls, environment facts, non-obvious procedures. Cut generic tutorials.
- Keep SKILL.md short; move bulky or rarely-needed detail to linked references.
- Each fact lives in one place. No duplicates across a skill and its references, or across skills.
- Separate durable procedure from volatile state (IDs, IPs, sizes, versions): state goes in a dated `references/inventory.md`, and the procedure says how to re-check it live.
- Shell snippets must pass `bash -n` (placeholders aside) and must not need a TTY (`docker exec -it`, `read -p`) unless the user runs them.
- Write instructions as actions ("run", "read the file"), not one harness's tool names, so skills work in Hermes, Claude Code and others.

## Skills adapted from mattpocock/skills

`engineering/{diagnosing-bugs,two-axis-review,to-tickets,to-spec,codebase-design,improve-codebase-architecture}` and `productivity/{grilling,writing-for-agents}` come from [mattpocock/skills](https://github.com/mattpocock/skills) at commit `49dd158` (MIT, see `THIRD_PARTY_LICENSE-mattpocock-skills.txt`). They were adapted, not copied verbatim: GitHub via `gh` instead of Matt's per-repo setup skill, `code-review` renamed to `two-axis-review` (Claude Code has a built-in `code-review`), Codex `agents/openai.yaml` files dropped, and review findings fixed. To pull upstream changes, diff the upstream skill between `49dd158` and its current head and port what applies; don't overwrite.

## When you change skills

Update the README's Contents list when adding, removing or renaming a skill.

## Skills adapted from jakubkrehel/skills

`frontend/*` comes from [jakubkrehel/skills](https://github.com/jakubkrehel/skills) at commit `4c66b1f` (MIT, see `THIRD_PARTY_LICENSE-jakubkrehel-skills.txt`); `technical-drawing` was left out. Changes: descriptions rewritten to our "Use when…" form, Codex `agents/openai.yaml` dropped, Hermes guard lines added, supporting files moved into `references/`, the standalone report format moved from each `better-*` skill into `better-interface`'s `references/review-format.md`, and review findings fixed (scope resolution in `interface-review`, throwaway-route guards and cleanup, factual errors). Upstream's own rules still hold inside `frontend/`: each rule has one owning `better-*` skill (see the [ownership table](https://github.com/jakubkrehel/skills/blob/4c66b1f/AGENTS.md#rule-ownership) in upstream's AGENTS.md), and these texts are deliberate pairs that must change together: `variant/references/picker.md` and `state-machine/references/switcher.md`, and the throwaway-route paragraphs in `break` and `state-machine`. To pull upstream changes, diff upstream between `4c66b1f` and its current head and port what applies.
