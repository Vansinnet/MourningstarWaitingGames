local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")
local Gfx = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_canvas")

local math_abs = math.abs
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_sin = math.sin

local RENDER_SIZE = 600
local GAME_W = 600
local GAME_H = 600
local STAR_COUNT = 120

local COLORS = {
    bg = { 245, 0, 5, 1 },
    grid = { 34, 0, 95, 52 },
    grid_hot = { 60, 0, 180, 95 },
    star = { 115, 0, 175, 120 },
    star_hot = { 185, 95, 240, 180 },
    invader_top = { 255, 160, 255, 110 },
    invader_mid = { 255, 0, 235, 120 },
    invader_low = { 255, 0, 205, 80 },
    invader_core = { 255, 220, 255, 220 },
    player = { 255, 0, 255, 105 },
    player_core = { 255, 170, 255, 185 },
    pbullet = { 255, 255, 255, 255 },
    ebullet = { 255, 255, 110, 35 },
    shield = { 235, 0, 200, 75 },
    shield_hot = { 255, 80, 255, 130 },
    mystery = { 255, 255, 170, 25 },
    mystery_hot = { 255, 255, 245, 120 },
    hud = { 255, 0, 230, 115 },
    hud_dim = { 170, 0, 165, 90 },
    warning = { 255, 255, 90, 50 },
    armor = { 255, 12, 95, 55 },
    message = { 210, 100, 255, 175 },
    hidden = { 0, 0, 0, 0 },
    space_top = { 255, 6, 3, 18 },
    space_low = { 255, 1, 12, 12 },
    nebula_a = { 255, 120, 40, 190 },
    nebula_b = { 255, 0, 150, 130 },
    planet = { 255, 60, 120, 110 },
    planet_dark = { 255, 5, 14, 18 },
    atmosphere = { 255, 90, 255, 200 },
    ground = { 255, 0, 255, 140 },
    hull = { 255, 30, 170, 110 },
    hull_light = { 255, 180, 255, 210 },
    cockpit = { 255, 120, 230, 255 },
    flame = { 255, 255, 170, 60 },
    flame_core = { 255, 255, 250, 210 },
    eye = { 255, 255, 60, 60 },
    beam = { 255, 255, 220, 120 },
    white = { 255, 255, 255, 255 },
    shadow = { 255, 0, 0, 0 },
}

local INVADER_FRAMES = {
    {
        {
            "00111100",
            "01111110",
            "11011011",
            "11111111",
            "00100100",
            "01011010",
            "10100101",
        },
        {
            "00111100",
            "01111110",
            "11011011",
            "11111111",
            "01011010",
            "10000001",
            "01000010",
        },
    },
    {
        {
            "00100100",
            "01111110",
            "11011011",
            "11111111",
            "11111111",
            "01000010",
            "10000001",
        },
        {
            "00100100",
            "10111101",
            "11011011",
            "11111111",
            "01111110",
            "00100100",
            "01000010",
        },
    },
    {
        {
            "00011000",
            "00111100",
            "01111110",
            "11011011",
            "11111111",
            "00100100",
            "01000010",
        },
        {
            "00011000",
            "00111100",
            "01111110",
            "11011011",
            "11111111",
            "01011010",
            "10100101",
        },
    },
}

local function compile_mask(mask)
    local runs = {}
    local eyes = {}
    for row = 1, #mask do
        local line = mask[row]
        local first = nil
        for col = 1, #line + 1 do
            if line:sub(col, col) == "1" then
                first = first or col
            elseif first then
                runs[#runs + 1] = { first - 1, row - 1, col - first, 1 - (row - 1) / #mask * 0.35 }
                first = nil
            end
        end
        local left = line:find("1", 1, true)
        local right = left and #line - line:reverse():find("1", 1, true) + 1
        if left and line:find("11011", 1, true) then
            for col = left + 1, right - 1 do
                if line:sub(col, col) == "0" then eyes[#eyes + 1] = { col - 1, row - 1 } end
            end
        end
    end
    runs.eyes = eyes
    return runs
end

for i = 1, #INVADER_FRAMES do
    for f = 1, 2 do
        INVADER_FRAMES[i][f] = compile_mask(INVADER_FRAMES[i][f])
    end
end

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
    game_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { GAME_W, GAME_H }, position = { 0, 0, 8 },
    },
    title_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 500, 22 }, position = { 0, -280, 20 },
    },
    score_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 180, 22 }, position = { -190, -250, 20 },
    },
    wave_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 180, 22 }, position = { 0, -250, 20 },
    },
    lives_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 180, 22 }, position = { 190, -250, 20 },
    },
    message_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 420, 80 }, position = { 0, 0, 25 },
    },
    controls_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 560, 22 }, position = { 0, 250, 20 },
    },
    highscore_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 560, 22 }, position = { 0, 272, 20 },
    },
}

