#!/usr/bin/env python3
"""Download replacement videos for 17 duplicate ID fixes."""

import sys
sys.stdout.reconfigure(line_buffering=True)

import json
from pathlib import Path
import time
import urllib.request
from multiprocessing import Process, Queue
from queue import Empty

NEW_IDS = [
    "c0aqDu8Dmvo", "OnQtuOlJBoY", "91YBinrDHrs", "7FHHXTUsJx0",
    "xLOJt2NJZqI", "-40Tgg07J9A", "6p_yaNFSYao", "tvT4a2nYvOk",
    "VlU4eDBNeEQ", "K3GlXuWv3Uc", "HFlxEM6zZsc", "7heIFvaVu-Y",
    "sTANio_2E0Q", "WeEaX0xy9ic", "FWTNMzK9vG4", "CuCptHYw_-c",
    "oDC6Xcyt65Q",
]

OUTPUT_DIR = Path(__file__).parent / "output_fixes"
PROGRESS_FILE = Path(__file__).parent / "download_fixes_progress.json"


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
    print("Duplicate Fix Downloads (17 replacement videos)")
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
        print("\nAll done!")
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
        time.sleep(0.5)
    save_progress(progress)
    elapsed = time.time() - start
    print(f"\nDone! {ok} downloaded, {fail} failed in {elapsed/60:.1f} min")


if __name__ == "__main__":
    main()
