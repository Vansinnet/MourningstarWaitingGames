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

local BOARD_W = 600
local BOARD_H = 400
local PADDLE_W = 10
local PADDLE_H = 70
local BALL_SIZE = 12
local RENDER_SIZE = 600
local OFFSET_Y = (RENDER_SIZE - BOARD_H) / 2

local COLORS = {
    bg          = { 255, 4, 14, 18 },
    paddle      = { 255, 91, 222, 180 },
    paddle_glow = { 38, 41, 205, 150 },
    cpu         = { 255, 232, 149, 105 },
    cpu_glow    = { 38, 220, 103, 67 },
    ball        = { 255, 238, 255, 244 },
    ball_glow   = { 55, 120, 229, 195 },
    net         = { 105, 78, 158, 143 },
    grid        = { 115, 48, 130, 112 },
    hud         = { 255, 131, 233, 192 },
    hud_dim     = { 220, 80, 161, 139 },
    title       = { 255, 181, 240, 210 },
    court_top   = { 255, 4, 22, 27 },
    court_low   = { 255, 1, 7, 10 },
    dot         = { 255, 90, 220, 185 },
    white       = { 255, 255, 255, 255 },
    spark_hot   = { 255, 255, 236, 170 },
    fast        = { 255, 255, 170, 90 },
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
		size = { BOARD_W, BOARD_H }, position = { 0, 0, 5 },
	},
	title_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 500, 20 }, position = { 0, -270, 12 },
	},
	score_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 200, 20 }, position = { -150, -220, 12 },
	},
	cpu_score_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 200, 20 }, position = { 150, -220, 12 },
	},
	level_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 200, 20 }, position = { 0, -240, 12 },
	},
	controls_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 500, 20 }, position = { 0, 220, 12 },
	},
	highscore_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 500, 20 }, position = { 0, 240, 12 },
	},
}

local widget_definitions = {
	panel_bg = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 250, 3, 10, 13 } },
		}
	}, "scanner_base", nil, { RENDER_SIZE, RENDER_SIZE }),
	bg = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.bg },
		}
	}, "game_area", nil, { BOARD_W, BOARD_H }),
	scanner_noise = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
			style = { hdr = true, color = { 60, 0, 128, 0 }, offset = { -300, -300, 1 } },
		}
	}, "center_pivot", nil, { 600, 600 }),
	scanner_noise_hot = UIWidget.create_definition({
		{ pass_type = "texture", style_id = "noise",
			value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
			style = { hdr = true, color = { 32, 100, 210, 90 }, offset = { -300, -300, 2 } },
		}
	}, "center_pivot", nil, { 600, 600 }),
	border_top = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/default_square",
			style = { hdr = true, color = COLORS.grid, offset = { 0, 0, 8 } },
		}
	}, "game_area", nil, { BOARD_W, 2 }),
	border_bottom = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/default_square",
			style = { hdr = true, color = COLORS.grid, offset = { 0, BOARD_H - 2, 8 } },
		}
	}, "game_area", nil, { BOARD_W, 2 }),
	border_left = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/default_square",
			style = { hdr = true, color = COLORS.grid, offset = { 0, 0, 8 } },
		}
	}, "game_area", nil, { 2, BOARD_H }),
	border_right = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/default_square",
			style = { hdr = true, color = COLORS.grid, offset = { BOARD_W - 2, 0, 8 } },
		}
	}, "game_area", nil, { 2, BOARD_H }),
	title_text = UIWidget.create_definition({
		{ pass_type = "text", style_id = "text",
            value = "PONG",
            style = { font_size = 22, font_type = "machine_medium",
				text_horizontal_alignment = "center", text_vertical_alignment = "center",
				text_color = COLORS.title, offset = { 0, 0, 1 } },
		}
	}, "title_area", nil, { 500, 20 }),
	score_text = UIWidget.create_definition({
		{ pass_type = "text", style_id = "text", value = "", value_id = "text",
			style = { font_size = 20, font_type = "machine_medium",
				text_horizontal_alignment = "center", text_vertical_alignment = "center",
				text_color = COLORS.hud, offset = { 0, 0, 1 } },
		}
	}, "score_area", nil, { 200, 20 }),
	cpu_score_text = UIWidget.create_definition({
		{ pass_type = "text", style_id = "text", value = "", value_id = "text",
			style = { font_size = 20, font_type = "machine_medium",
				text_horizontal_alignment = "center", text_vertical_alignment = "center",
				text_color = COLORS.cpu, offset = { 0, 0, 1 } },
		}
	}, "cpu_score_area", nil, { 200, 20 }),
	level_text = UIWidget.create_definition({
		{ pass_type = "text", style_id = "text", value = "", value_id = "text",
			style = { font_size = 14, font_type = "machine_medium",
				text_horizontal_alignment = "center", text_vertical_alignment = "center",
				text_color = COLORS.hud, offset = { 0, 0, 1 } },
		}
	}, "level_area", nil, { 200, 20 }),
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
			value = mod:localize("pong_controls"),
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
    outline_size = { 640, 590 },
    center = { 0, -15 },
})
AuspexFrame.add_inner_border(widget_definitions, {
    render_size = RENDER_SIZE,
    size = { BOARD_W, BOARD_H },
    prefix = "pong_game_border",
})

