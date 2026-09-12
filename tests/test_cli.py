"""Argument-parsing tests. No network calls."""

from pathlib import Path

import pytest

from igdl.cli import build_parser, main
from igdl.core import IGDLError


def test_parser_requires_url():
    parser = build_parser()
    with pytest.raises(SystemExit):
        parser.parse_args([])


def test_parser_defaults():
    parser = build_parser()
    args = parser.parse_args(["https://www.instagram.com/reel/abc123/"])
    assert args.url == "https://www.instagram.com/reel/abc123/"
    assert args.out == "~/Downloads"
    assert args.filename is None
    assert args.cookies_from_browser is None
    assert args.verbose is False


def test_parser_all_options():
    parser = build_parser()
    args = parser.parse_args([
        "https://www.instagram.com/reel/abc123/",
        "-o", "/tmp/out",
        "--filename", "myreel.mp4",
        "--cookies-from-browser", "chrome",
        "-v",
    ])
    assert args.out == "/tmp/out"
    assert args.filename == "myreel.mp4"
    assert args.cookies_from_browser == "chrome"
    assert args.verbose is True


def test_main_rejects_non_instagram_url(capsys):
    exit_code = main(["https://example.com/not-instagram"])
    assert exit_code == 1
    captured = capsys.readouterr()
    assert "error:" in captured.err


def test_main_reports_download_error(monkeypatch, capsys):
    def fake_download(*args, **kwargs):
        raise IGDLError("boom")

    monkeypatch.setattr("igdl.cli.download", fake_download)
    exit_code = main(["https://www.instagram.com/reel/abc123/"])
    assert exit_code == 1
    assert "boom" in capsys.readouterr().err


def test_main_success_prints_path(monkeypatch, capsys, tmp_path):
    from igdl.core import DownloadResult

    fake_file = tmp_path / "abc123.mp4"
    fake_file.write_bytes(b"0" * 2048)

    def fake_download(*args, **kwargs):
        return [DownloadResult(path=fake_file, size_bytes=fake_file.stat().st_size)]

    monkeypatch.setattr("igdl.cli.download", fake_download)
    exit_code = main(["https://www.instagram.com/reel/abc123/"])
    assert exit_code == 0
    out = capsys.readouterr().out
    assert str(fake_file) in out
    assert "done:" not in out  # only printed for multi-file (carousel) results


def test_main_success_prints_all_carousel_files(monkeypatch, capsys, tmp_path):
    from igdl.core import DownloadResult

    files = []
    for name, size in [("vid1.mp4", 4096), ("img1.jpg", 1024)]:
        f = tmp_path / name
        f.write_bytes(b"0" * size)
        files.append(DownloadResult(path=f, size_bytes=size))

    monkeypatch.setattr("igdl.cli.download", lambda *a, **k: files)
    exit_code = main(["https://www.instagram.com/p/carousel123/"])
    assert exit_code == 0
    out = capsys.readouterr().out
    assert "vid1.mp4" in out
    assert "img1.jpg" in out
    assert "done: 2 files" in out
