# Set permissions
chown -hR $username:$username $CCDC_DIR
# Fix permissions (just in case)
chown root:root /etc/group
chmod a=r,u=rw /etc/group
chown root:root /etc/sudoers
chmod a=,ug=r /etc/sudoers
chown root:root /etc/passwd
chmod a=r,u=rw /etc/passwd
if [ $(getent group shadow) ]; then
  chown root:shadow /etc/shadow
else
  chown root:root /etc/shadow
fi
chmod a=,u=rw,g=r /etc/shadow
