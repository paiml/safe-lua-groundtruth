#!/usr/bin/env lua5.1
--[[
  obs_script.lua — Example: OBS Studio script template.
  Reference template showing how to integrate safe-lua into an OBS
  Lua script. Wraps the OBS API with guard contracts, validates
  scene/source names, uses structured logging.

  Includes stub OBS API so the example runs standalone.

  Usage: lua5.1 examples/obs_script.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local string_format = string.format
local string_rep = string.rep
local tostring = tostring
local pcall = pcall

log.set_level(log.DEBUG)
log.set_context("obs")

-- ----------------------------------------------------------------
-- Stub OBS API (so this example runs without OBS)
-- ----------------------------------------------------------------
local stub_sources = {
    { name = "Webcam", kind = "v4l2_input", active = true },
    { name = "Desktop Audio", kind = "pulse_output_capture", active = true },
    { name = "Text Overlay", kind = "text_ft2_source_v2", active = false },
}

local stub_scenes = {
    { name = "Main Scene", sources = { "Webcam", "Desktop Audio" } },
    { name = "Intermission", sources = { "Text Overlay" } },
}

local function create_obs_stub()
    local function obs_get_source_by_name(name)
        guard.assert_type(name, "string", "source_name")
        for i = 1, #stub_sources do
            if stub_sources[i].name == name then
                return { _data = stub_sources[i] }
            end
        end
        return nil
    end

    local function obs_source_get_name(source)
        guard.assert_not_nil(source, "source")
        return source._data.name
    end

    local function obs_source_get_type(source)
        guard.assert_not_nil(source, "source")
        return source._data.kind
    end

    local function obs_source_active(source)
        guard.assert_not_nil(source, "source")
        return source._data.active
    end

    local function obs_source_release(_source) end

    local function obs_enum_scenes()
        local scenes = {}
        for i = 1, #stub_scenes do
            scenes[i] = { _scene = stub_scenes[i] }
        end
        return scenes
    end

    local function obs_scene_get_name(scene)
        guard.assert_not_nil(scene, "scene")
        return scene._scene.name
    end

    local function obs_scene_enum_items(scene)
        guard.assert_not_nil(scene, "scene")
        local sources = scene._scene.sources
        local items = {}
        for i = 1, #sources do
            items[i] = { _source_name = sources[i] }
        end
        return items
    end

    local function obs_sceneitem_get_source_name(item)
        guard.assert_not_nil(item, "scene_item")
        return item._source_name
    end

    return {
        obs_get_source_by_name = obs_get_source_by_name,
        obs_source_get_name = obs_source_get_name,
        obs_source_get_type = obs_source_get_type,
        obs_source_active = obs_source_active,
        obs_source_release = obs_source_release,
        obs_enum_scenes = obs_enum_scenes,
        obs_scene_get_name = obs_scene_get_name,
        obs_scene_enum_items = obs_scene_enum_items,
        obs_sceneitem_get_source_name = obs_sceneitem_get_source_name,
    }
end

-- ----------------------------------------------------------------
-- Safe OBS wrappers using safe-lua patterns
-- ----------------------------------------------------------------

--- Safely get a source by name with validation.
--- @param obs table OBS API table
--- @param name string source name
--- @return table|nil source, string|nil error
local function safe_get_source(obs, name)
    local ok, err = validate.check_string_not_empty(name, "source_name")
    if not ok then
        return nil, err
    end

    local source = obs.obs_get_source_by_name(name)
    if not source then
        return nil, string_format("source not found: %s", name)
    end

    return source, nil
end

--- Validate a scene name against known scenes.
--- @param obs table OBS API table
--- @param name string scene name
--- @return boolean ok, string|nil error
local function validate_scene_name(obs, name)
    local ok, err = validate.check_string_not_empty(name, "scene_name")
    if not ok then
        return false, err
    end

    local scenes = obs.obs_enum_scenes()
    for i = 1, #scenes do
        if obs.obs_scene_get_name(scenes[i]) == name then
            return true, nil
        end
    end
    return false, string_format("scene not found: %s", name)
end

--- List all sources in a scene with validation.
--- @param obs table OBS API table
--- @param scene_name string
--- @return boolean ok, table|string sources_or_error
local function list_scene_sources(obs, scene_name)
    local ok, err = validate_scene_name(obs, scene_name)
    if not ok then
        return false, err
    end

    local scenes = obs.obs_enum_scenes()
    for i = 1, #scenes do
        if obs.obs_scene_get_name(scenes[i]) == scene_name then
            local items = obs.obs_scene_enum_items(scenes[i])
            local names = {}
            for j = 1, #items do
                names[j] = obs.obs_sceneitem_get_source_name(items[j])
            end
            return true, names
        end
    end
    return false, "scene not found"
end

--- Audit all sources, reporting type and active status.
--- @param obs table OBS API table
--- @return table audit results
local function audit_sources(obs)
    local results = {}
    for i = 1, #stub_sources do
        local name = stub_sources[i].name
        local source, err = safe_get_source(obs, name)
        if source then
            results[#results + 1] = {
                name = obs.obs_source_get_name(source),
                kind = obs.obs_source_get_type(source),
                active = obs.obs_source_active(source),
            }
            obs.obs_source_release(source)
        else
            log.warn("skipping source %s: %s", name, tostring(err))
        end
    end
    return results
end

local function main(_args)
    io.write("OBS Studio Script Template\n")
    io.write(string_rep("=", 50) .. "\n\n")

    local obs = create_obs_stub()

    -- 1. Audit sources
    io.write("Source Audit:\n")
    io.write(string_rep("-", 50) .. "\n")
    local sources = audit_sources(obs)
    for i = 1, #sources do
        local s = sources[i]
        io.write(string_format("  %-20s %-30s %s\n", s.name, s.kind, s.active and "ACTIVE" or "inactive"))
    end

    -- 2. List scenes and their sources
    io.write("\nScene Layout:\n")
    io.write(string_rep("-", 50) .. "\n")
    local scenes = obs.obs_enum_scenes()
    for i = 1, #scenes do
        local scene_name = obs.obs_scene_get_name(scenes[i])
        io.write(string_format("  Scene: %s\n", scene_name))
        local ok, scene_sources = list_scene_sources(obs, scene_name)
        if ok then
            for j = 1, #scene_sources do
                io.write(string_format("    - %s\n", scene_sources[j]))
            end
        else
            io.write(string_format("    (error: %s)\n", tostring(scene_sources)))
        end
    end

    -- 3. Validate edge cases
    io.write("\nValidation Edge Cases:\n")
    io.write(string_rep("-", 50) .. "\n")

    -- Missing source
    local _src, src_err = safe_get_source(obs, "NonExistent")
    io.write(string_format("  Get missing source: %s\n", tostring(src_err)))

    -- Empty name
    local _src2, empty_err = safe_get_source(obs, "")
    io.write(string_format("  Get empty name:     %s\n", tostring(empty_err)))

    -- Bad scene name
    local _scene_ok, scene_err = validate_scene_name(obs, "No Such Scene")
    io.write(string_format("  Bad scene name:     %s\n", tostring(scene_err)))

    -- Nil contract
    local nil_ok, _nil_err = pcall(function()
        obs.obs_source_get_name(nil)
    end)
    if nil_ok then
        io.write("  Nil source guard:   no error\n")
    end
    if not nil_ok then
        io.write("  Nil source guard:   caught\n")
    end

    io.write("\n")
    log.info("OBS script demo complete")
    return 0
end

os.exit(main(arg))