for side = 1, 2 do
    local accent = side == 1 and COLORS.paddle or COLORS.cpu
    widget_definitions["score_panel_" .. side] = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 255, 10, 25, 27 }, size = { 200, 34 }, offset = { 0, -7, -2 } } },
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = accent, size = { 32, 2 }, offset = { 84, 26, -1 } } },
    }, side == 1 and "score_area" or "cpu_score_area", nil, { 200, 34 })
end

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }

local PongView = class("PongView", "BaseView")

local TRAIL_POINTS = 18

function PongView:init(settings, context)
    PongView.super.init(self, definitions, settings, context)
    self._game = context.game
    self._no_cursor = true

    self._canvas = Gfx.Canvas.new(BOARD_W, BOARD_H, 4200)
    self._particles = Gfx.Particles.new(260)
    self._shaker = Gfx.Shaker.new()
    self._time = 0
    self._trail = {}
    for i = 1, TRAIL_POINTS do
        self._trail[i] = { x = BOARD_W * 0.5, y = BOARD_H * 0.5 }
    end
    self._player_flash = 0
    self._cpu_flash = 0
    self._score_flash_left = 0
    self._score_flash_right = 0
    self._prev = nil
    self._ball_color = { 255, 0, 0, 0 }
end

function PongView:dialogue_system() return nil end
function PongView:is_using_input() return false end

function PongView:update(dt, t, input_service)
    if self._game then self._game:update(dt) end
    return PongView.super.update(self, dt, t, input_service)
end

