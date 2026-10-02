# Wazuh Manager Config

Lab-owned configuration for the Wazuh manager. The deployment itself is the upstream `wazuh-docker` single-node stack (see [docs/setup.md](../../docs/setup.md)).

| Path | Deployed to (inside `wazuh.manager`) | Purpose |
|---|---|---|
| `shared/default/agent.conf` | `/var/ossec/etc/shared/default/agent.conf` | Centralized config for the `default` agent group: collect Sysmon on Windows |
| `cont-init/1-enable-archives` | `/etc/cont-init.d/1-enable-archives` (bind mount) | Re-enables Filebeat archive shipping on every container start |
| `enable-archives.sh` | (run from WSL) | Turns on full event archiving, see below |
| `Install-WazuhAgent.ps1` | (run on the Windows endpoint) | Installs and enrolls the agent, see [docs/setup.md](../../docs/setup.md) |

## Deploy `agent.conf`

From `infrastructure/wazuh-docker/single-node`:

```bash
C=$(docker compose ps -q wazuh.manager)
docker cp ../../wazuh/shared/default/agent.conf "$C":/tmp/agent.conf
docker exec "$C" /var/ossec/bin/verify-agent-conf -f /tmp/agent.conf   # must print OK
docker exec "$C" install -o wazuh -g wazuh -m 660 /tmp/agent.conf /var/ossec/etc/shared/default/agent.conf
```

The manager pushes the change to enrolled agents in the group on their next check-in (no manager restart needed).

## Archive all events

By default Wazuh only indexes **alerts**. An event that matches only a level-0 rule is analyzed and then dropped. Sysmon process creation (rule 61603) is one of them, so a plain `whoami` never reaches the dashboard. Investigations need that surrounding activity, so the lab archives everything:

```bash
bash infrastructure/wazuh/enable-archives.sh
```

It sets `<logall_json>yes</logall_json>` in the manager config, then recreates the manager container. Filebeat archive shipping can't simply be edited inside the container, because the image restores `/etc/filebeat/filebeat.yml` on every start (`PERMANENT_DATA_EXCP` in `/permanent_data.env`). Instead, the script mounts `cont-init/1-enable-archives`, which switches `archives.enabled` back on after the image's own `1-config-filebeat` step.

Then, in the dashboard: **Dashboards Management → Index patterns → Create**, name `wazuh-archives-*`, time field `timestamp`. Browse it in **Discover**.

Verify after any restart:

```bash
docker compose exec wazuh.manager grep -A1 'archives:' /etc/filebeat/filebeat.yml   # enabled: true
```
