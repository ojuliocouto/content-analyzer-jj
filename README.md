# Content Analyzer JJ

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill that downloads and deeply analyzes a single piece of social content (Instagram Reel, TikTok, YouTube Short or video, image carousel) starting from nothing but its URL.

It exists to solve two problems that break naive scraping:

1. **The networks block direct access.** Reels sit behind a login wall and the video is served as an opaque blob, so a plain `curl` gets you nothing.
2. **The caption is not the content.** On video posts the real substance (the hook, the argument, the call to action) lives in the spoken audio, not in the post caption. Reading the caption alone tells you almost nothing about why the content works.

This skill handles both: it authenticates with your logged-in browser cookies to pull the actual media, then transcribes the audio and reads the frames so the analysis is based on what was really said and shown.

---

## What it is, and what it is NOT

Read this before installing so your expectations are honest.

**It IS:**
- A download + transcription + visual-frame pipeline that feeds a structured content analysis (hook, content, structure/retention, CTA, strategic read).
- A tool for studying *one* piece of content at a time, in depth.
- Driven by `yt-dlp`, so it works with almost any platform `yt-dlp` supports (Instagram, TikTok, YouTube, and more), not just Instagram.
- Local-first: the default transcriber (`parakeet-mlx`) runs entirely on your machine, no audio leaves your computer.

**It is NOT:**
- A bulk scraper. It is built for deep analysis of individual posts, not for crawling thousands of URLs.
- A way to bypass authentication you do not have. It reuses *your own* logged-in session cookies. You can only download what your own account can already see.
- A guaranteed downloader. If a network changes its internals or `yt-dlp` is out of date, a download can fail. Keep `yt-dlp` updated.
- An analytics API. It does not pull historical reach, audience demographics, or paid-promotion data. It reads what is publicly attached to the post (likes, comments, caption) plus the media itself.

---

## Prerequisites (onboarding)

You need these in place **before** the skill can do anything. Each maps to a step in the pipeline, so if one is missing, that step fails.

| Tool | What it is used for | Required? |
|---|---|---|
| **Claude Code** | the host the skill runs inside | yes |
| **yt-dlp** | downloads the video/media from the platform | yes |
| **ffmpeg / ffprobe** | builds the frame grids and reads the duration | yes |
| **gallery-dl** | downloads image carousels (posts with no video) | yes (for carousels) |
| **jq** | reads the JSON metadata | yes |
| **A logged-in browser** (Edge or Chrome) | its cookies get past the Instagram login wall | yes |
| **parakeet-mlx** | transcribes the audio (fast, local, **Apple Silicon only**) | one transcriber required\* |
| **whisper** (openai-whisper) | transcribes the audio (any machine, fallback) | one transcriber required\* |

\* You need **at least one** transcriber. On an Apple Silicon Mac, use `parakeet-mlx` (much faster). On any other machine, use `whisper`.

### Why a logged-in browser is required

Instagram serves Reels behind a login wall. This skill does not store or ask for your password. Instead it reads the **session cookies** from a browser you have already logged into (Edge by default), exactly the way you would watch the Reel yourself. Log into Instagram once in that browser and you are done. You can only download content your own account is allowed to view.

---

## Installation

### 1. Install the system dependencies

**macOS (Homebrew):**
```bash
brew install yt-dlp ffmpeg gallery-dl jq
```

**Linux (Debian/Ubuntu, adjust for your distro):**
```bash
sudo apt install ffmpeg jq
pip install --user yt-dlp gallery-dl
```

**Pick one transcriber:**
```bash
# Apple Silicon (recommended, fast):
pip install --user parakeet-mlx

# Any machine (fallback):
pip install --user openai-whisper
```

Keep `yt-dlp` current, since platforms change their internals often:
```bash
yt-dlp -U   # or: pip install --user -U yt-dlp
```

### 2. Log into Instagram in your browser

The skill reads cookies from **Edge** by default (override with `IG_COOKIES_BROWSER=chrome`). Open Edge (or Chrome), log into Instagram once, and the cookies are saved for reuse.

### 3. Install the skill into Claude Code

