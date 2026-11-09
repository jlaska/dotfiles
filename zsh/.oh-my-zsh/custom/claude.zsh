# Claude Code: one shared ~/.claude/settings.json. The backend is chosen per invocation by
# environment variables, so nothing here is exported globally.
#   claude          subscription login (Max on Fedora, Enterprise on the work Mac)
#   claude-api      Anthropic API key billing
#   claude-litellm  homelab LiteLLM proxy (routes to Vertex AI, traces to Langfuse)
# See: https://code.claude.com/docs/en/env-vars

_claude_auth_vars=(ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL ANTHROPIC_CUSTOM_HEADERS
  ANTHROPIC_MODEL ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL
  CLAUDE_CODE_USE_VERTEX ANTHROPIC_VERTEX_PROJECT_ID CLOUD_ML_REGION)

# Print a secret from the OS keyring; fails quietly if the item is missing.
#   macOS: security add-generic-password -U -s <item> -a "$USER" -w "<value>"
#   Linux: secret-tool store --label=<item> service <item> account "$USER"   (prompts for the value)
_keyring_get() {
  local value
  if [[ $OSTYPE == darwin* ]]; then
    value=$(security find-generic-password -s "$1" -a "$USER" -w 2>/dev/null)
  else
    (( $+commands[secret-tool] )) && value=$(secret-tool lookup service "$1" 2>/dev/null)
  fi
  [[ -n $value ]] && print -r -- "$value"
}

_claude_secret() {
  _keyring_get "$1" || { print -u2 "claude: keyring item '$1' not found"; return 1; }
}

claude() {
  (unset $_claude_auth_vars; command claude "$@")
}

claude-api() {
  local key
  key=$(_claude_secret anthropic-api-key) || return
  (unset $_claude_auth_vars; ANTHROPIC_API_KEY=$key command claude "$@")
}

# Bearer token: kubectl get secret litellm-secrets -n litellm -o jsonpath='{.data.PROXY_MASTER_KEY}' | base64 -d
claude-litellm() {
  local token
  token=$(_claude_secret litellm-bearer-token) || return
  (unset $_claude_auth_vars
    ANTHROPIC_BASE_URL=https://litellm.internal.keener.us ANTHROPIC_AUTH_TOKEN=$token ANTHROPIC_MODEL=opus \
      command claude "$@")
}

# GitHub MCP server (claude/mcp.json): "Authorization": "Bearer ${GITHUB_COPILOT_BEARER_TOKEN}".
# The keyring item holds only the PAT (github_pat_…), without "Bearer ".
() { local t; t=$(_keyring_get github_copilot_bearer_token) && export GITHUB_COPILOT_BEARER_TOKEN=$t }
