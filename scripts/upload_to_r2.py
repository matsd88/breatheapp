#!/usr/bin/env python3 -u
"""
Upload meditation videos to Cloudflare R2.
Uploads the folder structure: {videoID}/audio.m4a, video.mp4, thumb.jpg
"""

import sys
# Force unbuffered output
sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

import boto3
from botocore.config import Config
from pathlib import Path
import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
import time

# R2 Configuration
R2_ACCOUNT_ID = "90e5f5a3668be71e30a2673ed2511b55"
R2_ACCESS_KEY_ID = "6195c9e816c53513b6e3287f6ea0c00f"
R2_SECRET_ACCESS_KEY = "f6bb7fa802731c684b531a8507929b16d0a3465e3d029cea1f6b8c3dbac48ed9"
R2_ENDPOINT = f"https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
R2_BUCKET = "breathe"

# Local paths
OUTPUT_DIR = Path(__file__).parent / "output"

# Content types
CONTENT_TYPES = {
    ".m4a": "audio/mp4",
    ".mp4": "video/mp4",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
}

def get_s3_client():
    """Create S3 client configured for R2."""
    return boto3.client(
        "s3",
        endpoint_url=R2_ENDPOINT,
        aws_access_key_id=R2_ACCESS_KEY_ID,
        aws_secret_access_key=R2_SECRET_ACCESS_KEY,
        config=Config(
            signature_version="s3v4",
            retries={"max_attempts": 3, "mode": "adaptive"},
        ),
    )

def get_content_type(file_path: Path) -> str:
    """Get content type based on file extension."""
    return CONTENT_TYPES.get(file_path.suffix.lower(), "application/octet-stream")

def upload_file(s3_client, local_path: Path, s3_key: str) -> tuple[bool, str]:
    """Upload a single file to R2."""
    try:
        content_type = get_content_type(local_path)
        s3_client.upload_file(
            str(local_path),
            R2_BUCKET,
            s3_key,
            ExtraArgs={"ContentType": content_type},
        )
        return True, s3_key
    except Exception as e:
        return False, f"{s3_key}: {e}"

def get_existing_files(s3_client) -> set:
    """Get set of existing files in R2 bucket."""
    existing = set()
    paginator = s3_client.get_paginator("list_objects_v2")

    print("Checking existing files in R2...")
    try:
        for page in paginator.paginate(Bucket=R2_BUCKET, Prefix="videos/"):
            if "Contents" in page:
                for obj in page["Contents"]:
                    existing.add(obj["Key"])
    except Exception as e:
        print(f"Warning: Could not list existing files: {e}")

    print(f"Found {len(existing)} existing files in R2")
    return existing

def collect_files_to_upload(existing_files: set) -> list[tuple[Path, str]]:
    """Collect all files that need to be uploaded."""
    files_to_upload = []

    if not OUTPUT_DIR.exists():
        print(f"Error: Output directory not found: {OUTPUT_DIR}")
        return files_to_upload

    # Each subdirectory is a video ID
    video_dirs = [d for d in OUTPUT_DIR.iterdir() if d.is_dir()]
    print(f"Found {len(video_dirs)} video directories")

    for video_dir in video_dirs:
        video_id = video_dir.name

        for file_path in video_dir.iterdir():
            if file_path.is_file():
                s3_key = f"videos/{video_id}/{file_path.name}"

                # Skip if already uploaded
                if s3_key in existing_files:
                    continue

                files_to_upload.append((file_path, s3_key))

    return files_to_upload

def format_size(bytes_size: int) -> str:
    """Format bytes as human-readable size."""
    for unit in ["B", "KB", "MB", "GB"]:
        if bytes_size < 1024:
            return f"{bytes_size:.1f} {unit}"
        bytes_size /= 1024
    return f"{bytes_size:.1f} TB"

def upload_worker(args):
    """Worker function for thread pool."""
    s3_client, local_path, s3_key = args
    return upload_file(s3_client, local_path, s3_key)

def main():
    print("=" * 60)
    print("Cloudflare R2 Upload Script")
    print("=" * 60)
    print(f"Bucket: {R2_BUCKET}")
    print(f"Source: {OUTPUT_DIR}")
    print()

    # Create S3 client
    s3_client = get_s3_client()

    # Test connection
    print("Testing R2 connection...")
    try:
        s3_client.head_bucket(Bucket=R2_BUCKET)
        print("Connection successful!")
    except Exception as e:
        print(f"Error: Could not connect to R2 bucket: {e}")
        print("Please check your credentials and bucket name.")
        sys.exit(1)

    print()

    # Get existing files to skip
    existing_files = get_existing_files(s3_client)

    # Collect files to upload
    files_to_upload = collect_files_to_upload(existing_files)

    if not files_to_upload:
        print("No new files to upload!")
        return

    # Calculate total size
    total_size = sum(f[0].stat().st_size for f in files_to_upload)
    print(f"\nFiles to upload: {len(files_to_upload)}")
    print(f"Total size: {format_size(total_size)}")
    print()

    # Upload with progress
    uploaded = 0
    failed = 0
    uploaded_size = 0
    start_time = time.time()

    # Use thread pool for parallel uploads
    max_workers = 10  # Adjust based on your connection

    print(f"Starting upload with {max_workers} parallel workers...")
    print("-" * 60)

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all tasks
        futures = {
            executor.submit(upload_file, s3_client, local_path, s3_key): (local_path, s3_key)
            for local_path, s3_key in files_to_upload
        }

        for future in as_completed(futures):
            local_path, s3_key = futures[future]
            success, message = future.result()

            if success:
                uploaded += 1
                file_size = local_path.stat().st_size
                uploaded_size += file_size

                # Progress update every 10 files
                if uploaded % 10 == 0:
                    elapsed = time.time() - start_time
                    rate = uploaded_size / elapsed if elapsed > 0 else 0
                    remaining = total_size - uploaded_size
                    eta = remaining / rate if rate > 0 else 0

                    print(f"Progress: {uploaded}/{len(files_to_upload)} files | "
                          f"{format_size(uploaded_size)}/{format_size(total_size)} | "
                          f"Speed: {format_size(rate)}/s | "
                          f"ETA: {eta/60:.1f} min")
            else:
                failed += 1
                print(f"FAILED: {message}")

    # Final summary
    elapsed = time.time() - start_time
    print()
    print("=" * 60)
    print("Upload Complete!")
    print("=" * 60)
    print(f"Uploaded: {uploaded} files ({format_size(uploaded_size)})")
    print(f"Failed: {failed} files")
    print(f"Time: {elapsed/60:.1f} minutes")
    print(f"Average speed: {format_size(uploaded_size/elapsed)}/s")

    if failed > 0:
        print("\nSome files failed to upload. Run the script again to retry.")

if __name__ == "__main__":
    main()
