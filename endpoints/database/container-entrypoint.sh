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

# Wait for the real MariaDB server to be up and accepting authenticated connections.
# The official entrypoint handles MARIADB_ROOT_PASSWORD during init; we just wait
# until the root password works, polling both with and without the password to
# cover the temporary-server phase and the final real-server phase.
for i in $(seq 1 45); do
    if ! kill -0 "$db_pid" 2>/dev/null; then
        echo "MariaDB exited before becoming ready." >&2
        exit 1
    fi
    if MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb-admin \
        --protocol=socket -uroot ping --silent 2>/dev/null; then
        break
    fi
    # Password may not be set yet on the temporary server; try without it.
    if mariadb -uroot -e "SELECT 1" --silent 2>/dev/null; then
        # Connected without password: root not yet secured. Set the password now.
        mariadb -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}'; FLUSH PRIVILEGES;" \
            2>/dev/null || true
    fi
    sleep 2
done

# Final verification: root must accept the configured password.
if ! MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb-admin \
    --protocol=socket -uroot ping --silent 2>/dev/null; then
    echo "WARNING: could not verify MariaDB root password; proceeding anyway." >&2
fi

/usr/local/bin/database-metrics-loop.sh &
metrics_pid=$!
/usr/local/bin/resource-metrics.sh &
resource_pid=$!
/usr/local/bin/run-wazuh-agent.sh &
agent_pid=$!

while true; do
    # Only MariaDB is critical; metrics/agent scripts are best-effort.
    if ! kill -0 "$db_pid" 2>/dev/null; then
        echo "MariaDB exited unexpectedly." >&2
        exit 1
    fi
    sleep 2
done
