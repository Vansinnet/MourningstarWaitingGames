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
local math_random = math.random
local math_sin = math.sin
local math_sqrt = math.sqrt

local RENDER_SIZE = 600
local VIEW_W = 600
local VIEW_H = 480
local HORIZON = 214
local COLUMN_COUNT = 200
local COLUMN_W = VIEW_W / COLUMN_COUNT
local FOV = 1.18
local PROJ_PLANE = (VIEW_W * 0.5) / math.tan(FOV * 0.5)

local COLORS = {
    void = { 255, 1, 3, 8 },
    panel = { 205, 2, 8, 13 },
    text = { 255, 205, 245, 238 },
    text_dim = { 185, 85, 155, 150 },
    warning = { 255, 255, 72, 65 },
    health = { 255, 235, 72, 62 },
    health_bg = { 180, 60, 16, 22 },
    fervor = { 255, 45, 230, 215 },
    fervor_bg = { 180, 8, 54, 60 },
    gold = { 255, 255, 194, 72 },
    gold_hot = { 255, 255, 245, 180 },
    corruption = { 255, 240, 35, 155 },
    corruption_hot = { 255, 255, 150, 225 },
    grace = { 255, 100, 255, 130 },
    white = { 255, 245, 255, 252 },
    black = { 255, 0, 0, 0 },
    armor = { 255, 39, 18, 37 },
    armor_edge = { 255, 136, 64, 110 },
}

local THEMES = {
    {
        ceiling = { 245, 3, 12, 20 },
        ceiling_hot = { 185, 9, 40, 47 },
        floor = { 250, 3, 15, 17 },
        floor_hot = { 185, 8, 57, 53 },
        grid = { 115, 30, 190, 170 },
        wall = { 255, 58, 112, 106 },
        wall_side = { 255, 26, 65, 68 },
        wall_detail = { 255, 110, 175, 150 },
        portal = { 255, 255, 202, 68 },
        locked = { 255, 145, 28, 70 },
        fog = { 165, 15, 58, 62 },
    },
    {
        ceiling = { 245, 7, 7, 26 },
        ceiling_hot = { 185, 42, 14, 70 },
        floor = { 250, 10, 5, 24 },
        floor_hot = { 185, 70, 14, 82 },
        grid = { 115, 180, 55, 235 },
        wall = { 255, 90, 48, 145 },
        wall_side = { 255, 45, 22, 85 },
        wall_detail = { 255, 175, 95, 210 },
        portal = { 255, 70, 225, 250 },
        locked = { 255, 210, 40, 110 },
        fog = { 165, 70, 20, 100 },
    },
    {
        ceiling = { 245, 3, 14, 11 },
        ceiling_hot = { 185, 20, 52, 28 },
        floor = { 250, 7, 16, 9 },
        floor_hot = { 185, 48, 52, 12 },
        grid = { 115, 170, 175, 45 },
        wall = { 255, 95, 102, 44 },
        wall_side = { 255, 48, 58, 28 },
        wall_detail = { 255, 195, 170, 65 },
        portal = { 255, 245, 120, 35 },
        locked = { 255, 135, 36, 30 },
        fog = { 165, 64, 66, 22 },
    },
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
        size = { VIEW_W, VIEW_H }, position = { 0, 6, 8 },
    },
    title_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 540, 22 }, position = { 0, -284, 35 },
    },
    score_area = {
        horizontal_alignment = "center", parent = "game_area", vertical_alignment = "center",
        size = { 180, 22 }, position = { -196, -220, 35 },
    },
    sector_area = {
        horizontal_alignment = "center", parent = "game_area", vertical_alignment = "center",
        size = { 220, 22 }, position = { 0, -220, 35 },
    },
    timer_area = {
        horizontal_alignment = "center", parent = "game_area", vertical_alignment = "center",
        size = { 180, 22 }, position = { 196, -220, 35 },
    },
    objective_area = {
        horizontal_alignment = "center", parent = "game_area", vertical_alignment = "center",
        size = { 400, 22 }, position = { 0, -193, 35 },
    },
    message_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 520, 76 }, position = { 0, -20, 38 },
    },
    combo_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 340, 30 }, position = { 0, 195, 36 },
    },
    controls_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 580, 22 }, position = { 0, 263, 35 },
    },
    highscore_area = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 580, 22 }, position = { 0, 284, 35 },
    },
}

local function text_def(parent, font_size, color)
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

local widget_definitions = {
    bg = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.void },
        },
    }, "game_area", nil, { VIEW_W, VIEW_H }),
    scanner_noise = UIWidget.create_definition({
        {
            pass_type = "rotated_texture",
            style_id = "noise",
            value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
            style = { hdr = true, color = { 45, 75, 180, 160 }, offset = { -300, -300, 29 }, angle = 0, pivot = {} },
        },
    }, "center_pivot", nil, { 600, 600 }),
    scanner_noise_hot = UIWidget.create_definition({
        {
            pass_type = "rotated_texture",
            style_id = "noise",
            value = "content/ui/materials/backgrounds/scanner/scanner_background_noise",
            style = { hdr = true, color = { 0, 230, 55, 130 }, offset = { -300, -300, 30 }, angle = 0, pivot = {} },
        },
    }, "center_pivot", nil, { 600, 600 }),
    top_panel = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.panel, offset = { 0, 0, 31 } },
        },
    }, "game_area", nil, { VIEW_W, 62 }),
    health_bar_bg = UIWidget.create_definition({
        {
            pass_type = "texture", style_id = "gfx",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.health_bg, offset = { 18, 47, 34 } },
        },
    }, "game_area", nil, { 145, 6 }),
    health_bar = UIWidget.create_definition({
        {
            pass_type = "texture", style_id = "gfx",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.health, offset = { 18, 47, 35 } },
        },
    }, "game_area", nil, { 145, 6 }),
    fervor_bar_bg = UIWidget.create_definition({
        {
            pass_type = "texture", style_id = "gfx",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.fervor_bg, offset = { 437, 47, 34 } },
        },
    }, "game_area", nil, { 145, 6 }),
    fervor_bar = UIWidget.create_definition({
        {
            pass_type = "texture", style_id = "gfx",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.fervor, offset = { 437, 47, 35 } },
        },
    }, "game_area", nil, { 145, 6 }),
    vignette_top = UIWidget.create_definition({
        {
            pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 150, 0, 0, 0 }, offset = { 0, 0, 27 } },
        },
    }, "game_area", nil, { VIEW_W, 10 }),
    vignette_bottom = UIWidget.create_definition({
        {
            pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 205, 0, 0, 0 }, offset = { 0, VIEW_H - 16, 27 } },
        },
    }, "game_area", nil, { VIEW_W, 16 }),
    vignette_left = UIWidget.create_definition({
        {
            pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 140, 0, 0, 0 }, offset = { 0, 0, 27 } },
        },
    }, "game_area", nil, { 9, VIEW_H }),
    vignette_right = UIWidget.create_definition({
        {
            pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 140, 0, 0, 0 }, offset = { VIEW_W - 9, 0, 27 } },
        },
    }, "game_area", nil, { 9, VIEW_H }),
    damage_flash = UIWidget.create_definition({
        {
            pass_type = "texture", style_id = "gfx",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 0, 255, 10, 45 }, offset = { 0, 0, 26 } },
        },
    }, "game_area", nil, { VIEW_W, VIEW_H }),
    dash_flash = UIWidget.create_definition({
        {
            pass_type = "texture", style_id = "gfx",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 0, 40, 255, 225 }, offset = { 0, 0, 25 } },
        },
    }, "game_area", nil, { VIEW_W, VIEW_H }),
    reticle_outer = UIWidget.create_definition({
        {
            pass_type = "circle", style_id = "gfx",
            style = { color = { 85, 105, 245, 225 }, offset = { VIEW_W * 0.5 - 12, HORIZON - 12, 31 } },
        },
    }, "game_area", nil, { 24, 24 }),
    reticle_dot = UIWidget.create_definition({
        {
            pass_type = "circle", style_id = "gfx",
            style = { color = { 220, 215, 255, 245 }, offset = { VIEW_W * 0.5 - 2, HORIZON - 2, 32 } },
        },
    }, "game_area", nil, { 4, 4 }),
    title_text = UIWidget.create_definition({
        {
            pass_type = "text", style_id = "text", value = "PENITENT PURGE // RELIQUARY RUN",
            style = {
                font_size = 17, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.text, offset = { 0, 0, 1 },
            },
        },
    }, "title_area", nil, { 540, 22 }),
    score_text = text_def("score_area", 16, COLORS.text),
    sector_text = text_def("sector_area", 15, COLORS.text_dim),
    timer_text = text_def("timer_area", 16, COLORS.text),
    objective_text = text_def("objective_area", 15, COLORS.gold),
    message_text = text_def("message_area", 29, { 0, 0, 0, 0 }),
    combo_text = text_def("combo_area", 22, { 0, 0, 0, 0 }),
    controls_text = UIWidget.create_definition({
        {
            pass_type = "text", style_id = "text", value = mod:localize("raycaster_controls"),
            style = {
                font_size = 14, font_type = "machine_medium",
                text_horizontal_alignment = "center", text_vertical_alignment = "center",
                text_color = COLORS.text_dim, offset = { 0, 0, 1 },
            },
        },
    }, "controls_area", nil, { 580, 22 }),
    highscore_text = text_def("highscore_area", 14, COLORS.text),
}

