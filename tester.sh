#!/bin/bash
echo "Configuring Postfix..."
POSTFIX_CONFIG="/etc/postfix/main.cf"

declare -A POSTFIX_SETTINGS=(
    ["smtpd_client_connection_count_limit"]="10"
    ["smtpd_client_connection_rate_limit"]="60"
    ["smtpd_error_sleep_time"]="5s"
    ["smtpd_soft_error_limit"]="10"
    ["smtpd_hard_error_limit"]="20"
    ["message_size_limit"]="10485760"
    ["smtpd_recipient_restrictions"]="reject_unauth_destination"
)

for key in "${!POSTFIX_SETTINGS[@]}"; do
    if ! grep -q "^$key" "$POSTFIX_CONFIG"; then
        echo "$key = ${POSTFIX_SETTINGS[$key]}" >> "$POSTFIX_CONFIG"
    fi
done

sudo systemctl restart postfix
