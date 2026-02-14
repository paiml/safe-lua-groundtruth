# MLT Pipeline

Demonstrates timeline composition using the MLT multimedia framework's Lua SWIG API.
Falls back to a mock API when the real `mlt` module is unavailable, so the code
structure is identical to what runs with the real C library.

## Key Patterns

- **Factory + Profile init**: `mlt.Factory_init()`, `mlt.Profile("dv_pal")` for format configuration
- **Producer creation**: `mlt.Producer(profile, "file.mp4")` with `is_valid()` checks
- **Playlist composition**: `playlist:append(producer, in_pt, out_pt)` for trimmed clip sequencing
- **Tractor + Multitrack**: parallel tracks with `tractor:set_track(producer, track_n)`
- **Transitions**: `mlt.Transition(profile, "luma")` planted between tracks via `field:plant_transition`
- **Filter chain**: `mlt.Filter(profile, "greyscale")` attached via `producer:attach(filter)`
- **Consumer rendering**: `mlt.Consumer(profile, "avformat")` for file output with codec properties
- **Graceful degradation**: `pcall(require, "mlt")` with mock fallback

## Pipeline Steps

| Demo | Operation |
|------|-----------|
| Simple Playback | Load file, connect to SDL2 consumer |
| Playlist Cuts | 3 clips trimmed and sequenced |
| Dissolve Transition | Luma dissolve via tractor/transition |
| Filter Chain | Greyscale + volume adjustment |
| Render to File | Encode output via avformat consumer |

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-600 | `guard.check` validates all producers and inputs |
| CB-601 | `guard.contract` on profile and service validity |
| CB-607 | Colon-syntax methods on mock service objects |

## Source

```lua
{{#include ../../../examples/mlt_pipeline.lua}}
```

## Sample Output

```
MLT Multimedia Pipeline
============================================================
(mock mode — mlt SWIG bindings not installed)

Profile: 720x576 @ 25 fps

1. Simple Playback
------------------------------------------------------------
Load a file and connect to a consumer for playback.

  Producer: intro.mp4 (length=250 frames)
  Consumer started (sdl2 window)
  Playback complete.

2. Playlist with Trimmed Clips
------------------------------------------------------------
Sequence 3 clips with in/out trim points.

  [1] scene_01.mp4  in=0 out=74 (75 frames)
  [2] scene_02.mp4  in=25 out=149 (125 frames)
  [3] scene_03.mp4  in=50 out=199 (150 frames)

  Playlist: 3 clips, 750 total frames
  Playback complete.

3. Dissolve Transition (Tractor)
------------------------------------------------------------
Two clips composited with a luma dissolve.

  Track 0: sunset.mp4
  Track 1: sunrise.mp4
  Transition: luma dissolve (50 frames, softness=0.1)
  Playback complete.

4. Filter Chain
------------------------------------------------------------
Apply greyscale + volume adjustment to a clip.

  Filters attached to interview.mp4:
    - greyscale
    - volume (gain=0.8)
  Playback complete.

5. Render to File (avformat consumer)
------------------------------------------------------------
Encode a playlist to an output file via avformat consumer.

  Playlist: 2 clips
  target          = output/final_edit.mp4
  vcodec          = libx264
  acodec          = aac
  width           = 1920
  height          = 1080

  Encoding started...
  Encoding complete: output/final_edit.mp4

============================================================
All MLT pipeline demos complete.
```
