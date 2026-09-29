# Setup

Reproducible setup instructions, filled in as each phase is completed. Only verified steps go here.

## Phase 0: Development Environment · Completed

| Requirement | Notes |
|---|---|
| Windows 11 | Host OS |
| WSL2 + Ubuntu | The repository lives in the Ubuntu filesystem |
| Docker Desktop | WSL integration enabled for Ubuntu |
| Git | Used from WSL |
| RAM | 32 GB (a single-node Wazuh deployment needs roughly 8 GB or more) |

Verify:

```bash
wsl --status            # from Windows
docker version          # from WSL
docker compose version  # from WSL
git --version
```

Clone:

```bash
git clone https://github.com/<your-username>/SentinelForge.git
cd SentinelForge
```

## Phase 1: Infrastructure · In Progress

### 1.1 Wazuh single-node (Docker) · Completed

Uses the official [wazuh-docker](https://github.com/wazuh/wazuh-docker) single-node deployment, pinned to **v4.14.8**. The clone lives at `infrastructure/wazuh-docker/` and is git-ignored.

Prerequisite: Docker Desktop must be **running** on Windows. If WSL prints `The command 'docker' could not be found`, start Docker Desktop first (enable *Start Docker Desktop when you sign in* to avoid this).

```bash
# Wazuh indexer (OpenSearch) needs a higher mmap limit; persist it across WSL restarts
echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-wazuh.conf
sudo sysctl --system > /dev/null

cd infrastructure
git clone https://github.com/wazuh/wazuh-docker.git -b v4.14.8
cd wazuh-docker/single-node
docker compose -f generate-indexer-certs.yml run --rm generator   # one-time: TLS certs
docker compose up -d
docker compose ps
```

Expected: three containers `Up`: `wazuh.manager`, `wazuh.indexer`, `wazuh.dashboard`.

| Port | Service |
|---|---|
| 443 | Dashboard → https://localhost (self-signed cert warning is expected) |
| 1514 / 1515 | Agent events / agent enrollment |
| 9200 | Indexer API |
| 55000 | Wazuh server API |

Login uses the upstream default credentials defined in `single-node/docker-compose.yml`. These are public defaults: change them before exposing the lab to any network.

Stop / start:

```bash
docker compose stop     # keeps data
docker compose start
```

### 1.2 Windows endpoint, Sysmon, audit policy, agent · Planned

_Still to document._

## Secrets Handling

- Never commit passwords, API keys, tokens, certificates or agent keys.
- Put local values in `.env` (git-ignored). If a template is needed, commit `.env.example` with placeholder values only.
- Keep Wazuh-generated certificates out of Git (see `.gitignore`).
