# To update the token in the future, just run:
# $ security add-generic-password -U -s "jira-api-token" -a "$USER" -w "<new-token>"
export JIRA_API_TOKEN="$(security find-generic-password -s "jira-api-token" -a "$USER" -w 2>/dev/null)"
