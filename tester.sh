#!/bin/bash
# Consolidated Backup Script for Fedora 21 with Apache, Postfix, Dovecot, Roundcube, and MariaDB
# Assumes a full system compromise so this backup aims to include all configurations and databases needed to restore services.

set -e  # Exit on any error

# Set a timestamp for backup filenames
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Define backup destination directories
BACKUP_DIR1="/etc/ftb"
BACKUP_DIR2="/etc/.tarkov"

# Create backup directories if they don't exist
mkdir -p "$BACKUP_DIR1"
mkdir -p "$BACKUP_DIR2"

# Create a temporary working directory for backup files
TMP_DIR="/tmp/backup_$TIMESTAMP"
mkdir -p "$TMP_DIR"

echo "Starting backup at $(date)"

##############################
# Backup Apache
##############################
# Assumes Apache configuration is in /etc/httpd and web data in /var/www
mkdir -p "$TMP_DIR/apache"
if [ -d /etc/httpd ]; then
  cp -a /etc/httpd "$TMP_DIR/apache/"
else
  echo "Warning: /etc/httpd not found."
fi
if [ -d /var/www ]; then
  cp -a /var/www "$TMP_DIR/apache/"
else
  echo "Warning: /var/www not found."
fi

##############################
# Backup Postfix
##############################
# Assumes Postfix config is in /etc/postfix
mkdir -p "$TMP_DIR/postfix"
if [ -d /etc/postfix ]; then
  cp -a /etc/postfix "$TMP_DIR/postfix/"
else
  echo "Warning: /etc/postfix not found."
fi

##############################
# Backup Dovecot
##############################
# Assumes Dovecot config is in /etc/dovecot
mkdir -p "$TMP_DIR/dovecot"
if [ -d /etc/dovecot ]; then
  cp -a /etc/dovecot "$TMP_DIR/dovecot/"
else
  echo "Warning: /etc/dovecot not found."
fi

##############################
# Backup Roundcube
##############################
# Assumes Roundcube config is in /etc/roundcube and its web files in /usr/share/roundcube
mkdir -p "$TMP_DIR/roundcube"
if [ -d /etc/roundcubemail ]; then
  cp -a /etc/roundcubemail "$TMP_DIR/roundcubemail/"
else
  echo "Warning: /etc/roundcubemail not found."
fi
if [ -d /usr/share/roundcubemail ]; then
  cp -a /usr/share/roundcubemail "$TMP_DIR/roundcubemail/"
else
  echo "Warning: /usr/share/roundcubemail not found."
fi

##############################
# Backup MariaDB Databases
##############################
echo "Backing up MariaDB databases..."
# This command dumps all databases. If a password is required, you might need to modify the command 
# (for example, using a .my.cnf file for credentials or appending -p and entering the password).
mysqldump --all-databases --single-transaction --quick --lock-tables=false > "$TMP_DIR/all_databases_$TIMESTAMP.sql"

##############################
# (Optional) Backup additional system configurations
##############################
# Uncomment the following if you wish to include the entire /etc directory:
# cp -a /etc "$TMP_DIR/etc_full_backup"

##############################
# Create the compressed backup archive
##############################
BACKUP_FILE="backup_$TIMESTAMP.tar.gz"
tar -czvf "/tmp/$BACKUP_FILE" -C "$TMP_DIR" .

##############################
# Copy the backup archive to both destinations
##############################
cp "/tmp/$BACKUP_FILE" "$BACKUP_DIR1/"
cp "/tmp/$BACKUP_FILE" "$BACKUP_DIR2/"

echo "Backup completed successfully at $(date)."
echo "Backup file: $BACKUP_FILE saved in $BACKUP_DIR1 and $BACKUP_DIR2"

# Clean up temporary files
rm -rf "$TMP_DIR"
rm "/tmp/$BACKUP_FILE"

exit 0
