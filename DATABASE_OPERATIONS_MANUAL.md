
# Central Database Platform: Operations Manual v1.1

This document provides the essential information for operating, maintaining, and integrating applications with the central data platform deployed on the Oracle Linux 10 (`aarch64`) host.

## 1. System Architecture

-   **Host:** Oracle Linux 10 (`aarch64`) on OCI.
-   **Primary Services:**
    -   **PostgreSQL 17:** The core relational database (`pgvector` enabled).
    -   **Redis 7.2:** The in-memory data store.
    -   **PgBouncer:** A lightweight connection pooler for PostgreSQL.
-   **Containerization:** All services are deployed via Docker and Docker Compose across multiple stacks (`postgres-stack`, `redis-stack`, `trading-app`, `librarian`).
-   **FHS Compliance:** All application code, configuration, and persistent data are strictly contained within the `/srv` directory tree for portability and simplified disaster recovery.
-   **Networking:** All platform services and connected applications communicate over a shared Docker bridge network named `central-data-platform`.

## 2. Architectural Decisions & Justifications (The "Why")

This section documents the reasoning behind key design choices to ensure long-term maintainability.

-   **Why Centralized Secrets in `/srv/config/platform.env`?**
    -   **Single Source of Truth:** A single, master secrets file with strict `600` permissions reduces configuration drift and simplifies secret rotation.

-   **Why the `wait-for.sh` Entrypoint Script?**
    -   **Problem:** Docker Compose does not guarantee the startup order of dependencies, especially for services in separate files (like `redis` and `trading-app`). This created a race condition where applications would fail to start because they couldn't resolve the DNS for `redis` or `pgbouncer` before those services were fully initialized.
    -   **Solution:** A generic, POSIX-compliant `wait-for.sh` script was implemented as the `ENTRYPOINT` for all application containers. This script forces each container to actively wait until its network dependencies (e.g., `pgbouncer:6432`, `redis:6379`) are available before executing the main application command, making the entire startup sequence robust and resilient.

-   **Why the `nc -z` Health Check for PgBouncer?**
    -   **Problem:** The `perconalab/percona-pgbouncer` image is minimal and does not contain the `psql` or `pg_isready` client tools, making authenticated health checks impossible.
    -   **Solution:** The `nc -z` (netcat) command performs a simple, unauthenticated check to confirm the port is open. Combined with a `start_period` of 20 seconds, this provides a reliable health check that is compatible with the minimal container environment.

### 2.2. Vault & Secret Management

-   **Vault:** `RAG-Project-Vault`
-   **Secret:** `librarian-db-connection`
-   **Function Configuration (`DB_SECRET_OCID`):** The function **must** be configured with the OCID of the **Secret** (`ocid1.vaultsecret...`), not the Vault.
-   **Secret Content:** The secret must contain a **structured JSON object** with the database credentials, using the **Private IP** of the database VM.
    -   Format:
        ```json
        {
          "username": "librarian_user",
          "password": "YOUR_DATABASE_PASSWORD",
          "host": "10.0.0.146",
          "port": 6432,
          "dbname": "librarian_db"
        }
        ```
-   **CRITICAL NOTE on Connection String Dialect:** The serverless function code constructs the database connection string internally. It uses the `postgresql+psycopg2://` dialect to ensure compatibility with SQLAlchemy's parameter expansion features for `IN` clauses, even while using the modern `psycopg` (v3) library. This is a deliberate choice for robustness.


## 3. Runbooks

### 3.1. Critical Label Data Backup (High-Frequency)
This procedure backs up only the irreplaceable `trade_id`/`order_id` and `label` data for active transactions.

-   **To Perform a Manual Backup:**
    ```bash
    sudo /srv/apps/backup_active_labels.sh
    ```
-   **Automation:** This script is configured via `crontab` to run every 5 minutes.

### 3.2. Full Label Data Backup (Daily Archival)
This procedure backs up the `label` data for all transactions (active and inactive).

-   **To Perform a Manual Backup:**
    ```bash
    sudo /srv/apps/backup_all_labels.sh
    ```
-   **Automation:** This script is configured via `crontab` to run daily at 3:05 AM.

### 3.3. Full Database Backup (Disaster Recovery)
This procedure performs a full structural and data dump of the databases.

-   **To Perform a Manual Backup:**
    ```bash
    sudo /srv/apps/backup.sh
    ```

### 3.4. Recovery from Backup (Labels Only)
1.  Allow the application to re-populate transaction data from the exchange APIs.
2.  Download the latest label backup CSV from OCI Object Storage.
3.  Write and execute a recovery script to run `UPDATE` statements on the `orders` table, applying the labels from the CSV file.

## 4. Monitoring & Logging

-   **Container Status:** The primary command for checking service health is `docker ps`.
-   **Log Management:** The system uses Docker's default `json-file` logging driver for maximum reliability.
    -   **To view live logs for a service:**
        ```bash
        docker logs -f <container_name>
        # Example: docker logs -f trading-app-distributor-1
        ```
    -   **To find the persistent log file for a container:**
        ```bash
        LOG_PATH=$(docker inspect --format='{{.LogPath}}' <container_name>)
        sudo tail -f $LOG_PATH
        ```
## 5. External Access & Firewall
The database is accessible to the serverless ingestor function via the PgBouncer port (`6432`). This requires a specific ingress rule in the VCN Security List and an open port in the host's `firewalld`. See `CLOUD_INFRASTRUCTURE_GUIDE.md` for the authoritative VCN configuration."

### 5.1. Host Firewall and Docker Networking

"If an external service (like the OCI Function) times out when connecting, but the OCI Network Path Analyzer shows the path is 'Reachable', the problem is on the host. Follow these steps:"
	1.  "**Check the host firewall:** `sudo firewall-cmd --list-all`. Ensure the required port (e.g., `6432/tcp`) is listed."
	2.  "**Check the listening service:** `sudo ss -tlnp | grep 6432`. Confirm the service is listening on `0.0.0.0` and not `127.0.0.1`."
	3.  "**Reset Docker's network rules (The 'Big Hammer'):** If the above are correct, Docker's internal `iptables` rules may be stale. Flush the rules and restart Docker to force a rebuild:
		```bash
		sudo iptables -F
		sudo iptables -t nat -F
		sudo systemctl restart docker
		```"


## 6. Known Technical Debt & Growth Path

-   **[CRITICAL] Trading App Password Workaround:**
    -   **Problem:** The `trading-app` has a critical bug where it incorrectly uses its database password as the database port.
    -   **Workaround:** The password for `trading_app_user` has been intentionally set to the insecure value of `"6432"`.
    -   **Required Action:** The Trading App maintainer **must** fix the application's configuration logic. Once patched, a new secure password must be provisioned.

-   **[IMPORTANT] Centralized Logging on ARM Architecture:**
    -   **Problem:** Our goal of implementing a native, off-host centralized logging solution was blocked by two platform limitations discovered during deployment:
        1.  The OCI Docker Log Driver plugin could not be pulled from Docker Hub due to a network or authentication block specific to this server's environment.
        2.  The native Oracle Cloud Agent's **Custom Logs Monitoring plugin is not supported on ARM-based instances**, making it impossible to tail Docker log files.
    -   **Current State:** We have reverted to the reliable default `json-file` driver. Logs are stored on the host's local disk.
    -   **Growth Path:** For a more robust production setup, the recommended path is to deploy a dedicated log-shipping container (e.g., Fluentd, Vector) that is configured to collect the JSON log files from `/var/lib/docker/containers/` and forward them to a desired destination (like OCI Logging). This would achieve the original goal while bypassing the platform limitations.
