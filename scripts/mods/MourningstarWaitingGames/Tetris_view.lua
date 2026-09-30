local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")
local Gfx = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_canvas")

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_abs = math.abs
local math_pi = math.pi
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
    board_top = { 255, 3, 16, 18 },
    board_low = { 255, 1, 6, 8 },
    beam = { 255, 110, 255, 225 },
    shadow = { 255, 0, 0, 0 },
    dust = { 255, 170, 235, 215 },
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

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }

local TetrisView = class("TetrisView", "BaseView")

local function set_color(dst, src, alpha)
    dst[1] = alpha or src[1]
    dst[2] = src[2]
    dst[3] = src[3]
    dst[4] = src[4]
end

function TetrisView:init(settings, context)
    TetrisView.super.init(self, definitions, settings, context)

    self._game = context.game
    self._no_cursor = true
    self._canvas = Gfx.Canvas.new(RENDER_SIZE, RENDER_SIZE, 7500)
    self._particles = Gfx.Particles.new(360)
    self._shaker = Gfx.Shaker.new()
    self._time = 0
    self._prev_filled = nil
    self._prev_active = {}
    self._prev_ghost = {}
    self._prev_clearing = 0
    self._prev_lines = nil
    self._prev_level = nil
    self._prev_drop_flash = 0
    self._clear_anim = 0
    self._clear_rows = {}
    self._big_flash = 0
    self._level_flash = 0
    self._streaks = {}
    self._impacts = {}
end

function TetrisView:dialogue_system() return nil end
function TetrisView:is_using_input() return false end

function TetrisView:update(dt, t, input_service)
    if self._game then self._game:update(dt) end
    return TetrisView.super.update(self, dt, t, input_service)
end

local function copy_cells(dst, cells)
    for i = 1, 4 do
        local c = cells and cells[i]
        local d = dst[i]
        if c then
            if not d then
                d = {}
                dst[i] = d
            end
            d.col, d.row, d.color = c.col, c.row, c.color
        else
            dst[i] = nil
        end
    end
end

function TetrisView:_area_offset(name, base)
    local p = self:_scenegraph_world_position(name)
    return p[1] - base[1], p[2] - base[2]
end

