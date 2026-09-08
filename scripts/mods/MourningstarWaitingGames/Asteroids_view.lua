local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")

local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_sin = math.sin
local math_sqrt = math.sqrt

local RENDER_SIZE = 600
local GAME_W = 600
local GAME_H = 600
local STAR_WIDGETS = 90
local ROCK_LINE_WIDGETS = 864 -- 12 starting rocks * 3 * 2 fragments * 12 shape edges.
local BULLET_WIDGETS = 12
local PARTICLE_WIDGETS = 120
local DEBRIS_WIDGETS = 70
local SHIP_LINE_WIDGETS = 12
local TRAIL_WIDGETS = 18

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
}

local SHIP_POINTS = {
    { 18, 0 }, { -12, -12 }, { -7, -4 },
    { -14, 0 }, { -7, 4 }, { -12, 12 },
}
local SHIP_LINES = {
    { 1, 2, 255, 2.0 }, { 2, 3, 210, 1.5 },
    { 3, 4, 180, 1.5 }, { 4, 5, 180, 1.5 },
    { 5, 6, 210, 1.5 }, { 6, 1, 255, 2.0 },
    { 3, 5, 200, 1.5 },
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

local function line_def(thickness)
    return UIWidget.create_definition({
        { pass_type = "triangle", style_id = "tri1",
            style = { color = { 0, 0, 0, 0 }, triangle_corners = { { 0, 0 }, { 0, 0 }, { 0, 0 } } },
        },
        { pass_type = "triangle", style_id = "tri2",
            style = { color = { 0, 0, 0, 0 }, triangle_corners = { { 0, 0 }, { 0, 0 }, { 0, 0 } } },
        },
    }, "game_area", nil, { 1, thickness or 2 })
end

local function circle_def(size)
    return UIWidget.create_definition({
        { pass_type = "circle", style_id = "gfx",
            style = { color = { 0, 0, 0, 0 } },
        }
    }, "game_area", nil, { size or 4, size or 4 })
end

local function triangle_def()
    return UIWidget.create_definition({
        { pass_type = "triangle", style_id = "gfx",
            style = { color = { 0, 0, 0, 0 }, triangle_corners = { { 0, 0 }, { 0, 0 }, { 0, 0 } } },
        }
    }, "game_area", nil, { 1, 1 })
end

local function rect_def(size)
    return UIWidget.create_definition({
        { pass_type = "texture", style_id = "gfx",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 0, 0, 0, 0 } },
        }
    }, "game_area", nil, { size or 4, size or 4 })
end

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

local function set_color(dst, src, alpha)
    dst[1] = alpha or src[1]
    dst[2] = src[2]
    dst[3] = src[3]
    dst[4] = src[4]
end

local function clear_line(w)
    w.style.tri1.color[1] = 0
    w.style.tri2.color[1] = 0
end

local function clear_circle(w)
    w.style.gfx.color[1] = 0
end

