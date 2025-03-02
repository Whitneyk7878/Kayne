#!/bin/bash

echo "Clearing mail logs and mailboxes for all users..."

# MAIL_LOG="/var/log/maillog"
MAIL_BASE="/home"

# Ensure only root can run the script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root!"
   exit 1
fi

# Iterate over users and clear mailboxes
for user in $(ls $MAIL_BASE); do
    MAILDIR="$MAIL_BASE/$user/Maildir"
    
    if [[ -d "$MAILDIR" ]]; then
        echo "Clearing emails for user: $user"

        # Delete all emails in cur, new, and tmp
        rm -rf "$MAILDIR/cur/*" "$MAILDIR/new/*" "$MAILDIR/tmp/*"

        # Reset ownership (to avoid permission issues)
        chown -R "$user:$user" "$MAILDIR"
    fi
done

# Clear mail log
#echo "Clearing mail logs..."
#cat /dev/null > $MAIL_LOG

# Restart mail services to apply changes
echo "Restarting Postfix and Dovecot..."
systemctl restart postfix
systemctl restart dovecot

echo "All mailboxes"