function TetrisView:_detect_events(bx, by)
    local game = self._game
    local board = game:board()
    local filled = 0

    for i = 1, GRID_W * GRID_H do
        if board[i] > 0 then filled = filled + 1 end
    end

    local particles = self._particles
    local clearing = game:clearing_rows()
    local drop_flash = game:drop_flash()

    if self._prev_filled and filled > self._prev_filled then
        local ghost = self._prev_ghost
        local active = self._prev_active
        local hard = drop_flash > self._prev_drop_flash + 0.05

        for i = 1, #ghost do
            local g = ghost[i]
            local cx = bx + g.col * CELL_SIZE + CELL_SIZE * 0.5
            local cy = by + g.row * CELL_SIZE + CELL_SIZE
            local color = COLORS[g.color] or COLORS.dust
            particles:burst(cx, cy, hard and 5 or 2, 20, hard and 160 or 70, 0.2, 0.45, 1.4, color, "spark", 4, 180, -math_pi * 0.5, 2.6)

            local a = active[i]
            if hard and a and g.row - a.row > 1 then
                self._streaks[#self._streaks + 1] = { x = g.col * CELL_SIZE, y0 = a.row * CELL_SIZE, y1 = g.row * CELL_SIZE, life = 0.28, color = color }
            end
        end

        if hard then
            self._impacts[#self._impacts + 1] = { life = 0.35 }
            self._shaker:add(0.2)
        end
    end

    if #clearing > 0 and self._prev_clearing == 0 then
        self._clear_anim = 0
        for i = 1, #clearing do
            local row = clearing[i]
            self._clear_rows[i] = row
            local cy = by + row * CELL_SIZE + CELL_SIZE * 0.5
            for col = 0, GRID_W - 1 do
                local color = COLORS[board[row * GRID_W + col + 1]] or COLORS.clear
                particles:burst(bx + col * CELL_SIZE + CELL_SIZE * 0.5, cy, 3, 60, 260, 0.35, 0.8, 1.8, color, "spark", 2.5, 140)
            end
            particles:burst(bx + BOARD_W * 0.5, cy, 10, 30, 140, 0.5, 1.0, 3, COLORS.clear, "ember", 1.5, -30)
        end
        for i = #clearing + 1, #self._clear_rows do self._clear_rows[i] = nil end
        self._shaker:add(0.15 + #clearing * 0.12)

        if #clearing >= 4 then
            self._big_flash = 1
            particles:shockwave(bx + BOARD_W * 0.5, by + clearing[1] * CELL_SIZE, 260, 0.7, COLORS.warning, 5)
            particles:flash(bx + BOARD_W * 0.5, by + clearing[1] * CELL_SIZE, 180, 0.4, COLORS.warning)
        end
    end

    local lines = game:lines()
    local level = game:level()
    if self._prev_level and level > self._prev_level then
        self._level_flash = 1
        particles:shockwave(bx + BOARD_W * 0.5, by + BOARD_H * 0.5, 320, 0.9, COLORS.hud, 4)
    end

    self._prev_filled = filled
    self._prev_clearing = #clearing
    self._prev_lines = lines
    self._prev_level = level
    self._prev_drop_flash = drop_flash
    copy_cells(self._prev_active, game:falling_piece_cells())
    copy_cells(self._prev_ghost, game:ghost_piece_cells())
end

function TetrisView:_draw_block(canvas, x, y, size, color, alpha, layer, glow, white)
    if glow and glow > 0 then
        canvas:soft_rect(x, y, size, size, 5, layer - 0.3, color, glow, 3)
    end
    canvas:rect(x + 2, y + 3, size, size, layer - 0.1, COLORS.shadow, alpha * 0.45)
    canvas:bevel_box(x, y, size, size, math_max(2, size * 0.17), layer, color, alpha, 0.62, 0.36)
    canvas:rect(x + size * 0.5 - 1.5, y + size * 0.5 - 1.5, 3, 3, layer + 0.05, color, alpha * 0.6, 1, 0.6)

    if white and white > 0 then
        canvas:rect(x, y, size, size, layer + 0.06, COLORS.clear, white)
    end
end

function TetrisView:_draw_board_bg(canvas, bx, by, t, active)
    canvas:soft_rect(bx, by, BOARD_W, BOARD_H, 14, 7.5, COLORS.grid_hot, 40 + self._level_flash * 120, 5)
    canvas:vgradient(bx, by, BOARD_W, BOARD_H, 8.1, COLORS.board_top, COLORS.board_low, 255, 255, 28)

    for col = 0, GRID_W - 1, 2 do
        canvas:rect(bx + col * CELL_SIZE, by, CELL_SIZE, BOARD_H, 8.2, COLORS.grid, 20)
    end

    -- Spotlight column under the falling piece.
    if active and #active > 0 then
        local min_col, max_col, max_row = 99, -1, 0
        for i = 1, #active do
            local c = active[i]
            min_col = math_min(min_col, c.col)
            max_col = math_max(max_col, c.col)
            max_row = math_max(max_row, c.row)
        end
        local x = bx + min_col * CELL_SIZE
        local w = (max_col - min_col + 1) * CELL_SIZE
        local y = by + math_max(0, max_row + 1) * CELL_SIZE
        canvas:vgradient(x, y, w, by + BOARD_H - y, 8.25, COLORS.beam, COLORS.beam, 26, 4, 10)
    end

    for row = 0, GRID_H do
        for col = 0, GRID_W do
            local pulse = (math_sin(t * 2.4 - row * 0.35 + col * 0.2) + 1) * 0.5
            canvas:rect(bx + col * CELL_SIZE - 0.75, by + row * CELL_SIZE - 0.75, 1.5, 1.5, 8.3, COLORS.grid_hot, 40 + pulse * 70)
        end
    end

    local danger = self:_stack_danger()
    if danger > 0 then
        local pulse = (math_sin(t * 7) + 1) * 0.5
        canvas:vgradient(bx, by, BOARD_W, BOARD_H * 0.45, 8.35, COLORS.warning, COLORS.warning, danger * (70 + pulse * 60), 0, 14)
    end
end

function TetrisView:_draw_board(canvas, bx, by, t)
    local game = self._game
    local board = game:board()
    local clearing = self:_clearing_lookup()
    local clear_k = self._clear_anim

    for i = 1, GRID_W * GRID_H do
        local color_id = board[i]

        if color_id > 0 then
            local row = math_floor((i - 1) / GRID_W)
            local col = (i - 1) % GRID_W
            local x = bx + col * CELL_SIZE + 1.5
            local y = by + row * CELL_SIZE + 1.5

            if clearing[row] then
                local center_d = math_abs(col - 4.5) / 5
                local white = math_min(255, 120 + clear_k * 600 - center_d * 120)
                local shrink = math_max(0, (clear_k - 0.45) * 1.8) * CELL_VIS * 0.5
                self:_draw_block(canvas, x + shrink, y + shrink, CELL_VIS - shrink * 2, COLORS[color_id], 255, 12, 90, white)
            else
                self:_draw_block(canvas, x, y, CELL_VIS, COLORS[color_id], 255, 12)
            end
        end
    end

    for i = 1, #self._clear_rows do
        local row = self._clear_rows[i]
        if clearing[row] then
            local cy = by + row * CELL_SIZE + CELL_SIZE * 0.5
            local half = math_min(1, clear_k * 2.5) * (BOARD_W * 0.5 + 30)
            canvas:glow_line(bx + BOARD_W * 0.5 - half, cy, bx + BOARD_W * 0.5 + half, cy, 3 + clear_k * 5, 14.5, COLORS.clear, 255 * (1 - clear_k * 0.6), 3)
        end
    end
end

function TetrisView:_draw_ghost_and_active(canvas, bx, by, t)
    local game = self._game
    local ghost = game:ghost_piece_cells()
    local active = game:falling_piece_cells()
    local pulse = (math_sin(t * 6) + 1) * 0.5

    for i = 1, #ghost do
        local c = ghost[i]
        if c.row >= 0 and c.row < GRID_H then
            local x = bx + c.col * CELL_SIZE + 1.5
            local y = by + c.row * CELL_SIZE + 1.5
            local color = COLORS[c.color] or COLORS.ghost
            canvas:rect(x, y, CELL_VIS, CELL_VIS, 11.5, color, 26 + pulse * 18)
            canvas:line(x, y, x + CELL_VIS, y, 1.2, 11.6, color, 170)
            canvas:line(x + CELL_VIS, y, x + CELL_VIS, y + CELL_VIS, 1.2, 11.6, color, 170)
            canvas:line(x + CELL_VIS, y + CELL_VIS, x, y + CELL_VIS, 1.2, 11.6, color, 170)
            canvas:line(x, y + CELL_VIS, x, y, 1.2, 11.6, color, 170)
        end
    end

    local lock = game:lock_progress()
    for i = 1, #active do
        local c = active[i]
        if c.row >= 0 and c.row < GRID_H then
            local color = COLORS[c.color]
            local white = lock > 0.65 and (math_sin(t * 28) + 1) * 45 or 0
            self:_draw_block(canvas, bx + c.col * CELL_SIZE + 1.5, by + c.row * CELL_SIZE + 1.5, CELL_VIS, color, 255, 13, 70 + pulse * 40, white)
        end
    end

    for i = #self._streaks, 1, -1 do
        local s = self._streaks[i]
        local k = s.life / 0.28
        canvas:vgradient(bx + s.x + 3, by + s.y0, CELL_SIZE - 6, s.y1 - s.y0 + CELL_SIZE, 12.8, s.color, s.color, 0, 150 * k, 10)
        canvas:vgradient(bx + s.x + CELL_SIZE * 0.5 - 1, by + s.y0, 2, s.y1 - s.y0 + CELL_SIZE, 12.85, COLORS.clear, COLORS.clear, 0, 230 * k, 6)
    end
end

function TetrisView:_draw_preview(canvas, cells, area_x, area_y, y_offset, alpha)
    if #cells == 0 then return end

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
    local ox = area_x + 46 - width * 0.5
    local oy = area_y + 10 + y_offset + (48 - height) * 0.5
    local color = COLORS[cells[1].color] or COLORS.hud

    canvas:glow(area_x + 46, oy + height * 0.5, 34, 11.2, color, 55 * alpha / 255)

    for i = 1, #cells do
        local cell = cells[i]
        self:_draw_block(canvas, ox + (cell.col - min_col) * PREVIEW_SIZE, oy + (cell.row - min_row) * PREVIEW_SIZE, PREVIEW_SIZE - 2, COLORS[cell.color], alpha, 12)
    end
end

function TetrisView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local game = self._game

    if game then
        local score_w = self._widgets_by_name.score_text
        if score_w then score_w.content.text = string.format("Score: %06d", game:score()) end

        local level_w = self._widgets_by_name.level_text
        if level_w then level_w.content.text = string.format("Level: %d", game:level()) end

        local lines_w = self._widgets_by_name.lines_text
        if lines_w then lines_w.content.text = string.format("Lines: %d", game:lines()) end

        local combo_w = self._widgets_by_name.combo_text
        if combo_w then
            local combo = game:combo()
            local b2b = game:is_b2b()
            combo_w.content.text = combo > 0 and string.format("Combo: %d", combo) or b2b and "B2B READY" or ""
        end

        local message_w = self._widgets_by_name.message_text
        if message_w then
            if game:is_game_over() then
                message_w.content.text = "GAME OVER"
                message_w.style.text.text_color = COLORS.warning
            else
                local last_clear = game:last_clear()
                if last_clear == 4 and game:drop_flash() > 0 then
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
            noise.style.noise.color[1] = 32 + math_floor((math_sin(game:time() * 2.1) + 1) * 6) + math_floor(game:shake() * 30)
        end
    end

    local hsw = self._widgets_by_name.highscore_text
    if hsw then hsw.content.text = mod:localize("tetris_highscore") .. " " .. (mod:get("tetris_highscore") or 0) end

    TetrisView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

    if not game then return end

    dt = math_min(dt or 0.016, 0.05)
    self._time = self._time + dt

    local base = self:_scenegraph_world_position("scanner_base")
    local bx, by = self:_area_offset("board_area", base)

    self:_detect_events(bx, by)
    self._particles:update(dt)
    self._shaker:update(dt, 7)
    self._clear_anim = math_min(1, self._clear_anim + dt / 0.36)
    self._big_flash = math_max(0, self._big_flash - dt * 1.6)
    self._level_flash = math_max(0, self._level_flash - dt * 1.2)

    for i = #self._streaks, 1, -1 do
        local s = self._streaks[i]
        s.life = s.life - dt
        if s.life <= 0 then table.remove(self._streaks, i) end
    end

    local canvas = self._canvas
    if not canvas:begin(ui_renderer, base) then return end

    local time = self._time
    local shake = game:shake()
    local sx = (math_random() - 0.5) * shake * 8 + self._shaker.x
    local sy = (math_random() - 0.5) * shake * 8 + self._shaker.y

    canvas:set_shake(sx, sy)
    self:_draw_board_bg(canvas, bx, by, time, game:falling_piece_cells())
    canvas:set_clip(bx, by - 4, bx + BOARD_W, by + BOARD_H)
    self:_draw_board(canvas, bx, by, time)
    self:_draw_ghost_and_active(canvas, bx, by, time)
    canvas:reset_clip()
    self._particles:draw(canvas, 16)
    canvas:set_shake(0, 0)

    local hx, hy = self:_area_offset("hold_area", base)
    self:_draw_preview(canvas, game:hold_piece_cells(), hx, hy, 0, game:can_hold() and 255 or 90)

    local nx, ny = self:_area_offset("next_area", base)
    for slot = 1, 3 do
        self:_draw_preview(canvas, game:next_piece_cells(slot), nx, ny, (slot - 1) * 64, slot == 1 and 255 or 190)
    end

    if self._big_flash > 0 then
        canvas:rect(bx, by, BOARD_W, BOARD_H, 17, COLORS.warning, self._big_flash * 120)
    end

    canvas:crt(bx, by, BOARD_W, BOARD_H, time, 18, { tint = COLORS.beam, vignette_depth = 40, vignette_alpha = 120, noise_count = 10, sweep_period = 4 })

    if game:is_game_over() then
        canvas:vgradient(bx, by, BOARD_W, BOARD_H, 18.5, COLORS.board_low, COLORS.danger, 120, 200, 16)
    end

    canvas:finish()
end

function TetrisView:_clearing_lookup()
    local lookup = self._clearing_cache or {}
    self._clearing_cache = lookup
    for k in pairs(lookup) do lookup[k] = nil end
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

function TetrisView:destroy()
    self._canvas = nil
    self._particles = nil
    TetrisView.super.destroy(self)
end

return TetrisView
