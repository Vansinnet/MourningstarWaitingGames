local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_random = math.random
local math_sin = math.sin

local RENDER_SIZE = 600
local CELL_SIZE = 22
local CELL_VIS = 19
local GRID_W = 10
local GRID_H = 20
local BOARD_W = GRID_W * CELL_SIZE
local BOARD_H = GRID_H * CELL_SIZE
local PREVIEW_SIZE = 16

local COLORS = {
    [1] = { 255, 65, 212, 226 },
    [2] = { 255, 232, 202, 92 },
    [3] = { 255, 178, 126, 225 },
    [4] = { 255, 75, 211, 137 },
    [5] = { 255, 231, 101, 101 },
    [6] = { 255, 91, 146, 226 },
    [7] = { 255, 236, 160, 86 },
    bg = { 245, 0, 4, 2 },
    board = { 255, 3, 12, 13 },
    grid = { 42, 42, 119, 99 },
    grid_hot = { 85, 0, 220, 115 },
    ghost = { 74, 160, 230, 210 },
    core = { 190, 222, 255, 241 },
    dark_core = { 125, 5, 18, 22 },
    hud = { 255, 132, 233, 188 },
    hud_dim = { 220, 76, 165, 136 },
    warning = { 255, 255, 90, 50 },
    danger = { 130, 255, 40, 25 },
    clear = { 255, 255, 255, 255 },
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
        size = { BOARD_W, BOARD_H }, position = { -25, 20, 8 },
    },
    hold_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 92, 82 }, position = { -220, -150, 8 },
    },
    next_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 92, 210 }, position = { 205, -96, 8 },
    },
    title_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 500, 22 }, position = { 0, -280, 20 },
    },
    score_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 160, 22 }, position = { -220, -30, 20 },
    },
    level_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 160, 22 }, position = { -220, 4, 20 },
    },
    lines_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 160, 22 }, position = { -220, 38, 20 },
    },
    combo_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 160, 22 }, position = { -220, 72, 20 },
    },
    hold_label_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 100, 20 }, position = { -220, -210, 20 },
    },
    next_label_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 100, 20 }, position = { 205, -220, 20 },
    },
    message_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 410, 80 }, position = { -25, 20, 30 },
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

local function cell_def(parent, size)
    return UIWidget.create_definition({
        { pass_type = "texture", style_id = "glow",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 0, 0, 0, 0 }, offset = { -1, -1, 1 }, size = { size + 2, size + 2 } },
        },
        { pass_type = "texture", style_id = "cell",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 0, 0, 0, 0 }, offset = { 0, 0, 2 }, size = { size, size } },
        },
        { pass_type = "texture", style_id = "core",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 0, 0, 0, 0 }, offset = { 3, 3, 3 }, size = { size - 3, size - 3 } },
        },
        { pass_type = "texture", style_id = "shine",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 0, 0, 0, 0 }, offset = { 1, 1, 4 }, size = { size - 2, 2 } },
        },
    }, parent, nil, { size, size })
end

local function rect_def(parent)
    return UIWidget.create_definition({
        { pass_type = "texture", style_id = "gfx",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 0, 0, 0, 0 } },
        }
    }, parent, nil, { 1, 1 })
end

