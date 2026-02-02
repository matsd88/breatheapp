#!/usr/bin/env python3
"""
Breathe App — ASO Keyword Tracker & App Store Connect Reporter
Tracks keyword rankings, generates weekly reports, and monitors competitors.
Run: python3 aso_keyword_tracker.py
"""

import json
import os
from datetime import datetime

DATA_FILE = os.path.join(os.path.dirname(__file__), "aso_data.json")

# Target keywords with estimated search volume (1-10 scale) and difficulty
KEYWORDS = {
    # Primary keywords
    "meditation app": {"volume": 10, "difficulty": 10, "priority": "high"},
    "sleep app": {"volume": 9, "difficulty": 9, "priority": "high"},
    "guided meditation": {"volume": 8, "difficulty": 8, "priority": "high"},
    "sleep stories": {"volume": 8, "difficulty": 7, "priority": "high"},
    "breathing exercises": {"volume": 7, "difficulty": 6, "priority": "high"},
    "mindfulness app": {"volume": 7, "difficulty": 8, "priority": "high"},
    "calm app": {"volume": 9, "difficulty": 10, "priority": "medium"},
    "anxiety relief": {"volume": 7, "difficulty": 7, "priority": "high"},

    # Secondary keywords (lower competition, high intent)
    "box breathing": {"volume": 5, "difficulty": 3, "priority": "high"},
    "4-7-8 breathing": {"volume": 4, "difficulty": 2, "priority": "high"},
    "wim hof breathing app": {"volume": 4, "difficulty": 2, "priority": "high"},
    "body scan meditation": {"volume": 4, "difficulty": 3, "priority": "medium"},
    "pomodoro meditation": {"volume": 3, "difficulty": 1, "priority": "medium"},
    "ai meditation chat": {"volume": 3, "difficulty": 1, "priority": "high"},
    "soundscape mixer": {"volume": 2, "difficulty": 1, "priority": "medium"},
    "sleep sounds app": {"volume": 6, "difficulty": 5, "priority": "medium"},
    "mood tracking meditation": {"volume": 3, "difficulty": 2, "priority": "medium"},

    # Long-tail (blog/SEO targets)
    "how to fall asleep fast": {"volume": 8, "difficulty": 6, "priority": "seo"},
    "breathing exercises for anxiety": {"volume": 6, "difficulty": 4, "priority": "seo"},
    "best meditation app 2026": {"volume": 5, "difficulty": 5, "priority": "seo"},
    "sleep stories for adults": {"volume": 5, "difficulty": 4, "priority": "seo"},
    "navy seal breathing technique": {"volume": 4, "difficulty": 2, "priority": "seo"},
}

COMPETITORS = {
    "Calm": {"id": "571800810", "price": "$69.99/yr"},
    "Headspace": {"id": "493145008", "price": "$69.99/yr"},
    "Insight Timer": {"id": "337472899", "price": "Free + $59.99/yr"},
    "Balance": {"id": "1361356590", "price": "$69.99/yr"},
    "Ten Percent Happier": {"id": "992210239", "price": "$99.99/yr"},
}


def load_data():
    if os.path.exists(DATA_FILE):
        with open(DATA_FILE, "r") as f:
            return json.load(f)
    return {"entries": [], "rankings": {}}


def save_data(data):
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=2)


def log_ranking(keyword, rank):
    """Log a keyword ranking observation."""
    data = load_data()
    entry = {
        "date": datetime.now().isoformat(),
        "keyword": keyword,
        "rank": rank
    }
    data["entries"].append(entry)
    data["rankings"][keyword] = {"rank": rank, "date": datetime.now().strftime("%Y-%m-%d")}
    save_data(data)
    print(f"  Logged: '{keyword}' → rank #{rank}")