local function clip_line(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local t0 = 0
    local t1 = 1

    for edge = 1, 4 do
        local p = edge == 1 and -dx or edge == 2 and dx or edge == 3 and -dy or dy
        local q = edge == 1 and x1 or edge == 2 and GAME_W - x1 or edge == 3 and y1 or GAME_H - y1
        if p == 0 then
            if q < 0 then return nil end
        else
            local r = q / p
            if p < 0 then
                if r > t1 then return nil end
                if r > t0 then t0 = r end
            else
                if r < t0 then return nil end
                if r < t1 then t1 = r end
            end
        end
    end

    return x1 + dx * t0, y1 + dy * t0, x1 + dx * t1, y1 + dy * t1
end

local function draw_line(w, x1, y1, x2, y2, thickness, color, alpha, z)
    x1, y1, x2, y2 = clip_line(x1, y1, x2, y2)

    if not x1 then
        clear_line(w)
        return
    end

    local dx = x2 - x1
    local dy = y2 - y1
    local len = math_sqrt(dx * dx + dy * dy)

    if len <= 0.1 then
        clear_line(w)
        return
    end

    local half = thickness * 0.5
    local nx = -dy / len * half
    local ny = dx / len * half
    local x1a = x1 + nx
    local y1a = y1 + ny
    local x1b = x1 - nx
    local y1b = y1 - ny
    local x2a = x2 + nx
    local y2a = y2 + ny
    local x2b = x2 - nx
    local y2b = y2 - ny

    w.offset[1] = 0
    w.offset[2] = 0
    w.offset[3] = z or 5

    local tri1 = w.style.tri1.triangle_corners
    tri1[1][1], tri1[1][2] = x1a, y1a
    tri1[2][1], tri1[2][2] = x2a, y2a
    tri1[3][1], tri1[3][2] = x2b, y2b

    local tri2 = w.style.tri2.triangle_corners
    tri2[1][1], tri2[1][2] = x1a, y1a
    tri2[2][1], tri2[2][2] = x2b, y2b
    tri2[3][1], tri2[3][2] = x1b, y1b

    set_color(w.style.tri1.color, color, alpha)
    set_color(w.style.tri2.color, color, alpha)
end

local function draw_circle(w, x, y, size, color, alpha, z)
    w.content.size[1] = size
    w.content.size[2] = size
    w.offset[1] = x - size * 0.5
    w.offset[2] = y - size * 0.5
    w.offset[3] = z or 5
    set_color(w.style.gfx.color, color, alpha)
end

local function point_rot(x, y, angle, scale)
    local ca = math_cos(angle)
    local sa = math_sin(angle)

    return x * ca - y * sa, x * sa + y * ca
end

local function color_alpha(base, alpha)
    if alpha < 0 then return 0 end
    if alpha > base[1] then return base[1] end

    return alpha
end

function AsteroidsView:init(settings, context)
    AsteroidsView.super.init(self, definitions, settings, context)
    self._game = context.game
    self._no_cursor = true

    self._star_widgets = {}
    for i = 1, STAR_WIDGETS do
        self._star_widgets[i] = UIWidget.init("ast_star_" .. i, circle_def(3))
    end

    self._rock_line_widgets = {}
    for i = 1, ROCK_LINE_WIDGETS do
        self._rock_line_widgets[i] = UIWidget.init("ast_rock_line_" .. i, line_def(2))
    end

    self._ship_line_widgets = {}
    for i = 1, SHIP_LINE_WIDGETS do
        self._ship_line_widgets[i] = UIWidget.init("ast_ship_line_" .. i, line_def(3))
    end

    self._ship_fill_widget = UIWidget.init("ast_ship_fill", triangle_def())
    self._ship_points = {}
    for i = 1, #SHIP_POINTS do
        self._ship_points[i] = { 0, 0 }
    end

    self._bullet_widgets = {}
    for i = 1, BULLET_WIDGETS do
        self._bullet_widgets[i] = UIWidget.init("ast_bullet_" .. i, line_def(4))
    end

    self._trail_widgets = {}
    for i = 1, TRAIL_WIDGETS do
        self._trail_widgets[i] = UIWidget.init("ast_trail_" .. i, line_def(2))
    end

    self._particle_widgets = {}
    for i = 1, PARTICLE_WIDGETS do
        self._particle_widgets[i] = UIWidget.init("ast_particle_" .. i, circle_def(4))
    end

    self._debris_widgets = {}
    for i = 1, DEBRIS_WIDGETS do
        self._debris_widgets[i] = UIWidget.init("ast_debris_" .. i, line_def(2))
    end

    self._grid_widgets = {}
    for i = 1, 24 do
        self._grid_widgets[i] = UIWidget.init("ast_grid_" .. i, line_def(1))
    end
end

function AsteroidsView:dialogue_system() return nil end
function AsteroidsView:is_using_input() return false end

function AsteroidsView:update(dt, t, input_service)
    if self._game then self._game:update(dt) end
    return AsteroidsView.super.update(self, dt, t, input_service)
end

function AsteroidsView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    if self._game then
        local score_w = self._widgets_by_name.score_text
        if score_w then score_w.content.text = string.format("Score: %d", self._game:score()) end

        local wave_w = self._widgets_by_name.wave_text
        if wave_w then wave_w.content.text = string.format("Wave: %d", self._game:wave()) end

        local lives_w = self._widgets_by_name.lives_text
        if lives_w then lives_w.content.text = string.format("Hull: %d", self._game:lives()) end

        local message_w = self._widgets_by_name.message_text
        if message_w then
            if self._game:is_game_over() then
                message_w.content.text = "GAME OVER"
                message_w.style.text.text_color = COLORS.warning
            else
                local text = self._game:level_text()
                message_w.content.text = text
                if text ~= "" then
                    message_w.style.text.text_color = COLORS.message
                else
                    message_w.style.text.text_color = COLORS.hidden
                end
            end
        end
    end

    local hsw = self._widgets_by_name.highscore_text
    if hsw then hsw.content.text = mod:localize("asteroids_highscore") .. " " .. (mod:get("asteroids_highscore") or 0) end

    local hot_noise = self._widgets_by_name.scanner_noise_hot
    if hot_noise and self._game then
        local a = 20 + math_floor((math_sin(self._game:time() * 2.7) + 1) * 12) + math_floor(self._game:shake() * 80)
        hot_noise.style.noise.color[1] = math_min(150, a)
    end

    AsteroidsView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

    if not self._game then return end

    self:_draw_dynamic(ui_renderer)
end

function AsteroidsView:_draw_dynamic(ui_renderer)
    local ent = self._game:entities()
    local shake = self._game:shake()
    local time = self._game:time()
    local sx = math_sin(time * 71) * shake * 6
    local sy = math_sin(time * 93 + 1.2) * shake * 6

    self:_draw_grid(ui_renderer, sx, sy)
    self:_draw_stars(ui_renderer, ent.stars, sx, sy)
    self:_draw_rocks(ui_renderer, ent.rocks, sx, sy)
    self:_draw_bullets(ui_renderer, ent.bullets, sx, sy)
    self:_draw_debris(ui_renderer, ent.debris, sx, sy)
    self:_draw_particles(ui_renderer, ent.particles, sx, sy)
    self:_draw_ship(ui_renderer, ent.ship, ent.thrusting, ent.braking, ent.invulnerable, sx, sy)
end

function AsteroidsView:_draw_grid(ui_renderer, sx, sy)
    local idx = 1
    local t = self._game:time()
    local drift = (t * 2) % 75

    for x = -75, GAME_W + 75, 75 do
        local w = self._grid_widgets[idx]
        idx = idx + 1
        draw_line(w, x + drift + sx, sy, x + drift + sx, GAME_H + sy, 1, COLORS.grid_dim, 18, 1)
        UIWidget.draw(w, ui_renderer)
    end

    for y = -75, GAME_H + 75, 75 do
        local w = self._grid_widgets[idx]
        idx = idx + 1
        draw_line(w, sx, y + drift + sy, GAME_W + sx, y + drift + sy, 1, COLORS.grid_dim, 14, 1)
        UIWidget.draw(w, ui_renderer)
    end

    for i = 23, 24 do
        local y = i == 23 and 73 or 527
        local w = self._grid_widgets[i]
        draw_line(w, 22, y, 578, y, 1, COLORS.grid, 65, 3)
        UIWidget.draw(w, ui_renderer)
    end
end

function AsteroidsView:_draw_stars(ui_renderer, stars, sx, sy)
    for i = 1, STAR_WIDGETS do
        local star = stars[i]
        local w = self._star_widgets[i]

        if star then
            local color = star.layer == 1 and COLORS.star_far or star.layer == 2 and COLORS.star_mid or COLORS.star_near
            local pulse = (math_sin(star.pulse) + 1) * 0.5
            local size = math_max(1, star.size * 0.45)
            local alpha = color_alpha(color, color[1] * (0.55 + pulse * 0.2))
            local x = star.x + sx * star.layer * 0.2
            local y = star.y + sy * star.layer * 0.2

            if star.layer == 3 then
                draw_circle(w, x, y, size * 3, color, 14 + pulse * 6, 2)
                UIWidget.draw(w, ui_renderer)
            end
            draw_circle(w, x, y, size, color, alpha, 2 + star.layer)
            UIWidget.draw(w, ui_renderer)
        else
            clear_circle(w)
        end
    end
end

function AsteroidsView:_draw_rocks(ui_renderer, rocks, sx, sy)
    local widget_index = 1

    for i = 1, #rocks do
        if widget_index > ROCK_LINE_WIDGETS then break end
        local rock = rocks[i]
        local shape = rock.shape
        local points = #shape
        local thickness = rock.size == 1 and 2.0 or rock.size == 2 and 1.7 or 1.4
        local cx, cy = rock.x + sx, rock.y + sy

        for p = 1, points do
            if widget_index > ROCK_LINE_WIDGETS then break end

            local a = shape[p]
            local b = shape[p == points and 1 or p + 1]
            local ax, ay = point_rot(a.x, a.y, rock.angle)
            local bx, by = point_rot(b.x, b.y, rock.angle)
            local w = self._rock_line_widgets[widget_index]

            -- Inset strata follow the actual silhouette; a fixed light direction shades the rim.
            local light = math_max(0, math_min(1, 0.5 - (ax + bx + ay + by) / (rock.radius * 5)))
            draw_line(w, cx + ax * 0.65, cy + ay * 0.65, cx + bx * 0.65, cy + by * 0.65, rock.radius * 0.3, COLORS.rock_shadow, 100 + light * 50, 6)
            UIWidget.draw(w, ui_renderer)
            draw_line(w, cx + ax * 0.53, cy + ay * 0.53, cx + bx * 0.53, cy + by * 0.53, 1, COLORS.rock, 30 + light * 30, 7)
            UIWidget.draw(w, ui_renderer)
            if p % 3 == 1 then
                draw_line(w, cx + ax * 0.53, cy + ay * 0.53, cx + ax, cy + ay, 1, COLORS.rock, 50, 7)
                UIWidget.draw(w, ui_renderer)
            end
            draw_line(w, cx + ax, cy + ay, cx + bx, cy + by, thickness + 3, COLORS.rock, 24, 7)
            UIWidget.draw(w, ui_renderer)
            draw_line(w, cx + ax, cy + ay, cx + bx, cy + by, thickness, COLORS.rock, 125 + light * 110, 8)
            UIWidget.draw(w, ui_renderer)
            draw_line(w, cx + ax, cy + ay, cx + bx, cy + by, 0.8, COLORS.rock_hot, light * 165, 9)
            UIWidget.draw(w, ui_renderer)
            widget_index = widget_index + 1
        end
    end

    for i = widget_index, ROCK_LINE_WIDGETS do
        clear_line(self._rock_line_widgets[i])
    end
end

function AsteroidsView:_draw_bullets(ui_renderer, bullets, sx, sy)
    for i = 1, BULLET_WIDGETS do
        local b = bullets[i]
        local w = self._bullet_widgets[i]

        if b then
            local dx = b.x - b.px
            local dy = b.y - b.py
            local trail = math_sqrt(dx * dx + dy * dy)

            if trail > 80 then
                dx = 0
                dy = 0
                trail = 8
            elseif trail < 8 then
                trail = 8
            end

            local alpha = 110 + math_floor((b.life / b.max_life) * 145)
            draw_line(w, b.x - dx * 0.8 + sx, b.y - dy * 0.8 + sy, b.x + sx, b.y + sy, 2, COLORS.bullet, alpha, 14)
            UIWidget.draw(w, ui_renderer)
        else
            clear_line(w)
        end
    end

    for i = 1, TRAIL_WIDGETS do
        local b = bullets[i]
        local w = self._trail_widgets[i]

        if b then
            local dx = b.x - b.px
            local dy = b.y - b.py

            if dx * dx + dy * dy <= 6400 then
                draw_line(w, b.px + sx, b.py + sy, b.x + sx, b.y + sy, 7, COLORS.bullet_glow, 48, 13)
                UIWidget.draw(w, ui_renderer)
            else
                clear_line(w)
            end
        else
            clear_line(w)
        end
    end
end

function AsteroidsView:_draw_particles(ui_renderer, particles, sx, sy)
    for i = 1, PARTICLE_WIDGETS do
        local p = particles[i]
        local w = self._particle_widgets[i]

        if p then
            local f = math_max(0, p.life / p.max_life)
            local color = p.kind == "flame" and COLORS.particle_flame or p.kind == "ship" and COLORS.particle_ship or p.kind == "muzzle" and COLORS.bullet or COLORS.particle_rock
            local size = p.size * (0.35 + f)
            local alpha = color_alpha(color, color[1] * f)

            if p.kind ~= "rock" then
                draw_circle(w, p.x + sx, p.y + sy, size * 1.8, color, alpha * 0.12, 6)
                UIWidget.draw(w, ui_renderer)
            end
            draw_circle(w, p.x + sx, p.y + sy, size * 0.7, color, alpha, p.kind == "flame" and 7 or 11)
            UIWidget.draw(w, ui_renderer)
        else
            clear_circle(w)
        end
    end
end

function AsteroidsView:_draw_debris(ui_renderer, debris, sx, sy)
    for i = 1, DEBRIS_WIDGETS do
        local d = debris[i]
        local w = self._debris_widgets[i]

        if d then
            local f = math_max(0, d.life / d.max_life)
            local dx = math_cos(d.angle) * d.length * 0.5
            local dy = math_sin(d.angle) * d.length * 0.5

            draw_line(w, d.x - dx + sx, d.y - dy + sy, d.x + dx + sx, d.y + dy + sy, 2, COLORS.debris, color_alpha(COLORS.debris, COLORS.debris[1] * f), 10)
            UIWidget.draw(w, ui_renderer)
        else
            clear_line(w)
        end
    end
end

function AsteroidsView:_draw_ship(ui_renderer, ship, thrusting, braking, invulnerable, sx, sy)
    for i = 1, SHIP_LINE_WIDGETS do
        clear_line(self._ship_line_widgets[i])
    end

    self._ship_fill_widget.style.gfx.color[1] = 0

    if not ship or not ship.alive then return end

    local blink = invulnerable and math_floor(self._game:time() * 12) % 2 == 0
    if invulnerable and not blink then return end

    local color = invulnerable and COLORS.ship_invuln or COLORS.ship
    local transformed = self._ship_points

    for i = 1, #SHIP_POINTS do
        local px, py = point_rot(SHIP_POINTS[i][1], SHIP_POINTS[i][2], ship.angle)
        transformed[i][1], transformed[i][2] = ship.x + px + sx, ship.y + py + sy
    end

    local fill = self._ship_fill_widget
    fill.offset[1] = 0
    fill.offset[2] = 0
    fill.offset[3] = 15
    fill.style.gfx.triangle_corners[1][1] = transformed[1][1]
    fill.style.gfx.triangle_corners[1][2] = transformed[1][2]
    fill.style.gfx.triangle_corners[2][1] = transformed[2][1]
    fill.style.gfx.triangle_corners[2][2] = transformed[2][2]
    fill.style.gfx.triangle_corners[3][1] = transformed[4][1]
    fill.style.gfx.triangle_corners[3][2] = transformed[4][2]
    set_color(fill.style.gfx.color, color, 85)
    UIWidget.draw(fill, ui_renderer)
    fill.style.gfx.triangle_corners[2][1] = transformed[4][1]
    fill.style.gfx.triangle_corners[2][2] = transformed[4][2]
    fill.style.gfx.triangle_corners[3][1] = transformed[6][1]
    fill.style.gfx.triangle_corners[3][2] = transformed[6][2]
    set_color(fill.style.gfx.color, color, 35)
    UIWidget.draw(fill, ui_renderer)

    for i = 1, #SHIP_LINES do
        local info = SHIP_LINES[i]
        local a = transformed[info[1]]
        local b = transformed[info[2]]
        local w = self._ship_line_widgets[i]

        draw_line(w, a[1], a[2], b[1], b[2], info[4] + 4, color, 28, 14)
        UIWidget.draw(w, ui_renderer)
        draw_line(w, a[1], a[2], b[1], b[2], info[4], i == 7 and COLORS.ship_core or color, info[3], 16)
        UIWidget.draw(w, ui_renderer)
    end

    local nose_x, nose_y = point_rot(11, 0, ship.angle)
    local cockpit_x, cockpit_y = point_rot(-2, 0, ship.angle)
    local cx, cy = ship.x + sx, ship.y + sy
    draw_line(self._ship_line_widgets[10], cx + nose_x, cy + nose_y, cx + cockpit_x, cy + cockpit_y, 4, COLORS.rock_shadow, 255, 16)
    UIWidget.draw(self._ship_line_widgets[10], ui_renderer)
    draw_line(self._ship_line_widgets[11], cx + nose_x, cy + nose_y, cx + cockpit_x, cy + cockpit_y, 1.3, COLORS.ship_core, 245, 17)
    UIWidget.draw(self._ship_line_widgets[11], ui_renderer)

    if thrusting then
        local back_x, back_y = point_rot(-15, 0, ship.angle)
        local l_x, l_y = point_rot(-7, -5, ship.angle)
        local r_x, r_y = point_rot(-7, 5, ship.angle)
        local flame = 23 + math_sin(self._game:time() * 23) * 4 + math_sin(self._game:time() * 37) * 2
        local f_x, f_y = point_rot(-15 - flame, 0, ship.angle)

        fill.offset[3] = 14
        local corners = fill.style.gfx.triangle_corners
        corners[1][1], corners[1][2] = cx + l_x, cy + l_y
        corners[2][1], corners[2][2] = cx + f_x, cy + f_y
        corners[3][1], corners[3][2] = cx + r_x, cy + r_y
        set_color(fill.style.gfx.color, COLORS.flame, 95)
        UIWidget.draw(fill, ui_renderer)
        draw_line(self._ship_line_widgets[8], ship.x + l_x + sx, ship.y + l_y + sy, ship.x + f_x + sx, ship.y + f_y + sy, 1.5, COLORS.flame, 180, 15)
        UIWidget.draw(self._ship_line_widgets[8], ui_renderer)
        draw_line(self._ship_line_widgets[9], ship.x + r_x + sx, ship.y + r_y + sy, ship.x + f_x + sx, ship.y + f_y + sy, 1.5, COLORS.flame, 180, 15)
        UIWidget.draw(self._ship_line_widgets[9], ui_renderer)
        local hot_x, hot_y = point_rot(-15 - flame * 0.6, 0, ship.angle)
        draw_line(self._ship_line_widgets[12], cx + back_x, cy + back_y, cx + hot_x, cy + hot_y, 3, COLORS.flame_hot, 230, 15)
        UIWidget.draw(self._ship_line_widgets[12], ui_renderer)
    elseif braking then
        local f1x, f1y = point_rot(18, -5, ship.angle)
        local f2x, f2y = point_rot(32, -5, ship.angle)
        local f3x, f3y = point_rot(18, 5, ship.angle)
        local f4x, f4y = point_rot(32, 5, ship.angle)

        draw_line(self._ship_line_widgets[8], ship.x + f1x + sx, ship.y + f1y + sy, ship.x + f2x + sx, ship.y + f2y + sy, 2.5, COLORS.brake, 170, 15)
        UIWidget.draw(self._ship_line_widgets[8], ui_renderer)
        draw_line(self._ship_line_widgets[9], ship.x + f3x + sx, ship.y + f3y + sy, ship.x + f4x + sx, ship.y + f4y + sy, 2.5, COLORS.brake, 170, 15)
        UIWidget.draw(self._ship_line_widgets[9], ui_renderer)
    end
end

function AsteroidsView:destroy() AsteroidsView.super.destroy(self) end

return AsteroidsView
