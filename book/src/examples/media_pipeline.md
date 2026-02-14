# Media Pipeline

Builds safe FFmpeg and ImageMagick commands via `shell.build_command` and `shell.escape`. Demonstrates video transcode, thumbnail extraction, and image resize pipelines with proper argument escaping and validation. Runs in dry-run mode by default (prints commands without executing).

## Key Patterns

- **Safe command building**: `shell.build_command` validates program names, `shell.escape_args` escapes all arguments
- **Input validation**: File paths, resolutions, codecs all validated before command construction
- **Injection prevention**: Adversarial filenames (`;`, `` ` ``, `$()`) are safely escaped
- **Dry-run mode**: Commands are displayed but not executed

## Pipeline Steps

| Step | Tool | Operation |
|------|------|-----------|
| Transcode | FFmpeg | H.264 encode at 720p, 2500k bitrate |
| Thumbnail | FFmpeg | Extract single frame at timestamp |
| Resize | ImageMagick | Resize image to target geometry |

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-601 | `guard.contract` validates all inputs before use |
| CB-603 | `shell.build_command` wraps dangerous commands safely |
| CB-607 | `validate.Checker` colon-syntax for path validation |

## Source

```lua
{{#include ../../../examples/media_pipeline.lua}}
```

## Sample Output

```
Media Tooling Pipeline (Dry Run)
==================================================

1. Video Transcode (H.264, 720p)
--------------------------------------------------
   ffmpeg '-i' 'input/my video (2024).mp4' '-c:v' 'libx264' '-s' '1280x720' '-b:v' '2500k' '-y' 'output/final [web].mp4'

2. Thumbnail Extraction (at 1:30)
--------------------------------------------------
   ffmpeg '-i' 'input/my video (2024).mp4' '-ss' '00:01:30' '-vframes' '1' '-y' 'output/thumb'"'"'s preview.jpg'

3. Image Resize (800x600)
--------------------------------------------------
   convert 'output/thumb'"'"'s preview.jpg' '-resize' '800x600' 'output/resized image.png'

4. Escaping Demo (adversarial filenames)
--------------------------------------------------
   file; rm -rf /          -> 'file; rm -rf /'
   $(whoami).mp4           -> '$(whoami).mp4'
   file`id`.mp4            -> 'file`id`.mp4'
   normal_file.mp4         -> 'normal_file.mp4'
```
