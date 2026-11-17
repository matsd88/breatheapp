#!/usr/bin/env python3
"""Download v33 new videos, then upload to R2."""

import sys
sys.stdout.reconfigure(line_buffering=True)

import os
import json
from pathlib import Path
import time
import urllib.request
from multiprocessing import Process, Queue
from queue import Empty

NEW_IDS = [
    # Meditation (15)
    "QwqlurCvXuM", "SAV1RCnuAaE", "Z7oYJZg9nOA", "PxuNf87E1_c",
    "y5EqO8CQ_cQ", "ft-vhYwHzxw", "EpgusOQUlmA", "L3-SlMJHrms",
    "lNeiLi882MU", "yDJYZXlsASg", "bXk916CpGxw", "AtF0T2fPvbI",
    "c2iCoEluq8A", "9m45ITi-ALw", "yaA_aYEe8JA",
    # Sleep Stories (15)
    "pXzD871cyEw", "N4qCFFBrrgk", "vvfnUHwULvM", "46RQhUE0sD8",
    "_gRQleINoJk", "1uwbPydMLjo", "Rm-4JUivLcE", "D8eplSV1wus",
    "Btn0YZajEkk", "By1-wZ9G2QQ", "jMxHxzY5usw", "3Qx49IyhCME",
    "oJjc4XreJSQ", "ZVXflJ1g298", "a9MZvseN6Ug",
    # Soundscapes (15)
    "7ev8I2AW9ko", "GHqA2Ruhz1E", "40sHfUrDezE", "YN6wj5NfOnM",
    "8_6WU4kqr5A", "jK3cMcH9e_c", "FUQEecZ0HG0", "ih4_1FyVjaY",
    "sT5f1jBJHng", "bbjMDgMz504", "yuybyOCd0Bw", "-PS9EBu8KmQ",
    "Bpq2KdZcOto", "7_-XU8jSGZM", "OD5worsS-Mg",
    # Music (15)
    "o-9T184mpY4", "tQGE_Mivb8M", "UllduL1OqOc", "OHzT6IMx_S8",
    "uwEaQk5VeS4", "j_3C0z96GE0", "c1rX8wQ80JE", "9Y5XmI8KiUc",
    "W-hrBhA4XkM", "d2MfVktfYFU", "FuZgOP5zOQM", "vNwYtllyt3Q",
    "dCvEgqePl84", "QCT3WcUPPmI", "MzgMBrtrFc4",
    # Movement (15)
    "IyINAjEoTIs", "nmmNWj9YtAw", "CCicH-iz1oU", "kfjVFQWWiZw",
    "E2YqFYFLSbE", "24qDdn2QXjk", "xM2Z-miz3Y4", "QoB9wpuO688",
    "XZM1xiY9jOw", "01L4f_oT6DM", "XeXz8fIZDCE", "2eA2Koq6pTI",
    "8XNpAg5mDS8", "4TQsfBYCyKQ", "IMB-7y1lfqs",
    # Mindset (15)
    "heh5XLwZVOY", "sx2CBR0O6RY", "Yhn1Fe8cT0Q", "KUWn_TJTrnU",
    "75GFzikmRY0", "1naEi1f0Zo4", "FbmwWvZEdZw", "3qELiw_1Ddg",
    "VNCL1glwyOI", "V3vhXQy48jo", "lLZ-3TSoe9E", "LX71ZTAsmg8",
    "gh2m0dj_lFk", "KXvyd-tkrmc", "SxA69uUGEUI",
]

OUTPUT_DIR = Path(__file__).parent / "output_v33"
PROGRESS_FILE = Path(__file__).parent / "download_v33_progress.json"


def load_progress():
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE) as f:
            return json.load(f)
    return {"completed": [], "failed": []}


def save_progress(progress):
    with open(PROGRESS_FILE, "w") as f:
        json.dump(progress, f, indent=2)


