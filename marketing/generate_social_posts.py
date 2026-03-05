#!/usr/bin/env python3
"""
Breathe App — Social Media Post Generator
Generates ready-to-post content for Reddit, Twitter/X, Instagram, and TikTok.
Run: python3 generate_social_posts.py
"""

import random
from datetime import datetime, timedelta

APP_URL = "https://apps.apple.com/app/id6758229420"
WEBSITE = "https://meditationandsleepapp.com"

# ─── Content Templates ───

REDDIT_POSTS = [
    {
        "subreddit": "r/sleep",
        "title": "The 4-7-8 breathing technique changed my sleep completely",
        "body": """I used to lie in bed for 1-2 hours every night, mind racing. A friend told me about 4-7-8 breathing:

1. Breathe in through your nose for 4 seconds
2. Hold your breath for 7 seconds
3. Exhale slowly through your mouth for 8 seconds
4. Repeat 3-4 times

The key is the long exhale — it activates your parasympathetic nervous system and literally tells your body "it's safe to sleep."

I've been doing this for 3 weeks and I'm usually asleep within 10-15 minutes now. The first few nights felt weird but once your body learns the pattern, it's automatic.

Has anyone else tried this? What breathing technique works for you?"""
    },
    {
        "subreddit": "r/Meditation",
        "title": "Box Breathing: The technique Navy SEALs use to stay calm under pressure",
        "body": """Box breathing is ridiculously simple but incredibly effective:

- Inhale for 4 seconds
- Hold for 4 seconds
- Exhale for 4 seconds
- Hold for 4 seconds

That's it. Repeat for 3-5 minutes.

It's called "box" breathing because all four phases are equal — like the four sides of a box.

Navy SEALs use it before high-stress operations. I started using it before meetings at work and the difference is noticeable. My heart rate drops, my thoughts slow down, and I feel genuinely present.

The science: the equal inhale/exhale ratio balances your CO2 and O2 levels, which calms your autonomic nervous system.

Try it right now — 3 cycles. I'll wait.

How did that feel?"""
    },
    {
        "subreddit": "r/Anxiety",
        "title": "Something that actually helps during a panic attack",
        "body": """I've had anxiety for years and tried a lot of things. Here's what actually works for me in the moment:

**Breathing (4-7-8 technique):**
Inhale 4 seconds, hold 7, exhale 8. The long exhale is the key — it forces your nervous system out of fight-or-flight.

**Body scan:**
Start at the top of your head. Notice any tension. Move to your face, neck, shoulders, arms... all the way down to your toes. Just notice — don't try to change anything. This pulls your attention out of anxious thoughts and into your body.

**Name 5 things:**
5 things you can see, 4 you can touch, 3 you can hear, 2 you can smell, 1 you can taste. Grounding technique that works fast.

None of these are cures. But they've gotten me through some really bad moments.

What works for you?"""
    },
    {
        "subreddit": "r/getdisciplined",
        "title": "I replaced my phone doomscrolling before bed with a 10-minute meditation and here's what happened after 30 days",
        "body": """Rules were simple:
- Phone goes on Do Not Disturb at 9:30 PM
- 10 minutes of guided meditation or breathing exercises
- Then a sleep story or calming sounds until I drift off

**Week 1:** Felt weird. Kept reaching for my phone. Did the meditation anyway.

**Week 2:** Started falling asleep faster. Like noticeably faster. 30 minutes → 15 minutes.

**Week 3:** Started looking forward to the routine. The breathing exercises became automatic.

**Week 4:** Sleep quality improved so much that I'm waking up before my alarm. Energy levels during the day are completely different.

The biggest surprise: my morning anxiety basically disappeared. I think the pre-bed doomscrolling was spiking cortisol right before sleep.

If you're struggling with sleep, just try replacing the last 30 minutes of screen time with something calming. Doesn't have to be meditation — even just listening to rain sounds helps.

Anyone else made a similar switch?"""
    },
    {
        "subreddit": "r/productivity",
        "title": "The Pomodoro technique works 10x better with ambient sounds",
        "body": """I've used Pomodoro for years but recently started adding ambient sounds during focus sessions and the difference is wild.

My setup:
- 25 minute focus blocks
- Rain + fireplace sounds in the background (low volume)
- 5 minute break with breathing exercises
- Every 4 blocks, take a longer 15 minute break

The ambient sounds serve two purposes:
1. They mask distracting noises (office, traffic, etc.)
2. They create a Pavlovian "focus trigger" — my brain now associates rain sounds with deep work

For breaks, I do 2-3 cycles of box breathing instead of checking my phone. This actually recharges you instead of adding more stimulation.

After 2 weeks: I'm getting roughly 2 more hours of productive work done per day.

What's your focus routine?"""
    },
    {
        "subreddit": "r/selfimprovement",
        "title": "Mood tracking changed how I understand myself",
        "body": """3 months ago I started tracking my mood every morning and after meditation sessions. Here's what I learned:

1. **My anxiety peaks on Sundays and Mondays.** I had no idea until I saw the pattern. Now I schedule lighter Mondays and do a longer meditation Sunday evening.

2. **Exercise is more effective than meditation for my mood.** On days I exercise AND meditate, my mood averages 8/10. Meditation alone: 6.5/10. Exercise alone: 7.5/10.

3. **Sleep quality predicts next-day mood with ~80% accuracy.** Bad sleep = bad mood, almost without exception. This made me take sleep hygiene seriously.

4. **Gratitude journaling has a real effect** — but only if I'm specific. "Grateful for my family" does nothing. "Grateful that my friend called to check on me today" actually shifts my mood.

You don't need a fancy app — even a simple 1-10 rating in your notes app works. But the key is consistency. Do it for 30 days minimum before looking for patterns.

What patterns have you noticed in your own mood?"""
    }
]

