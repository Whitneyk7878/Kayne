echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m         Installing Comp Tools from Github            \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
# Create the directory if it doesn't exist
mkdir -p COMPtools

# Base URL for the files
base_url="https://raw.githubusercontent.com/Whitneyk7878/Kayne/refs/heads/main/"

# List of files to download
files=(
    "COMPMailBoxClear.sh"
    "COMPInstallBroZEEK.sh"
    "COMPBackupFIREWALL.sh"
    "COMPcreatebackups.sh"
    "COMPrestorefrombackup.sh"
)

# Loop over each file and download it into the COMPtools directory
for file in "${files[@]}"; do
    echo "Downloading ${file}..."
    wget -P COMPtools "${base_url}${file}"
done

echo "All files have been downloaded to the COMPtools directory."