function PongView:_detect_events(bx, by)
    local game = self._game
    local prev = self._prev
    local score, cpu_score = game:score(), game:cpu_score()

    if not prev then
        self._prev = { x = bx, y = by, vx = 0, vy = 0, score = score, cpu = cpu_score }
        return
    end

    local particles = self._particles
    local vx = bx - prev.x
    local vy = by - prev.y
    local teleported = vx * vx + vy * vy > 6400

    if score > prev.score then
        self:_goal_burst(BOARD_W - 4, prev.y, math_pi, COLORS.paddle)
        self._score_flash_right = 1
    elseif cpu_score > prev.cpu then
        self:_goal_burst(4, prev.y, 0, COLORS.cpu)
        self._score_flash_left = 1
    elseif not teleported then
        if prev.vx < 0 and vx > 0 and bx < BOARD_W * 0.3 then
            self._player_flash = 1
            particles:burst(bx - BALL_SIZE * 0.5, by, 18, 90, 360, 0.2, 0.5, 1.6, COLORS.paddle, "spark", 3.5, 0, 0, 1.9)
            particles:shockwave(bx - BALL_SIZE * 0.5, by, 34, 0.35, COLORS.ball, 2.5)
            particles:flash(bx, by, 26, 0.18, COLORS.paddle)
            self._shaker:add(0.18)
        elseif prev.vx > 0 and vx < 0 and bx > BOARD_W * 0.7 then
            self._cpu_flash = 1
            particles:burst(bx + BALL_SIZE * 0.5, by, 18, 90, 360, 0.2, 0.5, 1.6, COLORS.cpu, "spark", 3.5, 0, math_pi, 1.9)
            particles:shockwave(bx + BALL_SIZE * 0.5, by, 34, 0.35, COLORS.ball, 2.5)
            particles:flash(bx, by, 26, 0.18, COLORS.cpu)
            self._shaker:add(0.18)
        end

        if prev.vy < 0 and vy > 0 and by < 40 then
            particles:burst(bx, 1, 9, 60, 220, 0.15, 0.35, 1.2, COLORS.ball_glow, "spark", 4, 0, math_pi * 0.5, 1.8)
        elseif prev.vy > 0 and vy < 0 and by > BOARD_H - 40 then
            particles:burst(bx, BOARD_H - 1, 9, 60, 220, 0.15, 0.35, 1.2, COLORS.ball_glow, "spark", 4, 0, -math_pi * 0.5, 1.8)
        end
    end

    if teleported then
        for i = 1, TRAIL_POINTS do
            self._trail[i].x = bx
            self._trail[i].y = by
        end
        vx, vy = 0, 0
    end

    if vx ~= 0 then prev.vx = vx end
    if vy ~= 0 then prev.vy = vy end
    prev.x, prev.y = bx, by
    prev.score, prev.cpu = score, cpu_score
end

function PongView:_goal_burst(x, y, angle, color)
    local particles = self._particles
    particles:burst(x, y, 46, 120, 520, 0.35, 0.95, 2.2, color, "spark", 2.2, 0, angle, 2.4)
    particles:burst(x, y, 16, 30, 160, 0.6, 1.3, 3.5, COLORS.spark_hot, "ember", 1.6, 25, angle, 2.8)
    particles:shockwave(x, y, 120, 0.6, color, 4)
    particles:shockwave(x, y, 70, 0.45, COLORS.white, 2)
    particles:flash(x, y, 90, 0.35, color)
    self._shaker:add(0.55)
end

function PongView:_update_trail(bx, by)
    local trail = self._trail

    for i = TRAIL_POINTS, 2, -1 do
        trail[i].x = trail[i - 1].x
        trail[i].y = trail[i - 1].y
    end

    trail[1].x = bx
    trail[1].y = by
end

