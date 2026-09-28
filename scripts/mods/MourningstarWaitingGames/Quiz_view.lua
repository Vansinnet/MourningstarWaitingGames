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

local COLORS = {
	title    = { 255, 232, 199, 128 },
	question = { 255, 224, 238, 223 },
	answer   = { 255, 153, 185, 175 },
	selected = { 255, 255, 227, 164 },
	correct  = { 255, 99, 244, 171 },
	incorrect = { 255, 255, 112, 103 },
	score    = { 255, 232, 199, 128 },
	progress = { 255, 141, 195, 180 },
	feedback_text = { 255, 224, 238, 223 },
	bg_top   = { 255, 6, 16, 15 },
	bg_low   = { 255, 1, 5, 6 },
	panel    = { 255, 12, 28, 27 },
	panel_low = { 255, 4, 11, 12 },
	brass    = { 255, 194, 161, 97 },
	scan     = { 255, 70, 230, 170 },
	white    = { 255, 255, 255, 255 },
	shadow   = { 255, 0, 0, 0 },
	pending  = { 255, 60, 90, 84 },
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
	title_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 500, 30 }, position = { 0, -215, 10 },
	},
	question_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 500, 100 }, position = { 0, -120, 10 },
	},
	answer_1 = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 500, 44 }, position = { 0, -22, 10 },
	},
	answer_2 = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 500, 44 }, position = { 0, 28, 10 },
	},
	answer_3 = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 500, 44 }, position = { 0, 78, 10 },
	},
	answer_4 = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 500, 44 }, position = { 0, 128, 10 },
	},
	feedback_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 500, 30 }, position = { 0, 174, 10 },
	},
	score_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 160, 20 }, position = { 200, 200, 10 },
	},
	progress_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 160, 20 }, position = { -200, 200, 10 },
	},
	controls_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 500, 20 }, position = { 0, 230, 10 },
	},
	highscore_area = {
		horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
		size = { 500, 20 }, position = { 0, 250, 10 },
	},
}

local function _make_text(value, color, size)
	return {
		{ pass_type = "text", style_id = "text",
			value = value, value_id = "text",
			style = { font_size = size, font_type = "machine_medium",
				text_horizontal_alignment = "center", text_vertical_alignment = "center",
				text_color = color, offset = { 0, 0, 1 } },
		}
	}
end

local widget_definitions = {
	bg = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/default_square",
			style = { hdr = true, color = { 0, 0, 0, 0 } },
		}
	}, "scanner_base", nil, { RENDER_SIZE, RENDER_SIZE }),
	scanner_noise = UIWidget.create_definition({
		{ pass_type = "texture",
			value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
			style = { hdr = true, color = { 38, 45, 110, 85 }, offset = { -300, -280, 1 } },
		}
	}, "center_pivot", nil, { 600, 600 }),
	title_text = UIWidget.create_definition({
		{ pass_type = "text", style_id = "text",
			value = "Warhammer 40k Quiz",
			style = { font_size = 23, font_type = "machine_medium",
				text_horizontal_alignment = "center", text_vertical_alignment = "center",
				text_color = COLORS.title, offset = { 0, 0, 1 } },
		}
	}, "title_area", nil, { 500, 30 }),
	question_text = UIWidget.create_definition(_make_text("", COLORS.question, 20), "question_area", nil, { 500, 100 }),
	answer_1_text = UIWidget.create_definition(_make_text("", COLORS.answer, 16), "answer_1", nil, { 500, 44 }),
	answer_2_text = UIWidget.create_definition(_make_text("", COLORS.answer, 16), "answer_2", nil, { 500, 44 }),
	answer_3_text = UIWidget.create_definition(_make_text("", COLORS.answer, 16), "answer_3", nil, { 500, 44 }),
	answer_4_text = UIWidget.create_definition(_make_text("", COLORS.answer, 16), "answer_4", nil, { 500, 44 }),
	feedback_text = UIWidget.create_definition(_make_text("", COLORS.feedback_text, 18), "feedback_area", nil, { 500, 30 }),
	score_text = UIWidget.create_definition(_make_text("", COLORS.score, 16), "score_area", nil, { 160, 20 }),
	progress_text = UIWidget.create_definition(_make_text("", COLORS.progress, 16), "progress_area", nil, { 160, 20 }),
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
			value = mod:localize("quiz_controls"),
			style = { font_size = 14, font_type = "machine_medium",
				text_horizontal_alignment = "center", text_vertical_alignment = "center",
				text_color = { 255, 0, 200, 0 }, offset = { 0, 0, 1 } },
		}
	}, "controls_area", nil, { 500, 20 }),
	highscore_text = UIWidget.create_definition({
		{ pass_type = "text", style_id = "text",
			value = "", value_id = "text",
			style = { font_size = 14, font_type = "machine_medium",
				text_horizontal_alignment = "center", text_vertical_alignment = "center",
				text_color = { 255, 0, 255, 0 }, offset = { 0, 0, 1 } },
		}
	}, "highscore_area", nil, { 500, 20 }),
}

