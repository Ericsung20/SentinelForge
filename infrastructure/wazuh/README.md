# Wazuh Manager Config

Lab-owned configuration for the Wazuh manager. The deployment itself is the upstream `wazuh-docker` single-node stack (see [docs/setup.md](../../docs/setup.md)).

| Path | Deployed to (inside `wazuh.manager`) | Purpose |
|---|---|---|
| `shared/default/agent.conf` | `/var/ossec/etc/shared/default/agent.conf` | Centralized config for the `default` agent group: collect Sysmon on Windows |

## Deploy `agent.conf`

From `infrastructure/wazuh-docker/single-node`:

```bash
C=$(docker compose ps -q wazuh.manager)
docker cp ../../wazuh/shared/default/agent.conf "$C":/tmp/agent.conf
docker exec "$C" /var/ossec/bin/verify-agent-conf -f /tmp/agent.conf   # must print OK
docker exec "$C" install -o wazuh -g wazuh -m 660 /tmp/agent.conf /var/ossec/etc/shared/default/agent.conf
```

The manager pushes the change to enrolled agents in the group on their next check-in (no manager restart needed).
