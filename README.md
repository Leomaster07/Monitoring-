# Wazuh single-node deployment

This repository starts the Wazuh manager, indexer, and dashboard with Docker
Compose. The images are pinned to Wazuh **4.14.11**.

## Requirements

- Docker Desktop with the WSL 2 backend and Docker Compose v2.
- At least 4 CPU cores, 8 GB RAM, and 50 GB free disk space.
- In a WSL 2 terminal, set the indexer's required virtual-memory map limit:

  ```sh
  sudo sysctl -w vm.max_map_count=262144
  ```

## Start

Run these commands from the repository root in PowerShell:

```powershell
docker compose -f .\wazuh\generate-indexer-certs.yml run --rm generator
docker compose up -d
docker compose ps
```

The first startup can take several minutes while the indexer initializes. Open
<https://localhost> and accept the warning for the generated self-signed TLS
certificate.

Default first-run dashboard login:

- Username: `admin`
- Password: `SecretPassword`

The Wazuh API's initial `wazuh-wui` password is `MyS3cr37P450r.*-`. These are
upstream demo credentials. Dashboard HTTPS (port 443), manager API (port 55000),
and indexer API (port 9200) are bound to localhost by default. Manager agent
enrollment/events use ports 1515 and 1514 (TCP), and syslog uses 514/UDP. If
you need remote dashboard access, rotate the demo credentials, change the
dashboard/API host bindings in `docker-compose.yml`, and restrict access with
your firewall before exposing them.

## Operations

```powershell
docker compose logs -f
docker compose down
```

`docker compose down` preserves the named data volumes. For a truly empty
reinstall, `docker compose down --volumes` removes all stored Wazuh data as well
as the containers; use it only when you intend to permanently erase that data.