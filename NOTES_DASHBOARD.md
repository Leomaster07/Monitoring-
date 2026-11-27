# Notes : dashboards Wazuh

## Ce qui a été construit
Deux dashboards personnalisés (8 graphiques au total), exportés dans `dashboards/dashboards_wazuh.ndjson`.
Les vues fournies par Wazuh (Overview, Threat Hunting) ont servi de point de départ pour comprendre les données, mais elles ne sont pas le livrable.

## Dashboard Direction (synthèse métier)
- DIR - Alertes par niveau
- Dir - Evolutions des alertes (évolution dans le temps)
- Dir-Totale des alertes
- Dir-Disponibilité des agents

## Dashboard Exploitation (vue technique, méthodes USE/RED)
- EXP-Alertes par agents : quelle machine produit le plus d'alertes
- EXP - Top 10 des règles : quel événement se répète le plus
- EXP-Rythme des alertes : indicateur Rate (RED)
- EXP - Alertes niveau 7+ : indicateur Errors (RED)

## Notification
Les e-mails d'alerte passent par Mailpit, qui est un service du projet (docker-compose).

## Fichiers
- `dashboards/dashboards_wazuh.ndjson` : export des 2 dashboards et de leurs graphiques
- `captures/` : captures des dashboards
