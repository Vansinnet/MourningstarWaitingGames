local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")

local math_floor = math.floor
local math_min = math.min
local math_sin = math.sin

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

local CELL_DEF = UIWidget.create_definition({
	{ pass_type = "texture", style_id = "gfx",
		value = "content/ui/materials/backgrounds/default_square",
        style = { hdr = true, color = { 0, 0, 0, 0 }, size = { GRID - 2, GRID - 2 }, offset = { 1, 1, 0 } },
    },
    { pass_type = "texture", style_id = "shade",
        value = "content/ui/materials/backgrounds/default_square",
        style = { color = { 105, 3, 22, 23 }, size = { GRID - 5, GRID - 5 }, offset = { 4, 4, 1 } },
    },
    { pass_type = "texture", style_id = "shine",
        value = "content/ui/materials/backgrounds/default_square",
        style = { hdr = true, color = { 90, 191, 255, 222 }, size = { GRID - 4, 2 }, offset = { 2, 2, 2 } },
    }
}, "board_area", nil, { GRID, GRID })

local LINE_DEF = UIWidget.create_definition({
	{ pass_type = "texture", style_id = "gfx",
		value = "content/ui/materials/backgrounds/default_square",
		style = { hdr = true, color = { 0, 0, 0, 0 } },
	}
}, "board_area", nil, { 1, 1 })

local function circle_def(size)
	return UIWidget.create_definition({
		{ pass_type = "circle", style_id = "gfx",
			style = { color = { 0, 0, 0, 0 } },
		}
	}, "board_area", nil, { size, size })
end

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

for col = 0, COLS - 1, 5 do
    widget_definitions["board_band_" .. col] = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 45, 16, 40, 36 }, offset = { col * GRID, 0, 0.5 } } },
    }, "board_area", nil, { GRID, ROWS * GRID })
end

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