local widget_definitions = {
    scanner_bg = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.bg, offset = { -300, -300, 0 } },
        }
    }, "center_pivot", nil, { 600, 600 }),
    scanner_noise = UIWidget.create_definition({
        { pass_type = "texture", style_id = "noise",
            value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
            style = { hdr = true, color = { 105, 0, 130, 45 }, offset = { -300, -300, 1 }, angle = 0 },
        }
    }, "center_pivot", nil, { 600, 600 }),
    danger_tint = UIWidget.create_definition({
        { pass_type = "texture", style_id = "gfx", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 0, 0, 0, 0 }, offset = { -300, -300, 2 } },
        }
    }, "center_pivot", nil, { 600, 600 }),
    board_bg = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.board },
        }
    }, "board_area", nil, { BOARD_W, BOARD_H }),
    title_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "DATAFALL",
            style = { font_size = 22, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud, offset = { 0, 0, 1 } },
        }
    }, "title_area", nil, { 500, 22 }),
    hold_label = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "HOLD",
            style = { font_size = 14, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud_dim, offset = { 0, 0, 1 } },
        }
    }, "hold_label_area", nil, { 100, 20 }),
    next_label = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "NEXT",
            style = { font_size = 14, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud_dim, offset = { 0, 0, 1 } },
        }
    }, "next_label_area", nil, { 100, 20 }),
    score_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = { font_size = 16, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud, offset = { 0, 0, 1 } },
        }
    }, "score_area", nil, { 160, 22 }),
    level_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = { font_size = 16, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud, offset = { 0, 0, 1 } },
        }
    }, "level_area", nil, { 160, 22 }),
    lines_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = { font_size = 16, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud, offset = { 0, 0, 1 } },
        }
    }, "lines_area", nil, { 160, 22 }),
    combo_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = { font_size = 16, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.warning, offset = { 0, 0, 1 } },
        }
    }, "combo_area", nil, { 160, 22 }),
    message_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = { font_size = 38, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = { 0, 0, 0, 0 }, offset = { 0, 0, 1 } },
        }
    }, "message_area", nil, { 410, 80 }),
    controls_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = mod:localize("tetris_controls"),
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
}

AuspexFrame.add(widget_definitions, {
    render_size = RENDER_SIZE,
    outline_size = { 620, 620 },
})
AuspexFrame.add_inner_border(widget_definitions, {
    render_size = RENDER_SIZE,
    size = { BOARD_W, BOARD_H },
    center = { -25, 20 },
    prefix = "tetris_board_border",
})

-- Fixed panel passes keep the ornament cost independent of the stack height.
for name, panel in pairs({
    hold = { "hold_area", 92, 82 },
    next = { "next_area", 92, 210 },
    telemetry = { "score_area", 150, 128 },
}) do
    local width, height = panel[2], panel[3]
    widget_definitions["inset_" .. name] = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 255, 2, 9, 11 }, size = { width + 4, height + 4 }, offset = { -2, -2, -3 } } },
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 255, 9, 24, 25 }, size = { width, height }, offset = { 0, 0, -2 } } },
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 150, 64, 150, 120 }, size = { width, 1 }, offset = { 0, 0, -1 } } },
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.hud, size = { 18, 2 }, offset = { 0, 0, 0 } } },
    }, panel[1], nil, { width, height })
end

for col = 0, GRID_W - 1, 2 do
    widget_definitions["board_lane_" .. col] = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 70, 13, 32, 31 }, offset = { col * CELL_SIZE, 0, 1 } } },
    }, "board_area", nil, { CELL_SIZE, BOARD_H })
end

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }

local TetrisView = class("TetrisView", "BaseView")

local function set_color(dst, src, alpha)
    dst[1] = alpha or src[1]
    dst[2] = src[2]
    dst[3] = src[3]
    dst[4] = src[4]
end

local function clear_cell(w)
    w.style.glow.color[1] = 0
    w.style.cell.color[1] = 0
    w.style.core.color[1] = 0
    w.style.shine.color[1] = 0
end

