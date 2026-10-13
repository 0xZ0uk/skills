# Proving a fix where CI proves it

A green local run is not evidence the tier passes: reproduce each claim in the environment CI uses. Three failures this class hides, all seen in one slice of a turborepo monorepo (adapt the specifics to the repo's build tool):

- **Cache masking.** A result that is cached is never recomputed, so a change to a file the config reads (a ledger, a policy JSON) can pass a tier that would have refused to load it. If config-time validation is part of the claim, declare that file a turbo global dependency and watch the tier go red on purpose.
- **Inherited runner environment.** A test that spawns a nested runner must strip runner-only variables (e.g. `GITHUB_STEP_SUMMARY`) *after* spreading `process.env`, or the nested run writes its report to the job summary instead of the stdout the test asserts on. Also: prove env-var behaviour by faking the CI variables locally, not by reasoning about them.
- **Ordering the build graph does not guarantee.** A package whose own tests or fixtures import it by name needs its own `build` in `dependsOn`, not just `^build` — a warm tree hides that on the developer's machine.

Prefer a proof that lives in the repo (fixture specs + a test that checks exit codes, counts and output) over a throwaway commit, and use the throwaway commit only for what CI alone can show, reverting it right after.
