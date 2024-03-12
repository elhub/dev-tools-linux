#!/usr/bin/env bash
# Automated bootstrap script for devxp-linux.

# Define text color variables
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
NC=$(tput sgr0) # No Color
timestamp="$HOME/.local/devxp-files/.timestamp"

# Navigate to the directory containing the script
cd "$(dirname "$0")" || exit

# Store the current script hash
current_hash=$(sha256sum "$0")

# Perform a git pull to update the repository and suppress "Already up to date." message
git_pull_output=$(git pull 2>&1 | grep -v 'Already up to date.')

# Check if the script has changed after git pull
new_hash=$(sha256sum "$0")

if [ "$current_hash" != "$new_hash" ]; then
    echo "${GREEN}Script has been updated. Reloading...${NC}"
    exec "$0" "$@" # Reload the script
    exit 0
fi

# Define the undesired path
old_path="/usr/local/bin/devxp-files/devxp-linux/scripts"
new_path="$HOME/.local/devxp-files/devxp-linux/scripts"

# Check if the current directory is the old directory
if [ "$(realpath "$(dirname "$0")")" == "$old_path" ]; then
    echo "${YELLOW}The directory location will change from${NC}"
    echo "${RED}$old_path${NC}"
    echo "${YELLOW}to${NC}"
    echo "${GREEN}$new_path${NC}"
    echo "${YELLOW}The script will then continue from the new location.${NC}"
    read -p "Press any key to continue... " -n1 -s
    echo
    echo "$old_path/move-directory.sh"
    exit 0
fi

# Read the user from the file
USER=$(cat $HOME/.local/devxp-files/.user)

# Ensure that user has ownership of the devxp scripts directory and its sub directories
sudo chown -R ${user}:${user} $HOME/.local/devxp-files/devxp-linux/scripts
sudo chmod -R u+rx $HOME/.local/devxp-files/devxp-linux/scripts

# Upgrade the distro.
sudo apt-get update
sudo apt-get -y dist-upgrade

# Install tools.
sudo apt-get install -y make git python3 python3-pip

# Install Ansible via pip.
sudo apt-get remove -y ansible
sudo apt-get autoremove -y
python3 -m pip install --user ansible

# Ansible should now be installed in ~/.local/bin.
# If this directory did not exist already, then you might have to restart WSL.
# ~/.local/bin is conditionally loaded into $PATH in ~/.profile.

# Ensure that ~/.local/bin is loaded into $PATH.
source ~/.profile

# Run Ansible-runbooks to install necessary command-line tools.
ansible-galaxy install -r $HOME/.local/devxp-files/devxp-linux/requirements.yml --force

logFile="$HOME/.local/devxp-files/ansible-playbook.log"
lastRunFile="$HOME/.local/devxp-files/.last-run"

# Write a message indicating that the Ansible playbook is starting
echo "${YELLOW}Ansible playbook is starting, this can take some time.${NC}"

# Run Ansible playbook and redirect output to the log file
ANSIBLE_FORCE_COLOR=true ansible-playbook $HOME/.local/devxp-files/devxp-linux/site.yml --ask-become-pass 2>&1 | tee "$logFile";
if [[ "$?" -eq 0 ]]; then

    # Completion message content
    content="devxp-linux was last run $(date +'%d.%m.%y %H:%M')"

    # Write completion message
    echo "$content" > $lastRunFile

    # Write success message
    echo "${GREEN}Ansible playbook finished successfully.${NC}"
else
    # Write failure message
    echo "${RED}Ansible playbook execution failed. Please check ${logFile} for details.${NC}"

    # Completion message content
    content="devxp-linux failed on its last run at $(date +'%d.%m.%y %H:%M') Please check $logFile for details."

    # Write completion message
    echo "$content" > $lastRunFile
fi

# Remove ANSI color codes from the logfile for easier reading
sed -i 's/\x1b\[[0-9;]*m//g' "$logFile"

# Run the rc-injecter script to add the rc-notifications.sh script to the shell initialization files
$HOME/.local/devxp-files/devxp-linux/scripts/rc-injecter.sh
sudo chmod +x $HOME/.local/devxp-files/devxp-linux/scripts/rc-notifications.sh
date +%s > "$timestamp"

echo "${GREEN}Update complete${NC}"
