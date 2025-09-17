**`CENTRAL_DB_PLATFORM_MANUAL_V1.md`**
```markdown
# Central Database Platform: Operations Manual v1.0

This document provides the essential information for operating, maintaining, and integrating applications with the central data platform.

## 1. System Architecture

-   **Host:** Oracle Linux 10 (`aarch64`) on OCI.
-   **Primary Services:**
    -   **PostgreSQL 17:** The core relational database.
    -   **Redis 7.2:** The in-memory data store.
    -   **PgBouncer:** A lightweight connection pooler for PostgreSQL.
-   **Containerization:** All services are deployed via Docker and Docker Compose.
-   **Networking:** All platform services and connected applications communicate over a shared Docker bridge network named `central-data-platform`.
-   **FHS Compliance:** All persistent data and configuration are located under `/srv` for predictable management.

## 2. Connecting a New Application

To connect a new application to the platform, follow these steps:

1.  **Request a Database and User:** A dedicated database and user must be provisioned for your application to ensure multi-tenant isolation. Provide the application name to the platform operator.
2.  **Receive Credentials:** The operator will provide you with a username, password, and database name.
3.  **Configure Your Application:**
    -   **Database Host:** `pgbouncer`
    -   **Database Port:** `6432`
    -   **Redis Host:** `redis-stack`
    -   **Redis Port:** `6379`
4.  **Docker Compose Integration:**
    -   Your application's `docker-compose.yml` must declare the `central-data-platform` network as external:
        ```yaml
        networks:
          central-data-platform:
            external: true
        ```
    -   Each of your application's services must be attached to this network.

## 3. Maintenance & Troubleshooting

-   **Service Management:** All platform services are managed via `docker compose` in their respective directories (`/srv/apps/postgres-stack`, `/srv/apps/redis-stack`).
-   **Logs:** All container logs are centralized in the OCI Logging service. Check the configured Log Group in the OCI console for troubleshooting.
-   **Monitoring:** Host CPU and Memory are monitored in OCI. Alarms will be sent via email for critical thresholds.
-   **Checking DB Size:**
    ```bash
    # Connect to the container
    sudo docker exec -it postgres-db psql -U platform_admin -d postgres

    # Run sizing query
    SELECT pg_size_pretty(pg_database_size('your_db_name'));
    ```

## 4. Known Technical Debt & Critical Reminders

This platform is operational but has known issues and environmental constraints that require careful management.

-   **[CRITICAL] Backup Automation is Non-Functional:** The automated backup script at `/srv/apps/backup.sh` is not working. The root cause is a complex I/O issue with `docker exec`. **Manual backups are currently required for disaster recovery.** This is the highest priority item to resolve.
-   **[Medium] PgBouncer Entrypoint Errors:** The `percona-pgbouncer` container logs non-fatal permission errors on startup. While the service works, this indicates a minor configuration mismatch that should be investigated.
-   **[IMPORTANT] Oracle Linux 10 & ARM64 Architecture Considerations:**
    -   **Package Availability:** Not all software is available in the default OL10 repositories. The `htop` utility, for example, required enabling the EPEL repository. Expect to manage repositories carefully.
    -   **Docker Image Compatibility:** The `aarch64` (ARM64) architecture is not universally supported by all Docker image authors. We encountered this with the first PgBouncer image. **Always verify `linux/arm64/v8` or `linux/aarch64` support on Docker Hub before selecting an image.** This is the most common point of failure for this environment.

```

---

### **2. Memo to Application Maintainers**

**To:** Trading App Maintainer, Librarian Service Maintainer
**From:** Platform Engineering (`csa-1`, `sre-1`, `dbre-1`)
**Date:** 2025-09-14
**Subject:** MANDATORY: Migration to Centralized Data Platform and Current Application Status

Team,

This memo is to inform you that the new Central Data Platform is now operational. As per our architectural roadmap, all stateful services are being migrated from self-contained databases to this shared, production-grade platform.

**What This Means for You:**

