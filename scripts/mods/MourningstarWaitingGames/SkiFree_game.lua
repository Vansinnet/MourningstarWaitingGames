-- SkiFree after the 1991 classic: pure logic (world, skier physics, hazards, slalom, the Yeti)
-- plus the Win95 shell that owns menus and dialogs. The view only renders and forwards input.
local mod = get_mod("MourningstarWaitingGames")
local Win95 = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_win95")

local math_abs = math.abs
local math_atan2 = math.atan2
local math_ceil = math.ceil
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_random = math.random
local math_sin = math.sin
local math_sqrt = math.sqrt

local CLIENT_W, CLIENT_H = 560, 470
local PX_PER_M = 12
local CHUNK = 192
local STEP = 1 / 120

-- Skier directions -3..3: hard left (sideways), left, left-steep, down, right-steep, right, hard right.
local DIR_ANGLE = {}
for d = -3, 3 do DIR_ANGLE[d] = d * math_pi / 6 end
local DIR_SPEED = { [0] = 1, [1] = 0.84, [2] = 0.55, [3] = 0 }

local VMAX = 190
local VTURBO = 290
local ACCEL = 150
local ACCEL_TURBO = 190
local DECEL = 210
local STOP_DECEL = 460
local BRAKE_DECEL = 520
local GRAVITY = 460
local HOP_V = 130
local RAMP_V = 150
local RAMP_K = 0.45
local WALK_SPEED = 42
local SHUFFLE = 6
local CRASH_TIME = 1.25
local GETUP_TIME = 0.4
local ANCHOR_REST = 185
local ANCHOR_FAST = 125

local YETI_METRES = 2000
local YETI_V0 = 225
local YETI_ACCEL = 1.6
local YETI_VMAX = 330
local YETI_LEASH = 650
local YETI_REACH = 15
local EAT_TIME = 3.3

local SLALOM_X = -340
local SLALOM_START_Y = 300
local SLALOM_GATES = 20
local SLALOM_FIRST = 440
local SLALOM_GAP = 180
local SLALOM_HALF = 30
local SLALOM_PENALTY = 5
local SLALOM_FINISH_Y = SLALOM_FIRST + (SLALOM_GATES - 1) * SLALOM_GAP + 200
local SLALOM_LANE = 72

local FREE_X0, FREE_X1 = 300, 740
local FREE_BANNER_X = 470
local FREE_Y0, FREE_Y1 = 280, 1200 * PX_PER_M

local LIFT_X = 236
local LIFT_SPACING = 2600
local POLE_GAP = 420
local POLE_OFFSET = 80

local SKIER_BOX = { -4, 4, -3, 1 }

local KINDS = {
    tree_small = { hit = { -6, 6, -6, 2 }, height = 34, effect = "crash" },
    tree_big = { hit = { -8, 8, -6, 2 }, height = 60, effect = "crash" },
    tree_dead = { hit = { -5, 5, -5, 2 }, height = 42, effect = "crash" },
    stump = { hit = { -6, 6, -5, 1 }, height = 9, effect = "crash" },
    rock = { hit = { -8, 8, -5, 1 }, height = 11, effect = "crash" },
    mogul = { hit = { -11, 11, -7, 1 }, height = 5, effect = "bump" },
    ramp = { hit = { -14, 14, -9, 1 }, height = 7, effect = "ramp" },
    lift_pole = { hit = { -4, 4, -4, 2 }, height = 1000, effect = "crash" },
    sign = { hit = { -3, 3, -4, 2 }, height = 30, effect = "crash" },
    banner_pole = { hit = { -3, 3, -4, 2 }, height = 1000, effect = "crash" },
    flag = { hit = { -3, 3, -4, 2 }, height = 28, effect = "flag" },
    dog = { hit = { -8, 8, -5, 2 }, height = 14, effect = "crash" },
    boarder = { hit = { -6, 6, -5, 2 }, height = 32, effect = "crash" },
}

local TRICKS = {
    { name = "Spread Eagle", time = 0.34, points = 10 },
    { name = "Daffy", time = 0.34, points = 12 },
    { name = "Helicopter", time = 0.5, points = 20 },
    { name = "Back Flip", time = 0.6, points = 30 },
}

