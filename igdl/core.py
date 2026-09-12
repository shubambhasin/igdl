"""Core download logic: yt-dlp + ffmpeg, no CLI concerns here."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
import urllib.request
from dataclasses import dataclass
from pathlib import Path

import yt_dlp

FFMPEG_INSTALL_HINT = "ffmpeg not found on PATH. Install it with:\n\n    brew install ffmpeg\n"

SUPPORTED_BROWSERS = {"chrome", "safari", "firefox", "edge", "brave", "opera", "vivaldi"}


class IGDLError(Exception):
    """Raised for any expected, user-facing failure (missing ffmpeg, bad URL, download failure)."""


def check_ffmpeg() -> str:
    """Return the path to ffmpeg on PATH, or raise IGDLError with an install hint."""
    path = shutil.which("ffmpeg")
    if not path:
        raise IGDLError(FFMPEG_INSTALL_HINT)
    return path


def validate_url(url: str) -> None:
    if "instagram.com" not in url:
        raise IGDLError(f"Not an Instagram URL: {url!r}")


@dataclass
class DownloadResult:
    path: Path
    size_bytes: int


def download(
    url: str,
    out_dir: Path,
    filename: str | None = None,
    cookies_from_browser: str | None = None,
    verbose: bool = False,
) -> list[DownloadResult]:
    """Download an Instagram reel/post/carousel into out_dir.

    Returns one DownloadResult per saved file: a single video/image for a plain
    reel or image post, or one per item for a carousel (each item downloaded
    as a video or an image, whichever it actually is).
    """
    validate_url(url)
    check_ffmpeg()

    out_dir = Path(out_dir).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    outtmpl = str(out_dir / (filename or "%(id)s.%(ext)s"))

    ydl_opts: dict = {
        # Prefer H.264 video + AAC audio when Instagram offers it; VP9/AV1 (its
        # other common formats) don't play in QuickTime/Photos/AVFoundation on
        # macOS, so we transcode below if this fallback is what we get instead.
        "format": (
            "bv*[vcodec^=avc1]+ba[acodec^=mp4a]"
            "/bv*[vcodec^=avc1]+ba"
            "/b[vcodec^=avc1]"
            "/bv*+ba/b"
        ),
        "merge_output_format": "mp4",
        "outtmpl": outtmpl,
        "quiet": not verbose,
        "no_warnings": not verbose,
        "noprogress": not verbose,
        "restrictfilenames": False,
        # yt-dlp's Instagram extractor only handles video; image posts and
        # image items inside a carousel would otherwise abort extraction
        # entirely with "No video formats found!". This lets extraction
        # succeed so we can pull each image's real URL from its thumbnail
        # list ourselves (see _best_image_url / _download_image below).
        "ignore_no_formats_error": True,
    }

    if cookies_from_browser:
        browser = cookies_from_browser.lower()
        if browser not in SUPPORTED_BROWSERS:
            raise IGDLError(
                f"Unsupported --cookies-from-browser value: {cookies_from_browser!r} "
                f"(expected one of: {', '.join(sorted(SUPPORTED_BROWSERS))})"
            )
        ydl_opts["cookiesfrombrowser"] = (browser,)

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            items = [item for item in (info.get("entries") or [info]) if item]
            if not items:
                raise IGDLError("No downloadable video or image found at this URL.")
            multi = len(items) > 1

            results: list[DownloadResult] = []
            for item in items:
                if item.get("formats"):
                    ydl.process_video_result(item, download=True)
                    video_path = _resolve_output_path(item, ydl_opts, out_dir)
                    if not video_path or not video_path.exists():
                        continue
                    if _needs_h264_transcode(item):
                        _transcode_to_h264(video_path, verbose=verbose)
                    results.append(DownloadResult(path=video_path, size_bytes=video_path.stat().st_size))
                else:
                    image_url = _best_image_url(item.get("thumbnails") or [])
                    if not image_url:
                        continue
                    dest = _image_output_path(item, out_dir, filename, multi)
                    _download_image(image_url, dest)
                    results.append(DownloadResult(path=dest, size_bytes=dest.stat().st_size))
    except yt_dlp.utils.DownloadError as exc:
        raise IGDLError(_friendly_error(str(exc))) from exc

    if not results:
        raise IGDLError("Download finished but no files could be saved.")

    return results


def _resolve_output_path(info: dict, ydl_opts: dict, out_dir: Path) -> Path | None:
    requested = info.get("requested_downloads") or []
    if requested:
        candidate = requested[-1].get("filepath")
        if candidate:
            return Path(candidate)

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        prepared = ydl.prepare_filename(info)
    prepared_path = Path(prepared)
    mp4_path = prepared_path.with_suffix(".mp4")
    if mp4_path.exists():
        return mp4_path
    if prepared_path.exists():
        return prepared_path
    return None


_IMAGE_RESOLUTION_RE = re.compile(r"_s(\d+)x(\d+)_")


def _best_image_url(thumbnails: list[dict]) -> str | None:
    """Pick the highest-resolution candidate. Instagram's CDN URLs encode
    their size as e.g. '..._s1080x1080_...'; fall back to the last listed
    thumbnail if none of them match that pattern."""
    sized = []
    for thumb in thumbnails:
        url = thumb.get("url")
        if not url:
            continue
        match = _IMAGE_RESOLUTION_RE.search(url)
        area = int(match.group(1)) * int(match.group(2)) if match else -1
        sized.append((area, url))
    if not sized:
        return None
    return max(sized, key=lambda pair: pair[0])[1]


def _image_output_path(item: dict, out_dir: Path, filename: str | None, multi: bool) -> Path:
    item_id = item.get("id") or "image"
    if filename and not multi:
        name = filename.replace("%(id)s", str(item_id)).replace("%(ext)s", "jpg")
        return out_dir / name
    return out_dir / f"{item_id}.jpg"


def _download_image(url: str, dest: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response, open(dest, "wb") as f:
            shutil.copyfileobj(response, f)
    except Exception as exc:
        dest.unlink(missing_ok=True)
        raise IGDLError(f"Failed to download image: {exc}") from exc


def _needs_h264_transcode(info: dict) -> bool:
    """True if the video track yt-dlp picked isn't H.264 (i.e. won't play in
    QuickTime/Photos/AVFoundation on macOS)."""
    requested = info.get("requested_downloads") or [info]
    for entry in requested:
        vcodec = entry.get("vcodec")
        if vcodec and vcodec != "none" and not vcodec.startswith("avc1"):
            return True
    return False


def _transcode_to_h264(path: Path, verbose: bool = False) -> None:
    """Re-encode the video track to H.264 in place, keeping audio as AAC and
    adding +faststart so it plays directly (QuickTime, Photos, Finder Quick Look)."""
    fd, tmp_name = tempfile.mkstemp(suffix=".mp4", dir=str(path.parent))
    os.close(fd)
    tmp_path = Path(tmp_name)

    cmd = [
        "ffmpeg", "-y", "-i", str(path),
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
        "-c:a", "aac",
        "-movflags", "+faststart",
        str(tmp_path),
    ]
    try:
        subprocess.run(
            cmd,
            check=True,
            capture_output=not verbose,
            text=True,
        )
    except subprocess.CalledProcessError as exc:
        tmp_path.unlink(missing_ok=True)
        stderr = exc.stderr or ""
        raise IGDLError(f"Failed to transcode video for compatibility:\n{stderr}") from exc

    tmp_path.replace(path)


def _friendly_error(message: str) -> str:
    lowered = message.lower()
    if "login" in lowered or "rate-limit" in lowered or "private" in lowered:
        return (
            f"{message}\n\n"
            "This looks like a login-walled or private post. Retry with "
            "--cookies-from-browser chrome (or safari/firefox) to use your logged-in session."
        )
    return message