local function draw_cell(w, x, y, size, color, alpha, z, ghost, lock_pulse)
    alpha = alpha or color[1]
    w.content.size[1] = size
    w.content.size[2] = size
    w.offset[1] = x
    w.offset[2] = y
    w.offset[3] = z or 5

    w.style.glow.offset[1] = -1
    w.style.glow.offset[2] = -1
    w.style.glow.offset[3] = 1
    w.style.glow.size[1] = size + 2
    w.style.glow.size[2] = size + 2
    set_color(w.style.glow.color, color, ghost and 0 or math_min(60, alpha * 0.18 + (lock_pulse or 0) * 14))

    set_color(w.style.cell.color, color, alpha)
    w.style.cell.offset[1] = 0
    w.style.cell.offset[2] = 0
    w.style.cell.offset[3] = 2
    w.style.cell.size[1] = size
    w.style.cell.size[2] = size

    local core_size = size - (ghost and 2 or 3)
    w.style.core.offset[1] = ghost and 1 or 3
    w.style.core.offset[2] = ghost and 1 or 3
    w.style.core.offset[3] = 3
    set_color(w.style.core.color, ghost and COLORS.board or COLORS.dark_core, ghost and 255 or math_floor(alpha * 0.48))

    w.style.shine.offset[1] = 1
    w.style.shine.offset[2] = 1
    w.style.shine.offset[3] = 4
    set_color(w.style.shine.color, COLORS.core, ghost and 0 or math_min(alpha, 85 + (lock_pulse or 0) * 90))

    w.style.core.size[1] = core_size
    w.style.core.size[2] = core_size
    w.style.shine.size[1] = size - 2
    w.style.shine.size[2] = 2
end

local function draw_rect(w, x, y, width, height, color, alpha, z)
    w.content.size[1] = width
    w.content.size[2] = height
    w.offset[1] = x
    w.offset[2] = y
    w.offset[3] = z or 5
    set_color(w.style.gfx.color, color, alpha)
end

local function clear_rect(w)
    w.style.gfx.color[1] = 0
end

function TetrisView:init(settings, context)
    TetrisView.super.init(self, definitions, settings, context)

    self._game = context.game
    self._no_cursor = true

    self._cells = {}
    local board_def = cell_def("board_area", CELL_VIS)
    for row = 0, GRID_H - 1 do
        for col = 0, GRID_W - 1 do
            local idx = row * GRID_W + col + 1
            local widget = UIWidget.init("tetris_cell_" .. idx, board_def)
            widget.offset[1] = col * CELL_SIZE + 1
            widget.offset[2] = row * CELL_SIZE + 1
            widget.offset[3] = 5
            self._cells[idx] = widget
        end
    end

    self._ghost_cells = {}
    self._active_cells = {}
    for i = 1, 4 do
        self._ghost_cells[i] = UIWidget.init("tetris_ghost_" .. i, cell_def("board_area", CELL_VIS))
        self._active_cells[i] = UIWidget.init("tetris_active_" .. i, cell_def("board_area", CELL_VIS))
    end

    self._hold_cells = {}
    for i = 1, 16 do
        self._hold_cells[i] = UIWidget.init("tetris_hold_" .. i, cell_def("hold_area", PREVIEW_SIZE))
    end

    self._next_cells = {}
    for i = 1, 48 do
        self._next_cells[i] = UIWidget.init("tetris_next_" .. i, cell_def("next_area", PREVIEW_SIZE))
    end

    self._grid_widgets = {}
    for i = 1, 32 do
        self._grid_widgets[i] = UIWidget.init("tetris_grid_" .. i, rect_def("board_area"))
    end
end

function TetrisView:dialogue_system() return nil end
function TetrisView:is_using_input() return false end

function TetrisView:update(dt, t, input_service)
    if self._game then self._game:update(dt) end
    return TetrisView.super.update(self, dt, t, input_service)
end

