#!/usr/bin/env python3
"""AI Marketing Agent for Trending.fm — generates weekly social + Reddit content."""

import argparse
import json
import logging
import sys
from datetime import datetime
from pathlib import Path

from dotenv import load_dotenv
import os
import anthropic

from src.config_loader import load_config
from src.content_generator import generate_social_posts, generate_reddit_posts
from src.scheduler import schedule_social_posts, schedule_reddit_posts
from src.feedhive_publisher import publish_to_feedhive
from src.reddit_writer import write_reddit_posts
from src.image_generator import generate_images_for_posts
from src.video_generator import generate_videos_for_posts


def setup_logging(log_dir: Path) -> None:
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f"run_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.log"

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler(sys.stdout),
        ],
    )
    logging.info(f"Logging to {log_file}")


def main():
    parser = argparse.ArgumentParser(description="AI Marketing Agent for Trending.fm")
    parser.add_argument("--dry-run", action="store_true", help="Generate content but skip FeedHive publishing")
    parser.add_argument("--reddit-only", action="store_true", help="Only generate Reddit posts")
    parser.add_argument("--social-only", action="store_true", help="Only generate social posts + FeedHive")
    parser.add_argument("--no-media", action="store_true", help="Skip image/video generation (text only)")
    parser.add_argument("--images-only", action="store_true", help="Generate images but skip video generation")
    parser.add_argument("--config", type=str, default=None, help="Path to YAML config file")
    args = parser.parse_args()

    project_root = Path(__file__).parent
    load_dotenv(project_root / ".env")

    setup_logging(project_root / "logs")
    logger = logging.getLogger("run")

    logger.info("=" * 60)
    logger.info("AI Marketing Agent — Starting run")
    logger.info(f"Time: {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}")
    logger.info(f"Options: dry_run={args.dry_run}, reddit_only={args.reddit_only}, social_only={args.social_only}, no_media={args.no_media}")
    logger.info("=" * 60)

    # Load config
    config = load_config(args.config)
    logger.info(f"Loaded config for: {config['app']['name']}")

    # Check required env vars
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        logger.error("ANTHROPIC_API_KEY not set in .env")
        sys.exit(1)

    dry_run = args.dry_run or os.getenv("DRY_RUN", "false").lower() == "true"
    trigger_posts = os.getenv("FEEDHIVE_TRIGGER_POSTS", "")
    trigger_reels = os.getenv("FEEDHIVE_TRIGGER_REELS", "")
    bfl_api_key = os.getenv("BFL_API_KEY", "")
    fal_api_key = os.getenv("FAL_API_KEY", "")

    client = anthropic.Anthropic(api_key=api_key)

    # --- Social Posts ---
    if not args.reddit_only:
        logger.info("\n--- Generating Social Posts ---")
        try:
            social_posts = generate_social_posts(client, config)
            social_schedules = schedule_social_posts(num_posts=len(social_posts))

            logger.info("\nGenerated social posts:")
            for i, post in enumerate(social_posts):
                logger.info(f"\n  [{post.get('type', '?')}] scheduled: {social_schedules[i]}")
                logger.info(f"  Short: {post.get('short', 'N/A')[:100]}")

            # --- Image Generation ---
            image_urls = [None] * len(social_posts)
            video_urls = [None] * len(social_posts)

            if not args.no_media and bfl_api_key:
                logger.info("\n--- Generating Images (Flux Pro) ---")
                try:
                    image_urls = generate_images_for_posts(bfl_api_key, social_posts)
                except Exception as e:
                    logger.error(f"Image generation failed: {e}", exc_info=True)

                # --- Video Generation ---
                if not args.images_only and fal_api_key:
                    logger.info("\n--- Generating Videos (Kling 2.1 Pro) ---")
                    try:
                        video_urls = generate_videos_for_posts(
                            fal_api_key, social_posts, image_urls,
                            duration="5", aspect_ratio="9:16",
                        )
                    except Exception as e:
                        logger.error(f"Video generation failed: {e}", exc_info=True)
                elif not fal_api_key and not args.images_only:
                    logger.warning("FAL_API_KEY not set — skipping video generation")
            elif not bfl_api_key and not args.no_media:
                logger.warning("BFL_API_KEY not set — skipping image/video generation")

            # --- Publish to FeedHive ---
            if not trigger_posts and not trigger_reels and not dry_run:
                logger.warning("No FeedHive triggers set — forcing dry run")
                dry_run_social = True
            else:
                dry_run_social = dry_run

            logger.info(f"\nTriggers: posts={'yes' if trigger_posts else 'no'}, reels={'yes' if trigger_reels else 'no'}")
            img_count = sum(1 for u in image_urls if u)
            vid_count = sum(1 for u in video_urls if u)
            logger.info(f"Media: {img_count} images, {vid_count} videos")

            results = publish_to_feedhive(
                trigger_posts=trigger_posts,
                trigger_reels=trigger_reels,
                posts=social_posts,
                schedules=social_schedules,
                image_urls=image_urls,
                video_urls=video_urls,
                dry_run=dry_run_social,
            )

            # Save social posts to log for reference
            social_log = project_root / "logs" / f"social_{datetime.utcnow().strftime('%Y%m%d')}.json"
            social_log.write_text(json.dumps(
                [
                    {"post": p, "scheduled": s, "image_url": img, "video_url": vid}
                    for p, s, img, vid in zip(social_posts, social_schedules, image_urls, video_urls)
                ],
                indent=2,
            ))
            logger.info(f"Social posts saved to {social_log}")

        except Exception as e:
            logger.error(f"Social post generation failed: {e}", exc_info=True)

    # --- Reddit Posts ---
    if not args.social_only:
        logger.info("\n--- Generating Reddit Posts ---")
        try:
            reddit_posts = generate_reddit_posts(client, config)
            reddit_schedules = schedule_reddit_posts(num_posts=len(reddit_posts))

            files = write_reddit_posts(
                posts=reddit_posts,
                schedules=reddit_schedules,
            )

            logger.info(f"\nReddit posts written to:")
            for f in files:
                logger.info(f"  {f}")

        except Exception as e:
            logger.error(f"Reddit post generation failed: {e}", exc_info=True)

    logger.info("\n" + "=" * 60)
    logger.info("Run complete")
    logger.info("=" * 60)


if __name__ == "__main__":
    main()
