**Role:** Act as a senior engineer embodying the combined expertise of a **Collaborative Systems Architect (`csa-1`)**, a **Site Reliability Engineer (`sre-1`)**, and a **Database Reliability Engineer (`dbre-1`)**.

When necessary and could improve the result both of qualitatively/quantitatively, embody alternative most appropriate persona other than those mentioned above.

**Core Operational Heuristic: A Three-Strike Protocol for Problem Solving**

Your primary methodology is to solve problems by starting with the most reliable methods and escalating to workarounds only when necessary. You must follow this protocol rigorously.

1.  **Attempt Standard Path (Strike 1):**
    *   **Action:** Propose and execute solutions based on your extensive training data and knowledge of standard, stable environments (e.g., CentOS, Oracle Linux 10).
    *   **Outcome:** If successful, proceed. If it fails, you must **HALT** the current path and move to Strike 2.

2.  **Attempt Documented Path (Strike 2):**
    *   **Action:** If the standard path fails, your next step is to guide me in finding the official documentation. You must:
        a.  State the command that failed and the error.
        b.  Provide recommended search terms and likely documentation hubs to help me find the correct guide.
        c.  After I provide the documentation, formulate a new plan based on the official, vendor-supported method.
    *   **Outcome:** If successful, proceed. If the documented path also fails or if no documentation can be found, you must **HALT** and move to Strike 3.

3.  **Propose a Conscious Workaround (Strike 3):**
    *   **Action:** If both standard and documented paths are exhausted, you are now permitted to propose a workaround. This proposal **MUST** be presented in a formal block and contain the following sections:
        *   **Problem Summary:** "The standard `yum install` and the documented `dnf config-manager` methods both failed to install Docker."
        *   **Proposed Workaround:** "I propose we add a third-party repository, which is not officially supported by Oracle but is known to contain the required `aarch64` packages."
        *   **Risk Analysis:**
            *   `[High]` This may introduce unsupported packages, potentially causing conflicts during future system updates.
            *   `[Medium]` The third-party repository may not be as secure or well-maintained as the official one.
            *   `[Low]` This will require manual configuration that must be documented to be reproducible.
        *   **Request for Consent:** "This is a deviation from best practices. Do you understand the risks and give consent to proceed with this workaround?"
    *   **Outcome:** You will only proceed with implementing the workaround after I give my explicit approval. Any implemented workaround **must** be logged as critical technical debt in the final documentation.

**Ask me to confirm each step before proceeding to the next part**

---


### **Preamble: Project Goals & Constraints**

This project is to redeploy a production-grade, multi-tenant central data platform on a fresh Oracle Linux 10 host. The design must prioritize long-term maintainability, security, and reproducibility for a solo operator.


**Core Requirements & Constraints:**

1.  **Target Environment:** The deployment target is **Oracle Linux 10**. All commands and package management must be compatible with this OS.
2.  **Architectural Principles:**
    *   **Strict FHS Compliance:** All application data, configuration, and backups must be located within the `/srv` directory, following the Filesystem Hierarchy Standard.
    *   **Design for Reproducibility:** The entire setup must be designed for Infrastructure-as-Code (IaC).
    *   **Multi-Tenant Database Design:** The database instance must be configured to securely serve at least two distinct applications with separate databases, users, and permissions.
3.  **Technical Specifications:**
    *   **Database Engine:** PostgreSQL version 17, provisioned with the `pgvector` extension.
    *   **In-Memory Store:** Redis/Redis-stack:7.2.0-v7, configured for data persistence.
    *   **Connection Pooling:** PgBouncer must be placed in front of the PostgreSQL database.
4.  **Input Artifacts:** I will provide detailed project blueprints for the two primary applications that will consume this database service:
    *   A high-throughput **"Trading App"**.
    *   A read-heavy **"Librarian (RAG) Service"**.
    *   A practical documentation of this legacy server **"DATABASE_OPERATIONS_MANUAL.md"**.
    You must analyze these blueprints to ensure the database architecture meets all their explicit and implicit requirements.

``
The development environment above will create a unique challenge of the deployment that you have to address:

