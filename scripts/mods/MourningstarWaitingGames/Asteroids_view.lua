local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")
local Gfx = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_canvas")

local math_cos = math.cos
local math_abs = math.abs
local math_floor = math.floor
local math_pi = math.pi
local math_max = math.max
local math_min = math.min
local math_sin = math.sin
local math_sqrt = math.sqrt

local RENDER_SIZE = 600
local GAME_W = 600
local GAME_H = 600
local COLORS = {
    bg = { 245, 0, 5, 2 },
    grid = { 35, 0, 130, 70 },
    grid_dim = { 22, 0, 75, 45 },
    star_far = { 95, 30, 85, 75 },
    star_mid = { 145, 55, 160, 150 },
    star_near = { 205, 120, 230, 240 },
    ship = { 255, 95, 255, 135 },
    ship_core = { 255, 225, 255, 225 },
    ship_invuln = { 145, 95, 210, 255 },
    flame = { 255, 255, 170, 30 },
    flame_hot = { 255, 255, 245, 140 },
    brake = { 220, 65, 180, 255 },
    rock = { 235, 0, 230, 120 },
    rock_hot = { 255, 120, 255, 210 },
    rock_shadow = { 255, 10, 70, 47 },
    bullet = { 255, 255, 255, 255 },
    bullet_glow = { 180, 80, 255, 180 },
    debris = { 220, 255, 160, 60 },
    particle_rock = { 210, 0, 230, 120 },
    particle_flame = { 235, 255, 120, 20 },
    particle_ship = { 245, 180, 235, 255 },
    hud = { 255, 0, 230, 120 },
    hud_dim = { 180, 0, 150, 85 },
    warning = { 255, 255, 90, 50 },
    message = { 210, 100, 255, 175 },
    hidden = { 0, 0, 0, 0 },
    space_top = { 255, 2, 8, 14 },
    space_low = { 255, 4, 3, 12 },
    nebula_a = { 255, 30, 120, 160 },
    nebula_b = { 255, 110, 40, 150 },
    nebula_c = { 255, 20, 170, 90 },
    stone = { 255, 88, 104, 92 },
    stone_dark = { 255, 14, 22, 20 },
    crater = { 255, 8, 14, 12 },
    hull = { 255, 150, 170, 165 },
    hull_dark = { 255, 40, 60, 58 },
    canopy = { 255, 90, 230, 255 },
    shield = { 255, 90, 210, 255 },
    white = { 255, 255, 255, 255 },
    shadow = { 255, 0, 0, 0 },
    lock = { 255, 255, 80, 60 },
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
        size = { 180, 22 }, position = { -190, -248, 20 },
    },
    lives_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 180, 22 }, position = { 190, -248, 20 },
    },
    wave_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 180, 22 }, position = { 0, -248, 20 },
    },
    message_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 420, 80 }, position = { 0, 0, 25 },
    },
    controls_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 560, 22 }, position = { 0, 248, 20 },
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
        { pass_type = "texture",
            value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
            style = { hdr = true, color = { 115, 0, 120, 45 }, offset = { -300, -300, 2 } },
        }
    }, "center_pivot", nil, { 600, 600 }),
    scanner_noise_hot = UIWidget.create_definition({
        { pass_type = "texture", style_id = "noise",
            value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
            style = { hdr = true, color = { 30, 150, 220, 80 }, offset = { -300, -300, 3 }, angle = 0 },
        }
    }, "center_pivot", nil, { 600, 600 }),
    border_top = UIWidget.create_definition({
        { pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.grid, offset = { -300, -300, 12 } },
        }
    }, "center_pivot", nil, { 600, 2 }),
    border_bottom = UIWidget.create_definition({
        { pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.grid, offset = { -300, 298, 12 } },
        }
    }, "center_pivot", nil, { 600, 2 }),
    border_left = UIWidget.create_definition({
        { pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.grid, offset = { -300, -300, 12 } },
        }
    }, "center_pivot", nil, { 2, 600 }),
    border_right = UIWidget.create_definition({
        { pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.grid, offset = { 298, -300, 12 } },
        }
    }, "center_pivot", nil, { 2, 600 }),
    decoration_inquisition = UIWidget.create_definition({
        { pass_type = "texture", style_id = "highlight",
            value = "content/ui/materials/backgrounds/scanner/scanner_decoration_inquisition",
            style = { hdr = true, color = { 70, 0, 230, 120 }, offset = { -24, -292, 5 } },
        }
    }, "center_pivot", nil, { 48, 48 }),
    decoration_left_mark = UIWidget.create_definition({
        { pass_type = "texture", style_id = "highlight",
            value = "content/ui/materials/backgrounds/scanner/scanner_decoration_left_mark",
            style = { hdr = true, color = { 45, 0, 190, 115 }, offset = { -288, -60, 5 } },
        }
    }, "center_pivot", nil, { 42, 120 }),
    decoration_right_mark = UIWidget.create_definition({
        { pass_type = "texture", style_id = "highlight",
            value = "content/ui/materials/backgrounds/scanner/scanner_decoration_right_mark",
            style = { hdr = true, color = { 45, 0, 190, 115 }, offset = { 246, -60, 5 } },
        }
    }, "center_pivot", nil, { 42, 120 }),
    decoration_eagle = UIWidget.create_definition({
        { pass_type = "texture", style_id = "highlight",
            value = "content/ui/materials/backgrounds/scanner/scanner_decoration_eagle",
            style = { hdr = true, color = { 35, 0, 180, 110 }, offset = { 215, 205, 5 } },
        }
    }, "center_pivot", nil, { 95, 95 }),
    decoration_skull = UIWidget.create_definition({
        { pass_type = "texture", style_id = "highlight",
            value = "content/ui/materials/backgrounds/scanner/scanner_decoration_skull",
            style = { hdr = true, color = { 50, 0, 180, 110 }, offset = { -270, 235, 5 } },
        }
    }, "center_pivot", nil, { 44, 44 }),
    title_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text",
            value = "ASTEROIDS",
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
        { pass_type = "text", style_id = "text",
            value = mod:localize("asteroids_controls"),
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
    prefix = "asteroids_game_border",
})

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }


local AsteroidsView = class("AsteroidsView", "BaseView")

local LIGHT_X, LIGHT_Y = -0.70710678, -0.70710678
local SHIP_HULL = { 20, 0, -8, -6, -13, -14, -9, -3, -12, 0, -9, 3, -13, 14, -8, 6 }

local rock_points = {}
local inner_points = {}

function AsteroidsView:init(settings, context)
    AsteroidsView.super.init(self, definitions, settings, context)
    self._game = context.game
    self._no_cursor = true

    self._canvas = Gfx.Canvas.new(GAME_W, GAME_H, 9500)
    self._particles = Gfx.Particles.new(360)
    self._shaker = Gfx.Shaker.new()
    self._time = 0
    self._known_rocks = {}
    self._rock_seen = {}
    self._ship_was_alive = true
    self._death_flash = 0
    self._hull_points = {}
    self._wave_flash = 0
    self._prev_wave = nil
end

function AsteroidsView:dialogue_system() return nil end
function AsteroidsView:is_using_input() return false end

function AsteroidsView:update(dt, t, input_service)
    if self._game then self._game:update(dt) end
    return AsteroidsView.super.update(self, dt, t, input_service)
end

function AsteroidsView:_detect_events(ent)
    local particles = self._particles
    local known = self._known_rocks
    local seen = self._rock_seen
    local rocks = ent.rocks or {}

    for rock in pairs(seen) do seen[rock] = nil end
    for i = 1, #rocks do seen[rocks[i]] = true end

    for rock, info in pairs(known) do
        if not seen[rock] then
            local size = info.size
            local scale = size == 1 and 1.6 or size == 2 and 1.1 or 0.7
            particles:shockwave(info.x, info.y, info.radius * 2.4, 0.45, COLORS.rock_hot, 3 * scale)
            particles:flash(info.x, info.y, info.radius * 2, 0.28, COLORS.rock_hot)
            particles:burst(info.x, info.y, math_floor(8 * scale), 20, 90, 0.6, 1.3, 7 * scale, COLORS.stone, "smoke", 1.2)
            particles:burst(info.x, info.y, math_floor(10 * scale), 50, 230, 0.4, 1, 3.5 * scale, COLORS.stone, "shard", 1.4)
            self._shaker:add(0.08 * scale)
            known[rock] = nil
        end
    end

    for i = 1, #rocks do
        local rock = rocks[i]
        local info = known[rock]
        if not info then
            info = {}
            known[rock] = info
        end
        info.x, info.y, info.size, info.radius = rock.x, rock.y, rock.size, rock.radius
    end

    local ship = ent.ship
    local alive = ship and ship.alive
    if self._ship_was_alive and not alive and ship then
        particles:shockwave(ship.x, ship.y, 130, 0.8, COLORS.flame, 5)
        particles:flash(ship.x, ship.y, 120, 0.5, COLORS.flame_hot)
        particles:burst(ship.x, ship.y, 30, 60, 380, 0.5, 1.3, 2.5, COLORS.flame, "spark", 1.6)
        particles:burst(ship.x, ship.y, 12, 30, 150, 0.8, 1.6, 6, COLORS.hull, "shard", 1, 0)
        self._death_flash = 1
        self._shaker:add(0.9)
    end
    self._ship_was_alive = alive and true or false

    local wave = self._game:wave()
    if self._prev_wave and wave > self._prev_wave then self._wave_flash = 1 end
    self._prev_wave = wave

    if ship and alive and ent.thrusting then
        local back = ship.angle + math_pi
        local bx = ship.x + math_cos(back) * 13
        local by = ship.y + math_sin(back) * 13
        particles:emit(bx, by, math_cos(back) * 60 + ship.vx * 0.3, math_sin(back) * 60 + ship.vy * 0.3, 0.6, 5, COLORS.hull_dark, "smoke", 1.5)
    end
