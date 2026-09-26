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
local math_sqrt = math.sqrt

local GRID = 24
local COLS = 25
local ROWS = 25
local RENDER_SIZE = 600
local BORDER_X = (RENDER_SIZE - COLS * GRID) / 2
local BORDER_Y = (RENDER_SIZE - ROWS * GRID) / 2 + 20

local COLORS = {
    title      = { 255, 178, 243, 208 },
    hud        = { 255, 124, 225, 181 },
    hud_dim    = { 225, 79, 167, 137 },
    head       = { 255, 195, 248, 210 },
    head_glow  = { 42, 78, 232, 160 },
    snake      = { 255, 45, 194, 135 },
    snake_tail = { 255, 34, 124, 101 },
    apple      = { 255, 245, 160, 89 },
    apple_glow = { 65, 244, 111, 53 },
    grid       = { 26, 40, 115, 97 },
    border     = { 140, 61, 177, 136 },
    bg         = { 255, 3, 13, 15 },
    bg_top     = { 255, 4, 20, 20 },
    bg_low     = { 255, 1, 7, 9 },
    body_dark  = { 255, 8, 60, 44 },
    belly      = { 255, 150, 245, 190 },
    scale      = { 255, 18, 110, 80 },
    eye        = { 255, 245, 255, 235 },
    pupil      = { 255, 2, 10, 8 },
    tongue     = { 255, 255, 70, 90 },
    white      = { 255, 255, 255, 255 },
    death      = { 255, 255, 60, 45 },
    data       = { 255, 70, 255, 170 },
    shadow     = { 255, 0, 0, 0 },
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
	board_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { COLS * GRID, ROWS * GRID }, position = { 0, 20, 5 },
	},
	title_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 240, 24 }, position = { 0, -309, 12 },
	},
	score_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 160, 20 }, position = { 205, -309, 12 },
	},
	controls_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 500, 20 }, position = { 0, 340, 12 },
	},
	highscore_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 500, 20 }, position = { 0, 362, 12 },
	},
}

