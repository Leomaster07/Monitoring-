FROM wazuh/wazuh-agent:4.14.11 AS wazuh-agent

FROM mariadb:11.4

RUN groupadd --system --gid 10001 wazuh \
    && useradd --system --uid 10001 --gid wazuh \
        --home-dir /var/ossec --no-create-home \
        --shell /usr/sbin/nologin wazuh \
    && mkdir -p /var/log/mysql /var/www

COPY --from=wazuh-agent /var/ossec /var/ossec

RUN chown -R wazuh:wazuh /var/ossec \
    && chown mysql:mysql /var/log/mysql \
    && chmod 0755 /var/log/mysql /var/www

COPY 99-wazuh.cnf /etc/mysql/mariadb.conf.d/99-wazuh.cnf
COPY wazuh-agent.conf /var/ossec/etc/ossec.conf
COPY container-entrypoint.sh run-wazuh-agent.sh database-metrics.sh database-metrics-loop.sh resource-metrics.sh /usr/local/bin/

RUN chmod 0755 \
    /usr/local/bin/container-entrypoint.sh \
    /usr/local/bin/run-wazuh-agent.sh \
    /usr/local/bin/database-metrics.sh \
    /usr/local/bin/database-metrics-loop.sh \
    /usr/local/bin/resource-metrics.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/container-entrypoint.sh"]
