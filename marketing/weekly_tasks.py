#!/usr/bin/env python3
"""
Breathe App — Weekly Marketing Task Automation
Generates your weekly checklist and tracks completion.
Run: python3 weekly_tasks.py
"""

import json
import os
from datetime import datetime, timedelta

DATA_FILE = os.path.join(os.path.dirname(__file__), "task_history.json")


def get_week_number():
    return datetime.now().isocalendar()[1]


def load_history():
    if os.path.exists(DATA_FILE):
        with open(DATA_FILE, "r") as f:
            return json.load(f)
    return {"weeks": {}}


def save_history(data):
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=2)


WEEKLY_TASKS = [
    # Content creation
    {"task": "Create & post TikTok/Reel #1 (breathing technique)", "category": "Content", "day": "Tuesday", "time_min": 30},
    {"task": "Create & post TikTok/Reel #2 (app feature demo)", "category": "Content", "day": "Thursday", "time_min": 30},
    {"task": "Create & post TikTok/Reel #3 (sleep/relaxation)", "category": "Content", "day": "Saturday", "time_min": 30},

    # Reddit
    {"task": "Write & post Reddit value post #1", "category": "Reddit", "day": "Monday", "time_min": 20},
    {"task": "Write & post Reddit value post #2", "category": "Reddit", "day": "Wednesday", "time_min": 20},
    {"task": "Engage in 10+ Reddit comments (helpful, no spam)", "category": "Reddit", "day": "Friday", "time_min": 30},

    # Twitter/X
    {"task": "Post 2 tweets/threads", "category": "Twitter", "day": "Wed+Fri", "time_min": 15},

    # App Store
    {"task": "Respond to ALL new App Store reviews", "category": "ASO", "day": "Wednesday", "time_min": 15},
    {"task": "Check App Store Connect analytics", "category": "ASO", "day": "Sunday", "time_min": 10},

    # Ads (if running)
    {"task": "Review Apple Search Ads performance, adjust bids", "category": "Ads", "day": "Wednesday", "time_min": 15},
    {"task": "Review Meta Ads performance (if running)", "category": "Ads", "day": "Wednesday", "time_min": 10},

    # Analytics & planning
    {"task": "Review weekly metrics (downloads, trials, conversions)", "category": "Analytics", "day": "Sunday", "time_min": 15},
    {"task": "Plan next week's content topics", "category": "Planning", "day": "Sunday", "time_min": 20},
]


def generate_checklist():
    week = get_week_number()
    year = datetime.now().year
    week_key = f"{year}-W{week:02d}"

    history = load_history()
    completed = history.get("weeks", {}).get(week_key, [])

    today = datetime.now()
    mon = today - timedelta(days=today.weekday())

    print("=" * 60)
    print(f"  BREATHE — Weekly Marketing Checklist")
    print(f"  Week {week} ({mon.strftime('%b %d')} - {(mon + timedelta(days=6)).strftime('%b %d, %Y')})")
    print("=" * 60)

    total_time = 0
    done_count = 0

    days_order = ["Monday", "Tuesday", "Wednesday", "Wed+Fri", "Thursday", "Friday", "Saturday", "Sunday"]

    for day in days_order:
        day_tasks = [t for t in WEEKLY_TASKS if t["day"] == day]
        if not day_tasks:
            continue

        print(f"\n  {day.upper()}")
        for t in day_tasks:
            is_done = t["task"] in completed
            check = "✅" if is_done else "⬜"
            if is_done:
                done_count += 1
            total_time += t["time_min"]
            print(f"    {check} [{t['category']:>9}] {t['task']} ({t['time_min']}min)")

    total_tasks = len(WEEKLY_TASKS)
    print(f"\n{'─' * 60}")
    print(f"  Progress: {done_count}/{total_tasks} tasks ({done_count/total_tasks*100:.0f}%)")
    print(f"  Total time estimate: {total_time} minutes ({total_time/60:.1f} hours)")
    print(f"  Average per day: {total_time/7:.0f} minutes")
    print(f"{'─' * 60}")

    return week_key, completed


def mark_complete(week_key, completed):
    history = load_history()

    print("\nWhich task did you complete? (enter number, or 'q' to quit)")
    tasks = WEEKLY_TASKS.copy()
    for i, t in enumerate(tasks, 1):
        is_done = "✅" if t["task"] in completed else "  "
        print(f"  {is_done} {i:2d}. {t['task']}")

    while True:
        choice = input("\nTask #: ").strip()
        if choice.lower() == 'q':
            break
        try:
            idx = int(choice) - 1
            task_name = tasks[idx]["task"]
            if task_name not in completed:
                completed.append(task_name)
                print(f"  ✅ Marked complete: {task_name}")
            else:
                print(f"  Already done!")
        except (ValueError, IndexError):
            print("  Invalid number.")
            continue

    if "weeks" not in history:
        history["weeks"] = {}
    history["weeks"][week_key] = completed
    save_history(history)
    print("\nProgress saved!")


def show_streak():
    history = load_history()
    weeks = history.get("weeks", {})

    if not weeks:
        print("\n  No history yet. Start completing tasks!")
        return

    print("\n📈 COMPLETION HISTORY\n")
    total_tasks = len(WEEKLY_TASKS)
    for week_key in sorted(weeks.keys())[-8:]:
        done = len(weeks[week_key])
        pct = done / total_tasks * 100
        bar = "█" * int(pct / 5) + "░" * (20 - int(pct / 5))
        print(f"  {week_key}: {bar} {done}/{total_tasks} ({pct:.0f}%)")


if __name__ == "__main__":
    while True:
        print("\n┌─────────────────────────────────┐")
        print("│  Breathe Marketing Tracker       │")
        print("├─────────────────────────────────┤")
        print("│  1. View weekly checklist         │")
        print("│  2. Mark tasks complete           │")
        print("│  3. View completion history        │")
        print("│  4. Exit                           │")
        print("└─────────────────────────────────┘")

        choice = input("\nChoice: ").strip()

        if choice == "1":
            generate_checklist()
        elif choice == "2":
            week_key, completed = generate_checklist()
            mark_complete(week_key, completed)
        elif choice == "3":
            show_streak()
        elif choice == "4":
            break