function TetrisView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    if self._game then
        local score_w = self._widgets_by_name.score_text
        if score_w then score_w.content.text = string.format("Score: %06d", self._game:score()) end

        local level_w = self._widgets_by_name.level_text
        if level_w then level_w.content.text = string.format("Level: %d", self._game:level()) end

        local lines_w = self._widgets_by_name.lines_text
        if lines_w then lines_w.content.text = string.format("Lines: %d", self._game:lines()) end

        local combo_w = self._widgets_by_name.combo_text
        if combo_w then
            local combo = self._game:combo()
            local b2b = self._game:is_b2b()
            combo_w.content.text = combo > 0 and string.format("Combo: %d", combo) or b2b and "B2B READY" or ""
        end

        local message_w = self._widgets_by_name.message_text
        if message_w then
            if self._game:is_game_over() then
                message_w.content.text = "GAME OVER"
                message_w.style.text.text_color = COLORS.warning
            else
                local last_clear = self._game:last_clear()
                if last_clear == 4 and self._game:drop_flash() > 0 then
                    message_w.content.text = "TETRIS"
                    message_w.style.text.text_color = COLORS.warning
                else
                    message_w.content.text = ""
                    message_w.style.text.text_color = { 0, 0, 0, 0 }
                end
            end
        end

        local danger = self:_stack_danger()
        local danger_w = self._widgets_by_name.danger_tint
        if danger_w then
            set_color(danger_w.style.gfx.color, COLORS.danger, math_floor(danger * 120))
        end

        local noise = self._widgets_by_name.scanner_noise
        if noise then
            noise.style.noise.color[1] = 32 + math_floor((math_sin(self._game:time() * 2.1) + 1) * 6) + math_floor(self._game:shake() * 30)
        end
    end

    local hsw = self._widgets_by_name.highscore_text
    if hsw then hsw.content.text = mod:localize("tetris_highscore") .. " " .. (mod:get("tetris_highscore") or 0) end

    TetrisView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

    if not self._game then return end
    self:_draw_dynamic(ui_renderer)
end

function TetrisView:_draw_dynamic(ui_renderer)
    local shake = self._game:shake()
    local sx = (math_random() - 0.5) * shake * 8
    local sy = (math_random() - 0.5) * shake * 8

    self:_draw_grid(ui_renderer, sx, sy)
    self:_draw_board(ui_renderer, sx, sy)
    self:_draw_ghost(ui_renderer, sx, sy)
    self:_draw_active(ui_renderer, sx, sy)
    self:_draw_hold(ui_renderer)
    self:_draw_next(ui_renderer)
end

function TetrisView:_draw_grid(ui_renderer, sx, sy)
    local idx = 1

    for col = 0, GRID_W do
        local w = self._grid_widgets[idx]
        draw_rect(w, col * CELL_SIZE + sx, sy, 1, BOARD_H, COLORS.grid, (col == 0 or col == GRID_W) and 95 or 28, 2)
        UIWidget.draw(w, ui_renderer)
        idx = idx + 1
    end

    for row = 0, GRID_H do
        local w = self._grid_widgets[idx]
        draw_rect(w, sx, row * CELL_SIZE + sy, BOARD_W, 1, COLORS.grid, (row == 0 or row == GRID_H) and 95 or 22, 2)
        UIWidget.draw(w, ui_renderer)
        idx = idx + 1
    end

    for i = idx, #self._grid_widgets do
        clear_rect(self._grid_widgets[i])
    end
end

function TetrisView:_draw_board(ui_renderer, sx, sy)
    local board = self._game:board()
    local clearing = self:_clearing_lookup()
    local t = self._game:time()

    for i = 1, GRID_W * GRID_H do
        local color_id = board[i]
        local w = self._cells[i]

        if color_id > 0 then
            local row = math_floor((i - 1) / GRID_W)
            local color = COLORS[color_id]
            local alpha = color[1]
            local lock_pulse = 0

            if clearing[row] then
                color = COLORS.clear
                alpha = 120 + math_floor((math_sin(t * 38 + row) + 1) * 67)
                lock_pulse = 1
            end

            draw_cell(w, ((i - 1) % GRID_W) * CELL_SIZE + 1 + sx, row * CELL_SIZE + 1 + sy, CELL_VIS, color, alpha, 5, false, lock_pulse)
            UIWidget.draw(w, ui_renderer)
        else
            clear_cell(w)
        end
    end
end

