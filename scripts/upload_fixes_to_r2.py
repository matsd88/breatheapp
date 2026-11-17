#!/usr/bin/env python3 -u
"""Upload duplicate-fix replacement videos to Cloudflare R2."""

import sys
sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

import boto3
from botocore.config import Config
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import time

R2_ACCOUNT_ID = "90e5f5a3668be71e30a2673ed2511b55"
R2_ACCESS_KEY_ID = "6195c9e816c53513b6e3287f6ea0c00f"
R2_SECRET_ACCESS_KEY = "f6bb7fa802731c684b531a8507929b16d0a3465e3d029cea1f6b8c3dbac48ed9"
R2_ENDPOINT = f"https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
R2_BUCKET = "breathe"

OUTPUT_DIR = Path(__file__).parent / "output_fixes"

CONTENT_TYPES = {".m4a": "audio/mp4", ".mp4": "video/mp4", ".jpg": "image/jpeg"}


def get_s3_client():
    return boto3.client(
        "s3", endpoint_url=R2_ENDPOINT,
        aws_access_key_id=R2_ACCESS_KEY_ID,
        aws_secret_access_key=R2_SECRET_ACCESS_KEY,
        config=Config(signature_version="s3v4", retries={"max_attempts": 3, "mode": "adaptive"}),
    )


def format_size(b):
    for u in ["B", "KB", "MB", "GB"]:
        if b < 1024:
            return f"{b:.1f} {u}"
        b /= 1024
    return f"{b:.1f} TB"


def main():
    print("=" * 60)
    print("Duplicate Fix Upload to R2")
    print("=" * 60)
    s3 = get_s3_client()
    print("Testing R2 connection...")
    try:
        s3.head_bucket(Bucket=R2_BUCKET)
        print("Connected!")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
    existing = set()
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=R2_BUCKET, Prefix="videos/"):
        if "Contents" in page:
            for obj in page["Contents"]:
                existing.add(obj["Key"])
    print(f"Existing files in R2: {len(existing)}")
    files = []
    if not OUTPUT_DIR.exists():
        print(f"Error: {OUTPUT_DIR} not found.")
        sys.exit(1)
    for video_dir in OUTPUT_DIR.iterdir():
        if not video_dir.is_dir():
            continue
        for f in video_dir.iterdir():
            if f.is_file():
                key = f"videos/{video_dir.name}/{f.name}"
                if key not in existing:
                    files.append((f, key))
    if not files:
        print("Nothing new to upload!")
        return
    total_size = sum(f[0].stat().st_size for f in files)
    print(f"\nFiles to upload: {len(files)} ({format_size(total_size)})")
    uploaded = failed = 0
    start = time.time()
    def upload(args):
        path, key = args
        ct = CONTENT_TYPES.get(path.suffix.lower(), "application/octet-stream")
        s3.upload_file(str(path), R2_BUCKET, key, ExtraArgs={"ContentType": ct})
        return path, key
    with ThreadPoolExecutor(max_workers=10) as pool:
        futures = {pool.submit(upload, f): f for f in files}
        for future in as_completed(futures):
            path, key = futures[future]
            try:
                future.result()
                uploaded += 1
            except Exception as e:
                failed += 1
                print(f"  FAIL: {key}: {e}")
    elapsed = time.time() - start
    print(f"\nDone! {uploaded} uploaded, {failed} failed in {elapsed/60:.1f} min")


if __name__ == "__main__":
    main()
