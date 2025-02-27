#!/bin/bash
# List of critical files to protect
FILES=(
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

# Loop through each file and set it immutable if it exists
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        chattr +i "$file"
        echo "Set immutable on $file"
    else
        echo "File not found: $file"
    fi
done
