# Vertex Setup
# To update: security add-generic-password -U -s "anthropic-vertex-project-id" -a "$USER" -w "<new-value>"
export ANTHROPIC_VERTEX_PROJECT_ID="$(security find-generic-password -s "anthropic-vertex-project-id" -a "$USER" -w 2>/dev/null)"
export ANTHROPIC_MODEL="opusplan"
# export ANTHROPIC_MODEL"opus[1m]"
export ANTHROPIC_DEFAULT_OPUS_MODEL="claude-opus-4-6[1m]"
export ANTHROPIC_DEFAULT_SONNET_MODEL="claude-sonnet-4-6[1m]"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="claude-sonnet-4-5"
export CLAUDE_CODE_USE_VERTEX=1
export CLOUD_ML_REGION=global
