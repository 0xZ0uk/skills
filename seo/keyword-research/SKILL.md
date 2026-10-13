---
name: keyword-research
description: "Discover and prioritize keyword opportunities with OpenSEO: start from Search Console striking-distance queries, expand seeds, hydrate volume/KD/intent/CPC, check SERPs, and save/tag the chosen terms. Use when the user asks for keyword research, keyword ideas, what to target or write about, search demand for a topic, or local/market-specific keyword volumes."
---

# OpenSEO Keyword Research

## Goal

Turn seed topics into a prioritized keyword opportunity set using OpenSEO data. The output should help the user decide what to target, what to save, and what to research next.

## Setup

- **Load `seo-report` first.** Its `references/openseo-access.md` has the Executor call shape, account constants, and the project-context rules (read context first, fill missing fields inline, reuse research under 30 days old, research-log length cap). Delivery goes through it too, saving with `skill: "keyword-research"`; if it is unavailable, say so and stop before writing HTML.
- Inputs: `projectId` (`list_projects` if missing), one or more seeds (topics, products, pages, competitors, audience problems), optional market/location/language. Ask about the market only if it would materially change the metrics; otherwise use tool defaults.
- This skill needs `business_overview` and `current_goal` in project context.
- **Market quirks:** some locations sell only one language (Portugal is Portuguese-only), and sub-national volume needs a `locationName`. Read `references/markets.md` before researching any non-US market; country codes are in `references/location-codes.md`.

## Tools

| Tool | Use | Cost / limits |
|---|---|---|
| `get_search_console_performance` | First-party demand when connected. Pass `minPosition: 5, maxPosition: 20, minImpressions: 50` to get striking-distance rows (Google itself can't filter by position). | free |
| `get_keyword_metrics` | Hydrate up to 700 known keywords with volume, KD, intent, CPC, monthly trends in one call. | far cheaper than discovery |
| `research_keywords` | Discovery from 1–5 seeds; prefer 150 results unless exhaustive research is asked for. | ~54 credits per seed at 150 — for terms you can already name, use `get_keyword_metrics` instead |
| `get_ranked_keywords` | Exact ranking rows when a domain/page is in the brief. | |
| `get_serp_results` | SERPs for top or ambiguous candidates. | `depth` must be a positive multiple of 10 (`5` fails validation) |
| `search_local_businesses`, `get_local_serp_results`, `get_google_business_questions` | Local SEO when a business location or radius matters. | |
| `search_serp_locations` | Resolve city/region `locationName`s. | cities only, no country rows |
| `list_saved_keywords` / `save_keywords` | Avoid duplicating saved work / save chosen terms. | save only after explicit confirmation |

## Workflow

1. Normalize seeds into a small set of distinct research angles. If Search Console is connected, pull striking-distance queries first and hydrate them with `get_keyword_metrics` — that ranked, hydrated list is the fastest opportunity set; work it before broad discovery.
2. For local SEO, identify the business, location or service area, and local categories; research local volume with `locationName`, and use the local business/SERP tools for the key location/keyword set instead of relying on national data.
3. `research_keywords` for exploratory seeds, bulked where possible.
4. `get_keyword_metrics` to hydrate any fixed list before prioritizing.
5. `get_ranked_keywords` when the user gives a domain/page and wants opportunities from current rankings, near-misses, or competitor-owned terms.
6. Remove irrelevant, duplicate, branded-only, and off-intent terms.
7. Prioritize by practical opportunity, not volume alone: product/page fit, clear intent, reasonable difficulty, useful volume/CPC, a SERP the user can plausibly compete in, and for local SEO, local-pack proximity fit.
8. `get_serp_results` for high-potential or ambiguous terms when intent would change the recommendation; keep this check small.
9. Present a shortlist and a longer opportunity table.
10. Ask before saving. Suggest concise tags: `topic:<topic>`, `intent:<intent>`, `page:<slug>`.
11. Write back durable context: a sharpened `business_overview`/`current_goal`, competitors that kept appearing (`addCompetitors`), landing pages (`addKeyPages`), and a research-log line `Keyword research: <seeds/market>. Verdict: <conclusion>`.

## Output format

`h1`: the site or topic. If a report template applies (see `seo-report`), its sections and tone replace this list.

1. **The opportunity** — two or three bullets: the best theme, and why the site can win it now.
2. **Target these now** — table of keyword, intent, volume, KD, CPC, and the page to make, plus a bar chart of shortlist volumes.
3. **Why these** — one finding per keyword that needs justifying: the SERP or metric evidence, then the page to build.
4. **The longer opportunity list** — second table, same columns.
5. **Risks and caveats** — SERP intent that would change the recommendation, missing metrics written as `unknown`, close-variant volumes that are one bucket rather than several, demand-proxy markets.
6. **What to do next** — ordered list: keyword clustering, a content brief, or saving the chosen keywords.
7. **How this report was made** — the skill link line from `seo-report` pointing at `https://openseo.so/docs/skills/keyword-research` ("OpenSEO Keyword Research skill"), then which tools returned what.

## Guardrails

- Do not invent metrics. If OpenSEO does not return a value, write `unknown`.
- Do not call `save_keywords` without explicit confirmation.
- Prefer business-fit and intent-fit over the largest volume term.