AuspexFrame.add(widget_definitions, {
    render_size = RENDER_SIZE,
    outline_size = { 632, 620 },
    backdrop_alpha = 248,
    alpha = 170,
})
AuspexFrame.add_inner_border(widget_definitions, {
    render_size = RENDER_SIZE,
    size = { VIEW_W, VIEW_H },
    center = { 0, 6 },
    prefix = "raycaster_game_border",
    color = { 145, 40, 215, 190 },
})

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }
local RaycasterView = class("RaycasterView", "BaseView")

local function set_color(destination, source, alpha)
    destination[1] = alpha or source[1]
    destination[2] = source[2]
    destination[3] = source[3]
    destination[4] = source[4]
end


function RaycasterView:dialogue_system() return nil end
function RaycasterView:is_using_input() return false end

function RaycasterView:update(dt, t, input_service)
    local ui = Managers.ui
    local has_focus = ui and ui:active_top_view() == "raycaster_view"

    if self._game and has_focus then
        self._game:update(dt)

        if self._game:health() < self._last_health then
            self._damage_flash = 0.55
        end

        local dashing = self._game:dash_active()
        if dashing and not self._last_dash then
            self._dash_flash = 0.22
        end

        self._last_dash = dashing
        self._last_health = self._game:health()
    end

    dt = dt or 0.016
    self._damage_flash = math_max(0, self._damage_flash - dt * 1.8)
    self._dash_flash = math_max(0, self._dash_flash - dt * 2.8)

    return RaycasterView.super.update(self, dt, t, input_service)
end

function RaycasterView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    if self._game then
        self:_update_hud()
    end

    RaycasterView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

    if self._game then
        self:_draw_dynamic(ui_renderer, dt)
    end
end

function RaycasterView:_update_hud()
    local game = self._game
    local theme = THEMES[game:theme()] or THEMES[1]
    local score_widget = self._widgets_by_name.score_text
    local sector_widget = self._widgets_by_name.sector_text
    local timer_widget = self._widgets_by_name.timer_text
    local objective_widget = self._widgets_by_name.objective_text
    local message_widget = self._widgets_by_name.message_text
    local combo_widget = self._widgets_by_name.combo_text
    local highscore_widget = self._widgets_by_name.highscore_text

    if score_widget then
        score_widget.content.text = string.format("SCORE %06d", game:score())
    end

    if sector_widget then
        sector_widget.content.text = string.format("SECTOR %02d  //  SIGILS %d/%d", game:level(), game:sigils(), game:sigils_required())
    end

    if timer_widget then
        timer_widget.content.text = string.format("PURGE %05.1f", game:time_left())
        timer_widget.style.text.text_color = game:time_left() <= 15 and COLORS.warning or COLORS.text
    end

    if objective_widget then
        local objective = game:objective()

        if objective then
            local direction = math_abs(objective.angle) < 0.12 and "[  ^  ]"
                or objective.angle < 0 and "<<"
                or ">>"
            objective_widget.content.text = string.format("%s  %s  //  %02.0fm", direction, objective.kind, objective.distance)
            objective_widget.style.text.text_color = objective.kind == "VAULT" and theme.portal or COLORS.gold
        else
            objective_widget.content.text = ""
        end
    end

    if message_widget then
        if game:is_game_over() then
            message_widget.content.text = game:message()
            message_widget.style.text.text_color = COLORS.warning
        elseif game:message_time() > 0 then
            local alpha = math_min(255, 90 + game:message_time() * 120)
            message_widget.content.text = game:message()
            set_color(message_widget.style.text.text_color, COLORS.text, alpha)
        else
            message_widget.content.text = ""
            message_widget.style.text.text_color[1] = 0
        end
    end

    if combo_widget then
        if game:combo() > 1 then
            local alpha = math_min(255, 65 + game:combo_time() * 75)
            combo_widget.content.text = string.format("RESONANCE %02d  //  x%d", game:combo(), game:multiplier())
            set_color(combo_widget.style.text.text_color, game:multiplier() >= 4 and COLORS.gold_hot or COLORS.fervor, alpha)
        else
            combo_widget.content.text = ""
            combo_widget.style.text.text_color[1] = 0
        end
    end

    if highscore_widget then
        highscore_widget.content.text = string.format(
            "INTEGRITY %03d       FERVOR %03d       %s %d",
            game:health(),
            game:ammo(),
            mod:localize("raycaster_highscore"),
            mod:get("raycaster_highscore") or 0
        )
    end

    local health_bar = self._widgets_by_name.health_bar
    if health_bar then health_bar.content.size[1] = 145 * math_max(0, game:health()) / 100 end

    local fervor_bar = self._widgets_by_name.fervor_bar
    if fervor_bar then fervor_bar.content.size[1] = 145 * math_max(0, game:fervor()) / 100 end

    local noise = self._widgets_by_name.scanner_noise
    if noise then
        noise.style.noise.angle = game:time() * 0.025
        set_color(noise.style.noise.color, theme.grid, 34)
    end

    local hot_noise = self._widgets_by_name.scanner_noise_hot
    if hot_noise then
        local alpha = math_floor(game:shake() * 105 + self._dash_flash * 280)
        set_color(hot_noise.style.noise.color, game:dash_active() and COLORS.fervor or COLORS.corruption, alpha)
    end

    local damage_flash = self._widgets_by_name.damage_flash
    if damage_flash then damage_flash.style.gfx.color[1] = math_floor(self._damage_flash * 225) end

    local dash_flash = self._widgets_by_name.dash_flash
    if dash_flash then dash_flash.style.gfx.color[1] = math_floor(self._dash_flash * 190) end

    local reticle = self._widgets_by_name.reticle_outer
    if reticle then
        set_color(reticle.style.gfx.color, game:dash_active() and COLORS.gold_hot or theme.grid, game:dash_active() and 180 or 75)
    end