for i = 1, 4 do
    widget_definitions["answer_panel_" .. i] = UIWidget.create_definition({
        { pass_type = "texture", style_id = "background",
            value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 235, 9, 23, 22 }, offset = { 0, 0, -3 } } },
        { pass_type = "texture", style_id = "edge",
            value = "content/ui/materials/frames/frame_tile_2px",
            style = { color = { 100, 60, 100, 85 }, scale_to_material = true, offset = { 0, 0, -2 } } },
        { pass_type = "texture", style_id = "accent",
            value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 130, 60, 100, 85 }, size = { 3, 30 }, offset = { 0, 7, -1 } } },
    }, "answer_" .. i, nil, { 500, 44 })
end

widget_definitions.question_panel = UIWidget.create_definition({
    { pass_type = "texture",
        value = "content/ui/materials/backgrounds/default_square",
        style = { color = { 230, 8, 19, 19 }, offset = { -10, -8, -3 } } },
    { pass_type = "texture",
        value = "content/ui/materials/backgrounds/default_square",
        style = { color = { 180, 194, 161, 97 }, size = { 80, 2 }, offset = { 210, -8, -2 } } },
    { pass_type = "texture",
        value = "content/ui/materials/backgrounds/default_square",
        style = { color = { 70, 194, 161, 97 }, size = { 520, 1 }, offset = { -10, 107, -2 } } },
}, "question_area", nil, { 520, 116 })

AuspexFrame.add(widget_definitions, {
    render_size = RENDER_SIZE,
    outline_size = { 580, 560 },
    center = { 0, 10 },
})
AuspexFrame.add_inner_border(widget_definitions, {
    render_size = RENDER_SIZE,
    size = { 540, 500 },
    center = { 0, 15 },
    prefix = "quiz_panel_border",
    alpha = 85,
})

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }

local ANSWER_NAMES = { "answer_1_text", "answer_2_text", "answer_3_text", "answer_4_text" }
local PANEL_ACCENTS = { "edge", "accent" }
local SEL_PREFIX = "      "

local QuizView = class("QuizView", "BaseView")

function QuizView:init(settings, context)
    QuizView.super.init(self, definitions, settings, context)
    self._game = context.game
    self._no_cursor = true
    self._canvas = Gfx.Canvas.new(RENDER_SIZE, RENDER_SIZE, 5000)
    self._particles = Gfx.Particles.new(240)
    self._shaker = Gfx.Shaker.new()
    self._time = 0
    self._results = {}
    self._prev_feedback = false
    self._prev_index = nil
    self._sel_y = nil
    self._feedback_anim = 0
    self._question_anim = 0
    self._data_columns = {}
    for i = 1, 22 do
        self._data_columns[i] = { x = 18 + (i - 1) * 26.5, speed = 12 + (i * 29) % 30, seed = i * 7919 }
    end
end

