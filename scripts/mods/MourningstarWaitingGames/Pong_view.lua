local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")

local math_floor = math.floor
local math_min = math.min

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

local RECT_DEF = UIWidget.create_definition({
	{ pass_type = "texture", style_id = "gfx",
		value = "content/ui/materials/backgrounds/default_square",
		style = { hdr = true, color = { 0, 0, 0, 0 } },
	}
}, "game_area", nil, { 10, 10 })

local function circle_def(size)
	return UIWidget.create_definition({
		{ pass_type = "circle", style_id = "gfx",
			style = { color = { 0, 0, 0, 0 } },
		}
	}, "game_area", nil, { size, size })
end

local PADDLE_DEF = UIWidget.create_definition({
    { pass_type = "texture", style_id = "gfx",
        value = "content/ui/materials/backgrounds/default_square",
        style = { hdr = true, color = { 0, 0, 0, 0 } } },
    { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
        style = { color = { 150, 7, 23, 27 }, size = { PADDLE_W - 3, PADDLE_H - 3 }, offset = { 3, 3, 1 } } },
    { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
        style = { hdr = true, color = { 175, 224, 255, 238 }, size = { 2, PADDLE_H - 4 }, offset = { 1, 2, 2 } } },
    { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
        style = { hdr = true, color = { 130, 224, 255, 238 }, size = { PADDLE_W - 2, 2 }, offset = { 1, 1, 2 } } },
}, "game_area", nil, { PADDLE_W, PADDLE_H })

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
	net = UIWidget.create_definition({
		{ pass_type = "texture", style_id = "gfx",
			value = "content/ui/materials/backgrounds/default_square",
			style = { hdr = true, color = { 45, 0, 90, 40 }, offset = { BOARD_W / 2 - 1, 0, 0 } },
		}
	}, "game_area", nil, { 2, BOARD_H }),
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

-- Broad, low-contrast court markings stay behind the ball and paddles.
for side = 1, 2 do
    local x = side == 1 and 0 or BOARD_W / 2
    local accent = side == 1 and COLORS.paddle or COLORS.cpu
    widget_definitions["court_half_" .. side] = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = side == 1 and { 50, 18, 48, 43 } or { 40, 50, 33, 27 },
                size = { BOARD_W / 2, BOARD_H }, offset = { x, 0, 1 } } },
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 90, 49, 98, 90 }, size = { 1, BOARD_H - 48 }, offset = { x + (side == 1 and 46 or 253), 24, 2 } } },
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = accent, size = { 46, 2 }, offset = { x + (side == 1 and 0 or 254), 0, 3 } } },
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = accent, size = { 46, 2 }, offset = { x + (side == 1 and 0 or 254), BOARD_H - 2, 3 } } },
    }, "game_area", nil, { BOARD_W / 2, BOARD_H })

    widget_definitions["score_panel_" .. side] = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 255, 10, 25, 27 }, size = { 200, 34 }, offset = { 0, -7, -2 } } },
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = accent, size = { 32, 2 }, offset = { 84, 26, -1 } } },
    }, side == 1 and "score_area" or "cpu_score_area", nil, { 200, 34 })
end

widget_definitions.center_disc = UIWidget.create_definition({
    { pass_type = "circle", style = { color = { 110, 35, 76, 72 }, size = { 104, 104 }, offset = { 248, 148, 1 } } },
    { pass_type = "circle", style = { color = COLORS.bg, size = { 100, 100 }, offset = { 250, 150, 2 } } },
}, "game_area", nil, { 104, 104 })

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }

local PongView = class("PongView", "BaseView")

function PongView:init(settings, context)
	PongView.super.init(self, definitions, settings, context)
	self._game = context.game
	self._no_cursor = true

	self._player_paddle_glow = UIWidget.init("pong_player_glow", RECT_DEF)
    self._player_paddle = UIWidget.init("pong_player", PADDLE_DEF)
	self._cpu_paddle_glow = UIWidget.init("pong_cpu_glow", RECT_DEF)
    self._cpu_paddle = UIWidget.init("pong_cpu", PADDLE_DEF)
	self._ball_glow = UIWidget.init("pong_ball_glow", circle_def(BALL_SIZE * 3.4))
	self._ball = UIWidget.init("pong_ball", circle_def(BALL_SIZE))

	self._net_widgets = {}
	for i = 1, 11 do
		self._net_widgets[i] = UIWidget.init("pong_net_dash_" .. i, RECT_DEF)
	end

	self._trail_widgets = {}
	self._ball_trail = {}
	for i = 1, 8 do
		self._trail_widgets[i] = UIWidget.init("pong_ball_trail_" .. i, circle_def(BALL_SIZE))
		self._ball_trail[i] = { x = BOARD_W / 2, y = BOARD_H / 2 }
	end
end

function PongView:dialogue_system() return nil end
function PongView:is_using_input() return false end

function PongView:update(dt, t, input_service)
	if self._game then self._game:update(dt) end
	return PongView.super.update(self, dt, t, input_service)
end

