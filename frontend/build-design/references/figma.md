# Reading a Figma file

How **Read the design at its source** gets values out of Figma. Tool names here are the official Figma MCP server's. Where a Figma skill ships with the server, load it before the first call and follow its calling rules. This file covers only what this skill needs from the answers.

## From link to node

A Figma URL carries the file key after `/design/` or `/file/` and the node in `node-id`. On a branch URL, `/design/<fileKey>/branch/<branchKey>/`, pass the branch key as the file key. The URL writes the node as `1-2`, and the tools take it as `1:2`. A link with no `node-id` points at no frame in particular, so list the frames with `get_metadata` and confirm which ones ship before reading any of them.

## The calls

| Tool | Gives you | Use it for |
| --- | --- | --- |
| `get_design_context` | Reference code, exact values, bound variables, component instances, asset downloads and optionally a screenshot | Every frame in scope, one call each |
| `get_screenshot` | A render of the node | The comparison target, when the design context returned none |
| `get_variable_defs` | The variables the node uses, with their names and values | Mapping design variables onto project tokens |
| `get_metadata` | The layer tree with ids and sizes, no styling | Large pages, to find which child nodes to read |

Request the screenshot in the same `get_design_context` call. The code it returns is a reference, by default React with Tailwind and raw values. Translate it through **Map the design onto the project** and never paste it.

A design context flagged as sparse is a summary, not values. Read the visible children it names, in parallel, and build from those answers.

## What to trust

- **Variable names over raw values.** A fill bound to `gray/600` maps to the project's `gray-600` even where the hex drifted. A raw hex with no variable goes through the mapping table.
- **Code Connect over name matching, when present.** Code Connect needs an Organization or Enterprise plan, so most files have none. A node with a Code Connect mapping names the exact component and props. Use that component unless it cannot express the design, and report the case where it cannot.
- **Auto layout over absolute positions.** Gap and padding on an auto layout frame are the spacing intent. Absolute x and y on a free-floating layer are where someone dropped it.
- **Downloaded assets over Figma URLs.** Asset URLs from the server expire. Save each asset into the project the way the design context says, and leave no Figma URL in code.

The screenshot is the target you compare against. It is never an asset in the build.

## Without a Figma MCP server

The REST API reads the same file with a personal access token that has the `file_content:read` scope. Take it from an environment variable the user set, here `FIGMA_TOKEN`. Never echo the token, write it into a file or commit it. With no token, ask the user to export each frame in scope as a PNG at 2× and build from the image instead.

```bash
cd "$(mktemp -d)"   # keep API output out of the project
# FILE_KEY and NODE_IDS come from the link; ids are comma-separated, 1:2 form
curl -sS -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/$FILE_KEY/nodes?ids=$NODE_IDS" -o nodes.json
curl -sS -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/images/$FILE_KEY?ids=$NODE_IDS&format=png&scale=2" -o renders.json
```

A link with no `node-id` takes `/v1/files/$FILE_KEY?depth=2` first, which lists pages and their top-level frames. `nodes.json` is the raw node tree: fills, strokes, effects, `layoutMode`, `itemSpacing`, padding and `boundVariables` ids, with no generated code. The variables endpoint needs an Enterprise plan, so a bound variable often arrives as an id with no name. Map it by value instead. `renders.json` maps each node id to a PNG URL that expires after 30 days. Download each render into the same directory as the comparison target.
