#!/usr/bin/env bash
#
# undo_permissions.sh
#
# This script attempts to undo the permissions/ownership/hardening from
# the previous script. It removes the immutable attribute and sets
# ownership/perms back to more typical defaults for Fedora. Adjust as needed!

# Must run as root or via sudo
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (or via sudo). Exiting."
  exit 1
fi

# Directories we previously hardened
CONFIG_DIRS=(
  "/etc/roundcubemail"
  "/etc/httpd"
  "/etc/dovecot"
  "/etc/postfix"
)

echo "==============================================="
echo " Undoing Immutable Attribute & Permissions"
echo "==============================================="

# 1) Remove immutable attribute recursively
for dir in "${CONFIG_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    echo "Removing immutable attribute in $dir ..."
    chattr -R -i "$dir"
  else
    echo "Warning: $dir does not exist on this system. Skipping."
  fi
done

# 2) Optionally restore more typical Fedora ownership & permissions
#
# Below are *examples* of typical defaults, but they may differ on your system.
# You may want to adjust or omit these if you do not know your original setup.

echo
echo "Restoring ownership and permissions (example defaults) ..."

# /etc/roundcubemail
#   Typically root-owned, 755 for dirs, 644 for files if only root modifies them.
#   If the webserver needs to read these configs, 644 is usually enough for the files.
if [[ -d "/etc/roundcubemail" ]]; then
  echo " -> Reset /etc/roundcubemail"
  chown -R root:root /etc/roundcubemail
  find /etc/roundcubemail -type d -exec chmod 755 {} \;
  find /etc/roundcubemail -type f -exec chmod 644 {} \;
fi

# /etc/httpd
#   Usually root:root with 755 for directories, 644 for files.
#   (Fedora default for Apache config is root-owned. The service runs as apache:apache,
#    but does NOT need write access to /etc/httpd.)
if [[ -d "/etc/httpd" ]]; then
  echo " -> Reset /etc/httpd"
  chown -R root:root /etc/httpd
  find /etc/httpd -type d -exec chmod 755 {} \;
  find /etc/httpd -type f -exec chmod 644 {} \;
fi

# /etc/dovecot
#   Typically root:root, though some distros may set group to dovecot if needed.
#   The default is usually root:root for the configs. 755 for directories, 644 for files.
if [[ -d "/etc/dovecot" ]]; then
  echo " -> Reset /etc/dovecot"
  chown -R root:root /etc/dovecot
  find /etc/dovecot -type d -exec chmod 755 {} \;
  find /etc/dovecot -type f -exec chmod 644 {} \;
fi

# /etc/postfix
#   Usually root:root, with directories 755 and files 644.
#   Some subdirectories might have different defaults, but this is typical.
if [[ -d "/etc/postfix" ]]; then
  echo " -> Reset /etc/postfix"
  chown -R root:root /etc/postfix
  find /etc/postfix -type d -exec chmod 755 {} \;
  find /etc/postfix -type f -exec chmod 644 {} \;
fi

echo
echo "Done! Immutable attribute removed and example default perms/ownership applied."
echo "If you have a backup or reference for your original settings, consider restoring it now."
echo "Otherwise, verify everything is working as intended."