end

function AsteroidsView:_draw_space(canvas, t, stars, sx, sy)
    canvas:vgradient(0, 0, GAME_W, GAME_H, 0.2, COLORS.space_top, COLORS.space_low, 255, 255, 30)

    canvas:glow(150 + math_sin(t * 0.03) * 30, 170, 210, 0.3, COLORS.nebula_a, 30, 7)
    canvas:glow(470, 420 + math_cos(t * 0.025) * 25, 240, 0.31, COLORS.nebula_b, 26, 7)
    canvas:glow(380, 140, 120, 0.32, COLORS.nebula_c, 18, 5)

    -- Distant spiral galaxy.
    local gx, gy = 470, 120
    for arm = 0, 1 do
        for k = 0, 16 do
            local a = t * 0.02 + arm * math_pi + k * 0.32
            local r = 4 + k * 3.4
            canvas:circle(gx + math_cos(a) * r * 1.6, gy + math_sin(a) * r * 0.6, 3.5 - k * 0.12, 0.33, COLORS.star_mid, 34 - k * 1.6, 1, 0, 8)
        end
    end
    canvas:glow(gx, gy, 16, 0.34, COLORS.star_near, 90, 4)

    for i = 1, #stars do
        local s = stars[i]
        local twinkle = (math_sin(s.pulse * 2) + 1) * 0.5
        local color = s.layer == 1 and COLORS.star_far or s.layer == 2 and COLORS.star_mid or COLORS.star_near
        local size = math_min(2.4, s.size * 0.55)
        local x = s.x + sx * s.layer * 0.3
        local y = s.y + sy * s.layer * 0.3
        canvas:rect(x - size * 0.5, y - size * 0.5, size, size, 0.5, color, color[1] * (0.55 + twinkle * 0.45), 1, 0.3)
        if s.layer == 3 then
            canvas:circle(x, y, size * 2.2, 0.49, color, 30 * twinkle, 1, 0, 8)
            if twinkle > 0.75 then
                local f = (twinkle - 0.75) * 24
                canvas:rect(x - f, y - 0.4, f * 2, 0.8, 0.51, color, 120)
                canvas:rect(x - 0.4, y - f, 0.8, f * 2, 0.51, color, 120)
            end
        end
    end
end

