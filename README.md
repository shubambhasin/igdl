# igdl

Download Instagram Reels/posts to a single merged `.mp4`, driven by `yt-dlp` + `ffmpeg`.

## One-time setup

```bash
brew install ffmpeg   # if you don't already have it
cd igdl
make setup
```

This creates a project-local venv at `.venv` and installs `igdl` into it as a console script.

Optionally add it to your PATH so you can just run `igdl` from anywhere:

```bash
echo 'export PATH="$HOME/Desktop/igdl/.venv/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Usage

Public reel, saved to `~/Downloads`:

```bash
igdl "https://www.instagram.com/reel/DdJ7Rj1TG9X/"
```

Custom output dir and filename:

```bash
igdl "https://www.instagram.com/reel/DdJ7Rj1TG9X/" -o ~/Movies --filename my_reel.mp4
```

Private / login-walled post, using your logged-in browser session's cookies:

```bash
igdl "https://www.instagram.com/reel/xyz/" --cookies-from-browser chrome
```

Verbose (full yt-dlp output):

```bash
igdl "https://www.instagram.com/reel/xyz/" -v
```

Without the venv on PATH, run it via make:

```bash
make run URL="https://www.instagram.com/reel/DdJ7Rj1TG9X/"
```

## Options

| Flag | Description |
|---|---|
| `url` (positional) | Instagram reel/post URL |
| `-o`, `--out` | Output directory (default `~/Downloads`) |
| `--filename` | Custom output filename (default `%(id)s.%(ext)s`) |
| `--cookies-from-browser` | `chrome`, `safari`, `firefox`, etc. — for private posts |
| `-v`, `--verbose` | Show full yt-dlp output |

## Troubleshooting

**"ffmpeg not found on PATH"** — install it: `brew install ffmpeg`.

**Login wall / private post / rate limit** — retry with `--cookies-from-browser chrome`
(or `safari`/`firefox`) so yt-dlp reuses your logged-in session's cookies. Make sure you're
actually logged into Instagram in that browser first.

**Rate limited by Instagram** — wait a few minutes between requests; avoid hammering the
same account/post repeatedly.

**Nothing downloads / "Not an Instagram URL"** — check the URL is a real
`instagram.com/reel/...` or `instagram.com/p/...` link, not a shortened/redirect link.

## Tests

```bash
make test
```

Tests mock out `yt-dlp`/`ffmpeg` — no live network calls or real Instagram requests are made.

## Notes

- Only downloads the URL you give it. No uploading, no telemetry, no writes outside the
  chosen output directory.
- Don't commit browser cookies or any exported cookie files.

## Menubar app (topbar icon)

`MenubarApp/` is a native SwiftUI status-bar app that wraps the same `igdl` CLI —
it shells out to whatever `igdl` it finds (project venv, PATH, or a path you set
in Settings) rather than reimplementing the download logic.

Build & run:

```bash
cd MenubarApp
./build_app.sh      # builds IGDL.app one level up, at igdl/IGDL.app
open ../IGDL.app
```

Usage: click the download-arrow icon in the menubar, paste a reel/post URL (or hit
"Paste from Clipboard" if you already copied one), and click Download. Recent
downloads show up in the dropdown — click a filename to reveal it in Finder.
Settings (gear-less "Settings…" button) lets you change the output directory or
override the detected `igdl` executable path.

To launch it automatically at login: System Settings → General → Login Items →
add `igdl/IGDL.app`.

Requires macOS 26 (Tahoe) or later (the UI uses Liquid Glass-era gradient APIs) and Swift's
command-line tools (`swift build`); no full Xcode install needed.

### Gatekeeper

`build_app.sh` ad-hoc code-signs `IGDL.app` (`codesign --sign -`) after building, which is
enough for a locally built app to launch without the "damaged" / "unidentified developer"
errors that unsigned arm64 binaries can hit. This does **not** produce a Developer ID
signature or notarization (both require a paid Apple Developer account), so a `.app` you
zip/AirDrop/download from elsewhere will still get a Gatekeeper warning the first time you
open it — right-click → Open bypasses that.

### Distributing it (DMG)

```bash
cd MenubarApp
./build_dmg.sh 1.0.0   # builds IGDL.app, then packages dist/IGDL-1.0.0.dmg
```

The DMG mounts with `IGDL.app` next to an `Applications` symlink for a normal
drag-to-install. This project's DMGs are attached to
[GitHub Releases](https://github.com/shubambhasin/igdl/releases).

## Landing page

`site/` is a static one-page site (plain HTML/CSS, no build step) that links to the latest
release DMG. `vercel.json` at the repo root points Vercel at `site/` as the output directory.

To deploy: connect this repo at [vercel.com/new](https://vercel.com/new) — Vercel will pick
up `vercel.json` automatically, no other configuration needed. To preview locally:

```bash
python3 -m http.server 8080 --directory site
```

