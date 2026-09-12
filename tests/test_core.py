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


class FakeYDL:
    """Minimal stand-in for yt_dlp.YoutubeDL covering the calls download() makes:
    extract_info(download=False), process_video_result(download=True), and
    prepare_filename(). "Downloading" a video just writes a fake file."""

    def __init__(self, opts):
        self.opts = opts

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def extract_info(self, url, download=False):
        return self.info

    def process_video_result(self, item, download=True):
        path = Path(self._prepare(item))
        path.write_bytes(b"0" * item.get("_fake_size", 4096))

    def prepare_filename(self, info):
        return self._prepare(info)

    def _prepare(self, info):
        return self.opts["outtmpl"].replace("%(id)s", str(info["id"])).replace("%(ext)s", info.get("ext", "mp4"))


def test_download_single_video_mocked(monkeypatch, tmp_path):
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/ffmpeg")

    FakeYDL.info = {
        "id": "abc123", "ext": "mp4", "vcodec": "avc1.42001f",
        "formats": [{"format_id": "0"}], "_fake_size": 4096,
    }
    monkeypatch.setattr("igdl.core.yt_dlp.YoutubeDL", FakeYDL)

    results = download("https://www.instagram.com/reel/abc123/", tmp_path)
    assert len(results) == 1
    assert results[0].path == tmp_path / "abc123.mp4"
    assert results[0].size_bytes == 4096


def test_download_single_image_mocked(monkeypatch, tmp_path):
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/ffmpeg")

    FakeYDL.info = {
        "id": "img123",
        "formats": [],
        "thumbnails": [{"url": "https://cdn.example.com/x_s150x150_y.jpg"},
                        {"url": "https://cdn.example.com/x_s1080x1080_y.jpg"}],
    }
    monkeypatch.setattr("igdl.core.yt_dlp.YoutubeDL", FakeYDL)

    downloaded = {}

    def fake_download_image(url, dest):
        downloaded["url"] = url
        dest.write_bytes(b"1" * 2048)

    monkeypatch.setattr("igdl.core._download_image", fake_download_image)

    results = download("https://www.instagram.com/p/img123/", tmp_path)
    assert len(results) == 1
    assert results[0].path == tmp_path / "img123.jpg"
    assert results[0].size_bytes == 2048
    assert "s1080x1080" in downloaded["url"]  # picked the highest-resolution candidate


def test_download_mixed_carousel_mocked(monkeypatch, tmp_path):
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/ffmpeg")

    FakeYDL.info = {
        "_type": "playlist",
        "entries": [
            {"id": "vid1", "ext": "mp4", "vcodec": "avc1.42001f", "formats": [{"format_id": "0"}], "_fake_size": 1000},
            {"id": "img1", "formats": [], "thumbnails": [{"url": "https://cdn.example.com/a_s720x720_b.jpg"}]},
        ],
    }
    monkeypatch.setattr("igdl.core.yt_dlp.YoutubeDL", FakeYDL)
    monkeypatch.setattr("igdl.core._download_image", lambda url, dest: dest.write_bytes(b"2" * 512))

    results = download("https://www.instagram.com/p/carousel123/", tmp_path)
    paths = sorted(r.path.name for r in results)
    assert paths == ["img1.jpg", "vid1.mp4"]


def test_best_image_url_picks_largest():
    from igdl.core import _best_image_url

    thumbs = [
        {"url": "https://x/y_s320x320_z.jpg"},
        {"url": "https://x/y_s1080x1080_z.jpg"},
        {"url": "https://x/y_s150x150_z.jpg"},
    ]
    assert "1080" in _best_image_url(thumbs)


def test_best_image_url_empty_list_returns_none():
    from igdl.core import _best_image_url

    assert _best_image_url([]) is None
