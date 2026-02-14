#!/usr/bin/env lua5.1
--[[
  ffmpeg_pipeline.lua — Example: FFmpeg video editing via safe.shell.
  Generates synthetic test media (color bars + sine tones), then demonstrates
  dissolve transitions, filter pipelines, thumbnail extraction, and concat
  via actual ffmpeg commands. All temp files live in /tmp/safe-lua-ffmpeg-demo/.

  Usage: lua5.1 examples/ffmpeg_pipeline.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local shell = require("safe.shell")
local log = require("safe.log")

local string_format = string.format
local string_rep = string.rep
local string_match = string.match
local table_concat = table.concat
local tostring = tostring

log.set_level(log.INFO)
log.set_context("ffmpeg")

local WORK_DIR = "/tmp/safe-lua-ffmpeg-demo"

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function banner(title)
    io.write("\n" .. title .. "\n")
    io.write(string_rep("-", 60) .. "\n")
end

--- Run a shell command, log it, and return success + output.
local function run(program, args)
    local cmd = shell.build_command(program, args)
    log.debug("exec: %s", cmd)
    local ok, output = shell.capture(program, args)
    if not ok then
        log.error("command failed: %s", cmd)
    end
    return ok, output
end

--- Run a shell command via exec (no capture).
local function run_exec(program, args)
    local cmd = shell.build_command(program, args)
    log.debug("exec: %s", cmd)
    local ok, code = shell.exec(program, args)
    if not ok then
        log.error("command failed (exit %s): %s", tostring(code), cmd)
    end
    return ok
end

--- Check that ffmpeg is available.
local function check_ffmpeg()
    local ok, output = shell.capture("ffmpeg", { "-version" })
    if not ok then
        return false, "ffmpeg not found in PATH"
    end
    local version = string_match(tostring(output), "ffmpeg version ([%d%.]+)")
    return true, version
end

--------------------------------------------------------------------------------
-- Demo 1: Generate synthetic test media
--------------------------------------------------------------------------------
local function demo_generate_test_media()
    banner("1. Generate Synthetic Test Media")
    io.write("Creating 3 test clips with color bars and sine tones.\n\n")

    local clips = {
        { name = "clip_a.mp4", color = "red", freq = "440", dur = "3" },
        { name = "clip_b.mp4", color = "blue", freq = "554", dur = "3" },
        { name = "clip_c.mp4", color = "green", freq = "659", dur = "3" },
    }

    local paths = {}
    for i = 1, #clips do
        local c = clips[i]
        local ok_name, err_name = validate.check_string_not_empty(c.name, "clip name")
        guard.contract(ok_name, tostring(err_name))

        local out = WORK_DIR .. "/" .. c.name
        local video_src = string_format("color=c=%s:size=320x240:rate=25:duration=%s", c.color, c.dur)
        local audio_src = string_format("sine=frequency=%s:duration=%s", c.freq, c.dur)

        local ok = run_exec("ffmpeg", {
            "-y",
            "-f",
            "lavfi",
            "-i",
            video_src,
            "-f",
            "lavfi",
            "-i",
            audio_src,
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-b:a",
            "128k",
            "-shortest",
            out,
        })
        guard.contract(ok, "failed to generate " .. c.name)
        paths[i] = out
        io.write(string_format("  [%d] %s (%s, %sHz, %ss)\n", i, c.name, c.color, c.freq, c.dur))
    end

    io.write("\n  All test clips generated.\n")
    return paths
end

--------------------------------------------------------------------------------
-- Demo 2: Probe media info
--------------------------------------------------------------------------------
local function demo_probe(clip_path)
    banner("2. Probe Media Info")
    io.write(string_format("Probing: %s\n\n", clip_path))

    local ok_path, err_path = validate.check_string_not_empty(clip_path, "clip_path")
    guard.contract(ok_path, tostring(err_path))

    local ok, output = run("ffprobe", {
        "-v",
        "quiet",
        "-show_format",
        "-show_streams",
        "-of",
        "flat",
        clip_path,
    })
    guard.contract(ok, "ffprobe failed")

    local info = tostring(output)
    -- Extract key fields from flat output
    local fields = {
        { pattern = 'format%.duration="([^"]+)"', label = "duration" },
        { pattern = 'streams%.stream%.0%.codec_name="([^"]+)"', label = "video codec" },
        { pattern = "streams%.stream%.0%.width=(%d+)", label = "width" },
        { pattern = "streams%.stream%.0%.height=(%d+)", label = "height" },
        { pattern = 'streams%.stream%.1%.codec_name="([^"]+)"', label = "audio codec" },
    }

    for i = 1, #fields do
        local val = string_match(info, fields[i].pattern)
        if val then
            io.write(string_format("  %-15s: %s\n", fields[i].label, val))
        end
    end
end

--------------------------------------------------------------------------------
-- Demo 3: Dissolve transition (xfade)
--------------------------------------------------------------------------------
local function demo_dissolve(clip_a, clip_b)
    banner("3. Dissolve Transition (xfade)")
    io.write("Crossfade between two clips using xfade filter.\n\n")

    local ok_a, err_a = validate.check_string_not_empty(clip_a, "clip_a")
    guard.contract(ok_a, tostring(err_a))
    local ok_b, err_b = validate.check_string_not_empty(clip_b, "clip_b")
    guard.contract(ok_b, tostring(err_b))

    local output = WORK_DIR .. "/dissolve.mp4"
    local xfade = "xfade=transition=fade:duration=1:offset=2"
    local acrossfade = "acrossfade=d=1:c1=tri:c2=tri"

    local ok = run_exec("ffmpeg", {
        "-y",
        "-i",
        clip_a,
        "-i",
        clip_b,
        "-filter_complex",
        xfade .. "[v];" .. acrossfade .. "[a]",
        "-map",
        "[v]",
        "-map",
        "[a]",
        "-c:v",
        "libx264",
        "-preset",
        "ultrafast",
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        output,
    })
    guard.contract(ok, "dissolve failed")
    io.write("  Transition: fade, duration=1s, offset=2s\n")
    io.write("  Audio: acrossfade (triangular curves)\n")
    io.write(string_format("  Output: %s\n", output))
end

--------------------------------------------------------------------------------
-- Demo 4: Multi-clip transitions
--------------------------------------------------------------------------------
local function demo_multi_transition(clips)
    banner("4. Multi-Clip Transition Chain")
    io.write("Chain 3 clips with different xfade transitions.\n\n")

    guard.contract(#clips >= 3, "need at least 3 clips")

    -- Two-pass: first xfade clips[1]+clips[2], then result+clips[3]
    local mid = WORK_DIR .. "/multi_mid.mp4"
    local final = WORK_DIR .. "/multi_final.mp4"

    local transitions = {
        { name = "dissolve", filter = "xfade=transition=dissolve:duration=1:offset=2" },
        { name = "wipeleft", filter = "xfade=transition=wipeleft:duration=1:offset=2" },
    }

    -- Pass 1
    local ok1 = run_exec("ffmpeg", {
        "-y",
        "-i",
        clips[1],
        "-i",
        clips[2],
        "-filter_complex",
        transitions[1].filter,
        "-c:v",
        "libx264",
        "-preset",
        "ultrafast",
        "-pix_fmt",
        "yuv420p",
        "-an",
        mid,
    })
    guard.contract(ok1, "multi-transition pass 1 failed")
    io.write(string_format("  Pass 1: %s (%s)\n", transitions[1].name, "clip_a + clip_b"))

    -- Pass 2
    local ok2 = run_exec("ffmpeg", {
        "-y",
        "-i",
        mid,
        "-i",
        clips[3],
        "-filter_complex",
        transitions[2].filter,
        "-c:v",
        "libx264",
        "-preset",
        "ultrafast",
        "-pix_fmt",
        "yuv420p",
        "-an",
        final,
    })
    guard.contract(ok2, "multi-transition pass 2 failed")
    io.write(string_format("  Pass 2: %s (%s)\n", transitions[2].name, "result + clip_c"))
    io.write(string_format("  Output: %s\n", final))
end

--------------------------------------------------------------------------------
-- Demo 5: Filter pipeline
--------------------------------------------------------------------------------
local function demo_filters(clip_path)
    banner("5. Filter Pipeline")
    io.write("Apply drawtext overlay, brightness adjustment, and speed change.\n\n")

    local ok_path, err_path = validate.check_string_not_empty(clip_path, "clip_path")
    guard.contract(ok_path, tostring(err_path))

    local output = WORK_DIR .. "/filtered.mp4"
    -- Chain: drawtext -> brightness -> 2x speed (setpts + atempo)
    local vfilter = table_concat({
        "drawtext=text='SAFE-LUA':fontsize=24:fontcolor=white:x=10:y=10",
        "eq=brightness=0.06",
        "setpts=0.5*PTS",
    }, ",")

    local ok = run_exec("ffmpeg", {
        "-y",
        "-i",
        clip_path,
        "-vf",
        vfilter,
        "-af",
        "atempo=2.0",
        "-c:v",
        "libx264",
        "-preset",
        "ultrafast",
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        output,
    })
    guard.contract(ok, "filter pipeline failed")
    io.write("  Video filters:\n")
    io.write("    - drawtext: 'SAFE-LUA' overlay at (10,10)\n")
    io.write("    - eq: brightness +0.06\n")
    io.write("    - setpts: 2x speed\n")
    io.write("  Audio filters:\n")
    io.write("    - atempo: 2x speed\n")
    io.write(string_format("  Output: %s\n", output))
end

--------------------------------------------------------------------------------
-- Demo 6: Thumbnail extraction
--------------------------------------------------------------------------------
local function demo_thumbnail(clip_path)
    banner("6. Thumbnail Extraction")
    io.write("Extract best representative frame from clip.\n\n")

    local ok_path, err_path = validate.check_string_not_empty(clip_path, "clip_path")
    guard.contract(ok_path, tostring(err_path))

    local output = WORK_DIR .. "/thumbnail.jpg"

    local ok = run_exec("ffmpeg", {
        "-y",
        "-i",
        clip_path,
        "-vf",
        "thumbnail=n=50",
        "-frames:v",
        "1",
        output,
    })
    guard.contract(ok, "thumbnail extraction failed")
    io.write("  Filter: thumbnail=n=50 (analyze 50 frames)\n")
    io.write(string_format("  Output: %s\n", output))
end

--------------------------------------------------------------------------------
-- Demo 7: Concat demuxer
--------------------------------------------------------------------------------
local function demo_concat(clips)
    banner("7. Concat Demuxer")
    io.write("Concatenate clips via ffmpeg concat demuxer.\n\n")

    guard.contract(#clips >= 2, "need at least 2 clips for concat")

    -- Write concat file list
    local list_path = WORK_DIR .. "/concat_list.txt"
    local list_file = io.open(list_path, "w")
    guard.contract(list_file ~= nil, "failed to open concat list for writing")
    for i = 1, #clips do
        list_file:write(string_format("file '%s'\n", clips[i]))
        io.write(string_format("  [%d] %s\n", i, clips[i]))
    end
    list_file:close()

    local output = WORK_DIR .. "/concatenated.mp4"
    local ok = run_exec("ffmpeg", {
        "-y",
        "-f",
        "concat",
        "-safe",
        "0",
        "-i",
        list_path,
        "-c",
        "copy",
        output,
    })
    guard.contract(ok, "concat failed")
    io.write(string_format("\n  Output: %s\n", output))
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------
local function cleanup()
    log.info("cleaning up %s", WORK_DIR)
    shell.exec("rm", { "-rf", WORK_DIR })
end

--------------------------------------------------------------------------------
-- Main
--------------------------------------------------------------------------------
local function main(_args)
    io.write("FFmpeg Pipeline via safe.shell\n")
    io.write(string_rep("=", 60) .. "\n")

    -- Check ffmpeg availability
    local ff_ok, ff_ver = check_ffmpeg()
    if not ff_ok then
        io.write("ERROR: " .. tostring(ff_ver) .. "\n")
        io.write("Install ffmpeg to run this example.\n")
        return 1
    end
    io.write(string_format("ffmpeg version: %s\n", tostring(ff_ver)))

    -- Create work directory
    shell.exec("mkdir", { "-p", WORK_DIR })

    -- Run demos
    local ok_run, err_msg = pcall(function()
        local clips = demo_generate_test_media()
        demo_probe(clips[1])
        demo_dissolve(clips[1], clips[2])
        demo_multi_transition(clips)
        demo_filters(clips[1])
        demo_thumbnail(clips[1])
        demo_concat(clips)
    end)

    -- Always clean up
    cleanup()

    if not ok_run then
        io.write("\nERROR: " .. tostring(err_msg) .. "\n")
        return 1
    end

    io.write("\n" .. string_rep("=", 60) .. "\n")
    io.write("All FFmpeg pipeline demos complete.\n")
    log.info("ffmpeg pipeline example finished")
    return 0
end

os.exit(main(arg))
