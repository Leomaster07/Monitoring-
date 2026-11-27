#!/bin/bash
set -Eeuo pipefail

: "${WAZUH_MANAGER_SERVER:=wazuh.manager}"
: "${WAZUH_REGISTRATION_PORT:=1515}"
: "${WAZUH_AGENT_NAME:=webserver}"
: "${RESOURCE_SERVICE:=webserver}"
: "${RESOURCE_METRICS_INTERVAL:=5}"

mkdir -p /run/sshd /var/log/nginx /var/log/webserver \
    /var/ossec/etc /var/ossec/logs /var/ossec/queue /home/webadmin/.ssh
ssh-keygen -A
touch /var/log/auth.log

if [ -n "${SSH_PUBLIC_KEY:-}" ]; then
    printf '%s\n' "$SSH_PUBLIC_KEY" > /home/webadmin/.ssh/authorized_keys
fi

chown -R webadmin:webadmin /home/webadmin/.ssh
chmod 0700 /home/webadmin/.ssh
if [ -f /home/webadmin/.ssh/authorized_keys ]; then
    chmod 0600 /home/webadmin/.ssh/authorized_keys
else
    echo "SSH_PUBLIC_KEY is empty; SSH key login is not configured." >&2
fi

chown -R wazuh:wazuh /var/ossec/etc /var/ossec/logs /var/ossec/queue
rm -f /var/log/nginx/access.log /var/log/nginx/error.log
touch /var/log/nginx/access.log /var/log/nginx/error.log
chmod 0644 /var/log/nginx/access.log /var/log/nginx/error.log

/usr/sbin/sshd -D -E /var/log/auth.log &
sshd_pid=$!
nginx -g 'daemon off;' &
nginx_pid=$!
/usr/local/bin/resource-metrics.sh &
metrics_pid=$!
/usr/local/bin/run-wazuh-agent.sh &
agent_pid=$!

cleanup() {
    trap - EXIT INT TERM
    for pid in "$agent_pid" "$metrics_pid" "$nginx_pid" "$sshd_pid"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done
    for pid in "$agent_pid" "$metrics_pid" "$nginx_pid" "$sshd_pid"; do
        wait "$pid" 2>/dev/null || true
    done
}

trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

while true; do
    for pid in "$nginx_pid" "$sshd_pid" "$metrics_pid" "$agent_pid"; do
        if ! kill -0 "$pid" 2>/dev/null; then
            if wait "$pid"; then
                echo "A supervised webserver service exited unexpectedly." >&2
                exit 1
            else
                status=$?
                exit "$status"
            fi
        fi
    done
    sleep 2
done