-- Widgets exist only after the view package has loaded, so legacy panels are hidden on first draw.
function QuizView:_hide_legacy_panel()
    if self._legacy_hidden then return end
    local question_panel = self._widgets_by_name.question_panel
    if not question_panel then return end
    for _, pass_style in pairs(question_panel.style) do
        if type(pass_style) == "table" and pass_style.color then pass_style.color[1] = 0 end
    end
    self._legacy_hidden = true
end

function QuizView:dialogue_system() return nil end
function QuizView:is_using_input() return false end

function QuizView:update(dt, t, input_service)
    if self._game then self._game:update(dt) end
    return QuizView.super.update(self, dt, t, input_service)
end

function QuizView:_area(base, name)
    local p = self:_scenegraph_world_position(name)
    return p[1] - base[1], p[2] - base[2]
end

function QuizView:_detect_events(base)
    local game = self._game
    local feedback = game:is_showing_feedback()
    local idx = game:current_index()

    if self._prev_index and idx ~= self._prev_index then
        self._question_anim = 0
    end

    if feedback and not self._prev_feedback then
        local correct = game:last_correct()
        self._results[idx] = correct and 1 or -1
        self._feedback_anim = 0

        local q = game:current_question()
        local target = correct and (game:selected() + 1) or (game:selected() + 1)
        local ax, ay = self:_area(base, "answer_" .. target)
        local particles = self._particles

        if correct then
            particles:burst(ax + 250, ay + 22, 40, 90, 380, 0.4, 1.0, 2, COLORS.correct, "spark", 2.2, 60)
            particles:burst(ax + 250, ay + 22, 14, 30, 140, 0.8, 1.4, 3, COLORS.selected, "ember", 1.2, -20)
            particles:shockwave(ax + 250, ay + 22, 180, 0.6, COLORS.correct, 3)
        else
            particles:burst(ax + 250, ay + 22, 26, 50, 260, 0.3, 0.8, 3, COLORS.incorrect, "shard", 2, 200)
            self._shaker:add(0.45)
            if q then
                local cx, cy = self:_area(base, "answer_" .. (q.correct + 1))
                particles:shockwave(cx + 250, cy + 22, 120, 0.5, COLORS.correct, 2)
            end
        end
    end

    if game:is_game_over() and not self._done_burst then
        self._done_burst = true
        for i = 1, 6 do
            self._particles:burst(80 + i * 75, 140, 12, 60, 260, 0.8, 1.6, 2, i % 2 == 0 and COLORS.correct or COLORS.selected, "spark", 1.2, 120, -math_pi * 0.5, 1.4)
        end
    elseif not game:is_game_over() then
        self._done_burst = false
    end

    if idx == 1 and not feedback and self._prev_index and self._prev_index > 1 then
        self._results = {}
    end

    self._prev_feedback = feedback
    self._prev_index = idx
end

function QuizView:_draw_backdrop(canvas, t)
    canvas:vgradient(20, 40, 560, 530, 0.5, COLORS.bg_top, COLORS.bg_low, 235, 245, 26)

    -- Cogitator data columns.
    for i = 1, #self._data_columns do
        local col = self._data_columns[i]
        local offset = (t * col.speed) % 18
        local s = col.seed
        for row = 0, 29 do
            s = (s * 16807) % 2147483647
            local on = (s % 7) < 3
            if on then
                local y = 44 + row * 18 + offset
                if y < 562 then
                    local w = 4 + (s % 5) * 2
                    local fade = (math_sin(t * 0.8 + row * 0.4 + i) + 1) * 0.5
                    canvas:rect(col.x, y, w, 2, 0.6, COLORS.scan, 8 + fade * 16)
                end
            end
        end
    end

    -- Rotating cogwheel behind the question.
    local cx, cy, r = 300, 330, 190
    local teeth = 18
    local rot = t * 0.08
    canvas:ring(cx, cy, r, 10, 0.7, COLORS.brass, 16, 48)
    canvas:ring(cx, cy, r * 0.55, 4, 0.7, COLORS.brass, 14, 36)
    for k = 0, teeth - 1 do
        local a = rot + k / teeth * math_pi * 2
        local ca, sa = math_cos(a), math_sin(a)
        local w = 0.07
        local ca2, sa2 = math_cos(a + w), math_sin(a + w)
        local ca1, sa1 = math_cos(a - w), math_sin(a - w)
        canvas:quad(cx + ca1 * (r + 4), cy + sa1 * (r + 4), cx + ca2 * (r + 4), cy + sa2 * (r + 4),
            cx + ca2 * (r + 22), cy + sa2 * (r + 22), cx + ca1 * (r + 22), cy + sa1 * (r + 22), 0.7, COLORS.brass, 16)
        if k % 3 == 0 then
            canvas:line(cx + ca * r * 0.55, cy + sa * r * 0.55, cx + ca * (r - 5), cy + sa * (r - 5), 3, 0.7, COLORS.brass, 12)
        end
    end

    canvas:radar(cx, cy, r - 6, t * 0.9, 0.8, COLORS.scan, 40, 1.3, 16)