function PongView:_draw_court(canvas, t, bx, by, level)
    canvas:vgradient(0, 0, BOARD_W, BOARD_H, 0.2, COLORS.court_top, COLORS.court_low, 255, 255, 24)
    canvas:glow(BOARD_W * 0.5, BOARD_H * 0.5, 190, 0.3, COLORS.paddle_glow, 34 + level * 2, 5)

    local left_flash = self._score_flash_left
    local right_flash = self._score_flash_right
    canvas:hgradient(0, 0, 110, BOARD_H, 0.4, COLORS.paddle, COLORS.paddle, 38 + left_flash * 140, 0, 12)
    canvas:hgradient(BOARD_W - 110, 0, 110, BOARD_H, 0.4, COLORS.cpu, COLORS.cpu, 0, 38 + right_flash * 140, 12)

    -- Dot matrix lit by the ball's proximity.
    for gy = 12.5, BOARD_H, 25 do
        for gx = 12.5, BOARD_W, 25 do
            local dx = gx - bx
            local dy = gy - by
            local d2 = dx * dx + dy * dy
            local lit = d2 < 19600 and (1 - math_sqrt(d2) / 140) or 0
            local wave = (math_sin(t * 1.7 - gx * 0.02 + gy * 0.013) + 1) * 0.5
            local alpha = 14 + wave * 12 + lit * lit * 170
            local size = 1.5 + lit * 1.5
            canvas:rect(gx - size * 0.5, gy - size * 0.5, size, size, 0.6, COLORS.dot, alpha, 1, lit * 0.4)
        end
    end

    -- Centre rings and energy line.
    local cx, cy = BOARD_W * 0.5, BOARD_H * 0.5
    canvas:ring(cx, cy, 58, 1.4, 0.8, COLORS.net, 120, 48)
    canvas:ring(cx, cy, 58, 6, 0.75, COLORS.net, 22, 48)
    for i = 0, 3 do
        local a0 = t * 0.6 + i * math_pi * 0.5
        canvas:ring(cx, cy, 68, 2, 0.8, COLORS.paddle, 90, 8, a0, a0 + 0.9)
        local b0 = -t * 0.9 + i * math_pi * 0.5 + 0.4
        canvas:ring(cx, cy, 46, 1.2, 0.8, COLORS.cpu, 70, 6, b0, b0 + 0.6)
    end
    canvas:circle(cx, cy, 4, 0.85, COLORS.net, 170)

    local pulse_y = (t * 220) % (BOARD_H + 120) - 60
    for i = 0, 10 do
        local y0 = 12 + i * 36
        local d = math_abs(y0 + 9 - pulse_y)
        local boost = d < 60 and (1 - d / 60) or 0
        canvas:rect(cx - 3, y0 - 2, 6, 22, 0.9, COLORS.net, 18 + boost * 50)
        canvas:rect(cx - 1, y0, 2, 18, 0.95, COLORS.net, 110 + boost * 145, 1, boost * 0.6)
    end
end

function PongView:_draw_paddle(canvas, x, center_y, color, flash, t, facing)
    local top = center_y - PADDLE_H * 0.5
    local layer = 4

    canvas:soft_rect(x, top, PADDLE_W, PADDLE_H, 12 + flash * 10, layer - 0.2, color, 55 + flash * 150, 5)
    canvas:bevel_box(x, top, PADDLE_W, PADDLE_H, 2.5, layer, color, 255, 0.6 + flash * 0.3, 0.38)

    for k = 0, 3 do
        local y = top + 3 + ((t * 95 * facing + k * 17.5) % (PADDLE_H - 12))
        canvas:rect(x + PADDLE_W * 0.5 - 1, y, 2, 6, layer + 0.05, COLORS.white, 150)
    end

    canvas:rect(x - 1, top - 1, PADDLE_W + 2, 2, layer + 0.06, color, 255, 1, 0.8)
    canvas:rect(x - 1, top + PADDLE_H - 1, PADDLE_W + 2, 2, layer + 0.06, color, 255, 1, 0.8)

    if flash > 0 then
        canvas:rect(x, top, PADDLE_W, PADDLE_H, layer + 0.07, COLORS.white, flash * 210)
    end

    -- Emitter light spilled onto the court.
    local spill_x = facing > 0 and x + PADDLE_W or x - 60
    canvas:hgradient(spill_x, top - 6, 60, PADDLE_H + 12, layer - 0.3, color, color, facing > 0 and 45 + flash * 80 or 0, facing > 0 and 0 or 45 + flash * 80, 8)
end

function PongView:_draw_ball(canvas, bx, by, speed)
    local heat = math_min(1, math_max(0, (speed - 150) / 450))
    local color = Gfx.Canvas.lerp_color(self._ball_color, COLORS.ball_glow, COLORS.fast, heat)
    color[1] = 255
    local trail = self._trail

    for i = 1, TRAIL_POINTS - 1 do
        local p1 = trail[i]
        local p2 = trail[i + 1]
        local k = 1 - (i - 1) / (TRAIL_POINTS - 1)
        canvas:line(p1.x, p1.y, p2.x, p2.y, BALL_SIZE * 1.6 * k, 5, color, 40 * k)
        canvas:line(p1.x, p1.y, p2.x, p2.y, BALL_SIZE * 0.85 * k, 5.01, color, 150 * k * k, 1, 0.3 * k)
    end

    canvas:glow(bx, by, BALL_SIZE * (2.6 + heat), 5.5, color, 120, 5)
    canvas:orb(bx, by, BALL_SIZE * 0.5, 5.6, COLORS.ball, 255, 2)
