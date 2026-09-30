local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local PATH = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/"
local AuspexFrame = mod:io_dofile(PATH .. "MourningstarWaitingGames_auspex_frame")
local Gfx = mod:io_dofile(PATH .. "MourningstarWaitingGames_canvas")
local Win95 = mod:io_dofile(PATH .. "MourningstarWaitingGames_win95")
local D3 = mod:io_dofile(PATH .. "BattleChess_3d")
local Figures = mod:io_dofile(PATH .. "BattleChess_figures")
local Board2D = mod:io_dofile(PATH .. "BattleChess_board2d")

local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_random = math.random
local math_sin = math.sin
local math_sqrt = math.sqrt

local RENDER_SIZE = 600
local TEXT_POOL = 100
local TEXT_PREFIX = "bc_text_"
local TAU = math_pi * 2
local SCENE_LAYER = 4
local FX_LAYER = 4.5
local HUD_LAYER = 5.5
local MAX_PARTICLES = 260

local C = {
    white = { 255, 255, 255, 255 },
    black = { 255, 0, 0, 0 },
    gold = { 255, 255, 206, 90 },
    spark = { 255, 255, 236, 170 },
    fire = { 255, 255, 150, 40 },
    red = { 255, 255, 60, 40 },
    blood_free = { 255, 255, 220, 120 },
    blue = { 255, 120, 200, 255 },
    magic_w = { 255, 140, 220, 255 },
    magic_b = { 255, 255, 110, 60 },
    dust = { 255, 150, 130, 110 },
    ash = { 255, 40, 34, 32 },
    star = { 255, 255, 236, 80 },
    sparkle = { 255, 255, 250, 210 },
    text_black = Win95.C.text_black,
    text_red = { 255, 190, 0, 0 },
    label = { 255, 236, 206, 140 },
    bar = { 255, 8, 6, 8 },
    banner = { 255, 255, 232, 170 },
    banner_shadow = { 255, 40, 10, 0 },
    hall_top = { 255, 10, 8, 12 },
    hall_bottom = { 255, 44, 30, 26 },
    icon_ivory = { 255, 238, 228, 200 },
    icon_blue = { 255, 40, 80, 190 },
    icon_dark = { 255, 30, 26, 30 },
    stone_bits = { 255, 150, 140, 120 },
}

local HINT = "Click select/move  Right-drag rotate  WASD cursor  Space select  E view  1/2 zoom  Q undo  R new  Tab menu"
local HINT_2D = "Click or drag pieces   WASD cursor   Space select   3 flip board   Q undo   R new   Tab menu   View: 3D/2D"
local HOW_TO = {
    "Chess with a temper: whenever a piece captures, the two",
    "fighters battle it out right there on the board.",
    "You play White against the computer (see Options).",
    "",
    "Mouse: click one of your pieces, then a glowing square.",
    "Right-drag or middle-drag rotates the camera.",
    "Keys: WASD / arrows move the cursor, Space selects and",
    "moves, Shift + WASD rotates the camera, E cycles views,",
    "1 / 2 zoom, 3 turns the board, 4 resets the camera.",
    "Q takes back your last move, R starts a new game.",
    "Click or press Space during a battle to skip it; turn",
    "battles off under Options > Battle Animations.",
    "View > 2D Board shows a classic flat board instead.",
}
local CRT_OPTS = {
    tint = { 255, 255, 230, 190 }, scan_alpha = 12, sweep_alpha = 8, vignette_depth = 60, vignette_alpha = 110,
    noise_count = 6, noise_alpha = 22, flicker = false,
}
local SHOUTS = {
    p = "POKE!", n = "SLASH!", b = "BONK!", r = "SMASH!", q = "ZAP!", k = "CLANG!",
}

local scenegraph = {
    screen = table.clone(UIWorkspaceSettings.screen),
    overlay_panel = {
        horizontal_alignment = "center", parent = "screen", vertical_alignment = "center",
        size = { RENDER_SIZE, RENDER_SIZE }, position = { 0, 0, 25 },
    },
    scanner_base = {
        horizontal_alignment = "center", parent = "overlay_panel", vertical_alignment = "center",
        size = { RENDER_SIZE, RENDER_SIZE }, position = { 0, 0, 5 },
    },
    center_pivot = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 0, 0 }, position = { 0, 0, 1 },
    },
}

local widget_definitions = {
    backdrop = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 255, 0, 0, 0 } } },
    }, "scanner_base", nil, { RENDER_SIZE, RENDER_SIZE }),
}

Win95.add_text_widgets(UIWidget, widget_definitions, TEXT_PREFIX, TEXT_POOL, RENDER_SIZE)

AuspexFrame.add(widget_definitions, {
    render_size = RENDER_SIZE,
    outline_size = { 620, 620 },
    backdrop_alpha = 250,
    alpha = 150,
})

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }

local BattleChessView = class("BattleChessView", "BaseView")

-- Icon: an ivory chess knight on a blue base.
local ICON_NECK = { -3.5, 5.2, 3.2, 5.2, 1.6, -1.2, -2.6, -3.4 }
local ICON_HEAD = { -2.6, -3.4, 0.8, -5.6, 4.0, -3.2, 5.6, 0.1, 4.7, 1.7, 1.6, -1.2 }
local ICON_EAR = { 0.0, -5.0, 1.0, -7.2, 1.9, -4.9 }
local icon_pts = {}

local function icon_poly(canvas, pts, count, cx, cy, s, layer, color, ox, oy)
    for i = 1, count * 2, 2 do
        icon_pts[i] = cx + (pts[i] + (ox or 0)) * s
        icon_pts[i + 1] = cy + (pts[i + 1] + (oy or 0)) * s
    end
    canvas:poly(icon_pts, count, layer, color)
end

local function draw_icon(canvas, cx, cy, size, layer)
    local s = size / 15
    for _, o in ipairs({ { -0.7, 0 }, { 0.7, 0 }, { 0, -0.7 }, { 0, 0.7 } }) do
        icon_poly(canvas, ICON_NECK, 4, cx, cy, s, layer, C.icon_dark, o[1], o[2])
        icon_poly(canvas, ICON_HEAD, 6, cx, cy, s, layer, C.icon_dark, o[1], o[2])
        icon_poly(canvas, ICON_EAR, 3, cx, cy, s, layer, C.icon_dark, o[1], o[2])
    end
    icon_poly(canvas, ICON_NECK, 4, cx, cy, s, layer + 0.1, C.icon_ivory)
    icon_poly(canvas, ICON_HEAD, 6, cx, cy, s, layer + 0.1, C.icon_ivory)
    icon_poly(canvas, ICON_EAR, 3, cx, cy, s, layer + 0.1, C.icon_ivory)
    canvas:rect(cx - 5.5 * s, cy + 4.6 * s, 11 * s, 2.6 * s, layer + 0.2, C.icon_blue)
    canvas:rect(cx + 1.8 * s, cy - 3.2 * s, 1.1 * s, 1.1 * s, layer + 0.2, C.icon_dark)
end

local DESKTOP_OPTS = { app = "Battle Chess", icon = draw_icon, clock = "" }
local WINDOW_OPTS = { title = "Battle Chess", icon = draw_icon }

-- Static scenery -----------------------------------------------------------------------------------------------

