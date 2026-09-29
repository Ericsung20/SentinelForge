# SentinelForge: Learning Log

A running journal of what I built, what broke and what I learned. Newest entries go at the top. Copy the template below for each session.

---

## Entry Template

```markdown
### YYYY-MM-DD: <Topic>

**Phase:** <0–8>

**What I worked on**
-

**What I learned**
-

**Problems encountered**
-

**How I solved them**
-

**Security concepts learned**
-

**Next step**
-
```

---

## Entries

### 2026-09-28: Wazuh single-node deployment

**Phase:** 1

**What I worked on**
- Archived the early Python prototype under `automation/legacy/`.
- Deployed Wazuh v4.14.8 (manager, indexer, dashboard) with the official single-node Docker Compose setup and logged in to the dashboard.

**What I learned**
- Wazuh has three parts: the manager analyzes events, the indexer (OpenSearch) stores and searches them, and the dashboard is the web UI.
- The indexer needs `vm.max_map_count=262144`. `sysctl -w` resets when WSL restarts, so the value also goes in `/etc/sysctl.d/`.
- Docker Desktop provides the `docker` command inside WSL, so it only works while Docker Desktop is running on Windows.
- Cloning a third-party repo at a pinned release tag makes the setup reproducible. The clone stays git-ignored because it is not my code.

**Problems encountered**
- `git clone -b v4.X.Y` failed because I ran the placeholder tag literally.
- WSL reported `The command 'docker' could not be found`.

**How I solved them**
- Looked up the real latest tag with `git ls-remote --tags` and cloned `v4.14.8`.
- Docker Desktop was installed but not running. Starting it fixed the error.

**Security concepts learned**
- The indexer uses TLS certificates generated locally. Certificates and keys never go into Git.
- The deployment ships with public default credentials, which must be changed before the lab touches any real network.
- The Windows endpoint should be an isolated VM with snapshots, so attack simulations cannot harm the host.

**Next step**
- Build the Windows lab VM, then install Sysmon and the Wazuh agent.

### 2026-09-28: Repository setup

**Phase:** 0

**What I worked on**
- Initialized the SentinelForge repository, its structure and the planning docs (README, PRD, ROADMAP).

**What I learned**
-

**Problems encountered**
-

**How I solved them**
-

**Security concepts learned**
-

**Next step**
- Phase 1: deploy single-node Wazuh with Docker.
