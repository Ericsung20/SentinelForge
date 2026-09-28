from detection.rules import RULES


def analyze_event(event):
    command = event.get("command", "").lower()

    for rule in RULES:
        if rule["pattern"].lower() in command:
            return {
                "status": "ALERT",
                "rule_id": rule["id"],
                "rule_name": rule["name"],
                "severity": rule["severity"],
                "reason": f"Matched pattern: {rule['pattern']}",
            }

    return {
        "status": "NORMAL",
        "reason": "No suspicious activity detected",
    }