1.  **Operating System:** Oracle Linux 10 (`aarch64`). This is a relatively new enterprise Linux distribution. Its default configurations, kernel settings, and security modules (like SELinux) can differ from more common development environments like Ubuntu or CentOS.
2.  **Hardware Architecture:** ARM64 (`aarch64`). While increasingly common, it can still have subtle differences in how software, especially low-level system software like container runtimes, is compiled and behaves compared to the more traditional x86_64 architecture.
3.  **Virtualization Platform:** OCI (Oracle Cloud Infrastructure). The underlying hypervisor and the specific storage drivers provided to the VM can influence how filesystem operations, like Docker's bind mounts for secrets, are handled.
4.  **Docker Version and Configuration:** The specific version of the Docker Engine (`docker-ce`) and its storage driver (likely `overlay2`) as well as percona-pgbouncer:1.24.1 interact with the OS kernel. The warning `secrets 'uid', 'gid' and 'mode' are not supported` strongly suggests an incompatibility or a configuration issue at this specific intersection of OS, kernel, and Docker Engine, even with a modern Docker Compose version.

This prompt codifies the lessons learned from the initial server deployment. It is designed to be a repeatable, "golden path" for recreating the entire platform, incorporating best practices for secret management, service configuration, and schema migration from the outset to prevent known failures.

**Core Principles of this Blueprint:**
*   **Centralized Secrets:** All secrets are managed in a single master file, `/srv/config/platform.env`.
*   **Explicit Configuration:** We use the `sudo docker compose --env-file ...` command pattern for all deployments to ensure variables are loaded correctly for both build-time and run-time.
*   **Robust Services:** Health checks are simple and reliable, and entrypoint scripts are written with minimal dependencies.
*   **Predictable Migrations:** The database provisioning and schema migration process is ordered to handle restored data correctly.

---

### **Part A: Host Preparation & Platform Deployment**

#### **Phase 1: Host Preparation & Directory Structure**

1.  **Run the Host Setup Script:** This script prepares the Oracle Linux 10 host with all necessary tools, permissions, and kernel tuning.

    ```bash
    # Create and run the host setup script
    tee ~/host_setup.sh > /dev/null <<'EOF'
    #!/bin/bash
    set -e
    echo "### Phase 1: Host Preparation ###"
    echo "[TASK 1] Updating system packages..."
    sudo dnf update -y --exclude=python3-pyOpenSSL
    echo "[TASK 2] Setting SELinux to permissive mode..."
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    echo "[TASK 3] Installing essential tools..."
    sudo dnf install -y git vim tree htop policycoreutils-python-utils
    echo "[TASK 4] Installing Docker Engine..."
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker ${USER}
    echo "[TASK 5] Applying PostgreSQL-specific kernel tuning..."
    cat <<'E_O_F' | sudo tee /etc/sysctl.d/99-postgresql.conf
    kernel.shmmax=17179869184
    kernel.shmall=4194304
    vm.overcommit_memory=1
    vm.swappiness=10
    E_O_F
    sudo sysctl -p /etc/sysctl.d/99-postgresql.conf
    echo "### Host setup complete. Please log out and log back in for docker group changes to take effect. ###"
    EOF
    chmod +x ~/host_setup.sh && ~/host_setup.sh

    # CRITICAL: You must log out and log back in now.
    exit
    ```

2.  **Create FHS Structure and Shared Docker Network:**

    ```bash
    # Reconnect to the server via SSH before proceeding.
    sudo mkdir -p /srv/{data,config,backups,apps}
    sudo mkdir -p /srv/data/{postgres,redis}
    sudo mkdir -p /srv/config/{pgbouncer,trading-app}
    sudo mkdir -p /srv/apps/{postgres-stack,redis-stack}
    sudo mkdir -p /opt/secrets # For legacy librarian path
    docker network create central-data-platform
    ```

#### **Phase 2: Centralized Secrets & Platform Configuration**

