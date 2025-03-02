#!/bin/bash

echo "Starting Postfix chroot setup on Fedora 21..."

# Define Postfix chroot directory
CHROOT_DIR="/var/spool/postfix"

# -------------------------------------
# 1. Create Required Directories
# -------------------------------------
echo "Creating necessary directories for Postfix chroot..."

mkdir -p "$CHROOT_DIR"/{dev,etc,lib,usr,usr/lib,usr/lib/zoneinfo,var,var/run}
mkdir -p "$CHROOT_DIR/usr/lib/sasl2"

echo "Directories created."

# -------------------------------------
# 2. Copy Required Configuration Files
# -------------------------------------
echo "Copying required system files..."

cp /etc/localtime "$CHROOT_DIR/etc/"
cp /etc/host.conf "$CHROOT_DIR/etc/"
cp /etc/resolv.conf "$CHROOT_DIR/etc/"
cp /etc/nsswitch.conf "$CHROOT_DIR/etc/"
cp /etc/services "$CHROOT_DIR/etc/"
cp /etc/hosts "$CHROOT_DIR/etc/"
cp /etc/passwd "$CHROOT_DIR/etc/"

echo "System files copied."

# -------------------------------------
# 3. Copy Required Libraries
# -------------------------------------
echo "Copying required shared libraries..."

cp /lib/libnss_*.so* "$CHROOT_DIR/lib/"
cp /lib/libresolv.so* "$CHROOT_DIR/lib/"
cp /lib/libdb.so* "$CHROOT_DIR/lib/"

echo "Shared libraries copied."

# -------------------------------------
# 4. Copy Timezone Information
# -------------------------------------
echo "Copying timezone information..."

cp /etc/localtime "$CHROOT_DIR/usr/lib/zoneinfo/"

echo "Timezone info copied."

# -------------------------------------
# 5. Configure Syslog Logging for Chroot
# -------------------------------------
echo "Setting up logging for chrooted Postfix..."

mkdir -p "$CHROOT_DIR/dev"
touch "$CHROOT_DIR/dev/log"
chown root:root "$CHROOT_DIR/dev/log"
chmod 666 "$CHROOT_DIR/dev/log"

# Modify syslog startup for chroot logging
if ! grep -q "/var/spool/postfix/dev/log" /etc/sysconfig/syslog; then
    echo 'SYSLOGD_OPTIONS="-a /var/spool/postfix/dev/log"' >> /etc/sysconfig/syslog
fi

systemctl restart rsyslog

echo "Syslog configured for Postfix chroot."

# -------------------------------------
# 6. Copy SASL Files (if using SASL authentication)
# -------------------------------------
echo "Copying SASL configuration..."

if [ -d "/usr/lib/sasl2" ]; then
    cp -r /usr/lib/sasl2/* "$CHROOT_DIR/usr/lib/sasl2/"
fi

if [ -f "/etc/sasl2/smtpd.conf" ]; then
    cp /etc/sasl2/smtpd.conf "$CHROOT_DIR/etc/sasl2/"
fi

echo "SASL setup completed."

# -------------------------------------
# 7. Modify Postfix master.cf for Chrooting
# -------------------------------------
echo "Configuring Postfix master.cf for chroot..."

POSTFIX_MASTER="/etc/postfix/master.cf"

while IFS= read -r line; do
    if [[ $line =~ ^#?\s*([a-zA-Z0-9]+)\s+inet\s+n\s+-\s+n ]]; then
        SERVICE_NAME="${BASH_REMATCH[1]}"
        # Skip local and virtual services
        if [[ "$SERVICE_NAME" != "local" && "$SERVICE_NAME" != "virtual" ]]; then
            sed -i "s/^$SERVICE_NAME\s\+inet\s\+n\s\+-\s\+n\s\+/&y /" "$POSTFIX_MASTER"
        fi
    fi
done < "$POSTFIX_MASTER"

systemctl restart postfix
echo "Postfix chroot configuration applied."

# -------------------------------------
# 8. Reload Postfix and Verify
# -------------------------------------
echo "Reloading Postfix..."
postfix reload

echo "Checking mail logs for any errors..."
tail -n 20 /var/log/maillog

echo "Postfix chroot setup is complete!"