end

function QuizView:_draw_plate(canvas, x, y, w, h, layer, accent, strength, t)
    canvas:rect(x + 4, y + 5, w, h, layer - 0.05, COLORS.shadow, 120)
    canvas:vgradient(x, y, w, h, layer, COLORS.panel, COLORS.panel_low, 240, 245, 8)
    canvas:rect(x, y, w, 1.5, layer + 0.01, accent, 90 + strength * 140)
    canvas:rect(x, y + h - 1, w, 1, layer + 0.01, accent, 40 + strength * 80)
    canvas:rect(x, y, 1, h, layer + 0.01, accent, 40 + strength * 100)
    canvas:rect(x + w - 1, y, 1, h, layer + 0.01, accent, 40 + strength * 100)

    local c = 9
    for qx = 0, 1 do
        for qy = 0, 1 do
            local px = x + qx * w
            local py = y + qy * h
            local dx = qx == 0 and 1 or -1
            local dy = qy == 0 and 1 or -1
            canvas:line(px, py, px + dx * c, py, 2, layer + 0.02, COLORS.brass, 200)
            canvas:line(px, py, px, py + dy * c, 2, layer + 0.02, COLORS.brass, 200)
            canvas:circle(px + dx * 4, py + dy * 4, 1.5, layer + 0.03, COLORS.brass, 220, 1, 0.3, 6)
        end
    end
end

