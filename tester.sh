echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m         Removing Immutable Attribute on Files        \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1

#!/bin/bash
# This script undoes the immutability set by the "Locking Down Critical Files" script.
# It removes the +i attribute from each file or directory listed below.

ITEMS=(
    /etc/roundcubemail
    /etc/httpd
    /etc/dovecot
    /etc/postfix
    /etc/passwd
    /etc/shadow
    /etc/group
    /etc/gshadow
    /etc/sudoers
    /etc/ssh/sshd_config
    /etc/ssh/ssh_config
    /etc/crontab
    /etc/fstab
    /etc/hosts
    /etc/resolv.conf
    /etc/sysctl.conf
    /etc/selinux/config
)

for item in "${ITEMS[@]}"; do
    if [ -f "$item" ]; then
        # If it's a file, remove the immutable attribute
        chattr -i "$item" 2>/dev/null && echo "Removed immutability from file: $item" || \
          echo "Warning: Could not remove immutability from file: $item"
    elif [ -d "$item" ]; then
        # If it's a directory, remove the immutable attribute (recursively)
        chattr -R -i "$item" 2>/dev/null && echo "Removed immutability from directory: $item" || \
          echo "Warning: Could not remove immutability from directory: $item"
    else
        echo "Not found (file or directory): $item"
    fi
done

echo
echo "All specified items have been processed for immutability removal."