local widget_definitions = {
    bg = UIWidget.create_definition({
        { pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.bg },
        }
    }, "game_area", nil, { GAME_W, GAME_H }),
    scanner_noise = UIWidget.create_definition({
        { pass_type = "texture", style_id = "noise",
            value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
            style = { hdr = true, color = { 120, 0, 125, 45 }, offset = { -300, -300, 2 }, angle = 0 },
        }
    }, "center_pivot", nil, { 600, 600 }),
    border_top = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.grid_hot, offset = { -300, -300, 12 } },
        }
    }, "center_pivot", nil, { 600, 2 }),
    border_bottom = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.grid_hot, offset = { -300, 298, 12 } },
        }
    }, "center_pivot", nil, { 600, 2 }),
    border_left = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.grid_hot, offset = { -300, -300, 12 } },
        }
    }, "center_pivot", nil, { 2, 600 }),
    border_right = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.grid_hot, offset = { 298, -300, 12 } },
        }
    }, "center_pivot", nil, { 2, 600 }),
    decoration_inquisition = UIWidget.create_definition({
        { pass_type = "texture", style_id = "highlight",
            value = "content/ui/materials/backgrounds/scanner/scanner_decoration_inquisition",
            style = { hdr = true, color = { 55, 0, 230, 120 }, offset = { -24, -292, 5 } },
        }
    }, "center_pivot", nil, { 48, 48 }),
    decoration_left_mark = UIWidget.create_definition({
        { pass_type = "texture", style_id = "highlight",
            value = "content/ui/materials/backgrounds/scanner/scanner_decoration_left_mark",
            style = { hdr = true, color = { 42, 0, 190, 115 }, offset = { -288, -60, 5 } },
        }
    }, "center_pivot", nil, { 42, 120 }),
    decoration_right_mark = UIWidget.create_definition({
        { pass_type = "texture", style_id = "highlight",
            value = "content/ui/materials/backgrounds/scanner/scanner_decoration_right_mark",
            style = { hdr = true, color = { 42, 0, 190, 115 }, offset = { 246, -60, 5 } },
        }
    }, "center_pivot", nil, { 42, 120 }),
    title_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "VOID INVADERS",
            style = { font_size = 16, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud, offset = { 0, 0, 1 } },
        }
    }, "title_area", nil, { 500, 22 }),
    score_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = { font_size = 18, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud, offset = { 0, 0, 1 } },
        }
    }, "score_area", nil, { 180, 22 }),
    wave_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = { font_size = 16, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud_dim, offset = { 0, 0, 1 } },
        }
    }, "wave_area", nil, { 180, 22 }),
    lives_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = { font_size = 18, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.warning, offset = { 0, 0, 1 } },
        }
    }, "lives_area", nil, { 180, 22 }),
    message_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = { font_size = 38, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = { 0, 0, 0, 0 }, offset = { 0, 0, 1 } },
        }
    }, "message_area", nil, { 420, 80 }),
    controls_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = mod:localize("invaders_controls"),
            style = { font_size = 14, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud_dim, offset = { 0, 0, 1 } },
        }
    }, "controls_area", nil, { 560, 22 }),
    highscore_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = { font_size = 14, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud, offset = { 0, 0, 1 } },
        }
    }, "highscore_area", nil, { 560, 22 }),
}

AuspexFrame.add(widget_definitions, {
    render_size = RENDER_SIZE,
    outline_size = { 620, 620 },
})
AuspexFrame.add_inner_border(widget_definitions, {
    render_size = RENDER_SIZE,
    size = { GAME_W, GAME_H },
    prefix = "invaders_game_border",
})

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }

local InvadersView = class("InvadersView", "BaseView")

local function set_color(dst, src, alpha)
    dst[1] = alpha or src[1]
    dst[2] = src[2]
    dst[3] = src[3]
    dst[4] = src[4]
end

local ROW_COLORS = { COLORS.invader_top, COLORS.invader_mid, COLORS.invader_mid, COLORS.invader_low, COLORS.invader_low }
local GROUND_Y = 574

