#!/usr/bin/env python3
import os
from app import play_file, UPLOAD_FOLDER  # import from where your function is defined

# Which file extensions count as "video"
VIDEO_EXTENSIONS = {".mp4", ".avi", ".mkv", ".mov", ".m4v"}

def find_first_video(folder: str) -> str | None:
    """
    Return the first video filename (not full path) found in `folder`,
    sorted alphabetically. Returns None if no video files are found.
    """
    try:
        entries = os.listdir(folder)
    except FileNotFoundError:
        return None

    videos = []
    for name in entries:
        full_path = os.path.join(folder, name)
        if not os.path.isfile(full_path):
            continue
        _, ext = os.path.splitext(name)
        if ext.lower() in VIDEO_EXTENSIONS:
            videos.append(name)

    if not videos:
        return None

    videos.sort()  # "first" = alphabetically first
    return videos[0]


if __name__ == "__main__":
    folder = UPLOAD_FOLDER  # this should already be set to "videos", or similar
    video = find_first_video(folder)
    if not video:
        raise SystemExit(f"No video files found in folder: {folder!r}")

    ok = play_file(video, loop=True)  # change loop=True/False as you like
    if not ok:
        raise SystemExit(f"Failed to start video {video!r}")
