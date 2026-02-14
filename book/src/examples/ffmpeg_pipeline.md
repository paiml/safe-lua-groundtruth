# FFmpeg Pipeline

Builds and executes real FFmpeg commands via `safe.shell` for video editing operations.
Generates synthetic test media (color bars + sine tones), then demonstrates dissolve
transitions, filter pipelines, thumbnail extraction, and concat demuxer usage.

## Key Patterns

- **Safe command execution**: All ffmpeg calls go through `shell.exec` / `shell.capture` with escaped arguments
- **Synthetic test media**: `ffmpeg -f lavfi` generates color bars + sine tones — no real video files needed
- **Media probing**: `ffprobe -of flat` for machine-readable media metadata
- **xfade transitions**: Dissolve and wipe transitions between clips
- **Filter chaining**: `drawtext`, `eq` brightness, `setpts` speed in one `-vf` pipeline
- **Audio crossfade**: `acrossfade=d=1:c1=tri:c2=tri` for smooth audio transitions
- **Concat demuxer**: File-list based concatenation with `-f concat`
- **Cleanup on exit**: `pcall` wrapper ensures `/tmp` cleanup even on error

## Pipeline Steps

| Demo | FFmpeg Feature | Description |
|------|---------------|-------------|
| Generate Media | `-f lavfi` | Create 3 synthetic clips (color + sine) |
| Probe | `ffprobe -of flat` | Extract duration, codecs, resolution |
| Dissolve | `xfade=transition=fade` | Crossfade between 2 clips |
| Multi-Transition | `xfade` chaining | 3 clips with dissolve + wipeleft |
| Filters | `-vf` pipeline | drawtext, brightness, 2x speed |
| Thumbnail | `thumbnail=n=50` | Extract best representative frame |
| Concat | `-f concat` | Join clips via demuxer file list |

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-600 | `guard.check` / `guard.contract` validate all paths and results |
| CB-603 | `shell.exec` / `shell.capture` wrap all command execution safely |
| CB-601 | Input validation via `validate.check_string_not_empty` |

## Source

```lua
{{#include ../../../examples/ffmpeg_pipeline.lua}}
```

## Sample Output

```
FFmpeg Pipeline via safe.shell
============================================================
ffmpeg version: 4.4.2

1. Generate Synthetic Test Media
------------------------------------------------------------
Creating 3 test clips with color bars and sine tones.

  [1] clip_a.mp4 (red, 440Hz, 3s)
  [2] clip_b.mp4 (blue, 554Hz, 3s)
  [3] clip_c.mp4 (green, 659Hz, 3s)

  All test clips generated.

2. Probe Media Info
------------------------------------------------------------
Probing: /tmp/safe-lua-ffmpeg-demo/clip_a.mp4

  duration       : 3.048000
  video codec    : h264
  width          : 320
  height         : 240
  audio codec    : aac

3. Dissolve Transition (xfade)
------------------------------------------------------------
Crossfade between two clips using xfade filter.

  Transition: fade, duration=1s, offset=2s
  Audio: acrossfade (triangular curves)
  Output: /tmp/safe-lua-ffmpeg-demo/dissolve.mp4

4. Multi-Clip Transition Chain
------------------------------------------------------------
Chain 3 clips with different xfade transitions.

  Pass 1: dissolve (clip_a + clip_b)
  Pass 2: wipeleft (result + clip_c)
  Output: /tmp/safe-lua-ffmpeg-demo/multi_final.mp4

5. Filter Pipeline
------------------------------------------------------------
Apply drawtext overlay, brightness adjustment, and speed change.

  Video filters:
    - drawtext: 'SAFE-LUA' overlay at (10,10)
    - eq: brightness +0.06
    - setpts: 2x speed
  Audio filters:
    - atempo: 2x speed
  Output: /tmp/safe-lua-ffmpeg-demo/filtered.mp4

6. Thumbnail Extraction
------------------------------------------------------------
Extract best representative frame from clip.

  Filter: thumbnail=n=50 (analyze 50 frames)
  Output: /tmp/safe-lua-ffmpeg-demo/thumbnail.jpg

7. Concat Demuxer
------------------------------------------------------------
Concatenate clips via ffmpeg concat demuxer.

  [1] /tmp/safe-lua-ffmpeg-demo/clip_a.mp4
  [2] /tmp/safe-lua-ffmpeg-demo/clip_b.mp4
  [3] /tmp/safe-lua-ffmpeg-demo/clip_c.mp4

  Output: /tmp/safe-lua-ffmpeg-demo/concatenated.mp4

============================================================
All FFmpeg pipeline demos complete.
```
