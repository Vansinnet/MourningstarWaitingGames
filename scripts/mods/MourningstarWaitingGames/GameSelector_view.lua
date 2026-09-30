local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")
local Gfx = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_canvas")

local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_sin = math.sin

local RENDER_SIZE = 600
local CARD_WIDTH = 104
local CARD_HEIGHT = 116

local GAMES = {
    { label = "game_type_tetris", description = "selector_desc_tetris", highscore = "tetris_highscore", color = { 255, 40, 235, 170 } },
    { label = "game_type_invaders", description = "selector_desc_invaders", highscore = "invaders_highscore", color = { 255, 245, 80, 70 } },
    { label = "game_type_quiz", description = "selector_desc_quiz", highscore = "quiz_highscore", color = { 255, 180, 245, 80 } },
    { label = "game_type_snake", description = "selector_desc_snake", highscore = "snake_highscore", color = { 255, 65, 255, 95 } },
    { label = "game_type_pong", description = "selector_desc_pong", highscore = "pong_highscore", color = { 255, 80, 205, 255 } },
    { label = "game_type_asteroids", description = "selector_desc_asteroids", highscore = "asteroids_highscore", color = { 255, 230, 80, 245 } },
    { label = "game_type_raycaster", description = "selector_desc_raycaster", highscore = "raycaster_highscore", color = { 255, 255, 190, 65 } },
    { label = "game_type_noosphere", description = "selector_desc_noosphere", highscore = "noosphere_highscore", color = { 255, 80, 230, 220 } },
    { label = "game_type_minesweeper", description = "selector_desc_minesweeper", highscore = "minesweeper_highscore", color = { 255, 215, 220, 230 }, best_time = true },
    { label = "game_type_solitaire", description = "selector_desc_solitaire", highscore = "solitaire_highscore", color = { 255, 90, 225, 110 } },
    { label = "game_type_hearts", description = "selector_desc_hearts", highscore = "hearts_highscore", color = { 255, 255, 95, 125 } },
    { label = "game_type_skifree", description = "selector_desc_skifree", highscore = "skifree_highscore", color = { 255, 150, 215, 255 }, suffix = "m" },
    { label = "game_type_breakout", description = "selector_desc_breakout", highscore = "breakout_highscore", color = { 255, 255, 110, 80 } },
    { label = "game_type_battlechess", description = "selector_desc_battlechess", highscore = "battlechess_highscore", color = { 255, 240, 200, 110 } },
}

-- Rows of five; a shorter last row is centred.
local CARD_POSITIONS = {}
for i = 1, #GAMES do
    local col = (i - 1) % 5
    local row = math.floor((i - 1) / 5)
    local in_row = math.min(5, #GAMES - row * 5)
    CARD_POSITIONS[i] = { (col - (in_row - 1) * 0.5) * 112, -151 + row * 126 }
end

local COLORS = {
    text = { 255, 190, 255, 225 },
    text_dim = { 230, 117, 164, 150 },
    frame_dim = { 100, 25, 105, 80 },
    card = { 220, 2, 14, 12 },
    card_selected = { 245, 5, 30, 25 },
    grid = { 255, 30, 170, 130 },
    white = { 255, 255, 255, 255 },
    shadow = { 255, 0, 0, 0 },
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
        size = { 540, 28 }, position = { 0, -272, 20 },
    },
    subtitle_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 540, 22 }, position = { 0, -240, 20 },
    },
    selection_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 520, 26 }, position = { 0, 190, 20 },
    },
    controls_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 570, 22 }, position = { 0, 235, 20 },
    },
    status_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 570, 20 }, position = { 0, 262, 20 },
    },
}

for i = 1, #CARD_POSITIONS do
    local position = CARD_POSITIONS[i]
    scenegraph["card_" .. i] = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { CARD_WIDTH, CARD_HEIGHT }, position = { position[1], position[2], 16 },
    }
end

local ICONS = {
    { "0011000", "0011000", "1111000", "1111000", "0011110", "0011110", "0000000" },
    { "0100010", "0010100", "0111110", "1101011", "1111111", "1010101", "0100010" },
    { "0011100", "0100010", "0000010", "0001100", "0001000", "0000000", "0001000" },
    { "0001111", "0001001", "1111000", "1000000", "1111100", "0000100", "0011100" },
    { "1000001", "1000001", "1001001", "1000001", "1000001", "1000001", "1000001" },
    { "0001000", "0001000", "0011100", "0011100", "0111110", "0110110", "1100011" },
    { "0011100", "0111110", "1100011", "1100011", "1100011", "1100011", "1100011" },
    { "0011100", "0100010", "1011101", "1010101", "1011101", "0100010", "0011100" },
    { "0001000", "0101010", "0011100", "1111111", "0011100", "0101010", "0001000" },
    { "1111000", "1001111", "1001001", "1111001", "0001001", "0001001", "0001111" },
    { "0110110", "1111111", "1111111", "1111111", "0111110", "0011100", "0001000" },
    { "0001000", "0011100", "0111110", "0011100", "0111110", "1111111", "0001000" },
    { "1101101", "1101101", "0000000", "0000000", "0001000", "0000000", "0111110" },
    { "0011000", "0111100", "1101110", "0001110", "0011100", "0111110", "1111111" },
}

