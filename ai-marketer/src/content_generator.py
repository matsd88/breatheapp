import json
import logging
import anthropic

logger = logging.getLogger(__name__)

MODEL = "claude-sonnet-4-5-20250929"


def _strip_json_fences(text: str) -> str:
    text = text.strip()
    if text.startswith("```json"):
        text = text[7:]
    elif text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()


def _call_claude(client: anthropic.Anthropic, system: str, user: str) -> str:
    response = client.messages.create(
        model=MODEL,
        max_tokens=4096,
        system=system,
        messages=[{"role": "user", "content": user}],
    )
    return response.content[0].text


def generate_social_posts(client: anthropic.Anthropic, config: dict) -> list[dict]:
    app = config["app"]
    benefits = config["benefits"]
    voice = config["voice"]["social"]
    post_types = config["social_post_types"]

    benefits_text = "\n".join(f"- {b}" for b in benefits)
    types_text = "\n".join(
        f"- {pt['type']}: {pt['description']} (angle: {pt['example_angle']})"
        for pt in post_types
    )
    do_text = "\n".join(f"- {d}" for d in voice["do"])
    dont_text = "\n".join(f"- {d}" for d in voice["dont"])

    system = f"""You are a brand content creator for {app['name']}, a {app['platform']} music streaming app.
Tagline: "{app['tagline']}"
Description: {app['description']}

Key benefits:
{benefits_text}

App Store URL: {app['app_store_url']}

Voice/tone: {voice['tone']}
DO:
{do_text}
DON'T:
{dont_text}

You must return ONLY valid JSON, no other text."""

    user = f"""Generate 6 social media posts for next week. Each post should be a different type:
{types_text}

For each post, provide:
1. "type" — the post type name
2. "long" — full post for LinkedIn/Facebook (150-280 words)
3. "short" — condensed version for X/Instagram (under 280 characters)
4. "hashtags" — 3-5 relevant hashtags
5. "image_prompt" — a detailed prompt for AI image generation (Flux Pro). Describe a visually striking,
   social-media-ready image that complements the post. Be specific about composition, colors, mood,
   lighting, and style. Use a modern, clean aesthetic. Do NOT include any text/words in the image.
   The image should work as a square (1:1) social post image.
6. "video_prompt" — a short motion/camera description to animate the image into a 5-second reel.
   Describe camera movement (slow zoom, pan, parallax), subtle animations (particles, light shifts,
   gentle motion), and mood. Keep it cinematic and smooth. Example: "Slow zoom in with gentle
   light particles floating upward, warm golden hour glow intensifying"

The CTA post should include the App Store link: {app['app_store_url']}
All other posts should NOT include the link.

Return a JSON array of 6 objects. Example format:
[
  {{
    "type": "educational",
    "long": "Full post text here...",
    "short": "Short version here...",
    "hashtags": ["#MusicDiscovery", "#Playlist"],
    "image_prompt": "Overhead flat-lay of vintage vinyl records scattered on a warm oak table, soft golden hour light streaming from the left, shallow depth of field, moody and nostalgic, clean modern photography style",
    "video_prompt": "Slow dolly zoom out revealing more records, dust particles floating in the light beam, gentle warm light pulsing"
  }}
]"""

    logger.info("Generating social posts via Claude...")
    raw = _call_claude(client, system, user)
    cleaned = _strip_json_fences(raw)

    try:
        posts = json.loads(cleaned)
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse social posts JSON: {e}")
        logger.error(f"Raw response:\n{raw[:500]}")
        raise

    if not isinstance(posts, list) or len(posts) < 1:
        raise ValueError(f"Expected list of posts, got: {type(posts)}")

    logger.info(f"Generated {len(posts)} social posts")
    return posts


def generate_reddit_posts(client: anthropic.Anthropic, config: dict) -> list[dict]:
    subreddits = config["subreddits"]
    voice = config["voice"]["reddit"]

    # Pick 3 different subreddits
    import random
    chosen = random.sample(subreddits, min(3, len(subreddits)))

    subs_text = "\n".join(
        f"- {s['name']}: {s['focus']} (style: {s['style']})"
        for s in chosen
    )
    do_text = "\n".join(f"- {d}" for d in voice["do"])
    dont_text = "\n".join(f"- {d}" for d in voice["dont"])

    system = f"""You are a genuine music enthusiast who loves discovering and sharing music.
You are NOT a marketer. You are a real person who participates in music communities.

Voice/tone: {voice['tone']}
DO:
{do_text}
DON'T:
{dont_text}

CRITICAL RULES:
- NEVER mention any app, product, or service by name
- NEVER include any links or URLs
- Write as a genuine community member
- Be specific about artists, albums, genres — not generic

You must return ONLY valid JSON, no other text."""

    user = f"""Write 3 Reddit posts, one for each of these subreddits:
{subs_text}

Each post should be something a genuine music fan would write — a discussion starter,
a recommendation, a question, or a shared experience. The post should provide real value
to the community.

For each post, provide:
1. "subreddit" — the subreddit name (e.g., "r/Music")
2. "title" — the post title
3. "body" — the full post body (100-300 words)
4. "flair" — suggested flair if applicable (or null)

Return a JSON array of 3 objects. Example format:
[
  {{
    "subreddit": "r/Music",
    "title": "Post title here",
    "body": "Full post body here...",
    "flair": "Discussion"
  }}
]"""

    logger.info("Generating Reddit posts via Claude...")
    raw = _call_claude(client, system, user)
    cleaned = _strip_json_fences(raw)

    try:
        posts = json.loads(cleaned)
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse Reddit posts JSON: {e}")
        logger.error(f"Raw response:\n{raw[:500]}")
        raise

    if not isinstance(posts, list) or len(posts) < 1:
        raise ValueError(f"Expected list of posts, got: {type(posts)}")

    logger.info(f"Generated {len(posts)} Reddit posts")
    return posts
