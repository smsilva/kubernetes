#!/bin/bash

export MARIADB_SERVER_HOST="wasp-telemetry.mariadb.database.azure.com"
export MARIADB_SERVER_PORT="3306"
export MARIADB_SERVER_ADMIN_USERNAME="${USER}"
export GRAFANA_READER_PASSWORD=$(uuidgen)

source password.conf

echo "MARIADB_SERVER_HOST...........: ${MARIADB_SERVER_HOST}"
echo "MARIADB_SERVER_ADMIN_USERNAME.: ${MARIADB_SERVER_ADMIN_USERNAME}"
echo "MARIADB_SERVER_ADMIN_PASSWORD.: ${MARIADB_SERVER_ADMIN_PASSWORD:0:8}"
echo "MARIADB_DATABASE_NAME.........: ${MARIADB_DATABASE_NAME}"
echo "GRAFANA_READER_PASSWORD.......: ${GRAFANA_READER_PASSWORD}"

sed "s/GRAFANA_READER_PASSWORD/${MARIADB_SERVER_ADMIN_PASSWORD}/g" init-database-template.sql > init-database-temp.sql

mysql \
  --ssl \
  --host "${MARIADB_SERVER_HOST?}" \
  --user "${MARIADB_SERVER_ADMIN_USERNAME?}" \
  --password="${MARIADB_SERVER_ADMIN_PASSWORD?}" < init-database-temp.sql