function SnakeView:init(settings, context)
	SnakeView.super.init(self, definitions, settings, context)
	self._game = context.game
	self._no_cursor = true

	self._grid_lines = {}
	for col = 1, COLS - 1 do
		local w = UIWidget.init("sn_grid_v_" .. col, LINE_DEF)
		w.offset[1] = col * GRID
		w.offset[2] = 0
		w.offset[3] = 1
		w.content.size[1] = 1
		w.content.size[2] = ROWS * GRID
		self._grid_lines[#self._grid_lines + 1] = w
	end
	for row = 1, ROWS - 1 do
		local w = UIWidget.init("sn_grid_h_" .. row, LINE_DEF)
		w.offset[1] = 0
		w.offset[2] = row * GRID
		w.offset[3] = 1
		w.content.size[1] = COLS * GRID
		w.content.size[2] = 1
		self._grid_lines[#self._grid_lines + 1] = w
	end

	self._apple_glow = UIWidget.init("sn_apple_glow", circle_def(GRID * 2))
	self._apple_core = UIWidget.init("sn_apple_core", circle_def(GRID * 0.8))
	self._head_glow = UIWidget.init("sn_head_glow", circle_def(GRID * 1.7))
    self._apple_shine = UIWidget.init("sn_apple_shine", circle_def(5))
    self._head_eyes = {}
    for i = 1, 2 do
        self._head_eyes[i] = UIWidget.init("sn_eye_" .. i, circle_def(4))
    end

	self._cells = {}
	for row = 0, ROWS - 1 do
		for col = 0, COLS - 1 do
			local idx = row * COLS + col + 1
			local w = UIWidget.init("sn_cell_" .. idx, CELL_DEF)
			w.offset[1] = col * GRID
			w.offset[2] = row * GRID
			w.offset[3] = 2
			self._cells[idx] = w
		end
	end
end

function SnakeView:dialogue_system() return nil end
function SnakeView:is_using_input() return false end

function SnakeView:update(dt, t, input_service)
	if self._game then self._game:update(dt) end
	return SnakeView.super.update(self, dt, t, input_service)
end

function SnakeView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
	local hsw = self._widgets_by_name.highscore_text
	if hsw then hsw.content.text = mod:localize("snake_highscore") .. " " .. (mod:get("snake_highscore") or 0) end
	local score_w = self._widgets_by_name.score_text
	if score_w and self._game then
		score_w.content.text = string.format("Score: %d", self._game:score())
	end
	local hot_noise = self._widgets_by_name.scanner_noise_hot
	if hot_noise and self._game then
        hot_noise.style.noise.color[1] = 12 + math_min(self._game:score(), 12)
	end

	SnakeView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

	if not self._game then return end

	for i = 1, #self._grid_lines do
		local w = self._grid_lines[i]
		w.style.gfx.color = COLORS.grid
		UIWidget.draw(w, ui_renderer)
	end

	local ax, ay = self._game:get_apple()
	local pulse = (math_sin((t or 0) * 5) + 1) * 0.5
    local glow_size = GRID * 1.3 + pulse * 4
	local apple_glow = self._apple_glow
	apple_glow.offset[1] = ax + GRID / 2 - glow_size / 2
	apple_glow.offset[2] = ay + GRID / 2 - glow_size / 2
	apple_glow.offset[3] = 2
	apple_glow.content.size[1] = glow_size
	apple_glow.content.size[2] = glow_size
    apple_glow.style.gfx.color[1] = 32 + math_floor(pulse * 25)
	apple_glow.style.gfx.color[2] = COLORS.apple_glow[2]
	apple_glow.style.gfx.color[3] = COLORS.apple_glow[3]
	apple_glow.style.gfx.color[4] = COLORS.apple_glow[4]
	UIWidget.draw(apple_glow, ui_renderer)

	local apple_core = self._apple_core
	local core_size = GRID * 0.72
	apple_core.offset[1] = ax + GRID / 2 - core_size / 2
	apple_core.offset[2] = ay + GRID / 2 - core_size / 2
	apple_core.offset[3] = 4
	apple_core.content.size[1] = core_size
	apple_core.content.size[2] = core_size
	apple_core.style.gfx.color = COLORS.apple
	UIWidget.draw(apple_core, ui_renderer)

    local apple_shine = self._apple_shine
    apple_shine.offset[1] = ax + 7
    apple_shine.offset[2] = ay + 6
    apple_shine.offset[3] = 5
    apple_shine.style.gfx.color = COLORS.head
    UIWidget.draw(apple_shine, ui_renderer)

	local cells = self._game:get_cells()
	local head = cells[1]
	if head then
		local head_glow = self._head_glow
		local size = GRID * 1.55
		head_glow.offset[1] = head.x + GRID / 2 - size / 2
		head_glow.offset[2] = head.y + GRID / 2 - size / 2
		head_glow.offset[3] = 3
		head_glow.content.size[1] = size
		head_glow.content.size[2] = size
		head_glow.style.gfx.color = COLORS.head_glow
		UIWidget.draw(head_glow, ui_renderer)
	end

	for i = #cells, 1, -1 do
		local c = cells[i]
		local idx = (c.y / GRID) * COLS + (c.x / GRID) + 1
		local w = self._cells[idx]
		if w then
			local color = w.style.gfx.color
			if i == 1 then
				color[1] = COLORS.head[1]
				color[2] = COLORS.head[2]
				color[3] = COLORS.head[3]
				color[4] = COLORS.head[4]
			else
				local fade = math_min(i - 2, 14)
                color[1] = COLORS.snake[1]
				color[2] = COLORS.snake[2]
				color[3] = math_min(COLORS.snake[3], COLORS.snake[3] - fade * 5)
				color[4] = COLORS.snake[4] + math_floor((COLORS.snake_tail[4] - COLORS.snake[4]) * fade / 14)
			end
			UIWidget.draw(w, ui_renderer)
		end
	end

    if head then
        -- The neck gives a visual heading without accessing or changing input state.
        local neck = cells[2]
        local dx, dy = 1, 0
        if neck then
            dx = head.x == neck.x and 0 or (head.x > neck.x and 1 or -1)
            dy = head.y == neck.y and 0 or (head.y > neck.y and 1 or -1)
            if math.abs(head.x - neck.x) > GRID then dx = -dx end
            if math.abs(head.y - neck.y) > GRID then dy = -dy end
        end
        for i = 1, 2 do
            local eye = self._head_eyes[i]
            local side = i == 1 and -4 or 4
            eye.offset[1] = head.x + GRID / 2 + dx * 5 - dy * side - 2
            eye.offset[2] = head.y + GRID / 2 + dy * 5 + dx * side - 2
            eye.offset[3] = 6
            eye.style.gfx.color = COLORS.bg
            UIWidget.draw(eye, ui_renderer)
        end
    end
end

function SnakeView:destroy() SnakeView.super.destroy(self) end

return SnakeView