end


local TAN_HALF_FOV = math.tan(FOV * 0.5)
local FLOOR_BANDS = 34
local MAX_PLANE_DISTANCE = 13
local BRICK_COURSES = 6

local RC = {
    mortar = { 255, 0, 0, 0 },
    torch = { 255, 255, 170, 70 },
    torch_hot = { 255, 255, 240, 190 },
    ember = { 255, 255, 120, 40 },
    lead = { 255, 8, 6, 10 },
    shadow = { 255, 0, 0, 0 },
    robe = { 255, 34, 16, 32 },
    robe_light = { 255, 86, 40, 78 },
    eye = { 255, 255, 60, 40 },
    bone = { 255, 205, 196, 170 },
    steel = { 255, 72, 82, 90 },
    steel_light = { 255, 150, 165, 172 },
}

local plane_breaks = {}
local sprite_queue = {}
local glass_color = { 255, 0, 0, 0 }
local torch_lookup = {}

local function hash(a, b, c)
    local v = math_sin(a * 127.1 + b * 311.7 + (c or 0) * 74.7) * 43758.5453
    return v - math_floor(v)
end

local function mix_channel(a, b, t)
    return a + (b - a) * t
end

function RaycasterView:init(settings, context)
    RaycasterView.super.init(self, definitions, settings, context)

    self._game = context.game
    self._no_cursor = true
    self._last_health = self._game and self._game:health() or 100
    self._last_dash = false
    self._damage_flash = 0
    self._dash_flash = 0
    self._zbuffer = {}
    self._canvas = Gfx.Canvas.new(VIEW_W, VIEW_H, 9000)
    self._particles = Gfx.Particles.new(200)
    self._torches = {}
    self._time = 0
    self._last_sigils = nil
    self._last_score = nil
    self._pickup_flash = 0
    self._pickup_color = COLORS.gold

    -- The reworked renderer draws its own vignette.
    for _, name in ipairs({ "vignette_top", "vignette_bottom", "vignette_left", "vignette_right" }) do
        local widget = self._widgets_by_name[name]
        if widget then
            for _, pass_style in pairs(widget.style) do
                if pass_style.color then pass_style.color[1] = 0 end
            end
        end
    end
end

function RaycasterView:_project(x, y, horizon, sx)
    local player = self._game:player()
    local cosine = math_cos(player.angle)
    local sine = math_sin(player.angle)
    local dx = x - player.x
    local dy = y - player.y
    local forward = dx * cosine + dy * sine

    if forward <= 0.12 then return nil end

    local side = -dx * sine + dy * cosine
    local screen_x = VIEW_W * 0.5 + side / forward * PROJ_PLANE + sx
    local floor_y = horizon + PROJ_PLANE * 0.5 / forward

    return screen_x, floor_y, forward
end

function RaycasterView:_detect_events(horizon, sx)
    local game = self._game
    local sigils = game:sigils()
    local score = game:score()

    if self._last_sigils and sigils > self._last_sigils then
        self._pickup_flash = 1
        self._pickup_color = COLORS.gold
        self._particles:burst(VIEW_W * 0.5, horizon + 60, 30, 80, 320, 0.4, 1, 2, COLORS.gold_hot, "spark", 2, 120)
        self._particles:shockwave(VIEW_W * 0.5, horizon + 40, 220, 0.6, COLORS.gold, 4)
    elseif self._last_score and score > self._last_score + 40 then
        self._pickup_flash = math_max(self._pickup_flash, 0.5)
        self._pickup_color = COLORS.corruption_hot
    end

    self._last_sigils = sigils
    self._last_score = score
end

function RaycasterView:_draw_dynamic(ui_renderer, dt)
    local game = self._game
    local canvas = self._canvas
    dt = math_min(dt or 0.016, 0.05)
    self._time = self._time + dt

    local time = game:time()
    local shake = game:shake()
    local dash = game:dash_active() and 1 or 0
    local sx = math_sin(time * 73) * shake * 7
    local sy = math_cos(time * 59) * shake * 5
    local bob = math_sin(time * (dash > 0 and 11 or 6.5)) * (1.2 + dash * 2.5)
    local horizon = HORIZON + sy + bob
    local theme = THEMES[game:theme()] or THEMES[1]
    local entities = game:render_entities()

    self:_detect_events(horizon, sx)
    self._particles:update(dt)
    self._pickup_flash = math_max(0, self._pickup_flash - dt * 1.6)

    if not canvas:begin(ui_renderer, self:_scenegraph_world_position("game_area")) then return end

    self._flicker = 0.9 + math_sin(self._time * 13) * 0.04 + math_sin(self._time * 29.3) * 0.03

    self:_draw_sky(canvas, theme, horizon, sx)
    self:_draw_plane(canvas, theme, horizon, true)
    self:_draw_plane(canvas, theme, horizon, false)
    self:_draw_walls(canvas, theme, horizon, sx, entities.map)
    self:_draw_torches(canvas, theme)
    self:_draw_entities(canvas, entities, theme, horizon, sx)
    self:_draw_effects(canvas, entities.effects, horizon, sx)
    self:_draw_motes(canvas, theme, horizon, sx)
    self._particles:draw(canvas, 21.5)
    self:_draw_speed_lines(canvas, theme, horizon)
    self:_draw_gauntlets(canvas, theme)
    self:_draw_post(canvas, theme, horizon)

    canvas:finish()
end

function RaycasterView:_draw_sky(canvas, theme, horizon, sx)
    canvas:vgradient(0, 0, VIEW_W, math_max(1, horizon), 0.5, theme.ceiling, theme.fog, 255, 255, 20)
    canvas:vgradient(0, horizon, VIEW_W, VIEW_H - horizon, 0.5, theme.fog, theme.floor, 255, 255, 20)

    -- Distant nave: layered gothic arches receding into fog.
    local player = self._game:player()
    local spacing = 150
    local scroll = (player.angle / (math_pi * 2) * VIEW_W * 2.4) % spacing

    for arch = 0, 5 do
        local x = arch * spacing - scroll + sx * 0.15 - spacing * 0.5
        local spring = horizon - 70
        local apex = horizon - 175
        local w = spacing
        canvas:line(x, horizon, x, spring, 10, 0.7, theme.wall_side, 120)
        canvas:line(x, spring, x + w * 0.22, spring - 55, 6, 0.7, theme.wall_side, 110)
        canvas:line(x + w * 0.22, spring - 55, x + w * 0.5, apex, 5, 0.7, theme.wall_side, 110)
        canvas:line(x + w * 0.5, apex, x + w * 0.78, spring - 55, 5, 0.7, theme.wall_side, 110)
        canvas:line(x + w * 0.78, spring - 55, x + w, spring, 6, 0.7, theme.wall_side, 110)

        -- Rose window glowing through the fog.
        local rx, ry = x + w * 0.5, spring - 42
        canvas:glow(rx, ry, 30, 0.72, theme.portal, 28, 3)
        canvas:ring(rx, ry, 15, 2, 0.74, theme.wall_detail, 80, 16)
        for k = 0, 5 do
            local a = k / 6 * math_pi * 2 + self._time * 0.1
            canvas:line(rx, ry, rx + math_cos(a) * 14, ry + math_sin(a) * 14, 1, 0.75, theme.wall_detail, 60)
        end
    end
