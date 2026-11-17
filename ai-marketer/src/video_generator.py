import logging
import time
from typing import List, Optional
import requests

logger = logging.getLogger(__name__)

FAL_SUBMIT_URL = "https://queue.fal.run/fal-ai/kling-video/v2.1/pro/image-to-video"
FAL_STATUS_URL = "https://queue.fal.run/fal-ai/kling-video/v2.1/pro/image-to-video/requests/{request_id}/status"
FAL_RESULT_URL = "https://queue.fal.run/fal-ai/kling-video/v2.1/pro/image-to-video/requests/{request_id}"
POLL_INTERVAL = 10  # seconds — video gen is slow
MAX_POLL_ATTEMPTS = 60  # 10 min max wait


def _fal_headers(api_key: str) -> dict:
    return {
        "Authorization": f"Key {api_key}",
        "Content-Type": "application/json",
    }


def generate_video(
    api_key: str,
    image_url: str,
    prompt: str,
    duration: str = "5",
    aspect_ratio: str = "9:16",
) -> Optional[str]:
    """Generate a video from an image with Kling 2.1 Pro via Fal.ai. Returns video URL or None."""

    logger.info(f"Generating video from image: {prompt[:80]}...")

    # Submit to queue
    try:
        resp = requests.post(
            FAL_SUBMIT_URL,
            headers=_fal_headers(api_key),
            json={
                "prompt": prompt,
                "image_url": image_url,
                "duration": duration,
                "aspect_ratio": aspect_ratio,
                "negative_prompt": "blur, distort, low quality, text overlay, watermark",
                "cfg_scale": 0.5,
            },
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()
    except requests.RequestException as e:
        logger.error(f"Fal.ai submit failed: {e}")
        return None

    request_id = data.get("request_id")
    if not request_id:
        logger.error(f"Fal.ai response missing request_id: {data}")
        return None

    logger.info(f"Video queued: {request_id}")

    # Poll for completion
    status_url = FAL_STATUS_URL.format(request_id=request_id)
    for attempt in range(MAX_POLL_ATTEMPTS):
        time.sleep(POLL_INTERVAL)
        try:
            poll_resp = requests.get(status_url, headers=_fal_headers(api_key), timeout=30)
            poll_resp.raise_for_status()
            poll_data = poll_resp.json()
        except requests.RequestException as e:
            logger.warning(f"Video poll attempt {attempt+1} failed: {e}")
            continue

        status = poll_data.get("status")
        if status == "COMPLETED":
            # Fetch result
            result_url = FAL_RESULT_URL.format(request_id=request_id)
            try:
                result_resp = requests.get(result_url, headers=_fal_headers(api_key), timeout=30)
                result_resp.raise_for_status()
                result_data = result_resp.json()
                video_url = result_data.get("video", {}).get("url")
                if video_url:
                    logger.info(f"Video generated successfully ({attempt * POLL_INTERVAL}s)")
                    return video_url
                logger.error(f"Completed but no video URL: {result_data}")
            except requests.RequestException as e:
                logger.error(f"Failed to fetch video result: {e}")
            return None
        elif status == "FAILED":
            logger.error(f"Video generation failed: {poll_data}")
            return None
        else:
            if attempt % 3 == 0:
                logger.info(f"  Video still processing... ({attempt * POLL_INTERVAL}s, status={status})")

    logger.error(f"Video polling timed out after {MAX_POLL_ATTEMPTS * POLL_INTERVAL}s")
    return None


def generate_videos_for_posts(
    api_key: str,
    posts: list[dict],
    image_urls: list[Optional[str]],
    duration: str = "5",
    aspect_ratio: str = "9:16",
) -> list[Optional[str]]:
    """Generate videos for posts that have images. Uses image-to-video with motion prompts."""

    video_urls = []
    for i, (post, image_url) in enumerate(zip(posts, image_urls)):
        if not image_url:
            logger.warning(f"Post {i+1} has no image, skipping video generation")
            video_urls.append(None)
            continue

        motion_prompt = post.get("video_prompt", post.get("image_prompt", ""))
        if not motion_prompt:
            logger.warning(f"Post {i+1} has no video_prompt, skipping")
            video_urls.append(None)
            continue

        url = generate_video(api_key, image_url, motion_prompt, duration, aspect_ratio)
        video_urls.append(url)

    generated = sum(1 for u in video_urls if u is not None)
    logger.info(f"Generated {generated}/{len(posts)} videos")
    return video_urls