local HALL_PAL = {
    { 70, 58, 52 }, { 56, 47, 44 }, { 74, 60, 52, 0.02 }, { 104, 90, 80, 0.05 }, { 70, 90, 150, 0, true },
    { 44, 72, 170, 0.1 }, { 170, 28, 34, 0.1 }, { 210, 160, 60, 0.4 }, { 60, 44, 32, 0.2 }, { 255, 170, 60, 0, true },
    { 255, 236, 150, 0, true }, { 116, 100, 88, 0.05 }, { 90, 60, 40, 0.1 }, { 204, 160, 70, 0.6 }, { 88, 76, 68, 0.03 },
    { 62, 53, 48 }, { 120, 24, 30, 0.05 }, { 196, 150, 60, 0.3 }, { 70, 64, 60, 0.3 },
}
local FLOOR_A, FLOOR_B, WALL, PILLAR, WINDOW, BANNER_W, BANNER_B, BANNER_TRIM, BRACKET, FLAME, FLAME_CORE, STONE, WOOD, INLAY, PED, PED_DARK =
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16
local CARPET, CARPET_TRIM, IRON = 17, 18, 19
local FLOOR_Y = -1.3
local PILLAR_R = 12.5

local function build_hall()
    local floor = D3.mesh()
    local T = 5
    for i = -5, 4 do
        for j = -5, 4 do
            local mat = (i + j) % 2 == 0 and FLOOR_A or FLOOR_B
            local a = floor:vert(i * T, FLOOR_Y, j * T)
            local b = floor:vert(i * T + T, FLOOR_Y, j * T)
            local c = floor:vert(i * T + T, FLOOR_Y, j * T + T)
            local d = floor:vert(i * T, FLOOR_Y, j * T + T)
            floor:quad(a, b, c, d, mat, 0, 1, 0)
        end
    end
    -- a carpet runner out from each side of the pedestal
    local y = FLOOR_Y + 0.01
    for side = 0, 3 do
        local a = side * math_pi * 0.5
        local dx, dz = math_sin(a), -math_cos(a)
        local tx, tz = math_cos(a), math_sin(a)
        local function strip(w0, w1, r0, r1, mat, yy)
            floor:flat({ dx * r0 + tx * w0, yy, dz * r0 + tz * w0, dx * r0 + tx * w1, yy, dz * r0 + tz * w1,
                dx * r1 + tx * w1, yy, dz * r1 + tz * w1, dx * r1 + tx * w0, yy, dz * r1 + tz * w0 }, mat)
        end
        strip(-1.5, 1.5, 4.8, 16, CARPET, y)
        strip(-1.5, -1.3, 4.8, 16, CARPET_TRIM, y + 0.005)
        strip(1.3, 1.5, 4.8, 16, CARPET_TRIM, y + 0.005)
    end

    local walls = D3.mesh()
    local R = 19
    for i = 0, 7 do
        local a0, a1 = (i - 0.5) / 8 * TAU, (i + 0.5) / 8 * TAU
        local x0, z0, x1, z1 = math_cos(a0) * R, math_sin(a0) * R, math_cos(a1) * R, math_sin(a1) * R
        local ac = i / 8 * TAU
        local nx, nz = -math_cos(ac), -math_sin(ac)
        local v1, v2 = walls:vert(x0, FLOOR_Y, z0), walls:vert(x1, FLOOR_Y, z1)
        local v3, v4 = walls:vert(x1, 16, z1), walls:vert(x0, 16, z0)
        walls:quad(v1, v2, v3, v4, WALL, nx, 0, nz)
        local cx, cz = math_cos(ac) * (R * 0.92 - 0.1), math_sin(ac) * (R * 0.92 - 0.1)
        local tx, tz = -nz, nx
        local w = 1.4
        walls:flat({ cx - tx * w, 2.0, cz - tz * w, cx + tx * w, 2.0, cz + tz * w, cx + tx * w, 7.5, cz + tz * w, cx, 9.3, cz, cx - tx * w, 7.5, cz - tz * w }, WINDOW)
    end

    local pillars = {}
    local torches = {}
    for i = 0, 7 do
        local a = (i + 0.5) / 8 * TAU
        local m = D3.mesh()
        local px, pz = math_cos(a) * PILLAR_R, math_sin(a) * PILLAR_R
        m:box(px - 0.9, FLOOR_Y, pz - 0.9, px + 0.9, FLOOR_Y + 0.7, pz + 0.9, STONE, true)
        m:lathe(px, pz, { 0.62, FLOOR_Y + 0.7, 0.55, 10 }, 6, PILLAR, false, false, a)
        m:box(px - 0.85, 10, pz - 0.85, px + 0.85, 10.6, pz + 0.85, STONE, false)
        local nx, nz = -math_cos(a), -math_sin(a)
        local tx, tz = -nz, nx
        local bx, bz = px + nx * 0.64, pz + nz * 0.64
        local mat = pz < 0 and BANNER_W or BANNER_B
        local w = 0.55
        m:flat({ bx - tx * w, 8.4, bz - tz * w, bx + tx * w, 8.4, bz + tz * w, bx + tx * w, 4.4, bz + tz * w, bx, 3.7, bz, bx - tx * w, 4.4, bz - tz * w }, mat)
        local ex, ez = bx + nx * 0.03, bz + nz * 0.03
        m:flat({ ex, 7.5, ez, ex + tx * 0.26, 6.8, ez + tz * 0.26, ex, 6.1, ez, ex - tx * 0.26, 6.8, ez - tz * 0.26 }, BANNER_TRIM)
        m:flat({ bx - tx * w, 8.4, bz - tz * w, bx + tx * w, 8.4, bz + tz * w, bx + tx * w * 1.1, 8.7, bz + tz * w * 1.1, bx - tx * w * 1.1, 8.7, bz - tz * w * 1.1 }, BANNER_TRIM)
        local hx, hz = px + nx * 0.78, pz + nz * 0.78
        m:box(hx - 0.09, 1.9, hz - 0.09, hx + 0.09, 2.45, hz + 0.09, BRACKET, false)
        pillars[#pillars + 1] = { mesh = m, cos = math_cos(a), sin = math_sin(a) }
        torches[#torches + 1] = { x = hx, y = 2.65, z = hz, phase = i * 1.7, pillar = #pillars, size = 0.2, glow = 2.0 }
    end
    -- braziers at the pedestal's corners
    local braziers = D3.mesh()
    for i = 0, 3 do
        local a = (i + 0.5) / 4 * TAU
        local bx, bz = math_cos(a) * 8.6, math_sin(a) * 8.6
        braziers:lathe(bx, bz, { 0.34, FLOOR_Y, 0.14, FLOOR_Y + 0.25, 0.09, -0.35, 0.16, -0.25, 0.46, 0.05, 0.4, 0.12 }, 6, IRON, false, true, 0)
        torches[#torches + 1] = { x = bx, y = 0.22, z = bz, phase = i * 2.3 + 0.5, size = 0.34, glow = 2.6, pool = true }
    end

    local ped = D3.mesh()
    local E, S = 4.6, 4.0
    -- slab sides and bevel below it
    ped:frustum(0, 0, -0.3, E * 2, E * 2, 0, E * 2, E * 2, WOOD, true, 0, 0, WOOD)
    ped:frustum(0, 0, -0.52, 8.2, 8.2, -0.3, E * 2 - 0.1, E * 2 - 0.1, PED, true, 0, 0, PED)
    ped:frustum(0, 0, -1.02, 7.0, 7.0, -0.52, 7.0, 7.0, PED_DARK, true, 0, 0, PED)
    ped:frustum(0, 0, FLOOR_Y, 9.8, 9.8, -1.02, 8.8, 8.8, PED, true, 0, 0, PED)
    -- carved panels on the waist
    for side = 0, 3 do
        local a = side * math_pi * 0.5
        local nx, nz = math_sin(a), -math_cos(a)
        local tx, tz = math_cos(a), math_sin(a)
        for k = -1, 1 do
            local cx, cz = nx * 3.52 + tx * k * 2.1, nz * 3.52 + tz * k * 2.1
            ped:flat({ cx - tx * 0.8, -0.62, cz - tz * 0.8, cx + tx * 0.8, -0.62, cz + tz * 0.8, cx + tx * 0.8, -0.92, cz + tz * 0.8, cx - tx * 0.8, -0.92, cz - tz * 0.8 }, STONE)
        end
    end
    -- gold inlay around the playing area
    local g, h = S + 0.08, S + 0.16
    ped:flat({ -h, 0.002, -h, h, 0.002, -h, g, 0.002, -g, -g, 0.002, -g }, INLAY)
    ped:flat({ h, 0.002, -h, h, 0.002, h, g, 0.002, g, g, 0.002, -g }, INLAY)
    ped:flat({ h, 0.002, h, -h, 0.002, h, -g, 0.002, g, g, 0.002, g }, INLAY)
    ped:flat({ -h, 0.002, h, -h, 0.002, -h, -g, 0.002, -g, -g, 0.002, g }, INLAY)

    local board = D3.mesh()
    local board_pal = {}
    for sq = 0, 63 do
        local f, r = sq % 8, math_floor(sq / 8)
        local light = (f + r) % 2 == 1
        local v = 0.94 + ((f * 7 + r * 13) % 5) * 0.03
        local base = light and { 198, 180, 146 } or { 96, 76, 62 }
        board_pal[sq + 1] = { base[1] * v, base[2] * v, base[3] * v, light and 0.12 or 0.06 }
        local x0, z0 = f - 4, r - 4
        local a = board:vert(x0, 0, z0)
        local b = board:vert(x0 + 1, 0, z0)
        local c = board:vert(x0 + 1, 0, z0 + 1)
        local d = board:vert(x0, 0, z0 + 1)
        board:quad(a, b, c, d, sq + 1, 0, 1, 0)
    end
    return { floor = floor, walls = walls, pillars = pillars, braziers = braziers, torches = torches, ped = ped, board = board, board_pal = board_pal }
end

local SCENE
local TINT_SELECT, TINT_CHECK, TINT_HOVER = { 255, 230, 140 }, { 255, 40, 30 }, { 255, 255, 255 }

-- View ------------------------------------------------------------------------------------------------------------

function BattleChessView:init(settings, context)
    BattleChessView.super.init(self, definitions, settings, context)

    self._game = context.game
    self._no_cursor = false
    self._flat = Board2D.new()
    self._canvas = Gfx.Canvas.new(RENDER_SIZE, RENDER_SIZE, 14000)
    self._canvas:set_layer_scale(10)
    self._text = Win95.text_pool(self, TEXT_PREFIX, TEXT_POOL)
    self._renderer = D3.renderer()
    self._shaker = Gfx.Shaker.new()
    self._time = 0
    self._poses = setmetatable({}, { __mode = "k" })
    self._particles = {}
    self._pcount = 0
    for i = 1, MAX_PARTICLES do self._particles[i] = {} end
    self._flashes = {}
    self._shouts = {}
    self._bolt = nil
    self._bars = 0
    self._banner = nil
    self._banner_t = 0
    self._preview_cam = D3.camera()
    self._preview_actor = { kind = "q", side = "w", x = 0, y = 0, z = 0, yaw = 0, anim = "idle", anim_t = 0, id = 3 }
    self._preview_pose = Figures.new_pose()
    self._stats = { tris = 0, ms = 0 }
    self._ident = D3.mat()
    self._flame_m = D3.mat()
    self._pillar_fade = {}
    self._dialog_cb = function(c, D, dialog, pool, tt) self:_dialog_content(c, D, dialog, pool, tt) end
    self._event_cb = function(ev) self:_on_event(ev) end
    if not SCENE then SCENE = build_hall() end
end

function BattleChessView:dialogue_system() return nil end
function BattleChessView:is_using_input() return false end

function BattleChessView:update(dt, t, input_service)
    if self._game then self._game:update(dt) end
    return BattleChessView.super.update(self, dt, t, input_service)
end

-- Input -------------------------------------------------------------------------------------------------------------

local function input_value(input_service, action)
    if not input_service or not input_service.get then return false end
    local ok, value = pcall(input_service.get, input_service, action)
    if not ok then return false end
    return value == true or (type(value) == "number" and value > 0)
end

function BattleChessView:_process_pointer(input_service, ui_renderer, base)
    if not input_service or not input_service.get then return end

    local ok, cursor = pcall(input_service.get, input_service, "cursor")
    if not ok or not cursor then return end

    local inverse = ui_renderer.inverse_scale or 1
    local x = cursor[1] * inverse - base[1]
    local y = cursor[2] * inverse - base[2]

    local input = self._pointer_state or {}
    self._pointer_state = input
    input.left = input_value(input_service, "left_hold")
    input.right = input_value(input_service, "right_hold")
    input.middle = input_value(input_service, "middle_hold")
    input.left_pressed = input_value(input_service, "left_pressed")
    input.right_pressed = input_value(input_service, "right_pressed")
    input.middle_pressed = input_value(input_service, "middle_pressed")
    input.left_released = input_value(input_service, "left_released")
    input.right_released = input_value(input_service, "right_released")
    input.middle_released = input_value(input_service, "middle_released")

    self._game:pointer_input(x, y, input)
end

-- World-space particles -------------------------------------------------------------------------------------------

function BattleChessView:_emit(x, y, z, vx, vy, vz, life, size, color, kind, gravity, drag)
    local n = self._pcount + 1
    if n > MAX_PARTICLES then
        n = math_random(1, MAX_PARTICLES)
    else
        self._pcount = n
    end
    local p = self._particles[n]
    p.x, p.y, p.z, p.vx, p.vy, p.vz = x, y, z, vx, vy, vz
    p.life, p.max, p.size, p.color, p.kind = life, life, size, color, kind
    p.gravity, p.drag = gravity or 0, drag or 1.5
    p.spin = (math_random() - 0.5) * 12
    p.angle = math_random() * TAU
    return p
end

function BattleChessView:_burst(x, y, z, count, speed_min, speed_max, life_min, life_max, size, color, kind, gravity, up, drag)
    for _ = 1, count do
        local a = math_random() * TAU
        local e = (math_random() - 0.3) * 1.4 + (up or 0)
        local s = speed_min + (speed_max - speed_min) * math_random()
        local ce = math_cos(e)
        self:_emit(x, y, z, math_cos(a) * ce * s, math_sin(e) * s, math_sin(a) * ce * s,
            life_min + (life_max - life_min) * math_random(), size * (0.6 + math_random() * 0.8), color, kind, gravity, drag)
    end
end

function BattleChessView:_update_particles(dt)
    local items = self._particles
    local i = 1
    while i <= self._pcount do
        local p = items[i]
        p.life = p.life - dt
        if p.life <= 0 then
            items[i] = items[self._pcount]
            items[self._pcount] = p
            self._pcount = self._pcount - 1
        else
            local damp = 1 / (1 + p.drag * dt)
            p.vx, p.vy, p.vz = p.vx * damp, p.vy * damp - p.gravity * dt, p.vz * damp
            p.x, p.y, p.z = p.x + p.vx * dt, p.y + p.vy * dt, p.z + p.vz * dt
            if p.y < 0.01 and p.gravity > 0 then
                p.y = 0.01
                p.vy = -p.vy * 0.3
                p.vx, p.vz = p.vx * 0.6, p.vz * 0.6
            end
            p.angle = p.angle + p.spin * dt
            i = i + 1
        end
    end
end

function BattleChessView:_draw_particles(canvas, cam)
    local items = self._particles
    local F = cam.F
    for i = 1, self._pcount do
        local p = items[i]
        local sx, sy, d = cam:project(p.x, p.y, p.z)
        if sx then
            local k = p.life / p.max
            local color = p.color
            local alpha = color[1] * k
            local size = p.size * F / d
            local kind = p.kind
            if kind == "spark" then
                local tx, ty = cam:project(p.x - p.vx * 0.05, p.y - p.vy * 0.05, p.z - p.vz * 0.05)
                if tx then
                    canvas:line(tx, ty, sx, sy, size * 2.2 + 0.8, FX_LAYER - 0.01, color, alpha * 0.3)
                    canvas:line(tx, ty, sx, sy, size * 0.8 + 0.6, FX_LAYER, color, alpha, 1, 0.4 * k)
                end
            elseif kind == "ember" or kind == "sparkle" then
                local s = size * (0.4 + 0.6 * k)
                canvas:circle(sx, sy, s * 2.6, FX_LAYER - 0.01, color, alpha * 0.25, 1, 0, 8)
                if kind == "sparkle" then
                    local tw = s * (1.6 + math_sin(p.angle * 3) * 0.8)
                    canvas:rect(sx - tw, sy - 0.6, tw * 2, 1.2, FX_LAYER + 0.02, color, alpha, 1, 0.6)
                    canvas:rect(sx - 0.6, sy - tw, 1.2, tw * 2, FX_LAYER + 0.02, color, alpha, 1, 0.6)
                else
                    canvas:rect(sx - s * 0.5, sy - s * 0.5, s, s, FX_LAYER + 0.01, color, alpha, 1, 0.4 * k)
                end
            elseif kind == "chunk" or kind == "ash" then
                local s = size * (0.6 + 0.4 * k)
                local c, sn = math_cos(p.angle) * s, math_sin(p.angle) * s
                canvas:quad(sx + c, sy + sn, sx - sn, sy + c, sx - c, sy - sn, sx + sn, sy - c, FX_LAYER, color, alpha)
            elseif kind == "smoke" then
                local s = size * (1.8 - k * 0.8)
                canvas:circle(sx, sy, s, FX_LAYER - 0.02, color, alpha * 0.35, 1, 0, 12)
            elseif kind == "star" then
                self:_star(canvas, sx, sy, size * 1.4, p.angle, color, alpha)
            else
                canvas:rect(sx - size * 0.5, sy - size * 0.5, size, size, FX_LAYER, color, alpha)
            end
        end
    end
end

local star_pts = {}
function BattleChessView:_star(canvas, x, y, r, angle, color, alpha)
    for i = 0, 9 do
        local rr = i % 2 == 0 and r or r * 0.45
        local a = angle + i / 10 * TAU
        star_pts[i * 2 + 1] = x + math_cos(a) * rr
        star_pts[i * 2 + 2] = y + math_sin(a) * rr
    end
    for i = 0, 4 do
        local j = i * 2
        local k = (j + 2) % 10
        canvas:tri_raw(x, y, star_pts[j * 2 + 1], star_pts[j * 2 + 2], star_pts[j * 2 + 3], star_pts[j * 2 + 4], FX_LAYER + 0.03, alpha, color[2], color[3], color[4])
        canvas:tri_raw(x, y, star_pts[j * 2 + 3], star_pts[j * 2 + 4], star_pts[k * 2 + 1], star_pts[k * 2 + 2], FX_LAYER + 0.03, alpha, color[2], color[3], color[4])
    end
end

function BattleChessView:_flash(x, y, z, radius, life, color)
    local f = self._flashes
    f[#f + 1] = { x = x, y = y, z = z, r = radius, life = life, max = life, color = color, ring = false }
end

function BattleChessView:_ring(x, z, radius, life, color)
    local f = self._flashes
    f[#f + 1] = { x = x, y = 0.02, z = z, r = radius, life = life, max = life, color = color, ring = true }
end

function BattleChessView:_shout(text, x, y, z, color)
    local s = self._shouts
    s[#s + 1] = { text = text, x = x, y = y, z = z, t = 0, color = color or C.banner }
    if #s > 4 then table.remove(s, 1) end
end

-- Events -------------------------------------------------------------------------------------------------------------

local function magic_color(side) return side == "w" and C.magic_w or C.magic_b end

function BattleChessView:_handle_events()
    self._game:drain_events(self._event_cb)
end

function BattleChessView:_on_event(ev)
    local game = self._game
    self._flat:event(ev, game)
    do
        local kind = ev.kind
        if kind == "new" then
            self._pcount = 0
            self._flashes = {}
            self._shouts = {}
            self._banner, self._banner_t = "New Game", 1.6
        elseif kind == "hit" then
            local style, att, vic, side = ev.s:match("^(%a+):(%a):(%a):(%a)$")
            local x, y, z = ev.a, ev.b, ev.c
            self:_shout(SHOUTS[att] or "HIT!", x, y + 0.55, z)
            if att == "r" then
                self._shaker:add(0.75)
                self:_burst(x, 0.1, z, 26, 0.8, 2.6, 0.5, 1.1, 0.07, C.dust, "smoke", 0, 0.2, 2.5)
                self:_ring(x, z, 1.4, 0.55, C.spark)
            elseif att == "q" then
                self._shaker:add(0.35)
                self:_flash(x, y, z, 0.9, 0.35, magic_color(side))
                self:_burst(x, y, z, 30, 0.8, 3.2, 0.3, 0.8, 0.02, magic_color(side), "spark", 1.5)
            elseif att == "b" then
                self._shaker:add(0.3)
                self:_burst(x, y + 0.35, z, 8, 0.5, 1.4, 0.5, 0.9, 0.05, C.star, "star", 2.5, 0.8)
            else
                self._shaker:add(att == "k" and 0.4 or 0.3)
                self:_burst(x, y + 0.1, z, 22, 1.0, 3.5, 0.2, 0.5, 0.012, C.spark, "spark", 3)
            end
            self:_flash(x, y + 0.1, z, 0.55, 0.22, C.spark)
            if style == "crumble" then
                self:_burst(x, 0.45, z, 16, 0.4, 1.6, 0.8, 1.4, 0.05, C.stone_bits, "chunk", 5, 0.6)
            end
        elseif kind == "bolt" then
            local color = magic_color(ev.s)
            self._bolt = { x1 = ev.a, y1 = ev.b, z1 = ev.c, x2 = ev.d, y2 = ev.e, z2 = ev.f, t = 0, color = color }
            self:_flash(ev.a, ev.b, ev.c, 0.45, 0.3, color)
        elseif kind == "charge" then
            for _ = 1, 14 do
                local a = math_random() * TAU
                local p = self:_emit(ev.a + math_cos(a) * 0.6, ev.b + (math_random() - 0.3) * 0.5, ev.c + math_sin(a) * 0.6, -math_cos(a) * 1.2, 0.2, -math_sin(a) * 1.2, 0.45, 0.02, C.magic_w, "sparkle", 0, 0)
                p.drag = 0
            end
        elseif kind == "stomp" then
            self._shaker:add(ev.d or 0.2)
            self:_burst(ev.a, 0.05, ev.c, 5, 0.3, 0.8, 0.4, 0.7, 0.05, C.dust, "smoke", 0, 0.1, 3)
        elseif kind == "land" then
            self._shaker:add(0.15)
            self:_burst(ev.a, 0.05, ev.c, 8, 0.4, 1.0, 0.4, 0.7, 0.05, C.dust, "smoke", 0, 0.1, 3)
        elseif kind == "poof" then
            self:_burst(ev.a, ev.b, ev.c, 18, 0.5, 1.8, 0.4, 0.8, 0.07, C.dust, "smoke", 0, 0.3, 2.5)
            self:_burst(ev.a, ev.b, ev.c, 12, 1, 2.5, 0.2, 0.4, 0.012, C.spark, "spark", 2)
            self._shaker:add(0.2)
        elseif kind == "promote_start" then
            self:_burst(ev.a, ev.b, ev.c, 16, 0.3, 1.2, 0.6, 1.1, 0.02, C.gold, "sparkle", -0.5, 0.6, 1)
        elseif kind == "promote" then
            self:_flash(ev.a, ev.b, ev.c, 1.0, 0.5, C.gold)
            self:_burst(ev.a, ev.b, ev.c, 26, 0.8, 2.4, 0.5, 1.0, 0.02, C.gold, "sparkle", 1, 0.5)
            self._banner, self._banner_t = "Promotion!", 1.4
        elseif kind == "mate" then
            self._shaker:add(0.5)
            self._banner, self._banner_t = "Checkmate!", 2.2
            self:_burst(ev.a, 0.1, ev.c, 20, 0.6, 1.8, 0.5, 1.0, 0.06, C.dust, "smoke", 0, 0.2, 2.5)
        elseif kind == "check" then
            local x, z = game.sq_xz(ev.a)
            self:_ring(x, z, 0.9, 0.6, C.red)
            self._banner, self._banner_t = "Check!", 1.2
        elseif kind == "select" then
            local x, z = game.sq_xz(ev.a)
            self:_ring(x, z, 0.55, 0.3, C.gold)
        elseif kind == "battle" then
            self._bars_on = true
        elseif kind == "undo" then
            self._banner, self._banner_t = "Move taken back", 1.2
        elseif kind == "skip" then
            self._bolt = nil
        end
    end
end

-- Continuous effects driven by the figures' animation state.
function BattleChessView:_ambient_effects(dt)
    local game = self._game
    local actors = game:actors()
    local rate = dt * 60
    for i = 1, #actors do
        local a = actors[i]
        if a.anim == "cheer" and math_random() < 0.08 * rate then
            self:_emit(a.x + (math_random() - 0.5) * 0.3, 1.1 + math_random() * 0.3, a.z + (math_random() - 0.5) * 0.3,
                (math_random() - 0.5) * 1.2, 1.2 + math_random(), (math_random() - 0.5) * 1.2, 0.9, 0.022, C.gold, "sparkle", 2.5, 1)
        end
        if a.anim == "die" then
            local t = a.anim_t
            local style = a.style
            if style == "sparkle" and math_random() < 0.6 * rate then
                self:_emit(a.x + (math_random() - 0.5) * 0.4, 0.3 + math_random() * 0.8 + t * 0.2, a.z + (math_random() - 0.5) * 0.4,
                    (math_random() - 0.5) * 0.5, 0.6, (math_random() - 0.5) * 0.5, 0.7, 0.022, C.sparkle, "sparkle", 0, 1)
            elseif style == "ash" and t > 0.3 and t < 1.5 and math_random() < 0.7 * rate then
                self:_emit(a.x + (math_random() - 0.5) * 0.35, 0.1 + math_random() * 0.7 * (1.6 - t), a.z + (math_random() - 0.5) * 0.35,
                    (math_random() - 0.5) * 0.3, 0.5 + math_random() * 0.5, (math_random() - 0.5) * 0.3, 0.9, 0.035, C.ash, "ash", -0.2, 1)
                if t < 0.9 and math_random() < 0.4 then
                    self:_emit(a.x, 0.5, a.z, (math_random() - 0.5) * 2, math_random() * 2, (math_random() - 0.5) * 2, 0.25, 0.012, magic_color(a.side == "w" and "b" or "w"), "spark", 0, 2)
                end
            elseif style == "crumble" and t > 0.15 and t < 0.9 and math_random() < 0.35 * rate then
                self:_emit(a.x + (math_random() - 0.5) * 0.6, 0.05, a.z + (math_random() - 0.5) * 0.6, 0, 0.3, 0, 0.8, 0.07, C.dust, "smoke", 0, 2)
            end
        end
    end
end

-- Scene --------------------------------------------------------------------------------------------------------------

function BattleChessView:_pose(actor)
    local pose = self._poses[actor]
    if not pose then
        pose = Figures.new_pose()
        self._poses[actor] = pose
    end
    return pose
end

local function frame_quads(R, x, z, inner, outer, y, a, r, g, b)
    local x0, x1, z0, z1 = x - outer, x + outer, z - outer, z + outer
    local i0, i1, j0, j1 = x - inner, x + inner, z - inner, z + inner
    R:quad(x0, y, z0, x1, y, z0, i1, y, j0, i0, y, j0, a, r, g, b)
    R:quad(x1, y, z0, x1, y, z1, i1, y, j1, i1, y, j0, a, r, g, b)
    R:quad(x1, y, z1, x0, y, z1, i0, y, j1, i1, y, j1, a, r, g, b)
    R:quad(x0, y, z1, x0, y, z0, i0, y, j0, i0, y, j1, a, r, g, b)
end

local function square_quad(R, sq, inset, y, a, r, g, b)
    local x, z = sq % 8 - 3.5, math_floor(sq / 8) - 3.5
    local h = 0.5 - inset
    R:quad(x - h, y, z - h, x + h, y, z - h, x + h, y, z + h, x - h, y, z + h, a, r, g, b)
end

function BattleChessView:_draw_markers(R, time)
    local game = self._game
    local pulse = 0.5 + 0.5 * math_sin(time * 5)
    local last = game:last_move()
    if last then
        square_quad(R, last.from, 0.02, 0.003, 60, 255, 190, 60)
        square_quad(R, last.to, 0.02, 0.003, 85, 255, 190, 60)
    end
    local check = game:check_square()
    if check then
        local x, z = game.sq_xz(check)
        R:disc(x, 0.004, z, 0.48, 0.48, 16, 90 + 70 * pulse, 255, 40, 30)
        R:disc(x, 0.005, z, 0.3, 0.3, 12, 80 + 60 * pulse, 255, 120, 60)
    end
    local sel = game:selected()
    if sel then
        local x, z = game.sq_xz(sel)
        square_quad(R, sel, 0.04, 0.004, 70 + 40 * pulse, 255, 210, 80)
        frame_quads(R, x, z, 0.4, 0.48, 0.005, 230, 255, 220, 90)
        local targets = game:targets()
        local pos = game:position()
        for to, move in pairs(targets) do
            local tx, tz = game.sq_xz(to)
            if move.captured then
                frame_quads(R, tx, tz, 0.36, 0.47, 0.005, 170 + 70 * pulse, 255, 60, 40)
                square_quad(R, to, 0.05, 0.004, 55, 255, 40, 20)
            else
                square_quad(R, to, 0.04, 0.004, 38 + 18 * pulse, 110, 255, 140)
                R:disc(tx, 0.005, tz, 0.24, 0.24, 14, 70, 120, 255, 140)
                R:disc(tx, 0.006, tz, 0.13, 0.13, 10, 170 + 70 * pulse, 190, 255, 190)
            end
        end
    end
    local hover = game:hover()
    if hover and hover ~= sel then
        local x, z = game.sq_xz(hover)
        frame_quads(R, x, z, 0.44, 0.49, 0.006, 150, 255, 255, 255)
    end
    local cursor, visible = game:cursor()
    if visible and cursor then
        local x, z = game.sq_xz(cursor)
        frame_quads(R, x, z, 0.38, 0.5, 0.007, 180 + 70 * pulse, 90, 200, 255)
    end
end

function BattleChessView:_draw_scene(canvas, client, time)
    local game = self._game
    local R = self._renderer
    local cam = game:camera()
    local stats = self._stats
    R:reset_stats()
    R:begin(cam, client.x, client.y, client.x + client.w, client.y + client.h)

    canvas:vgradient(client.x, client.y, client.w, client.h, 3.05, C.hall_top, C.hall_bottom, 255, 255, 16)

    -- hall: floor, then walls / pillars / torches back to front
    local ident = self._ident
    R:mesh(SCENE.floor, ident, HALL_PAL)
    R:flush(canvas, SCENE_LAYER, true)
    -- warm light pools under the braziers
    local torches = SCENE.torches
    for i = 1, #torches do
        local t = torches[i]
        if t.pool then
            local flick = 0.9 + 0.1 * math_sin(time * 11 + t.phase)
            R:disc(t.x, FLOOR_Y + 0.02, t.z, 3.2 * flick, 3.2 * flick, 14, 22, 255, 150, 60)
            R:disc(t.x, FLOOR_Y + 0.03, t.z, 1.8 * flick, 1.8 * flick, 12, 26, 255, 170, 80)
        end
    end
    R:flush(canvas, SCENE_LAYER, true)

    R:mesh(SCENE.walls, ident, HALL_PAL)
    R:mesh(SCENE.braziers, ident, HALL_PAL)
    -- pillars between the camera and the board fade away
    local cyaw = cam.yaw
    local cdx, cdz = math_sin(cyaw), -math_cos(cyaw)
    local pillars = SCENE.pillars
    local fade = self._pillar_fade
    for i = 1, #pillars do
        local p = pillars[i]
        local dot = p.cos * cdx + p.sin * cdz
        local a = 1 - D3.clamp((dot - 0.35) / 0.3, 0, 1)
        fade[i] = a
        if a > 0.02 then R:mesh(p.mesh, ident, HALL_PAL, 255 * a) end
    end
    local fm = self._flame_m
    local flame = self:_flame_mesh()
    for i = 1, #torches do
        local t = torches[i]
        local a = t.pillar and fade[t.pillar] or 1
        if a > 0.02 then
            local flick = 0.85 + 0.15 * math_sin(time * 13 + t.phase) * math_sin(time * 7.3 + t.phase * 2)
            R:glow(t.x, t.y + t.size * 0.6, t.z, t.glow * flick, 70 * a, 255, 150, 60, 3, 12, 0.3)
            D3.mat_set(fm, t.x, t.y, t.z, 0, time * 3 + t.phase, math_sin(time * 9 + t.phase) * 0.15, t.size, t.size * 1.9 * flick, t.size)
            R:mesh(flame, fm, HALL_PAL, 255 * a, -0.4)
        end
    end
    R:flush(canvas, SCENE_LAYER)

    R:mesh(SCENE.ped, ident, HALL_PAL)
    R:flush(canvas, SCENE_LAYER)
    R:mesh(SCENE.board, ident, SCENE.board_pal)
    R:flush(canvas, SCENE_LAYER, true)

    -- decals on the board: markers, shadows
    self:_draw_markers(R, time)
    local actors = game:actors()
    for i = 1, #actors do
        local a = actors[i]
        local s = 1 / (1 + (a.y or 0) * 1.5)
        local alpha = 70 * (a.alpha or 1)
        if a.anim == "die" then alpha = alpha * math_max(0, 1 - a.anim_t / 1.8) end
        local rad = a.kind == "r" and 0.32 or (a.kind == "n" and 0.28 or 0.25)
        R:disc(a.x, 0.008, a.z, rad * s, rad * s * (a.kind == "n" and 1.25 or 1), 10, alpha, 0, 0, 0)
    end
    R:flush(canvas, SCENE_LAYER, true)

    -- figures
    local sel = game:selected()
    local hover = game:hover()
    local check = game:check_square()
    local pulse = 0.5 + 0.5 * math_sin(time * 5)
    local gtime = game:time()
    local battle = game:battle()
    for i = 1, #actors do
        local a = actors[i]
        local pose = self:_pose(a)
        Figures.animate(a, pose, gtime)
        if a.anim ~= "die" then
            if a.sq and a.sq == sel then
                a.tint, a.tint_k = TINT_SELECT, 0.18 + 0.12 * pulse
            elseif a.sq and a.sq == check and a.anim ~= "topple" then
                a.tint, a.tint_k = TINT_CHECK, 0.12 + 0.18 * pulse
            elseif a.sq and a.sq == hover and not game:in_sequence() then
                a.tint, a.tint_k = TINT_HOVER, 0.12
            else
                a.tint_k = 0
            end
        end
        Figures.draw(R, a, pose, nil, self:_bystander_alpha(a, cam, battle))
    end
    -- dizzy stars orbit above bonked heads
    for i = 1, #actors do
        local a = actors[i]
        if a.anim == "die" and a.style == "dizzy" and a.anim_t < 1.3 then
            for k = 0, 2 do
                local ang = a.anim_t * 7 + k * TAU / 3
                R:glow(a.x + math_cos(ang) * 0.2, Figures.HEIGHT[a.kind] + 0.05, a.z + math_sin(ang) * 0.2, 0.06, 230, 255, 230, 80, 2, 8, -0.3)
            end
        end
    end
    R:flush(canvas, SCENE_LAYER)
    stats.tris = R.submitted
end

-- During a battle close-up, figures standing between the camera and the fighters turn see-through.
function BattleChessView:_bystander_alpha(a, cam, battle)
    if not battle or battle.attacker_actor == a or battle.victim_actor == a then return 1 end
    local ex, ez = cam.ex, cam.ez
    local sx, sz = cam.tx - ex, cam.tz - ez
    local sl = sx * sx + sz * sz
    if sl < 0.01 then return 1 end
    local vx, vz = a.x - ex, a.z - ez
    local t = (vx * sx + vz * sz) / sl
    if t <= 0 or t >= 0.92 then return 1 end
    local qx, qz = vx - sx * t, vz - sz * t
    local d = math_sqrt(qx * qx + qz * qz)
    return 0.25 + 0.75 * D3.clamp((d - 0.35) / 0.5, 0, 1)
end

local flame_mesh
function BattleChessView:_flame_mesh()
    if not flame_mesh then
        flame_mesh = D3.mesh()
        flame_mesh:octa(0, 0.5, 0, 0.5, 0.7, FLAME, 4)
        flame_mesh:octa(0, 0.35, 0, 0.28, 0.35, FLAME_CORE, 4)
    end
    return flame_mesh
end

function BattleChessView:_draw_fx(canvas, cam, dt)
    -- flashes and ground rings
    local flashes = self._flashes
    for i = #flashes, 1, -1 do
        local f = flashes[i]
        f.life = f.life - dt
        if f.life <= 0 then
            table.remove(flashes, i)
        else
            local k = f.life / f.max
            local sx, sy, d = cam:project(f.x, f.y, f.z)
            if sx then
                if f.ring then
                    local r = f.r * (1 - k * k * k)
                    local pts = self._ring_pts or {}
                    self._ring_pts = pts
                    local n = 0
                    for s = 0, 20 do
                        local a = s / 20 * TAU
                        local px, py = cam:project(f.x + math_cos(a) * r, f.y, f.z + math_sin(a) * r)
                        if not px then n = 0 break end
                        pts[n * 2 + 1], pts[n * 2 + 2] = px, py
                        n = n + 1
                    end
                    for s = 1, n - 1 do
                        canvas:line(pts[s * 2 - 1], pts[s * 2], pts[s * 2 + 1], pts[s * 2 + 2], 1 + 4 * k, FX_LAYER, f.color, 220 * k)
                    end
                else
                    canvas:glow(sx, sy, cam.F * f.r / d * (0.6 + 0.6 * (1 - k)), FX_LAYER - 0.03, f.color, 200 * k, 5, 1, 0.3 * k)
                end
            end
        end
    end

    local bolt = self._bolt
    if bolt then
        bolt.t = bolt.t + dt
        if bolt.t > 0.4 then
            self._bolt = nil
        else
            local k = 1 - bolt.t / 0.4
            local reach = math_min(1, bolt.t / 0.12)
            local ax, ay = cam:project(bolt.x1, bolt.y1, bolt.z1)
            local steps = 7
            local px, py = ax, ay
            if ax then
                for s = 1, steps do
                    local u = s / steps * reach
                    local jx = s < steps and (math_random() - 0.5) * 0.18 or 0
                    local jy = s < steps and (math_random() - 0.5) * 0.18 or 0
                    local qx, qy = cam:project(D3.lerp(bolt.x1, bolt.x2, u) + jx, D3.lerp(bolt.y1, bolt.y2, u) + jy, D3.lerp(bolt.z1, bolt.z2, u))
                    if qx and px then
                        canvas:glow_line(px, py, qx, qy, 2.4, FX_LAYER + 0.05, bolt.color, 255 * k, 3)
                    end
                    px, py = qx, qy
                end
            end
        end
    end

    self:_draw_particles(canvas, cam)

    local text = self._text
    local shouts = self._shouts
    for i = #shouts, 1, -1 do
        local s = shouts[i]
        s.t = s.t + dt
        if s.t > 1.1 then
            table.remove(shouts, i)
        else
            local sx, sy = cam:project(s.x, s.y + s.t * 0.25, s.z)
            if sx then
                sy = math_max(sy, cam.vy + 62)
                local pop = s.t < 0.12 and (s.t / 0.12) or 1
                local size = math_floor(18 + 10 * pop)
                local a = 255 * math_min(1, (1.1 - s.t) * 3)
                text:draw(s.text, sx - 90 + 2, sy - 20 + 2, 180, 40, size, C.banner_shadow, "center", FX_LAYER + 0.2, nil, a)
                text:draw(s.text, sx - 90, sy - 20, 180, 40, size, s.color, "center", FX_LAYER + 0.3, nil, a)
            end
        end
    end
end

function BattleChessView:_draw_labels(cam, client)
    local text = self._text
    local ex, ez = cam.ex, cam.ez
    local zside = ez < 0 and -4.3 or 4.3
    local xside = ex < 0 and -4.3 or 4.3
    local files = "abcdefgh"
    for i = 0, 7 do
        local sx, sy, d = cam:project(i - 3.5, 0, zside)
        if sx and sx > client.x and sx < client.x + client.w and sy > client.y and sy < client.y + client.h then
            local size = math_floor(math_max(8, math_min(15, cam.F * 0.3 / d)))
            text:draw(files:sub(i + 1, i + 1), sx - 10, sy - 9, 20, 18, size, C.label, "center", SCENE_LAYER + 0.02, nil, 190)
        end
        sx, sy, d = cam:project(xside, 0, i - 3.5)
        if sx and sx > client.x and sx < client.x + client.w and sy > client.y and sy < client.y + client.h then
            local size = math_floor(math_max(8, math_min(15, cam.F * 0.3 / d)))
            text:draw(tostring(i + 1), sx - 10, sy - 9, 20, 18, size, C.label, "center", SCENE_LAYER + 0.02, nil, 190)
        end
    end
end

function BattleChessView:_draw_hud(canvas, client, dt)
    local game = self._game
    local text = self._text
    -- cinematic bars during battles
    local target = game:battle() and 1 or 0
    self._bars = self._bars + (target - self._bars) * math_min(1, dt * 6)
    if self._bars > 0.01 then
        local h = 30 * self._bars
        canvas:rect(client.x, client.y, client.w, h, HUD_LAYER, C.bar, 235)
        canvas:rect(client.x, client.y + client.h - h, client.w, h, HUD_LAYER, C.bar, 235)
        local b = game:battle()
        if b then
            local label = Figures.NAMES[b.attacker] .. "  vs  " .. Figures.NAMES[b.victim]
            text:draw(label, client.x, client.y + h - 28, client.w, 26, 16, C.banner, "center", HUD_LAYER + 0.2, nil, 255 * self._bars)
            text:draw("Click or press Space to skip", client.x, client.y + client.h - h + 4, client.w, 22, 11, C.label, "center", HUD_LAYER + 0.2, nil, 200 * self._bars)
        end
    end

    local cx, cy = client.x, client.y + client.h * 0.36
    if self._banner and self._banner_t > 0 then
        local a = math_min(1, self._banner_t * 3)
        local grow = math_min(1, (2.2 - self._banner_t) * 8)
        local size = math_floor(22 + 4 * grow)
        text:draw(self._banner, cx + 2, cy + 2, client.w, 40, size, C.banner_shadow, "center", HUD_LAYER + 0.3, nil, 255 * a)
        text:draw(self._banner, cx, cy, client.w, 40, size, C.banner, "center", HUD_LAYER + 0.4, nil, 255 * a)
    end

    local msg, mt = game:message()
    if msg then
        text:draw(msg, client.x, client.y + client.h - 58, client.w, 22, 14, C.label, "center", HUD_LAYER + 0.2, nil, 255 * math_min(1, mt * 3))
    end

    if game:is_thinking() then
        -- a small hourglass in the corner while the computer thinks
        local x, y = client.x + client.w - 26, client.y + 12
        local a = self._time * 2.5
        local c, s = math_cos(a) * 7, math_sin(a) * 7
        canvas:circle(x, y + 7, 11, HUD_LAYER, C.black, 110, 1, 0, 14)
        canvas:tri(x - c, y + 7 - s, x + c, y + 7 + s, x, y + 7, HUD_LAYER + 0.1, C.gold)
        canvas:tri(x + s * 0.8, y + 7 - c * 0.8, x - s * 0.8, y + 7 + c * 0.8, x, y + 7, HUD_LAYER + 0.1, C.spark)
        text:draw("Thinking", x - 80, y - 3, 64, 20, 11, C.label, "right", HUD_LAYER + 0.2)
    end
end

-- Dialog content ------------------------------------------------------------------------------------------------------

function BattleChessView:_mini_figure(canvas, kind, side, x, y, w, h, t, layer, yaw)
    local cam = self._preview_cam
    cam:set_viewport(x, y, w, h)
    cam.yaw, cam.pitch, cam.dist, cam.tx, cam.ty, cam.tz = yaw or (math_pi + math_sin(t * 0.9) * 0.9), 0.28, 2.35, 0, 0.5, 0
    cam:update()
    local R = self._renderer
    R:begin(cam, x, y, x + w, y + h)
    R:disc(0, 0, 0, 0.42, 0.42, 14, 120, 200, 180, 140)
    R:disc(0, 0.002, 0, 0.3, 0.3, 12, 90, 0, 0, 0)
    local a = self._preview_actor
    a.kind, a.side, a.anim, a.id = kind, side, "idle", 2
    Figures.animate(a, self._preview_pose, t)
    Figures.draw(R, a, self._preview_pose)
    R:flush(canvas, layer)
end

function BattleChessView:_dialog_content(canvas, D, dialog, text, t)
    local box = D.box
    local game = self._game
    local x, y = box.x + 16, box.y + 34
    if dialog.kind == "how_to" then
        for i = 1, #HOW_TO do
            text:draw(HOW_TO[i], x, y + (i - 1) * 19, box.w - 32, 18, 12, C.text_black, "left", 10.5)
        end
    elseif dialog.kind == "about" then
        Win95.field(canvas, x, y, 76, 92, 9.2, { 255, 40, 34, 34 })
        self:_mini_figure(canvas, "n", "w", x + 1, y + 1, 74, 90, t, 9.3)
        text:draw("Battle Chess", x + 88, y, 220, 24, 16, C.text_black, "left", 10.5)
        text:draw("Mourningstar Waiting Games edition", x + 88, y + 26, 230, 18, 12, C.text_black, "left", 10.5)
        text:draw("A tribute to the 1988 classic.", x + 88, y + 46, 230, 18, 12, C.text_black, "left", 10.5)
        text:draw("Games won against the computer: " .. game:wins(), x + 88, y + 70, 230, 18, 12, C.text_black, "left", 10.5)
    elseif dialog.kind == "over" then
        draw_icon(canvas, x + 14, y + 18, 28, 9.3)
        local over = game:over_info()
        text:draw(game:result_text(), x + 46, y, 230, 20, 14, C.text_black, "left", 10.5)
        local line
        if over and over.status == "checkmate" then
            if game:two_players() then
                line = "Well played, both of you."
            elseif over.human_won then
                line = "You won! Games won: " .. game:wins()
            else
                line = "The computer wins this one."
            end
        else
            line = "Nobody wins this battle."
        end
        text:draw(line, x + 46, y + 26, 230, 18, 12, (over and over.human_won) and C.text_red or C.text_black, "left", 10.5)
    elseif dialog.kind == "promote" then
        local px, py = box.x + 176, box.y + 36
        Win95.field(canvas, px, py, 110, 112, 9.2, { 255, 40, 34, 34 })
        local pos = game:position()
        local piece = pos:piece_at(dialog.from)
        local side = piece and (piece:upper() == piece and "w" or "b") or "w"
        self:_mini_figure(canvas, dialog.values.piece or "q", side, px + 1, py + 1, 108, 110, t, 9.3)
    end
end

-- Main draw ---------------------------------------------------------------------------------------------------------

function BattleChessView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local game = self._game
    local text = self._text
    text:reset()

    if not game then
        BattleChessView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
        return
    end

    dt = math_min(dt or 0.016, 0.05)
    self._time = self._time + dt

    local base = self:_scenegraph_world_position("scanner_base")
    self:_process_pointer(input_service, ui_renderer, base)

    local shell = game:shell()
    local client = shell:layout().client
    self:_handle_events()
    self:_ambient_effects(dt)
    self:_update_particles(dt)
    self._banner_t = self._banner_t - dt
    self._shaker:update(dt, 6)

    local canvas = self._canvas
    if canvas:begin(ui_renderer, base) then
        local time = self._time
        local seconds = math_floor(game:time())
        local blink = math_floor(time * 2) % 2 == 0 and ":" or " "
        DESKTOP_OPTS.clock = string.format("%02d%s%02d", math_floor(seconds / 60) % 100, blink, seconds % 60)
        Win95.draw_desktop(canvas, text, time, DESKTOP_OPTS)
        WINDOW_OPTS.status = game:status_segments()
        Win95.draw_window(canvas, text, shell, time, WINDOW_OPTS)

        canvas:set_clip(client.x, client.y, client.x + client.w, client.y + client.h)
        local sh = self._shaker
        canvas:set_shake(sh.x, sh.y)
        text:set_offset(sh.x, sh.y)
        if game:board2d() then
            self._flat:update(dt)
            self._flat:draw(canvas, text, game, time, SCENE_LAYER)
        else
            self:_draw_scene(canvas, client, time)
            self:_draw_labels(game:camera(), client)
            self:_draw_fx(canvas, game:camera(), dt)
        end
        canvas:set_shake(0, 0)
        text:set_offset(0, 0)
        self:_draw_hud(canvas, client, dt)
        canvas:reset_clip()

        Win95.draw_menu(canvas, text, shell)
        Win95.draw_dialog(canvas, text, shell, time, self._dialog_cb)
        Win95.draw_hint(canvas, text, game:board2d() and HINT_2D or HINT)

        canvas:crt(0, 0, RENDER_SIZE, RENDER_SIZE, time, 11.5, CRT_OPTS)
        self._stats.submissions = canvas:submissions()
        canvas:finish()
    end

    BattleChessView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

function BattleChessView:frame_stats()
    return self._stats
end

function BattleChessView:destroy()
    self._canvas = nil
    self._renderer = nil
    self._particles = nil
    BattleChessView.super.destroy(self)
end

return BattleChessView
