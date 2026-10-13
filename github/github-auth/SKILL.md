---
name: github-auth
description: "Set up or repair GitHub authentication for git and the gh CLI: detect what's already configured, log in headlessly via the OAuth device flow, work around gh hanging on keyring-less Linux, and fall back to a GITHUB_TOKEN for curl. Use when git push/clone asks for a password or fails with auth errors, when gh is not logged in, or before any GitHub work on a new machine or container."
version: 1.2.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitHub, Authentication, Git, gh-cli, SSH, Setup]
    related_skills: [github-gh-pitfalls, github-issue-to-pr, safe-git-sync]
---

# GitHub Authentication

## 1. Detect what already works

```bash
source <this-skill-dir>/scripts/gh-env.sh
```

Sets and prints `GH_AUTH_METHOD` (`gh` | `curl` | `none`), `GITHUB_TOKEN`, `GH_USER`, and — inside a repo with a GitHub remote — `GH_OWNER`, `GH_REPO`, `GH_OWNER_REPO`. Token sources, first non-empty wins: `$GITHUB_TOKEN` → `GITHUB_TOKEN=` in `$HERMES_HOME/.env` → `~/.git-credentials` (parsed by `scripts/git-credential-token.py`) → `gh auth token` when gh is logged in.

- `gh` → use it for everything; done.
- `curl` → API calls work with `Authorization: token $GITHUB_TOKEN`; to get `gh` too, log it in with that token (end of section 2).
- `none` → section 2 if `gh` is installed, otherwise section 4.

## 2. Log gh in without a TTY — OAuth device flow (proven)

Use this from agent sessions, headless boxes, or whenever `gh auth login`'s interactive prompts are impractical. It uses gh's public OAuth client id; the user only enters a code at github.com/login/device. `gh auth login --with-token` requires at least `repo` and `read:org`; `gist` matches gh's own default login. Append `,workflow` only if you'll push workflow files.

```bash
# 1. Request a device code
RESP=$(curl -s -X POST -H "Accept: application/json" \
  -d "client_id=178c6fc778ccc68e1d6a&scope=repo,read:org,gist" \
  https://github.com/login/device/code)
case "$RESP" in *'"device_code"'*) ;; *) echo "DEVICE_CODE_REQUEST_FAILED: $RESP" ;; esac   # stop here if this prints
DEVICE_CODE=$(echo "$RESP" | sed 's/.*"device_code":"\([^"]*\)".*/\1/')
USER_CODE=$(echo "$RESP" | sed 's/.*"user_code":"\([^"]*\)".*/\1/')
INTERVAL=$(echo "$RESP" | sed 's/.*"interval":\([0-9]*\).*/\1/'); INTERVAL=${INTERVAL:-5}
echo "Tell the user: go to https://github.com/login/device and enter code: $USER_CODE"

# 2. Poll for the token (respect interval; +5s on slow_down; ~15 min expiry).
#    Show the user the code first. Run step 2 in the same shell session as
#    any fallback, so $TOKEN survives.
while true; do
  sleep "$INTERVAL"
  POLL=$(curl -s -X POST -H "Accept: application/json" \
    -d "client_id=178c6fc778ccc68e1d6a&device_code=${DEVICE_CODE}&grant_type=urn:ietf:params:oauth:grant-type:device_code" \
    https://github.com/login/oauth/access_token)
  case "$POLL" in
    *access_token*)
      # Keep the token in a variable (never echo it) so the section-3
      # fallback can use it if gh hangs on a keyring-less box.
      TOKEN=$(printf '%s' "$POLL" | sed 's/.*"access_token":"\([^"]*\)".*/\1/')
      if printf '%s' "$TOKEN" | timeout 20 gh auth login --with-token; then
        gh auth setup-git && gh auth status && echo "LOGIN_COMPLETE"
      else
        echo "WITH_TOKEN_HUNG_OR_FAILED — run the section-3 fallback in this same shell (\$TOKEN is set)"
      fi
      break ;;
    *authorization_pending*) ;;
    *slow_down*) INTERVAL=$((INTERVAL + 5)) ;;
    *expired_token*) echo "CODE_EXPIRED — restart the flow"; break ;;
    *access_denied*) echo "USER_DENIED"; break ;;
    *) echo "UNEXPECTED: $POLL"; break ;;
  esac
done
```

With a token already in hand: `printf '%s' "$TOKEN" | timeout 20 gh auth login --with-token && gh auth setup-git` (section 3 if it hangs).

**Interactive `gh auth login` from an agent on Windows:** answer prompts with a real Enter/submit action, never a bare `\n` written to the pty — ConPTY treats Enter as `\r`, so gh's "Press Enter to open the browser" line read never returns and the login hangs. The browser may also not open on the user's desktop from a background session; fall back to the device flow. Winget installs gh at `/c/Program Files/GitHub CLI` — add it to `PATH` in the same shell.

## 3. Pitfall: `gh auth login --with-token` hangs on headless Linux

On keyring-less boxes (VPS, containers, no dbus session) gh's credential storage can block forever on a secret-service keyring — even with `--insecure-storage`, and with no output. If it doesn't return within ~20 s, skip gh's login and write the credential store directly:

```bash
# $TOKEN = the access token from section 2 or the user (never echo it)
mkdir -p ~/.config/gh
LOGIN=$(curl -s -H "Authorization: token $TOKEN" https://api.github.com/user \
  | sed 's/.*"login": *"\([^"]*\)".*/\1/')
printf 'github.com:\n    users:\n        %s:\n            oauth_token: %s\n    git_protocol: https\n    oauth_token: %s\n    user: %s\n' \
  "$LOGIN" "$TOKEN" "$TOKEN" "$LOGIN" > ~/.config/gh/hosts.yml
chmod 600 ~/.config/gh/hosts.yml
gh auth status          # reads hosts.yml directly — no keyring
gh auth setup-git       # wires the git credential helper (does not hang)
```

Proven on a headless x86_64 VPS (gh 2.97.0, Aug 2026) after `--with-token` hung twice.

## 4. git only (no gh)

- **HTTPS + token:** have the user create a fine-grained PAT (or classic with `repo`, plus `workflow` / `read:org` as needed). `git config --global credential.helper store` (plaintext `~/.git-credentials`) or `'cache --timeout=28800'` (memory only), then trigger one auth (`git ls-remote https://github.com/<owner>/<repo>.git`) and enter the token as the password. Avoid embedding the token in remote URLs — it lands in `.git/config` and process lists.
- **SSH:** reuse an existing `~/.ssh/id_*.pub` or `ssh-keygen -t ed25519 -C <email>`; the user adds the public key at github.com/settings/keys; verify with `ssh -T git@github.com`.
- Commits also need `user.name` / `user.email` set.

## Troubleshooting

| Problem | Fix |
|---|---|
| `git push` asks for a password | GitHub dropped password auth — use a token as the password, or SSH |
| `remote: Permission to X denied` | Token lacks scope/repo access — regenerate |
| `fatal: Authentication failed` | Stale cached credential — `git credential reject`, then re-auth |
| `ssh: connect to host github.com port 22: Connection refused` | `~/.ssh/config`: `Host github.com` → `Hostname ssh.github.com`, `Port 443` |
| Credentials not persisting | `git config --global credential.helper` must be `store` or `cache` |
| Multiple GitHub accounts | Per-host SSH aliases in `~/.ssh/config`, or per-repo credential URLs |
| `gh: command not found`, no sudo | Use section 4 |
