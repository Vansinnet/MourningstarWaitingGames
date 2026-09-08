local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")

local math_floor = math.floor
local math_sin = math.sin

local RENDER_SIZE = 600
local GAME_W = 600
local GAME_H = 600
local ENEMY_WIDGETS = 55
local ENEMY_PIXELS = 1024
local SHIELD_WIDGETS = 640
local PLAYER_PIXELS = 36
local MYSTERY_PIXELS = 34
local BULLET_WIDGETS = 18
local STAR_WIDGETS = 55

local COLORS = {
    bg = { 245, 0, 5, 1 },
    grid = { 34, 0, 95, 52 },
    grid_hot = { 60, 0, 180, 95 },
    star = { 115, 0, 175, 120 },
    star_hot = { 185, 95, 240, 180 },
    invader_top = { 255, 160, 255, 110 },
    invader_mid = { 255, 0, 235, 120 },
    invader_low = { 255, 0, 205, 80 },
    invader_core = { 255, 220, 255, 220 },
    player = { 255, 0, 255, 105 },
    player_core = { 255, 170, 255, 185 },
    pbullet = { 255, 255, 255, 255 },
    ebullet = { 255, 255, 110, 35 },
    shield = { 235, 0, 200, 75 },
    shield_hot = { 255, 80, 255, 130 },
    mystery = { 255, 255, 170, 25 },
    mystery_hot = { 255, 255, 245, 120 },
    hud = { 255, 0, 230, 115 },
    hud_dim = { 170, 0, 165, 90 },
    warning = { 255, 255, 90, 50 },
    armor = { 255, 12, 95, 55 },
    message = { 210, 100, 255, 175 },
    hidden = { 0, 0, 0, 0 },
}

local INVADER_MASKS = {
    {
        "00111100",
        "01111110",
        "11011011",
        "11111111",
        "00100100",
        "01011010",
        "10100101",
    },
    {
        "00100100",
        "01111110",
        "11011011",
        "11111111",
        "11111111",
        "01000010",
        "10000001",
    },
    {
        "00011000",
        "00111100",
        "01111110",
        "11011011",
        "11111111",
        "00100100",
        "01000010",
    },
}

local PLAYER_MASK = {
    "0000001000000",
    "0000011100000",
    "0000011100000",
    "0111111111110",
    "1111111111111",
    "1111111111111",
}

local MYSTERY_MASK = {
    "0001111111000",
    "0111111111110",
    "1110111110111",
    "1111111111111",
    "0011000001100",
}

local function compile_mask(mask)
    local runs = {}
    for row = 1, #mask do
        local line = mask[row]
        local first = nil
        for col = 1, #line + 1 do
            if line:sub(col, col) == "1" then
                first = first or col
            elseif first then
                runs[#runs + 1] = { first - 1, row - 1, col - first, 1 - (row - 1) / #mask * 0.28 }
                first = nil
            end
        end
    end
    return runs
end

for i = 1, #INVADER_MASKS do
    INVADER_MASKS[i] = compile_mask(INVADER_MASKS[i])
end
PLAYER_MASK = compile_mask(PLAYER_MASK)
MYSTERY_MASK = compile_mask(MYSTERY_MASK)

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
        size = { GAME_W, GAME_H }, position = { 0, 0, 8 },
    },
    title_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 500, 22 }, position = { 0, -280, 20 },
    },
    score_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 180, 22 }, position = { -190, -250, 20 },
    },
    wave_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 180, 22 }, position = { 0, -250, 20 },
    },
    lives_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 180, 22 }, position = { 190, -250, 20 },
    },
    message_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 420, 80 }, position = { 0, 0, 25 },
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

local function rect_def()
    return UIWidget.create_definition({
        { pass_type = "texture", style_id = "gfx",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 0, 0, 0, 0 } },
        }
    }, "game_area", nil, { 1, 1 })
end

