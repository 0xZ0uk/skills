# OmniRoute (verified 2026-09-14)

- OmniRoute binds loopback by default since #12568, so it 502s behind Traefik until you set `HOSTNAME=0.0.0.0` (SKILL.md, Traefik ingress).
- Behind TLS termination also set `AUTH_COOKIE_SECURE=true`, else the session cookie isn't marked Secure and dashboard auth misbehaves; and prefer explicit `NEXT_PUBLIC_BASE_URL` over `OMNIROUTE_TRUST_PROXY` (forwarded headers come from Traefik, not a token-stamped loopback peer, so trust mode won't match).
