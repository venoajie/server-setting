FROM postgres:17

# Switch to the root user to install packages
USER root

# Update the package list and install pgbouncer
# --no-install-recommends keeps the image smaller
RUN apt-get update && \
    apt-get install -y --no-install-recommends pgbouncer && \
    rm -rf /var/lib/apt/lists/*

# Switch back to the default postgres user for security
USER postgres