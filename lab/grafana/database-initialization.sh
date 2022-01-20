#!/bin/bash
MARIADB_SERVER_HOST="silvios-demo-1.mariadb.database.azure.com"
MARIADB_SERVER_USER_ADMIN_NAME="sofia"
MARIADB_SERVER_ADMIN_PASSWORD=""

mysql \
  --ssl \
  --host "${MARIADB_SERVER_HOST?}" \
  --user "${MARIADB_SERVER_USER_ADMIN_NAME?}" \
  --password="${MARIADB_SERVER_ADMIN_PASSWORD?}" < database.sql

mysql \
  --ssl \
  --host "${MARIADB_SERVER_HOST?}" \
  --user "${MARIADB_SERVER_USER_ADMIN_NAME?}" \
  --password="${MARIADB_SERVER_ADMIN_PASSWORD?}" \
  infrastructure_telemetry
