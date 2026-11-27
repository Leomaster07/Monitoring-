#!/bin/sh
set -eu

: "${WAZUH_MANAGER_SERVER:=wazuh.manager}"
: "${WAZUH_REGISTRATION_PORT:=1515}"
: "${WAZUH_AGENT_NAME:=database}"

until MYSQL_PWD="${MARIADB_ROOT_PASSWORD}" mariadb-admin \
    --protocol=socket -uroot ping --silent >/dev/null 2>&1; do
    sleep 2
done

if [ ! -s /var/ossec/etc/client.keys ]; then
    until /var/ossec/bin/agent-auth \
        -m "$WAZUH_MANAGER_SERVER" \
        -p "$WAZUH_REGISTRATION_PORT" \
        -A "$WAZUH_AGENT_NAME"; do
        echo "Wazuh enrollment failed; retrying in 5 seconds." >&2
        sleep 5
    done
fi

chown wazuh:wazuh /var/ossec/etc/client.keys

if ! /var/ossec/bin/wazuh-control status >/dev/null 2>&1; then
    /var/ossec/bin/wazuh-control start
fi

while true; do
    if ! /var/ossec/bin/wazuh-control status >/dev/null 2>&1; then
        echo "Wazuh agent not running; starting..." >&2
        /var/ossec/bin/wazuh-control start
    fi
    sleep 5
done