TWITTER_POSTS = [
    "The 4-7-8 breathing technique:\n\n- Inhale 4 seconds\n- Hold 7 seconds\n- Exhale 8 seconds\n\nRepeat 3x. You'll feel calmer within 60 seconds.\n\nThe long exhale activates your parasympathetic nervous system. It's basically a cheat code for your brain.",
    "Most people doomscroll for 45 minutes before bed then wonder why they can't sleep.\n\nReplace the last 20 minutes with:\n- A breathing exercise (2 min)\n- A sleep story or rain sounds\n\nYou'll fall asleep faster than you have in years.",
    "Meditation doesn't have to be 30 minutes of sitting in silence.\n\n3 minutes of focused breathing counts.\nListening to a sleep story counts.\nA quick body scan at your desk counts.\n\nConsistency > duration.",
    "Box breathing (4-4-4-4) is used by:\n- Navy SEALs\n- First responders\n- Surgeons\n- Athletes\n\nIt's the simplest stress management tool that actually works. 4 cycles takes under 2 minutes.",
    "I tracked my mood every day for 90 days.\n\nBiggest finding: sleep quality predicts next-day mood with ~80% accuracy.\n\nSleep isn't a luxury. It's the foundation everything else is built on.",
    "Your evening routine matters more than your morning routine.\n\nWhat you do in the last 30 minutes before sleep determines:\n- How fast you fall asleep\n- Your sleep quality\n- Your energy tomorrow\n- Your mood tomorrow\n\nProtect those 30 minutes.",
    "The Wim Hof breathing method in 30 seconds:\n\n1. Take 30 deep breaths (in through nose, out through mouth)\n2. Exhale and hold as long as you can\n3. Inhale deep and hold 15 seconds\n4. Repeat 3 rounds\n\nYou'll feel energized, focused, and slightly euphoric.",
    "Unpopular opinion: most meditation apps are overcomplicated.\n\nYou don't need a 47-step onboarding flow.\nYou don't need 17 subscription tiers.\nYou don't need a social feed.\n\nYou need a play button and something calming."
]