1.  **Create the Master Secrets File:** This is the single source of truth for all secrets.

    ```bash
    sudo tee /srv/config/platform.env > /dev/null <<'EOF'
    # --- PostgreSQL & PgBouncer Platform Passwords ---
    POSTGRES_ADMIN_PASSWORD=REPLACE_WITH_YOUR_POSTGRES_ADMIN_PASSWORD
    PGBOUNCER_PASSWORD=REPLACE_WITH_YOUR_PGBOUNCER_PASSWORD

    # --- Redis Platform Password ---
    REDIS_PASSWORD=REPLACE_WITH_YOUR_REDIS_PASSWORD

    # --- Application Tenant Passwords ---
    # [CRITICAL WORKAROUND] The trading_app_user password MUST be "6432" due to an application bug.
    TRADING_APP_DB_PASSWORD=6432
    LIBRARIAN_APP_DB_PASSWORD=REPLACE_WITH_YOUR_LIBRARIAN_APP_DB_PASSWORD
    EOF
    sudo chmod 600 /srv/config/platform.env
    ```

2.  **Create PgBouncer Configuration and the Robust Entrypoint Script:**

    ```bash
    # pgbouncer.ini (no changes)
    sudo tee /srv/config/pgbouncer/pgbouncer.ini > /dev/null <<'EOF'
    [databases]
    * = host=postgres port=5432
    [pgbouncer]
    listen_addr = 0.0.0.0
    listen_port = 6432
    auth_type = md5
    auth_file = /etc/pgbouncer/userlist.txt
    admin_users = platform_admin
    stats_users = platform_admin
    pool_mode = transaction
    server_reset_query = DISCARD ALL
    max_client_conn = 2000
    default_pool_size = 20
    EOF

    # The userlist TEMPLATE file
    sudo tee /srv/config/pgbouncer/userlist.txt.template > /dev/null <<'EOF'
    "platform_admin" "${POSTGRES_ADMIN_PASSWORD}"
    "trading_app_user" "${TRADING_APP_DB_PASSWORD}"
    "librarian_user" "${LIBRARIAN_APP_DB_PASSWORD}"
    EOF

    # The sed-based entrypoint script that does not require 'envsubst'
    sudo tee /srv/apps/postgres-stack/pgbouncer_entrypoint.sh > /dev/null <<'EOF'
    #!/bin/sh
    set -e
    TEMPLATE=$(cat /etc/pgbouncer/userlist.txt.template)
    USERLIST=$(echo "${TEMPLATE}" | sed \
        -e "s/\${POSTGRES_ADMIN_PASSWORD}/${POSTGRES_ADMIN_PASSWORD}/g" \
        -e "s/\${TRADING_APP_DB_PASSWORD}/${TRADING_APP_DB_PASSWORD}/g" \
        -e "s/\${LIBRARIAN_APP_DB_PASSWORD}/${LIBRARIAN_APP_DB_PASSWORD}/g")
    echo "${USERLIST}" > /etc/pgbouncer/userlist.txt
    exec /usr/bin/pgbouncer /etc/pgbouncer/pgbouncer.ini
    EOF
    sudo chmod +x /srv/apps/postgres-stack/pgbouncer_entrypoint.sh
    ```

3.  **Create Hardened `docker-compose.yml` Files for the Platform:**

    ```bash
    # For postgres-stack
    sudo tee /srv/apps/postgres-stack/docker-compose.yml > /dev/null <<'EOF'
    services:
      postgres:
        image: pgvector/pgvector:pg17
        container_name: postgres-db
        restart: always
        environment:
          - POSTGRES_DB=postgres
          - POSTGRES_USER=platform_admin
          - POSTGRES_PASSWORD=${POSTGRES_ADMIN_PASSWORD}
        volumes:
          - /srv/data/postgres:/var/lib/postgresql/data
        networks:
          - central-data-platform
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U platform_admin -d postgres"]
          interval: 10s
          timeout: 5s
          retries: 5
      pgbouncer:
        image: perconalab/percona-pgbouncer:1.24.1
        container_name: pgbouncer
        restart: always
        environment:
          - DB_HOST=postgres
          - DB_USER=pgbouncer
          - DB_PASSWORD=${PGBOUNCER_PASSWORD}
          - DB_NAME=postgres
          - POSTGRES_ADMIN_PASSWORD=${POSTGRES_ADMIN_PASSWORD}
          - TRADING_APP_DB_PASSWORD=${TRADING_APP_DB_PASSWORD}
          - LIBRARIAN_APP_DB_PASSWORD=${LIBRARIAN_APP_DB_PASSWORD}
        ports:
          - "6432:6432"
        entrypoint: /app/pgbouncer_entrypoint.sh
        volumes:
          - /srv/config/pgbouncer/pgbouncer.ini:/etc/pgbouncer/pgbouncer.ini:ro
          - /srv/config/pgbouncer/userlist.txt.template:/etc/pgbouncer/userlist.txt.template:ro
          - ./pgbouncer_entrypoint.sh:/app/pgbouncer_entrypoint.sh:ro
        networks:
          - central-data-platform
        depends_on:
          postgres:
            condition: service_healthy
        healthcheck:
          test: ["CMD", "nc", "-z", "localhost", "6432"]
          interval: 15s
          timeout: 10s
          retries: 5
    networks:
      central-data-platform:
        external: true
    EOF

    # For redis-stack
    sudo tee /srv/apps/redis-stack/docker-compose.yml > /dev/null <<'EOF'
    services:
      redis:
        image: redis/redis-stack:7.2.0-v7
        container_name: redis-stack
        restart: always
        ports:
          - "6379:6379"
          - "8001:8001"
        environment:
          - REDIS_ARGS=--requirepass ${REDIS_PASSWORD}
        volumes:
          - /srv/data/redis:/data
        networks:
          - central-data-platform
        healthcheck:
          test: ["CMD", "redis-cli", "-h", "localhost", "-p", "6379", "--raw", "ping"]
          interval: 10s
          timeout: 5s
          retries: 5
    networks:
      central-data-platform:
        external: true
    EOF
    ```

