#!/bin/sh
set -eu

until MYSQL_PWD="${MARIADB_ROOT_PASSWORD}" mariadb-admin \
    --protocol=socket -uroot ping --silent >/dev/null 2>&1; do
    sleep 2
done

while true; do
    /usr/local/bin/database-metrics.sh
    sleep 60
done