TIKTOK_IDEAS = [
    {
        "hook": "Try this 60-second breathing exercise right now",
        "content": "Guide viewer through 4-7-8 breathing with calm background. Count on screen. End with 'Did you feel that? Save this for tonight.'",
        "hashtags": "#breathingexercise #sleep #anxietyrelief #478breathing #meditation #sleephack #mentalhealth"
    },
    {
        "hook": "The Navy SEAL technique for instant calm",
        "content": "Explain box breathing with visual timer. Show 4-4-4-4 pattern. 'This is what special forces use before missions. Try it before your next stressful meeting.'",
        "hashtags": "#boxbreathing #navyseal #stressrelief #calm #anxiety #breathwork #mindfulness"
    },
    {
        "hook": "POV: You finally found a meditation app that isn't annoying",
        "content": "Quick aesthetic walkthrough of Breathe app. Show: home screen, breathing exercise, soundscape mixer, sleep stories. Clean transitions.",
        "hashtags": "#meditationapp #sleepapp #appoftiktok #wellness #selfcare #meditation #calm"
    },
    {
        "hook": "3 sounds that will knock you out in 10 minutes",
        "content": "Demo the soundscape mixer. Layer rain + fireplace + ocean. Show the independent volume controls. 'This combination is sleep magic.'",
        "hashtags": "#sleepsounds #rainsounds #sleephack #insomnia #sleep #asmr #relaxation"
    },
    {
        "hook": "I asked an AI to help with my anxiety and this happened",
        "content": "Show conversation with AI wellness chat. Ask about anxiety. Show the thoughtful, personalized response. 'It actually understood what I was feeling.'",
        "hashtags": "#ai #mentalhealth #anxiety #wellness #aichat #therapy #selfcare"
    },
    {
        "hook": "Wim Hof breathing but make it aesthetic",
        "content": "Guided Wim Hof session with beautiful animated visuals from the app. Fast breaths, hold, recovery breath. 'How do you feel?'",
        "hashtags": "#wimhof #breathwork #wimhofmethod #icebath #energy #morning #breathingexercise"
    },
    {
        "hook": "This is what happens to your body during a body scan",
        "content": "Walk through body scan meditation. Show each body region highlighted. Explain the science of progressive muscle relaxation.",
        "hashtags": "#bodyscan #meditation #relaxation #stressrelief #pmc #mindfulness #sleep"
    },
    {
        "hook": "Replace doomscrolling with this bedtime routine",
        "content": "Show evening routine: phone on DND → breathing exercise (2 min) → sleep story → drift off. Before/after sleep quality comparison.",
        "hashtags": "#bedtimeroutine #sleep #doomscrolling #nightroutine #sleeptips #mentalhealth"
    }
]

INSTAGRAM_CAPTIONS = [
    {
        "type": "Carousel (swipe post)",
        "caption": """5 Breathing Techniques That Actually Work 🫁

Swipe to learn each one →

1️⃣ Box Breathing (4-4-4-4)
Best for: Focus & calm before meetings

2️⃣ 4-7-8 Relaxing Breath
Best for: Falling asleep fast

3️⃣ Wim Hof Method
Best for: Energy & mental clarity

4️⃣ Alternate Nostril
Best for: Balance & anxiety relief

5️⃣ Energizing Breath
Best for: Morning wake-up

Save this post 🔖 and try one tonight.

#breathingexercises #meditation #sleep #anxiety #mindfulness #wellness #boxbreathing #wimhof #breathwork #selfcare"""
    },
    {
        "type": "Reel",
        "caption": """This 60-second breathing exercise will change your night ✨

The 4-7-8 technique was developed by Dr. Andrew Weil and activates your parasympathetic nervous system — literally switching your body from "alert mode" to "rest mode."

Try it tonight. You'll feel the difference immediately.

Link in bio to try Breathe free for 3 days 🫁

#478breathing #sleephack #insomnia #breathingexercise #meditation #sleep #nightroutine #calm #relaxation #mentalhealth"""
    }
]


