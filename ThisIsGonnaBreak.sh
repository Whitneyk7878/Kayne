#!/bin/bash

# -------------------------------------
# 2. Enable Postfix Rate Limiting
# -------------------------------------

echo "Setting Postfix rate limits..."
cat <<EOF >> /etc/postfix/main.cf

# Limit email flood attacks
smtpd_client_connection_count_limit = 10
smtpd_client_connection_rate_limit = 60
smtpd_error_sleep_time = 5s
smtpd_soft_error_limit = 10
smtpd_hard_error_limit = 20

# Enable message size limit (10MB max)
message_size_limit = 10485760

# Disable open relay
smtpd_recipient_restrictions = reject_unauth_destination
EOF

systemctl restart postfix
echo "Postfix rate limits applied."

# -------------------------------------
# 3. Secure Dovecot (IMAP/POP3)
# -------------------------------------

echo "Configuring Dovecot security..."
cat <<EOF >> /etc/dovecot/conf.d/20-imap.conf

# Limit concurrent IMAP connections per user
service imap-login {
  process_limit = 10
  service_count = 1
}

# Prevent mailbox overflows (quota system)
plugin {
  quota = maildir:User quota
  quota_rule = *:storage=1G
}
EOF

systemctl restart dovecot
echo "Dovecot security settings applied."

# -------------------------------------
# 4. Protect Roundcube (Webmail)
# -------------------------------------

echo "Hardening Roundcube..."
ROUND_CUBE_CONFIG="/etc/roundcubemail/config.inc.php"

# Secure session handling and brute-force protection
cat <<EOF >> "$ROUND_CUBE_CONFIG"

\$config['session_lifetime'] = 10; # Auto logout after 10 minutes
\$config['max_login_attempts'] = 5; # Lockout after 5 failed attempts
\$config['login_rate_limit'] = '1r/10s'; # Rate limit logins

# Disable large file uploads to prevent disk overflow
\$config['max_message_size'] = '10M';

EOF

systemctl restart httpd
echo "Roundcube hardened."


# -------------------------------------
# 7. Enforce Disk Quotas (for Mailbox Protection)
# -------------------------------------

echo "Setting up disk quotas..."
dnf install -y quota

# Enable quotas on /home (where mailboxes are stored)
mount -o remount,usrquota,grpquota /home
quotacheck -avugm
quotaon -avug

# Set default mailbox quota (1GB per user)
edquota -u $(ls /home) -f /home <<EOF
500000
EOF

echo "Disk quotas enforced."

