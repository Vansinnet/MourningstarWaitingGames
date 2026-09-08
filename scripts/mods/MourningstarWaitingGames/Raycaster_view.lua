local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")

local math_abs = math.abs
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_sin = math.sin
local math_sqrt = math.sqrt

local RENDER_SIZE = 600
local VIEW_W = 600
local VIEW_H = 480
local HORIZON = 214
local COLUMN_COUNT = 150
local COLUMN_W = VIEW_W / COLUMN_COUNT
local FOV = 1.18
local PROJ_PLANE = (VIEW_W * 0.5) / math.tan(FOV * 0.5)
local CEILING_BANDS = 16
local FLOOR_BANDS = 18
local GRID_LINES = 28
local ARCH_WIDGETS = 30
local SPRITE_RECTS = 260
local SPRITE_CIRCLES = 100
local EFFECT_WIDGETS = 90
local MOTE_WIDGETS = 52
local SPEED_LINE_WIDGETS = 24
local GAUNTLET_WIDGETS = 18

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

local function rect_def(parent)
    return UIWidget.create_definition({
        {
            pass_type = "texture",
            style_id = "gfx",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = { 0, 0, 0, 0 } },
        },
    }, parent or "game_area", nil, { 4, 4 })
end

local function circle_def(size, parent)
    return UIWidget.create_definition({
        {
            pass_type = "circle",
            style_id = "gfx",
            style = { color = { 0, 0, 0, 0 } },
        },
    }, parent or "game_area", nil, { size or 8, size or 8 })
end

local function line_def()
    return UIWidget.create_definition({
        {
            pass_type = "triangle",
            style_id = "tri1",
            style = { color = { 0, 0, 0, 0 }, triangle_corners = { { 0, 0 }, { 0, 0 }, { 0, 0 } } },
        },
        {
            pass_type = "triangle",
            style_id = "tri2",
            style = { color = { 0, 0, 0, 0 }, triangle_corners = { { 0, 0 }, { 0, 0 }, { 0, 0 } } },
        },
    }, "game_area", nil, { 1, 1 })
end

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

local function color_alpha(color, alpha)
    return math_max(0, math_min(color[1], alpha))
end

local function clear_rect(widget)
    widget.style.gfx.color[1] = 0
end

local function clear_circle(widget)
    widget.style.gfx.color[1] = 0
end

local function clear_line(widget)
    widget.style.tri1.color[1] = 0
    widget.style.tri2.color[1] = 0
end

local function draw_rect(widget, x, y, width, height, color, alpha, z)
    widget.offset[1] = x
    widget.offset[2] = y
    widget.offset[3] = z or 5
    widget.content.size[1] = width
    widget.content.size[2] = height
    set_color(widget.style.gfx.color, color, alpha)
end

local function draw_world_rect(widget, x, y, width, height, color, alpha, z)
    if x < 0 then
        width = width + x
        x = 0
    end
    if y < 0 then
        height = height + y
        y = 0
    end
    if x + width > VIEW_W then width = VIEW_W - x end
    if y + height > VIEW_H then height = VIEW_H - y end

    if width <= 0 or height <= 0 then
        clear_rect(widget)
        return false
    end

    draw_rect(widget, x, y, width, height, color, alpha, z)
    return true
end

local function draw_circle(widget, x, y, size, color, alpha, z)
    if x + size < 0 or x - size > VIEW_W or y + size < 0 or y - size > VIEW_H then
        clear_circle(widget)
        return false
    end

    widget.offset[1] = x - size * 0.5
    widget.offset[2] = y - size * 0.5
    widget.offset[3] = z or 5
    widget.content.size[1] = size
    widget.content.size[2] = size
    set_color(widget.style.gfx.color, color, alpha)

    return true
end

