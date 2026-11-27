#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

: "${RESOURCE_SERVICE:=webserver}"
: "${RESOURCE_METRICS_INTERVAL:=5}"

case "$RESOURCE_SERVICE" in
    webserver) metrics_file=/var/log/webserver/resource-metrics.json ;;
    *) echo "Unsupported RESOURCE_SERVICE: $RESOURCE_SERVICE" >&2; exit 1 ;;
esac

case "$RESOURCE_METRICS_INTERVAL" in
    ''|*[!0-9]*) echo "RESOURCE_METRICS_INTERVAL must be a positive integer" >&2; exit 1 ;;
esac
[ "$RESOURCE_METRICS_INTERVAL" -gt 0 ] || {
    echo "RESOURCE_METRICS_INTERVAL must be greater than zero" >&2
    exit 1
}

if [ -r /sys/fs/cgroup/cpu.max ]; then
    read -r cpu_quota cpu_period < /sys/fs/cgroup/cpu.max
    [ "$cpu_quota" != max ] && [ "$cpu_quota" -gt 0 ] && [ "$cpu_period" -gt 0 ] || {
        echo "A finite cgroup v2 CPU limit is required for resource metrics" >&2
        exit 1
    }
    cpu_cores=$(awk -v quota="$cpu_quota" -v period="$cpu_period" 'BEGIN { printf "%.6f", quota / period }')
    cpu_mode=v2
    memory_current_file=/sys/fs/cgroup/memory.current
    memory_limit_file=/sys/fs/cgroup/memory.max
elif [ -r /sys/fs/cgroup/cpu/cpu.cfs_quota_us ] && [ -r /sys/fs/cgroup/cpuacct/cpuacct.usage ]; then
    cpu_quota=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us)
    cpu_period=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)
    [ "$cpu_quota" -gt 0 ] && [ "$cpu_period" -gt 0 ] || {
        echo "A finite cgroup v1 CPU limit is required for resource metrics" >&2
        exit 1
    }
    cpu_cores=$(awk -v quota="$cpu_quota" -v period="$cpu_period" 'BEGIN { printf "%.6f", quota / period }')
    cpu_mode=v1
    memory_current_file=/sys/fs/cgroup/memory/memory.usage_in_bytes
    memory_limit_file=/sys/fs/cgroup/memory/memory.limit_in_bytes
else
    echo "Unable to find supported cgroup CPU and memory metrics" >&2
    exit 1
fi

[ -r "$memory_current_file" ] && [ -r "$memory_limit_file" ] || {
    echo "Cgroup memory metrics are unavailable" >&2
    exit 1
}
memory_limit=$(cat "$memory_limit_file")
case "$memory_limit" in
    ''|*[!0-9]*) echo "Cgroup memory limit is not finite: $memory_limit" >&2; exit 1 ;;
esac
[ "$memory_limit" -gt 0 ] || {
    echo "Cgroup memory limit must be greater than zero" >&2
    exit 1
}

read_cpu_usage_ns() {
    if [ "$cpu_mode" = v2 ]; then
        awk '$1 == "usage_usec" { printf "%.0f\n", $2 * 1000 }' /sys/fs/cgroup/cpu.stat
    else
        cat /sys/fs/cgroup/cpuacct/cpuacct.usage
    fi
}

mkdir -p "$(dirname "$metrics_file")"
umask 022
: >> "$metrics_file"
previous_usage=$(read_cpu_usage_ns)
previous_time=$(date +%s%N)

while :; do
    sleep "$RESOURCE_METRICS_INTERVAL"
    current_usage=$(read_cpu_usage_ns)
    current_time=$(date +%s%N)
    elapsed_ns=$((current_time - previous_time))
    usage_delta_ns=$((current_usage - previous_usage))
    [ "$elapsed_ns" -gt 0 ] || {
        echo "Invalid elapsed time while sampling cgroup CPU usage" >&2
        exit 1
    }
    [ "$usage_delta_ns" -ge 0 ] || {
        echo "Cgroup CPU usage counter moved backwards" >&2
        exit 1
    }

    cpu_pct=$(awk -v used="$usage_delta_ns" -v elapsed="$elapsed_ns" -v cores="$cpu_cores" \
        'BEGIN { value = used / elapsed / cores * 100; if (value > 100) value = 100; printf "%.2f", value }')
    memory_current=$(cat "$memory_current_file")
    ram_pct=$(awk -v used="$memory_current" -v limit="$memory_limit" \
        'BEGIN { value = used / limit * 100; if (value > 100) value = 100; printf "%.2f", value }')
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    printf '{"timestamp":"%s","service":"%s","metric":"cpu","value_pct":%s,"cpu_limit_cores":%s}\n' \
        "$timestamp" "$RESOURCE_SERVICE" "$cpu_pct" "$cpu_cores" >> "$metrics_file"
    printf '{"timestamp":"%s","service":"%s","metric":"ram","value_pct":%s,"memory_current_bytes":%s,"memory_limit_bytes":%s}\n' \
        "$timestamp" "$RESOURCE_SERVICE" "$ram_pct" "$memory_current" "$memory_limit" >> "$metrics_file"

    previous_usage=$current_usage
    previous_time=$current_time
done
