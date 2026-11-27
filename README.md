# Wazuh single-node deployment

This repository starts the Wazuh manager, indexer, and dashboard with Docker
Compose. The images are pinned to Wazuh **4.14.11**.

## Resource limits

With the optional database profile enabled, the stack is capped at 3 GB RAM
and 2 CPUs total: indexer 1 GB / 1 CPU, manager 768 MB / 0.5 CPU, dashboard
512 MB / 0.25 CPU, webserver 256 MB / 0.125 CPU, and database 512 MB / 0.125
CPU. Without that profile, the database container does not start. The
indexer's JVM heap is set to 512 MB to leave room for its other memory use.
These are container limits, not image build settings. They are intentionally
small and may make startup or services slower; containers may restart if they
exceed their memory caps.

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
Copy-Item .\.env.example .\.env
notepad .\.env
docker compose up -d --build
docker compose ps
```

The `certificates` service generates Wazuh's internal TLS certificates
automatically on the first `docker compose up`. It stores them in the Docker
named volume `wazuh_certs`; no generated certificate files need to be cloned
or committed. The other Wazuh services wait for generation to finish. The
volume keeps the same CA and node certificates across restarts.

After the indexer starts, a one-shot service initializes its security
configuration before the manager and dashboard start.

Put your SSH public key on the `SSH_PUBLIC_KEY` line in `.env`. If you do not
already have a key pair, create one first:

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\id_ed25519"
```

Use the contents of the resulting `.pub` file for `SSH_PUBLIC_KEY`. The SSH
daemon only accepts public-key authentication for the non-root `webadmin` user;
passwords and root SSH login are disabled. SSH keys are stored in a Compose
volume. The webserver agent enrolls with the manager as `webserver`.

The database endpoint is an optional Compose profile. To enable it, set a
non-empty `MARIADB_ROOT_PASSWORD` in `.env`, then run:

```powershell
docker compose --profile database up -d --build
```

Its MariaDB port is bound to localhost at 3307; the database agent enrolls as
`database`.

The first startup can take several minutes while the indexer initializes. Open
<https://localhost> and accept the warning for the generated self-signed TLS
certificate.

The Nginx test page is at <http://localhost:8080>. SSH is available locally on
port 2222:

```powershell
ssh -p 2222 webadmin@localhost
```

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

`docker compose down` preserves the named data volumes. For a truly empty reinstall, `docker compose down --volumes` removes all
stored Wazuh data, including `wazuh_certs`; the next startup generates a new
CA and node certificates. Use it only when you intend to permanently erase
that data.