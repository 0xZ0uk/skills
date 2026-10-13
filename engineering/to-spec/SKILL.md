---
name: to-spec
description: "Turn the current conversation into a spec and publish it as a GitHub issue."
disable-model-invocation: true
---

Run only when the user explicitly asked for this (e.g. typed `/to-spec`); otherwise do nothing.

This skill takes the current conversation context and codebase understanding and produces a spec, published as a GitHub issue in the current repo via the `gh` CLI. Do NOT interview the user about the subject; just synthesize what you already know. The one allowed check is confirming the test seams (step 2).

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary vocabulary throughout the spec, and respect any ADRs in the area you're touching.

2. Sketch out the seams at which you're going to test the feature. Existing seams should be preferred to new ones. Use the highest seam possible. If new seams are needed, propose them at the highest point you can. The fewer seams across the codebase, the better - the ideal number is one.

Ask the user once to confirm the seams and the list of modules to build or modify. This is a single confirmation, not an interview; do not ask anything else.

3. Write the spec using the template below, then publish it as a GitHub issue. Apply the `ready-for-agent` label - no need for additional triage.

   `gh issue create --label X` fails if the label doesn't exist, so ensure it first:

   ```bash
   gh label list --search ready-for-agent --json name --jq '.[].name' | grep -qx ready-for-agent \
     || gh label create ready-for-agent --color 0E8A16 --description "Ready for an agent to pick up"
   ```

   Write the spec to a temp file, then create the issue and report the URL it prints:

   ```bash
   gh issue create --title "<spec title>" --label ready-for-agent --body-file "$tmpfile"
   ```

<spec-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts, not a working demo, just the important bits.

## Testing Decisions

A list of testing decisions that were made. Include:

- Which seams will be tested, and what each one catches (the behaviour or regression it guards)
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Out of Scope

A description of the things that are out of scope for this spec.

## Further Notes

Any further notes about the feature.

</spec-template>
