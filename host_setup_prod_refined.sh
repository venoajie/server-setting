#!/bin/bash
set -euo pipefail

echo "--- Starting Production Server Setup ---"

# --- 1. Install Prerequisite Tools ---
echo "Updating base packages and installing git..."
sudo dnf update -y
sudo dnf install -y git

# --- 2. Prepare Host Directory Structure ---
echo "Creating secure and application directories in /opt..."
sudo mkdir -p /opt/secrets
sudo chown opc:opc /opt/secrets
sudo chmod 700 /opt/secrets

sudo mkdir -p /opt/apps
sudo chown opc:opc /opt/apps

sudo mkdir -p /opt/fluentd/config
sudo chown -R opc:opc /opt/fluentd

# --- 3. Clone Production Configuration Files ---
echo "Cloning pg-cluster configuration from git repository into /opt..."
cd /opt
sudo git clone https://github.com/venoajie/server_setting.git
sudo mv server_setting/pg-cluster ./pg-cluster
sudo rm -rf server_setting
cd ~ # Return to home directory for safety

# --- 4. Generate and Inject Secrets (DBRE-1 & SSA-1 Best Practice) ---
echo "Generating and injecting database credentials..."
# Generate strong, unique passwords
SUPERUSER_PASS=$(openssl rand -base64 24)
APP_USER_PASS=$(openssl rand -base64 24)

# Save the application password to the central secret file
echo "$APP_USER_PASS" > /opt/secrets/trading_app_password.txt

# Use sed to safely replace placeholders in the cloned config files
# This is non-interactive and safer than echoing secrets.
CONFIG_DIR="/opt/pg-cluster"
sed -i "s/YOUR_STRONG_SUPERUSER_PASSWORD_HERE/$SUPERUSER_PASS/g" $CONFIG_DIR/.env
sed -i "s/YOUR_STRONG_APP_USER_PASSWORD_HERE/$APP_USER_PASS/g" $CONFIG_DIR/.env

sed -i "s/YOUR_STRONG_SUPERUSER_PASSWORD_HERE/$SUPERUSER_PASS/g" $CONFIG_DIR/config/pgbouncer/userlist.txt
sed -i "s/YOUR_STRONG_APP_USER_PASSWORD_HERE/$APP_USER_PASS/g" $CONFIG_DIR/config/pgbouncer/userlist.txt

echo "Secrets have been generated and injected."

# --- 5. Set Correct Ownership and Permissions ---
echo "Setting final permissions for pg-cluster..."
sudo chown -R opc:opc /opt/pg-cluster
sudo chmod +x /opt/pg-cluster/bin/*.sh

# --- 6. Install Docker and System Dependencies (SRE-1) ---
echo "Updating all system packages, excluding conflicting pyOpenSSL..."
sudo dnf update -y --exclude=python3-pyOpenSSL

echo "Installing EPEL repository and essential tools..."
sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
sudo dnf install -y htop jq

echo "Configuring DNF to use the Docker repository for CentOS 9..."
sudo tee /etc/yum.repos.d/docker-ce.repo > /dev/null <<'EOF'
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://download.docker.com/linux/centos/9/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/centos/gpg
EOF

echo "Installing Docker Engine and Compose plugin..."
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Enabling and starting Docker service..."
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# --- 7. Apply Kernel Tuning (DBRE-1) ---
echo "Applying PostgreSQL-optimized kernel parameters..."
sudo tee /etc/sysctl.d/99-postgres.conf > /dev/null <<'EOF'
# DBRE-1: Tuned settings for a 18GB RAM PostgreSQL server
kernel.shmmax = 12884901888
kernel.shmall = 3145728
vm.swappiness = 1
vm.overcommit_memory = 2
vm.overcommit_ratio = 95
vm.dirty_background_ratio = 2
vm.dirty_ratio = 3
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
EOF
sudo sysctl --system

# --- 8. Automate Local Backups ---
echo "Adding daily backup job to crontab..."
# This command adds the job without needing to open an editor.
(crontab -l 2>/dev/null; echo "5 3 * * * /opt/pg-cluster/bin/backup.sh") | crontab -

echo "--- Host Preparation Complete ---"
echo "!!! CRITICAL: You MUST log out and log back in for Docker group changes to take effect. !!!"