function InvadersView:init(settings, context)
    InvadersView.super.init(self, definitions, settings, context)
    self._game = context.game
    self._no_cursor = true

    self._canvas = Gfx.Canvas.new(GAME_W, GAME_H, 7000)
    self._particles = Gfx.Particles.new(420)
    self._shaker = Gfx.Shaker.new()
    self._time = 0
    self._alive = {}
    self._shield_alive = {}
    self._prev_state = nil
    self._prev_player = nil
    self._prev_bullet = false
    self._muzzle = 0
    self._hit_flash = 0
    self._wave_flash = 0
    self._prev_wave = nil
    self._mystery_boom = false
    self._last_mystery_x = nil

    self._stars = {}
    for i = 1, STAR_COUNT do
        local layer = 1 + i % 3
        self._stars[i] = {
            x = (i * 137.51) % GAME_W,
            y = (i * 83.17 + i * i * 0.37) % GAME_H,
            layer = layer,
            phase = i * 2.399,
            size = layer == 3 and 1.8 or layer == 2 and 1.3 or 0.9,
        }
    end
end

function InvadersView:dialogue_system() return nil end
function InvadersView:is_using_input() return false end

function InvadersView:_detect_events(ent)
    local game = self._game
    local particles = self._particles
    local enemies = ent.enemies or {}
    local alive = self._alive

    for i = 1, #enemies do
        local e = enemies[i]
        if alive[e] and not e.alive then
            local color = ROW_COLORS[e.row] or COLORS.invader_mid
            local cx, cy = e.x + e.w * 0.5, e.y + e.h * 0.5
            particles:burst(cx, cy, 16, 60, 260, 0.25, 0.6, 1.8, color, "spark", 3)
            particles:burst(cx, cy, 8, 30, 140, 0.4, 0.9, 4, color, "shard", 1.5, 90)
            particles:shockwave(cx, cy, 34, 0.3, color, 2.5)
            particles:flash(cx, cy, 30, 0.2, COLORS.white)
            self._shaker:add(0.08)
        end
        alive[e] = e.alive or nil
    end

    local shields = ent.shields or {}
    local shield_alive = self._shield_alive
    for i = 1, #shields do
        local b = shields[i]
        if shield_alive[b] and not b.alive then
            particles:burst(b.x + b.w * 0.5, b.y + b.h * 0.5, 3, 20, 110, 0.3, 0.6, 2.2, COLORS.shield, "dot", 3, 160)
        end
        shield_alive[b] = b.alive or nil
    end

    local state = game:state()
    if state == "dying" and self._prev_state ~= "dying" and self._prev_player then
        local p = self._prev_player
        local cx, cy = p.x + p.w * 0.5, p.y + p.h * 0.5
        particles:burst(cx, cy, 50, 80, 420, 0.4, 1.1, 2.4, COLORS.flame, "spark", 2)
        particles:burst(cx, cy, 20, 40, 200, 0.7, 1.4, 5, COLORS.hull, "shard", 1.2, 140)
        particles:burst(cx, cy, 12, 10, 60, 0.8, 1.6, 10, COLORS.flame, "smoke", 1, -30)
        particles:shockwave(cx, cy, 110, 0.7, COLORS.flame, 4)
        particles:flash(cx, cy, 110, 0.45, COLORS.flame)
        self._hit_flash = 1
        self._shaker:add(0.9)
    end

    local wave = game:wave()
    if self._prev_wave and wave ~= self._prev_wave then
        if wave > self._prev_wave then self._wave_flash = 1 end
        self._alive = {}
        self._shield_alive = {}
        alive = self._alive
        for i = 1, #enemies do alive[enemies[i]] = enemies[i].alive or nil end
        for i = 1, #shields do self._shield_alive[shields[i]] = shields[i].alive or nil end
    end

    local mystery_hit = game.mystery_hit_ticks and game:mystery_hit_ticks() or 0
    if mystery_hit > 0 and not self._mystery_boom then
        local mx = (game.mystery_x and game:mystery_x() or self._last_mystery_x or GAME_W * 0.5) + 25
        particles:burst(mx, 54, 40, 80, 380, 0.4, 1, 2.2, COLORS.mystery, "spark", 2.2)
        particles:burst(mx, 54, 14, 30, 160, 0.6, 1.2, 5, COLORS.mystery_hot, "shard", 1.2, 120)
        particles:shockwave(mx, 54, 90, 0.6, COLORS.mystery, 3.5)
        particles:flash(mx, 54, 80, 0.4, COLORS.mystery_hot)
        self._shaker:add(0.4)
    end
    self._mystery_boom = mystery_hit > 0
    if ent.mystery then self._last_mystery_x = ent.mystery.x end

    local has_bullet = ent.player_bullets and ent.player_bullets[1] ~= nil
    if has_bullet and not self._prev_bullet then
        self._muzzle = 1
    end
    self._prev_bullet = has_bullet

    self._prev_state = state
    self._prev_wave = wave
    if ent.player then
        local p = self._prev_player or {}
        p.x, p.y, p.w, p.h = ent.player.x, ent.player.y, ent.player.w, ent.player.h
        self._prev_player = p
    end
