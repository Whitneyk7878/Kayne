#!/bin/bash


# -------------------------------------
# 2. Enable Postfix Rate Limiting
# -------------------------------------

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

systemctl restart postfix
echo "Postfix security applied."

# -------------------------------------
# 3. Secure Dovecot (IMAP/POP3)
# -------------------------------------

echo "Configuring Dovecot..."
DOVECOT_CONFIG="/etc/dovecot/dovecot.conf"

if ! grep -q "process_limit" "$DOVECOT_CONFIG"; then
    echo "service imap-login { process_limit = 10; service_count = 1; }" >> "$DOVECOT_CONFIG"
fi

if ! grep -q "quota_rule" "$DOVECOT_CONFIG"; then
    echo "plugin { quota = maildir:User quota; quota_rule = *:storage=1G; }" >> "$DOVECOT_CONFIG"
fi

systemctl restart dovecot
echo "Dovecot security settings applied."

# -------------------------------------
# 4. Protect Roundcube (Webmail)
# -------------------------------------

echo "Hardening Roundcube..."
ROUND_CUBE_CONFIG="/etc/roundcubemail/config.inc.php"

declare -A ROUNDCUBE_SETTINGS=(
    ["session_lifetime"]="10"
    ["max_login_attempts"]="5"
    ["login_rate_limit"]="'1r/10s'"
    ["max_message_size"]="'10M'"
)

for key in "${!ROUNDCUBE_SETTINGS[@]}"; do
    if ! grep -q "\$config\['$key'\]" "$ROUND_CUBE_CONFIG"; then
        echo "\$config['$key'] = ${ROUNDCUBE_SETTINGS[$key]};" >> "$ROUND_CUBE_CONFIG"
    fi
done

systemctl restart httpd
echo "Roundcube hardened."


# -------------------------------------
# 7. Enforce Disk Quotas (for Mailbox Protection)
# -------------------------------------

echo "Setting up disk quotas..."
yum install -y quota

# Ensure quotas are enabled
if ! mount | grep -q "/home.*usrquota"; then
    mount -o remount,usrquota,grpquota /home
    quotacheck -avugm
    quotaon -avug
fi

# Apply default user quotas
for user in $(ls /home); do
    if ! quota -u "$user" | grep -q "1000000"; then
        edquota -u "$user" -f /home <<EOF
500000
EOF
    fi
done

echo "Disk quotas enforced."