function TetrisView:_draw_ghost(ui_renderer, sx, sy)
    local cells = self._game:ghost_piece_cells()

    for i = 1, 4 do
        local cell = cells[i]
        local w = self._ghost_cells[i]

        if cell and cell.row >= 0 and cell.row < GRID_H then
            draw_cell(w, cell.col * CELL_SIZE + 1 + sx, cell.row * CELL_SIZE + 1 + sy, CELL_VIS, COLORS.ghost, 62, 4, true, 0)
            UIWidget.draw(w, ui_renderer)
        else
            clear_cell(w)
        end
    end
end

function TetrisView:_draw_active(ui_renderer, sx, sy)
    local cells = self._game:falling_piece_cells()
    local pulse = self._game:lock_progress()

    for i = 1, 4 do
        local cell = cells[i]
        local w = self._active_cells[i]

        if cell and cell.row >= 0 and cell.row < GRID_H then
            local color = COLORS[cell.color]
            local alpha = color[1]

            if pulse > 0.65 then
                alpha = math_min(255, alpha + math_floor((math_sin(self._game:time() * 28) + 1) * 50))
            end

            draw_cell(w, cell.col * CELL_SIZE + 1 + sx, cell.row * CELL_SIZE + 1 + sy, CELL_VIS, color, alpha, 8, false, pulse)
            UIWidget.draw(w, ui_renderer)
        else
            clear_cell(w)
        end
    end
end

function TetrisView:_draw_hold(ui_renderer)
    local cells = self._game:hold_piece_cells()
    self:_draw_preview(ui_renderer, self._hold_cells, cells, 0, self._game:can_hold() and 1 or 0.35)
end

function TetrisView:_draw_next(ui_renderer)
    local index = 1

    for slot = 1, 3 do
        local cells = self._game:next_piece_cells(slot)
        index = self:_draw_preview(ui_renderer, self._next_cells, cells, (slot - 1) * 64, 1, index)
    end

    for i = index, #self._next_cells do
        clear_cell(self._next_cells[i])
    end
end

function TetrisView:_draw_preview(ui_renderer, widgets, cells, y_offset, alpha_mult, start_index)
    local index = start_index or 1
    local min_col, max_col, min_row, max_row = 9, 0, 9, 0

    for i = 1, #cells do
        local cell = cells[i]
        min_col = math_min(min_col, cell.col)
        max_col = math_max(max_col, cell.col)
        min_row = math_min(min_row, cell.row)
        max_row = math_max(max_row, cell.row)
    end

    local width = (max_col - min_col + 1) * PREVIEW_SIZE
    local height = (max_row - min_row + 1) * PREVIEW_SIZE
    local ox = 46 - width * 0.5
    local oy = 10 + y_offset + (48 - height) * 0.5

    for i = 1, #cells do
        local cell = cells[i]
        local w = widgets[index]
        if not w then return index end

        local color = COLORS[cell.color]
        draw_cell(w, ox + (cell.col - min_col) * PREVIEW_SIZE, oy + (cell.row - min_row) * PREVIEW_SIZE, PREVIEW_SIZE - 2, color, math_floor(color[1] * alpha_mult), 6, false, 0)
        UIWidget.draw(w, ui_renderer)
        index = index + 1
    end

    if not start_index then
        for i = index, #widgets do
            clear_cell(widgets[i])
        end
    end

    return index
end

function TetrisView:_clearing_lookup()
    local lookup = {}
    local rows = self._game:clearing_rows()

    for i = 1, #rows do
        lookup[rows[i]] = true
    end

    return lookup
end

function TetrisView:_stack_danger()
    local board = self._game:board()
    local top = GRID_H
    local found = false

    for row = 0, GRID_H - 1 do
        if found then break end

        for col = 0, GRID_W - 1 do
            if board[row * GRID_W + col + 1] > 0 then
                top = row
                found = true
                break
            end
        end
    end

    if top >= 8 then return 0 end
    return (8 - top) / 8
end

function TetrisView:destroy() TetrisView.super.destroy(self) end

return TetrisView
