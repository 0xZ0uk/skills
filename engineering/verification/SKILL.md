---
name: verification
description: "Generate and run a project-local verify-<app> skill that drives the app the way a user does, then gate every change on captured evidence before pushing. Use before declaring a feature, fix, or ticket done, before opening a PR, or when a repo has no scripted way to prove UI/CLI/service behavior."
license: MIT
metadata:
  source: "cursor/plugins pstack create-verification-skill (MIT), trimmed for solo workflow"
  grafts: "assertion discipline + capture hygiene from michaelshimeles/skills evidence-driven-testing (MIT)"
  hermes:
    related_skills: [isolated-worktree, before-and-after, diagnosing-bugs, github-issue-to-pr]
---

# Verification

Every serious project needs a scripted way to drive the real app and prove behavior: launch it, exercise a feature the way a user would, capture evidence. This skill has two modes:

1. **Generate** — the repo has no verification skill yet → derive one (`verify-<app>/` in the project's skills directory — `.claude/skills/`, `.opencode/skills/`, or wherever this harness loads project skills) from the repo itself, prove it once, hand it over.
2. **Run** — a verify skill exists → execute it and treat its evidence as the gate before any push or "done".

`<task>` below is the task's name — the worktree name when you use `isolated-worktree`.

## Before you touch code

1. **No verify skill yet?** Generate it now (Mode 1), not at the end — you need its Launch and Drive recipe to capture the "before".
2. **Capture the "before".** For a bug, that's the failing repro (the `diagnosing-bugs` loop produces it); for a visible change, a screenshot of the current behavior, saved as `.artifacts/<task>/before.png` and taken by the rules in the `before-and-after` skill (same viewport and state as the after, equal heights for full-page shots). It's the first half of the proof, and it can't be recreated once the code has changed.

## Mode 1: generate

### Interview the repo, not the user

Answer these from the codebase; ask the user only what you cannot observe:

- **Surface:** what does a user actually touch? Web UI, CLI/TUI, API, desktop app, library? Pick the primary, note the rest.
- **Run:** how does the app start locally? Prefer the repo's own documented dev command (package scripts, Makefile, README quickstart). Note ports, env vars, seed data, auth.
- **Drive:** how can an agent interact programmatically? Existing harnesses first (Playwright/Cypress specs, curl-able endpoints, PTY helpers), then a generic recipe (browser/CDP for web and Electron, plain HTTP for services, PTY/tmux for CLI/TUI).
- **Observe:** what evidence can be captured — screenshots, terminal transcripts, response bodies, logs, exit codes, DB rows?
- **Isolate:** can two instances run side by side (ports, data dirs)? If not, the generated skill must refuse to double-drive a shared instance instead of corrupting the user's session.

If the checkout doesn't build or start, fix that first (or report it precisely) before generating. A skill written against a broken base teaches wrong steps.

### Generate the skill

Write `verify-<app>/SKILL.md` with frontmatter (`name: verify-<app>`, description naming the app, surface, and when to reach for it). Every section grounded in what the interview found — no placeholders:

- **Launch:** the exact start command and how to tell it's ready (a log line, a port answering, a prompt). Include teardown.
- **Doctor:** one read-only check — process up, right version/build, port owned by us, auth valid. An agent runs this first whenever anything looks off.
- **Drive:** the harness recipe with this repo's real selectors/commands/paths, not examples. Stable handles (ARIA labels, data attributes, prompt strings, routes) over coordinates and tab order.
- **Evidence:** what to capture and where it goes — `.artifacts/<task>/`, never committed (it gets uploaded or cited). Have the generated skill keep it out of git without a commit, in the common dir so it covers every worktree: `grep -qxF '.artifacts/' "$(git -C <wt> rev-parse --path-format=absolute --git-common-dir)/info/exclude" || echo '.artifacts/' >> "$(git -C <wt> rev-parse --path-format=absolute --git-common-dir)/info/exclude"` (`<wt>` = the checkout you're working in). Screenshots of a visible change are named `before.png` / `after.png` so the `before-and-after` skill can publish them as-is. Proof standards: exercise the real user path, not internal setters or test-only endpoints; capture the action AND the resulting state, not just the final screen; verify side effects (files written, rows inserted, messages sent) alongside what's visible.
- **Cleanup:** tear down what the run created — by the PID you started, never by process name. Evidence survives teardown.

### Checklist instead of a feature map

One file, `verify-<app>/CHECKLIST.md`: one entry per user-facing feature — how to reach it, how to drive it, the observable end state that proves it works. Start with the top 3–5 (from routes, commands, menus). Update when features land or change: fix or delete a stale line, never leave it to lie.

### Prove it before handing it over

Run the generated skill end to end once: launch, doctor, drive ONE checklist feature, capture evidence, clean up, confirm the evidence still exists at the named location. A verification skill that was never executed is a draft, not a deliverable. Clean up after failed iterations too, so broken attempts don't strand processes and ports.

Commit it as its own commit (`add verify-<app> skill`) and call it out in the PR body, so a reviewer can tell it apart from the feature change. When you're generating it in the middle of a ticket, it rides that ticket's PR; otherwise open a PR for it alone.

## Mode 2: run (the gate)

Before any push, PR, or "done" on a code change:

1. Run the verify skill's **doctor**, then drive the changed behavior through the real user path.
2. Capture evidence per the skill's Evidence section.
3. **Assertion discipline:** each check is a named assertion with a result — `passed`, `failed`, or `untested` + reason. Never skip silently. Looking at the actual state is what makes an assertion true; don't record `passed` from a timestamp or a self-report.
4. **Show before and after** — the "before" from [Before you touch code](#before-you-touch-code) next to the same check now.
5. **Capture hygiene:** confirm the server you're driving runs *your* code — `ss -ltnp 'sport = :<port>'` (or `lsof -i :<port>`) to find the listener's PID, then `ls -l /proc/<pid>/cwd` (macOS: `lsof -p <pid> -a -d cwd`) to see which checkout it runs from. No PID shown means another user's process or a container's published port — not yours; don't trust it. Multiple worktrees and agents share ports; "it answers" is not "it's mine".
6. State the evidence in your reply. If you can't produce a handle (URL, path, output), you're not done.

Verification complements typecheck/lint/tests; it never replaces them.

## Maintenance

No formal pass. Update the verify skill whenever: a run fails because the skill drifted, the app gains or changes a user-facing feature, or the harness recipe breaks. Drift fixes ride the same PR as the change that caused them. When the checklist and the app disagree, either fix the doc or report the regression — never paper over a real behavior change in docs.