```bash
git clone https://github.com/ojuliocouto/content-analyzer-jj.git
mkdir -p ~/.claude/skills/content-analyzer-jj
cp content-analyzer-jj/SKILL.md ~/.claude/skills/content-analyzer-jj/
cp -r content-analyzer-jj/scripts ~/.claude/skills/content-analyzer-jj/
chmod +x ~/.claude/skills/content-analyzer-jj/scripts/*.sh
```

On your next Claude Code session the skill is recognized automatically.

---

## How it works (step by step)

When you paste a link, the pipeline runs end to end:

1. **Download.** `ingest.sh` calls `yt-dlp` with your browser cookies to fetch the real media file, even behind the login wall. For image carousels (no video), it falls back to `gallery-dl`.
2. **Frame grids.** `ffmpeg` samples one frame every 3 seconds and tiles them into 5x4 mosaic images (`grid_*.png`, roughly 60s of video per grid). This lets the model "see" the visual: format, on-screen captions, screen inserts, cuts, and the all-important first frame (the visual hook).
3. **Transcription.** The audio is transcribed locally with `parakeet-mlx` by default. If that returns empty (for example a music-only Reel with no speech), it automatically falls back to `whisper`.
4. **Analysis.** The model cross-references transcript + frames + public engagement and returns a structured read:
   - **Snapshot:** account, duration, format, engagement, date.
   - **Hook (0-3s):** what stops the scroll (the opening line plus frame 1), and the pattern being used.
   - **Content:** a faithful summary of what is actually taught or said, taken from the transcript, never invented.
   - **Structure and retention:** how it is sequenced, where inserts or B-roll hold attention, the pacing.
   - **CTA / objective:** what it asks for at the end, and the goal behind it (authority, lead, sale).
   - **Strategic read:** relevance to your own business or niche, what is worth learning or doing better, and whether it is worth producing something on the topic.
5. **Save to Notion (optional).** If you use Notion, the analysis can be catalogued in a database of your own (see below).

### Run the ingestion manually (without Claude)

```bash
~/.claude/skills/content-analyzer-jj/scripts/ingest.sh "https://www.instagram.com/reel/XXXXXXXX/" /tmp/ig_reel
```

Output lands in `/tmp/ig_reel/`: `reel.mp4`, `grid_*.png`, and `reel.txt` (the transcript, also printed at the end).

### Useful flags

| Flag | Effect |
|---|---|
| `TRANSCRIBER=whisper ingest.sh ...` | force Whisper from the start (use this if you are not on Apple Silicon) |
| `IG_COOKIES_BROWSER=chrome ingest.sh ...` | read cookies from Chrome instead of Edge |

---

## Notion integration (optional)

If you want to catalogue every analysis in a Notion database:

1. Create a Notion integration and copy its token (`secret_...` or `ntn_...`).
2. Export it: `export NOTION_API_TOKEN="<your-token>"`.
3. Create a database and share it with your integration.
4. Build a payload JSON whose `parent.data_source_id` points at **your** database (the suggested schema is documented inside `scripts/notion-save.sh`).
5. Run `scripts/notion-save.sh /tmp/notion_reel_payload.json`. It prints the URL of the created page.

If you do not use Notion, skip this entirely. The analysis works fully without it.

---

## Security

- **No credentials in the code.** The Notion token is read from the `NOTION_API_TOKEN` environment variable, never hard-coded or committed.
- **No password handling.** Instagram access uses your existing browser session cookies. The skill never sees, stores, or transmits your password.
- **Local transcription by default.** With `parakeet-mlx`, audio is transcribed on your machine. Nothing is uploaded.
- **Use only on content you are allowed to access**, and respect each platform's Terms of Service and the rights of the content creators. This tool is for studying and learning from content, not for republishing it.
- The downloaded files live in `/tmp/`. Clean them up when you are done.

---

## Project layout

```
content-analyzer-jj/
├── SKILL.md              # the skill definition Claude Code loads
├── scripts/
│   ├── ingest.sh         # download + frame grids + transcription
│   └── notion-save.sh    # optional: POST an analysis to your Notion database
├── README.md
└── LICENSE
```

---

## License

Released under the MIT License. See [LICENSE](LICENSE).
