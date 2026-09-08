local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")
local NoosphereBreachRenderer = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/NoosphereBreach_renderer")

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_sin = math.sin

local RENDER_SIZE = 600
local GAME_W = 600
local GAME_H = 480
local BAR_W = 142

local COLORS = {
    void = { 255, 1, 7, 9 },
    panel = { 228, 2, 15, 18 },
    text = { 255, 194, 250, 230 },
    text_dim = { 180, 57, 151, 137 },
    cyan = { 255, 32, 228, 200 },
    cyan_dim = { 150, 7, 74, 73 },
    dash = { 255, 65, 185, 255 },
    dash_dim = { 150, 14, 50, 82 },
    warning = { 255, 255, 65, 69 },
    corruption = { 255, 238, 38, 167 },
    gold = { 255, 255, 202, 79 },
    black = { 255, 0, 0, 0 },
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
        size = { GAME_W, GAME_H }, position = { 0, 6, 8 },
    },
    title_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 550, 24 }, position = { 0, -284, 42 },
    },
    score_area = {
        horizontal_alignment = "center", parent = "game_area", vertical_alignment = "top",
        size = { 180, 20 }, position = { -198, 10, 34 },
    },
    wave_area = {
        horizontal_alignment = "center", parent = "game_area", vertical_alignment = "top",
        size = { 190, 20 }, position = { 0, 10, 34 },
    },
    timer_area = {
        horizontal_alignment = "center", parent = "game_area", vertical_alignment = "top",
        size = { 180, 20 }, position = { 198, 10, 34 },
    },
    status_area = {
        horizontal_alignment = "center", parent = "game_area", vertical_alignment = "top",
        size = { 230, 18 }, position = { 0, 34, 34 },
    },
    message_area = {
        horizontal_alignment = "center", parent = "game_area", vertical_alignment = "center",
        size = { 500, 72 }, position = { 0, -4, 42 },
    },
    combo_area = {
        horizontal_alignment = "center", parent = "game_area", vertical_alignment = "bottom",
        size = { 360, 28 }, position = { 0, -22, 42 },
    },
    controls_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 580, 20 }, position = { 0, 264, 42 },
    },
    highscore_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 580, 20 }, position = { 0, 285, 42 },
    },
}

local function text_definition(parent, font_size, color)
    return UIWidget.create_definition({
        {
            pass_type = "text",
            style_id = "text",
            value = "",
            value_id = "text",
            style = {
                font_size = font_size,
                font_type = "machine_medium",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = color,
                offset = { 0, 0, 1 },
            },
        },
    }, parent)
end

local function bar_definition(x, y, color, z)
    return UIWidget.create_definition({
        {
            pass_type = "texture",
            style_id = "bar",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = color, offset = { x, y, z } },
        },
    }, "game_area", nil, { BAR_W, 6 })
end

local function mask_definition(x, y, width, height, color, z)
    return UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { color = color, offset = { x, y, z } },
        },
    }, "game_area", nil, { width, height })
end

