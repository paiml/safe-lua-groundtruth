#!/usr/bin/env lua5.1
--[[
  media_pipeline.lua — Example: media tooling pipeline.
  Builds safe FFmpeg/ImageMagick commands via shell.build_command
  and shell.escape. Demonstrates video transcode, thumbnail extraction,
  and image resize pipelines with proper argument escaping and validation.

  Dry-run mode by default (prints commands, doesn't execute).

  Usage: lua5.1 examples/media_pipeline.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local shell = require("safe.shell")
local log = require("safe.log")

local string_format = string.format
local string_rep = string.rep
local table_concat = table.concat
local tostring = tostring

log.set_level(log.INFO)
log.set_context("media")

--- Validate a file path for media operations.
--- @param path string file path
--- @param name string parameter name
--- @return boolean ok, string|nil error
local function validate_path(path, name)
    local c = validate.Checker:new()
    c:check_string_not_empty(path, name)
    if not c:ok() then
        return false, table_concat(c:errors(), "; ")
    end
    return true, nil
end

--- Validate video resolution string (e.g. "1920x1080").
--- @param res string resolution string
--- @return boolean ok, string|nil error
local function validate_resolution(res)
    local ok, err = validate.check_string_not_empty(res, "resolution")
    if not ok then
        return false, err
    end
    if not res:match("^%d+x%d+$") then
        return false, string_format("invalid resolution format: %s (expected NxN)", res)
    end
    return true, nil
end

--- Validate a codec name.
--- @param codec string
--- @return boolean ok, string|nil error
local function validate_codec(codec)
    local allowed = { "libx264", "libx265", "libvpx", "aac", "opus", "copy" }
    return validate.check_one_of(codec, allowed, "codec")
end

--- Build an FFmpeg transcode command.
--- @param input string input file path
--- @param output string output file path
--- @param opts table options: codec, resolution, bitrate
--- @return string command
local function build_transcode(input, output, opts)
    local ok_in, err_in = validate_path(input, "input")
    guard.contract(ok_in, tostring(err_in))
    local ok_out, err_out = validate_path(output, "output")
    guard.contract(ok_out, tostring(err_out))

    local codec = opts.codec or "libx264"
    local ok_codec, err_codec = validate_codec(codec)
    guard.contract(ok_codec, tostring(err_codec))

    local args = { "-i", input, "-c:v", codec }

    if opts.resolution then
        local ok_res, err_res = validate_resolution(opts.resolution)
        guard.contract(ok_res, tostring(err_res))
        args[#args + 1] = "-s"
        args[#args + 1] = opts.resolution
    end

    if opts.bitrate then
        local ok_br, err_br = validate.check_string_not_empty(opts.bitrate, "bitrate")
        guard.contract(ok_br, tostring(err_br))
        args[#args + 1] = "-b:v"
        args[#args + 1] = opts.bitrate
    end

    args[#args + 1] = "-y"
    args[#args + 1] = output

    return shell.build_command("ffmpeg", args)
end

--- Build an FFmpeg thumbnail extraction command.
--- @param input string input video path
--- @param output string output image path
--- @param timestamp string seek position (e.g. "00:01:30")
--- @return string command
local function build_thumbnail(input, output, timestamp)
    local ok_in, err_in = validate_path(input, "input")
    guard.contract(ok_in, tostring(err_in))
    local ok_out, err_out = validate_path(output, "output")
    guard.contract(ok_out, tostring(err_out))

    local ok_ts, err_ts = validate.check_string_not_empty(timestamp, "timestamp")
    guard.contract(ok_ts, tostring(err_ts))

    local args = {
        "-i",
        input,
        "-ss",
        timestamp,
        "-vframes",
        "1",
        "-y",
        output,
    }
    return shell.build_command("ffmpeg", args)
end

--- Build an ImageMagick resize command.
--- @param input string input image path
--- @param output string output image path
--- @param geometry string resize geometry (e.g. "800x600")
--- @return string command
local function build_resize(input, output, geometry)
    local ok_in, err_in = validate_path(input, "input")
    guard.contract(ok_in, tostring(err_in))
    local ok_out, err_out = validate_path(output, "output")
    guard.contract(ok_out, tostring(err_out))

    local ok_geom, err_geom = validate.check_string_not_empty(geometry, "geometry")
    guard.contract(ok_geom, tostring(err_geom))

    local args = { input, "-resize", geometry, output }
    return shell.build_command("convert", args)
end

local function main(_args)
    io.write("Media Tooling Pipeline (Dry Run)\n")
    io.write(string_rep("=", 50) .. "\n\n")

    -- Demonstrate with paths that could contain tricky characters
    local test_files = {
        video = "input/my video (2024).mp4",
        thumbnail = "output/thumb's preview.jpg",
        resized = "output/resized image.png",
        transcoded = "output/final [web].mp4",
    }

    -- 1. Video transcode
    io.write("1. Video Transcode (H.264, 720p)\n")
    io.write(string_rep("-", 50) .. "\n")
    local transcode_cmd = build_transcode(test_files.video, test_files.transcoded, {
        codec = "libx264",
        resolution = "1280x720",
        bitrate = "2500k",
    })
    io.write("   " .. transcode_cmd .. "\n\n")
    log.info("built transcode command")

    -- 2. Thumbnail extraction
    io.write("2. Thumbnail Extraction (at 1:30)\n")
    io.write(string_rep("-", 50) .. "\n")
    local thumb_cmd = build_thumbnail(test_files.video, test_files.thumbnail, "00:01:30")
    io.write("   " .. thumb_cmd .. "\n\n")
    log.info("built thumbnail command")

    -- 3. Image resize
    io.write("3. Image Resize (800x600)\n")
    io.write(string_rep("-", 50) .. "\n")
    local resize_cmd = build_resize(test_files.thumbnail, test_files.resized, "800x600")
    io.write("   " .. resize_cmd .. "\n\n")
    log.info("built resize command")

    -- 4. Show escaping in action with adversarial input
    io.write("4. Escaping Demo (adversarial filenames)\n")
    io.write(string_rep("-", 50) .. "\n")
    local adversarial = {
        "file; rm -rf /",
        "$(whoami).mp4",
        "file`id`.mp4",
        "normal_file.mp4",
    }
    for i = 1, #adversarial do
        local escaped = shell.escape(adversarial[i])
        io.write(string_format("   %-25s -> %s\n", adversarial[i], escaped))
    end

    io.write("\n")
    io.write("All commands shown above are safe to execute.\n")
    io.write("Arguments are properly escaped via shell.escape.\n")
    log.info("media pipeline demo complete")
    return 0
end

os.exit(main(arg))
