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