function QuizView:_draw_answers(canvas, base, t, q, sel, feedback, last_correct)
    local sel_target = nil

    for i = 1, 4 do
        local ax, ay = self:_area(base, "answer_" .. i)
        local selected = i - 1 == sel
        local is_correct = feedback and q and i - 1 == q.correct
        local is_wrong = feedback and selected and not last_correct
        local accent = is_correct and COLORS.correct or is_wrong and COLORS.incorrect or selected and COLORS.selected or COLORS.answer
        local strength = (selected or is_correct) and 1 or 0
        local shake_x = 0

        if is_wrong then
            shake_x = math_sin(t * 60) * 5 * math_max(0, 1 - self._feedback_anim * 2)
        end

        if selected and not feedback then sel_target = ay end

        self:_draw_plate(canvas, ax + shake_x, ay, 500, 44, 7.6, accent, strength, t)

        if is_correct or is_wrong then
            local pulse = (math_sin(t * 6) + 1) * 0.5
            canvas:hgradient(ax + shake_x, ay, 250, 44, 7.7, accent, accent, 90 + pulse * 40, 10, 12)
            canvas:soft_rect(ax + shake_x, ay, 500, 44, 10, 7.5, accent, 90, 4)
        end

        -- Answer index glyph box.
        local gx, gy = ax + 14 + shake_x, ay + 22
        canvas:quad(gx, gy - 9, gx + 9, gy, gx, gy + 9, gx - 9, gy, 7.75, accent, 70 + strength * 150)
        canvas:quad(gx, gy - 5, gx + 5, gy, gx, gy + 5, gx - 5, gy, 7.76, COLORS.panel_low, 255)
        canvas:rect(gx - 1.5, gy - 1.5, 3, 3, 7.77, accent, 150 + strength * 105)
    end

    -- Sliding selection highlight with travelling edge light.
    if sel_target then
        self._sel_y = self._sel_y and self._sel_y + (sel_target - self._sel_y) * 0.3 or sel_target
        local ax = self:_area(base, "answer_1")
        local y = self._sel_y
        local chevron = (math_sin(t * 7) + 1) * 3
        canvas:soft_rect(ax, y, 500, 44, 8, 7.55, COLORS.selected, 70, 4)
        canvas:hgradient(ax, y, 180, 44, 7.72, COLORS.selected, COLORS.selected, 60, 0, 10)

        for k = 0, 1 do
            local cx = ax - 22 + k * 8 + chevron
            canvas:line(cx, y + 14, cx + 7, y + 22, 2.4, 7.8, COLORS.selected, 230 - k * 90)
            canvas:line(cx + 7, y + 22, cx, y + 30, 2.4, 7.8, COLORS.selected, 230 - k * 90)
        end

        local perimeter = 2 * (500 + 44)
        local pos = (t * 420) % perimeter
        local function edge_point(d)
            if d < 500 then return ax + d, y end
            d = d - 500
            if d < 44 then return ax + 500, y + d end
            d = d - 44
            if d < 500 then return ax + 500 - d, y + 44 end
            return ax, y + 44 - (d - 500)
        end
        for k = 0, 5 do
            local px, py = edge_point((pos - k * 7) % perimeter)
            canvas:rect(px - 2, py - 2, 4, 4, 7.9, COLORS.white, 220 - k * 36)
        end
        local hx, hy = edge_point(pos)
        canvas:glow(hx, hy, 16, 7.85, COLORS.selected, 120, 3)
    end
end

function QuizView:_draw_progress(canvas, base, t, idx, total)
    local qx, qy = self:_area(base, "question_area")
    local pip_w = 500 / total
    for i = 1, total do
        local x = qx + (i - 1) * pip_w
        local y = qy + 110
        local r = self._results[i]
        local color = r == 1 and COLORS.correct or r == -1 and COLORS.incorrect or i == idx and COLORS.selected or COLORS.pending
        local alpha = r and 230 or i == idx and 150 + (math_sin(t * 5) + 1) * 50 or 90
        canvas:rect(x + 2, y, pip_w - 4, 4, 7.95, color, alpha)
        if r or i == idx then
            canvas:rect(x + 2, y - 2, pip_w - 4, 8, 7.94, color, alpha * 0.25)
        end
    end
end

function QuizView:_draw_final(canvas, t, score, total)
    local cx, cy = 300, 330
    local k = total > 0 and score / total or 0
    local anim = math_min(1, self._feedback_anim * 0.8)
    local sweep = k * anim * math_pi * 2
    canvas:ring(cx, cy, 70, 10, 7.6, COLORS.pending, 120, 48)
    if sweep > 0.01 then
        canvas:ring(cx, cy, 70, 10, 7.7, k >= 0.7 and COLORS.correct or k >= 0.4 and COLORS.selected or COLORS.incorrect, 240, 48, -math_pi * 0.5, -math_pi * 0.5 + sweep)
    end
    canvas:glow(cx, cy, 110, 7.5, k >= 0.7 and COLORS.correct or COLORS.selected, 50 + math_sin(t * 3) * 15, 6)
    for i = 0, 11 do
        local a = t * 0.5 + i * math_pi / 6
        canvas:line(cx + math_cos(a) * 84, cy + math_sin(a) * 84, cx + math_cos(a) * 94, cy + math_sin(a) * 94, 2, 7.7, COLORS.brass, 160)
    end
end

