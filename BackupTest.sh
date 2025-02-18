#!/bin/bash
#
# backup_mailserver.sh
#
# A simple script to back up Postfix, Dovecot, Roundcube config, mail data, 
# and the Roundcube MySQL database.

# 1. Set variables
BACKUP_DIR="/var/backups/mailserver"  # Where to store backup tarballs
NOW=$(date +%Y%m%d_%H%M%S)           # Timestamp
BACKUP_FILE="$BACKUP_DIR/mailserver_backup_$NOW.tar.gz"

# 2. Roundcube Database Credentials
#DB_NAME="roundcubemail"
#DB_USER="root"
#DB_PASS="YOUR_DB_PASSWORD"

# 3. Additional directories to back up
POSTFIX_DIR="/etc/postfix"
DOVECOT_DIR="/etc/dovecot"
#ROUNDCUBE_CONF_DIR="/etc/roundcubemail"
MAIL_DIR="/var/mail"                 # Adjust if your mail is elsewhere
#APACHE_CONF_DIR="/etc/httpd/conf"    # Optional
#APACHE_CONF_D_DIR="/etc/httpd/conf.d"
#SSL_CERT_DIR="/etc/pki/tls"

# 4. Create backup directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
fi

# 5. Dump Roundcube MySQL database
#echo "Dumping Roundcube database..."
#mysqldump -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" > /tmp/roundcube.sql
#if [ $? -ne 0 ]; then
#    echo "Error: mysqldump failed. Exiting."
#    exit 1
#fi

# 6. Create tarball of relevant directories + DB dump
echo "Creating tar archive..."
tar -czf "$BACKUP_FILE" \
    "$POSTFIX_DIR" \
    "$DOVECOT_DIR" \
#    "$ROUNDCUBE_CONF_DIR" \
    "$MAIL_DIR" \
#    "$APACHE_CONF_DIR" \
#    "$APACHE_CONF_D_DIR" \
#    "$SSL_CERT_DIR" \
#    /tmp/roundcube.sql \
    /etc/aliases \
    /etc/aliases.db 2>/dev/null

# 7. Remove temporary DB dump
#rm -f /tmp/roundcube.sql

# 8. Confirm backup is complete
if [ -f "$BACKUP_FILE" ]; then
    echo "Backup successful: $BACKUP_FILE"
else
    echo "Backup failed!"
fi
