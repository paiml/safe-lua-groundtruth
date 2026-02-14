#!/usr/bin/env lua5.1
--[[
  mlt_pipeline.lua — Example: MLT multimedia framework timeline composition.
  Demonstrates the MLT SWIG Lua API patterns: Producer, Playlist, Tractor,
  Transition, Filter, and Consumer. Falls back to a mock API when the real
  mlt module is unavailable, so the code structure is identical either way.

  Usage: lua5.1 examples/mlt_pipeline.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local log = require("safe.log")

local string_format = string.format
local string_rep = string.rep
local tostring = tostring
local setmetatable = setmetatable
local type = type

log.set_level(log.INFO)
log.set_context("mlt")

--------------------------------------------------------------------------------
-- Mock MLT SWIG API
--------------------------------------------------------------------------------
-- Simulates the real MLT Lua SWIG bindings interface so the example runs
-- without the C library installed. Every mock object mirrors the real API.

local function make_mock_mlt()
    local mock = {}

    -- Property bag shared by all mock services
    local function make_properties()
        local props = {}
        local mt = {}
        mt.__index = {
            set = function(self, key, value)
                self._props[key] = value
            end,
            get = function(self, key)
                return self._props[key]
            end,
        }
        local obj = setmetatable({ _props = props }, mt)
        return obj
    end

    -- Base service with attach/detach
    local function make_service(kind, name)
        local svc = make_properties()
        svc._kind = kind
        svc._name = name
        svc._filters = {}
        svc._valid = true
        local base_mt = getmetatable(svc)
        base_mt.__index.is_valid = function(self)
            return self._valid
        end
        base_mt.__index.attach = function(self, filter)
            self._filters[#self._filters + 1] = filter
        end
        base_mt.__index.describe = function(self)
            return string_format("%s(%s)", self._kind, self._name)
        end
        return svc
    end

    function mock.Factory_init()
        log.info("mlt.Factory_init()")
    end

    function mock.Factory_close()
        log.info("mlt.Factory_close()")
    end

    function mock.Profile(name)
        local p = make_service("Profile", name or "dv_pal")
        local mt = getmetatable(p)
        mt.__index.width = function()
            return 720
        end
        mt.__index.height = function()
            return 576
        end
        mt.__index.fps = function()
            return 25
        end
        log.debug("created profile: %s", name or "dv_pal")
        return p
    end

    function mock.Producer(profile, resource)
        guard.contract(profile ~= nil, "profile required")
        guard.contract(type(resource) == "string", "resource must be string")
        local p = make_service("Producer", resource)
        p:set("resource", resource)
        p:set("length", 250) -- 10 seconds at 25fps
        local mt = getmetatable(p)
        mt.__index.get_length = function()
            return 250
        end
        mt.__index.get_in = function()
            return 0
        end
        mt.__index.get_out = function(self)
            return self:get("length") - 1
        end
        log.debug("created producer: %s", resource)
        return p
    end

    function mock.Playlist(profile)
        guard.contract(profile ~= nil, "profile required")
        local pl = make_service("Playlist", "playlist")
        pl._clips = {}
        local mt = getmetatable(pl)
        mt.__index.append = function(self, producer, in_point, out_point)
            self._clips[#self._clips + 1] = {
                producer = producer,
                in_point = in_point or 0,
                out_point = out_point or -1,
            }
        end
        mt.__index.count = function(self)
            return #self._clips
        end
        mt.__index.get_length = function()
            return 750
        end
        return pl
    end

    function mock.Tractor(profile)
        guard.contract(profile ~= nil, "profile required")
        local tr = make_service("Tractor", "tractor")
        tr._tracks = {}
        local mt = getmetatable(tr)
        mt.__index.set_track = function(self, producer, track_n)
            self._tracks[track_n] = producer
        end
        mt.__index.multitrack = function(self)
            return self
        end
        mt.__index.field = function(self)
            return self
        end
        mt.__index.plant_transition = function(_self, transition, a_track, b_track)
            log.debug("planted transition %s between tracks %d and %d", transition:describe(), a_track, b_track)
        end
        mt.__index.plant_filter = function(_self, filter, track)
            log.debug("planted filter %s on track %d", filter:describe(), track)
        end
        return tr
    end

    function mock.Transition(profile, name)
        guard.contract(profile ~= nil, "profile required")
        guard.contract(type(name) == "string", "transition name must be string")
        local t = make_service("Transition", name)
        log.debug("created transition: %s", name)
        return t
    end

    function mock.Filter(profile, name)
        guard.contract(profile ~= nil, "profile required")
        guard.contract(type(name) == "string", "filter name must be string")
        local f = make_service("Filter", name)
        log.debug("created filter: %s", name)
        return f
    end

    function mock.Consumer(profile, name)
        guard.contract(profile ~= nil, "profile required")
        local c = make_service("Consumer", name or "sdl2")
        c._running = false
        local mt = getmetatable(c)
        mt.__index.connect = function(self, producer)
            self._source = producer
            log.debug("consumer connected to %s", producer:describe())
        end
        mt.__index.start = function(self)
            self._running = true
            log.debug("consumer started")
        end
        mt.__index.stop = function(self)
            self._running = false
            log.debug("consumer stopped")
        end
        mt.__index.is_stopped = function(self)
            return not self._running
        end
        return c
    end

    return mock
end

--------------------------------------------------------------------------------
-- Resolve mlt module: real SWIG bindings or mock
--------------------------------------------------------------------------------
local mlt_ok, mlt = pcall(require, "mlt")
local using_mock = false
if not mlt_ok then
    mlt = make_mock_mlt()
    using_mock = true
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function banner(title)
    io.write("\n" .. title .. "\n")
    io.write(string_rep("-", 60) .. "\n")
end

local function show_properties(service, keys)
    for i = 1, #keys do
        local val = service:get(keys[i])
        if val then
            io.write(string_format("  %-15s = %s\n", keys[i], tostring(val)))
        end
    end
end

--------------------------------------------------------------------------------
-- Demo 1: Simple playback
--------------------------------------------------------------------------------
local function demo_simple_playback(profile)
    banner("1. Simple Playback")
    io.write("Load a file and connect to a consumer for playback.\n\n")

    local producer = mlt.Producer(profile, "intro.mp4")
    guard.contract(producer:is_valid(), "producer must be valid")
    io.write(string_format("  Producer: %s (length=%d frames)\n", "intro.mp4", producer:get_length()))

    local consumer = mlt.Consumer(profile, "sdl2")
    consumer:set("rescale", "bicubic")
    consumer:connect(producer)
    consumer:start()

    -- In real code: while not consumer:is_stopped() do posix.usleep(10000) end
    io.write("  Consumer started (sdl2 window)\n")
    consumer:stop()
    io.write("  Playback complete.\n")
end

--------------------------------------------------------------------------------
-- Demo 2: Playlist with trimmed clips
--------------------------------------------------------------------------------
local function demo_playlist_cuts(profile)
    banner("2. Playlist with Trimmed Clips")
    io.write("Sequence 3 clips with in/out trim points.\n\n")

    local clips = {
        { file = "scene_01.mp4", in_pt = 0, out_pt = 74 },
        { file = "scene_02.mp4", in_pt = 25, out_pt = 149 },
        { file = "scene_03.mp4", in_pt = 50, out_pt = 199 },
    }

    local playlist = mlt.Playlist(profile)
    for i = 1, #clips do
        local c = clips[i]
        local producer = mlt.Producer(profile, c.file)
        guard.contract(producer:is_valid(), "producer must be valid: " .. c.file)
        playlist:append(producer, c.in_pt, c.out_pt)
        local dur = c.out_pt - c.in_pt + 1
        io.write(string_format("  [%d] %s  in=%d out=%d (%d frames)\n", i, c.file, c.in_pt, c.out_pt, dur))
    end

    io.write(string_format("\n  Playlist: %d clips, %d total frames\n", playlist:count(), playlist:get_length()))

    local consumer = mlt.Consumer(profile, "sdl2")
    consumer:connect(playlist)
    consumer:start()
    consumer:stop()
    io.write("  Playback complete.\n")
end

--------------------------------------------------------------------------------
-- Demo 3: Dissolve transition via Tractor
--------------------------------------------------------------------------------
local function demo_dissolve_transition(profile)
    banner("3. Dissolve Transition (Tractor)")
    io.write("Two clips composited with a luma dissolve.\n\n")

    local clip_a = mlt.Producer(profile, "sunset.mp4")
    local clip_b = mlt.Producer(profile, "sunrise.mp4")
    guard.contract(clip_a:is_valid(), "clip_a must be valid")
    guard.contract(clip_b:is_valid(), "clip_b must be valid")

    local tractor = mlt.Tractor(profile)
    tractor:set_track(clip_a, 0)
    tractor:set_track(clip_b, 1)
    io.write("  Track 0: sunset.mp4\n")
    io.write("  Track 1: sunrise.mp4\n")

    local transition = mlt.Transition(profile, "luma")
    transition:set("duration", "50")
    transition:set("softness", "0.1")

    local field = tractor:field()
    field:plant_transition(transition, 0, 1)
    io.write("  Transition: luma dissolve (50 frames, softness=0.1)\n")

    local consumer = mlt.Consumer(profile, "sdl2")
    consumer:connect(tractor)
    consumer:start()
    consumer:stop()
    io.write("  Playback complete.\n")
end

--------------------------------------------------------------------------------
-- Demo 4: Filter chain
--------------------------------------------------------------------------------
local function demo_filter_chain(profile)
    banner("4. Filter Chain")
    io.write("Apply greyscale + volume adjustment to a clip.\n\n")

    local producer = mlt.Producer(profile, "interview.mp4")
    guard.contract(producer:is_valid(), "producer must be valid")

    local greyscale = mlt.Filter(profile, "greyscale")
    local volume = mlt.Filter(profile, "volume")
    volume:set("gain", "0.8")

    producer:attach(greyscale)
    producer:attach(volume)
    io.write("  Filters attached to interview.mp4:\n")
    io.write("    - greyscale\n")
    io.write("    - volume (gain=0.8)\n")

    local consumer = mlt.Consumer(profile, "sdl2")
    consumer:connect(producer)
    consumer:start()
    consumer:stop()
    io.write("  Playback complete.\n")
end

--------------------------------------------------------------------------------
-- Demo 5: Render to file
--------------------------------------------------------------------------------
local function demo_render_to_file(profile)
    banner("5. Render to File (avformat consumer)")
    io.write("Encode a playlist to an output file via avformat consumer.\n\n")

    local playlist = mlt.Playlist(profile)
    local files = { "clip_a.mp4", "clip_b.mp4" }
    for i = 1, #files do
        local p = mlt.Producer(profile, files[i])
        guard.contract(p:is_valid(), "producer must be valid: " .. files[i])
        playlist:append(p)
    end
    io.write(string_format("  Playlist: %d clips\n", playlist:count()))

    local consumer = mlt.Consumer(profile, "avformat")
    consumer:set("target", "output/final_edit.mp4")
    consumer:set("vcodec", "libx264")
    consumer:set("acodec", "aac")
    consumer:set("width", "1920")
    consumer:set("height", "1080")
    consumer:set("frame_rate_num", "25")

    show_properties(consumer, { "target", "vcodec", "acodec", "width", "height" })

    consumer:connect(playlist)
    consumer:start()

    -- In real code: poll consumer:is_stopped() in a loop
    io.write("\n  Encoding started...\n")
    consumer:stop()
    io.write("  Encoding complete: output/final_edit.mp4\n")
end

--------------------------------------------------------------------------------
-- Main
--------------------------------------------------------------------------------
local function main(_args)
    io.write("MLT Multimedia Pipeline\n")
    io.write(string_rep("=", 60) .. "\n")

    if using_mock then
        io.write("(mock mode — mlt SWIG bindings not installed)\n")
    else
        io.write("(live mode — using real mlt SWIG bindings)\n")
    end

    mlt.Factory_init()
    local profile = mlt.Profile("dv_pal")

    io.write(string_format("\nProfile: %dx%d @ %d fps\n", profile:width(), profile:height(), profile:fps()))

    demo_simple_playback(profile)
    demo_playlist_cuts(profile)
    demo_dissolve_transition(profile)
    demo_filter_chain(profile)
    demo_render_to_file(profile)

    mlt.Factory_close()

    io.write("\n" .. string_rep("=", 60) .. "\n")
    io.write("All MLT pipeline demos complete.\n")
    log.info("mlt pipeline example finished")
    return 0
end

os.exit(main(arg))