function AsteroidsView:_draw_rock(canvas, rock, sx, sy, t)
    local shape = rock.shape
    local count = #shape
    local ca, sa = math_cos(rock.angle), math_sin(rock.angle)
    local cx, cy = rock.x + sx, rock.y + sy
    local radius = rock.radius
    local layer = 3 + rock.size * 0.05

    for i = 1, count do
        local p = shape[i]
        rock_points[i * 2 - 1] = p.x * ca - p.y * sa
        rock_points[i * 2] = p.x * sa + p.y * ca
        inner_points[i * 2 - 1] = rock_points[i * 2 - 1] * 0.58
        inner_points[i * 2] = rock_points[i * 2] * 0.58
    end

    canvas:poly(rock_points, count, layer - 0.1, COLORS.shadow, 110, 1, 0, cx + 5, cy + 6)

    for i = 1, count do
        local j = i == count and 1 or i + 1
        local ax, ay = rock_points[i * 2 - 1], rock_points[i * 2]
        local bx, by = rock_points[j * 2 - 1], rock_points[j * 2]
        local ex, ey = bx - ax, by - ay
        local len = math_sqrt(ex * ex + ey * ey)
        local nx, ny = 0, 0
        if len > 0 then nx, ny = ey / len, -ex / len end
        local lit = math_max(0, nx * LIGHT_X + ny * LIGHT_Y)
        local brightness = 0.28 + lit * 0.72

        canvas:quad(cx + ax, cy + ay, cx + bx, cy + by, cx + inner_points[j * 2 - 1], cy + inner_points[j * 2], cx + inner_points[i * 2 - 1], cy + inner_points[i * 2], layer, COLORS.stone, 255, brightness)
        canvas:line(cx + ax, cy + ay, cx + bx, cy + by, 1.6, layer + 0.02, lit > 0.25 and COLORS.rock_hot or COLORS.rock, 60 + lit * 190, 1, lit * 0.25)
    end

    canvas:poly(inner_points, count, layer + 0.01, COLORS.stone, 255, 0.62)
    canvas:ellipse(cx - radius * 0.18, cy - radius * 0.2, radius * 0.34, radius * 0.28, layer + 0.015, COLORS.stone, 110, 0.95, 0.08, 12)

    for k = 1, rock.size == 3 and 1 or 2 do
        local p = shape[(k * 4) % count + 1]
        local px = (p.x * ca - p.y * sa) * 0.36
        local py = (p.x * sa + p.y * ca) * 0.36
        local cr = radius * (k == 1 and 0.2 or 0.13)
        canvas:circle(cx + px, cy + py, cr, layer + 0.02, COLORS.crater, 190, 1, 0, 10)
        canvas:ring(cx + px, cy + py, cr, 1.2, layer + 0.025, COLORS.stone, 200, 8, math_pi * 0.25, math_pi * 1.25, 1.2)
    end

    if rock.size < 3 then
        local scan = (math_sin(t * 2 + rock.glow) + 1) * 0.5
        canvas:ring(cx, cy, radius * 1.12, 1, layer + 0.03, COLORS.rock, 25 + scan * 35, 16)
    end
end

function AsteroidsView:_draw_target_lock(canvas, rocks, ship, t, sx, sy)
    if not ship or not ship.alive then return end

    local best, best_d = nil, 99999999
    for i = 1, #rocks do
        local r = rocks[i]
        local dx, dy = r.x - ship.x, r.y - ship.y
        local d = dx * dx + dy * dy
        if d < best_d then best, best_d = r, d end
    end
    if not best then return end

    local cx, cy = best.x + sx, best.y + sy
    local s = best.radius * 1.35 + math_sin(t * 6) * 2
    local arm = s * 0.35
    local alpha = 170
    for qx = -1, 1, 2 do
        for qy = -1, 1, 2 do
            local x, y = cx + qx * s, cy + qy * s
            canvas:line(x, y, x - qx * arm, y, 1.4, 4.5, COLORS.lock, alpha)
            canvas:line(x, y, x, y - qy * arm, 1.4, 4.5, COLORS.lock, alpha)
        end
    end
    canvas:line(ship.x + sx, ship.y + sy, cx, cy, 1, 1, COLORS.lock, 22)
end

function AsteroidsView:_draw_bullets(canvas, bullets, sx, sy)
    for i = 1, #bullets do
        local b = bullets[i]
        local k = b.max_life and b.max_life > 0 and b.life / b.max_life or 1
        local tail_x = b.x - b.vx * 0.05
        local tail_y = b.y - b.vy * 0.05
        local dx, dy = b.x - (b.px or b.x), b.y - (b.py or b.y)
        if dx * dx + dy * dy > 2500 then tail_x, tail_y = b.x, b.y end
        canvas:glow_line(tail_x + sx, tail_y + sy, b.x + sx, b.y + sy, 2.2, 5.5, COLORS.bullet_glow, 255 * math_min(1, k * 2.5), 3)
        canvas:glow(b.x + sx, b.y + sy, 9, 5.45, COLORS.bullet_glow, 120 * k, 3)
        canvas:circle(b.x + sx, b.y + sy, 1.8, 5.6, COLORS.bullet, 255, 1, 0, 8)
    end
end

