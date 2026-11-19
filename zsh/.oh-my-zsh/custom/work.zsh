# To update the token in the future, just run:
# $ security add-generic-password -U -s "{{ KEY }}" -a "$USER" -w "{{ new_token }}"
export LINEAR_API_KEY="$(security find-generic-password -s linear_app_api_key -a "$USER" -w 2>/dev/null)"