local widget_definitions = {
	bg = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/default_square",
			style = { hdr = true, color = COLORS.bg },
		}
	}, "board_area", nil, { COLS * GRID, ROWS * GRID }),
	scanner_noise = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
			style = { hdr = true, color = { 60, 0, 128, 0 }, offset = { -300, -300, 1 } },
		}
	}, "center_pivot", nil, { 600, 600 }),
	scanner_noise_hot = UIWidget.create_definition({
		{ pass_type = "texture", style_id = "noise",
			value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
			style = { hdr = true, color = { 28, 120, 220, 80 }, offset = { -300, -300, 2 } },
		}
	}, "center_pivot", nil, { 600, 600 }),
	border_top = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/default_square",
			style = { hdr = true, color = COLORS.border, offset = { 0, 0, 8 } },
		}
	}, "board_area", nil, { COLS * GRID, 2 }),
	border_bottom = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/default_square",
			style = { hdr = true, color = COLORS.border, offset = { 0, ROWS * GRID - 2, 8 } },
		}
	}, "board_area", nil, { COLS * GRID, 2 }),
	border_left = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/default_square",
			style = { hdr = true, color = COLORS.border, offset = { 0, 0, 8 } },
		}
	}, "board_area", nil, { 2, ROWS * GRID }),
	border_right = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/default_square",
			style = { hdr = true, color = COLORS.border, offset = { COLS * GRID - 2, 0, 8 } },
		}
	}, "board_area", nil, { 2, ROWS * GRID }),
	title_text = UIWidget.create_definition({
		{ pass_type = "text", style_id = "text",
            value = "SNAKE",
            style = { font_size = 22, font_type = "machine_medium",
				text_horizontal_alignment = "center", text_vertical_alignment = "center",
				text_color = COLORS.title, offset = { 0, 0, 1 } },
		}
    }, "title_area", nil, { 240, 24 }),
	score_text = UIWidget.create_definition({
		{ pass_type = "text", style_id = "text",
			value = "", value_id = "text",
			style = { font_size = 16, font_type = "machine_medium",
				text_horizontal_alignment = "center", text_vertical_alignment = "center",
				text_color = COLORS.hud, offset = { 0, 0, 1 } },
		}
	}, "score_area", nil, { 160, 20 }),
	decoration_inquisition = UIWidget.create_definition({
		{ pass_type = "texture", style_id = "highlight",
			value = "content/ui/materials/backgrounds/scanner/scanner_decoration_inquisition",
			style = { hdr = true, color = { 60, 0, 200, 0 }, offset = { -18, -285, 2 } },
		}
	}, "center_pivot", nil, { 36, 36 }),
	decoration_left_mark = UIWidget.create_definition({
		{ pass_type = "texture", style_id = "highlight",
			value = "content/ui/materials/backgrounds/scanner/scanner_decoration_left_mark",
			style = { hdr = true, color = { 40, 0, 180, 0 }, offset = { -285, -265, 2 } },
		}
	}, "center_pivot", nil, { 30, 60 }),
	decoration_right_mark = UIWidget.create_definition({
		{ pass_type = "texture", style_id = "highlight",
			value = "content/ui/materials/backgrounds/scanner/scanner_decoration_right_mark",
			style = { hdr = true, color = { 40, 0, 180, 0 }, offset = { 255, -265, 2 } },
		}
	}, "center_pivot", nil, { 30, 60 }),
	decoration_eagle = UIWidget.create_definition({
		{ pass_type = "texture", style_id = "highlight",
			value = "content/ui/materials/backgrounds/scanner/scanner_decoration_eagle",
			style = { hdr = true, color = { 40, 0, 180, 0 }, offset = { 250, 250, 2 } },
		}
	}, "center_pivot", nil, { 60, 60 }),
	decoration_skull = UIWidget.create_definition({
		{ pass_type = "texture", style_id = "highlight",
			value = "content/ui/materials/backgrounds/scanner/scanner_decoration_skull",
			style = { hdr = true, color = { 40, 0, 180, 0 }, offset = { -270, 255, 2 } },
		}
	}, "center_pivot", nil, { 30, 30 }),
	controls_text = UIWidget.create_definition({
		{ pass_type = "text", style_id = "text",
			value = mod:localize("snake_controls"),
			style = { font_size = 14, font_type = "machine_medium",
				text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud_dim, offset = { 0, 0, 1 } },
		}
	}, "controls_area", nil, { 500, 20 }),
	highscore_text = UIWidget.create_definition({
		{ pass_type = "text", style_id = "text",
			value = "", value_id = "text",
			style = { font_size = 14, font_type = "machine_medium",
				text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud, offset = { 0, 0, 1 } },
		}
	}, "highscore_area", nil, { 500, 20 }),
}

AuspexFrame.add(widget_definitions, {
    render_size = RENDER_SIZE,
    outline_size = { 640, 740 },
    center = { 0, 20 },
})
AuspexFrame.add_inner_border(widget_definitions, {
    render_size = RENDER_SIZE,
    size = { COLS * GRID, ROWS * GRID },
    center = { 0, 20 },
    prefix = "snake_board_border",
})

for name, y in pairs({ header = -333, footer = 326 }) do
    widget_definitions["hud_panel_" .. name] = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 250, 5, 18, 20 }, size = { 596, 50 }, offset = { -298, y, 8 } } },
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 130, 60, 151, 121 }, size = { 596, 1 }, offset = { -298, y, 9 } } },
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.hud, size = { 24, 2 }, offset = { -298, y, 10 } } },
    }, "center_pivot", nil, { 596, 50 })
end

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }

local SnakeView = class("SnakeView", "BaseView")

local BOARD_W = COLS * GRID
local BOARD_H = ROWS * GRID
local HALF = GRID * 0.5

