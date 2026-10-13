# OpenSEO access through Executor

OpenSEO is **not** a direct MCP server here. Do not run `hermes mcp add`, edit `mcp_servers`, or check `hermes mcp list` for it. Every OpenSEO call runs inside the Executor MCP via `mcp__executor__execute`.

```typescript
const A = 'acc_0b91f591-6feb-4f77-b31b-be43e921b826';                       // accountId
const B = 'openseo-so.profiles.ins_140ec4c7-3799-4b0d-9802-0d565f87ff7c.';  // tool prefix
const r = await tools[B + 'whoami']({ accountId: A, input: {} });
const credits = r.content[0].text;
```

- Call `whoami` to confirm credits before spending. If it fails, the problem is Executor — never tell the user to "connect OpenSEO".
- **Executor does not persist variables between `execute` programs.** Parse results (e.g. SERP `rank | domain | title | url` lines) inside the same call that fetched them; a second call re-pays for paid lookups.
- `projectId`: `list_projects`; if no project matches the domain, `create_project`.

## Project context (free, shared with the app and other agents)

- `get_project_context` first, every skill. Ground the work in the saved business, goal, markets, competitors and key pages.
- If a field the skill needs is empty, fill just that field inline (ask the user, or infer from the site and confirm), write it back with `update_project_context`, and continue. Never front-load a full setup interview; mention at the end which other context fields are still empty.
- Check the research log before spending credits; reuse the same research if it ran within 30 days, and say so.
- On finish, write back durable facts and append `{ appendResearchLog: { summary: "<Skill>: <subject>. Verdict: <conclusion>" } }`.

### Write limits (verified 2026-10-03)

`appendResearchLog` summaries are length-capped. A ~1,400-character entry is rejected with a confusing `anyOf` / `Failed the "false" constraint` error that reads like a schema bug; ~730 characters passes. Keep entries under about 1,000 characters and put detail in the report.