local widget_definitions = {
    background = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.void },
        },
    }, "game_area", nil, { GAME_W, GAME_H }),
    scanner_noise = UIWidget.create_definition({
        {
            pass_type = "rotated_texture",
            style_id = "noise",
            value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
            style = { hdr = true, color = { 42, 25, 170, 145 }, angle = 0, pivot = {}, offset = { -300, -300, 3 } },
        },
    }, "center_pivot", nil, { RENDER_SIZE, RENDER_SIZE }),
    scanner_noise_hot = UIWidget.create_definition({
        {
            pass_type = "rotated_texture",
            style_id = "noise",
            value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
            style = { hdr = true, color = { 0, 220, 35, 135 }, angle = 0, pivot = {}, offset = { -300, -300, 4 } },
        },
    }, "center_pivot", nil, { RENDER_SIZE, RENDER_SIZE }),
    scanner_inquisition = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/scanner/scanner_decoration_inquisition",
            style = { hdr = true, color = { 65, 20, 205, 165 }, offset = { -22, -296, 52 } },
        },
    }, "center_pivot", nil, { 44, 44 }),
    scanner_left_mark = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/scanner/scanner_decoration_left_mark",
            style = { hdr = true, color = { 48, 20, 160, 135 }, offset = { -292, -58, 52 } },
        },
    }, "center_pivot", nil, { 42, 116 }),
    scanner_right_mark = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/scanner/scanner_decoration_right_mark",
            style = { hdr = true, color = { 48, 20, 160, 135 }, offset = { 250, -58, 52 } },
        },
    }, "center_pivot", nil, { 42, 116 }),
    hud_panel = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.panel, offset = { 0, 0, 31 } },
        },
    }, "game_area", nil, { GAME_W, 62 }),
    hud_rule = mask_definition(0, 60, GAME_W, 2, { 165, 24, 188, 167 }, 35),
    hud_lip = mask_definition(0, 62, GAME_W, 3, { 165, 0, 0, 0 }, 35),
    hud_header = mask_definition(12, 4, GAME_W - 24, 1, { 65, 110, 210, 182 }, 35),
    hud_divider_left = mask_definition(188, 12, 1, 35, { 65, 45, 128, 121 }, 35),
    hud_divider_right = mask_definition(411, 12, 1, 35, { 65, 45, 128, 121 }, 35),
    health_recess = mask_definition(18, 47, BAR_W + 4, 10, { 255, 0, 5, 9 }, 34),
    dash_recess = mask_definition(GAME_W - BAR_W - 22, 47, BAR_W + 4, 10, { 255, 0, 5, 9 }, 34),
    health_bg = bar_definition(20, 49, COLORS.cyan_dim, 35),
    health_bar = bar_definition(20, 49, COLORS.cyan, 36),
    dash_bg = bar_definition(GAME_W - BAR_W - 20, 49, COLORS.dash_dim, 35),
    dash_bar = bar_definition(GAME_W - BAR_W - 20, 49, COLORS.dash, 36),
    damage_flash = UIWidget.create_definition({
        {
            pass_type = "texture",
            style_id = "flash",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 0, 255, 18, 37 }, offset = { 0, 0, 29 } },
        },
    }, "game_area", nil, { GAME_W, GAME_H }),
    dash_flash = UIWidget.create_definition({
        {
            pass_type = "texture",
            style_id = "flash",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 0, 54, 185, 255 }, offset = { 0, 0, 28 } },
        },
    }, "game_area", nil, { GAME_W, GAME_H }),
    vignette_top = mask_definition(0, 0, GAME_W, 12, { 175, 0, 0, 0 }, 54),
    vignette_bottom = mask_definition(0, GAME_H - 16, GAME_W, 16, { 215, 0, 0, 0 }, 54),
    vignette_left = mask_definition(0, 0, 10, GAME_H, { 205, 0, 0, 0 }, 54),
    vignette_right = mask_definition(GAME_W - 10, 0, 10, GAME_H, { 205, 0, 0, 0 }, 54),
    edge_top = mask_definition(0, 0, GAME_W, 4, COLORS.black, 56),
    edge_bottom = mask_definition(0, GAME_H - 4, GAME_W, 4, COLORS.black, 56),
    edge_left = mask_definition(0, 0, 4, GAME_H, COLORS.black, 56),
    edge_right = mask_definition(GAME_W - 4, 0, 4, GAME_H, COLORS.black, 56),
    title_text = UIWidget.create_definition({
        {
            pass_type = "text",
            value = "NOOSPHERE BREACH // COMBAT PROTOCOL",
            style = {
                font_size = 17,
                font_type = "machine_medium",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = COLORS.text,
                offset = { 0, 0, 1 },
            },
        },
    }, "title_area", nil, { 550, 24 }),
    score_text = text_definition("score_area", 16, COLORS.text),
    wave_text = text_definition("wave_area", 15, COLORS.text_dim),
    timer_text = text_definition("timer_area", 16, COLORS.text),
    status_text = text_definition("status_area", 13, COLORS.text_dim),
    message_text = text_definition("message_area", 30, { 0, 0, 0, 0 }),
    combo_text = text_definition("combo_area", 21, { 0, 0, 0, 0 }),
    controls_text = UIWidget.create_definition({
        {
            pass_type = "text",
            value = mod:localize("noosphere_controls"),
            style = {
                font_size = 14,
                font_type = "machine_medium",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = COLORS.text_dim,
                offset = { 0, 0, 1 },
            },
        },
    }, "controls_area", nil, { 580, 20 }),
    highscore_text = text_definition("highscore_area", 14, COLORS.text),
}

