#!/bin/bash
# Simple Backup Script for Fedora 21 Services
# This script zips up service directories and copies the archives
# to two backup locations: /etc/ftb and /etc/.tarkov.
# Services:
#   - Apache: /etc/httpd and /var/www
#   - Postfix: /etc/postfix
#   - Dovecot: /etc/dovecot
#   - Roundcube: /etc/roundcube and /usr/share/roundcube
#   - MariaDB: /var/lib/mysql

set -e

# Define backup destination directories
BACKUP_DIR1="/etc/ftb"
BACKUP_DIR2="/etc/.tarkov"

# Create backup directories if they don't exist
mkdir -p "$BACKUP_DIR1" "$BACKUP_DIR2"

echo "Creating backup archives..."

# Apache backup: zip the Apache configuration and web files.
(cd / && zip -r /tmp/apache.zip etc/httpd var/www)
echo "Apache backup created."

# Postfix backup: zip the postfix configuration.
(cd / && zip -r /tmp/postfix.zip etc/postfix)
echo "Postfix backup created."

# Dovecot backup: zip the dovecot configuration.
(cd / && zip -r /tmp/dovecot.zip etc/dovecot)
echo "Dovecot backup created."

# Roundcube backup: zip the roundcube configuration and web files.
(cd / && zip -r /tmp/roundcube.zip etc/roundcube usr/share/roundcube)
echo "Roundcube backup created."

# MariaDB backup: zip the MySQL data directory.
(cd / && zip -r /tmp/mariadb.zip var/lib/mysql)
echo "MariaDB backup created."

# Copy each archive to both backup directories.
for ARCHIVE in apache.zip postfix.zip dovecot.zip roundcube.zip mariadb.zip; do
    cp /tmp/"$ARCHIVE" "$BACKUP_DIR1"/
    cp /tmp/"$ARCHIVE" "$BACKUP_DIR2"/
    echo "Copied $ARCHIVE to $BACKUP_DIR1 and $BACKUP_DIR2"
done

# Clean up temporary archives
rm /tmp/apache.zip /tmp/postfix.zip /tmp/dovecot.zip /tmp/roundcube.zip /tmp/mariadb.zip

echo "Backup completed successfully."
