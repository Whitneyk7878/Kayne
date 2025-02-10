#!/bin/bash
echo -e "starting script"


echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m             General Security Measures                      \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
# Only allow root login from console
echo "tty1" > /etc/securetty
chmod 700 /root
echo "DONE"

# DENY ALL TCP WRAPPERS
echo "ALL:ALL" > /etc/hosts.deny

echo "Removing all users from the wheel group except root..."

# Get a list of all users in the wheel group
wheel_users=$(grep '^wheel:' /etc/group | cut -d: -f4 | tr ',' '\n')

# Loop through each user and remove them if they are not root
for user in $wheel_users; do
    if [[ "$user" != "root" ]]; then
        echo "Removing $user from wheel group..."
        gpasswd -d "$user" wheel
    fi
done

echo "Cleanup complete. Only root has sudo permissions now."

#!/bin/bash

# Ensure only root can run this script
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

######################################THIS COULD BREAK IT ALL################################################################################
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