for i = 1, 9 do
    local step = BAR_W * i / 10
    widget_definitions["health_segment_" .. i] = mask_definition(20 + step, 49, 1, 6, { 185, 0, 8, 12 }, 37)
    widget_definitions["dash_segment_" .. i] = mask_definition(GAME_W - BAR_W - 20 + step, 49, 1, 6, { 185, 0, 8, 12 }, 37)
end
widget_definitions.health_glint = bar_definition(20, 49, { 135, 195, 255, 230 }, 36.1)
widget_definitions.dash_glint = bar_definition(GAME_W - BAR_W - 20, 49, { 135, 190, 232, 255 }, 36.1)

AuspexFrame.add(widget_definitions, {
    render_size = RENDER_SIZE,
    outline_size = { 632, 620 },
    backdrop_alpha = 248,
    alpha = 170,
    z = 58,
})
AuspexFrame.add_inner_border(widget_definitions, {
    render_size = RENDER_SIZE,
    size = { GAME_W, GAME_H },
    center = { 0, 6 },
    prefix = "noosphere_game_border",
    color = { 170, 30, 215, 184 },
    z = 60,
})

local definitions = {
    scenegraph_definition = scenegraph,
    widget_definitions = widget_definitions,
}

local NoosphereBreachView = class("NoosphereBreachView", "BaseView")

local function set_color(destination, source, alpha)
    destination[1] = alpha or source[1]
    destination[2] = source[2]
    destination[3] = source[3]
    destination[4] = source[4]
end

local function normalized_charge(value)
    value = value or 0

    if value > 1 then value = value / 100 end

    return math_max(0, math_min(1, value))
end

local function player_is_dashing(player)
    return player and not not (
        player.dashing
        or player.dash_active
        or player.dash_time and player.dash_time > 0
    )
end

function NoosphereBreachView:init(settings, context)
    NoosphereBreachView.super.init(self, definitions, settings, context)

    self._game = context and context.game
    self._renderer = NoosphereBreachRenderer.new()
    self._no_cursor = true
    self._damage_flash = 0
    self._dash_flash = 0
    self._last_health = self._game and (self._game:health() or 0) or 0
    self._last_dash_charge = self._game and normalized_charge(self._game:dash_charge()) or 0
    self._last_dashing = self._game and player_is_dashing(self._game:player()) or false
end

function NoosphereBreachView:dialogue_system()
    return nil
end

function NoosphereBreachView:is_using_input()
    return false
end

function NoosphereBreachView:update(dt, t, input_service)
    dt = dt or 0.016

    local ui_manager = Managers.ui
    local has_focus = ui_manager and ui_manager:active_top_view() == "noosphere_breach_view"
    local game = self._game

    if game and has_focus then
        game:update(dt)

        local health = game:health() or 0
        local dash_charge = normalized_charge(game:dash_charge())
        local dashing = player_is_dashing(game:player())

        if health < self._last_health then
            self._damage_flash = 0.62
        end

        if dashing and not self._last_dashing or dash_charge < self._last_dash_charge - 0.16 then
            self._dash_flash = 0.34
        end

        self._last_health = health
        self._last_dash_charge = dash_charge
        self._last_dashing = dashing
    end

    self._damage_flash = math_max(0, self._damage_flash - dt * 1.9)
    self._dash_flash = math_max(0, self._dash_flash - dt * 2.8)

    return NoosphereBreachView.super.update(self, dt, t, input_service)
end

