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

## Phase 1: Infrastructure · Planned

_Still to document: Wazuh Docker deployment, Windows endpoint, Sysmon, audit policy and agent enrollment._

## Secrets Handling

- Never commit passwords, API keys, tokens, certificates or agent keys.
- Put local values in `.env` (git-ignored). If a template is needed, commit `.env.example` with placeholder values only.
- Keep Wazuh-generated certificates out of Git (see `.gitignore`).