4.  **Launch the Central Data Platform:**

    ```bash
    # IMPORTANT: We use 'sudo' because the command needs to read the root-owned secrets file.
    # We use '--env-file' to load variables for substitution in the docker-compose.yml.
    cd /srv/apps/postgres-stack
    sudo docker compose --env-file /srv/config/platform.env up -d
    cd /srv/apps/redis-stack
    sudo docker compose --env-file /srv/config/platform.env up -d

    # Verify that all platform services are healthy
    echo "Verifying platform services... wait for all to show '(healthy)'"
    sleep 20 && docker ps
    ```

---

### **Part B: Application Provisioning & Deployment**

#### **Phase 3: Database Provisioning, Data Restore, and Schema Migration**

1.  **Create Application Databases, Users, and Grant Schema Permissions:**

    ```bash
    # Get passwords from the master secrets file
    TRADING_PASS=$(sudo grep TRADING_APP_DB_PASSWORD /srv/config/platform.env | cut -d'=' -f2)
    LIBRARIAN_PASS=$(sudo grep LIBRARIAN_APP_DB_PASSWORD /srv/config/platform.env | cut -d'=' -f2)

    # Provision Trading App DB
    docker exec postgres-db psql -U platform_admin -d postgres -c "CREATE DATABASE trading_db;"
    docker exec postgres-db psql -U platform_admin -d postgres -c "CREATE USER trading_app_user WITH PASSWORD '${TRADING_PASS}';"
    docker exec postgres-db psql -U platform_admin -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE trading_db TO trading_app_user;"
    docker exec postgres-db psql -U platform_admin -d trading_db -c "GRANT ALL ON SCHEMA public TO trading_app_user;"

    # Provision Librarian DB
    docker exec postgres-db psql -U platform_admin -d postgres -c "CREATE DATABASE librarian_db;"
    docker exec postgres-db psql -U platform_admin -d postgres -c "CREATE USER librarian_user WITH PASSWORD '${LIBRARIAN_PASS}';"
    docker exec postgres-db psql -U platform_admin -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE librarian_db TO librarian_user;"
    docker exec postgres-db psql -U platform_admin -d librarian_db -c "GRANT ALL ON SCHEMA public TO librarian_user;"
    docker exec postgres-db psql -U platform_admin -d librarian_db -c "CREATE EXTENSION IF NOT EXISTS vector;"
    ```

2.  **Restore Data from Backup:**
    *   **Action:** Manually upload your latest database backup file (e.g., `latest_trading_db.dump`) to `/srv/backups/`.

    ```bash
    # Command to run AFTER uploading the backup file
    docker cp /srv/backups/latest_trading_db.dump postgres-db:/tmp/backup.dump
    docker exec postgres-db pg_restore -U platform_admin -d trading_db --clean /tmp/backup.dump
    ```

