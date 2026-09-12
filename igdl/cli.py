"""igdl command-line entrypoint."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .core import IGDLError, download


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="igdl",
        description="Download an Instagram Reel or post as a single merged mp4.",
    )
    parser.add_argument("url", help="Instagram reel/post URL")
    parser.add_argument(
        "-o", "--out",
        default="~/Downloads",
        help="Output directory (default: ~/Downloads)",
    )
    parser.add_argument(
        "--filename",
        default=None,
        help="Custom output filename template (default: %%(id)s.%%(ext)s)",
    )
    parser.add_argument(
        "--cookies-from-browser",
        default=None,
        metavar="BROWSER",
        help="Use cookies from this browser for private/login-walled posts "
             "(chrome, safari, firefox, ...)",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Show full yt-dlp output",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        result = download(
            url=args.url,
            out_dir=Path(args.out).expanduser(),
            filename=args.filename,
            cookies_from_browser=args.cookies_from_browser,
            verbose=args.verbose,
        )
    except IGDLError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("interrupted", file=sys.stderr)
        return 130

    size_mb = result.size_bytes / (1024 * 1024)
    print(f"saved: {result.path} ({size_mb:.1f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