function SnakeView:init(settings, context)
    SnakeView.super.init(self, definitions, settings, context)
    self._game = context.game
    self._no_cursor = true

    self._canvas = Gfx.Canvas.new(BOARD_W, BOARD_H, 7000)
    self._particles = Gfx.Particles.new(320)
    self._shaker = Gfx.Shaker.new()
    self._time = 0
    self._points = {}
    self._eat_flash = 0
    self._bulges = {}
    self._apple_spawn = 1
    self._death_time = nil
    self._last_score = nil
    self._last_apple_x = nil
    self._last_apple_y = nil
    self._body_color = { 255, 0, 0, 0 }
    self._rain = {}
    for i = 1, 26 do
        self._rain[i] = { x = (i * 97.3) % BOARD_W, y = (i * 211.7) % BOARD_H, speed = 30 + (i * 37) % 70, len = 20 + (i * 13) % 50 }
    end
end

function SnakeView:dialogue_system() return nil end
function SnakeView:is_using_input() return false end

function SnakeView:update(dt, t, input_service)
    if self._game then self._game:update(dt) end
    return SnakeView.super.update(self, dt, t, input_service)
end

-- Interpolated body points: every segment glides from its previous cell.
function SnakeView:_build_points(cells, fraction)
    local points = self._points
    local count = #cells

    for i = 1, count do
        local p = points[i]
        if not p then
            p = {}
            points[i] = p
        end

        local c = cells[i]
        local x, y = c.x + HALF, c.y + HALF
        local from = cells[i + 1]

        if from and i < count then
            local fx, fy = from.x + HALF, from.y + HALF
            if math_abs(fx - x) <= GRID and math_abs(fy - y) <= GRID then
                x = fx + (x - fx) * fraction
                y = fy + (y - fy) * fraction
            end
        end

        p.x, p.y = x, y
    end

    for i = count + 1, #points do
        points[i] = nil
    end

    return points, count
end

