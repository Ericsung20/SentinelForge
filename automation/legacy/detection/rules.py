RULES = [
    {
        "id": "SF-001",
        "name": "Encoded PowerShell",
        "pattern": "powershell -enc",
        "severity": "HIGH",
    },
    {
        "id": "SF-002",
        "name": "Credential Dumping Tool",
        "pattern": "mimikatz",
        "severity": "CRITICAL",
    },
    {
        "id": "SF-003",
        "name": "Suspicious Web Download",
        "pattern": "invoke-webrequest",
        "severity": "MEDIUM",
    },
]