-- Fixed course furniture: start banner, signs, slalom course, freestyle banner.
local FIXED = {
    { kind = "banner_pole", x = -72, y = 96 },
    { kind = "banner_pole", x = 72, y = 96 },
    { kind = "sign", x = -122, y = 178, text = "Slalom", arrow = -1 },
    { kind = "sign", x = 122, y = 178, text = "Freestyle", arrow = 1 },
    { kind = "banner_pole", x = SLALOM_X - 66, y = SLALOM_START_Y },
    { kind = "banner_pole", x = SLALOM_X + 66, y = SLALOM_START_Y },
    { kind = "banner_pole", x = SLALOM_X - 66, y = SLALOM_FINISH_Y },
    { kind = "banner_pole", x = SLALOM_X + 66, y = SLALOM_FINISH_Y },
    { kind = "banner_pole", x = FREE_BANNER_X - 100, y = FREE_Y0 - 30 },
    { kind = "banner_pole", x = FREE_BANNER_X + 100, y = FREE_Y0 - 30 },
}
local BANNERS = {
    { x = 0, y = 96, w = 144, text = "SkiFree", style = "start" },
    { x = SLALOM_X, y = SLALOM_START_Y, w = 132, text = "Slalom", style = "slalom" },
    { x = SLALOM_X, y = SLALOM_FINISH_Y, w = 132, text = "Finish", style = "finish" },
    { x = FREE_BANNER_X, y = FREE_Y0 - 30, w = 200, text = "Freestyle", style = "freestyle" },
}
local GATES = {}
for i = 1, SLALOM_GATES do
    local side = i % 2 == 1 and -1 or 1
    GATES[i] = { x = SLALOM_X + side * 34, y = SLALOM_FIRST + (i - 1) * SLALOM_GAP, color = i % 2 == 1 and "red" or "blue" }
    FIXED[#FIXED + 1] = { kind = "flag", x = GATES[i].x - SLALOM_HALF, y = GATES[i].y, color = GATES[i].color, gate = i, side = -1 }
    FIXED[#FIXED + 1] = { kind = "flag", x = GATES[i].x + SLALOM_HALF, y = GATES[i].y, color = GATES[i].color, gate = i, side = 1 }
end

local SkiFreeGame = {}
SkiFreeGame.__index = SkiFreeGame

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function sign(value)
    if value < 0 then return -1 end
    return 1
end

-- Park-Miller generator for deterministic world chunks (no bit operators in Lua 5.1).
local chunk_state = 1
local function rnd()
    chunk_state = (chunk_state * 16807) % 2147483647
    return chunk_state / 2147483647
end

local function chunk_seed(cx, cy, seed)
    local h = (cx * 92821 + cy * 68917 + seed * 131 + 7) % 2147483647
    h = (h * 16807 + 12345) % 2147483647
    if h <= 0 then h = h + 2147483646 end
    return h
end

local function lift_near(x)
    return LIFT_X + math_floor((x - LIFT_X) / LIFT_SPACING + 0.5) * LIFT_SPACING
end

local function excluded(x, y)
    if x > -175 and x < 175 and y > -150 and y < 265 then return true end
    if y > SLALOM_START_Y - 90 and y < SLALOM_FINISH_Y + 90 and math_abs(x - SLALOM_X) < 124 then return true end
    if math_abs(x - lift_near(x)) < 38 then return true end
    if y > FREE_Y0 - 90 and y < FREE_Y0 + 30 and math_abs(x - FREE_BANNER_X) < 130 then return true end
    return false
end

local function spaced(list, x, y, sep)
    local sep2 = sep * sep
    for i = 1, #list do
        local o = list[i]
        local dx, dy = o.x - x, o.y - y
        if dx * dx + dy * dy < sep2 then return false end
    end
    return true
end

local function add(list, kind, x, y)
    local o = { kind = kind, x = math_floor(x + 0.5), y = math_floor(y + 0.5), var = rnd() < 0.5 and 0 or 1 }
    list[#list + 1] = o
    return o
end

local function scatter(list, kind, x0, y0, sep)
    for _ = 1, 6 do
        local x = x0 + rnd() * CHUNK
        local y = y0 + rnd() * CHUNK
        if not excluded(x, y) and spaced(list, x, y, sep) then
            return add(list, kind, x, y)
        end
    end
end

local function amount(expected)
    local n = math_floor(expected)
    if rnd() < expected - n then n = n + 1 end
    return n
end

-- options: get(key), set(key, value), on_sound(kind), seed (tests)
function SkiFreeGame:new(options)
    local game = setmetatable({}, SkiFreeGame)
    game._options = options or {}
    game._events = {}
    game._event_count = 0
    game._time = 0
    game._clock = 0
    game._held = {}
    game._close_requested = false
    game._steer = "keys"
    game._px, game._py = -1, -1
    game._pointer_seen = false
    game._pointer_in_client = false
    game._seed_base = tonumber(game._options.seed)
    local get = game._options.get
    game._best = math_max(0, math_floor(tonumber(get and get("skifree_highscore")) or 0))
    local slalom_best = tonumber(get and get("skifree_slalom_best"))
    game._slalom_best = slalom_best and slalom_best > 0 and slalom_best or nil
    game:_build_shell()
    game:_reset()
    return game
end

function SkiFreeGame:start()
    self:new_game()
end

function SkiFreeGame:_persist(key, value)
    local set = self._options.set
    if set then set(key, value) end
end

function SkiFreeGame:_sound(kind)
    local on_sound = self._options.on_sound
    if on_sound then on_sound(kind) end
end

function SkiFreeGame:_event(kind, x, y, value, extra)
    local n = self._event_count + 1
    local e = self._events[n]
    if not e then
        e = {}
        self._events[n] = e
    end
    e.kind, e.x, e.y, e.value, e.extra = kind, x, y, value, extra
    self._event_count = n
end

-- callback(kind, x, y, value, extra); x, y are world coordinates.
function SkiFreeGame:drain_events(callback)
    for i = 1, self._event_count do
        local e = self._events[i]
        callback(e.kind, e.x, e.y, e.value, e.extra)
    end
    self._event_count = 0
end

-- Shell ---------------------------------------------------------------------------------

function SkiFreeGame:_build_shell()
    local game = self
    self._shell = Win95.shell({
        client_w = CLIENT_W,
        client_h = CLIENT_H,
        menus = {
            { id = "game", label = "Game", width = 176, items = {
                { id = "new", label = "New Game", key = "R" },
                { id = "pause", label = "Pause", check = function() return game._paused end,
                    enabled = function() return game._state ~= "eaten" and game._state ~= "over" end },
                { separator = true },
                { id = "exit", label = "Exit", key = "Esc" },
            } },
            { id = "help", label = "Help", width = 176, items = {
                { id = "how_to", label = "How to Play..." },
                { separator = true },
                { id = "about", label = "About SkiFree..." },
            } },
        },
        on_command = function(id) game:_command(id) end,
        on_dialog = function(dialog, id) return game:_dialog_button(dialog, id) end,
    })
end

function SkiFreeGame:_command(id)
    if id == "new" then
        self:new_game()
    elseif id == "pause" then
        self:set_paused(not self._paused)
    elseif id == "exit" then
        self._close_requested = true
    elseif id == "how_to" then
        self._shell:open_dialog({ kind = "how_to", title = "How to Play", w = 404, h = 300, buttons_align = "center" })
    elseif id == "about" then
        self._shell:open_dialog({ kind = "about", title = "About SkiFree", w = 344, h = 186, buttons_align = "center" })
    end
end

function SkiFreeGame:_dialog_button(dialog, id)
    if dialog.kind == "over" then
        if id == "again" then
            self:new_game()
        elseif id == "exit" then
            self._close_requested = true
        end
    end
    return false
end

function SkiFreeGame:_open_over_dialog()
    self._shell:open_dialog({
        kind = "over", title = "SkiFree", w = 330, h = 170, cancel_id = "close",
        buttons = { { id = "again", label = "Play Again", default = true, w = 96 }, { id = "exit", label = "Exit" } },
        buttons_align = "center",
    })
end

function SkiFreeGame:set_paused(paused)
    if self._state == "eaten" or self._state == "over" then paused = false end
    if paused == self._paused then return end
    self._paused = paused and true or false
    self:_event(self._paused and "pause" or "resume")
end

-- Game state ----------------------------------------------------------------------------

function SkiFreeGame:_reset()
    self._world_seed = self._seed_base or math_random(1, 2000000000)
    self._state = "ski"
    self._paused = false
    self._x, self._y, self._z, self._vz = 0, 0, 0, 0
    self._air_vx, self._air_vy = 0, 0
    self._dir = 3
    self._speed = 0
    self._started = false
    self._elapsed = 0
    self._style = 0
    self._max_y = 0
    self._crash_t = 0
    self._crash_kind = nil
    self._jump_kind = nil
    self._trick = nil
    self._trick_t = 0
    self._last_trick = 0
    self._pending = 0
    self._jump_tricks = 0
    self._tricks_seen = {}
    self._brake_t = 0
    self._walk_t = 0
    self._walk_phase = 0
    self._walking = false
    self._turbo_toggle = false
    self._spray = 0
    self._movers = {}
    self._chunks = {}
    self._chunk_count = 0
    self._ghost = {}
    self._yeti = nil
    self._eat_t = 0
    self._eat_stage = 0
    self._slalom = { active = false, next_gate = 1, missed = 0, passed = 0, time = 0 }
    self._slalom_result = nil
    self._cam_x = -CLIENT_W * 0.5
    self._anchor = ANCHOR_REST
    self._cam_y = -ANCHOR_REST
    self._next_spawn = 140 * PX_PER_M
    self._milestone = 0
    self._mover_id = 0
    self._record_told = false
    self._run_best = self._best
end

function SkiFreeGame:new_game()
    self:_save_best()
    if self._shell:dialog() then self._shell:close_dialog() end
    if self._shell:menu() then self._shell:close_menu() end
    self:_reset()
    self:_event("new")
end

function SkiFreeGame:_save_best()
    local metres = math_floor(self:max_distance())
    if metres > self._best then
        self._best = metres
        self:_persist("skifree_highscore", metres)
    end
end

-- World generation ------------------------------------------------------------------------

function SkiFreeGame:_fixed_objects(list, x0, y0, x1, y1)
    for i = 1, #FIXED do
        local f = FIXED[i]
        if f.x >= x0 and f.x < x1 and f.y >= y0 and f.y < y1 then
            list[#list + 1] = { kind = f.kind, x = f.x, y = f.y, text = f.text, arrow = f.arrow, color = f.color, gate = f.gate, side = f.side, var = 0 }
        end
    end

    local j0 = math_ceil((x0 - LIFT_X) / LIFT_SPACING)
    local j1 = math_floor((x1 - 1 - LIFT_X) / LIFT_SPACING)
    for j = j0, j1 do
        local lx = LIFT_X + j * LIFT_SPACING
        local k0 = math_ceil((y0 - POLE_OFFSET) / POLE_GAP)
        local k1 = math_floor((y1 - 1 - POLE_OFFSET) / POLE_GAP)
        for k = k0, k1 do
            list[#list + 1] = { kind = "lift_pole", x = lx, y = POLE_OFFSET + k * POLE_GAP, var = 0 }
        end
    end
end

function SkiFreeGame:_generate(cx, cy)
    local list = {}
    local x0, y0 = cx * CHUNK, cy * CHUNK
    self:_fixed_objects(list, x0, y0, x0 + CHUNK, y0 + CHUNK)
    chunk_state = chunk_seed(cx, cy, self._world_seed)
    rnd(); rnd()

    local mid_x, mid_y = x0 + CHUNK * 0.5, y0 + CHUNK * 0.5
    if mid_y < -200 then
        for _ = 1, amount(1.1) do scatter(list, rnd() < 0.6 and "tree_small" or "tree_big", x0, y0, 30) end
        return list
    end

    local metres = math_max(0, mid_y) / PX_PER_M
    local d = clamp(metres / 2500, 0, 1) + clamp((metres - 2500) / 10000, 0, 0.3)
    local freestyle = mid_x > FREE_X0 and mid_x < FREE_X1 and mid_y > FREE_Y0 and mid_y < FREE_Y1
    local tree_k = freestyle and 0.35 or 1

    if not freestyle and rnd() < 0.08 + 0.1 * d then
        local fx, fy = x0 + 30 + rnd() * (CHUNK - 60), y0 + 30 + rnd() * (CHUNK - 60)
        for _ = 1, 3 + math_floor(rnd() * 4) do
            local x, y = fx + (rnd() - 0.5) * 90, fy + (rnd() - 0.5) * 80
            if x > x0 and x < x0 + CHUNK and y > y0 and y < y0 + CHUNK and not excluded(x, y) and spaced(list, x, y, 20) then
                add(list, rnd() < 0.55 and "tree_big" or "tree_small", x, y)
            end
        end
    end

    for _ = 1, amount((0.9 + 1.2 * d) * tree_k) do scatter(list, "tree_small", x0, y0, 28) end
    for _ = 1, amount((0.45 + 0.7 * d) * tree_k) do scatter(list, "tree_big", x0, y0, 32) end
    for _ = 1, amount((0.12 + 0.3 * d) * tree_k) do scatter(list, "tree_dead", x0, y0, 28) end
    for _ = 1, amount(0.25 + 0.25 * d) do scatter(list, "stump", x0, y0, 26) end
    for _ = 1, amount(0.3 + 0.3 * d) do scatter(list, "rock", x0, y0, 26) end
    for _ = 1, amount(freestyle and 2.6 or 0.35) do scatter(list, "mogul", x0, y0, 30) end
    for _ = 1, amount(freestyle and 0.75 or 0.1 + 0.06 * d) do scatter(list, "ramp", x0, y0, 46) end

    return list
end

function SkiFreeGame:_chunk(cx, cy)
    local column = self._chunks[cx]
    if not column then
        column = {}
        self._chunks[cx] = column
    end
    local list = column[cy]
    if not list then
        list = self:_generate(cx, cy)
        column[cy] = list
        self._chunk_count = self._chunk_count + 1
    end
    return list
end

function SkiFreeGame:_evict_chunks()
    if self._chunk_count < 80 then return end
    local cx0 = math_floor((self._cam_x - 2 * CHUNK) / CHUNK)
    local cx1 = math_floor((self._cam_x + CLIENT_W + 2 * CHUNK) / CHUNK)
    local cy0 = math_floor((self._cam_y - 2 * CHUNK) / CHUNK)
    local cy1 = math_floor((self._cam_y + CLIENT_H + 2 * CHUNK) / CHUNK)
    for cx, column in pairs(self._chunks) do
        for cy in pairs(column) do
            if cx < cx0 or cx > cx1 or cy < cy0 or cy > cy1 then
                column[cy] = nil
                self._chunk_count = self._chunk_count - 1
            end
        end
        if next(column) == nil then self._chunks[cx] = nil end
    end
end

-- Collision --------------------------------------------------------------------------------

local function overlaps(x, y, o)
    local hit = KINDS[o.kind].hit
    return x + SKIER_BOX[2] > o.x + hit[1] and x + SKIER_BOX[1] < o.x + hit[2]
        and y + SKIER_BOX[4] > o.y + hit[3] and y + SKIER_BOX[3] < o.y + hit[4]
end

function SkiFreeGame:_refresh_ghosts()
    for o in pairs(self._ghost) do
        if not overlaps(self._x, self._y, o) then self._ghost[o] = nil end
    end
end

-- Returns the first non-ghost object overlapping the skier, optionally only solid ones.
function SkiFreeGame:_hit_test(x, y, solid_only)
    local cx0 = math_floor((x - 24) / CHUNK)
    local cx1 = math_floor((x + 24) / CHUNK)
    local cy0 = math_floor((y - 16) / CHUNK)
    local cy1 = math_floor((y + 16) / CHUNK)
    for cx = cx0, cx1 do
        for cy = cy0, cy1 do
            local list = self:_chunk(cx, cy)
            for i = 1, #list do
                local o = list[i]
                if not self._ghost[o] and overlaps(x, y, o) then
                    local kind = KINDS[o.kind]
                    if not solid_only or kind.effect == "crash" then return o end
                end
            end
        end
    end
    local movers = self._movers
    for i = 1, #movers do
        local m = movers[i]
        if not self._ghost[m] and not m.fallen and overlaps(x, y, m) then return m end
    end
    return nil
end

function SkiFreeGame:_collide()
    local o = self:_hit_test(self._x, self._y, false)
    if not o then return end
    local kind = KINDS[o.kind]
    local z = self._z

    if kind.effect == "ramp" then
        self._ghost[o] = true
        if z < 4 and self._speed > 20 then
            self:_launch(RAMP_V + self._speed * RAMP_K, "ramp")
            self:_sound("jump")
        end
    elseif kind.effect == "bump" then
        self._ghost[o] = true
        if z < 3 and self._speed > 60 then
            self:_launch(70 + self._speed * 0.25, "bump")
        end
    elseif kind.effect == "flag" then
        self._ghost[o] = true
        o.hit_at = self._clock
        self:_event("flag", o.x, o.y)
    elseif z < kind.height then
        self._ghost[o] = true
        if o.kind == "dog" then
            o.flee = 1.6
            o.vx = sign(o.x - self._x) * 150
            self:_event("woof", o.x, o.y)
        elseif o.kind == "boarder" then
            o.fallen = 1.8
            self:_event("boarder_fall", o.x, o.y)
        end
        o.hit_at = self._clock
        self:_crash(o.kind, o)
    end
end

-- Skier -------------------------------------------------------------------------------------

function SkiFreeGame:_set_dir(d)
    d = clamp(d, -3, 3)
    if self._state == "air" then d = clamp(d, -2, 2) end
    if d == self._dir then return end
    local old = self._dir
    self._dir = d
    if self._state == "ski" and self._speed > 80 and math_abs(d - old) >= 1 then
        self:_event("turn", self._x, self._y, self._speed / VMAX * math_min(2, math_abs(d - old)))
    end
end

function SkiFreeGame:_start_clock()
    if not self._started then
        self._started = true
        self:_event("go", self._x, self._y)
    end
end

function SkiFreeGame:_launch(vz, kind)
    local angle = DIR_ANGLE[self._dir]
    if self._state ~= "air" then
        self._air_vx = self._speed * math_sin(angle)
        self._air_vy = self._speed * math_cos(angle)
        self._pending = 0
        self._jump_tricks = 0
        for k in pairs(self._tricks_seen) do self._tricks_seen[k] = nil end
    end
    self._state = "air"
    self._jump_kind = kind
    self._vz = vz
    self._z = math_max(self._z, 0.01)
    self._dir = clamp(self._dir, -2, 2)
    self:_start_clock()
    self:_event(kind, self._x, self._y, vz)
end

function SkiFreeGame:_crash(kind, object)
    local from_air = self._state == "air"
    self._state = "crash"
    self._crash_t = 0
    self._crash_kind = kind
    self._speed = 0
    self._z, self._vz = 0, 0
    self._trick = nil
    self._pending = 0
    self._turbo_toggle = false
    self._brake_t = 0
    self:_event("crash", self._x, self._y, kind == "trick" and "trick" or (from_air and "air" or kind), object)
    self:_sound("crash")
    self:_save_best()
end

function SkiFreeGame:_land()
    self._z, self._vz = 0, 0
    if self._trick then
        self:_crash("trick")
        return
    end
    self._state = "ski"
    self._speed = math_sqrt(self._air_vx * self._air_vx + self._air_vy * self._air_vy)
    if self._jump_kind == "ramp" or self._pending > 0 then
        local gained = self._pending
        if self._jump_kind == "ramp" then gained = gained + 5 end
        if self._jump_tricks > 1 then gained = gained + (self._jump_tricks - 1) * 5 end
        self._style = self._style + gained
        self:_event("land", self._x, self._y, gained)
        if self._pending > 0 then self:_sound("style") end
    else
        self:_event("touchdown", self._x, self._y)
    end
    self._pending = 0
    self._jump_kind = nil
end

function SkiFreeGame:_do_trick(step)
    if self._state ~= "air" then return end
    local n = #TRICKS
    local index = ((self._trick or self._last_trick) - 1 + step) % n + 1
    self._trick = index
    self._last_trick = index
    self._trick_t = 0
    self:_event("trick_start", self._x, self._y, index)
end

function SkiFreeGame:jump()
    if self._paused or self._shell:is_modal() then return end
    if self._state == "air" then
        self:_do_trick(1)
    elseif self._state == "ski" then
        self:_launch(HOP_V, "hop")
    elseif self._state == "crash" then
        self:_get_up_early()
    end
end

function SkiFreeGame:_get_up_early()
    if self._crash_t > 0.6 and self._crash_t < CRASH_TIME - GETUP_TIME then
        self._crash_t = CRASH_TIME - GETUP_TIME
    end
end

function SkiFreeGame:_turn(step)
    if self._state == "crash" then
        self:_get_up_early()
        return
    end
    if self._state ~= "ski" and self._state ~= "air" then return end

    local d = self._dir
    if self._state == "ski" and ((d == -3 and step < 0) or (d == 3 and step > 0)) then
        -- Facing sideways and pressing that way again: step sideways like the original.
        if self._speed >= 8 then return end
        local nx = self._x + step * SHUFFLE
        if not self:_hit_test(nx, self._y, true) then
            self._x = nx
            self._walk_phase = self._walk_phase + 0.25
            self._walk_t = math_max(self._walk_t, 0.12)
            self:_start_clock()
        end
        return
    end
    self:_set_dir(d + step)
end

function SkiFreeGame:_point_down()
    if self._state == "crash" then
        self:_get_up_early()
        return
    end
    if self._state == "ski" or self._state == "air" then self:_set_dir(0) end
end

function SkiFreeGame:_up_press()
    if self._state == "crash" then
        self:_get_up_early()
    elseif self._state == "air" then
        self:_do_trick(1)
    elseif self._state == "ski" then
        if math_abs(self._dir) == 3 and self._speed < 8 then
            self._walk_t = math_max(self._walk_t, 0.22)
        else
            self._brake_t = math_max(self._brake_t, 0.25)
        end
    end
end

function SkiFreeGame:_step_ski(h)
    local d = self._dir
    local ad = math_abs(d)
    local held_up = self._held.up
    local turbo = self._turbo_toggle or self._held.fast
    local vmax = turbo and VTURBO or VMAX

    self._brake_t = math_max(0, self._brake_t - h)
    self._walk_t = math_max(0, self._walk_t - h)
    local braking = self._brake_t > 0 or (held_up and ad < 3)

    local target = vmax * DIR_SPEED[ad]
    local speed = self._speed
    if braking then
        local before = speed
        speed = math_max(0, speed - BRAKE_DECEL * h)
        if before > 30 then self._spray = self._spray + (before - speed) * 0.02 end
    elseif speed < target then
        speed = math_min(target, speed + (turbo and ACCEL_TURBO or ACCEL) * h)
    elseif speed > target then
        local before = speed
        speed = math_max(target, speed - (ad == 3 and STOP_DECEL or DECEL) * h)
        if ad >= 2 and before > 40 then self._spray = self._spray + (before - speed) * 0.02 end
    end
    self._speed = speed
    if speed < 10 and self._turbo_toggle and ad == 3 then self._turbo_toggle = false end

    local walking = false
    if ad == 3 and speed < 8 and (held_up or self._walk_t > 0) then
        walking = true
        local ny = self._y - WALK_SPEED * h
        if not self:_hit_test(self._x, ny, true) then
            self._y = ny
            self._walk_phase = self._walk_phase + h * 3.5
            self:_start_clock()
        end
    end
    self._walking = walking or self._walk_t > 0

    if speed > 0.01 then
        local angle = DIR_ANGLE[d]
        self._x = self._x + speed * math_sin(angle) * h
        self._y = self._y + speed * math_cos(angle) * h
        self:_start_clock()
    end
end

function SkiFreeGame:_step_air(h)
    self._x = self._x + self._air_vx * h
    self._y = self._y + self._air_vy * h
    self._vz = self._vz - GRAVITY * h
    self._z = self._z + self._vz * h

    if self._trick then
        self._trick_t = self._trick_t + h
        local trick = TRICKS[self._trick]
        if self._trick_t >= trick.time then
            local points = trick.points
            if self._tricks_seen[self._trick] then points = math_floor(points * 0.5) end
            self._tricks_seen[self._trick] = true
            self._pending = self._pending + points
            self._jump_tricks = self._jump_tricks + 1
            self:_event("trick", self._x, self._y - self._z, points, self._trick)
            self._trick = nil
        end
    end

    if self._z <= 0 then self:_land() end
end

function SkiFreeGame:_steer_mouse()
    if self._steer ~= "mouse" or not self._pointer_in_client then return end
    if self._state ~= "ski" and self._state ~= "air" then return end
    local sx, sy = self:skier_screen()
    local dx, dy = self._px - sx, self._py - (sy - 10)
    if dx * dx + dy * dy < 144 then return end
    local d
    if dy <= 0 then
        d = dx < 0 and -3 or 3
    else
        d = clamp(math_floor(math_atan2(dx, dy) / (math_pi / 6) + 0.5), -3, 3)
    end
    self:_set_dir(d)
end

-- Movers --------------------------------------------------------------------------------------

function SkiFreeGame:_rand()
    return math_random()
end

function SkiFreeGame:_spawn_mover()
    local movers = self._movers
    if #movers >= 8 then return end
    local x = self._cam_x + 20 + self:_rand() * (CLIENT_W - 40)
    local y = self._cam_y + CLIENT_H + 30 + self:_rand() * 70
    if excluded(x, y) or self:_hit_test(x, y, false) then return end
    self._mover_id = self._mover_id + 1
    local m
    if self:_rand() < 0.45 then
        m = { kind = "dog", x = x, y = y, vx = (self:_rand() < 0.5 and -1 or 1) * (35 + self:_rand() * 35), turn = 1 + self:_rand() * 2, sit = 0, phase = 0 }
    else
        m = { kind = "boarder", x = x, y = y, base = x, vy = 90 + self:_rand() * 55, amp = 25 + self:_rand() * 45, freq = 1.4 + self:_rand(), phase = self:_rand() * 6.28, lean = 0 }
    end
    m.id = self._mover_id
    m.var = 0
    movers[#movers + 1] = m
end

function SkiFreeGame:_step_movers(h)
    local movers = self._movers
    local i = 1
    while i <= #movers do
        local m = movers[i]
        if m.kind == "dog" then
            m.phase = m.phase + h
            if m.flee and m.flee > 0 then
                m.flee = m.flee - h
                m.x = m.x + m.vx * h
                if m.flee <= 0 then
                    m.flee = nil
                    m.vx = sign(m.vx) * 45
                end
            elseif m.sit > 0 then
                m.sit = m.sit - h
            else
                m.x = m.x + m.vx * h
                m.turn = m.turn - h
                if m.turn <= 0 then
                    m.turn = 1 + self:_rand() * 2.2
                    local r = self:_rand()
                    if r < 0.25 then
                        m.sit = 0.8 + self:_rand() * 1.2
                        if self:_rand() < 0.4 then self:_event("woof", m.x, m.y, "idle") end
                    elseif r < 0.6 then
                        m.vx = -m.vx
                    end
                end
            end
        else
            if m.fallen then
                m.fallen = m.fallen - h
                if m.fallen <= 0 then m.fallen = nil end
            else
                m.phase = m.phase + m.freq * h
                m.y = m.y + m.vy * h
                local nx = m.base + math_sin(m.phase) * m.amp
                m.lean = nx - m.x
                m.x = nx
            end
        end

        local far = m.y < self._cam_y - 420 or m.y > self._cam_y + CLIENT_H + 700
            or math_abs(m.x - (self._cam_x + CLIENT_W * 0.5)) > 900
        if far then
            self._ghost[m] = nil
            table.remove(movers, i)
        else
            i = i + 1
        end
    end

    if self._state == "ski" or self._state == "air" then
        local ahead = self._y + CLIENT_H
        if ahead > self._next_spawn then
            local metres = math_max(0, self._y) / PX_PER_M
            local d = clamp(metres / 3000, 0, 1)
            self._next_spawn = ahead + (700 - 480 * d) * (0.7 + self:_rand() * 0.6)
            if metres > 120 then self:_spawn_mover() end
            if d > 0.6 and self:_rand() < d - 0.5 then self:_spawn_mover() end
        end
    end
end

-- Yeti ------------------------------------------------------------------------------------------

function SkiFreeGame:_spawn_yeti()
    local side = self:_rand() < 0.5 and -1 or 1
    self._yeti = {
        x = self._x + side * (CLIENT_W * 0.5 + 50),
        y = self._y - 200,
        speed = YETI_V0,
        face = -side,
        phase = 0,
        chase_t = 0,
    }
    self:_event("yeti", self._yeti.x, self._yeti.y)
    self:_sound("yeti")
end

function SkiFreeGame:_step_yeti(h)
    local yeti = self._yeti
    if not yeti then
        if self._started and self:max_distance() >= YETI_METRES and (self._state == "ski" or self._state == "air" or self._state == "crash") then
            self:_spawn_yeti()
        end
        return
    end

    yeti.chase_t = yeti.chase_t + h
    yeti.speed = math_min(YETI_VMAX, yeti.speed + YETI_ACCEL * h)
    local dx, dy = self._x - yeti.x, self._y - yeti.y
    local dist = math_sqrt(dx * dx + dy * dy)
    if dist > YETI_LEASH then
        yeti.x = self._x - dx / dist * (YETI_LEASH - 50)
        yeti.y = self._y - dy / dist * (YETI_LEASH - 50)
        dx, dy = self._x - yeti.x, self._y - yeti.y
        dist = YETI_LEASH - 50
    end
    if dist > 0.001 then
        local step = math_min(dist, yeti.speed * h)
        yeti.x = yeti.x + dx / dist * step
        yeti.y = yeti.y + dy / dist * step
        if math_abs(dx) > 2 then yeti.face = dx < 0 and -1 or 1 end
    end
    yeti.phase = yeti.phase + h * (yeti.speed / 60)

    if dist < YETI_REACH + 1 and self._z < 22 then
        self:_eaten()
    end
end

function SkiFreeGame:_eaten()
    local yeti = self._yeti
    self._state = "eaten"
    self._eat_t = 0
    self._eat_stage = 0
    self._trick = nil
    self._speed = 0
    self._z, self._vz = 0, 0
    yeti.x = self._x - yeti.face * 6
    yeti.y = self._y + 1
    self:_event("caught", self._x, self._y)
    self:_sound("lose")
    self:_save_best()
end

local CHOMPS = { 0.85, 1.35, 1.85 }

function SkiFreeGame:_step_eaten(h)
    self._eat_t = self._eat_t + h
    local stage = self._eat_stage
    if stage < #CHOMPS and self._eat_t >= CHOMPS[stage + 1] then
        self._eat_stage = stage + 1
        self:_event("chomp", self._x, self._y, self._eat_stage)
    end
    if self._state == "eaten" and self._eat_t >= EAT_TIME then
        self._state = "over"
        self:_event("over", self._x, self._y)
        self:_open_over_dialog()
    end
end

-- Slalom -----------------------------------------------------------------------------------------

function SkiFreeGame:_step_slalom(prev_y)
    local y, x = self._y, self._x
    local s = self._slalom

    if prev_y < SLALOM_START_Y and y >= SLALOM_START_Y and math_abs(x - SLALOM_X) < SLALOM_LANE then
        s.active = true
        s.next_gate = 1
        s.missed = 0
        s.passed = 0
        s.time = 0
        self._slalom_result = nil
        self:_event("slalom_start", x, y)
        return
    end
    if not s.active then return end

    if y < SLALOM_START_Y - 40 then
        s.active = false
        self:_event("slalom_abort", x, y)
        return
    end

    while s.next_gate <= SLALOM_GATES and y >= GATES[s.next_gate].y do
        local gate = GATES[s.next_gate]
        if prev_y < gate.y and math_abs(x - gate.x) < SLALOM_HALF then
            s.passed = s.passed + 1
            self:_event("gate", gate.x, gate.y, true)
        else
            s.missed = s.missed + 1
            self:_event("gate", gate.x, gate.y, false)
        end
        s.next_gate = s.next_gate + 1
    end

    if y >= SLALOM_FINISH_Y then
        s.active = false
        if math_abs(x - SLALOM_X) < SLALOM_LANE then
            local total = s.time + s.missed * SLALOM_PENALTY
            local record = not self._slalom_best or total < self._slalom_best
            self._slalom_result = { time = s.time, missed = s.missed, total = total, record = record, at = self._clock }
            if record then
                self._slalom_best = total
                self:_persist("skifree_slalom_best", math_floor(total * 100 + 0.5) / 100)
                self:_sound("win")
            end
            self:_event("slalom_finish", x, y, total)
        else
            self:_event("slalom_abort", x, y)
        end
    end
end

-- Update ------------------------------------------------------------------------------------------

function SkiFreeGame:_step(h)
    local state = self._state

    if state == "eaten" or state == "over" then
        self:_step_eaten(h)
        self:_step_movers(h)
        return
    end

    self:_steer_mouse()
    local prev_y = self._y

    if state == "crash" then
        self._crash_t = self._crash_t + h
        if self._crash_t >= CRASH_TIME then
            self._state = "ski"
            self._speed = 0
            self:_event("getup", self._x, self._y)
        end
    elseif state == "ski" then
        self:_step_ski(h)
        self:_collide()
    elseif state == "air" then
        self:_step_air(h)
        if self._state == "air" or self._state == "ski" then self:_collide() end
    end

    self:_refresh_ghosts()
    self:_step_slalom(prev_y)
    if self._slalom.active then self._slalom.time = self._slalom.time + h end
    if self._started then self._elapsed = self._elapsed + h end
    if self._y > self._max_y then self._max_y = self._y end

    local metres = self:max_distance()
    if not self._record_told and self._run_best > 0 and metres > self._run_best then
        self._record_told = true
        self:_event("record", self._x, self._y, self._run_best)
    end
    if metres >= (self._milestone + 1) * 250 then
        self._milestone = math_floor(metres / 250)
        self:_event("milestone", self._x, self._y, self._milestone * 250)
        self:_save_best()
    end

    self:_step_movers(h)
    self:_step_yeti(h)
    self:_step_camera(h)
end

function SkiFreeGame:_step_camera(h)
    local frac = clamp(self._speed / VTURBO, 0, 1)
    local target = ANCHOR_REST + (ANCHOR_FAST - ANCHOR_REST) * frac
    self._anchor = self._anchor + (target - self._anchor) * math_min(1, h * 1.5)
    -- Follow part of the jump height so big air stays on screen.
    self._cam_y = self._y - self._anchor - self._z * 0.6
    local tx = self._x - CLIENT_W * 0.5
    self._cam_x = self._cam_x + (tx - self._cam_x) * math_min(1, h * 5)
end

function SkiFreeGame:update(dt)
    dt = clamp(dt or 0, 0, 0.1)
    self._time = self._time + dt

    local frozen = self._paused or self._shell:is_modal()
    if frozen then
        if self._state == "eaten" or self._state == "over" then self:_step_eaten(dt) end
        return
    end

    local n = math_max(1, math_ceil(dt / STEP - 0.001))
    local h = dt / n
    for _ = 1, n do
        self._clock = self._clock + h
        self:_step(h)
    end

    if self._spray > 0.04 then
        self:_event("spray", self._x, self._y, math_min(3, self._spray))
    end
    self._spray = 0
    self:_evict_chunks()
end

-- Input -----------------------------------------------------------------------------------------

local SHELL_KEYS = { left = true, right = true, up = true, down = true, confirm = true, menu = true }
local PLAY_KEYS = { left = true, right = true, up = true, down = true, confirm = true, alt = true }

function SkiFreeGame:key_press(key, is_repeat)
    if SHELL_KEYS[key] and self._shell:key(key) then return end

    if key == "new" then
        local dialog = self._shell:dialog()
        if dialog and dialog.kind ~= "over" then return end
        self:new_game()
        return
    end

    if self._shell:is_modal() then return end
    if not PLAY_KEYS[key] then return end

    self._steer = "keys"
    if self._paused then
        if is_repeat then return end
        self:set_paused(false)
    end

    local state = self._state
    if state == "over" then
        if key == "confirm" and not is_repeat then self:new_game() end
        return
    end
    if state == "eaten" then return end
    if state == "air" and is_repeat and (key == "up" or key == "down" or key == "confirm") then return end

    if key == "left" then
        self:_turn(-1)
    elseif key == "right" then
        self:_turn(1)
    elseif key == "down" then
        if state == "air" then self:_do_trick(-1) else self:_point_down() end
    elseif key == "up" then
        self:_up_press()
    elseif key == "confirm" then
        self:jump()
    elseif key == "alt" then
        if not is_repeat and state ~= "crash" then
            self._turbo_toggle = not self._turbo_toggle
            self:_event(self._turbo_toggle and "turbo_on" or "turbo_off", self._x, self._y)
        end
    end
end

function SkiFreeGame:key_hold(key, held)
    self._held[key] = held and true or false
    if held and (key == "left" or key == "right" or key == "up" or key == "down") then
        self._steer = "keys"
    end
end

function SkiFreeGame:pointer_input(x, y, input)
    local moved = self._pointer_seen and math_abs(x - self._px) + math_abs(y - self._py) > 0.5
    self._pointer_seen = true
    self._px, self._py = x, y

    if self._shell:pointer(x, y, input) then
        self._pointer_in_client = false
        return
    end

    local in_client = Win95.inside(self._shell:layout().client, x, y)
    self._pointer_in_client = in_client
    if not in_client then return end
    if moved then self._steer = "mouse" end

    if input.left_pressed then
        if self._paused then
            self:set_paused(false)
        elseif self._state == "over" then
            self:new_game()
        else
            self._steer = "mouse"
            self:jump()
        end
    end
end

function SkiFreeGame:ui_back()
    if self._shell:ui_back() then return true end
    if self._paused then
        self:set_paused(false)
        return true
    end
    return false
end

function SkiFreeGame:consume_close_request()
    local requested = self._shell:consume_close_request() or self._close_requested
    self._close_requested = false
    return requested
end

function SkiFreeGame:is_game_over() return false end

local function format_time(seconds)
    local total = math_floor(seconds * 100 + 0.5)
    local cs = total % 100
    local s = math_floor(total / 100) % 60
    local m = math_floor(total / 6000)
    return string.format("%d:%02d.%02d", m, s, cs)
end
SkiFreeGame.format_time = format_time

function SkiFreeGame:summary()
    self:_save_best()
    local line = string.format("[SkiFree] Distance: %d m  Style: %d  Time: %s  Best: %d m",
        math_floor(self:distance()), self._style, format_time(self._elapsed), self._best)
    if self._state == "eaten" or self._state == "over" then line = line .. "  (eaten by the Yeti)" end
    return line
end

-- Queries for the renderer and tests --------------------------------------------------------

function SkiFreeGame:shell() return self._shell end
function SkiFreeGame:layout() return self._shell:layout() end
function SkiFreeGame:time() return self._time end
function SkiFreeGame:clock() return self._clock end
function SkiFreeGame:state() return self._state end
function SkiFreeGame:is_paused() return self._paused end
function SkiFreeGame:elapsed() return self._elapsed end
function SkiFreeGame:started() return self._started end
function SkiFreeGame:style() return self._style end
function SkiFreeGame:pending_style() return self._pending end
function SkiFreeGame:best() return self._best end
function SkiFreeGame:new_best() return math_floor(self:max_distance()) > self._run_best end
function SkiFreeGame:slalom_best() return self._slalom_best end
function SkiFreeGame:speed() return self._speed end
function SkiFreeGame:speed_ms() return self._speed / PX_PER_M end
function SkiFreeGame:distance() return math_max(0, self._y) / PX_PER_M end
function SkiFreeGame:max_distance() return math_max(0, self._max_y) / PX_PER_M end
function SkiFreeGame:camera() return self._cam_x, self._cam_y end
function SkiFreeGame:client_size() return CLIENT_W, CLIENT_H end
function SkiFreeGame:px_per_m() return PX_PER_M end
function SkiFreeGame:position() return self._x, self._y, self._z end
function SkiFreeGame:dir() return self._dir end
function SkiFreeGame:turbo() return (self._turbo_toggle or self._held.fast) and true or false end
function SkiFreeGame:walking() return self._walking end
function SkiFreeGame:walk_phase() return self._walk_phase end
function SkiFreeGame:crash_phase() return self._crash_t, CRASH_TIME, GETUP_TIME end
function SkiFreeGame:jump_kind() return self._jump_kind end
function SkiFreeGame:trick() return self._trick, self._trick and self._trick_t / TRICKS[self._trick].time or 0 end
function SkiFreeGame:tricks() return TRICKS end
function SkiFreeGame:last_trick() return self._last_trick end
function SkiFreeGame:yeti() return self._yeti end
function SkiFreeGame:eat_time() return self._eat_t, EAT_TIME end
function SkiFreeGame:movers() return self._movers end
function SkiFreeGame:slalom() return self._slalom, self._slalom_result end
function SkiFreeGame:slalom_gates() return GATES, SLALOM_GATES end
function SkiFreeGame:banners() return BANNERS end
function SkiFreeGame:steer_mode() return self._steer end
function SkiFreeGame:kinds() return KINDS end
function SkiFreeGame:yeti_metres() return YETI_METRES end
function SkiFreeGame:lift_near(x) return lift_near(x) end
function SkiFreeGame:lift_constants() return LIFT_X, LIFT_SPACING, POLE_GAP, POLE_OFFSET end
function SkiFreeGame:max_speed() return VMAX, VTURBO end
function SkiFreeGame:direction_angle(d) return DIR_ANGLE[d or self._dir] end

function SkiFreeGame:skier_screen()
    local client = self._shell:layout().client
    return client.x + (self._x - self._cam_x), client.y + (self._y - self._cam_y)
end

-- Fills out with every object (static and moving) whose sprite may be inside the view.
function SkiFreeGame:collect_visible(out)
    local n = 0
    local x0, x1 = self._cam_x - 40, self._cam_x + CLIENT_W + 40
    local y0, y1 = self._cam_y - 12, self._cam_y + CLIENT_H + 80
    for cx = math_floor(x0 / CHUNK), math_floor(x1 / CHUNK) do
        for cy = math_floor(y0 / CHUNK), math_floor(y1 / CHUNK) do
            local list = self:_chunk(cx, cy)
            for i = 1, #list do
                local o = list[i]
                if o.x > x0 and o.x < x1 and o.y > y0 and o.y < y1 then
                    n = n + 1
                    out[n] = o
                end
            end
        end
    end
    local movers = self._movers
    for i = 1, #movers do
        local m = movers[i]
        if m.x > x0 and m.x < x1 and m.y > y0 and m.y < y1 then
            n = n + 1
            out[n] = m
        end
    end
    for i = n + 1, #out do out[i] = nil end
    return n
end

return SkiFreeGame