end

-- Perspective-correct checkerboard floor (or vaulted ceiling) cast in horizontal bands.
function RaycasterView:_draw_plane(canvas, theme, horizon, is_floor)
    local player = self._game:player()
    local dir_x, dir_y = math_cos(player.angle), math_sin(player.angle)
    local plane_x, plane_y = -dir_y * TAN_HALF_FOV, dir_x * TAN_HALF_FOV
    local extent = is_floor and (VIEW_H - horizon) or horizon
    local base = is_floor and theme.floor or theme.ceiling
    local hot = is_floor and theme.floor_hot or theme.ceiling_hot
    local fog = theme.fog
    local flicker = self._flicker

    if extent <= 2 then return end

    for band = 1, FLOOR_BANDS do
        local k0 = ((band - 1) / FLOOR_BANDS) ^ 2
        local k1 = (band / FLOOR_BANDS) ^ 2
        local d0 = extent * k0
        local d1 = extent * k1
        local mid = (d0 + d1) * 0.5

        if mid > 0.5 then
            local row_distance = PROJ_PLANE * 0.5 / mid

            if row_distance < MAX_PLANE_DISTANCE then
                local lx = player.x + row_distance * (dir_x - plane_x)
                local ly = player.y + row_distance * (dir_y - plane_y)
                local rx = player.x + row_distance * (dir_x + plane_x)
                local ry = player.y + row_distance * (dir_y + plane_y)
                local ddx, ddy = rx - lx, ry - ly
                local count = 0

                plane_breaks[1] = 0
                count = 1

                if math_abs(ddx) > 1e-6 then
                    local first = math_floor(math_min(lx, rx)) + 1
                    local last = math_floor(math_max(lx, rx))
                    for gx = first, math_min(last, first + 30) do
                        count = count + 1
                        plane_breaks[count] = (gx - lx) / ddx
                    end
                end
                if math_abs(ddy) > 1e-6 then
                    local first = math_floor(math_min(ly, ry)) + 1
                    local last = math_floor(math_max(ly, ry))
                    for gy = first, math_min(last, first + 30) do
                        count = count + 1
                        plane_breaks[count] = (gy - ly) / ddy
                    end
                end
                count = count + 1
                plane_breaks[count] = 1

                for i = 2, count do
                    local v = plane_breaks[i]
                    local j = i - 1
                    while j >= 1 and plane_breaks[j] > v do
                        plane_breaks[j + 1] = plane_breaks[j]
                        j = j - 1
                    end
                    plane_breaks[j + 1] = v
                end

                local fog_t = math_min(1, row_distance / MAX_PLANE_DISTANCE)
                fog_t = fog_t * fog_t
                local lantern = (1 / (1 + row_distance * 0.3)) * flicker
                local y_top = is_floor and horizon + d0 or horizon - d1
                local height = d1 - d0 + 0.6

                for i = 1, count - 1 do
                    local t0, t1 = plane_breaks[i], plane_breaks[i + 1]
                    if t1 - t0 > 1e-4 then
                        local tm = (t0 + t1) * 0.5
                        local wx = lx + ddx * tm
                        local wy = ly + ddy * tm
                        local tx, ty = math_floor(wx), math_floor(wy)
                        local parity = (tx + ty) % 2
                        local variation = hash(tx, ty, is_floor and 1 or 2)
                        local shade = (parity == 0 and 0.75 or 1) * (0.85 + variation * 0.3)
                        local light = is_floor and (0.35 + lantern * 1.1) or (0.25 + lantern * 0.55)
                        local r = mix_channel(mix_channel(base[2], hot[2], 0.5) * shade * light, fog[2], fog_t)
                        local g = mix_channel(mix_channel(base[3], hot[3], 0.5) * shade * light, fog[3], fog_t)
                        local b = mix_channel(mix_channel(base[4], hot[4], 0.5) * shade * light, fog[4], fog_t)
                        canvas:rect_raw(t0 * VIEW_W, y_top, (t1 - t0) * VIEW_W + 0.5, height, 1, 255, r, g, b)
                    end
                end

                -- Mortar seams: thin dark lines at every tile crossing.
                if is_floor and row_distance < 7 then
                    local seam_alpha = 120 * (1 - row_distance / 7)
                    for i = 2, count - 1 do
                        canvas:rect_raw(plane_breaks[i] * VIEW_W - 0.5, y_top, 1, height, 1.05, seam_alpha, 0, 0, 0)
                    end
                end
            end
        end
    end

    -- Lantern pool of light on the floor and wet reflection sheen.
    if is_floor then
        canvas:ellipse(VIEW_W * 0.5, VIEW_H + 20, 260, 120, 1.1, theme.floor_hot, 45 * self._flicker, 1, 0.1, 24)
        canvas:vgradient(0, horizon, VIEW_W, 26, 1.12, fog, fog, 160, 0, 8)
    else
        canvas:vgradient(0, horizon - 26, VIEW_W, 26, 1.12, fog, fog, 0, 160, 8)
    end
end

