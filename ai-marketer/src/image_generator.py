import logging
import time
from typing import List, Optional
import requests

logger = logging.getLogger(__name__)

BFL_API_URL = "https://api.bfl.ai/v1/flux-2-pro"
POLL_INTERVAL = 2  # seconds
MAX_POLL_ATTEMPTS = 60  # 2 min max wait


def generate_image(api_key: str, prompt: str, width: int = 1080, height: int = 1080) -> Optional[str]:
    """Generate an image with Flux Pro via BFL API. Returns the image URL or None on failure."""

    logger.info(f"Generating image: {prompt[:80]}...")

    # Submit generation request
    try:
        resp = requests.post(
            BFL_API_URL,
            headers={"x-key": api_key, "Content-Type": "application/json"},
            json={"prompt": prompt, "width": width, "height": height},
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()
    except requests.RequestException as e:
        logger.error(f"BFL submit failed: {e}")
        return None

    polling_url = data.get("polling_url")
    request_id = data.get("id")
    if not polling_url or not request_id:
        logger.error(f"BFL response missing polling_url or id: {data}")
        return None

    # Poll for result
    for attempt in range(MAX_POLL_ATTEMPTS):
        time.sleep(POLL_INTERVAL)
        try:
            poll_resp = requests.get(
                polling_url,
                headers={"x-key": api_key},
                params={"id": request_id},
                timeout=30,
            )
            poll_resp.raise_for_status()
            poll_data = poll_resp.json()
        except requests.RequestException as e:
            logger.warning(f"Poll attempt {attempt+1} failed: {e}")
            continue

        status = poll_data.get("status")
        if status == "Ready":
            image_url = poll_data.get("result", {}).get("sample")
            if image_url:
                logger.info(f"Image generated successfully ({attempt*POLL_INTERVAL}s)")
                return image_url
            logger.error(f"Ready but no sample URL: {poll_data}")
            return None
        elif status in ("Error", "Failed"):
            logger.error(f"BFL generation failed: {poll_data}")
            return None

    logger.error(f"BFL polling timed out after {MAX_POLL_ATTEMPTS * POLL_INTERVAL}s")
    return None


def generate_images_for_posts(api_key: str, posts: list[dict], aspect: str = "square") -> list[Optional[str]]:
    """Generate images for a list of posts. Each post should have an 'image_prompt' field."""

    if aspect == "square":
        width, height = 1080, 1080
    elif aspect == "portrait":
        width, height = 1080, 1920
    elif aspect == "landscape":
        width, height = 1920, 1080
    else:
        width, height = 1080, 1080

    image_urls = []
    for i, post in enumerate(posts):
        prompt = post.get("image_prompt")
        if not prompt:
            logger.warning(f"Post {i+1} has no image_prompt, skipping image generation")
            image_urls.append(None)
            continue

        url = generate_image(api_key, prompt, width, height)
        image_urls.append(url)

    generated = sum(1 for u in image_urls if u is not None)
    logger.info(f"Generated {generated}/{len(posts)} images")
    return image_urls