local function card_definition(scenegraph_id, index)
    local passes = {
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 150, 0, 0, 0 }, offset = { 3, 5, -1 } },
        },
        {
            pass_type = "texture", style_id = "background",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.card, offset = { 0, 0, 0 } },
        },
        {
            pass_type = "texture", style_id = "frame",
            value = "content/ui/materials/frames/frame_tile_2px",
            style = { hdr = true, color = COLORS.frame_dim, scale_to_material = true, offset = { 0, 0, 3 } },
        },
        {
            pass_type = "texture", style_id = "accent",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.frame_dim, size = { CARD_WIDTH - 16, 2 }, offset = { 8, 8, 4 } },
        },
        {
            pass_type = "text", style_id = "title", value = "", value_id = "title",
            style = {
                font_size = 14, font_type = "machine_medium", size = { CARD_WIDTH - 10, 32 },
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.text, offset = { 5, 38, 5 },
            },
        },
        {
            pass_type = "text", style_id = "description", value = "", value_id = "description",
            style = {
                font_size = 11, font_type = "machine_medium", size = { CARD_WIDTH - 12, 24 },
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.text_dim, offset = { 6, 68, 5 },
            },
        },
        {
            pass_type = "text", style_id = "best", value = "", value_id = "best",
            style = {
                font_size = 11, font_type = "machine_medium", size = { CARD_WIDTH - 12, 20 },
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.text_dim, offset = { 6, 93, 5 },
            },
        },
    }
    local color = GAMES[index].color
    local icon = ICONS[index]
    for y = 1, #icon do
        for x = 1, #icon[y] do
            if icon[y]:sub(x, x) == "1" then
                passes[#passes + 1] = {
                    pass_type = "texture",
                    value = "content/ui/materials/backgrounds/default_square",
                    style = { color = { 220, color[2], color[3], color[4] },
                        size = { 3, 3 }, offset = { (CARD_WIDTH - 28) * 0.5 + (x - 1) * 4, 11 + (y - 1) * 4, 4 } },
                }
            end
        end
    end
    return UIWidget.create_definition(passes, scenegraph_id, nil, { CARD_WIDTH, CARD_HEIGHT })
end

local widget_definitions = {
    background = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 250, 0, 5, 4 } },
        },
    }, "scanner_base", nil, { RENDER_SIZE, RENDER_SIZE }),
    scanner_noise = UIWidget.create_definition({
        {
            pass_type = "rotated_texture", style_id = "noise",
            value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
            style = { hdr = true, color = { 80, 20, 150, 105 }, angle = 0, pivot = {}, offset = { -300, -300, 2 } },
        },
    }, "center_pivot", nil, { RENDER_SIZE, RENDER_SIZE }),
    title_text = UIWidget.create_definition({
        {
            pass_type = "text", value = mod:localize("selector_title"),
            style = {
                font_size = 20, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.text, offset = { 0, 0, 1 },
            },
        },
    }, "title_area", nil, { 540, 28 }),
    subtitle_text = UIWidget.create_definition({
        {
            pass_type = "text", value = mod:localize("selector_subtitle"),
            style = {
                font_size = 13, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.text_dim, offset = { 0, 0, 1 },
            },
        },
    }, "subtitle_area", nil, { 540, 22 }),
    selection_text = UIWidget.create_definition({
        {
            pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = {
                font_size = 17, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.text, offset = { 0, 0, 1 },
            },
        },
    }, "selection_area", nil, { 520, 26 }),
    controls_text = UIWidget.create_definition({
        {
            pass_type = "text", value = mod:localize("selector_controls"),
            style = {
                font_size = 13, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.text_dim, offset = { 0, 0, 1 },
            },
        },
    }, "controls_area", nil, { 570, 22 }),
    status_text = UIWidget.create_definition({
        {
            pass_type = "text", value = mod:localize("selector_status"),
            style = {
                font_size = 11, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = { 130, 45, 135, 115 }, offset = { 0, 0, 1 },
            },
        },
    }, "status_area", nil, { 570, 20 }),
}

for i = 1, #GAMES do
    widget_definitions["game_card_" .. i] = card_definition("card_" .. i, i)
end

