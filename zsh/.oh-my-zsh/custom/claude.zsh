# Vertex credentials (used by work tooling and LiteLLM proxy backend)
# To update: security add-generic-password -U -s "anthropic-vertex-project-id" -a "$USER" -w "<new-value>"
export ANTHROPIC_VERTEX_PROJECT_ID="$(security find-generic-password -s "anthropic-vertex-project-id" -a "$USER" -w 2>/dev/null)"
export CLOUD_ML_REGION=global
# Direct Vertex disabled — Claude Code routes through LiteLLM proxy (which uses Vertex internally)
# Re-enable to bypass proxy: export CLAUDE_CODE_USE_VERTEX=1
# export CLAUDE_CODE_USE_VERTEX=1

# LiteLLM proxy — routes to Vertex AI via homelab cluster, traces to Langfuse
# To store master key: security add-generic-password -U -s "litellm-master-key" -a "$USER" -w "<value>"
# To get key: kubectl get secret litellm-secrets -n litellm -o jsonpath='{.data.PROXY_MASTER_KEY}' | base64 -d
export ANTHROPIC_BASE_URL="https://litellm.internal.keener.us"
export ANTHROPIC_API_KEY="$(security find-generic-password -s "litellm-master-key" -a "$USER" -w 2>/dev/null)"
