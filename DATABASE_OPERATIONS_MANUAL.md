# Central Database Platform: Operations Manual v1.0

This document provides the essential information for operating, maintaining, and integrating applications with the central data platform deployed on the Oracle Linux 10 (`aarch64`) host.

## 1. System Architecture

-   **Host:** Oracle Linux 10 (`aarch64`) on OCI.
-   **Primary Services:**
    -   **PostgreSQL 17:** The core relational database (`pgvector` enabled).
    -   **Redis 7.2:** The in-memory data store.
    -   **PgBouncer:** A lightweight connection pooler for PostgreSQL.
-   **Containerization:** All services are deployed via Docker and Docker Compose.
-   **FHS Compliance:** All application code, configuration, and persistent data are strictly contained within the `/srv` directory tree for portability and simplified disaster recovery.
-   **Networking:** All platform services and connected applications communicate over a shared Docker bridge network named `central-data-platform`.

## 2. Architectural Decisions & Justifications (The "Why")

This section documents the reasoning behind key design choices to ensure long-term maintainability.

-   **Why FHS Compliance via `/srv`?**
    -   **Predictability & Portability:** The Filesystem Hierarchy Standard (FHS) designates `/srv` for "data for services provided by this system." By placing all platform state (code, config, data, backups) under this single directory, we create a self-contained, portable system. Disaster recovery is simplified to backing up and restoring this single directory.

-   **Why Centralized Secrets in `/srv/config/platform.env`?**
    -   **Single Source of Truth:** Managing secrets across multiple `.env` files is error-prone. A single, master secrets file with strict `600` permissions reduces configuration drift and simplifies secret rotation. All services source their secrets from this file.

-   **Why the `sudo docker compose --env-file ...` Pattern?**
    -   **Build-Time vs. Run-Time Scope:** The `--env-file` command-line flag is the only reliable way to load variables for both build-time `args` (used in Dockerfiles) and run-time variable substitutions in the `docker-compose.yml` file itself. The `env_file:` directive *inside* a service only applies to the running container.

-   **Why the `perconalab/percona-pgbouncer` Image?**
    -   **ARM64/aarch64 Compatibility:** This was the primary driver. This image is known to be multi-platform and stable on the `linux/arm64` architecture of our OCI host, avoiding compatibility issues found with other images.

-   **Why the `nc -z` Health Check for PgBouncer?**
    -   **Robustness:** Authenticated health checks (like `pg_isready`) can fail if the check's execution context lacks access to secrets. The `nc -z` (netcat) command performs a simple, unauthenticated check to confirm the port is open, which is a more reliable test of service availability. A long `start_period` was added to handle initial startup delays.

## 3. Runbooks

### 3.1. Backup
A robust backup script is located at `/srv/apps/backup.sh`. It handles dumping both databases and uploading them to a secure OCI Object Storage bucket.

-   **To Perform a Manual Backup:**
    ```bash
    sudo /srv/apps/backup.sh
    ```
-   **Recommended:** Configure this script to run as a nightly cron job.

### 3.2. Restore (Fresh Install Scenario)
This procedure is for rebuilding the `trading_db` from scratch without restoring data, as established during our deployment.

1.  **Drop the existing database:**
    ```bash
    docker exec postgres-db psql -U platform_admin -d postgres -c "DROP DATABASE trading_db WITH (FORCE);"
    ```
2.  **Re-create the database and grant permissions:**
    ```bash
    TRADING_PASS=$(sudo grep TRADING_APP_DB_PASSWORD /srv/config/platform.env | cut -d'=' -f2)
    docker exec postgres-db psql -U platform_admin -d postgres -c "CREATE DATABASE trading_db;"
    docker exec postgres-db psql -U platform_admin -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE trading_db TO trading_app_user;"
    docker exec postgres-db psql -U platform_admin -d trading_db -c "GRANT ALL ON SCHEMA public TO trading_app_user;"
    ```
3.  **Bootstrap the full schema using `init.sql`:**
    ```bash
    docker cp /srv/apps/trading-app/init.sql postgres-db:/tmp/init.sql
    docker exec postgres-db psql -U platform_admin -d trading_db -f /tmp/init.sql
    ```
4.  **Grant permissions on the new objects:**
    ```bash
    docker exec postgres-db psql -U platform_admin -d trading_db -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO trading_app_user;"
    docker exec postgres-db psql -U platform_admin -d trading_db -c "GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO trading_app_user;"
    ```
5.  **Stamp the database with the latest migration:**
    ```bash
    cd /srv/apps/trading-app
    sudo docker compose --env-file ./.env --env-file /srv/config/platform.env run --rm migrator alembic upgrade head
    ```

## 4. Monitoring & Logging

-   **Container Status:** The primary command for checking service health is `docker ps`.
-   **Log Management:** The system has been reverted to Docker's default `json-file` logging driver for maximum reliability.
    -   **To view live logs for a service:**
        ```bash
        docker logs -f <container_name>
        # Example: docker logs -f trading-app-distributor-1
        ```
    -   **To find the persistent log file for a container:**
        ```bash
        LOG_PATH=$(docker inspect --format='{{.LogPath}}' <container_name>)
        echo $LOG_PATH
        # Example: /var/lib/docker/containers/4078bba87e94.../...-json.log
        ```

## 5. Known Technical Debt & Growth Path

-   **[CRITICAL] Trading App Password Workaround:**
    -   **Problem:** The `trading-app` has a critical bug where it incorrectly uses its database password as the database port.
    -   **Workaround:** The password for `trading_app_user` has been intentionally set to the insecure value of `"6432"`.
    -   **Required Action:** The Trading App maintainer **must** fix the application's configuration logic. Once patched, a new secure password must be provisioned and updated in `/srv/config/platform.env`.

-   **[IMPORTANT] Centralized Logging on ARM Architecture:**
    -   **Problem:** Our goal of implementing a native, off-host centralized logging solution was blocked by two platform limitations:
        1.  The OCI Docker Log Driver plugin could not be pulled from Docker Hub due to a network or authentication block specific to this server's environment.
        2.  The native Oracle Cloud Agent's **Custom Logs Monitoring plugin is not supported on ARM-based instances**, making it impossible to tail Docker log files.
    -   **Current State:** We have reverted to the reliable default `json-file` driver. Logs are stored on the host's local disk and are subject to rotation policies in `/etc/docker/daemon.json`.
    -   **Growth Path:** For a more robust production setup, investigate implementing a third-party log shipper like **Fluentd**. A Fluentd container could be deployed on the host, configured to collect the JSON log files from `/var/lib/docker/containers/`, and forward them to OCI Logging. This would achieve the original goal while bypassing the platform limitations.

```