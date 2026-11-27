#!/bin/bash
set -Eeuo pipefail

: "${MARIADB_ROOT_PASSWORD:?MARIADB_ROOT_PASSWORD is required}"

mkdir -p /var/log/mysql /var/www /var/ossec/etc /var/ossec/logs /var/ossec/queue
chown mysql:mysql /var/log/mysql
chmod 0755 /var/log/mysql /var/www
touch /var/log/mysql/resource-metrics.json

chown -R wazuh:wazuh /var/ossec/etc /var/ossec/logs /var/ossec/queue

/usr/local/bin/docker-entrypoint.sh mariadbd &
db_pid=$!
agent_pid=
metrics_pid=
resource_pid=

cleanup() {
    trap - EXIT INT TERM

    if [ -n "$agent_pid" ] && kill -0 "$agent_pid" 2>/dev/null; then
        kill -TERM "$agent_pid" 2>/dev/null || true
    fi
    if /var/ossec/bin/wazuh-control status >/dev/null 2>&1; then
        /var/ossec/bin/wazuh-control stop >/dev/null 2>&1 || true
    fi
    if [ -n "$metrics_pid" ] && kill -0 "$metrics_pid" 2>/dev/null; then
        kill -TERM "$metrics_pid" 2>/dev/null || true
    fi
    if [ -n "$resource_pid" ] && kill -0 "$resource_pid" 2>/dev/null; then
        kill -TERM "$resource_pid" 2>/dev/null || true
    fi
    if [ -n "$db_pid" ] && kill -0 "$db_pid" 2>/dev/null; then
        kill -TERM "$db_pid" 2>/dev/null || true
    fi

    [ -z "$agent_pid" ] || wait "$agent_pid" 2>/dev/null || true
    [ -z "$metrics_pid" ] || wait "$metrics_pid" 2>/dev/null || true
    [ -z "$resource_pid" ] || wait "$resource_pid" 2>/dev/null || true
    [ -z "$db_pid" ] || wait "$db_pid" 2>/dev/null || true
}

trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

until MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb-admin \
    --protocol=socket -uroot ping --silent >/dev/null 2>&1; do
    if ! kill -0 "$db_pid" 2>/dev/null; then
        if wait "$db_pid"; then
            echo "MariaDB exited before becoming ready." >&2
            exit 1
        else
            status=$?
            exit "$status"
        fi
    fi
    sleep 2
done

/usr/local/bin/database-metrics-loop.sh &
metrics_pid=$!
/usr/local/bin/resource-metrics.sh &
resource_pid=$!
/usr/local/bin/run-wazuh-agent.sh &
agent_pid=$!

while true; do
    for pid in "$db_pid" "$metrics_pid" "$resource_pid" "$agent_pid"; do
        if ! kill -0 "$pid" 2>/dev/null; then
            if wait "$pid"; then
                echo "A supervised database service exited unexpectedly." >&2
                exit 1
            else
                status=$?
                exit "$status"
            fi
        fi
    done
    sleep 2
done
