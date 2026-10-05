#!/usr/bin/env bash
# Deploys the SentinelForge custom rules to the Wazuh manager and reloads it.
# The rule file is removed again if Wazuh rejects it, so a typo never leaves the manager unable to start.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
cd "$here/../../infrastructure/wazuh-docker/single-node"

rules=sentinelforge_rules.xml
dest=/var/ossec/etc/rules/$rules
C=$(docker compose ps -q wazuh.manager)

docker cp "$here/$rules" "$C:/tmp/$rules"
docker compose exec -T wazuh.manager install -o wazuh -g wazuh -m 660 "/tmp/$rules" "$dest"

if ! docker compose exec -T wazuh.manager /var/ossec/bin/wazuh-analysisd -t; then
    docker compose exec -T wazuh.manager rm -f "$dest"
    echo "Wazuh rejected $rules; removed it again. Fix the error above and rerun." >&2
    exit 1
fi

docker compose exec -T wazuh.manager /var/ossec/bin/wazuh-control restart >/dev/null
echo "Deployed $rules and restarted the manager."