function NoosphereBreachView:_update_hud()
    local game = self._game
    if not game then return end

    local score = game:score() or 0
    local wave = game:wave() or 0
    local health = game:health() or 0
    local max_health = math_max(1, game:max_health() or 1)
    local dash_charge = normalized_charge(game:dash_charge())
    local time = game:time() or 0
    local state = game:state()
    local score_widget = self._widgets_by_name.score_text
    local wave_widget = self._widgets_by_name.wave_text
    local timer_widget = self._widgets_by_name.timer_text
    local status_widget = self._widgets_by_name.status_text
    local message_widget = self._widgets_by_name.message_text
    local combo_widget = self._widgets_by_name.combo_text
    local highscore_widget = self._widgets_by_name.highscore_text

    if score_widget then score_widget.content.text = string.format("SCORE %07d", score) end
    if wave_widget then wave_widget.content.text = string.format("WAVE %02d // THREAT", wave) end
    if timer_widget then timer_widget.content.text = string.format("SYNC %06.1f", time) end
    if status_widget then status_widget.content.text = string.format("INTEGRITY %d/%d  //  %s", health, max_health, state and tostring(state) or "STANDBY") end

    if message_widget then
        local message_time = game:message_time() or 0

        if game:is_game_over() then
            message_widget.content.text = game:message() or "NOOSPHERE LINK SEVERED"
            set_color(message_widget.style.text.text_color, COLORS.warning, 255)
        elseif message_time > 0 then
            message_widget.content.text = game:message() or ""
            set_color(message_widget.style.text.text_color, COLORS.text, math_min(255, 75 + message_time * 120))
        else
            message_widget.content.text = ""
            message_widget.style.text.text_color[1] = 0
        end
    end

    if combo_widget then
        local combo = game:combo() or 0
        local combo_time = game:combo_time() or 0
        local multiplier = game:multiplier() or 1

        if combo > 1 and combo_time > 0 then
            combo_widget.content.text = string.format("BREACH CHAIN %02d  //  x%.1f", combo, multiplier)
            set_color(combo_widget.style.text.text_color, multiplier >= 3 and COLORS.gold or COLORS.cyan, math_min(255, 70 + combo_time * 90))
        else
            combo_widget.content.text = ""
            combo_widget.style.text.text_color[1] = 0
        end
    end

    if highscore_widget then
        highscore_widget.content.text = string.format(
            "%s %d       PEAK x%.1f       DASH %03d%%",
            mod:localize("noosphere_highscore"),
            mod:get("noosphere_highscore") or 0,
            game:best_multiplier() or 1,
            math_floor(dash_charge * 100 + 0.5)
        )
    end

    local health_bar = self._widgets_by_name.health_bar
    local health_fraction = math_max(0, math_min(1, health / max_health))
    if health_bar then
        health_bar.content.size[1] = BAR_W * health_fraction
        set_color(health_bar.style.bar.color, health_fraction <= 0.25 and COLORS.warning or COLORS.cyan)
    end

    local dash_bar = self._widgets_by_name.dash_bar
    if dash_bar then dash_bar.content.size[1] = BAR_W * dash_charge end

    local health_glint = self._widgets_by_name.health_glint
    if health_glint then
        health_glint.content.size[1] = BAR_W * health_fraction
        health_glint.content.size[2] = 1
    end
    local dash_glint = self._widgets_by_name.dash_glint
    if dash_glint then
        dash_glint.content.size[1] = BAR_W * dash_charge
        dash_glint.content.size[2] = 1
    end

    local damage_flash = self._widgets_by_name.damage_flash
    if damage_flash then damage_flash.style.flash.color[1] = math_floor(self._damage_flash * 220) end

    local dash_flash = self._widgets_by_name.dash_flash
    if dash_flash then dash_flash.style.flash.color[1] = math_floor(self._dash_flash * 185) end

    local noise = self._widgets_by_name.scanner_noise
    if noise then noise.style.noise.angle = time * 0.018 end

    local hot_noise = self._widgets_by_name.scanner_noise_hot
    if hot_noise then
        hot_noise.style.noise.angle = -time * 0.013
        local pulse = (math_sin(time * 3.7) + 1) * 8
        local alpha = math_min(135, 18 + pulse + (game:shake() or 0) * 90 + self._dash_flash * 120)
        set_color(hot_noise.style.noise.color, self._damage_flash > self._dash_flash and COLORS.corruption or COLORS.dash, math_floor(alpha))
    end
end

function NoosphereBreachView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    self:_update_hud()
    NoosphereBreachView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

    if not self._game or not self._renderer then return end

    local game_area_position = self:_scenegraph_world_position("game_area")
    self._renderer:draw(ui_renderer, game_area_position[1], game_area_position[2], self._game)
end

function NoosphereBreachView:destroy()
    self._renderer = nil
    NoosphereBreachView.super.destroy(self)
end

return NoosphereBreachView
