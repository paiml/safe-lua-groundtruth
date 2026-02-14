#!/usr/bin/env lua5.1
--[[
  config_loader.lua — Example: config loading and schema validation.
  Demonstrates dofile-based config loading, schema validation with
  validate.schema(), defaults via `or`, and frozen config objects.

  Patterns from resolve-pipeline: dofile(), manual field checks,
  defaults via `or`, config table validation.

  Usage: lua5.1 examples/config_loader.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local string_format = string.format
local string_rep = string.rep
local tostring = tostring
local type = type

log.set_level(log.INFO)
log.set_context("config")

-- ----------------------------------------------------------------
-- Schema definition (mirrors resolve-pipeline config structure)
-- ----------------------------------------------------------------

local PROJECT_SCHEMA = {
    project_name = { type = "string", required = true },
    frame_rate = { type = "number", required = true },
    output_dir = { type = "string", required = false, default = "./output" },
    log_level = { type = "string", required = false, default = "INFO" },
}

local VIDEO_SCHEMA = {
    id = { type = "string", required = true },
    filename = { type = "string", required = true },
    title = { type = "string", required = false, default = "Untitled" },
    duration = { type = "number", required = false },
}

local BRANDING_SCHEMA = {
    title_font = { type = "string", required = false, default = "Source-Sans-3" },
}

-- ----------------------------------------------------------------
-- Config loading patterns
-- ----------------------------------------------------------------

--- Load a config table (simulates dofile-based loading).
--- In production: local config = dofile(path)
--- Here we use inline tables for demonstration.
--- @param raw_config table
--- @return boolean ok, table|string config_or_error
local function load_config(raw_config)
    if type(raw_config) ~= "table" then
        return false, "config must be a table, got " .. type(raw_config)
    end

    -- Validate top-level schema
    local ok, result = validate.schema(raw_config, PROJECT_SCHEMA)
    if not ok then
        return false, "project config: " .. result
    end

    -- Validate branding subsection with defaults
    if raw_config.branding then
        local brand_ok, brand_result = validate.schema(raw_config.branding, BRANDING_SCHEMA)
        if not brand_ok then
            return false, "branding config: " .. brand_result
        end
        result.branding = brand_result
    else
        -- Apply branding defaults when section is missing
        result.branding = { title_font = "Source-Sans-3" }
    end

    -- Validate each video entry
    if raw_config.videos then
        guard.assert_type(raw_config.videos, "table", "videos")
        result.videos = {}
        for i = 1, #raw_config.videos do
            local v_ok, v_result = validate.schema(raw_config.videos[i], VIDEO_SCHEMA)
            if not v_ok then
                return false, string_format("video[%d]: %s", i, v_result)
            end
            result.videos[i] = v_result
        end
    else
        result.videos = {}
    end

    return true, result
end

--- Apply defaults via `or` pattern (resolve-pipeline style).
--- @param config table validated config
--- @return table config with runtime defaults applied
local function apply_runtime_defaults(config)
    -- Pattern: (table and table.key) or default
    local transitions = config.transitions or {}
    local fade_seconds = transitions.fade_seconds or 0.5
    local fade_frames = fade_seconds * config.frame_rate

    config._runtime = {
        fade_frames = fade_frames,
        fade_seconds = fade_seconds,
    }

    return config
end

--- Print config summary.
local function print_config(config)
    io.write(string_format("  project_name: %s\n", config.project_name))
    io.write(string_format("  frame_rate:   %s\n", tostring(config.frame_rate)))
    io.write(string_format("  output_dir:   %s\n", config.output_dir))
    io.write(string_format("  log_level:    %s\n", config.log_level))
    io.write(string_format("  title_font:   %s\n", config.branding.title_font))
    io.write(string_format("  videos:       %d entries\n", #config.videos))
    for i = 1, #config.videos do
        local v = config.videos[i]
        io.write(string_format("    [%d] %s — %s\n", i, v.id, v.title))
    end
    if config._runtime then
        io.write(string_format("  fade_frames:  %.0f\n", config._runtime.fade_frames))
    end
end

local function main(_args)
    io.write("Config Loading & Schema Validation\n")
    io.write(string_rep("=", 50) .. "\n\n")

    -- 1. Valid config (mirrors resolve-pipeline structure)
    io.write("1. Valid Config (with defaults)\n")
    io.write(string_rep("-", 50) .. "\n")
    local valid_raw = {
        project_name = "AdvancedFineTuning_Rust_Coursera",
        frame_rate = 30,
        branding = {
            title_font = "Roboto",
        },
        videos = {
            { id = "1.1.1-core-concepts", filename = "core_concepts.mp4", title = "Core Concepts" },
            { id = "1.1.2-architecture", filename = "architecture.mp4" },
        },
    }

    local ok, config = load_config(valid_raw)
    guard.contract(ok, "valid config must load")
    config = apply_runtime_defaults(config)
    print_config(config)
    log.info("loaded config: %s", config.project_name)

    -- Freeze config to prevent accidental modification
    local frozen = guard.freeze(config)
    local mutate_ok = pcall(function() -- pmat:ignore CB-602
        frozen.project_name = "oops"
    end)
    io.write(string_format("  frozen:       %s\n", mutate_ok and "MUTABLE (bad)" or "immutable (good)"))

    -- 2. Config with missing required fields
    io.write("\n2. Missing Required Fields\n")
    io.write(string_rep("-", 50) .. "\n")
    local bad_raw = { frame_rate = 24 }
    local bad_ok, bad_err = load_config(bad_raw)
    io.write(string_format("  ok:    %s\n", tostring(bad_ok)))
    io.write(string_format("  error: %s\n", tostring(bad_err)))

    -- 3. Config with wrong types
    io.write("\n3. Wrong Field Types\n")
    io.write(string_rep("-", 50) .. "\n")
    local type_raw = { project_name = 42, frame_rate = "not a number" }
    local type_ok, type_err = load_config(type_raw)
    io.write(string_format("  ok:    %s\n", tostring(type_ok)))
    io.write(string_format("  error: %s\n", tostring(type_err)))

    -- 4. Config with bad video entry
    io.write("\n4. Invalid Video Entry\n")
    io.write(string_rep("-", 50) .. "\n")
    local vid_raw = {
        project_name = "Test",
        frame_rate = 30,
        videos = {
            { id = "good", filename = "good.mp4" },
            { filename = "missing_id.mp4" },
        },
    }
    local vid_ok, vid_err = load_config(vid_raw)
    io.write(string_format("  ok:    %s\n", tostring(vid_ok)))
    io.write(string_format("  error: %s\n", tostring(vid_err)))

    -- 5. Nil config
    io.write("\n5. Nil Config\n")
    io.write(string_rep("-", 50) .. "\n")
    local nil_ok, nil_err = load_config(nil)
    io.write(string_format("  ok:    %s\n", tostring(nil_ok)))
    io.write(string_format("  error: %s\n", tostring(nil_err)))

    io.write("\n")
    log.info("config loader demo complete")
    return 0
end

os.exit(main(arg))