local function clip_line(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local t0 = 0
    local t1 = 1

    local function edge(p, q)
        if p == 0 then return q >= 0 end

        local ratio = q / p

        if p < 0 then
            if ratio > t1 then return false end
            if ratio > t0 then t0 = ratio end
        else
            if ratio < t0 then return false end
            if ratio < t1 then t1 = ratio end
        end

        return true
    end

    if edge(-dx, x1) and edge(dx, VIEW_W - x1) and edge(-dy, y1) and edge(dy, VIEW_H - y1) then
        return x1 + dx * t0, y1 + dy * t0, x1 + dx * t1, y1 + dy * t1
    end

    return nil
end

local function draw_line(widget, x1, y1, x2, y2, thickness, color, alpha, z)
    x1, y1, x2, y2 = clip_line(x1, y1, x2, y2)

    if not x1 then
        clear_line(widget)
        return false
    end

    local dx = x2 - x1
    local dy = y2 - y1
    local length = math_sqrt(dx * dx + dy * dy)

    if length <= 0.1 then
        clear_line(widget)
        return false
    end

    local half = thickness * 0.5
    local nx = -dy / length * half
    local ny = dx / length * half
    local x1a, y1a = x1 + nx, y1 + ny
    local x1b, y1b = x1 - nx, y1 - ny
    local x2a, y2a = x2 + nx, y2 + ny
    local x2b, y2b = x2 - nx, y2 - ny
    local triangle_one = widget.style.tri1.triangle_corners
    local triangle_two = widget.style.tri2.triangle_corners

    widget.offset[1] = 0
    widget.offset[2] = 0
    widget.offset[3] = z or 5
    triangle_one[1][1], triangle_one[1][2] = x1a, y1a
    triangle_one[2][1], triangle_one[2][2] = x2a, y2a
    triangle_one[3][1], triangle_one[3][2] = x2b, y2b
    triangle_two[1][1], triangle_two[1][2] = x1a, y1a
    triangle_two[2][1], triangle_two[2][2] = x2b, y2b
    triangle_two[3][1], triangle_two[3][2] = x1b, y1b
    set_color(widget.style.tri1.color, color, alpha)
    set_color(widget.style.tri2.color, color, alpha)

    return true
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

    self._ceiling_widgets = {}
    for i = 1, CEILING_BANDS do
        self._ceiling_widgets[i] = UIWidget.init("purge_ceiling_" .. i, rect_def())
    end

    self._floor_widgets = {}
    for i = 1, FLOOR_BANDS do
        self._floor_widgets[i] = UIWidget.init("purge_floor_" .. i, rect_def())
    end

    self._grid_widgets = {}
    for i = 1, GRID_LINES do
        self._grid_widgets[i] = UIWidget.init("purge_grid_" .. i, line_def())
    end

    self._arch_widgets = {}
    for i = 1, ARCH_WIDGETS do
        self._arch_widgets[i] = UIWidget.init("purge_arch_" .. i, line_def())
    end

    self._wall_widgets = {}
    self._wall_details = {}
    for i = 1, COLUMN_COUNT do
        self._wall_widgets[i] = UIWidget.init("purge_wall_" .. i, rect_def())
        for detail = 1, 3 do
            local index = (i - 1) * 3 + detail
            self._wall_details[index] = UIWidget.init("purge_masonry_" .. index, rect_def())
        end
    end

    self._sprite_rects = {}
    for i = 1, SPRITE_RECTS do
        self._sprite_rects[i] = UIWidget.init("purge_sprite_rect_" .. i, rect_def())
    end

    self._sprite_circles = {}
    for i = 1, SPRITE_CIRCLES do
        self._sprite_circles[i] = UIWidget.init("purge_sprite_circle_" .. i, circle_def(8))
    end

    self._effect_widgets = {}
    for i = 1, EFFECT_WIDGETS do
        self._effect_widgets[i] = UIWidget.init("purge_effect_" .. i, circle_def(5))
    end

    self._mote_widgets = {}
    for i = 1, MOTE_WIDGETS do
        self._mote_widgets[i] = UIWidget.init("purge_mote_" .. i, circle_def(4))
    end

    self._speed_line_widgets = {}
    for i = 1, SPEED_LINE_WIDGETS do
        self._speed_line_widgets[i] = UIWidget.init("purge_speed_" .. i, line_def())
    end

    self._gauntlet_widgets = {}
    for i = 1, GAUNTLET_WIDGETS do
        self._gauntlet_widgets[i] = UIWidget.init("purge_gauntlet_" .. i, rect_def())
    end
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
        self:_draw_dynamic(ui_renderer)
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

function RaycasterView:_draw_dynamic(ui_renderer)
    local game = self._game
    local time = game:time()
    local shake = game:shake()
    local dash = game:dash_active() and 1 or 0
    local sx = math_sin(time * 73) * shake * 7
    local sy = math_cos(time * 59) * shake * 5
    local bob = math_sin(time * (dash > 0 and 11 or 6.5)) * (1.2 + dash * 2.5)
    local horizon = HORIZON + sy + bob
    local theme = THEMES[game:theme()] or THEMES[1]
    local entities = game:render_entities()

    self:_draw_floor_and_ceiling(ui_renderer, theme, horizon, sx)
    self:_draw_cathedral_silhouette(ui_renderer, theme, horizon, sx)
    self:_draw_walls(ui_renderer, theme, horizon, sx)
    self:_draw_entities(ui_renderer, entities, theme, horizon, sx)
    self:_draw_effects(ui_renderer, entities.effects, horizon, sx)
    self:_draw_motes(ui_renderer, theme, horizon, sx)
    self:_draw_speed_lines(ui_renderer, theme)
    self:_draw_gauntlets(ui_renderer, theme)
end

function RaycasterView:_draw_floor_and_ceiling(ui_renderer, theme, horizon, sx)
    local ceiling_height = math_max(1, horizon)
    local ceiling_band_height = ceiling_height / CEILING_BANDS

    for i = 1, CEILING_BANDS do
        local widget = self._ceiling_widgets[i]
        local color = theme.ceiling
        local progress = i / CEILING_BANDS

        draw_world_rect(widget, 0, (i - 1) * ceiling_band_height, VIEW_W, ceiling_band_height + 1, color, 255, 1)
        for channel = 2, 4 do
            widget.style.gfx.color[channel] = color[channel] + (theme.ceiling_hot[channel] - color[channel]) * progress * progress * 0.55
        end
        UIWidget.draw(widget, ui_renderer)
    end

    local floor_height = math_max(1, VIEW_H - horizon)
    local floor_band_height = floor_height / FLOOR_BANDS

    for i = 1, FLOOR_BANDS do
        local widget = self._floor_widgets[i]
        local color = theme.floor
        local progress = (i - 0.5) / FLOOR_BANDS
        local light = math_sin(progress * math_pi) * 0.48

        draw_world_rect(widget, 0, horizon + (i - 1) * floor_band_height, VIEW_W, floor_band_height + 1, color, 255, 1)
        for channel = 2, 4 do
            widget.style.gfx.color[channel] = color[channel] + (theme.floor_hot[channel] - color[channel]) * light
        end
        UIWidget.draw(widget, ui_renderer)
    end

    local player = self._game:player()
    local line_index = 1
    local scroll = (player.x * 0.31 + player.y * 0.23) % 1

    for i = 1, 13 do
        local progress = ((i - 1 + scroll) % 13 + 1) / 13
        local y = horizon + floor_height * progress * progress
        local widget = self._grid_widgets[line_index]
        local alpha = 10 + math_floor(progress * 36)

        draw_line(widget, 0, y, VIEW_W, y, 1.1 + progress * 1.2, theme.grid, alpha, 3)
        UIWidget.draw(widget, ui_renderer)
        line_index = line_index + 1
    end

    local vanishing_x = VIEW_W * 0.5 + sx * 0.4
    local lateral_phase = ((player.x - player.y) * 46) % 92

    for i = 1, 11 do
        local endpoint_x = -170 + (i - 1) * 92 + lateral_phase
        local widget = self._grid_widgets[line_index]

        draw_line(widget, vanishing_x, horizon, endpoint_x, VIEW_H, 1.0, theme.grid, 28, 3)
        UIWidget.draw(widget, ui_renderer)
        line_index = line_index + 1
    end

    for i = 1, 4 do
        local endpoint_x = -100 + (i - 1) * 265
        local widget = self._grid_widgets[line_index]

        draw_line(widget, vanishing_x, horizon, endpoint_x, 0, 1.1, theme.grid, 23, 2)
        UIWidget.draw(widget, ui_renderer)
        line_index = line_index + 1
    end

    for i = line_index, GRID_LINES do
        clear_line(self._grid_widgets[i])
    end
end

function RaycasterView:_draw_cathedral_silhouette(ui_renderer, theme, horizon, sx)
    local player = self._game:player()
    local spacing = 152
    local scroll = (player.angle / (math_pi * 2) * VIEW_W * 2.4) % spacing

    for arch = 1, ARCH_WIDGETS / 6 do
        local x = (arch - 1) * spacing - scroll + sx * 0.15
        local spring = horizon - 82
        local apex = horizon - 173
        local index = (arch - 1) * 6

        draw_line(self._arch_widgets[index + 1], x, horizon, x, spring, 9, theme.wall_side, 155, 4)
        draw_line(self._arch_widgets[index + 2], x + spacing, horizon, x + spacing, spring, 9, theme.wall_side, 155, 4)
        draw_line(self._arch_widgets[index + 3], x, spring, x + spacing * 0.23, spring - 48, 5, theme.wall_detail, 48, 4)
        draw_line(self._arch_widgets[index + 4], x + spacing * 0.23, spring - 48, x + spacing * 0.5, apex, 4, theme.wall_detail, 48, 4)
        draw_line(self._arch_widgets[index + 5], x + spacing * 0.5, apex, x + spacing * 0.77, spring - 48, 4, theme.wall_detail, 32, 4)
        draw_line(self._arch_widgets[index + 6], x + spacing * 0.77, spring - 48, x + spacing, spring, 5, theme.wall_detail, 32, 4)
        for part = 1, 6 do
            UIWidget.draw(self._arch_widgets[index + part], ui_renderer)
        end
    end
end

function RaycasterView:_draw_walls(ui_renderer, theme, horizon, sx)
    local columns = self._game:cast_columns(COLUMN_COUNT, FOV)
    local portal_open = self._game:portal_open()
    local time = self._game:time()

    for i = 1, COLUMN_COUNT do
        local column = columns[i]
        local distance = math_max(0.07, column.corrected_distance or column.distance)
        local height = math_min(VIEW_H * 2.4, PROJ_PLANE / distance)
        local x = (i - 1) * COLUMN_W + sx
        local y = horizon - height * 0.5
        local color
        local alpha

        if column.tile == "X" then
            color = portal_open and theme.portal or theme.locked
            local bands = math_floor(column.wall_x * 12 + time * (portal_open and 5 or 1.5)) % 3
            alpha = 155 + bands * 45 + math_sin(time * 5 + i * 0.1) * 20
        else
            local stripe = math_floor(column.wall_x * 10 + column.map_x * 2 + column.map_y) % 5
            color = column.side == "y" and theme.wall_side or stripe == 0 and theme.wall_detail or theme.wall
            alpha = 255

            if column.wall_x < 0.035 or column.wall_x > 0.965 then
                color = theme.wall_detail
                alpha = alpha + 35
            end
        end

        local widget = self._wall_widgets[i]

        if draw_world_rect(widget, x, y, COLUMN_W + 1, height, color, color_alpha(color, alpha), 8) then
            if column.tile ~= "X" then
                local light = 1 / (1 + distance * 0.19)
                local stone = 0.88 + (column.map_x * 7 + column.map_y * 13) % 5 * 0.025
                for channel = 2, 4 do
                    widget.style.gfx.color[channel] = theme.fog[channel] * (1 - light) + color[channel] * light * stone
                end
            end
            UIWidget.draw(widget, ui_renderer)
        end

        -- Three clipped strips per ray keep masonry aligned with the wall hit, not the screen.
        local detail_index = (i - 1) * 3
        local u = math_abs(column.wall_x - 0.5) * 2
        local relief = math_max(0, 1 - distance / 15)
        local recess_top = 0.14 + u * u * 0.22
        local recess = self._wall_details[detail_index + 1]
        local sill = self._wall_details[detail_index + 2]
        local cornice = self._wall_details[detail_index + 3]
        if column.tile ~= "X" then
            if u < 0.72 and height > 12 then
                if draw_world_rect(recess, x, y + height * recess_top, COLUMN_W + 1, height * (0.77 - recess_top), COLORS.black, 125 * relief, 8.1) then
                    UIWidget.draw(recess, ui_renderer)
                end
            end
            if draw_world_rect(sill, x, y + height * 0.80, COLUMN_W + 1, math_max(1, height * 0.024), theme.wall_detail, 105 * relief, 8.2) then
                UIWidget.draw(sill, ui_renderer)
            end
            if draw_world_rect(cornice, x, y + height * 0.065, COLUMN_W + 1, math_max(1, height * 0.026), theme.wall_detail, 135 * relief, 8.2) then
                UIWidget.draw(cornice, ui_renderer)
            end
        else
            if draw_world_rect(recess, x, y + height * (0.1 + u * 0.18), COLUMN_W + 1, height * 0.60, color, 38, 8.1) then
                UIWidget.draw(recess, ui_renderer)
            end
            if draw_world_rect(sill, x, y + height * 0.85, COLUMN_W + 1, height * 0.035, COLORS.gold_hot, 180, 8.2) then
                UIWidget.draw(sill, ui_renderer)
            end
        end

        self._zbuffer[i] = distance
    end
end

function RaycasterView:_draw_entities(ui_renderer, entities, theme, horizon, sx)
    local player = self._game:player()
    local cosine = math_cos(player.angle)
    local sine = math_sin(player.angle)
    local render_queue = {}

    local function queue_entity(entity, kind)
        local dx = entity.x - player.x
        local dy = entity.y - player.y
        local forward = dx * cosine + dy * sine

        if forward <= 0.12 then return end

        local side = -dx * sine + dy * cosine
        local screen_x = VIEW_W * 0.5 + side / forward * PROJ_PLANE

        if screen_x < -180 or screen_x > VIEW_W + 180 then return end

        render_queue[#render_queue + 1] = {
            entity = entity,
            kind = kind,
            forward = forward,
            screen_x = screen_x,
        }
    end

    for i = 1, #entities.pickups do
        local pickup = entities.pickups[i]
        if not pickup.taken then queue_entity(pickup, pickup.kind) end
    end

    for i = 1, #entities.enemies do
        local enemy = entities.enemies[i]
        if enemy.alive then queue_entity(enemy, "enemy") end
    end

    table.sort(render_queue, function(a, b) return a.forward > b.forward end)

    self._sprite_rect_index = 1
    self._sprite_circle_index = 1
    self._sprite_renderer = ui_renderer
    local entity_layer_step = 6 / math_max(1, #render_queue)
    -- Components use 14..20; reserve seven sublayers per entity below effects at 21.
    self._sprite_layer_step = entity_layer_step / 7

    for i = 1, #render_queue do
        local entry = render_queue[i]
        local column = math_floor(math_min(COLUMN_COUNT, math_max(1, entry.screen_x / COLUMN_W + 1)))

        if entry.forward < (self._zbuffer[column] or 999) + 0.12 then
            self._sprite_layer = 14 + (i - 1) * entity_layer_step
            local floor_y = horizon + PROJ_PLANE * 0.5 / entry.forward
            local pulse = (math_sin(self._game:time() * 4.5 + entry.entity.phase) + 1) * 0.5

            if entry.kind == "enemy" then
                self:_draw_enemy(entry, floor_y, pulse, sx)
            elseif entry.kind == "sigil" then
                self:_draw_sigil(entry, floor_y, pulse, sx)
            elseif entry.kind == "shard" then
                self:_draw_shard(entry, floor_y, pulse, sx)
            elseif entry.kind == "health" then
                self:_draw_health(entry, floor_y, pulse, sx)
            else
                self:_draw_fervor(entry, floor_y, pulse, sx)
            end
        end
    end

    for i = self._sprite_rect_index, SPRITE_RECTS do clear_rect(self._sprite_rects[i]) end
    for i = self._sprite_circle_index, SPRITE_CIRCLES do clear_circle(self._sprite_circles[i]) end
end

function RaycasterView:_sprite_rect(x, y, width, height, color, alpha, z)
    local index = self._sprite_rect_index
    if index > SPRITE_RECTS then return end

    local widget = self._sprite_rects[index]
    self._sprite_rect_index = index + 1

    local layer = self._sprite_layer + ((z or 15) - 14) * self._sprite_layer_step
    if draw_world_rect(widget, x, y, width, height, color, alpha, layer) then
        UIWidget.draw(widget, self._sprite_renderer)
    end
end

function RaycasterView:_sprite_circle(x, y, size, color, alpha, z)
    local index = self._sprite_circle_index
    if index > SPRITE_CIRCLES then return end

    local widget = self._sprite_circles[index]
    self._sprite_circle_index = index + 1

    local layer = self._sprite_layer + ((z or 16) - 14) * self._sprite_layer_step
    if draw_circle(widget, x, y, size, color, alpha, layer) then
        UIWidget.draw(widget, self._sprite_renderer)
    end
end

function RaycasterView:_draw_enemy(entry, floor_y, pulse, sx)
    local forward = entry.forward
    local height = math_min(VIEW_H * 1.3, PROJ_PLANE * 0.94 / forward)
    local width = height * 0.46
    local center_x = entry.screen_x + sx
    local top = floor_y - height
    local fade = math_max(70, 255 - forward * 16)
    local sway = math_sin(entry.entity.phase * 1.7) * width * 0.08

    self:_sprite_circle(center_x + sway, top + height * 0.23, width * 0.55, COLORS.corruption, fade * 0.35, 14)
    self:_sprite_circle(center_x + sway, top + height * 0.20, width * 0.34, COLORS.armor_edge, fade, 18)
    self:_sprite_rect(center_x - width * 0.28 + sway, top + height * 0.27, width * 0.56, height * 0.42, COLORS.armor, fade, 17)
    self:_sprite_rect(center_x - width * 0.48 + sway, top + height * 0.37, width * 0.24, height * 0.08, COLORS.corruption_hot, fade * 0.75, 18)
    self:_sprite_rect(center_x + width * 0.24 + sway, top + height * 0.37, width * 0.24, height * 0.08, COLORS.corruption_hot, fade * 0.75, 18)
    self:_sprite_rect(center_x - width * 0.25 + sway, top + height * 0.67, width * 0.16, height * 0.26, COLORS.corruption, fade * 0.62, 16)
    self:_sprite_rect(center_x + width * 0.09 + sway, top + height * 0.67, width * 0.16, height * 0.26, COLORS.corruption, fade * 0.62, 16)
    self:_sprite_rect(center_x - width * 0.12 + sway, top + height * 0.17, width * 0.07, height * 0.035, COLORS.white, 230, 19)
    self:_sprite_rect(center_x + width * 0.05 + sway, top + height * 0.17, width * 0.07, height * 0.035, COLORS.white, 230, 19)

    if height > 28 then
        self:_sprite_rect(center_x - width * 0.28 + sway, top + height * 0.29, width * 0.055, height * 0.36, COLORS.armor_edge, fade, 18)
        self:_sprite_rect(center_x - width * 0.18 + sway, top + height * 0.31, width * 0.36, height * 0.065, COLORS.armor_edge, fade, 18)
        self:_sprite_rect(center_x - width * 0.045 + sway, top + height * 0.40, width * 0.09, height * 0.23, COLORS.corruption_hot, fade * 0.7, 18)
        self:_sprite_rect(center_x - width * 0.09 + sway, top + height * 0.22, width * 0.18, height * 0.045, COLORS.black, fade, 19)
    end

    if pulse > 0.72 then
        self:_sprite_circle(center_x + sway, top + height * 0.48, width * 0.18, COLORS.corruption_hot, 130, 19)
    end
end

function RaycasterView:_draw_sigil(entry, floor_y, pulse, sx)
    local forward = entry.forward
    local size = math_min(190, PROJ_PLANE * 0.43 / forward)
    local center_x = entry.screen_x + sx
    local center_y = floor_y - PROJ_PLANE * (0.48 + pulse * 0.06) / forward
    local fade = math_max(80, 255 - forward * 13)

    self:_sprite_circle(center_x, center_y, size * 1.18, COLORS.gold, 35 + pulse * 45, 14)
    self:_sprite_circle(center_x, center_y, size * 0.82, COLORS.gold, fade, 17)
    self:_sprite_circle(center_x, center_y, size * 0.52, COLORS.black, 235, 18)
    self:_sprite_rect(center_x - size * 0.07, center_y - size * 0.38, size * 0.14, size * 0.76, COLORS.gold_hot, fade, 19)
    self:_sprite_rect(center_x - size * 0.30, center_y - size * 0.07, size * 0.60, size * 0.14, COLORS.gold_hot, fade, 19)
    self:_sprite_circle(center_x, center_y, size * 0.16, COLORS.white, 240, 20)
end

function RaycasterView:_draw_shard(entry, floor_y, pulse, sx)
    local forward = entry.forward
    local size = math_min(90, PROJ_PLANE * 0.20 / forward)
    local center_x = entry.screen_x + sx
    local center_y = floor_y - PROJ_PLANE * (0.34 + pulse * 0.05) / forward
    local fade = math_max(70, 245 - forward * 15)

    self:_sprite_circle(center_x, center_y, size * 1.25, COLORS.fervor, 22 + pulse * 38, 14)
    self:_sprite_rect(center_x - size * 0.12, center_y - size * 0.48, size * 0.24, size * 0.96, COLORS.fervor, fade, 17)
    self:_sprite_rect(center_x - size * 0.34, center_y - size * 0.22, size * 0.68, size * 0.44, COLORS.fervor, fade * 0.82, 17)
    self:_sprite_rect(center_x - size * 0.06, center_y - size * 0.29, size * 0.12, size * 0.58, COLORS.white, 220, 18)
end

function RaycasterView:_draw_health(entry, floor_y, pulse, sx)
    local forward = entry.forward
    local size = math_min(100, PROJ_PLANE * 0.25 / forward)
    local center_x = entry.screen_x + sx
    local center_y = floor_y - PROJ_PLANE * 0.27 / forward
    local fade = math_max(80, 255 - forward * 13)

    self:_sprite_circle(center_x, center_y, size * 1.05, COLORS.grace, 30 + pulse * 30, 14)
    self:_sprite_rect(center_x - size * 0.38, center_y - size * 0.38, size * 0.76, size * 0.76, COLORS.grace, fade * 0.5, 16)
    self:_sprite_rect(center_x - size * 0.09, center_y - size * 0.32, size * 0.18, size * 0.64, COLORS.white, fade, 18)
    self:_sprite_rect(center_x - size * 0.32, center_y - size * 0.09, size * 0.64, size * 0.18, COLORS.white, fade, 18)
end

function RaycasterView:_draw_fervor(entry, floor_y, pulse, sx)
    local forward = entry.forward
    local size = math_min(100, PROJ_PLANE * 0.24 / forward)
    local center_x = entry.screen_x + sx
    local center_y = floor_y - PROJ_PLANE * 0.27 / forward
    local fade = math_max(80, 255 - forward * 13)

    self:_sprite_circle(center_x, center_y, size, COLORS.fervor, 25 + pulse * 45, 14)
    self:_sprite_rect(center_x - size * 0.23, center_y - size * 0.38, size * 0.46, size * 0.72, COLORS.fervor, fade * 0.75, 17)
    self:_sprite_rect(center_x - size * 0.15, center_y - size * 0.52, size * 0.30, size * 0.16, COLORS.gold_hot, fade, 18)
    self:_sprite_rect(center_x - size * 0.06, center_y - size * 0.25, size * 0.12, size * 0.43, COLORS.white, 210, 18)
end

function RaycasterView:_draw_effects(ui_renderer, effects, horizon, sx)
    local player = self._game:player()
    local cosine = math_cos(player.angle)
    local sine = math_sin(player.angle)

    for i = 1, EFFECT_WIDGETS do
        local widget = self._effect_widgets[i]
        local effect = effects[i]

        if effect then
            local dx = effect.x - player.x
            local dy = effect.y - player.y
            local forward = dx * cosine + dy * sine

            if forward > 0.12 then
                local side = -dx * sine + dy * cosine
                local screen_x = VIEW_W * 0.5 + side / forward * PROJ_PLANE + sx
                local floor_y = horizon + PROJ_PLANE * 0.5 / forward
                local screen_y = floor_y - effect.z * PROJ_PLANE / forward
                local column = math_floor(math_min(COLUMN_COUNT, math_max(1, screen_x / COLUMN_W + 1)))

                if forward < (self._zbuffer[column] or 999) + 0.1 then
                    local life = math_max(0, effect.life / effect.max_life)
                    local size = math_min(22, math_max(2, effect.size * PROJ_PLANE / forward))
                    local color = effect.kind == "purge" and COLORS.corruption_hot
                        or effect.kind == "sigil" and COLORS.gold_hot
                        or effect.kind == "health" and COLORS.grace
                        or COLORS.fervor

                    if draw_circle(widget, screen_x, screen_y, size, color, color_alpha(color, color[1] * life), 21) then
                        UIWidget.draw(widget, ui_renderer)
                    end
                else
                    clear_circle(widget)
                end
            else
                clear_circle(widget)
            end
        else
            clear_circle(widget)
        end
    end
end

function RaycasterView:_draw_motes(ui_renderer, theme, horizon, sx)
    local time = self._game:time()
    local player = self._game:player()

    for i = 1, MOTE_WIDGETS do
        local widget = self._mote_widgets[i]
        local depth = 0.45 + (i % 9) * 0.13
        local phase = i * 2.417 + time * (0.16 + (i % 5) * 0.035)
        local x = ((math_sin(phase + player.angle * depth) * 0.5 + 0.5) * VIEW_W + sx) % VIEW_W
        local y = (math_cos(phase * 0.71) * 0.5 + 0.5) * VIEW_H
        local size = 1.2 + (i % 4) * 0.8
        local alpha = y < horizon and 18 + i % 4 * 8 or 25 + i % 6 * 9

        draw_circle(widget, x, y, size, theme.grid, alpha, 12)
        UIWidget.draw(widget, ui_renderer)
    end
end

function RaycasterView:_draw_speed_lines(ui_renderer, theme)
    local intensity = self._game:dash_active() and 1 or math_max(0, (self._game:combo() - 8) / 20)

    if intensity <= 0 then
        for i = 1, SPEED_LINE_WIDGETS do clear_line(self._speed_line_widgets[i]) end
        return
    end

    local time = self._game:time()
    local center_x = VIEW_W * 0.5
    local center_y = HORIZON

    for i = 1, SPEED_LINE_WIDGETS do
        local widget = self._speed_line_widgets[i]
        local angle = i / SPEED_LINE_WIDGETS * math_pi * 2 + time * 0.16
        local inner = 70 + (i * 37 % 110)
        local length = 45 + (i * 29 % 105) * intensity
        local x1 = center_x + math_cos(angle) * inner
        local y1 = center_y + math_sin(angle) * inner * 0.72
        local x2 = center_x + math_cos(angle) * (inner + length)
        local y2 = center_y + math_sin(angle) * (inner + length) * 0.72

        draw_line(widget, x1, y1, x2, y2, 1.5 + intensity * 1.5, theme.portal, 35 + intensity * 105, 24)
        UIWidget.draw(widget, ui_renderer)
    end
end

function RaycasterView:_draw_gauntlets(ui_renderer, theme)
    local widgets = self._gauntlet_widgets
    local time = self._game:time()
    local dash = self._game:dash_active() and 1 or 0
    local bob = math_sin(time * 6.5) * 3
    local reach = dash * 46
    local glow = 130 + math_sin(time * 4.2) * 35

    draw_world_rect(widgets[1], 36 + reach, 407 + bob, 92, 73, COLORS.black, 225, 23)
    draw_world_rect(widgets[2], 49 + reach, 390 + bob, 72, 61, theme.wall, 245, 24)
    draw_world_rect(widgets[3], 75 + reach, 377 + bob, 37, 40, theme.wall_detail, 250, 25)
    draw_world_rect(widgets[4], 51 + reach, 402 + bob, 12, 47, COLORS.fervor, glow, 26)
    draw_world_rect(widgets[5], 91 + reach, 388 + bob, 10, 25, COLORS.gold_hot, 175, 26)
    draw_world_rect(widgets[6], 19 + reach, 443 + bob, 108, 37, theme.wall_side, 250, 24)

    draw_world_rect(widgets[7], 472 - reach, 407 - bob, 92, 73, COLORS.black, 225, 23)
    draw_world_rect(widgets[8], 479 - reach, 390 - bob, 72, 61, theme.wall, 245, 24)
    draw_world_rect(widgets[9], 488 - reach, 377 - bob, 37, 40, theme.wall_detail, 250, 25)
    draw_world_rect(widgets[10], 537 - reach, 402 - bob, 12, 47, COLORS.fervor, glow, 26)
    draw_world_rect(widgets[11], 499 - reach, 388 - bob, 10, 25, COLORS.gold_hot, 175, 26)
    draw_world_rect(widgets[12], 473 - reach, 443 - bob, 108, 37, theme.wall_side, 250, 24)

    if dash > 0 then
        draw_world_rect(widgets[13], 120, 448, 145, 12, COLORS.fervor, 80, 22)
        draw_world_rect(widgets[14], 335, 448, 145, 12, COLORS.fervor, 80, 22)
        draw_world_rect(widgets[15], 180, 463, 95, 7, COLORS.gold_hot, 75, 22)
        draw_world_rect(widgets[16], 325, 463, 95, 7, COLORS.gold_hot, 75, 22)
    else
        for i = 13, 16 do clear_rect(widgets[i]) end
    end

    draw_world_rect(widgets[17], 50 + reach, 392 + bob, 65, 3, COLORS.gold_hot, 125, 26)
    draw_world_rect(widgets[18], 480 - reach, 392 - bob, 65, 3, COLORS.gold_hot, 125, 26)

    for i = 1, GAUNTLET_WIDGETS do
        if widgets[i].style.gfx.color[1] > 0 then UIWidget.draw(widgets[i], ui_renderer) end
    end
end

function RaycasterView:destroy()
    RaycasterView.super.destroy(self)
end

return RaycasterView