local widget_definitions = {
    bg = UIWidget.create_definition({
        { pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.bg },
        }
    }, "game_area", nil, { GAME_W, GAME_H }),
    scanner_noise = UIWidget.create_definition({
        { pass_type = "texture", style_id = "noise",
            value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
            style = { hdr = true, color = { 120, 0, 125, 45 }, offset = { -300, -300, 2 }, angle = 0 },
        }
    }, "center_pivot", nil, { 600, 600 }),
    border_top = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.grid_hot, offset = { -300, -300, 12 } },
        }
    }, "center_pivot", nil, { 600, 2 }),
    border_bottom = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.grid_hot, offset = { -300, 298, 12 } },
        }
    }, "center_pivot", nil, { 600, 2 }),
    border_left = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.grid_hot, offset = { -300, -300, 12 } },
        }
    }, "center_pivot", nil, { 2, 600 }),
    border_right = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.grid_hot, offset = { 298, -300, 12 } },
        }
    }, "center_pivot", nil, { 2, 600 }),
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
    title_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "VOID INVADERS",
            style = { font_size = 16, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud, offset = { 0, 0, 1 } },
        }
    }, "title_area", nil, { 500, 22 }),
    score_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = { font_size = 18, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud, offset = { 0, 0, 1 } },
        }
    }, "score_area", nil, { 180, 22 }),
    wave_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = { font_size = 16, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.hud_dim, offset = { 0, 0, 1 } },
        }
    }, "wave_area", nil, { 180, 22 }),
    lives_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = { font_size = 18, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.warning, offset = { 0, 0, 1 } },
        }
    }, "lives_area", nil, { 180, 22 }),
    message_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = { font_size = 38, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = { 0, 0, 0, 0 }, offset = { 0, 0, 1 } },
        }
    }, "message_area", nil, { 420, 80 }),
    controls_text = UIWidget.create_definition({
        { pass_type = "text", style_id = "text", value = mod:localize("invaders_controls"),
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
}

AuspexFrame.add(widget_definitions, {
    render_size = RENDER_SIZE,
    outline_size = { 620, 620 },
})
AuspexFrame.add_inner_border(widget_definitions, {
    render_size = RENDER_SIZE,
    size = { GAME_W, GAME_H },
    prefix = "invaders_game_border",
})

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }

local InvadersView = class("InvadersView", "BaseView")

local function set_color(dst, src, alpha)
    dst[1] = alpha or src[1]
    dst[2] = src[2]
    dst[3] = src[3]
    dst[4] = src[4]
end

local function clear_rect(w)
    w.style.gfx.color[1] = 0
end

local function draw_rect(w, x, y, width, height, color, alpha, z)
    w.content.size[1] = width
    w.content.size[2] = height
    w.offset[1] = x
    w.offset[2] = y
    w.offset[3] = z or 5
    set_color(w.style.gfx.color, color, alpha)
end

local function draw_mask(widgets, index, x, y, mask, pixel_size, color, alpha, z, gap, pixel_height)
    gap = gap or 0
    pixel_height = pixel_height or pixel_size

    for i = 1, #mask do
        local run = mask[i]
        local w = widgets[index]
        if not w then return index end
        draw_rect(w, x + run[1] * (pixel_size + gap), y + run[2] * (pixel_height + gap),
            run[3] * pixel_size + (run[3] - 1) * gap, pixel_height, color, math_floor(alpha * run[4]), z)
        index = index + 1
    end

    return index
end

function InvadersView:init(settings, context)
    InvadersView.super.init(self, definitions, settings, context)
    self._game = context.game
    self._no_cursor = true

    self._enemy_pixel_widgets = {}
    for i = 1, ENEMY_PIXELS do
        self._enemy_pixel_widgets[i] = UIWidget.init("inv_enemy_pixel_" .. i, rect_def())
    end

    self._shield_widgets = {}
    for i = 1, SHIELD_WIDGETS do
        self._shield_widgets[i] = UIWidget.init("inv_shield_" .. i, rect_def())
    end

    self._player_widgets = {}
    for i = 1, PLAYER_PIXELS do
        self._player_widgets[i] = UIWidget.init("inv_player_" .. i, rect_def())
    end

    self._mystery_widgets = {}
    for i = 1, MYSTERY_PIXELS do
        self._mystery_widgets[i] = UIWidget.init("inv_mystery_" .. i, rect_def())
    end

    self._bullet_widgets = {}
    for i = 1, BULLET_WIDGETS do
        self._bullet_widgets[i] = UIWidget.init("inv_bullet_" .. i, rect_def())
    end

    self._star_widgets = {}
    for i = 1, STAR_WIDGETS do
        local w = UIWidget.init("inv_star_" .. i, rect_def())
        w._x = 5 + (i * 137.51) % 590
        w._y = (i * 83.17) % 460
        w._layer = 1 + i % 3
        w._size = w._layer == 3 and 2 or 1
        w._phase = i * 2.399
        self._star_widgets[i] = w
    end

    self._grid_widgets = {}
    for i = 1, 18 do
        self._grid_widgets[i] = UIWidget.init("inv_grid_" .. i, rect_def())
    end
end

function InvadersView:dialogue_system() return nil end
function InvadersView:is_using_input() return false end

function InvadersView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    if self._game then
        local score_w = self._widgets_by_name.score_text
        if score_w then score_w.content.text = string.format("Score: %04d", self._game:score()) end

        local wave_w = self._widgets_by_name.wave_text
        if wave_w then wave_w.content.text = string.format("Wave: %d", self._game:wave()) end

        local lives_w = self._widgets_by_name.lives_text
        if lives_w then lives_w.content.text = string.format("Hull: %d", self._game:lives()) end

        local message_w = self._widgets_by_name.message_text
        if message_w then
            if self._game:is_game_over() then
                message_w.content.text = "GAME OVER"
                message_w.style.text.text_color = COLORS.warning
            else
                local text = self._game:level_text()
                message_w.content.text = text
                message_w.style.text.text_color = text ~= "" and COLORS.message or COLORS.hidden
            end
        end
    end

    local hsw = self._widgets_by_name.highscore_text
    if hsw then hsw.content.text = mod:localize("invaders_highscore") .. " " .. (mod:get("invaders_highscore") or 0) end

    local noise = self._widgets_by_name.scanner_noise
    if noise and self._game then
        noise.style.noise.color[1] = 70 + math_floor((math_sin(self._game:time() * 2.3) + 1) * 18) + math_floor(self._game:shake() * 70)
    end

    InvadersView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

    if not self._game then return end

    self:_draw_dynamic(ui_renderer)
end

function InvadersView:_draw_dynamic(ui_renderer)
    local ent = self._game:entities()
    local shake = self._game:shake()
    local time = self._game:time()
    local sx = math_sin(time * 71) * shake * 5
    local sy = math_sin(time * 93 + 1.2) * shake * 5

    self:_draw_grid(ui_renderer, sx, sy)
    self:_draw_stars(ui_renderer, sx, sy)
    self:_draw_shields(ui_renderer, ent.shields, sx, sy)
    self:_draw_enemies(ui_renderer, ent.enemies, sx, sy)
    self:_draw_mystery(ui_renderer, ent.mystery, sx, sy)
    self:_draw_bullets(ui_renderer, ent.player_bullets, ent.enemy_bullets, sx, sy)
    self:_draw_player(ui_renderer, ent.player, sx, sy)
end

function InvadersView:_draw_grid(ui_renderer, sx, sy)
    local idx = 1

    for y = 78, 558, 80 do
        local w = self._grid_widgets[idx]
        draw_rect(w, sx, y + sy, GAME_W, 1, COLORS.grid, 22, 1)
        UIWidget.draw(w, ui_renderer)
        idx = idx + 1
    end

    for x = 70, 530, 92 do
        local w = self._grid_widgets[idx]
        draw_rect(w, x + sx, sy, 1, GAME_H, COLORS.grid, 15, 1)
        UIWidget.draw(w, ui_renderer)
        idx = idx + 1
    end

    draw_rect(self._grid_widgets[idx], 22, 73, 556, 1, COLORS.grid_hot, 65, 3)
    UIWidget.draw(self._grid_widgets[idx], ui_renderer)
    idx = idx + 1

    for i = idx, #self._grid_widgets do
        clear_rect(self._grid_widgets[i])
    end
end

function InvadersView:_draw_stars(ui_renderer, sx, sy)
    local t = self._game:time()

    for i = 1, STAR_WIDGETS do
        local w = self._star_widgets[i]
        local pulse = (math_sin(t * 0.7 + w._phase) + 1) * 0.5
        local color = w._layer == 3 and COLORS.star_hot or COLORS.star
        local alpha = math_floor(22 + w._layer * 19 + pulse * 22)
        local x = w._x + sx * w._layer * 0.2
        local y = 76 + (w._y + t * w._layer * 1.5) % 460 + sy * w._layer * 0.2

        if w._layer == 3 then
            draw_rect(w, x - 2, y - 2, 6, 6, color, 12 + pulse * 8, 2)
            UIWidget.draw(w, ui_renderer)
        end
        draw_rect(w, x, y, w._size, w._size, color, alpha, 2)
        UIWidget.draw(w, ui_renderer)
    end
end

function InvadersView:_draw_enemies(ui_renderer, enemies, sx, sy)
    local index = 1

    for i = 1, ENEMY_WIDGETS do
        local enemy = enemies[i]

        if enemy and enemy.alive then
            local mask_type = enemy.row == 1 and 1 or enemy.row <= 3 and 2 or 3
            local mask = INVADER_MASKS[mask_type]
            local color = enemy.row == 1 and COLORS.invader_top or enemy.row <= 3 and COLORS.invader_mid or COLORS.invader_low
            local alpha = 235

            for band = 1, 2 do
                local glow = self._enemy_pixel_widgets[index]
                draw_rect(glow, enemy.x + 3 - band * 2 + sx, enemy.y + 5 - band + sy, 25 + band * 4, 13 + band * 2, color, 22 - band * 6, 7)
                index = index + 1
            end

            -- Fit the 8x7 mask and its gaps to SpaceInvadersGame's 30x22 hitbox.
            index = draw_mask(self._enemy_pixel_widgets, index, enemy.x + sx, enemy.y + sy, mask, (30 - 7) / 8, color, alpha, 8, 1, (22 - 6) / 7)

            if index <= ENEMY_PIXELS then
                local core = self._enemy_pixel_widgets[index]
                draw_rect(core, enemy.x + 12 + sx, enemy.y + 4 + sy, 7, 1, COLORS.invader_core, 200, 9)
                index = index + 1
            end
        end
    end

    for i = index, ENEMY_PIXELS do
        clear_rect(self._enemy_pixel_widgets[i])
    end

    for i = 1, index - 1 do
        UIWidget.draw(self._enemy_pixel_widgets[i], ui_renderer)
    end
end

function InvadersView:_draw_shields(ui_renderer, shields, sx, sy)
    local index = 1

    for i = 1, #shields do
        local block = shields[i]

        if block.alive and index + 1 <= SHIELD_WIDGETS then
            local w = self._shield_widgets[index]
            local light = (block.x * 3 + block.y * 7) % 5
            draw_rect(w, block.x + sx, block.y + sy, block.w - 0.5, block.h - 0.5, COLORS.shield, 155 + light * 16, 6)
            draw_rect(self._shield_widgets[index + 1], block.x + sx, block.y + sy, block.w - 1, 1, COLORS.shield_hot, 155 + light * 20, 7)
            index = index + 2
        end
    end

    for i = index, SHIELD_WIDGETS do
        clear_rect(self._shield_widgets[i])
    end

    for i = 1, index - 1 do
        UIWidget.draw(self._shield_widgets[i], ui_renderer)
    end
end

function InvadersView:_draw_player(ui_renderer, player, sx, sy)
    local index = 1

    if player then
        draw_rect(self._player_widgets[index], player.x - 3 + sx, player.y + 9 + sy, 45, 12, COLORS.player, 25, 10)
        index = index + 1
        index = draw_mask(self._player_widgets, index, player.x + sx, player.y + sy, PLAYER_MASK, 3, COLORS.player, 230, 11, 0)

        for side = 0, 1 do
            local x = player.x + 5 + side * 24 + sx
            draw_rect(self._player_widgets[index], x, player.y + 12 + sy, 5, 4, COLORS.armor, 240, 12)
            draw_rect(self._player_widgets[index + 1], x, player.y + 11 + sy, 5, 1, COLORS.player_core, 230, 13)
            draw_rect(self._player_widgets[index + 2], x + 1, player.y + 18 + sy, 3, 3 + math_sin(self._game:time() * 8) * 0.7, COLORS.player_core, 140, 10)
            index = index + 3
        end

        if index <= PLAYER_PIXELS then
            draw_rect(self._player_widgets[index], player.x + 17 + sx, player.y - 5 + sy, 4, 8, COLORS.player_core, 210, 12)
            index = index + 1
        end
    end

    for i = index, PLAYER_PIXELS do
        clear_rect(self._player_widgets[i])
    end

    for i = 1, index - 1 do
        UIWidget.draw(self._player_widgets[i], ui_renderer)
    end
end

function InvadersView:_draw_mystery(ui_renderer, mystery, sx, sy)
    local index = 1

    if mystery then
        draw_rect(self._mystery_widgets[index], mystery.x + 4 + sx, mystery.y + 6 + sy, 44, 16, COLORS.mystery, 30, 9)
        index = index + 1
        index = draw_mask(self._mystery_widgets, index, mystery.x + sx, mystery.y + sy, MYSTERY_MASK, 4, COLORS.mystery, 240, 10, 0)

        for light = 0, 4 do
            draw_rect(self._mystery_widgets[index], mystery.x + 9 + light * 8 + sx, mystery.y + 13 + sy, 3, 2, COLORS.mystery_hot, 140 + 80 * math_sin(self._game:time() * 3 - light), 12)
            index = index + 1
        end

        if index <= MYSTERY_PIXELS then
            draw_rect(self._mystery_widgets[index], mystery.x + 10 + sx, mystery.y + 6 + sy, 30, 4, COLORS.mystery_hot, 180, 11)
            index = index + 1
        end
    end

    for i = index, MYSTERY_PIXELS do
        clear_rect(self._mystery_widgets[i])
    end

    for i = 1, index - 1 do
        UIWidget.draw(self._mystery_widgets[i], ui_renderer)
    end
end

function InvadersView:_draw_bullets(ui_renderer, player_bullets, enemy_bullets, sx, sy)
    local index = 1

    local pb = player_bullets[1]
    if pb then
        draw_rect(self._bullet_widgets[index], pb.x + sx, pb.y + sy, pb.w, pb.h, COLORS.pbullet, 255, 13)
        index = index + 1

        if index <= BULLET_WIDGETS then
            draw_rect(self._bullet_widgets[index], pb.x - 2 + sx, pb.y - 1 + sy, pb.w + 4, pb.h + 4, COLORS.player, 65, 12)
            index = index + 1
        end
        draw_rect(self._bullet_widgets[index], pb.x + sx, pb.y + pb.h + sy, pb.w, 9, COLORS.player_core, 90, 12)
        index = index + 1
    end

    for i = 1, #enemy_bullets do
        if index + 2 > BULLET_WIDGETS then break end

        local b = enemy_bullets[i]
        local wobble = b.kind == 1 and math_floor(math_sin(self._game:time() * 18 + b.y) * 2) or b.kind == 2 and 1 or -1
        draw_rect(self._bullet_widgets[index], b.x + wobble + sx, b.y + sy, b.w, b.h, COLORS.ebullet, 245, 13)
        draw_rect(self._bullet_widgets[index + 1], b.x + wobble - 2 + sx, b.y - 2 + sy, b.w + 4, b.h + 4, COLORS.ebullet, 45, 12)
        draw_rect(self._bullet_widgets[index + 2], b.x + wobble + sx, b.y + b.h - 3 + sy, b.w, 2, COLORS.mystery_hot, 240, 14)
        index = index + 3
    end

    for i = index, BULLET_WIDGETS do
        clear_rect(self._bullet_widgets[i])
    end

    for i = 1, index - 1 do
        UIWidget.draw(self._bullet_widgets[i], ui_renderer)
    end
end

function InvadersView:destroy() InvadersView.super.destroy(self) end

return InvadersView