end

function InvadersView:_draw_space(canvas, t, sx, sy)
    canvas:vgradient(0, 0, GAME_W, GAME_H, 0.2, COLORS.space_top, COLORS.space_low, 255, 255, 30)

    for i = 0, 3 do
        local nx = 300 + math_sin(t * 0.05 + i * 1.7) * 220
        local ny = 180 + math_cos(t * 0.04 + i * 2.3) * 110 + i * 40
        canvas:glow(nx, ny, 150 + i * 25, 0.3, i % 2 == 0 and COLORS.nebula_a or COLORS.nebula_b, 26, 6)
    end

    local px, py, pr = 555 + sx * 0.1, 500 + sy * 0.1, 80
    canvas:glow(px, py, pr * 1.5, 0.4, COLORS.atmosphere, 34, 6)
    canvas:circle(px, py, pr, 0.45, COLORS.planet, 255, 0.28)
    canvas:circle(px - pr * 0.18, py - pr * 0.18, pr * 0.8, 0.46, COLORS.planet, 255, 0.4)
    canvas:circle(px - pr * 0.32, py - pr * 0.32, pr * 0.45, 0.47, COLORS.planet, 200, 0.55, 0.05)
    for band = -2, 2 do
        canvas:ellipse(px, py + band * 17, pr * 0.95 - math_abs(band) * 12, 3, 0.48, COLORS.planet_dark, 90)
    end
    canvas:ellipse(px + pr * 0.35, py + pr * 0.35, pr * 0.72, pr * 0.72, 0.49, COLORS.planet_dark, 120)
    canvas:ring(px, py, pr + 1.5, 2, 0.5, COLORS.atmosphere, 70)
    canvas:ring(px, py, pr * 1.45, 1.2, 0.5, COLORS.atmosphere, 40, 40, 2.4, 5.6)

    for i = 1, STAR_COUNT do
        local s = self._stars[i]
        local twinkle = (math_sin(t * (1.3 + s.layer * 0.7) + s.phase) + 1) * 0.5
        local x = (s.x + sx * s.layer * 0.25) % GAME_W
        local y = (s.y + t * s.layer * 4 + sy * s.layer * 0.25) % GROUND_Y
        local alpha = 50 + s.layer * 45 + twinkle * 70
        local color = s.layer == 3 and COLORS.star_hot or COLORS.star

        canvas:rect(x - s.size * 0.5, y - s.size * 0.5, s.size, s.size, 0.6, color, alpha, 1, 0.5)
        if s.layer == 3 and twinkle > 0.7 then
            local flare = (twinkle - 0.7) * 20
            canvas:rect(x - flare, y - 0.4, flare * 2, 0.8, 0.61, color, alpha * 0.6)
            canvas:rect(x - 0.4, y - flare, 0.8, flare * 2, 0.61, color, alpha * 0.6)
        end
    end

    canvas:vgradient(0, GROUND_Y - 40, GAME_W, 40, 0.7, COLORS.ground, COLORS.ground, 0, 30, 10)
    canvas:rect(0, GROUND_Y, GAME_W, GAME_H - GROUND_Y, 0.75, COLORS.space_low, 255)
    canvas:glow_line(0, GROUND_Y, GAME_W, GROUND_Y, 1.5, 0.8, COLORS.ground, 190, 3)
    local scroll = (t * 18) % 12
    for i = 0, 3 do
        local y = GROUND_Y + 3 + i * 6 + scroll * (i + 1) / 4
        if y < GAME_H then
            canvas:rect(0, y, GAME_W, 1, 0.78, COLORS.ground, 70 - i * 14)
        end
    end
    for x = -300, 900, 40 do
        canvas:line(300 + (x - 300) * 0.35, GROUND_Y, x, GAME_H + 10, 1, 0.77, COLORS.ground, 45)
    end
