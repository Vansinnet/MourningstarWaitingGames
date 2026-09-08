local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")

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
local SEL_PREFIX = "  >  "

local QuizView = class("QuizView", "BaseView")

function QuizView:init(settings, context)
	QuizView.super.init(self, definitions, settings, context)
	self._game = context.game
	self._no_cursor = true
end

function QuizView:dialogue_system() return nil end
function QuizView:is_using_input() return false end

function QuizView:update(dt, t, input_service)
	if self._game then self._game:update(dt) end
	return QuizView.super.update(self, dt, t, input_service)
end

function QuizView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
	local hsw = self._widgets_by_name.highscore_text
	if hsw then hsw.content.text = mod:localize("quiz_highscore") .. " " .. (mod:get("quiz_highscore") or 0) end

	if not self._game then
        QuizView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
        return
    end

	local q = self._game:current_question()
	local idx = self._game:current_index()
	local total = self._game:total()
	local sel = self._game:selected()
	local feedback = self._game:is_showing_feedback()
	local last_correct = self._game:last_correct()

	local progress_w = self._widgets_by_name.progress_text
	if progress_w then
		if self._game:is_game_over() then
			progress_w.content.text = "Quiz complete!"
		elseif q then
			progress_w.content.text = string.format("Question %d/%d", idx, total)
		end
	end

	local score_w = self._widgets_by_name.score_text
	if score_w then
		score_w.content.text = string.format("Score: %d", self._game:score())
	end

	local q_w = self._widgets_by_name.question_text
	if q_w then
		if q then
			q_w.content.text = q.q
		elseif self._game:is_game_over() then
			local s = self._game:score()
			q_w.content.text = string.format("Final Score: %d / %d", s, total)
		end
	end

	if q then
		for i = 1, 4 do
			local w = self._widgets_by_name[ANSWER_NAMES[i]]
			if w then
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

                local panel = self._widgets_by_name["answer_panel_" .. i]
                if panel then
                    local active = i - 1 == sel or (feedback and i - 1 == q.correct)
                    local background = panel.style.background.color
                    background[1] = 235
                    background[2] = active and 29 or 9
                    background[3] = active and 39 or 23
                    background[4] = active and 32 or 22
                    for _, name in ipairs(PANEL_ACCENTS) do
                        local tint = panel.style[name].color
                        tint[1] = active and 220 or 65
                        tint[2], tint[3], tint[4] = color[2], color[3], color[4]
                    end
                end
			end
		end
	else
		for i = 1, 4 do
			local w = self._widgets_by_name[ANSWER_NAMES[i]]
			if w then w.content.text = "" end
            local panel = self._widgets_by_name["answer_panel_" .. i]
            if panel then
                panel.style.background.color[1] = 0
                panel.style.edge.color[1] = 0
                panel.style.accent.color[1] = 0
            end
		end
	end

	local fb_w = self._widgets_by_name.feedback_text
	if fb_w then
		if self._game:is_game_over() then
			fb_w.content.text = "Press Esc to close"
            fb_w.style.text.text_color = COLORS.feedback_text
		elseif feedback and q then
			fb_w.style.text.text_color = last_correct and COLORS.correct or COLORS.incorrect
			if last_correct then
				fb_w.content.text = "Correct! Press jump to continue."
			else
				fb_w.content.text = "Incorrect! Press jump to continue."
			end
		else
			fb_w.content.text = ""
		end
	end
    QuizView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

function QuizView:destroy() QuizView.super.destroy(self) end

return QuizView
