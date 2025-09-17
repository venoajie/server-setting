### **3. Key Metrics to Monitor at both the Host and Database level**

**Where to See Metrics:**
*   **Host Metrics (CPU/Memory):** **OCI Console** -> `Observability & Management` -> `Monitoring` -> `Metric Explorer`. Select the `oci_computeagent` namespace and the `CpuUtilization` or `MemoryUtilization` metric. Your alarms are already configured here.
*   **Database Metrics:** Inside the PostgreSQL container via `psql`.

**Key Metrics & How to Check Them:**

1.  **Cache Hit Ratio (Most Important DB Performance Metric):**
    *   **What it is:** The percentage of data requests that are served from memory (fast) versus disk (slow). For a healthy, read-heavy application, this should be **above 99%**.
    *   **How to check:**
        ```sql
        -- Connect to the target database (e.g., trading_db)
        \c trading_db

        -- Run the query
        SELECT
          'cache_hit_rate' AS metric,
          (sum(heap_blks_hit) - sum(heap_blks_read)) / sum(heap_blks_hit) * 100 AS value
        FROM pg_statio_user_tables;
        ```

2.  **Index Usage:**
    *   **What it is:** Checks if your indexes are actually being used. Unused indexes waste space and slow down writes.
    *   **How to check:**
        ```sql
        SELECT
          relname AS table_name,
          indexrelname AS index_name,
          idx_scan AS times_used
        FROM pg_stat_all_indexes
        WHERE schemaname = 'public' AND idx_scan = 0 AND indexrelname NOT LIKE 'pg_toast_%'
        ORDER BY relname, indexrelname;
        ```
    *   **What to look for:** Any frequently used table with an index that has `times_used` of `0` is a candidate for removal.

3.  **Connection Pool Status:**
    *   **What it is:** Shows how many client connections are active and how many server connections PgBouncer is using.
    *   **How to check:**
        ```bash
        # On the host
        sudo docker exec -it pgbouncer psql -h localhost -p 6432 -U platform_admin pgbouncer -c "SHOW POOLS;"
        ```
    *   **What to look for:** The number of `sv_active` (server) connections should be much lower than `cl_active` (client) connections, proving the pooler is working.

---

### **4. Constraints for New Users/Applications**

These are the critical rules and limitations that you and any new developers must be aware of.

1.  **Architecture is ARM64 (`aarch64`):** This is the most important constraint. Any new application or tool you wish to deploy **must** have a Docker image that supports the `linux/arm64` architecture. Always verify this on Docker Hub first.
2.  **Connection is via PgBouncer, Not Directly to PostgreSQL:** All applications **must** connect to the database via the PgBouncer service on port `6432`. Do not connect directly to the PostgreSQL container on port `5432`. This ensures all connections are properly pooled.
3.  **Database Provisioning is Centralized:** Developers cannot create their own databases or users. They must follow the official process (see Prompt 1) to have them provisioned by the platform operator. This maintains security and isolation.
4.  **Network is Isolated:** All communication happens on the `central-data-platform` Docker network. Your application's `docker-compose.yml` **must** be configured to use this external network.
5.  **Schema Migrations via Alembic:** For any application using the database, initial schema setup can be done via an `init.sql` script, but all subsequent changes **must** be managed through a migration tool like Alembic. Direct `ALTER TABLE` commands on a production database are forbidden.