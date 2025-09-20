
--- START OF FILE DATABASE_OPERATIONS_MANUAL.md (v1.2) ---

**`CENTRAL_DB_PLATFORM_MANUAL_V1.2.md`**
```markdown
# Central Database Platform: Operations Manual v1.2

This document provides the essential information for operating, maintaining, and integrating applications with the central data platform.

## 1. System Architecture

-   **Host:** Oracle Linux 10 (`aarch64`) on OCI.
-   **Primary Services:**
    -   **PostgreSQL 17:** The core relational database.
    -   **Redis 7.2:** The in-memory data store.
    -   **PgBouncer:** A lightweight connection pooler for PostgreSQL.
-   **Containerization:** All services are deployed via Docker and Docker Compose.
-   **Networking:** All platform services and connected applications communicate over a shared Docker bridge network named `central-data-platform`.

## 2. Architectural Decisions & Justifications (The "Why")

This section documents the reasoning behind key design choices to ensure long-term maintainability.

-   **Why FHS Compliance via `/srv`?**
    -   **Predictability:** The Filesystem Hierarchy Standard (FHS) designates `/srv` for "data for services provided by this system." By placing all application code, configuration, and persistent data under this single directory tree, any operator knows exactly where to look.
    -   **Portability & Recovery:** The entire platform's state is self-contained. A full backup and restore can be accomplished by archiving and restoring the `/srv` directory, dramatically simplifying disaster recovery.
    -   **Separation of Concerns:** It creates a clean boundary between the operating system's files (in `/etc`, `/var`, etc.) and our platform's files, preventing accidental conflicts.

-   **Why Centralized Secrets in `/srv/config/platform.env`?**
    -   **Single Source of Truth:** Managing secrets scattered across multiple `.env` files and configuration scripts is error-prone. A single, master secrets file reduces the chance of configuration drift and simplifies secret rotation.
    -   **Enhanced Security:** We can apply strict `600` permissions to this one file, ensuring it is only readable by the `root` user, and all service deployments must be explicitly run via `sudo` to access it.

-   **Why the `sudo docker compose --env-file ...` Pattern?**
    -   **Docker Compose's Order of Operations:** The `${VARIABLE}` syntax in a `docker-compose.yml` is substituted by the `docker compose` command *before* it processes the file. The `env_file:` directive *inside* a service only sets variables for the *running container*.
    -   **The Solution:** The `--env-file` command-line flag is the only reliable way to load variables for both build-time `args` and run-time `environment` variable substitutions. Using `sudo` is required to read the root-owned master secrets file.

-   **Why the `perconalab/percona-pgbouncer` Image?**
    -   **ARM64/aarch64 Compatibility:** This was the primary driver. During initial setup, other popular PgBouncer images were found to lack official support for the `linux/arm64` architecture of our OCI host. The Percona image was verified on Docker Hub to be multi-platform and is actively maintained.

-   **Why the `nc -z` Health Check for PgBouncer?**
    -   **Problem:** An earlier `psql`-based health check failed because the health check execution context does not have access to the secrets needed for authentication.
    -   **Solution:** A health check's primary goal is to confirm the service is alive and listening. `nc -z localhost 6432` (netcat) performs a simple, unauthenticated check to see if the port is open. This is a more robust and reliable test of service availability.

-   **Why the New Backup Script?**
    -   **Problem:** The legacy script used `docker exec ... > file.dump`, which is prone to I/O and pseudo-TTY (teletype) allocation issues that can corrupt the output stream.
    -   **Solution:** The new script uses `docker compose exec -T ... > file.dump`. The `-T` flag disables pseudo-TTY allocation, creating a clean, raw data stream suitable for redirection. The redirection happens on the host, which is more reliable than within the `exec` session.

## 3. Service Management & Deployment

-   **Master Secrets File:** All platform secrets are in `/srv/config/platform.env`.
-   **Deployment Command:** All services **MUST** be launched using the `sudo docker compose --env-file <path_to_env_file> up -d` pattern.
    -   **Platform Services:** `cd /srv/apps/postgres-stack && sudo docker compose --env-file /srv/config/platform.env up -d`
    -   **Application Services:** `cd /srv/apps/librarian && sudo docker compose --env-file ./server.env up -d`

## 4. Backup & Restore

-   **Backup Script:** A robust backup script is located at `/srv/apps/backup.sh`.
-   **To Perform a Manual Backup:** `sudo /srv/apps/backup.sh`
-   **To Restore a Backup:**
    1.  Copy the `.dump` file into the container: `docker cp /srv/backups/your_backup.dump postgres-db:/tmp/`
    2.  Execute the restore: `docker exec -it postgres-db pg_restore -U platform_admin -d <target_db> --clean /tmp/your_backup.dump`

## 5. Known Technical Debt & Critical Reminders

-   **[CRITICAL] Trading App Password Workaround:**
    -   **Problem:** The `trading-app` has a critical bug where it incorrectly uses its database password as the database port.
    -   **Workaround:** The password for `trading_app_user` has been intentionally set to the insecure value of `"6432"`.
    -   **Required Action:** The Trading App maintainer **must** fix the application's configuration logic. Once patched, a new secure password must be provisioned.

-   **[IMPORTANT] Oracle Linux 10 & ARM64 Architecture Considerations:**
    -   **Package Availability:** Not all software is available in the default OL10 repositories. Expect to manage repositories carefully.
    -   **Docker Image Compatibility:** The `aarch64` (ARM64) architecture is not universally supported. **Always verify `linux/arm64/v8` or `linux/aarch64` support on Docker Hub before selecting an image.** This remains the most common point of failure for this environment.

```
--- END OF FILE ---