end

function InvadersView:_draw_enemies(canvas, enemies, t, sx, sy)
    for i = 1, #enemies do
        local e = enemies[i]
        if e.alive then
            local kind = e.row == 1 and 1 or e.row <= 3 and 2 or 3
            local mask = INVADER_FRAMES[kind][e.frame == 2 and 2 or 1]
            local color = ROW_COLORS[e.row] or COLORS.invader_mid
            local ex, ey = e.x + sx, e.y + sy
            local wave = 0.85 + 0.3 * (math_sin(t * 3 - e.x * 0.025 - e.y * 0.01) + 1) * 0.5
            local pw = (30 - 7) / 8
            local ph = (22 - 6) / 7

            for r = 1, #mask do
                local run = mask[r]
                canvas:rect(ex + run[1] * (pw + 1) - 2, ey + run[2] * (ph + 1) - 2, run[3] * pw + (run[3] - 1) + 4, ph + 4, 3.1, color, 26 * wave)
                canvas:rect(ex + run[1] * (pw + 1), ey + run[2] * (ph + 1), run[3] * pw + (run[3] - 1), ph, 3.2, color, 245, run[4] * wave, 0)
                if run[2] == 0 then
                    canvas:rect(ex + run[1] * (pw + 1), ey, run[3] * pw + (run[3] - 1), 1, 3.25, color, 170, 1, 0.55)
                end
            end

            local eyes = mask.eyes
            local blink = (math_sin(t * 2.2 + e.x * 0.13) > 0.97) and 0.2 or 1
            for k = 1, #eyes do
                local eye = eyes[k]
                local ex2 = ex + eye[1] * (pw + 1) + pw * 0.5
                local ey2 = ey + eye[2] * (ph + 1) + ph * 0.5
                canvas:rect(ex2 - 2.5, ey2 - 2.5, 5, 5, 3.3, COLORS.eye, 70 * blink)
                canvas:rect(ex2 - 1, ey2 - 1, 2, 2, 3.35, COLORS.eye, 255 * blink, 1, 0.4)
            end
        end
    end
end

function InvadersView:_draw_shields(canvas, shields, t, sx, sy)
    for i = 1, #shields do
        local b = shields[i]
        if b.alive then
            local light = ((b.x * 3 + b.y * 7) % 5) / 5
            local shimmer = (math_sin(t * 2 - b.x * 0.05) + 1) * 0.5
            canvas:rect(b.x + sx, b.y + sy, b.w - 0.5, b.h - 0.5, 3, COLORS.shield, 200, 0.75 + light * 0.25)
            canvas:rect(b.x + sx, b.y + sy, b.w - 0.5, 1.2, 3.05, COLORS.shield_hot, 140 + shimmer * 80, 1, 0.3)
        end
    end
end

function InvadersView:_draw_mystery(canvas, mystery, t, sx, sy)
    if not mystery then return end

    local cx = mystery.x + 25 + sx
    local cy = mystery.y + 12 + sy

    canvas:tri(cx - 6, cy + 4, cx + 6, cy + 4, cx, cy + 4, 2.9, COLORS.beam, 0)
    canvas:quad(cx - 8, cy + 6, cx + 8, cy + 6, cx + 30, GROUND_Y - 150, cx - 30, GROUND_Y - 150, 2.8, COLORS.beam, 18 + (math_sin(t * 9) + 1) * 8)
    canvas:glow(cx, cy, 46, 2.9, COLORS.mystery, 70)
    canvas:ellipse(cx, cy + 2, 25, 7, 3.2, COLORS.mystery, 255, 0.55)
    canvas:ellipse(cx, cy + 1, 23, 5.5, 3.25, COLORS.mystery, 255, 1)
    canvas:ellipse(cx, cy - 4, 11, 8, 3.3, COLORS.mystery_hot, 200, 0.8, 0.2)
    canvas:ellipse(cx - 3, cy - 6, 4, 3, 3.35, COLORS.white, 170)

    for light = 0, 5 do
        local lx = cx - 18 + light * 7.2
        local on = (math_sin(t * 8 - light * 1.1) + 1) * 0.5
        canvas:circle(lx, cy + 2, 1.8, 3.4, COLORS.mystery_hot, 120 + on * 135, 1, on * 0.6, 6)
        canvas:circle(lx, cy + 2, 4, 3.38, COLORS.mystery_hot, on * 60, 1, 0, 8)
    end
