---
name: agent-router
description: "Pick the model tier for every agent, subagent, delegated task, or thread spawned from T3 Code: Pi + GLM-5.3-Flash (off the Claude quota) for mechanical work, Sonnet 5.5 for well-specified work, Opus 5.5 medium only for design judgment. Routes by how many unprompted decisions the task needs, escalates only after a tightened prompt fails, and de-escalates once a plan exists. Use in T3 Code before calling delegate_task, the Agent tool, t3_thread_launch, or create_threads, or when asked whether a task is heavy or light or which model should do it."
---

# Agent Router (T3 Code)

**Purpose:** stop every spawned agent from starting as Opus 5.5 medium. Spend the Claude quota only on reasoning-heavy work, and run cheap bulk work outside it entirely (Pi + GLM-5.3-Flash rides the OpenCode Go key, not the Max subscription).

Outside T3 Code (no `delegate_task` / `pi` provider), this skill doesn't apply.

## The three tiers

| Tier | Model | Burns | Role |
|---|---|---|---|
| C | Pi + GLM-5.3-Flash | OpenCode Go quota (Claude untouched) | Mechanical work: fully specified edits, search-and-report, command runs, summarization |
| B | Sonnet 5.5 | Claude quota (cheap) | One contained judgment, or large mechanical work: implementation to a spec, tests, refactors, contained reviews |
| A | Opus 5.5 (medium) | Claude quota (expensive) | Two or more design decisions: planning, architecture, debugging unknowns, ambiguity |

**Decision density is the axis, not importance.** A critical one-file hotfix with an obvious fix is B or C. A "low priority" investigation that must choose between three architectures is A.

## How to dispatch each tier

Model IDs come from `orchestrator_capabilities` (re-check if a dispatch is rejected — the catalog changes).

| Tier | Call |
|---|---|
| C | `delegate_task` with `target: {providerInstanceId: "pi", model: "opencode-go/glm-5.3-flash"}` |
| B | Agent tool with `model: "sonnet"`, or `delegate_task` with `target: {providerInstanceId: "claudeAgent", model: "claude-sonnet-5-5"}` |
| A | Agent tool with `model: "opus"`, or `delegate_task` with `target: {providerInstanceId: "claudeAgent", model: "claude-opus-5-5"}` |

Give every `delegate_task` a stable `clientRequestId`, keep the returned `taskId`, and track it with `task_status`. Use `t3_thread_launch` / `create_threads` only when the user explicitly wants separate top-level threads — they need the same model choice.

## Routing procedure (before every spawn)

1. **Count the decisions the task must make unprompted:**
   - 0 → mechanical (edit exactly what's specified, follow conventions, no choices)
   - 1 → contained judgment (pick between known options with a stated criterion)
   - 2+ → design judgment (ambiguous spec, tradeoffs, architecture, unknown failures)
2. **Pick the tier:**
   - 0 decisions → **C**, unless it touches more than ~10 files or a critical path another agent is changing concurrently → **B** (or several serial C passes under quota pressure — see reference).
   - 1 decision → **B**.
   - 2+ decisions, or the task asks "should we / which / why is this failing" → **A**.
3. **Never spawn without naming the model.** If you're about to dispatch on the default, stop and route.
4. **Cap every agent in its prompt:** files in scope, whether it may run commands, decisions it may make, and the report format (`result + files touched + deviations + questions`). Use the template in `references/escalation.md`.

## When an agent fails

A tier-C agent reporting "blocked, need decision on X" is a **success** — that's the route working. Read the report yourself, then:

1. **First failure → same tier, sharper prompt.** Most failures are under-specification, not an under-powered model.
2. **Second failure → next tier up**, with the failed agent's report attached.

Skip straight to step 2 only when the report shows the task itself needs a decision that wasn't in the prompt (hidden coupling), or the agent invented an architecture or reshaped the spec to make the problem easier — a better prompt can't fix those at the same tier. Losing the plot of a multi-part task means the task should be split, not escalated.

## De-escalation

- Once a Tier A pass produces a **plan or spec**, route each execution arm with the same decision test — most will be B or C.
- Never keep a Tier A agent alive past its last hard decision. Keep the plan, spawn cheap doers.

## Prompting per tier

- **Pi / GLM-5.3-Flash:** one task, explicit file paths, explicit "do NOT" list (no new deps, no renames, no format passes). Your prompt is its whole spec: if a careful junior developer couldn't do it from the prompt alone, it isn't Tier C.
- **Sonnet 5.5:** the spec plus acceptance criteria; parallel fan-out is fine since each arm is contained. Review its diff before accepting.
- **Opus 5.5 (medium):** looser prompt; ask for the plan first and a checkpoint before executing. Medium is deliberate.

## Anti-patterns

- Opus for everything "because it's the default".
- Escalating on the first failure.
- Routing by deadline pressure or task drama instead of decision count.

## Reference

`references/escalation.md` — worked routing examples, edge cases (scoping with Opus first, task growth mid-flight, unclear decision count, quota pressure), and the per-dispatch prompt template.
