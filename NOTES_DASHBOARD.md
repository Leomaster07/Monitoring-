# Dashboards Wazuh et alerte e-mail

## Dashboard 1 : Vue Direction (Overview)
Agents actifs et alertes des dernières 24h par sévérité (capture 12-49-36).

## Dashboard 2 : Vue Exploitation (Threat Hunting)
Alertes dans le temps et top 5 des agents (captures 13-54-35 et 13-54-46).

## Alerte e-mail
Wazuh envoie automatiquement un e-mail "Alert level 3" (règle 502) vers Mailpit (capture 14-43-53).
Mailpit a été lancé à part avec docker run. Le seuil est à 3 pour la démonstration.

## Limite
scenario.sh non reproduit sur ma machine : le conteneur webserver n'a ni sudo ni useradd.
