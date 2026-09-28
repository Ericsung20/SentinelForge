from src.collector import load_events
from src.engine import analyze_event


def main():
    print("SentinelForge starting...\n")

    events = load_events("logs/events.json")

    for event in events:
        result = analyze_event(event)

        print("Event:")
        print(event)

        print("Detection Result:")
        print(result)

        print("-" * 50)


if __name__ == "__main__":
    main()
