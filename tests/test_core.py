"""Core logic tests. yt-dlp/ffmpeg are mocked out — no live Instagram calls."""

from pathlib import Path

import pytest

from igdl.core import IGDLError, check_ffmpeg, download, validate_url


def test_validate_url_rejects_non_instagram():
    with pytest.raises(IGDLError):
        validate_url("https://example.com/video")


def test_validate_url_accepts_instagram():
    validate_url("https://www.instagram.com/reel/DdJ7Rj1TG9X/")


def test_check_ffmpeg_missing(monkeypatch):
    monkeypatch.setattr("shutil.which", lambda name: None)
    with pytest.raises(IGDLError, match="brew install ffmpeg"):
        check_ffmpeg()


def test_check_ffmpeg_found(monkeypatch):
    monkeypatch.setattr("shutil.which", lambda name: "/opt/homebrew/bin/ffmpeg")
    assert check_ffmpeg() == "/opt/homebrew/bin/ffmpeg"


def test_download_missing_ffmpeg_raises_before_network(monkeypatch, tmp_path):
    monkeypatch.setattr("shutil.which", lambda name: None)
    with pytest.raises(IGDLError, match="brew install ffmpeg"):
        download("https://www.instagram.com/reel/abc/", tmp_path)


def test_download_rejects_bad_url(monkeypatch, tmp_path):
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/ffmpeg")
    with pytest.raises(IGDLError, match="Not an Instagram URL"):
        download("https://example.com/reel/abc/", tmp_path)


def test_download_rejects_bad_browser(monkeypatch, tmp_path):
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/ffmpeg")
    with pytest.raises(IGDLError, match="Unsupported --cookies-from-browser"):
        download(
            "https://www.instagram.com/reel/abc/",
            tmp_path,
            cookies_from_browser="netscape-navigator",
        )


def test_download_success_mocked(monkeypatch, tmp_path):
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/ffmpeg")

    fake_file = tmp_path / "abc123.mp4"
    fake_file.write_bytes(b"0" * 4096)

    class FakeYDL:
        def __init__(self, opts):
            self.opts = opts

        def __enter__(self):
            return self

        def __exit__(self, *exc):
            return False

        def extract_info(self, url, download=True):
            return {"id": "abc123", "ext": "mp4", "requested_downloads": [{"filepath": str(fake_file)}]}

        def prepare_filename(self, info):
            return str(fake_file)

    monkeypatch.setattr("igdl.core.yt_dlp.YoutubeDL", FakeYDL)

    result = download("https://www.instagram.com/reel/abc123/", tmp_path)
    assert result.path == fake_file
    assert result.size_bytes == 4096