AuspexFrame.add(widget_definitions, {
    render_size = RENDER_SIZE,
    outline_size = { 630, 620 },
    backdrop_alpha = 248,
    alpha = 165,
})

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }
local GameSelectorView = class("GameSelectorView", "BaseView")

local function set_color(destination, source, alpha)
    destination[1] = alpha or source[1]
    destination[2] = source[2]
    destination[3] = source[3]
    destination[4] = source[4]
end

function GameSelectorView:init(settings, context)
    GameSelectorView.super.init(self, definitions, settings, context)
    self._state = context.state
    self._no_cursor = true
    self._time = 0
    self._canvas = Gfx.Canvas.new(RENDER_SIZE, RENDER_SIZE, 4000)
    self._particles = Gfx.Particles.new(200)
    self._cursor_x = nil
    self._cursor_y = nil
    self._last_selected = nil
    self._select_flash = 0
    self._motes = {}
    for i = 1, 40 do
        self._motes[i] = { x = (i * 131.7) % RENDER_SIZE, y = (i * 71.3) % RENDER_SIZE, speed = 6 + (i * 17) % 18, phase = i * 1.9 }
    end
end

function GameSelectorView:dialogue_system() return nil end
function GameSelectorView:is_using_input() return false end

function GameSelectorView:update(dt, t, input_service)
    self._time = self._time + (dt or 0)
    return GameSelectorView.super.update(self, dt, t, input_service)
end

function GameSelectorView:_card_rect(base, index)
    local p = self:_scenegraph_world_position("card_" .. index)
    return p[1] - base[1], p[2] - base[2], CARD_WIDTH, CARD_HEIGHT
end

function GameSelectorView:_draw_background(canvas, t)
    local cx, cy = RENDER_SIZE * 0.5, RENDER_SIZE * 0.5 + 8

    for ring = 1, 5 do
        local r = ring * 58 + (t * 12) % 58
        canvas:ring(cx, cy, r, 1, 0.6, COLORS.grid, 22 * (1 - r / 360), 48)
    end
    canvas:radar(cx, cy, 290, t * 0.7, 0.62, COLORS.grid, 34, 1.2, 16)

    for gx = 20, RENDER_SIZE - 20, 30 do
        for gy = 50, RENDER_SIZE - 40, 30 do
            local wave = (math_sin(t * 1.5 - (gx + gy) * 0.012) + 1) * 0.5
            canvas:rect(gx - 0.75, gy - 0.75, 1.5, 1.5, 0.64, COLORS.grid, 18 + wave * 40)
        end
    end

    for i = 1, #self._motes do
        local m = self._motes[i]
        local y = (m.y - t * m.speed) % RENDER_SIZE
        local tw = (math_sin(t * 2 + m.phase) + 1) * 0.5
        canvas:rect(m.x, y, 1.6, 1.6, 0.66, COLORS.grid, 40 + tw * 80, 1, 0.3)
    end
end

function GameSelectorView:_draw_cards(canvas, base, t, selected_index)
    for i = 1, #GAMES do
        local x, y, w, h = self:_card_rect(base, i)
        local color = GAMES[i].color
        local selected = i == selected_index

        canvas:rect(x + 5, y + 7, w, h, 15, COLORS.shadow, 150)

        if selected then
            local pulse = (math_sin(t * 4) + 1) * 0.5
            canvas:soft_rect(x, y, w, h, 18 + pulse * 6, 15.1, color, 70 + pulse * 30, 6)
        end

        -- Icon halo sits between the card face and its pixel icon.
        local glow = selected and 110 + math_sin(t * 5) * 30 or 30
        canvas:glow(x + CARD_WIDTH * 0.5, y + 24, selected and 34 or 24, 16.3, color, glow, 4)

        if selected then
            canvas:sweep(x + 2, y + 2, w - 4, h - 4, t, 1.6, 20.4, color, 50, 40)
            for k = 0, 2 do
                local bar = (t * 1.8 + k / 3) % 1
                canvas:rect(x + 8, y + 8 + bar * 30, w - 16, 1, 16.4, color, 70 * (1 - bar))
            end
        end
    end
end

