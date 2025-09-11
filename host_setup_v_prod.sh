# Problem with oracle 10 docker installation:
#**both** of Docker's primary installation methods are currently incompatible with a fresh Oracle Linux 10 installation:
#1.  The official DNF repository: **Does not exist.**
#2.  The official convenience script: **Does not support OL10.**

### **The Engineering Pivot: A More Resilient Solution**: When automated methods fail on a new OS, we fall back to a more manual but more controlled process. Since Oracle Linux is a derivative of Red Hat Enterprise Linux (RHEL), we can confidently use the official Docker repository for its closest, stable relative: **CentOS 9**.

#**Action Plan:**
#1.  Create a new script file named `host_setup_v_prod.sh` in your home directory.
#2.  Paste the content below into the file.
#3.  Make it executable: `chmod +x host_setup_v_prod.sh`.
#4.  Run it: `./host_setup_v.sh`.

#--- START OF FILE host_setup_v_prod.sh ---
#!/bin/bash
set -euo pipefail

# Create the entire folder structure correctly with a single command
sudo mkdir -p /opt/pg-cluster/{bin,config/postgres,config/pgbouncer,data/postgres,logs/{postgres,pgbouncer},backups/{daily,weekly}}

# Set the correct ownership so your 'opc' user can manage it
sudo chown -R opc:opc /opt/pg-cluster/

# Verify the new, clean structure
tree /opt/pg-cluster/

# --- SRE-1: System Preparation & Tooling (Definitive for OL10) ---
echo "Updating all system packages, excluding the conflicting pyOpenSSL package..."
sudo dnf update -y --exclude=python3-pyOpenSSL

echo "Installing the official EPEL 10 repository configuration..."
sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm

echo "Installing essential tools from base and EPEL repositories..."
sudo dnf install -y git htop jq

# --- SRE-1 & SSA-1: Docker Installation (Repository Method) ---
echo "Manually configuring DNF to use the official Docker repository for CentOS 9..."
sudo tee /etc/yum.repos.d/docker-ce.repo > /dev/null <<'EOF'
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://download.docker.com/linux/centos/9/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/centos/gpg
EOF

echo "Installing Docker Engine and Compose plugin from the newly configured repository..."
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Enabling and starting the Docker service..."
sudo systemctl enable --now docker

echo "Adding the current user ($USER) to the 'docker' group..."
sudo usermod -aG docker $USER

# --- DBRE-1: Kernel Tuning for PostgreSQL ---
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

echo "Applying sysctl changes..."
sudo sysctl --system

echo "Host preparation complete."
echo "!!! CRITICAL: You MUST log out and log back in for all changes to take effect. !!!"
#--- END OF FILE ---
