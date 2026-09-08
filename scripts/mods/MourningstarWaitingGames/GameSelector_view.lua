local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")

local RENDER_SIZE = 600
local CARD_WIDTH = 128
local CARD_HEIGHT = 150

local GAMES = {
    { label = "game_type_tetris", description = "selector_desc_tetris", highscore = "tetris_highscore", color = { 255, 40, 235, 170 } },
    { label = "game_type_invaders", description = "selector_desc_invaders", highscore = "invaders_highscore", color = { 255, 245, 80, 70 } },
    { label = "game_type_quiz", description = "selector_desc_quiz", highscore = "quiz_highscore", color = { 255, 180, 245, 80 } },
    { label = "game_type_snake", description = "selector_desc_snake", highscore = "snake_highscore", color = { 255, 65, 255, 95 } },
    { label = "game_type_pong", description = "selector_desc_pong", highscore = "pong_highscore", color = { 255, 80, 205, 255 } },
    { label = "game_type_asteroids", description = "selector_desc_asteroids", highscore = "asteroids_highscore", color = { 255, 230, 80, 245 } },
    { label = "game_type_raycaster", description = "selector_desc_raycaster", highscore = "raycaster_highscore", color = { 255, 255, 190, 65 } },
    { label = "game_type_noosphere", description = "selector_desc_noosphere", highscore = "noosphere_highscore", color = { 255, 80, 230, 220 } },
}

local CARD_POSITIONS = {
    { -210, -95 },
    { -70, -95 },
    { 70, -95 },
    { 210, -95 },
    { -210, 80 },
    { -70, 80 },
    { 70, 80 },
    { 210, 80 },
}

local COLORS = {
    text = { 255, 190, 255, 225 },
    text_dim = { 230, 117, 164, 150 },
    frame_dim = { 100, 25, 105, 80 },
    card = { 220, 2, 14, 12 },
    card_selected = { 245, 5, 30, 25 },
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
                font_size = 14, font_type = "machine_medium", size = { CARD_WIDTH - 10, 34 },
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.text, offset = { 5, 51, 5 },
            },
        },
        {
            pass_type = "text", style_id = "description", value = "", value_id = "description",
            style = {
                font_size = 11, font_type = "machine_medium", size = { CARD_WIDTH - 12, 28 },
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.text_dim, offset = { 6, 86, 5 },
            },
        },
        {
            pass_type = "text", style_id = "best", value = "", value_id = "best",
            style = {
                font_size = 11, font_type = "machine_medium", size = { CARD_WIDTH - 12, 20 },
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.text_dim, offset = { 6, 121, 5 },
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
                        size = { 3, 3 }, offset = { 50 + (x - 1) * 4, 19 + (y - 1) * 4, 4 } },
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
AuspexFrame.add_inner_border(widget_definitions, {
    render_size = RENDER_SIZE,
    size = { 568, 534 },
    center = { 0, 15 },
    prefix = "selector_border",
    color = { 120, 25, 180, 145 },
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
end

function GameSelectorView:dialogue_system() return nil end
function GameSelectorView:is_using_input() return false end

function GameSelectorView:update(dt, t, input_service)
    self._time = self._time + (dt or 0)
    return GameSelectorView.super.update(self, dt, t, input_service)
end

function GameSelectorView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local selected_index = self._state and self._state.selected or 1

    for i = 1, #GAMES do
        local game = GAMES[i]
        local widget = self._widgets_by_name["game_card_" .. i]

        if widget then
            local selected = i == selected_index
            local pulse = selected and 205 + math.floor((math.sin(self._time * 4) + 1) * 25) or 70

            widget.content.title = mod:localize(game.label)
            widget.content.description = mod:localize(game.description)
            widget.content.best = mod:localize(game.highscore) .. " " .. (mod:get(game.highscore) or 0)
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
end

function GameSelectorView:destroy()
    GameSelectorView.super.destroy(self)
end

return GameSelectorView
