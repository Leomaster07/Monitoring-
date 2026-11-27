#!/bin/bash
# setup.sh : prepare les fichiers de config a partir du .env
set -euo pipefail
cd "$(dirname "$0")"

[ -f .env ] || { echo "ERREUR : .env absent (cp .env.example .env, puis le remplir)"; exit 1; }
set -a; . ./.env; set +a
for v in INDEXER_PASSWORD DASHBOARD_PASSWORD API_PASSWORD; do
  if [ -z "${!v:-}" ] || [ "${!v}" = "CHANGE_ME" ]; then
    echo "ERREUR : $v n'est pas defini dans .env"; exit 1
  fi
done

CFG=wazuh/config
IMG=${INDEXER_IMAGE:-$(grep -m1 'image: wazuh/wazuh-indexer' docker-compose.yml | awk '{print $2}')}
hash() {
  docker run --rm -e PW="$1" "$IMG" bash -c \
    'JAVA_HOME=/usr/share/wazuh-indexer/jdk bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p "$PW"' | tail -n 1
}

# 1. certificats
if [ ! -f $CFG/wazuh_indexer_ssl_certs/root-ca.pem ]; then
  docker compose -f wazuh/generate-indexer-certs.yml run --rm generator
fi

# 2. comptes de l'indexeur
HA=$(hash "$INDEXER_PASSWORD")
HK=$(hash "$DASHBOARD_PASSWORD")
awk -v a="$HA" -v k="$HK" '/hash: "CHANGE_ME"/ { n++; sub(/CHANGE_ME/, (n==1) ? a : k) } { print }' \
  $CFG/wazuh_indexer/internal_users.yml.example > $CFG/wazuh_indexer/internal_users.yml

# 3. config du dashboard
sed "s|^\( *password:\).*|\1 \"$API_PASSWORD\"|" \
  $CFG/wazuh_dashboard/wazuh.yml.example > $CFG/wazuh_dashboard/wazuh.yml

chmod 644 $CFG/wazuh_indexer/internal_users.yml $CFG/wazuh_dashboard/wazuh.yml
echo "OK : configuration generee. Lance maintenant : docker compose up -d"