def generate_weekly_content():
    """Generate a week's worth of content."""
    today = datetime.now()

    print("=" * 60)
    print(f"  BREATHE APP — Weekly Content Plan")
    print(f"  Generated: {today.strftime('%B %d, %Y')}")
    print("=" * 60)

    # Pick content for the week
    reddit_picks = random.sample(REDDIT_POSTS, min(3, len(REDDIT_POSTS)))
    twitter_picks = random.sample(TWITTER_POSTS, min(4, len(TWITTER_POSTS)))
    tiktok_picks = random.sample(TIKTOK_IDEAS, min(3, len(TIKTOK_IDEAS)))

    days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    print("\n📋 WEEKLY SCHEDULE\n")

    # Monday - Reddit
    print(f"━━━ MONDAY ({(today + timedelta(days=(0-today.weekday())%7)).strftime('%b %d')}) ━━━")
    print(f"📌 REDDIT: {reddit_picks[0]['subreddit']}")
    print(f"   Title: {reddit_picks[0]['title']}")
    print(f"   [Full post saved below]\n")

    # Tuesday - TikTok/Reel
    print(f"━━━ TUESDAY ━━━")
    print(f"🎬 TIKTOK/REEL: \"{tiktok_picks[0]['hook']}\"")
    print(f"   {tiktok_picks[0]['content']}")
    print(f"   Tags: {tiktok_picks[0]['hashtags']}\n")

    # Wednesday - Reddit + Twitter
    print(f"━━━ WEDNESDAY ━━━")
    print(f"📌 REDDIT: {reddit_picks[1]['subreddit']}")
    print(f"   Title: {reddit_picks[1]['title']}")
    print(f"🐦 TWITTER/X:")
    print(f"   {twitter_picks[0][:100]}...\n")

    # Thursday - TikTok/Reel
    print(f"━━━ THURSDAY ━━━")
    print(f"🎬 TIKTOK/REEL: \"{tiktok_picks[1]['hook']}\"")
    print(f"   {tiktok_picks[1]['content']}")
    print(f"   Tags: {tiktok_picks[1]['hashtags']}\n")

    # Friday - Twitter + Reddit engagement
    print(f"━━━ FRIDAY ━━━")
    print(f"🐦 TWITTER/X:")
    print(f"   {twitter_picks[1][:100]}...")
    print(f"📌 REDDIT: Engage in 10+ comments on r/sleep, r/Meditation, r/Anxiety\n")

    # Saturday - TikTok/Reel
    print(f"━━━ SATURDAY ━━━")
    print(f"🎬 TIKTOK/REEL: \"{tiktok_picks[2]['hook']}\"")
    print(f"   {tiktok_picks[2]['content']}")
    print(f"   Tags: {tiktok_picks[2]['hashtags']}\n")

    # Sunday - Review + plan
    print(f"━━━ SUNDAY ━━━")
    print(f"📊 REVIEW: Check App Store Connect analytics")
    print(f"📊 REVIEW: Check Reddit post performance")
    print(f"📝 PLAN: Outline next week's content\n")

    # Full Reddit posts
    print("\n" + "=" * 60)
    print("  FULL REDDIT POSTS (copy-paste ready)")
    print("=" * 60)

    for i, post in enumerate(reddit_picks, 1):
        print(f"\n{'─' * 40}")
        print(f"POST {i} — {post['subreddit']}")
        print(f"Title: {post['title']}")
        print(f"{'─' * 40}")
        print(post['body'])

    # Full Twitter posts
    print("\n" + "=" * 60)
    print("  FULL TWITTER/X POSTS (copy-paste ready)")
    print("=" * 60)

    for i, post in enumerate(twitter_picks, 1):
        print(f"\n{'─' * 40}")
        print(f"TWEET {i} ({len(post)} chars)")
        print(f"{'─' * 40}")
        print(post)


if __name__ == "__main__":
    generate_weekly_content()
