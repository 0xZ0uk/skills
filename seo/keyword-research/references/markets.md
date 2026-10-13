# Market and language constraints (verified 2026-10-03)

## Portugal (location 2620) sells Portuguese only

English seeds return `Language 'en' is not available for this location. Available: pt.` on `research_keywords`, `find_serp_competitors` AND `get_keyword_metrics` — all three. Failed seeds cost no credits.

- For a Portugal-based business targeting English speakers, hydrate the same keyword list against the buyer's home market (`2826` UK, `2840` US, `2372` Ireland — see `location-codes.md`) and label the figures as a demand proxy: they measure where the buyers search from, not where the property is.
- Expect international long-tail to look tiny per country (UK returned 10/mo for "property management Portugal" and 0 for "property management Silver Coast"). Low per-country volume on an international service is a data artifact, not proof of no demand — say so instead of reporting "no demand" flatly.
- Pull the local-language cluster too (`locationCode: 2620, languageCode: 'pt'`); for Portugal that is where measurable service demand actually sits. Enter Portuguese terms with their accents — accents affect matching and volume.

## Sub-national demand

For one city, county, or region, call `search_serp_locations` and pass the returned `locationName` on the seed: volume, CPC, and competition become local; keyword ideas, KD, and intent stay national. Pass the same `locationName` to `get_serp_results` for the local SERP.

`search_serp_locations` takes `{ countryCode: 'GB', query: 'London' }` and returns rows like `London,England,United Kingdom (City, 1006886)`. It lists cities and municipalities only, never a country-level row — country codes are in `location-codes.md`.