1.  **New Reality:** Your applications (`trading-app`, `librarian-service`) no longer manage their own PostgreSQL or Redis instances. They are now clients of the central platform.
2.  **Configuration Changes:** The `docker-compose.yml` files for your applications have been modified to connect to the central services (`pgbouncer`, `redis-stack`) over the shared `central-data-platform` network.
3.  **Credential Management:** Database credentials are now managed centrally. Your applications read their passwords from Docker secrets mounted from the host filesystem.

**Current Application Status & Required Actions:**

-   **Trading App:** The application is **running but in a degraded state**. It is successfully connected to the central PostgreSQL and Redis instances. However, it is failing to authenticate with the external Deribit API due to invalid credentials.
    -   **ACTION REQUIRED:** You must investigate and provide the correct Deribit API key and secret in the files located at `/srv/apps/trading-app/secrets/`.

-   **Librarian Service:** The application is **currently failing to start**. It is successfully connecting to the central database, but it crashes on initialization due to a `ValidationError`.
    -   **ACTION REQUIRED:** The application requires three mandatory environment variables (`OCI_BUCKET_NAME`, `OCI_PROJECT_NAME`, `OCI_INDEX_BRANCH`) that are missing from its `server.env` configuration file. You must provide these values to resolve the startup failure.

Please prioritize these actions to bring your applications to a fully healthy state on the new platform. Refer to the `CENTRAL_DB_PLATFORM_MANUAL_V1.md` for details on the new architecture.

---

### **3. General Database Readiness Testing**

This is a quick, high-level assessment of the database's readiness for production workloads.

**1. Connection Pooling Test (PgBouncer):**
   - **Objective:** Verify that PgBouncer is correctly pooling connections.
   - **Method:** We will check the active connection stats in PgBouncer.
   - **Command:**
     ```bash
     # Connect to the pgbouncer admin console
     sudo docker exec -it pgbouncer psql -h localhost -p 6432 -U platform_admin pgbouncer

     # Inside psql, run the command to show pool stats
     SHOW POOLS;
     \q
     ```
   - **Success Criteria:** The output should show pools for `trading_db` and `librarian_db`. The `cl_active` (client active) and `sv_active` (server active) columns should be low, indicating that connections are being efficiently reused, even with multiple application services running.

**2. Basic Write/Read Throughput Metric (Benchmark):**
   - **Objective:** Get a rough baseline of the database's write performance for a simple workload.
   - **Method:** Use `pgbench`, the standard PostgreSQL benchmarking tool, to initialize a test dataset and run a simple transaction benchmark.
   - **Commands:**
     ```bash
     # Step A: Initialize a test dataset in a new test database
     sudo docker exec -it postgres-db psql -U platform_admin -c "CREATE DATABASE pgbench;"
     sudo docker exec -it postgres-db pgbench -i -U platform_admin pgbench

     # Step B: Run a 1-minute benchmark with 8 concurrent clients
     sudo docker exec -it postgres-db pgbench -U platform_admin -c 8 -T 60 pgbench
     ```
   - **Metric to Record:** The command will output a "tps" (transactions per second) value. For this hardware (OCI Ampere A1), a healthy baseline for this simple test would be in the range of **500-1500 TPS**. A significantly lower number could indicate a disk I/O bottleneck. This value should be recorded as our initial performance baseline.

**3. Extension Functionality Test (`pgvector`):**
   - **Objective:** Verify that the `vector` type and its functions are fully operational.
   - **Method:** Connect to `librarian_db` and perform a simple create, insert, and query operation using a vector.
   - **Commands:**
     ```bash
     # Connect to the librarian_db
     sudo docker exec -it postgres-db psql -U platform_admin -d librarian_db

     # Inside psql, run these commands:
     CREATE TABLE test_vectors (id serial primary key, embedding vector(3));
     INSERT INTO test_vectors (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
     SELECT * FROM test_vectors ORDER BY embedding <-> '[1,2,3]' LIMIT 1;
     DROP TABLE test_vectors;
     \q
     ```
   - **Success Criteria:** The `SELECT` query should execute without error and return the row with the `[1,2,3]` embedding. This confirms the extension is correctly installed and its operators are working.

   
