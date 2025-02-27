#!/bin/bash


###################################################################
# 2) Variables and backups
###################################################################
PHP_INI="/etc/php.ini"
PHP_INI_BAK="/etc/php.ini.bak-$(date +%F-%T)"
ROUNDCUBE_DIR="/usr/share/roundcubemail"   # Adjust if your Roundcube path differs
OPENBASEDIR_CONF="/etc/httpd/conf.d/roundcube-openbasedir.conf"
SESSION_PATH="/var/lib/php/session"

# Backup php.ini
if [[ -f "$PHP_INI" ]]; then
  cp -v "$PHP_INI" "$PHP_INI_BAK"
  echo "Backed up $PHP_INI to $PHP_INI_BAK"
else
  echo "WARNING: $PHP_INI not found. Exiting to avoid unintended changes."
  exit 1
fi

###################################################################
# 3) Disable dangerous PHP functions in php.ini
###################################################################
# We'll use sed to either replace the line if it exists or append if not found.
# Disabled functions: exec, shell_exec, system, passthru, popen, proc_open
DISABLE_FUNCTIONS="disable_functions = exec,shell_exec,system,passthru,popen,proc_open"

# If a disable_functions line exists, replace it. Otherwise, append.
if grep -qE "^disable_functions\s*=" "$PHP_INI"; then
  sed -i "s|^disable_functions\s*=.*|$DISABLE_FUNCTIONS|" "$PHP_INI"
else
  # Append at the end
  echo "$DISABLE_FUNCTIONS" >> "$PHP_INI"
fi

echo "Set disable_functions in $PHP_INI to: $DISABLE_FUNCTIONS"

###################################################################
# 4) Limit file uploads (upload_max_filesize, post_max_size)
###################################################################
# We set these to 5M and 6M respectively, as an example.
# Adjust as necessary for your environment.

# upload_max_filesize
if grep -qE "^upload_max_filesize\s*=" "$PHP_INI"; then
  sed -i "s|^upload_max_filesize\s*=.*|upload_max_filesize = 5M|" "$PHP_INI"
else
  echo "upload_max_filesize = 5M" >> "$PHP_INI"
fi

# post_max_size
if grep -qE "^post_max_size\s*=" "$PHP_INI"; then
  sed -i "s|^post_max_size\s*=.*|post_max_size = 6M|" "$PHP_INI"
else
  echo "post_max_size = 6M" >> "$PHP_INI"
fi

echo "Set upload_max_filesize = 5M and post_max_size = 6M in $PHP_INI"

###################################################################
# 5) Create Apache snippet for open_basedir
#
# This prevents PHP scripts from reading outside the specified
# directories (except /tmp). Adjust as needed. If you already have
# a custom VirtualHost config for Roundcube, place it there.
###################################################################
cat <<EOF > "$OPENBASEDIR_CONF"
# Roundcube open_basedir restriction
# This will only work if Apache is using mod_php (not PHP-FPM).
# For FPM, set 'php_admin_value[open_basedir]' in your pool config.

<Directory "$ROUNDCUBE_DIR">
    # Restrict Roundcube to its own directory + /tmp
    php_admin_value open_basedir "$ROUNDCUBE_DIR:/tmp"
</Directory>
EOF

echo "Created $OPENBASEDIR_CONF for open_basedir."

###################################################################
# 6) Secure Session Storage
#
# Roundcube sessions typically land in /var/lib/php/session/.
# Ensure ownership is root:apache and permissions are 770 or 750.
###################################################################
if [[ -d "$SESSION_PATH" ]]; then
  chown root:apache "$SESSION_PATH"
  chmod 770 "$SESSION_PATH"
  echo "Secured session directory: $SESSION_PATH (ownership root:apache, mode 770)"
else
  echo "WARNING: Session directory $SESSION_PATH not found. Check your PHP session.save_path."
fi

###################################################################
# 7) Restart/Reload Services
###################################################################
echo "Reloading Apache to apply open_basedir changes..."
systemctl reload httpd

echo "Done! PHP has been hardened for Roundcube on Fedora."
echo
echo "Summary of changes:"
echo "  - Backed up $PHP_INI to $PHP_INI_BAK"
echo "  - Disabled functions: exec, shell_exec, system, passthru, popen, proc_open"
echo "  - Set upload_max_filesize=5M, post_max_size=6M in $PHP_INI"
echo "  - Created $OPENBASEDIR_CONF to restrict Roundcube to $ROUNDCUBE_DIR and /tmp"
echo "  - Secured $SESSION_PATH (root:apache, 770)"
echo
echo "IMPORTANT: Verify these changes won't break any Roundcube plugins needing the disabled functions."