def _do_download(video_id, output_dir, result_queue):
    from pytubefix import YouTube

    video_dir = output_dir / video_id
    video_dir.mkdir(parents=True, exist_ok=True)
    url = f"https://www.youtube.com/watch?v={video_id}"
    errors = []

    try:
        yt = YouTube(url)
    except Exception as e:
        result_queue.put((False, f"Failed to load: {str(e)[:80]}"))
        return

    # Audio
    audio_path = video_dir / "audio.m4a"
    if not audio_path.exists():
        try:
            stream = yt.streams.filter(only_audio=True, mime_type='audio/mp4').order_by('abr').desc().first()
            if stream:
                stream.download(output_path=str(video_dir), filename='audio.m4a')
            else:
                errors.append("No audio stream")
        except Exception as e:
            errors.append(f"Audio: {str(e)[:50]}")

    # Video
    video_path = video_dir / "video.mp4"
    if not video_path.exists():
        try:
            stream = yt.streams.filter(progressive=True, file_extension='mp4').order_by('resolution').desc().first()
            if stream:
                stream.download(output_path=str(video_dir), filename='video.mp4')
            else:
                errors.append("No video stream")
        except Exception as e:
            errors.append(f"Video: {str(e)[:50]}")

    # Thumbnail
    thumb_path = video_dir / "thumb.jpg"
    if not thumb_path.exists():
        try:
            thumb_url = f"https://img.youtube.com/vi/{video_id}/mqdefault.jpg"
            urllib.request.urlretrieve(thumb_url, str(thumb_path))
        except Exception as e:
            errors.append(f"Thumb: {str(e)[:50]}")

    success = audio_path.exists() and video_path.exists() and thumb_path.exists()
    result_queue.put((success, "; ".join(errors) if errors else ""))


def download_video(video_id, progress, timeout=120):
    if video_id in progress["completed"]:
        return video_id, True, "Already done"

    result_queue = Queue()
    proc = Process(target=_do_download, args=(video_id, OUTPUT_DIR, result_queue))
    proc.start()
    proc.join(timeout=timeout)

    if proc.is_alive():
        proc.terminate()
        proc.join(timeout=5)
        if proc.is_alive():
            proc.kill()
        if video_id not in progress["failed"]:
            progress["failed"].append(video_id)
        return video_id, False, "Timed out"

    try:
        success, error = result_queue.get_nowait()
    except Empty:
        success, error = False, "No result"

    if success:
        progress["completed"].append(video_id)
        if video_id in progress["failed"]:
            progress["failed"].remove(video_id)
    elif video_id not in progress["failed"]:
        progress["failed"].append(video_id)

    return video_id, success, error


def main():
    print("=" * 60)
    print("v33 Content Download (90 new videos)")
    print("=" * 60)

    try:
        import pytubefix
        print(f"pytubefix {pytubefix.__version__}")
    except ImportError:
        print("ERROR: pip install pytubefix")
        sys.exit(1)

    OUTPUT_DIR.mkdir(exist_ok=True)
    progress = load_progress()
    remaining = [v for v in NEW_IDS if v not in progress["completed"]]

    print(f"Total: {len(NEW_IDS)} | Done: {len(progress['completed'])} | Remaining: {len(remaining)}")

    if not remaining:
        print("\nAll done! Run upload_v33_to_r2.py to upload.")
        return

    start = time.time()
    ok = fail = 0

    for i, vid in enumerate(remaining, 1):
        print(f"[{i}/{len(remaining)}] {vid}...", end=" ", flush=True)
        _, success, error = download_video(vid, progress)
        if success:
            ok += 1
            print("OK")
        else:
            fail += 1
            print(f"FAIL: {error}")

        if i % 5 == 0:
            save_progress(progress)
            elapsed = time.time() - start
            rate = i / elapsed * 60 if elapsed > 0 else 0
            eta = (len(remaining) - i) / rate if rate > 0 else 0
            print(f"    Progress: {ok} ok, {fail} fail | {rate:.0f}/min | ETA: {eta:.0f} min")

        time.sleep(0.5)

    save_progress(progress)
    elapsed = time.time() - start
    print(f"\nDone! {ok} downloaded, {fail} failed in {elapsed/60:.1f} min")
    print("Next: python3 upload_v33_to_r2.py")


if __name__ == "__main__":
    main()