end

function InvadersView:_draw_player(canvas, player, t, sx, sy)
    if not player then return end

    local x = player.x + sx
    local y = player.y + sy
    local cx = x + player.w * 0.5
    local flick = (math_sin(t * 40) + math_sin(t * 67)) * 0.25 + 1

    for side = -1, 1, 2 do
        local fx = cx + side * 11
        local len = 8 * flick
        canvas:glow(fx, y + 22, 10, 4.8, COLORS.flame, 70)
        canvas:tri(fx - 3, y + 18, fx + 3, y + 18, fx, y + 18 + len + 4, 4.85, COLORS.flame, 220)
        canvas:tri(fx - 1.5, y + 18, fx + 1.5, y + 18, fx, y + 18 + len, 4.86, COLORS.flame_core, 255)
    end

    canvas:glow(cx, y + 12, 34, 4.7, COLORS.player, 45)

    canvas:quad(x + 1, y + 16, x + player.w - 1, y + 16, x + player.w - 6, y + 20, x + 6, y + 20, 5, COLORS.hull, 255, 0.5)
    canvas:tri(x, y + 17, cx - 4, y + 6, cx - 4, y + 17, 5.05, COLORS.hull, 255, 0.8)
    canvas:tri(x + player.w, y + 17, cx + 4, y + 6, cx + 4, y + 17, 5.05, COLORS.hull, 255, 0.65)
    canvas:quad(cx - 6, y + 18, cx - 4, y + 2, cx + 4, y + 2, cx + 6, y + 18, 5.1, COLORS.hull, 255, 1)
    canvas:tri(cx - 4, y + 2, cx + 4, y + 2, cx, y - 6, 5.12, COLORS.hull_light, 255, 0.9)
    canvas:line(cx - 4, y + 2, cx - 6, y + 18, 1, 5.13, COLORS.hull_light, 200)
    canvas:line(x, y + 17, cx - 4, y + 6, 1, 5.13, COLORS.hull_light, 170)
    canvas:ellipse(cx, y + 7, 2.4, 4, 5.15, COLORS.cockpit, 255)
    canvas:ellipse(cx - 0.6, y + 5.5, 1, 1.8, 5.16, COLORS.white, 220)

    for side = -1, 1, 2 do
        local lx = cx + side * 16
        local on = (math_sin(t * 5 + side) + 1) * 0.5
        canvas:rect(lx - 1, y + 15, 2, 2, 5.17, side < 0 and COLORS.eye or COLORS.player_core, 150 + on * 105)
    end

    if self._muzzle > 0 then
        canvas:glow(cx, y - 8, 18 * self._muzzle, 5.2, COLORS.player_core, 200 * self._muzzle)
        canvas:tri(cx - 4, y - 5, cx + 4, y - 5, cx, y - 5 - 16 * self._muzzle, 5.21, COLORS.white, 230 * self._muzzle)
    end
end

function InvadersView:_draw_bullets(canvas, player_bullets, enemy_bullets, t, sx, sy)
    local pb = player_bullets[1]
    if pb then
        local cx = pb.x + pb.w * 0.5 + sx
        local top = pb.y + sy
        canvas:vgradient(cx - 3, top + pb.h, 6, 40, 5.4, COLORS.player, COLORS.player, 110, 0, 8)
        canvas:glow_line(cx, top, cx, top + pb.h, 2.5, 5.5, COLORS.player_core, 255, 3)
        canvas:glow(cx, top + 2, 10, 5.45, COLORS.player_core, 120)
    end

    for i = 1, #enemy_bullets do
        local b = enemy_bullets[i]
        local bx = b.x + b.w * 0.5 + sx
        local by = b.y + sy
        canvas:glow(bx, by + b.h * 0.5, 12, 5.3, COLORS.ebullet, 70)

        if b.kind == 1 then
            local phase = t * 24 + b.y * 0.3
            local px, py = bx + math_sin(phase) * 3, by
            for k = 1, 4 do
                local nx = bx + math_sin(phase + k * 1.6) * 3
                local ny = by + k * b.h / 4
                canvas:line(px, py, nx, ny, 2, 5.35, COLORS.ebullet, 255, 1, 0.2)
                px, py = nx, ny
            end
        elseif b.kind == 2 then
            canvas:rect(bx - 1, by, 2, b.h, 5.35, COLORS.ebullet, 255, 1, 0.3)
            local bar = (math_floor(t * 20) % 3) * 4
            canvas:rect(bx - 3, by + bar, 6, 2, 5.36, COLORS.mystery_hot, 255)
        else
            canvas:rect(bx - 1, by, 2, b.h, 5.35, COLORS.ebullet, 255, 1, 0.2)
            local roll = math_sin(t * 30 + b.y * 0.2) * 3
            canvas:rect(bx - 1 + roll, by + 3, 2, 2, 5.36, COLORS.white, 230)
            canvas:rect(bx - 1 - roll, by + b.h - 5, 2, 2, 5.36, COLORS.white, 230)
        end

        canvas:circle(bx, by + b.h, 2.2, 5.37, COLORS.mystery_hot, 255, 1, 0.5, 8)
    end