function RaycasterView:_draw_walls(canvas, theme, horizon, sx, map)
    local game = self._game
    local columns = game:cast_columns(COLUMN_COUNT, FOV)
    local portal_open = game:portal_open()
    local time = game:time()
    local fog = theme.fog
    local flicker = self._flicker
    local torches = self._torches

    for i = #torches, 1, -1 do torches[i] = nil end
    for key in pairs(torch_lookup) do torch_lookup[key] = nil end

    for i = 1, COLUMN_COUNT do
        local column = columns[i]
        local distance = math_max(0.07, column.corrected_distance or column.distance)
        local height = math_min(VIEW_H * 3, PROJ_PLANE / distance)
        local x = (i - 1) * COLUMN_W + sx
        local top = horizon - height * 0.5
        local u = column.wall_x or 0
        local fog_t = math_min(1, distance / 14)
        fog_t = fog_t * fog_t
        local light = (1 / (1 + distance * 0.2)) * (column.side == "y" and 0.72 or 1) * flicker

        self._zbuffer[i] = distance

        if column.tile == "X" then
            local color = portal_open and theme.portal or theme.locked
            canvas:rect(x, top, COLUMN_W + 0.6, height, 8, color, 255, 0.35)
            for band = 0, 5 do
                local v = (band / 6 + time * (portal_open and 0.35 or 0.08) + u * 0.3) % 1
                local wave = (math_sin(u * 18 + time * 4 + band) + 1) * 0.5
                canvas:rect(x, top + v * height, COLUMN_W + 0.6, height * 0.08, 8.1, color, 120 + wave * 120, 1, wave * 0.4)
            end
            local core = math_max(0, 1 - math_abs(u - 0.5) * 3)
            canvas:rect(x, top + height * 0.08, COLUMN_W + 0.6, height * 0.84, 8.2, COLORS.white, core * (60 + math_sin(time * 9) * 30))
            canvas:rect(x, top + height * 0.9, COLUMN_W + 0.6, height * 0.05, 8.25, COLORS.gold_hot, 180)
        else
            local mx, my = column.map_x or 0, column.map_y or 0
            local tile_hash = hash(mx, my, 3)
            local base = column.side == "y" and theme.wall_side or theme.wall
            local mortar_r = mix_channel(base[2] * 0.25 * light, fog[2], fog_t)
            local mortar_g = mix_channel(base[3] * 0.25 * light, fog[3], fog_t)
            local mortar_b = mix_channel(base[4] * 0.25 * light, fog[4], fog_t)

            canvas:rect_raw(x, top, COLUMN_W + 0.6, height, 8, 255, mortar_r, mortar_g, mortar_b)

            local is_window = tile_hash < 0.22 and height > 30
            local is_torch = not is_window and tile_hash > 0.8

            if height > 18 then
                local course_h = height / BRICK_COURSES
                local mortar = math_max(0.6, course_h * 0.07)
                for course = 0, BRICK_COURSES - 1 do
                    local brick_u = u * 2 + (course % 2) * 0.5
                    local brick_index = math_floor(brick_u)
                    local within = brick_u - brick_index
                    if within > 0.035 and within < 0.965 then
                        local variation = 0.78 + hash(mx * 3 + brick_index, my * 5 + course, 7) * 0.34
                        local edge = within < 0.12 and 1.18 or within > 0.9 and 0.82 or 1
                        local course_light = light * variation * edge
                        if course == 0 then course_light = course_light * 0.75 end
                        if course == BRICK_COURSES - 1 then course_light = course_light * 0.6 end
                        canvas:rect_raw(x, top + course * course_h + mortar, COLUMN_W + 0.6, course_h - mortar * 2, 8.05, 255,
                            mix_channel(base[2] * course_light, fog[2], fog_t),
                            mix_channel(base[3] * course_light, fog[3], fog_t),
                            mix_channel(base[4] * course_light, fog[4], fog_t))
                    end
                end

                -- Carved cornice and plinth.
                local detail = theme.wall_detail
                local dl = light * (1 - fog_t)
                canvas:rect_raw(x, top + height * 0.04, COLUMN_W + 0.6, math_max(1, height * 0.03), 8.1, 255 * (1 - fog_t * 0.8), detail[2] * dl, detail[3] * dl, detail[4] * dl)
                canvas:rect_raw(x, top + height * 0.86, COLUMN_W + 0.6, math_max(1, height * 0.025), 8.1, 200 * (1 - fog_t * 0.8), detail[2] * dl, detail[3] * dl, detail[4] * dl)
            end

            if is_window then
                local d = math_abs(u - 0.5)
                if d < 0.2 then
                    local v_top = 0.16 + 0.2 * (d / 0.2) ^ 1.6
                    local v_bottom = 0.64
                    canvas:rect_raw(x, top + height * (v_top - 0.02), COLUMN_W + 0.6, height * (v_bottom - v_top + 0.04), 8.15, 255, 10, 8, 12)
                    if d > 0.012 and math_abs(d - 0.1) > 0.01 then
                        local panes = 6
                        for p = 0, panes - 1 do
                            local v0 = v_top + (v_bottom - v_top) * p / panes
                            local v1 = v_top + (v_bottom - v_top) * (p + 1) / panes
                            local hue = hash(math_floor(u * 10), p, mx + my) * 0.9 + time * 0.01
                            Gfx.Canvas.hsv(glass_color, hue, 0.75, 0.9, 255)
                            local shimmer = 0.75 + 0.25 * math_sin(time * 1.5 + p + u * 8)
                            local glow = (1 - fog_t * 0.6) * shimmer
                            canvas:rect_raw(x, top + height * v0 + 0.8, COLUMN_W + 0.6, height * (v1 - v0) - 1.6, 8.2, 255,
                                glass_color[2] * glow, glass_color[3] * glow, glass_color[4] * glow)
                        end
                    end
                end
                -- Light spilling from the window onto the wall base.
                local spill = math_max(0, 1 - d * 3)
                canvas:rect(x, top + height * 0.66, COLUMN_W + 0.6, height * 0.3, 8.22, theme.portal, 40 * spill * (1 - fog_t))
            end

            if is_torch then
                local d = math_abs(u - 0.5)
                local warm = math_max(0, 1 - d / 0.5)
                canvas:rect(x, top, COLUMN_W + 0.6, height, 8.22, RC.torch, 70 * warm * warm * flicker * (1 - fog_t))
                if d < 0.035 then
                    canvas:rect(x, top + height * 0.36, COLUMN_W + 0.6, height * 0.12, 8.25, RC.steel, 255, light)
                    local key = mx * 1000 + my + (column.side == "y" and 0.5 or 0)
                    local existing = torch_lookup[key]
                    if not existing or d < existing.d then
                        if not existing then
                            existing = {}
                            torch_lookup[key] = existing
                            torches[#torches + 1] = existing
                        end
                        existing.d, existing.x, existing.y, existing.size, existing.distance, existing.fog = d, x + COLUMN_W * 0.5, top + height * 0.33, height * 0.07, distance, fog_t
                    end
                end
            end

            -- Ambient occlusion where wall meets floor and vault.
            canvas:rect(x, top + height * 0.9, COLUMN_W + 0.6, height * 0.1, 8.3, COLORS.black, 110 * (1 - fog_t))
            canvas:rect(x, top, COLUMN_W + 0.6, height * 0.04, 8.3, COLORS.black, 90 * (1 - fog_t))
        end
    end
end

function RaycasterView:_draw_torches(canvas, theme)
    local t = self._time
    local torches = self._torches

    for i = 1, #torches do
        local torch = torches[i]
        local s = math_min(40, math_max(2, torch.size))
        local fade = 1 - torch.fog * 0.7
        local f = 1 + math_sin(t * 17 + i) * 0.12 + math_sin(t * 31 + i * 2) * 0.08
        canvas:glow(torch.x, torch.y, s * 5 * f, 9, RC.torch, 90 * fade, 5)
        canvas:tri(torch.x - s * 0.6, torch.y, torch.x + s * 0.6, torch.y, torch.x + math_sin(t * 9 + i) * s * 0.2, torch.y - s * 2.2 * f, 9.1, RC.torch, 230 * fade)
        canvas:tri(torch.x - s * 0.3, torch.y, torch.x + s * 0.3, torch.y, torch.x, torch.y - s * 1.3 * f, 9.12, RC.torch_hot, 255 * fade)

        if math_random() < 0.05 then
            self._particles:emit(torch.x, torch.y - s * 2, (math_random() - 0.5) * 12, -20 - math_random() * 25, 0.8, 1.6, RC.ember, "ember", 0.5, -5)
        end
    end
end

function RaycasterView:_sprite_span(screen_x, half_width, forward)
    local left = screen_x
    local right = screen_x
    local center = math_floor(math_min(COLUMN_COUNT, math_max(1, screen_x / COLUMN_W + 1)))

    if forward >= (self._zbuffer[center] or 999) + 0.12 then return nil end

    local c = center
    while c > 1 and (self._zbuffer[c - 1] or 999) + 0.12 > forward and (c - 1) * COLUMN_W > screen_x - half_width do
        c = c - 1
    end
    left = (c - 1) * COLUMN_W
    c = center
    while c < COLUMN_COUNT and (self._zbuffer[c + 1] or 999) + 0.12 > forward and c * COLUMN_W < screen_x + half_width do
        c = c + 1
    end
    right = c * COLUMN_W

    return left, right
end

function RaycasterView:_draw_entities(canvas, entities, theme, horizon, sx)
    local count = 0

    local function queue(entity, kind)
        local screen_x, floor_y, forward = self:_project(entity.x, entity.y, horizon, sx)
        if not screen_x or screen_x < -200 or screen_x > VIEW_W + 200 then return end
        count = count + 1
        local entry = sprite_queue[count]
        if not entry then
            entry = {}
            sprite_queue[count] = entry
        end
        entry.entity, entry.kind, entry.screen_x, entry.floor_y, entry.forward = entity, kind, screen_x, floor_y, forward
    end

    for i = 1, #entities.pickups do
        local pickup = entities.pickups[i]
        if not pickup.taken then queue(pickup, pickup.kind) end
    end
    for i = 1, #entities.enemies do
        local enemy = entities.enemies[i]
        if enemy.alive then queue(enemy, "enemy") end
    end

    for i = 2, count do
        local entry = sprite_queue[i]
        local j = i - 1
        while j >= 1 and sprite_queue[j].forward < entry.forward do
            sprite_queue[j + 1] = sprite_queue[j]
            j = j - 1
        end
        sprite_queue[j + 1] = entry
    end

    local t = self._game:time()

    for i = 1, count do
        local entry = sprite_queue[i]
        local half = PROJ_PLANE * 0.6 / entry.forward
        local left, right = self:_sprite_span(entry.screen_x, half, entry.forward)

        if left then
            local layer = 14 + (i - 1) / math_max(1, count) * 6
            local pulse = (math_sin(t * 4.5 + (entry.entity.phase or 0)) + 1) * 0.5
            local fog_t = math_min(1, entry.forward / 14)
            local fade = 1 - fog_t * fog_t * 0.75

            canvas:set_clip(math_max(0, left), 0, math_min(VIEW_W, right), VIEW_H)

            if entry.kind == "enemy" then
                self:_draw_enemy(canvas, entry, layer, pulse, fade, t)
            elseif entry.kind == "sigil" then
                self:_draw_sigil(canvas, entry, layer, pulse, fade, t)
            elseif entry.kind == "shard" then
                self:_draw_shard(canvas, entry, layer, pulse, fade, t)
            elseif entry.kind == "health" then
                self:_draw_health(canvas, entry, layer, pulse, fade, t)
            else
                self:_draw_fervor(canvas, entry, layer, pulse, fade, t)
            end

            canvas:reset_clip()
        end
    end

    for i = count + 1, #sprite_queue do sprite_queue[i].entity = nil end
end

function RaycasterView:_floor_shadow(canvas, x, floor_y, width, layer, fade)
    canvas:ellipse(x, floor_y, width * 0.55, width * 0.12, layer, RC.shadow, 130 * fade, 1, 0, 14)
end

function RaycasterView:_draw_enemy(canvas, entry, layer, pulse, fade, t)
    local forward = entry.forward
    local height = math_min(VIEW_H * 1.4, PROJ_PLANE * 0.94 / forward)
    local width = height * 0.5
    local phase = entry.entity.phase or 0
    local hover = math_sin(t * 2.4 + phase) * height * 0.035
    local cx = entry.screen_x + math_sin(phase * 1.7 + t * 1.3) * width * 0.06
    local floor_y = entry.floor_y
    local top = floor_y - height + hover - height * 0.04
    local a = 255 * fade

    self:_floor_shadow(canvas, cx, floor_y, width * 1.1, layer, fade)
    canvas:glow(cx, top + height * 0.45, width * 1.1, layer + 0.01, COLORS.corruption, 70 * fade * (0.7 + pulse * 0.3), 4)

    -- Robe: tapered body with ragged hem.
    local sh_y = top + height * 0.26
    local hem_y = floor_y - height * 0.06 + hover
    local sh_w = width * 0.3
    local hem_w = width * 0.48
    canvas:quad(cx - sh_w, sh_y, cx, sh_y - height * 0.02, cx, hem_y, cx - hem_w, hem_y, layer + 0.02, RC.robe_light, a, 0.9)
    canvas:quad(cx, sh_y - height * 0.02, cx + sh_w, sh_y, cx + hem_w, hem_y, cx, hem_y, layer + 0.02, RC.robe, a)
    local teeth = 6
    for k = 0, teeth - 1 do
        local x0 = cx - hem_w + (k / teeth) * hem_w * 2
        local x1 = cx - hem_w + ((k + 1) / teeth) * hem_w * 2
        local drop = height * (0.04 + hash(k, phase, 1) * 0.05) * (1 + math_sin(t * 5 + k + phase) * 0.25)
        canvas:tri(x0, hem_y - 1, x1, hem_y - 1, (x0 + x1) * 0.5, hem_y + drop, layer + 0.021, k < teeth / 2 and RC.robe_light or RC.robe, a, k < teeth / 2 and 0.9 or 1)
    end

    -- Corrupted sigils burning on the robe.
    local rune = 150 + pulse * 105
    canvas:line(cx - width * 0.08, top + height * 0.42, cx + width * 0.08, top + height * 0.55, math_max(1, width * 0.025), layer + 0.03, COLORS.corruption_hot, rune * fade)
    canvas:line(cx + width * 0.08, top + height * 0.42, cx - width * 0.08, top + height * 0.55, math_max(1, width * 0.025), layer + 0.03, COLORS.corruption_hot, rune * fade)
    canvas:circle(cx, top + height * 0.485, width * 0.05, layer + 0.031, COLORS.corruption_hot, rune * fade, 1, 0.3, 8)

    -- Arms reaching forward with bone claws.
    for side = -1, 1, 2 do
        local sway = math_sin(t * 3 + phase + side) * width * 0.08
        local ax, ay = cx + side * sh_w * 0.9, sh_y + height * 0.03
        local ex, ey = cx + side * width * 0.52 + sway, top + height * 0.5
        local hx, hy = cx + side * width * 0.45 + sway * 1.4, top + height * 0.62
        canvas:line(ax, ay, ex, ey, math_max(1.5, width * 0.12), layer + 0.025, side < 0 and RC.robe_light or RC.robe, a)
        canvas:line(ex, ey, hx, hy, math_max(1.2, width * 0.08), layer + 0.026, RC.robe, a)
        for c = -1, 1 do
            canvas:line(hx, hy, hx + side * width * 0.05 + c * width * 0.04, hy + height * 0.07, math_max(0.8, width * 0.02), layer + 0.027, RC.bone, a)
        end
    end

    -- Hood and burning eyes.
    local hood_y = top + height * 0.08
    canvas:tri(cx - width * 0.24, sh_y + height * 0.02, cx + width * 0.24, sh_y + height * 0.02, cx, top - height * 0.04, layer + 0.04, RC.robe_light, a, 0.75)
    canvas:tri(cx, sh_y + height * 0.02, cx + width * 0.24, sh_y + height * 0.02, cx, top - height * 0.04, layer + 0.041, RC.robe, a)
    canvas:ellipse(cx, hood_y + height * 0.08, width * 0.13, height * 0.075, layer + 0.045, COLORS.black, a, 1, 0, 12)
    for side = -1, 1, 2 do
        local ex, ey = cx + side * width * 0.055, hood_y + height * 0.075
        canvas:glow(ex, ey, width * 0.09, layer + 0.046, RC.eye, 150 * fade, 3)
        canvas:circle(ex, ey, math_max(0.8, width * 0.022), layer + 0.047, RC.eye, 255, 1, 0.5, 6)
    end
end

function RaycasterView:_draw_sigil(canvas, entry, layer, pulse, fade, t)
    local forward = entry.forward
    local size = math_min(190, PROJ_PLANE * 0.43 / forward)
    local cx = entry.screen_x
    local cy = entry.floor_y - PROJ_PLANE * (0.48 + pulse * 0.06) / forward
    local a = 255 * fade
    local spin = t * 1.2 + (entry.entity.phase or 0)

    canvas:vgradient(cx - size * 0.18, cy, size * 0.36, entry.floor_y - cy, layer, COLORS.gold, COLORS.gold, 0, 70 * fade, 8)
    canvas:ellipse(cx, entry.floor_y, size * 0.6, size * 0.12, layer, COLORS.gold, 60 * fade, 1, 0, 16)
    canvas:glow(cx, cy, size * 1.2, layer + 0.01, COLORS.gold, (60 + pulse * 50) * fade, 5)

    local r = size * 0.42
    canvas:ring(cx, cy, r, math_max(1.5, size * 0.07), layer + 0.02, COLORS.gold, a, 24, nil, nil, 0.9)
    canvas:ring(cx, cy, r * 0.62, math_max(1, size * 0.03), layer + 0.02, COLORS.gold_hot, a, 20)
    for k = 0, 7 do
        local ang = spin + k * math_pi / 4
        local len = k % 2 == 0 and r * 1.3 or r * 1.05
        local ca, sa = math_cos(ang), math_sin(ang)
        local px, py = -sa * size * 0.06, ca * size * 0.06
        canvas:tri(cx + px, cy + py, cx - px, cy - py, cx + ca * len, cy + sa * len, layer + 0.025, k % 2 == 0 and COLORS.gold_hot or COLORS.gold, a)
    end
    canvas:circle(cx, cy, size * 0.14, layer + 0.03, COLORS.gold, a, 0.8, 0, 12)
    canvas:circle(cx - size * 0.03, cy - size * 0.03, size * 0.07, layer + 0.031, COLORS.white, 240 * fade, 1, 0, 10)
end

function RaycasterView:_draw_shard(canvas, entry, layer, pulse, fade, t)
    local forward = entry.forward
    local size = math_min(90, PROJ_PLANE * 0.2 / forward)
    local cx = entry.screen_x
    local cy = entry.floor_y - PROJ_PLANE * (0.34 + pulse * 0.05) / forward
    local a = 255 * fade
    local turn = math_cos(t * 2.2 + (entry.entity.phase or 0))
    local w = size * 0.34 * (0.35 + math_abs(turn) * 0.65)
    local h = size * 0.55

    self:_floor_shadow(canvas, cx, entry.floor_y, size * 0.8, layer, fade)
    canvas:glow(cx, cy, size * 1.1, layer + 0.01, COLORS.fervor, (50 + pulse * 60) * fade, 4)
    canvas:tri(cx, cy - h, cx - w, cy, cx, cy, layer + 0.02, COLORS.fervor, a, 1, 0.35)
    canvas:tri(cx, cy - h, cx + w, cy, cx, cy, layer + 0.02, COLORS.fervor, a, 0.75)
    canvas:tri(cx, cy + h, cx - w, cy, cx, cy, layer + 0.02, COLORS.fervor, a, 0.6)
    canvas:tri(cx, cy + h, cx + w, cy, cx, cy, layer + 0.02, COLORS.fervor, a, 0.4)
    canvas:line(cx, cy - h, cx, cy + h, math_max(0.8, size * 0.02), layer + 0.03, COLORS.white, 160 * fade)
end

function RaycasterView:_draw_health(canvas, entry, layer, pulse, fade, t)
    local forward = entry.forward
    local size = math_min(100, PROJ_PLANE * 0.25 / forward)
    local cx = entry.screen_x
    local cy = entry.floor_y - PROJ_PLANE * 0.3 / forward + math_sin(t * 2 + (entry.entity.phase or 0)) * size * 0.08
    local a = 255 * fade

    self:_floor_shadow(canvas, cx, entry.floor_y, size, layer, fade)
    canvas:glow(cx, cy, size * 1.2, layer + 0.01, COLORS.grace, (40 + pulse * 50) * fade, 4)
    canvas:circle(cx, cy, size * 0.42, layer + 0.02, COLORS.grace, 170 * fade, 0.6, 0, 18)
    canvas:circle(cx - size * 0.1, cy - size * 0.1, size * 0.28, layer + 0.021, COLORS.grace, 120 * fade, 1, 0.3, 14)
    canvas:rect(cx - size * 0.08, cy - size * 0.3, size * 0.16, size * 0.6, layer + 0.03, COLORS.white, a)
    canvas:rect(cx - size * 0.3, cy - size * 0.08, size * 0.6, size * 0.16, layer + 0.03, COLORS.white, a)
    canvas:ring(cx, cy, size * 0.5, math_max(1, size * 0.03), layer + 0.035, COLORS.grace, 200 * fade, 20, t * 2, t * 2 + math_pi * 1.3)
end

function RaycasterView:_draw_fervor(canvas, entry, layer, pulse, fade, t)
    local forward = entry.forward
    local size = math_min(100, PROJ_PLANE * 0.24 / forward)
    local cx = entry.screen_x
    local cy = entry.floor_y - PROJ_PLANE * 0.28 / forward
    local a = 255 * fade
    local level = 0.55 + math_sin(t * 3 + (entry.entity.phase or 0)) * 0.08

    self:_floor_shadow(canvas, cx, entry.floor_y, size * 0.7, layer, fade)
    canvas:glow(cx, cy, size, layer + 0.01, COLORS.fervor, (40 + pulse * 55) * fade, 4)
    canvas:rect(cx - size * 0.2, cy - size * 0.35, size * 0.4, size * 0.72, layer + 0.02, COLORS.black, 170 * fade)
    canvas:rect(cx - size * 0.18, cy - size * 0.35 + size * 0.72 * (1 - level), size * 0.36, size * 0.72 * level, layer + 0.025, COLORS.fervor, a, 1, 0.1)
    canvas:rect(cx - size * 0.14, cy - size * 0.3, size * 0.06, size * 0.6, layer + 0.03, COLORS.white, 110 * fade)
    canvas:rect(cx - size * 0.24, cy - size * 0.47, size * 0.48, size * 0.13, layer + 0.03, COLORS.gold, a, 0.8)
    canvas:rect(cx - size * 0.24, cy + size * 0.37, size * 0.48, size * 0.08, layer + 0.03, COLORS.gold, a, 0.7)
end

function RaycasterView:_draw_effects(canvas, effects, horizon, sx)
    if not effects then return end

    for i = 1, #effects do
        local effect = effects[i]
        local screen_x, floor_y, forward = self:_project(effect.x, effect.y, horizon, sx)

        if screen_x then
            local column = math_floor(math_min(COLUMN_COUNT, math_max(1, screen_x / COLUMN_W + 1)))
            if forward < (self._zbuffer[column] or 999) + 0.1 then
                local screen_y = floor_y - effect.z * PROJ_PLANE / forward
                local life = math_max(0, effect.life / effect.max_life)
                local size = math_min(22, math_max(2, effect.size * PROJ_PLANE / forward))
                local color = effect.kind == "purge" and COLORS.corruption_hot
                    or effect.kind == "sigil" and COLORS.gold_hot
                    or effect.kind == "health" and COLORS.grace
                    or COLORS.fervor
                canvas:glow(screen_x, screen_y, size * 1.6, 21, color, 150 * life, 3)
                canvas:circle(screen_x, screen_y, size * 0.35, 21.05, color, 255 * life, 1, 0.5, 8)
            end
        end
    end
end

function RaycasterView:_draw_motes(canvas, theme, horizon, sx)
    local time = self._game:time()
    local player = self._game:player()

    for i = 1, 60 do
        local depth = 0.45 + (i % 9) * 0.13
        local phase = i * 2.417 + time * (0.16 + (i % 5) * 0.035)
        local x = ((math_sin(phase + player.angle * depth) * 0.5 + 0.5) * VIEW_W + sx) % VIEW_W
        local y = (math_cos(phase * 0.71) * 0.5 + 0.5) * VIEW_H
        local size = 0.8 + (i % 4) * 0.5
        local twinkle = (math_sin(time * 2 + i) + 1) * 0.5
        canvas:rect(x - size * 0.5, y - size * 0.5, size, size, 12, theme.wall_detail, 40 + twinkle * 60, 1, 0.3)
    end
end

function RaycasterView:_draw_speed_lines(canvas, theme, horizon)
    local intensity = self._game:dash_active() and 1 or math_max(0, (self._game:combo() - 8) / 20)
    if intensity <= 0 then return end

    local time = self._game:time()
    local cx, cy = VIEW_W * 0.5, horizon

    for i = 1, 40 do
        local angle = i / 40 * math_pi * 2 + time * 0.16
        local inner = 70 + (i * 37 % 110) + (time * 400 + i * 50) % 120
        local length = 45 + (i * 29 % 105) * intensity
        local ca, sa = math_cos(angle), math_sin(angle) * 0.72
        canvas:line(cx + ca * inner, cy + sa * inner, cx + ca * (inner + length), cy + sa * (inner + length), 1 + intensity * 1.5, 22.5, theme.portal, 30 + intensity * 110)
    end
    canvas:glow(cx, cy, 160, 22.4, theme.portal, 50 * intensity, 5)
end

function RaycasterView:_draw_fist(canvas, theme, base_x, base_y, mirror, glow, dash, t)
    local m = mirror
    local function px(x) return base_x + x * m end
    local steel = RC.steel

    -- Armoured forearm rising from the bottom edge.
    canvas:quad(px(-46), base_y + 130, px(-24), base_y + 34, px(34), base_y + 34, px(52), base_y + 130, 22, steel, 255, 0.5)
    canvas:quad(px(-30), base_y + 130, px(-14), base_y + 40, px(22), base_y + 40, px(36), base_y + 130, 22.01, steel, 255, 0.78)
    canvas:line(px(-14), base_y + 40, px(-30), base_y + 130, 2, 22.02, RC.steel_light, 170)
    for band = 0, 1 do
        local y = base_y + 60 + band * 34
        local inset = band * 5
        canvas:quad(px(-28 - inset), y, px(38 + inset), y, px(40 + inset), y + 7, px(-30 - inset), y + 7, 22.03, COLORS.gold, 255, 0.75)
        canvas:line(px(-28 - inset), y, px(38 + inset), y, 1.2, 22.04, COLORS.gold_hot, 200)
    end

    -- Power coils glowing around the wrist.
    local field = 0.45 + glow * 0.35 + dash * 0.8
    canvas:glow(px(4), base_y + 36, 70 + dash * 30, 21.9, COLORS.fervor, 55 * field, 5)
    canvas:ellipse(px(4), base_y + 36, 34, 7, 22.05, COLORS.fervor, 120 + glow * 100, 1, 0.3, 16)
    canvas:ellipse(px(4), base_y + 36, 28, 4, 22.06, COLORS.white, 90 + glow * 90, 1, 0, 14)

    -- Back of the hand.
    canvas:quad(px(-30), base_y + 34, px(-34), base_y - 4, px(38), base_y - 6, px(36), base_y + 34, 22.1, theme.wall, 255, 0.62)
    canvas:quad(px(-22), base_y + 30, px(-24), base_y + 2, px(28), base_y, px(28), base_y + 30, 22.11, theme.wall, 255, 0.95)
    canvas:line(px(-24), base_y + 2, px(28), base_y, 1.5, 22.12, theme.wall_detail, 220)
    canvas:circle(px(2), base_y + 16, 6, 22.13, COLORS.gold, 255, 0.8, 0, 12)
    canvas:circle(px(2), base_y + 16, 3, 22.14, COLORS.corruption_hot, 230, 1, 0.2, 8)

    -- Thumb wrapped over the inner side.
    canvas:ellipse(px(38), base_y + 12, 10, 18, 22.15, steel, 255, 0.6, 0, 14)
    canvas:ellipse(px(36), base_y + 8, 6, 12, 22.16, steel, 255, 0.9, 0, 12)

    -- Knuckle plates, lit from above.
    for k = 0, 3 do
        local kx = px(-24 + k * 17)
        local ky = base_y - 10 + math_abs(k - 1.5) * 2
        canvas:circle(kx, ky + 2, 10, 22.2, RC.shadow, 120, 1, 0, 12)
        canvas:circle(kx, ky, 9, 22.21, steel, 255, 0.7, 0, 14)
        canvas:circle(kx - 2 * m, ky - 2.5, 6, 22.22, steel, 255, 1, 0.2, 12)
        canvas:circle(kx - 3 * m, ky - 4, 2, 22.23, COLORS.white, 180, 1, 0, 6)
    end

    -- Crackling power field arcs.
    if dash > 0 or math_sin(t * 7) > 0.55 then
        local seed = math_floor(t * 30) + (m > 0 and 17 or 3)
        for arc = 1, 1 + dash * 2 do
            local lx, ly = px(-24 + hash(seed, arc) * 52), base_y - 18
            for s = 1, 5 do
                local nx = lx + (hash(seed + arc, s * 3) - 0.5) * 22
                local ny = ly - 7 - hash(seed + arc, s * 5) * 12
                canvas:line(lx, ly, nx, ny, 4, 22.29, COLORS.fervor, 90)
                canvas:line(lx, ly, nx, ny, 1.3, 22.3, COLORS.white, 230)
                lx, ly = nx, ny
            end
        end
    end
end

function RaycasterView:_draw_gauntlets(canvas, theme)
    local time = self._game:time()
    local dash = self._game:dash_active() and 1 or 0
    local bob = math_sin(time * 6.5) * 3
    local reach = dash * 46
    local glow = (math_sin(time * 4.2) + 1) * 0.5

    self:_draw_fist(canvas, theme, 92 + reach, 408 + bob, 1, glow, dash, time)
    self:_draw_fist(canvas, theme, 508 - reach, 408 - bob, -1, glow, dash, time)
end

function RaycasterView:_draw_post(canvas, theme, horizon)
    local t = self._time

    if self._pickup_flash > 0 then
        canvas:vignette(0, 0, VIEW_W, VIEW_H, 120, 24.3, 160 * self._pickup_flash, 6, self._pickup_color)
    end
    if self._damage_flash > 0 then
        canvas:vignette(0, 0, VIEW_W, VIEW_H, 150, 24.35, 255 * self._damage_flash, 8, COLORS.warning)
    end

    canvas:crt(0, 0, VIEW_W, VIEW_H, t, 24.5, { tint = theme.grid, scan_alpha = 26, vignette_depth = 110, vignette_alpha = 190, noise_count = 16 })
end

function RaycasterView:destroy()
    self._canvas = nil
    self._particles = nil
    RaycasterView.super.destroy(self)
end

return RaycasterView