function SnakeView:_detect_events(cells)
    local game = self._game
    local score = game:score()
    local ax, ay = game:get_apple()

    if self._last_score and score > self._last_score then
        local ex, ey = (self._last_apple_x or ax) + HALF, (self._last_apple_y or ay) + HALF
        local particles = self._particles
        particles:burst(ex, ey, 34, 80, 330, 0.3, 0.8, 2, COLORS.apple, "spark", 3)
        particles:burst(ex, ey, 14, 20, 110, 0.6, 1.2, 3, COLORS.data, "ember", 1.5, -20)
        particles:shockwave(ex, ey, 60, 0.45, COLORS.apple, 3)
        particles:flash(ex, ey, 46, 0.25, COLORS.apple)
        self._eat_flash = 1
        self._bulges[#self._bulges + 1] = 0
        self._apple_spawn = 0
        self._shaker:add(0.22)
    elseif self._last_apple_x and (ax ~= self._last_apple_x or ay ~= self._last_apple_y) then
        self._apple_spawn = 0
    end

    if game:is_game_over() then
        if not self._death_time then
            self._death_time = 0
            local particles = self._particles
            for i = 1, #cells, math_max(1, math_floor(#cells / 40)) do
                local c = cells[i]
                particles:burst(c.x + HALF, c.y + HALF, 3, 40, 200, 0.5, 1.4, 3, i == 1 and COLORS.death or COLORS.snake, "shard", 1.8, 60)
            end
            local head = cells[1]
            if head then
                particles:shockwave(head.x + HALF, head.y + HALF, 140, 0.8, COLORS.death, 4)
                particles:flash(head.x + HALF, head.y + HALF, 90, 0.5, COLORS.death)
            end
            self._shaker:add(0.9)
        end
    else
        self._death_time = nil
    end

    self._last_score = score
    self._last_apple_x, self._last_apple_y = ax, ay
end

function SnakeView:_draw_board(canvas, t, head_x, head_y)
    canvas:vgradient(0, 0, BOARD_W, BOARD_H, 0.2, COLORS.bg_top, COLORS.bg_low, 255, 255, 30)

    for i = 1, #self._rain do
        local r = self._rain[i]
        local y = (r.y + t * r.speed) % (BOARD_H + r.len) - r.len
        canvas:vgradient(r.x, y, 1.5, r.len, 0.3, COLORS.data, COLORS.data, 0, 38, 5)
    end

    for row = 0, ROWS - 1 do
        local cy = row * GRID + HALF
        for col = 0, COLS - 1 do
            local cx = col * GRID + HALF
            local dx, dy = cx - head_x, cy - head_y
            local d2 = dx * dx + dy * dy
            local lit = d2 < 14400 and (1 - math_sqrt(d2) / 120) or 0
            local wave = (math_sin(t * 2 + col * 0.45 - row * 0.3) + 1) * 0.5
            local alpha = 10 + wave * 8 + lit * lit * 70

            if (row + col) % 2 == 0 then
                canvas:rect(col * GRID + 1, row * GRID + 1, GRID - 2, GRID - 2, 0.35, COLORS.grid, alpha * 0.9)
            end

            canvas:rect(col * GRID - 1, row * GRID - 1, 2, 2, 0.4, COLORS.hud, 25 + lit * 150)
        end
    end
end

function SnakeView:_draw_apple(canvas, t)
    local ax, ay = self._game:get_apple()
    local cx, cy = ax + HALF, ay + HALF
    local spawn = self._apple_spawn
    local pulse = (math_sin(t * 5) + 1) * 0.5
    local grow = spawn < 1 and (1 - (1 - spawn) ^ 3) or 1

    if spawn < 1 then
        canvas:ring(cx, cy, 8 + (1 - spawn) * 40, 2, 3.4, COLORS.apple, 220 * (1 - spawn))
    end

    canvas:glow(cx, cy, (26 + pulse * 6) * grow, 3.0, COLORS.apple_glow, 170)

    for i = 0, 3 do
        local a0 = t * 1.4 + i * math_pi * 0.5
        canvas:ring(cx, cy, 15 * grow, 1.4, 3.3, COLORS.apple, 180, 5, a0, a0 + 0.8)
    end

    canvas:circle(cx, cy, 8 * grow, 3.4, COLORS.apple, 255, 0.55, 0, 18)
    canvas:circle(cx - 0.5, cy - 0.8, 7 * grow, 3.41, COLORS.apple, 255, 1, 0, 18)
    canvas:circle(cx - 2.5, cy - 3, 3 * grow, 3.42, COLORS.apple, 230, 1, 0.7, 10)
    canvas:circle(cx - 3, cy - 3.5, 1.2 * grow, 3.43, COLORS.white, 240, 1, 0, 8)
    canvas:line(cx, cy - 7 * grow, cx + 2.5, cy - 11 * grow, 1.6, 3.44, COLORS.snake, 230)

    for i = 0, 2 do
        local a = t * 2.6 + i * math_pi * 2 / 3
        local ox = cx + math_cos(a) * 19 * grow
        local oy = cy + math_sin(a) * 19 * grow * 0.55
        canvas:circle(ox, oy, 3, 3.35, COLORS.apple_glow, 120)
        canvas:rect(ox - 1, oy - 1, 2, 2, 3.36, COLORS.white, 230)
    end
end

function SnakeView:_segment_color(k)
    local c = self._body_color
    Gfx.Canvas.lerp_color(c, COLORS.snake, COLORS.snake_tail, k)
    c[1] = 255
    return c
end

function SnakeView:_draw_snake(canvas, points, count, t, dead_fade)
    if count == 0 then return end

    local layer = 4
    local alpha = 255 * dead_fade
    local bulges = self._bulges

    -- Soft drop shadow first.
    for i = 1, count - 1 do
        local p, q = points[i], points[i + 1]
        if math_abs(p.x - q.x) <= GRID and math_abs(p.y - q.y) <= GRID then
            canvas:line(p.x + 3, p.y + 4, q.x + 3, q.y + 4, 18, layer - 0.5, COLORS.shadow, 110 * dead_fade)
        end
    end

    for pass = 1, 3 do
        for i = count, 1, -1 do
            local p = points[i]
            local q = points[i + 1]
            local k = count > 1 and (i - 1) / (count - 1) or 0
            local taper = 1 - k * 0.35
            local bulge = 0

            for b = 1, #bulges do
                local d = math_abs(bulges[b] - i)
                if d < 2 then bulge = math_max(bulge, (2 - d) * 2.5) end
            end

            local width = (18 * taper + bulge)
            local color = self:_segment_color(k)
            local connected = q and i < count and math_abs(p.x - q.x) <= GRID and math_abs(p.y - q.y) <= GRID

            if pass == 1 then
                if connected then canvas:line(p.x, p.y, q.x, q.y, width, layer, COLORS.body_dark, alpha) end
                canvas:circle(p.x, p.y, width * 0.5, layer, COLORS.body_dark, alpha, 1, 0, 12)
            elseif pass == 2 then
                if connected then canvas:line(p.x, p.y, q.x, q.y, width - 5, layer + 0.1, color, alpha) end
                canvas:circle(p.x, p.y, (width - 5) * 0.5, layer + 0.1, color, alpha, 1, 0, 12)
            else
                if connected then
                    canvas:line(p.x - 2.5, p.y - 2.5, q.x - 2.5, q.y - 2.5, 3 * taper, layer + 0.2, color, alpha * 0.8, 1, 0.55)
                end
                if i % 2 == 0 then
                    local shimmer = (math_sin(t * 6 - i * 0.7) + 1) * 0.5
                    canvas:circle(p.x + 1, p.y + 1, 2.6 * taper, layer + 0.25, COLORS.scale, alpha * (0.6 + shimmer * 0.4), 1, shimmer * 0.4, 6)
                end
            end
        end
    end

    local head = points[1]
    local dx, dy = self._game:get_dir()
    local len = math_sqrt(dx * dx + dy * dy)
    if len > 0 then dx, dy = dx / len, dy / len else dx, dy = 1, 0 end
    local sx, sy = -dy, dx

    canvas:glow(head.x, head.y, 30 + self._eat_flash * 16, layer - 0.2, COLORS.head_glow, 150 * dead_fade)
    canvas:ellipse(head.x + dx * 2, head.y + dy * 2, 11 + math_abs(dx) * 2, 11 + math_abs(dy) * 2, layer + 0.3, COLORS.body_dark, alpha, 1, 0, 16)
    canvas:ellipse(head.x + dx * 2, head.y + dy * 2, 9 + math_abs(dx) * 2, 9 + math_abs(dy) * 2, layer + 0.31, COLORS.head, alpha, 0.85, 0, 16)
    canvas:circle(head.x + dx * 1 - sx * 3, head.y + dy * 1 - sy * 3, 4, layer + 0.32, COLORS.head, alpha * 0.8, 1, 0.5, 8)

    if self._eat_flash > 0 then
        canvas:circle(head.x, head.y, 12, layer + 0.33, COLORS.white, self._eat_flash * 170 * dead_fade)
    end

    for side = -1, 1, 2 do
        local ex = head.x + dx * 4 + sx * side * 5
        local ey = head.y + dy * 4 + sy * side * 5
        canvas:circle(ex, ey, 3.4, layer + 0.34, COLORS.eye, alpha, 1, 0, 8)
        canvas:circle(ex + dx * 1.2, ey + dy * 1.2, 1.8, layer + 0.35, COLORS.pupil, alpha, 1, 0, 6)
        canvas:rect(ex - 1.2, ey - 1.4, 1, 1, layer + 0.36, COLORS.white, alpha)
    end

    local tongue = math_sin(t * 3.2)
    if tongue > 0.55 and dead_fade >= 1 then
        local reach = 7 + (tongue - 0.55) * 18
        local tx, ty = head.x + dx * (11 + reach), head.y + dy * (11 + reach)
        canvas:line(head.x + dx * 11, head.y + dy * 11, tx, ty, 1.4, layer + 0.29, COLORS.tongue, 230)
        canvas:line(tx, ty, tx + dx * 3 + sx * 3, ty + dy * 3 + sy * 3, 1.1, layer + 0.29, COLORS.tongue, 230)
        canvas:line(tx, ty, tx + dx * 3 - sx * 3, ty + dy * 3 - sy * 3, 1.1, layer + 0.29, COLORS.tongue, 230)
    end
end

function SnakeView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local game = self._game
    local hsw = self._widgets_by_name.highscore_text
    if hsw then hsw.content.text = mod:localize("snake_highscore") .. " " .. (mod:get("snake_highscore") or 0) end
    local score_w = self._widgets_by_name.score_text
    if score_w and game then
        score_w.content.text = string.format("Score: %d", game:score())
    end
    local hot_noise = self._widgets_by_name.scanner_noise_hot
    if hot_noise and game then
        hot_noise.style.noise.color[1] = 12 + math_min(game:score(), 12) + math_floor(self._shaker.trauma * 60)
    end

    SnakeView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

    if not game then return end

    dt = math_min(dt or 0.016, 0.05)
    self._time = self._time + dt

    local cells = game:get_cells()
    self:_detect_events(cells)
    self._particles:update(dt)
    self._shaker:update(dt, 9)
    self._eat_flash = math_max(0, self._eat_flash - dt * 3.5)
    self._apple_spawn = math_min(1, self._apple_spawn + dt * 2.2)
    if self._death_time then self._death_time = self._death_time + dt end

    local bulges = self._bulges
    for i = #bulges, 1, -1 do
        bulges[i] = bulges[i] + dt * 26
        if bulges[i] > #cells + 2 then table.remove(bulges, i) end
    end

    local canvas = self._canvas
    if not canvas:begin(ui_renderer, self:_scenegraph_world_position("board_area")) then return end

    local time = self._time
    local points, count = self:_build_points(cells, game.tick_fraction and game:tick_fraction() or 1)
    local head = points[1]
    local hx, hy = head and head.x or BOARD_W * 0.5, head and head.y or BOARD_H * 0.5

    self:_draw_board(canvas, time, hx, hy)
    canvas:set_shake(self._shaker.x, self._shaker.y)
    self:_draw_apple(canvas, time)

    local dead_fade = 1
    if self._death_time then
        dead_fade = math_max(0, 1 - self._death_time * 1.6)
    end
    if dead_fade > 0 then
        self:_draw_snake(canvas, points, count, time, dead_fade)
    end

    self._particles:draw(canvas, 6)
    canvas:set_shake(0, 0)

    if self._death_time then
        local k = math_max(0, 1 - self._death_time * 0.8)
        canvas:rect(0, 0, BOARD_W, BOARD_H, 6.8, COLORS.death, 60 * k + 18)
        local glitch = math_floor(time * 20)
        for i = 1, 5 do
            local gy = (glitch * 137 + i * 211) % BOARD_H
            canvas:rect(0, gy, BOARD_W, 2 + (glitch + i) % 4, 6.85, COLORS.death, 40)
        end
    end

    canvas:crt(0, 0, BOARD_W, BOARD_H, time, 7, { tint = COLORS.snake, vignette_depth = 80, vignette_alpha = 150 })
    canvas:finish()
end

function SnakeView:destroy()
    self._canvas = nil
    self._particles = nil
    SnakeView.super.destroy(self)
end

return SnakeView