end

function PongView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local game = self._game
    local hsw = self._widgets_by_name.highscore_text
    if hsw then hsw.content.text = mod:localize("pong_highscore") .. " " .. (mod:get("pong_highscore") or 0) end

    if game then
        local sw = self._widgets_by_name.score_text
        if sw then sw.content.text = string.format("%d", game:score()) end
        local cw = self._widgets_by_name.cpu_score_text
        if cw then cw.content.text = string.format("%d", game:cpu_score()) end
        local lw = self._widgets_by_name.level_text
        if lw then
            if game:state() == "done" then
                lw.content.text = "ALL LEVELS CLEARED!"
                lw.style.text.text_color = COLORS.ball
            else
                lw.content.text = string.format("Level %d", game:level())
                lw.style.text.text_color = COLORS.hud_dim
            end
        end

        local hot_noise = self._widgets_by_name.scanner_noise_hot
        if hot_noise then
            hot_noise.style.noise.color[1] = 12 + math_floor(math_min(game:level(), 20)) + math_floor(self._shaker.trauma * 60)
        end
    end

    PongView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

    if not game then return end

    dt = math_min(dt or 0.016, 0.05)
    self._time = self._time + dt

    local bx = game:get_ball_x()
    local by = game:get_ball_y()
    self:_detect_events(bx, by)
    self:_update_trail(bx, by)
    self._particles:update(dt)
    self._shaker:update(dt, 8)
    self._player_flash = math_max(0, self._player_flash - dt * 4)
    self._cpu_flash = math_max(0, self._cpu_flash - dt * 4)
    self._score_flash_left = math_max(0, self._score_flash_left - dt * 1.8)
    self._score_flash_right = math_max(0, self._score_flash_right - dt * 1.8)

    local canvas = self._canvas
    if not canvas:begin(ui_renderer, self:_scenegraph_world_position("game_area")) then return end

    local time = self._time
    local prev = self._prev
    local speed = prev and math_sqrt(prev.vx * prev.vx + prev.vy * prev.vy) / dt or 0

    self:_draw_court(canvas, time, bx, by, game:level())
    canvas:set_shake(self._shaker.x, self._shaker.y)
    self:_draw_paddle(canvas, 0, game:get_player_y(), COLORS.paddle, self._player_flash, time, 1)
    self:_draw_paddle(canvas, BOARD_W - PADDLE_W, game:get_cpu_y(), COLORS.cpu, self._cpu_flash, time, -1)
    self:_draw_ball(canvas, bx, by, speed)
    self._particles:draw(canvas, 6)
    canvas:set_shake(0, 0)
    canvas:crt(0, 0, BOARD_W, BOARD_H, time, 7, { tint = COLORS.dot, vignette_depth = 60, vignette_alpha = 140 })

    if game:state() == "done" then
        local pulse = (math_sin(time * 3) + 1) * 0.5
        canvas:rect(0, BOARD_H * 0.5 - 30, BOARD_W, 60, 6.5, COLORS.court_low, 170)
        canvas:hgradient(0, BOARD_H * 0.5 - 31, BOARD_W * 0.5, 2, 6.6, COLORS.paddle, COLORS.white, 0, 200 + pulse * 55)
        canvas:hgradient(BOARD_W * 0.5, BOARD_H * 0.5 - 31, BOARD_W * 0.5, 2, 6.6, COLORS.white, COLORS.cpu, 200 + pulse * 55, 0)
    end

    canvas:finish()
end

function PongView:destroy()
    self._canvas = nil
    self._particles = nil
    PongView.super.destroy(self)
end

return PongView