end

function InvadersView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local game = self._game

    if game then
        local score_w = self._widgets_by_name.score_text
        if score_w then score_w.content.text = string.format("Score: %04d", game:score()) end

        local wave_w = self._widgets_by_name.wave_text
        if wave_w then wave_w.content.text = string.format("Wave: %d", game:wave()) end

        local lives_w = self._widgets_by_name.lives_text
        if lives_w then lives_w.content.text = string.format("Hull: %d", game:lives()) end

        local message_w = self._widgets_by_name.message_text
        if message_w then
            if game:is_game_over() then
                message_w.content.text = "GAME OVER"
                message_w.style.text.text_color = COLORS.warning
            else
                local text = game:level_text()
                message_w.content.text = text
                message_w.style.text.text_color = text ~= "" and COLORS.message or COLORS.hidden
            end
        end
    end

    local hsw = self._widgets_by_name.highscore_text
    if hsw then hsw.content.text = mod:localize("invaders_highscore") .. " " .. (mod:get("invaders_highscore") or 0) end

    local noise = self._widgets_by_name.scanner_noise
    if noise and game then
        noise.style.noise.color[1] = 70 + math_floor((math_sin(game:time() * 2.3) + 1) * 18) + math_floor(game:shake() * 70)
    end

    InvadersView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

    if not game then return end

    dt = math_min(dt or 0.016, 0.05)
    self._time = self._time + dt

    local ent = game:entities()
    self:_detect_events(ent)
    self._particles:update(dt)
    self._shaker:update(dt, 8)
    self._muzzle = math_max(0, self._muzzle - dt * 9)
    self._hit_flash = math_max(0, self._hit_flash - dt * 1.4)
    self._wave_flash = math_max(0, self._wave_flash - dt * 0.9)

    local canvas = self._canvas
    if not canvas:begin(ui_renderer, self:_scenegraph_world_position("game_area")) then return end

    local time = self._time
    local shake = game:shake()
    local sx = math_sin(time * 71) * shake * 5 + self._shaker.x
    local sy = math_sin(time * 93 + 1.2) * shake * 5 + self._shaker.y

    self:_draw_space(canvas, time, sx, sy)
    self:_draw_shields(canvas, ent.shields or {}, time, sx, sy)
    self:_draw_enemies(canvas, ent.enemies or {}, time, sx, sy)
    self:_draw_mystery(canvas, ent.mystery, time, sx, sy)
    self:_draw_player(canvas, ent.player, time, sx, sy)
    self:_draw_bullets(canvas, ent.player_bullets or {}, ent.enemy_bullets or {}, time, sx, sy)
    canvas:set_shake(sx, sy)
    self._particles:draw(canvas, 6)
    canvas:set_shake(0, 0)

    if self._hit_flash > 0 then
        canvas:rect(0, 0, GAME_W, GAME_H, 7, COLORS.warning, self._hit_flash * 110)
    end
    if self._wave_flash > 0 then
        canvas:sweep(0, 0, GAME_W, GAME_H, (1 - self._wave_flash) * 2, 2, 7.1, COLORS.star_hot, 160 * self._wave_flash, 160)
    end

    canvas:crt(0, 0, GAME_W, GAME_H, time, 8, { tint = COLORS.player, vignette_depth = 90, vignette_alpha = 170 })
    canvas:finish()
end

function InvadersView:destroy()
    self._canvas = nil
    self._particles = nil
    InvadersView.super.destroy(self)
end

return InvadersView
