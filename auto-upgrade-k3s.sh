#!/bin/bash

# Define the path to the YAML file and the key-value to update
yamlFilePath="/mnt/d/git-repos/k3s-ansible-fork/inventory-copy.yml"
keyToUpdate="k3s_cluster.vars.k3s_version"
repo="k3s-io/k3s"
logFile="/mnt/d/git-repos/k3s-ansible-fork/auto-upgrade-k3s.log"

# Function to get the latest release tag from GitHub
get_latest_release_tag() {
    local repo=$1
    curl -s "https://api.github.com/repos/$repo/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")'
}

# Get the latest release tag from the k3s repository
newValue=$(get_latest_release_tag $repo)
echo "Latest release tag: $newValue"

# Install yq if it is not installed
if ! command -v /usr/local/bin/yq &> /dev/null
then
    echo "yq could not be found. Installing yq..."
    echo "" | sudo -S wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.6.1/yq_linux_amd64
    echo "" | sudo -S chmod +x /usr/local/bin/yq
fi

# Check current value in the YAML file
currentValue=$(/usr/local/bin/yq eval ".$keyToUpdate" $yamlFilePath)
echo "Current value: $currentValue"

# Check if newValue is not null and different from currentValue before updating the YAML file and running the playbook
if [ -n "$newValue" ] && [ "$newValue" != "$currentValue" ]; then
    # Update the YAML file using yq
    /usr/local/bin/yq eval ".$keyToUpdate = \"$newValue\"" -i $yamlFilePath

    # Define paths to the Ansible playbook and inventory
    playbookPath="/mnt/d/git-repos/k3s-ansible-fork/playbook/upgrade.yml"
    inventoryPath="/mnt/d/git-repos/k3s-ansible-fork/inventory.yml"

    # Run the Ansible playbook and log output
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting auto-upgrade script..."

        if ansible-playbook $playbookPath -i $inventoryPath; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ansible playbook run completed successfully."
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ansible playbook run failed."
        fi

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Script run completed."
    } >> $logFile 2>&1
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] No update needed. Current version and latest version are the same or new version is null." >> $logFile 2>&1
    exit 0
fi