3.  **Clone Application Codebases:**

    ```bash
    cd /srv/apps
    sudo git clone <YOUR_TRADING_APP_REPO_URL> trading-app
    sudo git clone <YOUR_LIBRARIAN_SERVICE_REPO_URL> librarian
    # Recreate necessary secret/config files for the apps
    sudo tee /srv/config/trading-app/trading_app_password.txt > /dev/null <<< "${TRADING_PASS}"
    sudo tee /opt/secrets/librarian_app_db_password.txt > /dev/null <<< "${LIBRARIAN_PASS}"
    # ... recreate other app-specific .env files as needed ...
    ```

4.  **Run Schema Migrations (The Correct Way):**
    This `downgrade` and `upgrade` sequence is critical to force Alembic to apply the schema on top of the restored data.

    ```bash
    cd /srv/apps/trading-app
    sudo docker compose --env-file ./.env --env-file /srv/config/platform.env run --rm migrator alembic downgrade base
    sudo docker compose --env-file ./.env --env-file /srv/config/platform.env run --rm migrator alembic upgrade head
    ```

#### **Phase 4: Launch and Verify Applications**

1.  **Launch the Trading App:**

    ```bash
    cd /srv/apps/trading-app
    # The command pattern uses both the local .env and the global platform.env
    sudo docker compose --env-file ./.env --env-file /srv/config/platform.env up -d --build
    ```

2.  **Launch the Librarian Service:**

    ```bash
    cd /srv/apps/librarian
    # This command uses the app's server.env for build args
    sudo docker compose --env-file ./server.env up -d --build
    ```

3.  **Final System-Wide Verification:**

    ```bash
    echo "### Verifying final system state... ###"
    sleep 15
    docker ps
    echo "--- Checking Trading App Logs ---"
    docker logs trading-app-distributor-1 --tail 20
    echo "--- Checking Librarian Service Logs ---"
    docker logs librarian-service --tail 20
    ```

    
## **Part C: OCI Integration, Hardening & Documentation**

### **Phase 5: OCI CLI Setup & Configuration**

**Your Task:**
1.  **Provide OCI CLI Installation & Configuration Steps:** Provide the commands to install the `oci-cli` and guide me through the `oci setup config` process.

### **Phase 6: Cloud Integration & Hardening (OCI CLI/Console)**

**Your Task:** Provide clear, step-by-step instructions (preferring CLI commands) to perform the following actions. Remember to apply the **Core Operational Heuristic** if any of these cloud interactions fail.
1.  **Configure Docker for OCI Logging:** Provide the content for `/etc/docker/daemon.json` to configure the `oci` log driver and explain how to find the necessary Log OCID from the OCI console. Provide the command to restart Docker.
2.  **Set Up Off-site Backups:** Provide the `oci-cli` command to create an Object Storage bucket and the `upload_to_oci.sh` script to push backups to it.
3.  **Harden the Network with an NSG:** Provide the `oci-cli` commands to create a Network Security Group, add a default-deny policy, add a stateful ingress rule for SSH from a specific IP, and associate the NSG with the VM's network interface.
4.  **Set Up OCI Monitoring & Alarms:** Guide me on how to create free-tier-compliant alarms in the OCI console for critical host metrics.

### **Phase 6: Final Documentation Generation**

**Your Task:** Generate a Markdown file named `DATABASE_OPERATIONS_MANUAL.md`. This document must include:
1.  **Architecture Overview:** A summary of the final host and container layout.
2.  **Key Configurations & Justifications:** A summary of critical settings.
3.  **Runbooks:** Clear procedures for Backup & Restore.
4.  **Monitoring Plan:** How to access logs and alarms in OCI.
5.  **Known Technical Debt & Growth Path:** A critical section listing future improvements. This section **must** document any steps where we had to deviate from standard practice and fall back to requesting official documentation, as these highlight areas of environmental friction.


### **Phase 7: Additional context**

I just migrated all resources in the cloud from root to a separate compartment. Current compartments (each with its own vnics): 
shared-services: will be hosted compute engine for postgres and redis
RAG-Project: will be hosted serverless function
Root: previously, all of the above compartments consolidated into root. Now, the root contains nothing
The non-root compartments setting is not completed yet. 
Based on above situations, dont assume on any naming/variables/settings related to OCI. 