function QuizView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local game = self._game
    self:_hide_legacy_panel()
    local hsw = self._widgets_by_name.highscore_text
    if hsw then hsw.content.text = mod:localize("quiz_highscore") .. " " .. (mod:get("quiz_highscore") or 0) end

    if not game then
        QuizView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
        return
    end

    local q = game:current_question()
    local idx = game:current_index()
    local total = game:total()
    local sel = game:selected()
    local feedback = game:is_showing_feedback()
    local last_correct = game:last_correct()

    local progress_w = self._widgets_by_name.progress_text
    if progress_w then
        if game:is_game_over() then
            progress_w.content.text = "Quiz complete!"
        elseif q then
            progress_w.content.text = string.format("Question %d/%d", idx, total)
        end
    end

    local score_w = self._widgets_by_name.score_text
    if score_w then
        score_w.content.text = string.format("Score: %d", game:score())
    end

    local q_w = self._widgets_by_name.question_text
    if q_w then
        if q then
            q_w.content.text = q.q
        elseif game:is_game_over() then
            q_w.content.text = string.format("Final Score: %d / %d", game:score(), total)
        end
    end

    for i = 1, 4 do
        local w = self._widgets_by_name[ANSWER_NAMES[i]]
        local panel = self._widgets_by_name["answer_panel_" .. i]
        if panel then
            panel.style.background.color[1] = 0
            panel.style.edge.color[1] = 0
            panel.style.accent.color[1] = 0
        end
        if w then
            if q then
                local prefix = (i - 1 == sel) and SEL_PREFIX or "    "
                local color = (i - 1 == sel) and COLORS.selected or COLORS.answer
                if feedback then
                    if i - 1 == q.correct then
                        prefix = "  ✓ "
                        color = COLORS.correct
                    elseif i - 1 == sel and not last_correct then
                        prefix = "  ✗ "
                        color = COLORS.incorrect
                    end
                end
                w.content.text = prefix .. q.a[i]
                w.style.text.text_color = color
            else
                w.content.text = ""
            end
        end
    end

    local fb_w = self._widgets_by_name.feedback_text
    if fb_w then
        if game:is_game_over() then
            fb_w.content.text = "Press Esc to close"
            fb_w.style.text.text_color = COLORS.feedback_text
        elseif feedback and q then
            fb_w.style.text.text_color = last_correct and COLORS.correct or COLORS.incorrect
            fb_w.content.text = last_correct and "Correct! Press jump to continue." or "Incorrect! Press jump to continue."
        else
            fb_w.content.text = ""
        end
    end

    QuizView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

    dt = math_min(dt or 0.016, 0.05)
    self._time = self._time + dt
    local base = self:_scenegraph_world_position("scanner_base")

    self:_detect_events(base)
    self._particles:update(dt)
    self._shaker:update(dt, 6)
    self._feedback_anim = self._feedback_anim + dt
    self._question_anim = math_min(1, self._question_anim + dt * 3)

    local canvas = self._canvas
    if not canvas:begin(ui_renderer, base) then return end

    local time = self._time
    self:_draw_backdrop(canvas, time)

    canvas:set_shake(self._shaker.x, self._shaker.y)
    local qx, qy = self:_area(base, "question_area")
    local reveal = 1 - (1 - self._question_anim) ^ 3
    self:_draw_plate(canvas, qx - 10, qy - 8, 520, 116 * reveal, 7.4, COLORS.brass, 0.6, time)
    canvas:sweep(qx - 10, qy - 8, 520, 116 * reveal, time, 3.2, 7.45, COLORS.scan, 40, 50)

    if q then
        self:_draw_answers(canvas, base, time, q, sel, feedback, last_correct)
        self:_draw_progress(canvas, base, time, idx, total)
    elseif game:is_game_over() then
        self:_draw_final(canvas, time, game:score(), total)
    end

    self._particles:draw(canvas, 9.5)
    canvas:set_shake(0, 0)
    canvas:crt(20, 40, 560, 530, time, 10.5, { tint = COLORS.scan, scan_alpha = 22, vignette_depth = 60, vignette_alpha = 120, noise_count = 12 })
    canvas:finish()
end

function QuizView:destroy()
    self._canvas = nil
    self._particles = nil
    QuizView.super.destroy(self)
end

return QuizView