def generate_report():
    """Generate a keyword strategy report."""
    data = load_data()

    print("=" * 70)
    print(f"  BREATHE APP — ASO & Keyword Report")
    print(f"  Generated: {datetime.now().strftime('%B %d, %Y')}")
    print("=" * 70)

    # Keyword opportunity analysis
    print("\n📊 KEYWORD OPPORTUNITY MATRIX\n")
    print(f"{'Keyword':<35} {'Vol':>4} {'Diff':>5} {'Priority':>8} {'Rank':>6}")
    print("─" * 70)

    high_opp = []
    for kw, info in sorted(KEYWORDS.items(), key=lambda x: x[1]["volume"], reverse=True):
        rank = data.get("rankings", {}).get(kw, {}).get("rank", "—")
        rank_str = f"#{rank}" if isinstance(rank, int) else rank
        opportunity = info["volume"] * (10 - info["difficulty"]) / 10
        print(f"{kw:<35} {info['volume']:>4} {info['difficulty']:>5} {info['priority']:>8} {rank_str:>6}")
        if info["difficulty"] <= 4 and info["volume"] >= 3:
            high_opp.append((kw, opportunity))

    # Quick wins
    print("\n🎯 QUICK WIN KEYWORDS (low difficulty, decent volume):\n")
    for kw, score in sorted(high_opp, key=lambda x: x[1], reverse=True):
        info = KEYWORDS[kw]
        print(f"  → {kw} (volume: {info['volume']}, difficulty: {info['difficulty']})")

    # Competitor pricing comparison
    print("\n\n💰 COMPETITOR PRICING COMPARISON\n")
    print(f"{'App':<25} {'Price':>15}")
    print("─" * 40)
    print(f"{'Breathe (you)':<25} {'$49.99/yr':>15}  ← YOUR ADVANTAGE")
    for name, info in COMPETITORS.items():
        print(f"{name:<25} {info['price']:>15}")

    # Apple Search Ads keyword suggestions
    print("\n\n🍎 APPLE SEARCH ADS — RECOMMENDED KEYWORDS\n")
    print("Exact Match (start here, highest intent):")
    exact = [kw for kw, info in KEYWORDS.items()
             if info["priority"] == "high" and info["difficulty"] <= 6]
    for kw in exact:
        print(f"  [{kw}]  — suggested bid: $0.50-1.50")

    print("\nBroad Match (scale after exact works):")
    broad = [kw for kw, info in KEYWORDS.items()
             if info["priority"] == "high" and info["difficulty"] > 6]
    for kw in broad:
        print(f"  {kw}  — suggested bid: $1.00-3.00")

    # Content/SEO keyword targets
    print("\n\n📝 BLOG/SEO CONTENT TARGETS\n")
    seo = [(kw, info) for kw, info in KEYWORDS.items() if info["priority"] == "seo"]
    for kw, info in sorted(seo, key=lambda x: x[1]["volume"], reverse=True):
        print(f"  → \"{kw}\" (volume: {info['volume']})")
        if "fall asleep" in kw:
            print(f"    Blog: '7 Science-Backed Ways to Fall Asleep Faster'")
        elif "breathing" in kw and "anxiety" in kw:
            print(f"    Blog: '5 Breathing Exercises for Anxiety Relief (with Guides)'")
        elif "best meditation" in kw:
            print(f"    Blog: 'Best Meditation Apps 2026: Complete Comparison'")
        elif "sleep stories" in kw:
            print(f"    Blog: 'Why Sleep Stories Work: The Science of Bedtime Narratives'")
        elif "navy seal" in kw:
            print(f"    Blog: 'Box Breathing: The Navy SEAL Technique for Instant Calm'")

    # Tracked rankings history
    if data.get("entries"):
        print("\n\n📈 RANKING HISTORY\n")
        for entry in data["entries"][-20:]:
            print(f"  {entry['date'][:10]} | {entry['keyword']:<30} | #{entry['rank']}")


def interactive_mode():
    """Interactive menu for tracking."""
    while True:
        print("\n┌─────────────────────────────────┐")
        print("│  Breathe ASO Tracker            │")
        print("├─────────────────────────────────┤")
        print("│  1. Generate full report         │")
        print("│  2. Log a keyword ranking        │")
        print("│  3. View ranking history          │")
        print("│  4. Exit                          │")
        print("└─────────────────────────────────┘")

        choice = input("\nChoice: ").strip()

        if choice == "1":
            generate_report()
        elif choice == "2":
            print("\nAvailable keywords:")
            for i, kw in enumerate(KEYWORDS.keys(), 1):
                print(f"  {i}. {kw}")
            try:
                idx = int(input("\nKeyword number: ")) - 1
                kw = list(KEYWORDS.keys())[idx]
                rank = int(input(f"Current rank for '{kw}': "))
                log_ranking(kw, rank)
            except (ValueError, IndexError):
                print("Invalid input.")
        elif choice == "3":
            data = load_data()
            if data.get("entries"):
                for entry in data["entries"][-20:]:
                    print(f"  {entry['date'][:10]} | {entry['keyword']:<30} | #{entry['rank']}")
            else:
                print("  No rankings logged yet.")
        elif choice == "4":
            break


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--report":
        generate_report()
    else:
        interactive_mode()
