#!/bin/sh
set -eu

db_status=$(MYSQL_PWD="${MARIADB_ROOT_PASSWORD}" mariadb-admin \
    --protocol=socket -uroot status)
load_avg=$(awk '{print $1","$2","$3}' /proc/loadavg)
memory_available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
mysql_disk_used=$(df -P /var/lib/mysql | awk 'NR == 2 {print $5}')
timestamp=$(date -u +%FT%TZ)

printf 'DB_METRICS timestamp=%s load_avg=%s mem_available_kb=%s mysql_disk_used=%s %s\n' \
    "$timestamp" "$load_avg" "$memory_available" "$mysql_disk_used" "$db_status" \
    | tee -a /var/log/mysql/metrics.log