function PongView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
	local hsw = self._widgets_by_name.highscore_text
	if hsw then hsw.content.text = mod:localize("pong_highscore") .. " " .. (mod:get("pong_highscore") or 0) end

	PongView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

	if not self._game then return end

	local sw = self._widgets_by_name.score_text
	if sw then sw.content.text = string.format("%d", self._game:score()) end
	local cw = self._widgets_by_name.cpu_score_text
	if cw then cw.content.text = string.format("%d", self._game:cpu_score()) end
	local lw = self._widgets_by_name.level_text
	if lw then
		if self._game:state() == "done" then
			lw.content.text = "ALL LEVELS CLEARED!"
			lw.style.text.text_color = COLORS.ball
		else
			lw.content.text = string.format("Level %d", self._game:level())
			lw.style.text.text_color = COLORS.hud_dim
		end
	end

	local hot_noise = self._widgets_by_name.scanner_noise_hot
	if hot_noise then
        local pulse = 12 + math_floor(math_min(self._game:level(), 20))
		hot_noise.style.noise.color[1] = pulse
	end

	for i = 1, #self._net_widgets do
		local nw = self._net_widgets[i]
        nw.offset[1] = BOARD_W / 2 - 1
		nw.offset[2] = 12 + (i - 1) * 36
        nw.offset[3] = 3
        nw.content.size[1] = 2
		nw.content.size[2] = 18
		nw.style.gfx.color = COLORS.net
		UIWidget.draw(nw, ui_renderer)
	end

	local pg = self._player_paddle_glow
	pg.offset[1] = 0
	pg.offset[2] = self._game:get_player_y() - PADDLE_H / 2 - 8
    pg.content.size[1] = PADDLE_W + 7
	pg.content.size[2] = PADDLE_H + 16
	pg.style.gfx.color = COLORS.paddle_glow
	pg.offset[3] = 2
	UIWidget.draw(pg, ui_renderer)

	local pp = self._player_paddle
    pp.offset[1] = 0
	pp.offset[2] = self._game:get_player_y() - PADDLE_H / 2
	pp.content.size[1] = PADDLE_W
	pp.content.size[2] = PADDLE_H
	pp.style.gfx.color = COLORS.paddle
	pp.offset[3] = 4
	UIWidget.draw(pp, ui_renderer)

	local cg = self._cpu_paddle_glow
    cg.offset[1] = BOARD_W - PADDLE_W - 7
	cg.offset[2] = self._game:get_cpu_y() - PADDLE_H / 2 - 8
    cg.content.size[1] = PADDLE_W + 7
	cg.content.size[2] = PADDLE_H + 16
	cg.style.gfx.color = COLORS.cpu_glow
	cg.offset[3] = 2
	UIWidget.draw(cg, ui_renderer)

	local cp = self._cpu_paddle
    cp.offset[1] = BOARD_W - PADDLE_W
	cp.offset[2] = self._game:get_cpu_y() - PADDLE_H / 2
	cp.content.size[1] = PADDLE_W
	cp.content.size[2] = PADDLE_H
	cp.style.gfx.color = COLORS.cpu
	cp.offset[3] = 4
	UIWidget.draw(cp, ui_renderer)

	local bx = self._game:get_ball_x()
	local by = self._game:get_ball_y()
	local trail = self._ball_trail
	local last = trail[1]
	if last and ((bx - last.x) * (bx - last.x) + (by - last.y) * (by - last.y)) > 6400 then
		for i = 1, #trail do
			trail[i].x = bx
			trail[i].y = by
		end
	else
		for i = #trail, 2, -1 do
			trail[i].x = trail[i - 1].x
			trail[i].y = trail[i - 1].y
		end
		trail[1].x = bx
		trail[1].y = by
	end

	for i = #trail, 2, -1 do
		local tw = self._trail_widgets[i]
		local point = trail[i]
        local size = BALL_SIZE * (1 - (i - 1) * 0.085)
		local color = tw.style.gfx.color
        color[1] = 115 - i * 12
		color[2] = COLORS.ball_glow[2]
		color[3] = COLORS.ball_glow[3]
		color[4] = COLORS.ball_glow[4]
		tw.offset[1] = point.x - size / 2
		tw.offset[2] = point.y - size / 2
		tw.offset[3] = 5
		tw.content.size[1] = size
		tw.content.size[2] = size
		UIWidget.draw(tw, ui_renderer)
	end

	local glow = self._ball_glow
    glow.offset[1] = bx - BALL_SIZE * 1.15
    glow.offset[2] = by - BALL_SIZE * 1.15
	glow.offset[3] = 6
    glow.content.size[1] = BALL_SIZE * 2.3
    glow.content.size[2] = BALL_SIZE * 2.3
	glow.style.gfx.color = COLORS.ball_glow
	UIWidget.draw(glow, ui_renderer)

	local b = self._ball
	b.offset[1] = bx - BALL_SIZE / 2
	b.offset[2] = by - BALL_SIZE / 2
	b.content.size[1] = BALL_SIZE
	b.content.size[2] = BALL_SIZE
	b.style.gfx.color = COLORS.ball
	b.offset[3] = 7
	UIWidget.draw(b, ui_renderer)
end

function PongView:destroy() PongView.super.destroy(self) end

return PongView
