import random
from datetime import datetime, timedelta


# US-friendly posting windows (hour in ET approximation — UTC-5)
SOCIAL_WINDOWS = [
    (12, 30),  # 7:30 AM ET
    (13, 0),   # 8:00 AM ET
    (14, 15),  # 9:15 AM ET
    (16, 0),   # 11:00 AM ET
    (17, 30),  # 12:30 PM ET
    (19, 0),   # 2:00 PM ET
    (21, 0),   # 4:00 PM ET
    (23, 0),   # 6:00 PM ET
]

# Social posts: Mon–Fri (0=Mon, 4=Fri)
SOCIAL_DAYS = [0, 1, 2, 3, 4]

# Reddit posts: Tue, Thu, Sat (1, 3, 5)
REDDIT_DAYS = [1, 3, 5]


def get_next_monday(from_date: datetime = None) -> datetime:
    if from_date is None:
        from_date = datetime.utcnow()
    days_ahead = 7 - from_date.weekday()  # 0=Mon
    if from_date.weekday() == 0:
        days_ahead = 7
    return from_date.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=days_ahead)


def schedule_social_posts(num_posts: int = 6, from_date: datetime = None) -> list[str]:
    monday = get_next_monday(from_date)

    # Pick days for posts — spread across the week
    if num_posts <= len(SOCIAL_DAYS):
        chosen_days = sorted(random.sample(SOCIAL_DAYS, num_posts))
    else:
        chosen_days = list(SOCIAL_DAYS)
        extra = num_posts - len(SOCIAL_DAYS)
        chosen_days += sorted(random.sample(SOCIAL_DAYS, extra))
        chosen_days.sort()

    schedules = []
    for day_offset in chosen_days:
        post_date = monday + timedelta(days=day_offset)
        hour, minute = random.choice(SOCIAL_WINDOWS)
        # Add some jitter (±15 min)
        jitter = random.randint(-15, 15)
        minute = max(0, min(59, minute + jitter))
        scheduled = post_date.replace(hour=hour, minute=minute)
        schedules.append(scheduled.strftime("%Y-%m-%dT%H:%M:%SZ"))

    return schedules


def schedule_reddit_posts(num_posts: int = 3, from_date: datetime = None) -> list[str]:
    monday = get_next_monday(from_date)

    chosen_days = REDDIT_DAYS[:num_posts]

    schedules = []
    for day_offset in chosen_days:
        post_date = monday + timedelta(days=day_offset)
        hour, minute = random.choice(SOCIAL_WINDOWS)
        scheduled = post_date.replace(hour=hour, minute=minute)
        schedules.append(scheduled.strftime("%Y-%m-%dT%H:%M:%SZ"))

    return schedules