function AsteroidsView:_draw_game_particles(canvas, particles, debris, sx, sy)
    for i = 1, #particles do
        local p = particles[i]
        local k = p.max_life and p.max_life > 0 and p.life / p.max_life or 1
        local kind = p.kind
        local color = kind == "flame" and COLORS.particle_flame or kind == "ship" and COLORS.particle_ship or kind == "muzzle" and COLORS.bullet_glow or COLORS.particle_rock
        local x, y = p.x + sx, p.y + sy
        local size = (p.size or 3) * (0.35 + k * 0.65)

        if kind == "flame" then
            canvas:circle(x, y, size * 1.3, 5.1, color, 60 * k, 1, 0, 8)
            canvas:circle(x, y, size * 0.5, 5.12, COLORS.flame_hot, 230 * k, 1, 0, 6)
        elseif kind == "muzzle" then
            canvas:glow(x, y, size * 1.6, 5.2, color, 200 * k, 3)
        else
            canvas:line(x - p.vx * 0.03, y - p.vy * 0.03, x, y, math_max(0.8, size * 0.45), 5.15, color, color[1] * k, 1, 0.3 * k)
        end
    end

    for i = 1, #debris do
        local d = debris[i]
        local k = d.max_life and d.max_life > 0 and d.life / d.max_life or 1
        local hx = math_cos(d.angle) * d.length * 0.5
        local hy = math_sin(d.angle) * d.length * 0.5
        canvas:line(d.x - hx + sx, d.y - hy + sy, d.x + hx + sx, d.y + hy + sy, 1.6, 5.05, COLORS.debris, COLORS.debris[1] * k)
    end
end

function AsteroidsView:_draw_ship(canvas, ship, thrusting, braking, invulnerable, t, sx, sy)
    if not ship or not ship.alive then return end

    if invulnerable and math_floor(t * 12) % 2 == 0 then
        -- Blink during spawn protection, but keep the shield visible.
        canvas:ring(ship.x + sx, ship.y + sy, 24, 2, 5.9, COLORS.shield, 150, 24, t * 3, t * 3 + math_pi * 1.6)
        return
    end

    local ca, sa = math_cos(ship.angle), math_sin(ship.angle)
    local cx, cy = ship.x + sx, ship.y + sy
    local hull = self._hull_points
    local count = #SHIP_HULL / 2

    for i = 1, count do
        local px, py = SHIP_HULL[i * 2 - 1], SHIP_HULL[i * 2]
        hull[i * 2 - 1] = px * ca - py * sa
        hull[i * 2] = px * sa + py * ca
    end

    local function pt(px, py)
        return cx + px * ca - py * sa, cy + px * sa + py * ca
    end

    if thrusting then
        local flick = 0.8 + (math_sin(t * 47) + math_sin(t * 71)) * 0.12
        local fx1, fy1 = pt(-10, -4)
        local fx2, fy2 = pt(-10, 4)
        local tipx, tipy = pt(-22 - 14 * flick, 0)
        local core_x, core_y = pt(-16 - 8 * flick, 0)
        local gx, gy = pt(-18, 0)
        canvas:glow(gx, gy, 24, 5.6, COLORS.flame, 110, 4)
        canvas:tri(fx1, fy1, fx2, fy2, tipx, tipy, 5.65, COLORS.flame, 220)
        canvas:tri(fx1, fy1, fx2, fy2, core_x, core_y, 5.66, COLORS.flame_hot, 255)
    end

    if braking then
        for side = -1, 1, 2 do
            local bx, by = pt(6, side * 8)
            local ex, ey = pt(14, side * 14)
            canvas:glow_line(bx, by, ex, ey, 1.6, 5.65, COLORS.brake, 180, 2.5)
        end
    end

    canvas:glow(cx, cy, 30, 5.55, COLORS.ship, 40, 4)
    canvas:poly(hull, count, 5.7, COLORS.shadow, 120, 1, 0, cx + 4, cy + 5)

    -- Split hull into lit and shaded halves around the spine.
    local nose_x, nose_y = pt(20, 0)
    local tail_x, tail_y = pt(-12, 0)
    for i = 1, count do
        local j = i == count and 1 or i + 1
        local ax, ay = cx + hull[i * 2 - 1], cy + hull[i * 2]
        local bx, by = cx + hull[j * 2 - 1], cy + hull[j * 2]
        local ex, ey = bx - ax, by - ay
        local len = math_sqrt(ex * ex + ey * ey)
        local nx, ny = 0, 0
        if len > 0 then nx, ny = ey / len, -ex / len end
        local lit = math_max(0, nx * LIGHT_X + ny * LIGHT_Y)
        canvas:tri(cx, cy, ax, ay, bx, by, 5.75, COLORS.hull, 255, 0.35 + lit * 0.65)
        canvas:line(ax, ay, bx, by, 1.2, 5.8, COLORS.ship, 120 + lit * 135, 1, lit * 0.4)
    end

    canvas:line(nose_x, nose_y, tail_x, tail_y, 1, 5.82, COLORS.ship_core, 110)
    local cpx, cpy = pt(5, 0)
    canvas:ellipse(cpx, cpy, 4, 4, 5.85, COLORS.canopy, 255, 0.7, 0, 10)
    local chx, chy = pt(6.5, -1.2)
    canvas:circle(chx, chy, 1.6, 5.86, COLORS.white, 230, 1, 0, 6)

    for side = -1, 1, 2 do
        local lx, ly = pt(-12, side * 13)
        local on = (math_sin(t * 6 + side) + 1) * 0.5
        canvas:circle(lx, ly, 1.8, 5.87, side < 0 and COLORS.lock or COLORS.ship_core, 140 + on * 115, 1, 0, 6)
        canvas:circle(lx, ly, 5, 5.86, side < 0 and COLORS.lock or COLORS.ship_core, on * 50, 1, 0, 8)
    end

    if invulnerable then
        canvas:ring(cx, cy, 24, 2, 5.9, COLORS.shield, 150, 24, t * 3, t * 3 + math_pi * 1.6)
        canvas:glow(cx, cy, 28, 5.52, COLORS.shield, 50, 3)
    end
