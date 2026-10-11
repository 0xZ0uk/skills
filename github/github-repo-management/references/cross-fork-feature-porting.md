# Cross-Fork Feature Porting

Pattern for porting a feature from an upstream repository to a diverged fork, when you need to track both the canonical upstream and the intermediate fork.

## Remote Setup

After forking the repo to your account, set up three remotes:

```bash
# Origin = your fork (where you push changes)
git remote rename origin origin-forked
git remote add origin git@github.com:YOUR_USER/repo.git

# The fork you cloned from (if different from upstream canonical)
git remote add upstream-fork https://github.com/OTHER_USER/repo.git

# The original canonical upstream (where the feature lives)
git remote add upstream-original https://github.com/CANONICAL_OWNER/repo.git
```

Fetch all remotes:
```bash
git fetch --all
```

Verify:
```bash
git remote -v
# origin          git@github.com:YOUR_USER/repo.git (fetch/push)
# upstream-fork   https://github.com/OTHER_USER/repo.git (fetch/push)
# upstream-original https://github.com/CANONICAL_OWNER/repo.git (fetch/push)
```

## Porting Workflow

1. **Create a feature branch** off the fork's main:
   ```bash
   git checkout -b feat/my-feature-port
   ```

2. **Read upstream implementation files** from the canonical repo:
   ```bash
   git show upstream-original/main:path/to/file.ts
   ```

3. **Read the fork's equivalent files** to understand API differences:
   ```bash
   cat server/src/services/router.ts  # fork's version
   ```

4. **Identify adapter points** — places where the fork's APIs differ from upstream:
   - Package names (e.g., `@freellmapi/shared` → `@api-gateway/shared`)
   - Module paths (e.g., `../lib/foo` → different structure)
   - Router function signatures (RouteResult fields, options objects)
   - Missing exports/constants that need to be added
   - Error handling patterns (inlined vs factored-out)
   - Provider resolution functions

5. **Extract shared dependencies** that would cause circular imports if left in-place:
   - Factor shared functions (e.g., `logRequest`, error classifiers) into a lib module
   - Update all import sites simultaneously

6. **Create new files** adapted to the fork's API:
   - Core feature file (e.g., `fusion.ts`)
   - New lib modules (e.g., `error-classify.ts`, `request-log.ts`)

7. **Add missing constants/exports** to the fork's existing modules:
   - New exports in router (e.g., `routePinnedModel`, `FusionCandidate`)
   - New constants in ratelimit (e.g., `MODEL_FORBIDDEN_COOLDOWN_MS`)

8. **Modify existing files** to wire up the feature:
   - Route handlers to intercept the new feature
   - Request schemas to accept new fields
   - Model listings to include virtual models

9. **Build and test**:
   ```bash
   cd server && npx tsc --noEmit  # check compilation
   ```

## Pitfalls

### Source-Level Redaction (`***` pattern)

Some repos display `***` and `getUni...ey()` in their source code. This is **display-only redaction** — the actual git source has real variable names. Verify with `hexdump -C` or `sed` when in doubt:

```bash
git show HEAD:path/to/file.ts | sed -n '100p' | hexdump -C
# Will show actual variable name (e.g., "decryptedKey") not "***"
```

### Database Re-initialization

Running a script that calls `initDb()` or importing the database module directly will **wipe existing data** (API keys, custom providers, settings). The models survive (they're baked into migrations), but operational data is lost. Always use the running server's API to read/write configuration:

```bash
# DO read via API
curl -s http://localhost:PORT/api/settings/api-key

# DON'T run scripts that call initDb() on a production DB
```

### Diverged Router Signatures

A fork may have evolved its router API significantly (added fields like `release`, `maxOutputTokens`, parallel-request gating, sticky-session support). When porting a feature that calls `routePinnedModel` or `routeRequest`, verify:

- Does the fork have `pinMode` in `RouteOptions`? (Some forks use it, others have a separate `selectKeyForModel`)
- Does `RouteResult` include `release`? (Fusion panel slots need to release slots)
- Are `PAYMENT_REQUIRED_COOLDOWN_MS` and `MODEL_FORBIDDEN_COOLDOWN_MS` both defined?
