#!/usr/bin/env bash
# GitHub environment detection helper.
#
# Usage:
#   source <github-auth skill dir>/scripts/gh-env.sh
#
# After sourcing, these variables are set:
#   GH_AUTH_METHOD  - "gh", "curl", or "none"
#   GITHUB_TOKEN    - personal access token (set if method is "curl")
#   GH_USER         - GitHub username
#   GH_OWNER        - repo owner  (only if inside a git repo with a github remote)
#   GH_REPO         - repo name   (only if inside a git repo with a github remote)
#   GH_OWNER_REPO   - owner/repo  (only if inside a git repo with a github remote)

# --- Auth detection ---

# Works when sourced from bash (BASH_SOURCE) or zsh (%x prompt expansion).
if [ -n "${BASH_SOURCE[0]:-}" ]; then _gh_env_src="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then _gh_env_src="${(%):-%x}"
else _gh_env_src="$0"; fi
_gh_env_dir="$(cd "$(dirname "$_gh_env_src")" && pwd)"

GH_AUTH_METHOD="none"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GH_USER=""

# Token sources, first non-empty wins: $GITHUB_TOKEN, $HERMES_HOME/.env, ~/.git-credentials
_hermes_env="${HERMES_HOME:-$HOME/.hermes}/.env"
if [ -z "$GITHUB_TOKEN" ] && [ -f "$_hermes_env" ]; then
    GITHUB_TOKEN=$(grep "^GITHUB_TOKEN=" "$_hermes_env" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\n\r"'"'"'')
fi
if [ -z "$GITHUB_TOKEN" ] && [ -f "$HOME/.git-credentials" ]; then
    GITHUB_TOKEN=$(python3 "$_gh_env_dir/git-credential-token.py" 2>/dev/null)
fi

if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    GH_AUTH_METHOD="gh"
    GH_USER=$(gh api user --jq '.login' 2>/dev/null)
    # gh is authenticated: expose its token for curl calls if none was found
    [ -z "$GITHUB_TOKEN" ] && GITHUB_TOKEN=$(gh auth token 2>/dev/null)
elif [ -n "$GITHUB_TOKEN" ]; then
    GH_AUTH_METHOD="curl"
fi

# Resolve username for curl method
if [ "$GH_AUTH_METHOD" = "curl" ] && [ -z "$GH_USER" ]; then
    GH_USER=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        https://api.github.com/user 2>/dev/null \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('login',''))" 2>/dev/null)
fi

# --- Repo detection (if inside a git repo with a GitHub remote) ---

GH_OWNER=""
GH_REPO=""
GH_OWNER_REPO=""

_remote_url=$(git remote get-url origin 2>/dev/null)
if [ -n "$_remote_url" ] && echo "$_remote_url" | grep -q "github.com"; then
    GH_OWNER_REPO=$(echo "$_remote_url" | sed -E 's|.*github\.com[:/]||; s|\.git$||')
    GH_OWNER=$(echo "$GH_OWNER_REPO" | cut -d/ -f1)
    GH_REPO=$(echo "$GH_OWNER_REPO" | cut -d/ -f2)
fi
unset _remote_url _gh_env_dir _gh_env_src _hermes_env

# --- Summary ---

echo "GitHub Auth: $GH_AUTH_METHOD"
[ -n "$GH_USER" ]       && echo "User: $GH_USER"
[ -n "$GH_OWNER_REPO" ] && echo "Repo: $GH_OWNER_REPO"
[ "$GH_AUTH_METHOD" = "none" ] && echo "⚠ Not authenticated — see github-auth skill"

export GH_AUTH_METHOD GITHUB_TOKEN GH_USER GH_OWNER GH_REPO GH_OWNER_REPO
