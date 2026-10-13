# Deepening

How to deepen a cluster of shallow modules safely, given its dependencies. Assumes the vocabulary in [SKILL.md](SKILL.md): **module**, **interface**, **seam**, **adapter**.

## Dependency categories

When assessing a candidate for deepening, classify its dependencies. The category determines how the deepened module is tested across its seam.

### 1. In-process

Pure computation, in-memory state, no I/O. Always deepenable: merge the modules and test through the new interface directly. No adapter needed.

### 2. Local-substitutable

Dependencies that have local test stand-ins (PGLite for Postgres, in-memory filesystem). Deepenable if the stand-in exists. The deepened module is tested with the stand-in running in the test suite. The seam is internal; nothing extra at the module's external interface.

### 3. Remote but owned (adapters at the seam)

Your own services, reached over the network (microservices, other teams' endpoints). Put the seam where the call leaves the module. The deep module owns the logic; the transport is injected as an **adapter**. Production uses an HTTP/gRPC/queue adapter and tests use an in-memory one, which together justify the seam only because the remote call is a real external dependency (see the seam rule in [SKILL.md](SKILL.md)).

Recommendation shape: *"Define the interface at the seam, implement an HTTP adapter for production and an in-memory adapter for testing, so the logic sits in one deep module even though it's deployed across a network."*

### 4. True external (Mock)

Third-party services (Stripe, Twilio, etc.) you don't control. The deepened module takes the external dependency through an interface at the seam; tests provide a mock adapter.

## Seam discipline

The rules for when a seam is real, and for internal vs external seams, are in the Principles in [SKILL.md](SKILL.md). Apply them to each category above.

## Testing strategy: replace, don't layer

- Old unit tests on shallow modules become waste once tests at the deepened module's interface exist; delete them.
- Write new tests at the deepened module's interface. The **interface is the test surface**.
- Tests assert on observable outcomes through the interface, not internal state.
- Tests should survive internal refactors, since they describe behaviour, not implementation. If a test has to change when the implementation changes, it's testing past the interface.
