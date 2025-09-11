
# Use the official Postgres 17 image as our base
FROM postgres:17

# Switch to the root user to install packages and create directories
USER root

# Update the package list and install pgbouncer
RUN apt-get update && \
    apt-get install -y --no-install-recommends pgbouncer && \
    rm -rf /var/lib/apt/lists/*

# SRE-1: Create the log directory and give the 'postgres' user ownership.
# This ensures pgbouncer can write its log file.
RUN mkdir -p /var/log/pgbouncer && \
    chown -R postgres:postgres /var/log/pgbouncer

# Switch back to the default postgres user for security
USER postgres