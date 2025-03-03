#!/bin/bash
# Interactive Restore Script
# This script complements the backup script and lets you choose which backup
# component(s) to restore and from which backup location.
# Components include:
#   a) Apache (configuration and web files)
#   b) Postfix (configuration)
#   c) Dovecot (configuration)
#   d) Roundcube (configuration and web files)
#   e) MariaDB (database dump)
#   f) Full Backup (all of the above)

set -e

# Function: Choose backup storage location
choose_backup_location() {
    echo "Select the backup location to restore from:"
    echo "1) /etc/ftb"
    echo "2) /etc/.tarkov"
    read -p "Enter choice (1 or 2): " loc_choice
    case "$loc_choice" in
      1) BACKUP_DIR="/etc/ftb" ;;
      2) BACKUP_DIR="/etc/.tarkov" ;;
      *) echo "Invalid choice. Exiting." && exit 1 ;;
    esac
}

# Function: Let the user choose a backup file from the selected directory
choose_backup_file() {
    echo "Looking for backup files in $BACKUP_DIR ..."
    files=("$BACKUP_DIR"/backup_*.tar.gz)
    if [ ${#files[@]} -eq 0 ]; then
       echo "No backup files found in $BACKUP_DIR. Exiting."
       exit 1
    fi

    echo "Available backup files:"
    i=1
    for file in "${files[@]}"; do
       echo "  $i) $(basename "$file")"
       ((i++))
    done
    read -p "Enter the number of the backup file to restore: " file_choice
    index=$((file_choice - 1))
    if [ $index -ge 0 ] && [ $index -lt ${#files[@]} ]; then
       SELECTED_BACKUP="${files[$index]}"
       echo "Selected backup file: $SELECTED_BACKUP"
    else
       echo "Invalid selection. Exiting."
       exit 1
    fi
}

# Function: Display restore component menu
show_component_menu() {
    echo "Select the backup component(s) to restore:"
    echo "a) Apache (configuration and web files)"
    echo "b) Postfix (configuration)"
    echo "c) Dovecot (configuration)"
    echo "d) Roundcube (configuration and web files)"
    echo "e) MariaDB (databases)"
    echo "f) Full Backup (all components)"
    read -p "Enter your choice (a, b, c, d, e or f): " comp_choice
}

# Function: Restore Apache backup
restore_apache() {
    echo "Restoring Apache backup..."
    # Restore Apache configuration from /etc/httpd
    if [ -d "$RESTORE_TMP/apache/httpd" ]; then
        cp -a "$RESTORE_TMP/apache/httpd" /etc/
        echo "Restored Apache configuration to /etc/httpd"
    else
        echo "Apache configuration backup not found."
    fi
    # Restore web files from /var/www
    if [ -d "$RESTORE_TMP/apache/www" ]; then
        cp -a "$RESTORE_TMP/apache/www" /var/
        echo "Restored Apache web files to /var/www"
    else
        echo "Apache web files backup not found."
    fi
}

# Function: Restore Postfix backup
restore_postfix() {
    echo "Restoring Postfix backup..."
    if [ -d "$RESTORE_TMP/postfix" ]; then
        cp -a "$RESTORE_TMP/postfix" /etc/
        echo "Restored Postfix configuration to /etc/postfix"
    else
        echo "Postfix backup not found."
    fi
}

# Function: Restore Dovecot backup
restore_dovecot() {
    echo "Restoring Dovecot backup..."
    if [ -d "$RESTORE_TMP/dovecot" ]; then
        cp -a "$RESTORE_TMP/dovecot" /etc/
        echo "Restored Dovecot configuration to /etc/dovecot"
    else
        echo "Dovecot backup not found."
    fi
}

# Function: Restore Roundcube backup
restore_roundcube() {
    echo "Restoring Roundcube backup..."
    if [ -d "$RESTORE_TMP/roundcube" ]; then
        # Restore to /etc/roundcube (configuration)
        rm -rf /etc/roundcube
        cp -a "$RESTORE_TMP/roundcube" /etc/roundcube
        echo "Restored Roundcube configuration to /etc/roundcube"
        # Restore to /usr/share/roundcube (web files)
        rm -rf /usr/share/roundcube
        cp -a "$RESTORE_TMP/roundcube" /usr/share/roundcube
        echo "Restored Roundcube web files to /usr/share/roundcube"
    else
        echo "Roundcube backup not found."
    fi
}

# Function: Restore MariaDB backup
restore_mariadb() {
    echo "Restoring MariaDB backup..."
    # Find the SQL dump file (named all_databases_*.sql)
    sql_file=$(find "$RESTORE_TMP" -maxdepth 1 -type f -name "all_databases_*.sql" | head -n 1)
    if [ -n "$sql_file" ]; then
        echo "Found MariaDB backup file: $(basename "$sql_file")"
        read -p "This will overwrite your current databases. Proceed? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            mysql -u root -p < "$sql_file"
            echo "MariaDB databases restored."
        else
            echo "MariaDB restore cancelled."
        fi
    else
        echo "MariaDB backup not found."
    fi
}

# MAIN SCRIPT EXECUTION

choose_backup_location
choose_backup_file
show_component_menu

# Create a temporary directory for extraction
RESTORE_TMP="/tmp/restore_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESTORE_TMP"
echo "Extracting backup file..."
tar -xzvf "$SELECTED_BACKUP" -C "$RESTORE_TMP"

# Based on user's selection, call the appropriate restore function(s)
case "$comp_choice" in
    a|A)
        restore_apache
        ;;
    b|B)
        restore_postfix
        ;;
    c|C)
        restore_dovecot
        ;;
    d|D)
        restore_roundcube
        ;;
    e|E)
        restore_mariadb
        ;;
    f|F)
        echo "Restoring full backup..."
        restore_apache
        restore_postfix
        restore_dovecot
        restore_roundcube
        restore_mariadb
        ;;
    *)
        echo "Invalid selection. Exiting."
        rm -rf "$RESTORE_TMP"
        exit 1
        ;;
esac

echo "Restoration process complete."
# Clean up temporary extraction directory
rm -rf "$RESTORE_TMP"

exit 0