function GameSelectorView:_draw_cursor(canvas, base, t, selected_index)
    local x, y, w, h = self:_card_rect(base, selected_index)
    local color = GAMES[selected_index].color

    if not self._cursor_x then
        self._cursor_x, self._cursor_y = x, y
    end

    self._cursor_x = self._cursor_x + (x - self._cursor_x) * 0.25
    self._cursor_y = self._cursor_y + (y - self._cursor_y) * 0.25

    local cx, cy = self._cursor_x, self._cursor_y
    local pad = 7 + math_sin(t * 5) * 2 + self._select_flash * 10
    local arm = 20

    for qx = 0, 1 do
        for qy = 0, 1 do
            local px = cx + qx * w + (qx == 0 and -pad or pad)
            local py = cy + qy * h + (qy == 0 and -pad or pad)
            local dx = qx == 0 and 1 or -1
            local dy = qy == 0 and 1 or -1
            canvas:glow_line(px, py, px + dx * arm, py, 2, 21, color, 240, 2.5)
            canvas:glow_line(px, py, px, py + dy * arm, 2, 21, color, 240, 2.5)
            canvas:rect(px - 2, py - 2, 4, 4, 21.1, COLORS.white, 230)
        end
    end

    -- Travelling edge light around the selected card.
    local perimeter = 2 * (w + h)
    for k = 0, 1 do
        local d = (t * 260 + k * perimeter * 0.5) % perimeter
        local px, py
        if d < w then px, py = cx + d, cy
        elseif d < w + h then px, py = cx + w, cy + d - w
        elseif d < 2 * w + h then px, py = cx + w - (d - w - h), cy + h
        else px, py = cx, cy + h - (d - 2 * w - h) end
        canvas:glow(px, py, 12, 20.6, color, 150, 3)
        canvas:rect(px - 1.5, py - 1.5, 3, 3, 20.7, COLORS.white, 255)
    end
end

function GameSelectorView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local selected_index = self._state and self._state.selected or 1

    for i = 1, #GAMES do
        local game = GAMES[i]
        local widget = self._widgets_by_name["game_card_" .. i]

        if widget then
            local selected = i == selected_index
            local pulse = selected and 205 + math_floor((math_sin(self._time * 4) + 1) * 25) or 70

            widget.content.title = mod:localize(game.label)
            widget.content.description = mod:localize(game.description)
            if game.best_time then
                local level = mod:get("minesweeper_level") or "beginner"
                local best = level ~= "custom" and tonumber(mod:get("minesweeper_best_" .. level)) or nil
                widget.content.best = mod:localize(game.highscore) .. " " .. ((best and best > 0) and (best .. "s") or "-")
            else
                widget.content.best = mod:localize(game.highscore) .. " " .. (mod:get(game.highscore) or 0) .. (game.suffix or "")
            end
            set_color(widget.style.background.color, selected and COLORS.card_selected or COLORS.card)
            set_color(widget.style.frame.color, selected and game.color or COLORS.frame_dim, pulse)
            set_color(widget.style.accent.color, game.color, selected and 255 or 140)
            set_color(widget.style.title.text_color, COLORS.text, selected and 255 or 220)
            set_color(widget.style.description.text_color, selected and COLORS.text or COLORS.text_dim, selected and 235 or 210)
            set_color(widget.style.best.text_color, selected and game.color or COLORS.text_dim, selected and 240 or 200)
        end
    end

    local selected_game = GAMES[selected_index]
    local selection_widget = self._widgets_by_name.selection_text
    if selection_widget and selected_game then
        selection_widget.content.text = ">  " .. mod:localize(selected_game.label) .. "  <"
        set_color(selection_widget.style.text.text_color, selected_game.color)
    end

    local noise = self._widgets_by_name.scanner_noise
    if noise then noise.style.noise.angle = self._time * 0.025 end

    GameSelectorView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

    if not selected_game then return end

    local frame_dt = math_min(dt or 0.016, 0.05)
    local base = self:_scenegraph_world_position("scanner_base")

    if self._last_selected and self._last_selected ~= selected_index then
        local x, y, w, h = self:_card_rect(base, selected_index)
        self._particles:burst(x + w * 0.5, y + h * 0.5, 24, 60, 240, 0.3, 0.7, 1.6, selected_game.color, "spark", 3)
        self._particles:shockwave(x + w * 0.5, y + h * 0.5, 90, 0.4, selected_game.color, 2)
        self._select_flash = 1
    end
    self._last_selected = selected_index
    self._particles:update(frame_dt)
    self._select_flash = math_max(0, self._select_flash - frame_dt * 3)

    local canvas = self._canvas
    if not canvas:begin(ui_renderer, base) then return end

    local time = self._time
    self:_draw_background(canvas, time)
    self:_draw_cards(canvas, base, time, selected_index)
    self:_draw_cursor(canvas, base, time, selected_index)
    self._particles:draw(canvas, 21.5)
    canvas:crt(16, 48, RENDER_SIZE - 32, RENDER_SIZE - 64, time, 19.8, { tint = COLORS.grid, scan_alpha = 16, vignette_depth = 60, vignette_alpha = 110, noise_count = 10, flicker = false })
    canvas:finish()
end

function GameSelectorView:destroy()
    self._canvas = nil
    self._particles = nil
    GameSelectorView.super.destroy(self)
end

return GameSelectorView