end

function AsteroidsView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local game = self._game

    if game then
        local score_w = self._widgets_by_name.score_text
        if score_w then score_w.content.text = string.format("Score: %d", game:score()) end

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
    if hsw then hsw.content.text = mod:localize("asteroids_highscore") .. " " .. (mod:get("asteroids_highscore") or 0) end

    local hot_noise = self._widgets_by_name.scanner_noise_hot
    if hot_noise and game then
        local a = 20 + math_floor((math_sin(game:time() * 2.7) + 1) * 12) + math_floor(game:shake() * 80)
        hot_noise.style.noise.color[1] = math_min(150, a)
    end

    AsteroidsView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

    if not game then return end

    dt = math_min(dt or 0.016, 0.05)
    self._time = self._time + dt

    local ent = game:entities()
    self:_detect_events(ent)
    self._particles:update(dt)
    self._shaker:update(dt, 7)
    self._death_flash = math_max(0, self._death_flash - dt * 1.5)
    self._wave_flash = math_max(0, self._wave_flash - dt * 0.8)

    local canvas = self._canvas
    if not canvas:begin(ui_renderer, self:_scenegraph_world_position("game_area")) then return end

    local time = self._time
    local shake = game:shake()
    local sx = math_sin(time * 71) * shake * 6 + self._shaker.x
    local sy = math_sin(time * 93 + 1.2) * shake * 6 + self._shaker.y
    local rocks = ent.rocks or {}

    -- Submission order is priority order when the budget is tight; layers still sort the result.
    self:_draw_space(canvas, time, ent.stars or {}, sx, sy)
    self:_draw_ship(canvas, ent.ship, ent.thrusting, ent.braking, ent.invulnerable, time, sx, sy)
    self:_draw_bullets(canvas, ent.bullets or {}, sx, sy)
    self:_draw_target_lock(canvas, rocks, ent.ship, time, sx, sy)
    for i = 1, #rocks do
        self:_draw_rock(canvas, rocks[i], sx, sy, time)
    end
    self:_draw_game_particles(canvas, ent.particles or {}, ent.debris or {}, sx, sy)
    canvas:set_shake(sx, sy)
    self._particles:draw(canvas, 6)
    canvas:set_shake(0, 0)

    if self._death_flash > 0 then
        canvas:rect(0, 0, GAME_W, GAME_H, 7, COLORS.warning, self._death_flash * 120)
    end
    if self._wave_flash > 0 then
        canvas:sweep(0, 0, GAME_W, GAME_H, (1 - self._wave_flash) * 2, 2, 7.1, COLORS.rock_hot, 150 * self._wave_flash, 160)
    end

    canvas:crt(0, 0, GAME_W, GAME_H, time, 8, { tint = COLORS.rock, vignette_depth = 90, vignette_alpha = 170 })
    canvas:finish()
end

function AsteroidsView:destroy()
    self._canvas = nil
    self._particles = nil
    AsteroidsView.super.destroy(self)
end

return AsteroidsView
