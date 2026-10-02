#!/usr/bin/env bash
# Stores every event the manager receives, not only alerts, and ships it to the wazuh-archives-* indices.
# Without this, events matched only by level-0 rules (e.g. Sysmon process creation, rule 61603) are dropped,
# so an investigation cannot see the activity around an alert. Safe to run more than once.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
cd "$here/../wazuh-docker/single-node"

# Manager: also write all events to /var/ossec/logs/archives/archives.json
conf=config/wazuh_cluster/wazuh_manager.conf
sed -i 's|<logall_json>no</logall_json>|<logall_json>yes</logall_json>|' "$conf"
grep -q '<logall_json>yes</logall_json>' "$conf"

# Filebeat: the image resets filebeat.yml on every start, so mount a cont-init hook that re-enables archives
chmod +x "$here/cont-init/1-enable-archives"
mount_line='      - ../../wazuh/cont-init/1-enable-archives:/etc/cont-init.d/1-enable-archives:ro'
if ! grep -qF "$mount_line" docker-compose.yml; then
    MOUNT_LINE=$mount_line python3 - <<'PY'
import os
path = "docker-compose.yml"
anchor = "      - ./config/wazuh_cluster/wazuh_manager.conf:/wazuh-config-mount/etc/ossec.conf\n"
text = open(path).read()
assert text.count(anchor) == 1, "manager config mount line not found"
open(path, "w").write(text.replace(anchor, anchor + os.environ["MOUNT_LINE"] + "\n"))
PY
fi

# Recreate rather than restart: sed -i replaced the bind-mounted conf file, and a plain restart
# fails on Docker Desktop because the mount still points at the old file. Data volumes are kept.
docker compose up -d --force-recreate wazuh.manager
until docker compose exec -T wazuh.manager pgrep -f bin/filebeat >/dev/null 2>&1; do sleep 3; done
docker compose exec -T wazuh.manager grep -A1 'archives:' /etc/filebeat/filebeat.yml | grep -q 'enabled: true'
echo "Archives enabled. Create the index pattern 'wazuh-archives-*' in the dashboard to browse all events."
