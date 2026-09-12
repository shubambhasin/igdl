"""Core download logic: yt-dlp + ffmpeg, no CLI concerns here."""

from __future__ import annotations

import shutil
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
) -> DownloadResult:
    """Download a single Instagram reel/post URL, merged to one mp4, into out_dir."""
    validate_url(url)
    check_ffmpeg()

    out_dir = Path(out_dir).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    outtmpl = str(out_dir / (filename or "%(id)s.%(ext)s"))

    ydl_opts: dict = {
        "format": "bv*+ba/b",
        "merge_output_format": "mp4",
        "outtmpl": outtmpl,
        "quiet": not verbose,
        "no_warnings": not verbose,
        "noprogress": not verbose,
        "restrictfilenames": False,
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
            info = ydl.extract_info(url, download=True)
    except yt_dlp.utils.DownloadError as exc:
        raise IGDLError(_friendly_error(str(exc))) from exc

    final_path = _resolve_output_path(info, ydl_opts, out_dir)
    if not final_path or not final_path.exists():
        raise IGDLError("Download finished but the output file could not be located.")

    return DownloadResult(path=final_path, size_bytes=final_path.stat().st_size)


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


def _friendly_error(message: str) -> str:
    lowered = message.lower()
    if "login" in lowered or "rate-limit" in lowered or "private" in lowered:
        return (
            f"{message}\n\n"
            "This looks like a login-walled or private post. Retry with "
            "--cookies-from-browser chrome (or safari/firefox) to use your logged-in session."
        )
    return message
