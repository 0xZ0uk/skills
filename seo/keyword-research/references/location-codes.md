# Verified DataForSEO location codes

Source of truth: DataForSEO's published list (refreshed monthly):
https://cdn.dataforseo.com/v3/locations/locations_serp_google_YYYY_MM_DD.csv
Columns: location_code, location_name, location_code_parent, country_iso_code, location_type.
For country-level codes, filter location_type == 'Country'.

## Country codes (verified 2026-10-03)

| Country | Code | Language |
|---|---|---|
| Portugal | 2620 | pt |
| United Kingdom | 2826 | en |
| Ireland | 2372 | en |
| United States | 2840 | en |
| Canada | 2124 | en |
| Germany | 2276 | de |
| Austria | 2040 | de |
| Switzerland | 2756 | de / fr |
| France | 2250 | fr |
| Luxembourg | 2442 | fr |
| Netherlands | 2528 | nl |
| Belgium | 2056 | nl / fr |
| Sweden | 2752 | sv |
| Norway | 2578 | no |
| Denmark | 2208 | da |
| Italy | 2380 | it |
| Spain | 2724 | es |

## Silver Coast city codes (Portugal)

| City | Code |
|---|---|
| Obidos | 9248594 |
| Caldas da Rainha | 9211161 |
| Peniche | 9238840 |
| Nazare | 9209895 |
| Leiria | 1011731 |
| Ericeira | 9210364 |
| Figueira da Foz | 1011722 |
| Marinha Grande | 1011732 |
| Alcobaca | 9238503 |
| Aveiro | 1011706 |
| Sao Martinho do Porto | 9251539 |
| Lourinha | 9258368 |
| Coimbra | 1011721 |
| Espinho | 1011707 |
| Pataias | 9250319 |

## Verifying a code empirically (cheap, about 5 credits)

Before trusting a country code, pull a SERP for a query whose top domains reveal the country, then check the TLDs:

```typescript
// A and B as defined in seo-report/references/openseo-access.md; depth 10 is enough to read TLDs
const r = await tools[B + 'get_serp_results']({
  accountId: A,
  input: { projectId: PID, queries: [{ keyword: 'car insurance', locationCode: 2826, languageCode: 'en' }], depth: 10 },
});
```

Observed results (2026-10-03):

- 2826 + en returned aviva.co.uk, gocompare.com, lv.com -> United Kingdom
- 2276 + de returned jb.de, papperts.de -> Germany
- 2528 + nl returned rabobank.nl -> Netherlands
- 2372 + en returned hastings.ie, its4women.ie -> Ireland
- 2250 + fr returned direct-assurance.fr, maaf.fr -> France
- 2056 + nl returned spaargids.be, kbc.be -> Belgium
- 2752 + sv returned protectorforsakring.se, if.se -> Sweden
- 2208 + da returned forsikringidanmark.dk, runa.dk -> Denmark

Rows on google.com/searchviewer are Google's own ad and related blocks; filter them before reading the country signal.
