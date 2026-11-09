# Claude Code: one shared ~/.claude/settings.json. The backend is chosen per invocation by
# environment variables, so nothing here is exported globally.
#   claude          subscription login (Max on Fedora, Enterprise on the work Mac)
#   claude-api      Anthropic API key billing
#   claude-litellm  homelab LiteLLM proxy (routes to Vertex AI, traces to Langfuse)
# See: https://code.claude.com/docs/en/env-vars

_claude_auth_vars=(ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL ANTHROPIC_CUSTOM_HEADERS
  ANTHROPIC_MODEL ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL
  CLAUDE_CODE_USE_VERTEX ANTHROPIC_VERTEX_PROJECT_ID CLOUD_ML_REGION)

# Read a secret from the OS keyring.
#   macOS: security add-generic-password -U -s <item> -a "$USER" -w "<value>"
#   Linux: secret-tool store --label=<item> service <item>
_claude_secret() {
  local value
  if [[ $OSTYPE == darwin* ]]; then
    value=$(security find-generic-password -s "$1" -a "$USER" -w 2>/dev/null)
  else
    value=$(secret-tool lookup service "$1" 2>/dev/null)
  fi
  [[ -n $value ]] || { print -u2 "claude: keyring item '$1' not found"; return 1; }
  print -r -- "$value"
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
