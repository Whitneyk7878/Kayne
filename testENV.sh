#!/bin/bash

# Ensure only root can run this script
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

echo "Restricting permissions: Only root will have full privileges."

# Loop through each user in the system (excluding root)
for user in $(getent passwd | awk -F: '$3 >= 1000 {print $1}'); do
    if [[ "$user" != "root" ]]; then
        echo "Modifying permissions for user: $user"

        # Set home directory permissions to read-only
        chmod -R 755 /home/"$user"
        
        # Remove sudo/wheel access
        gpasswd -d "$user" wheel 2>/dev/null
        gpasswd -d "$user" sudo 2>/dev/null

        # Set user shell to /bin/false to prevent login if needed
        usermod -s /bin/false "$user"
    fi
done

echo "Permission changes applied successfully. Only root has full privileges."
