import logging
from typing import List, Optional
import requests

logger = logging.getLogger(__name__)


def _post_to_trigger(trigger_url: str, payload: dict, label: str, dry_run: bool) -> dict:
    if dry_run:
        logger.info(f"  [DRY RUN] {label}: {payload.get('scheduled', '?')}")
        logger.info(f"    Text preview: {payload['text'][:100]}...")
        media = payload.get("media_urls", [])
        if media:
            logger.info(f"    Media: {len(media)} file(s)")
        return {"status": "dry_run", "scheduled": payload.get("scheduled"), "trigger": label}

    try:
        resp = requests.post(trigger_url, json=payload, timeout=30)
        resp.raise_for_status()
        logger.info(f"  {label} scheduled for {payload.get('scheduled')} — {resp.status_code}")
        return {"status": "published", "scheduled": payload.get("scheduled"), "trigger": label, "response_code": resp.status_code}
    except requests.RequestException as e:
        logger.error(f"  {label} failed: {e}")
        return {"status": "failed", "scheduled": payload.get("scheduled"), "trigger": label, "error": str(e)}


def publish_to_feedhive(
    trigger_posts: str,
    trigger_reels: str,
    posts: list[dict],
    schedules: list[str],
    image_urls: list[Optional[str]] = None,
    video_urls: list[Optional[str]] = None,
    dry_run: bool = False,
) -> list[dict]:
    results = []

    if image_urls is None:
        image_urls = [None] * len(posts)
    if video_urls is None:
        video_urls = [None] * len(posts)

    for i, (post, scheduled_at, img_url, vid_url) in enumerate(
        zip(posts, schedules, image_urls, video_urls)
    ):
        post_type = post.get("type", "unknown")
        hashtags = post.get("hashtags", [])
        hashtag_str = "\n\n" + " ".join(hashtags) if hashtags else ""

        logger.info(f"Post {i+1}/{len(posts)} [{post_type}]:")

        # Long-form + image → Posts trigger (Facebook, Instagram feed)
        if trigger_posts:
            long_text = post.get("long", post.get("short", "")) + hashtag_str
            payload = {"text": long_text, "scheduled": scheduled_at}
            if img_url:
                payload["media_urls"] = [img_url]
            results.append(_post_to_trigger(trigger_posts, payload, f"posts/{post_type}", dry_run))

        # Short-form + video → Reels trigger (Reels, Shorts, TikTok)
        if trigger_reels:
            short_text = post.get("short", post.get("long", "")) + hashtag_str
            payload = {"text": short_text, "scheduled": scheduled_at}
            if vid_url:
                payload["media_urls"] = [vid_url]
            elif img_url:
                # Fallback to image if video generation failed
                payload["media_urls"] = [img_url]
            results.append(_post_to_trigger(trigger_reels, payload, f"reels/{post_type}", dry_run))

        if not trigger_posts and not trigger_reels:
            logger.warning(f"  No triggers configured — skipping post {i+1}")
            results.append({"status": "skipped", "scheduled": scheduled_at, "type": post_type})

    published = sum(1 for r in results if r["status"] == "published")
    dry = sum(1 for r in results if r["status"] == "dry_run")
    failed = sum(1 for r in results if r["status"] == "failed")

    if dry_run:
        logger.info(f"Dry run complete: {dry} posts would be scheduled")
    else:
        logger.info(f"FeedHive results: {published} published, {failed} failed")

    return results
