#!/bin/sh
# Exit on any error
set -e

# Read the template file
TEMPLATE=$(cat /etc/pgbouncer/userlist.txt.template)

# Use sed to replace the placeholders with the actual environment variable values.
# This is more robust than envsubst as sed is available everywhere.
USERLIST=$(echo "${TEMPLATE}" | sed \
    -e "s/\${POSTGRES_ADMIN_PASSWORD}/${POSTGRES_ADMIN_PASSWORD}/g" \
    -e "s/\${TRADING_APP_DB_PASSWORD}/${TRADING_APP_DB_PASSWORD}/g" \
    -e "s/\${LIBRARIAN_APP_DB_PASSWORD}/${LIBRARIAN_APP_DB_PASSWORD}/g")

# Write the final, substituted content to the target file
echo "${USERLIST}" > /etc/pgbouncer/userlist.txt

# Now, execute the original pgbouncer command
# Use 'exec' to replace this script's process with the pgbouncer process
exec /usr/bin/pgbouncer /etc/pgbouncer/pgbouncer.ini