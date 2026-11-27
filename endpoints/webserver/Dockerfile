FROM wazuh/wazuh-agent:4.14.11 AS wazuh-agent

FROM nginx:1.28-bookworm

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openssh-server rsyslog iptables \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 10001 wazuh \
    && useradd --system --uid 10001 --gid wazuh \
        --home-dir /var/ossec --no-create-home \
        --shell /usr/sbin/nologin wazuh \
    && useradd --system --uid 10002 --create-home \
        --home-dir /home/webadmin --shell /bin/bash webadmin \
    && mkdir -p /var/log/webserver /var/ossec/etc /var/ossec/logs /var/ossec/queue \
        /home/webadmin/.ssh /opt/security-lab /run/sshd \
    && chmod 0700 /home/webadmin/.ssh \
    && chown -R wazuh:wazuh /var/ossec \
    && chown -R webadmin:webadmin /home/webadmin

COPY --from=wazuh-agent /var/ossec /var/ossec

RUN chown -R wazuh:wazuh /var/ossec

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY sshd_config /etc/ssh/sshd_config
COPY wazuh-agent.conf /var/ossec/etc/ossec.conf
COPY container-entrypoint.sh run-wazuh-agent.sh resource-metrics.sh /usr/local/bin/
COPY html/ /usr/share/nginx/html/
COPY cis_debian12.yml /var/ossec/etc/ruleset/sca/

RUN chmod 0755 \
        /usr/local/bin/container-entrypoint.sh \
        /usr/local/bin/run-wazuh-agent.sh \
        /usr/local/bin/resource-metrics.sh \
    && chown -R webadmin:webadmin /usr/share/nginx/html \
    && chmod 0755 /usr/share/nginx/html

EXPOSE 80 22

ENTRYPOINT ["/usr/local/bin/container-entrypoint.sh"]
