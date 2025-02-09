# List all users with sudo access
sudo_users=$(grep -Po '^sudo.+:\K.*$' /etc/group | tr ',' '\n')

# Loop through each sudo user and remove them (except root)
for user in $sudo_users; do
    if [[ "$user" != "root" ]]; then
        echo "Removing sudo privileges from: $user"
        deluser "$user" sudo
    fi
done

# Ensure only root exists in the sudoers file
if [ -f /etc/sudoers ]; then
    sed -i '/^%sudo/d' /etc/sudoers
    echo "Defaults root ALL=(ALL) ALL" > /etc/sudoers.d/root_only
fi

# Remove any lingering sudo access from /etc/sudoers.d/
find /etc/sudoers.d/ -type f ! -name "root_only" -exec rm -f {} \;

echo "Sudo permissions cleanup complete."
