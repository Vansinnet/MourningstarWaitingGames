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

local RENDER_SIZE = 600
local TEXT_POOL = 40
local TASKBAR_Y = 572

local C = {
    desktop = { 255, 0, 128, 128 },
    desktop_dark = { 255, 0, 96, 104 },
    face = { 255, 192, 192, 192 },
    face_light = { 255, 212, 212, 212 },
    face_dark = { 255, 176, 176, 176 },
    light = { 255, 255, 255, 255 },
    shadow = { 255, 128, 128, 128 },
    black = { 255, 0, 0, 0 },
    title_a = { 255, 0, 0, 128 },
    title_b = { 255, 16, 132, 208 },
    title_text = { 255, 255, 255, 255 },
    menu_text = { 255, 0, 0, 0 },
    menu_disabled = { 255, 128, 128, 128 },
    highlight = { 255, 0, 0, 128 },
    led_bg = { 255, 0, 0, 0 },
    led_on = { 255, 255, 0, 0 },
    led_off = { 255, 70, 0, 0 },
    yellow = { 255, 255, 255, 0 },
    yellow_dark = { 255, 200, 170, 0 },
    red = { 255, 255, 0, 0 },
    flag = { 255, 235, 0, 0 },
    hover = { 255, 190, 225, 255 },
    cursor = { 255, 255, 220, 60 },
    fire = { 255, 255, 170, 40 },
    fire_hot = { 255, 255, 245, 190 },
    smoke = { 255, 60, 60, 60 },
    text_white = { 255, 255, 255, 255 },
    text_black = { 255, 0, 0, 0 },
    text_gray = { 255, 128, 128, 128 },
    hint = { 255, 225, 255, 250 },
    confetti = {
        { 255, 255, 0, 0 }, { 255, 0, 200, 0 }, { 255, 0, 90, 255 },
        { 255, 255, 220, 0 }, { 255, 255, 0, 255 }, { 255, 0, 230, 230 },
    },
}

local NUMBER_COLORS = {
    { 255, 0, 0, 255 },
    { 255, 0, 128, 0 },
    { 255, 255, 0, 0 },
    { 255, 0, 0, 128 },
    { 255, 128, 0, 0 },
    { 255, 0, 128, 128 },
    { 255, 0, 0, 0 },
    { 255, 128, 128, 128 },
}

-- Bold 6x8 glyphs in the style of the Windows 95 board digits.
local GLYPH_SOURCE = {
    ["1"] = { "..##..", ".###..", "####..", "..##..", "..##..", "..##..", "..##..", "######" },
    ["2"] = { ".####.", "##..##", "....##", "...##.", "..##..", ".##...", "##....", "######" },
    ["3"] = { ".####.", "##..##", "....##", "..###.", "....##", "....##", "##..##", ".####." },
    ["4"] = { "...##.", "..###.", ".####.", "##.##.", "######", "...##.", "...##.", "...##." },
    ["5"] = { "######", "##....", "#####.", "....##", "....##", "....##", "##..##", ".####." },
    ["6"] = { ".####.", "##....", "##....", "#####.", "##..##", "##..##", "##..##", ".####." },
    ["7"] = { "######", "....##", "...##.", "...##.", "..##..", "..##..", ".##...", ".##..." },
    ["8"] = { ".####.", "##..##", "##..##", ".####.", "##..##", "##..##", "##..##", ".####." },
    ["?"] = { ".####.", "##..##", "....##", "...##.", "..##..", "..##..", "......", "..##.." },
}

-- Row runs merged vertically when consecutive rows share the same span.
local function compile_glyph(rows)
    local runs = {}
    local open = {}

    for y = 1, #rows do
        local line = rows[y]
        local spans = {}
        local x = 1
        while x <= #line do
            if line:sub(x, x) == "#" then
                local s = x
                while x <= #line and line:sub(x, x) == "#" do x = x + 1 end
                spans[#spans + 1] = { s - 1, x - s }
            else
                x = x + 1
            end
        end

        local next_open = {}
        for i = 1, #spans do
            local key = spans[i][1] * 100 + spans[i][2]
            local run = open[key]
            if run then
                run[4] = run[4] + 1
            else
                run = { spans[i][1], y - 1, spans[i][2], 1 }
                runs[#runs + 1] = run
            end
            next_open[key] = run
        end
        open = next_open
    end

    return runs
end

local GLYPHS = {}
for key, rows in pairs(GLYPH_SOURCE) do
    GLYPHS[key] = compile_glyph(rows)
end

-- Seven-segment masks: a, b, c, d, e, f, g.
local SEGMENTS = {
    ["0"] = { 1, 1, 1, 1, 1, 1, 0 }, ["1"] = { 0, 1, 1, 0, 0, 0, 0 }, ["2"] = { 1, 1, 0, 1, 1, 0, 1 },
    ["3"] = { 1, 1, 1, 1, 0, 0, 1 }, ["4"] = { 0, 1, 1, 0, 0, 1, 1 }, ["5"] = { 1, 0, 1, 1, 0, 1, 1 },
    ["6"] = { 1, 0, 1, 1, 1, 1, 1 }, ["7"] = { 1, 1, 1, 0, 0, 0, 0 }, ["8"] = { 1, 1, 1, 1, 1, 1, 1 },
    ["9"] = { 1, 1, 1, 1, 0, 1, 1 }, ["-"] = { 0, 0, 0, 0, 0, 0, 1 },
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
}

local widget_definitions = {
    backdrop = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 255, 0, 0, 0 } } },
    }, "scanner_base", nil, { RENDER_SIZE, RENDER_SIZE }),
}

for i = 1, TEXT_POOL do
    widget_definitions["ms_text_" .. i] = UIWidget.create_definition({
        {
            pass_type = "text", style_id = "text", value = "", value_id = "text",
            style = {
                font_size = 13, font_type = "machine_medium",
                text_horizontal_alignment = "left", text_vertical_alignment = "center",
                text_color = { 255, 0, 0, 0 }, offset = { 0, 0, 6 }, size = { 100, 20 },
            },
        },
    }, "scanner_base", nil, { RENDER_SIZE, RENDER_SIZE })
end

AuspexFrame.add(widget_definitions, {
    render_size = RENDER_SIZE,
    outline_size = { 620, 620 },
    backdrop_alpha = 250,
    alpha = 150,
})

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }

local MinesweeperView = class("MinesweeperView", "BaseView")

local seg_points = {}
local pressed_cells = {}

function MinesweeperView:init(settings, context)
    MinesweeperView.super.init(self, definitions, settings, context)

    self._game = context.game
    -- A real mouse pointer, like the original.
    self._no_cursor = false
    self._canvas = Gfx.Canvas.new(RENDER_SIZE, RENDER_SIZE, 14000)
    -- Every 0.1 of a layer below becomes a whole Gui layer, so shapes and text stack reliably.
    self._canvas:set_layer_scale(10)
    self._particles = Gfx.Particles.new(420)
    self._shaker = Gfx.Shaker.new()
    self._time = 0
    self._reveal_at = {}
    self._flag_at = {}
    self._mine_at = {}
    self._explode_at = nil
    self._win_at = nil
    self._record_at = nil
    self._blink_at = 3
    self._text_used = 0
    self._text_dx = 0
    self._text_dy = 0
    self._pressed_lookup = {}
    self._confetti = {}

    -- Widgets are created after the view package loads, so text widgets are looked up lazily.
    self._texts = {}
end

function MinesweeperView:dialogue_system() return nil end
function MinesweeperView:is_using_input() return false end

function MinesweeperView:update(dt, t, input_service)
    if self._game then self._game:update(dt) end
    return MinesweeperView.super.update(self, dt, t, input_service)
end

-- Text pool -------------------------------------------------------------------

function MinesweeperView:_text_widget(index)
    local widget = self._texts[index]
    if not widget then
        widget = self._widgets_by_name and self._widgets_by_name["ms_text_" .. index]
        self._texts[index] = widget
    end
    return widget
end

function MinesweeperView:_reset_texts()
    for i = 1, self._text_used do
        local widget = self:_text_widget(i)
        if widget then widget.content.text = "" end
    end
    self._text_used = 0
end

function MinesweeperView:_text(value, x, y, w, h, size, color, halign, z, font)
    local index = self._text_used + 1
    if index > TEXT_POOL then return end
    local widget = self:_text_widget(index)
    if not widget then return end

    self._text_used = index
    local style = widget.style.text
    widget.content.text = value
    style.font_size = size or 13
    style.font_type = font or "machine_medium"
    style.text_horizontal_alignment = halign or "left"
    style.text_vertical_alignment = "center"
    style.offset[1] = x + self._text_dx
    style.offset[2] = y + self._text_dy
    style.offset[3] = (z or 6) * 10
    style.size[1] = w
    style.size[2] = h
    local tc = style.text_color
    tc[1], tc[2], tc[3], tc[4] = color[1], color[2], color[3], color[4]
end

-- Input -------------------------------------------------------------------------

local function input_value(input_service, action)
    if not input_service or not input_service.get then return false end
    local ok, value = pcall(input_service.get, input_service, action)
    if not ok then return false end
    return value == true or (type(value) == "number" and value > 0)
end

function MinesweeperView:_process_pointer(input_service, ui_renderer, base)
    if not input_service or not input_service.get then return end

    local ok, cursor = pcall(input_service.get, input_service, "cursor")
    if not ok or not cursor then return end

    local inverse = ui_renderer.inverse_scale or 1
    local x = cursor[1] * inverse - base[1]
    local y = cursor[2] * inverse - base[2]

    local input = self._pointer_state or {}
    self._pointer_state = input
    input.left = input_value(input_service, "left_hold")
    input.right = input_value(input_service, "right_hold")
    input.middle = input_value(input_service, "middle_hold")
    input.left_pressed = input_value(input_service, "left_pressed")
    input.right_pressed = input_value(input_service, "right_pressed")
    input.middle_pressed = input_value(input_service, "middle_pressed")
    input.left_released = input_value(input_service, "left_released")
    input.right_released = input_value(input_service, "right_released")
    input.middle_released = input_value(input_service, "middle_released")

    self._game:pointer_input(x, y, input)
end

-- Events ------------------------------------------------------------------------

function MinesweeperView:_handle_events()
    local game = self._game
    local now = self._time
    local L = game:layout()
    local cell = L.cell
    local cols = game:cols()

    game:drain_events(function(kind, index, value)
        local cx, cy
        if index then
            local i = index - 1
            cx = L.board.x + (i % cols + 0.5) * cell
            cy = L.board.y + (math_floor(i / cols) + 0.5) * cell
        end

        if kind == "new" then
            self._reveal_at = {}
            self._flag_at = {}
            self._mine_at = {}
            self._explode_at = nil
            self._win_at = nil
            self._record_at = nil
            self._particles:clear()
            self._confetti = {}
        elseif kind == "reveal" then
            self._reveal_at[index] = now + (value or 0) * 0.022
        elseif kind == "flag" then
            if value then
                self._flag_at[index] = now
                self._particles:burst(cx, cy, 6, 30, 90, 0.2, 0.4, 1.4, C.flag, "spark", 5)
            else
                self._flag_at[index] = nil
            end
        elseif kind == "explode" then
            self._explode_at = now
            self._explode_index = index
            local particles = self._particles
            particles:flash(cx, cy, cell * 5, 0.5, C.fire_hot)
            particles:shockwave(cx, cy, cell * 8, 0.7, C.fire, 5)
            particles:shockwave(cx, cy, cell * 4, 0.45, C.light, 2)
            particles:burst(cx, cy, 60, 120, 520, 0.4, 1.1, 2.4, C.fire, "spark", 2)
            particles:burst(cx, cy, 22, 30, 260, 0.6, 1.4, cell * 0.35, C.face, "shard", 1.2, 420)
            particles:burst(cx, cy, 16, 10, 70, 0.9, 1.8, cell * 0.8, C.smoke, "smoke", 1, -40)
            self._shaker:add(1)
        elseif kind == "mine" then
            self._mine_at[index] = now + 0.35 + (value or 0) * 0.06
        elseif kind == "win" then
            self._win_at = now
            self:_spawn_confetti(L)
            self._particles:shockwave(L.face.x + 17, L.face.y + 17, 90, 0.6, C.yellow, 3)
        elseif kind == "record" then
            self._record_at = now
        end
    end)
end

function MinesweeperView:_spawn_confetti(L)
    local confetti = self._confetti
    for i = 1, 110 do
        confetti[i] = {
            x = L.window.x + math_random() * L.window.w,
            y = L.window.y - math_random() * 200,
            vx = (math_random() - 0.5) * 60,
            vy = 60 + math_random() * 120,
            spin = (math_random() - 0.5) * 10,
            angle = math_random() * math_pi * 2,
            size = 3 + math_random() * 4,
            color = C.confetti[(i % #C.confetti) + 1],
            phase = math_random() * 6,
        }
    end
end

-- Primitives ---------------------------------------------------------------------

-- Windows 95 3D edge: raised when inverted is false.
local function bevel(canvas, x, y, w, h, t, layer, inverted, outer)
    local tl = inverted and C.shadow or C.light
    local br = inverted and C.light or C.shadow

    if outer then
        local otl = inverted and C.black or C.face
        local obr = inverted and C.face or C.black
        canvas:rect(x, y, w, 1, layer, otl)
        canvas:rect(x, y, 1, h, layer, otl)
        canvas:rect(x, y + h - 1, w, 1, layer, obr)
        canvas:rect(x + w - 1, y, 1, h, layer, obr)
        x, y, w, h = x + 1, y + 1, w - 2, h - 2
    end

    canvas:rect(x, y, w, t, layer + 0.001, tl)
    canvas:rect(x, y, t, h, layer + 0.001, tl)
    canvas:rect(x, y + h - t, w, t, layer + 0.002, br)
    canvas:rect(x + w - t, y, t, h, layer + 0.002, br)
end

local function panel(canvas, x, y, w, h, layer, inverted)
    canvas:vgradient(x, y, w, h, layer, C.face_light, C.face_dark, 255, 255, 4)
    bevel(canvas, x, y, w, h, 1, layer + 0.01, inverted, true)
end

local function glyph(canvas, key, x, y, px, layer, color, alpha)
    local runs = GLYPHS[key]
    if not runs then return end
    for i = 1, #runs do
        local r = runs[i]
        canvas:rect(x + r[1] * px, y + r[2] * px, r[3] * px, r[4] * px, layer, color, alpha)
    end
end

local function hex_segment(canvas, x0, y0, x1, y1, t, layer, color, alpha)
    local p = seg_points
    local h = t * 0.5
    if y0 == y1 then
        p[1], p[2] = x0, y0
        p[3], p[4] = x0 + h, y0 - h
        p[5], p[6] = x1 - h, y0 - h
        p[7], p[8] = x1, y0
        p[9], p[10] = x1 - h, y0 + h
        p[11], p[12] = x0 + h, y0 + h
    else
        p[1], p[2] = x0, y0
        p[3], p[4] = x0 + h, y0 + h
        p[5], p[6] = x0 + h, y1 - h
        p[7], p[8] = x0, y1
        p[9], p[10] = x0 - h, y1 - h
        p[11], p[12] = x0 - h, y0 + h
    end
    canvas:poly(p, 6, layer, color, alpha)
end

local function seven_segment(canvas, ch, x, y, w, h, layer, glow)
    local mask = SEGMENTS[ch] or SEGMENTS["0"]
    local t = 3
    local g = 1
    local left, right = x + t * 0.5, x + w - t * 0.5
    local top, mid, bottom = y + t * 0.5, y + h * 0.5, y + h - t * 0.5
    local segs = {
        { left + g, top, right - g, top },
        { right, top + g, right, mid - g },
        { right, mid + g, right, bottom - g },
        { left + g, bottom, right - g, bottom },
        { left, mid + g, left, bottom - g },
        { left, top + g, left, mid - g },
        { left + g, mid, right - g, mid },
    }

    for i = 1, 7 do
        local s = segs[i]
        if mask[i] == 1 then
            if glow > 0 then
                canvas:line(s[1], s[2], s[3], s[4], t * 2.6, layer, C.led_on, 50 * glow)
            end
            hex_segment(canvas, s[1], s[2], s[3], s[4], t, layer + 0.01, C.led_on, 255)
        else
            hex_segment(canvas, s[1], s[2], s[3], s[4], t, layer + 0.01, C.led_off, 255)
        end
    end
end

function MinesweeperView:_draw_counter(canvas, r, value, glow)
    canvas:rect(r.x, r.y, r.w, r.h, 4.2, C.led_bg)
    bevel(canvas, r.x - 1, r.y - 1, r.w + 2, r.h + 2, 1, 4.21, true)
    canvas:rect(r.x + 1, r.y + 1, r.w - 2, r.h * 0.45, 4.4, C.light, 10)

    local text
    if value < 0 then
        text = "-" .. string.format("%02d", math_min(99, -value))
    else
        text = string.format("%03d", math_min(999, value))
    end

    local dw = (r.w - 6) / 3
    for i = 1, 3 do
        seven_segment(canvas, text:sub(i, i), r.x + 3 + (i - 1) * dw + 1.5, r.y + 3, dw - 3, r.h - 6, 4.3, glow)
    end
end

local function draw_mine(canvas, cx, cy, s, layer, glow)
    local r = s * 0.28
    local w = math_max(1.2, s * 0.08)
    if glow and glow > 0 then
        canvas:glow(cx, cy, s * 0.9, layer, C.red, 120 * glow, 3)
    end
    canvas:rect(cx - s * 0.4, cy - w * 0.5, s * 0.8, w, layer + 0.1, C.black)
    canvas:rect(cx - w * 0.5, cy - s * 0.4, w, s * 0.8, layer + 0.1, C.black)
    local d = s * 0.27
    canvas:line(cx - d, cy - d, cx + d, cy + d, w, layer + 0.2, C.black)
    canvas:line(cx - d, cy + d, cx + d, cy - d, w, layer + 0.2, C.black)
    canvas:circle(cx, cy, r, layer + 0.2, C.black, 255, 1, 0, 10)
    canvas:rect(cx - r * 0.55, cy - r * 0.55, r * 0.45, r * 0.45, layer + 0.3, C.light)
end

local function draw_flag(canvas, x, y, s, layer, wave, drop)
    local cx = x + s * 0.5
    local top = y + s * 0.18 - drop
    local pole_x = cx + s * 0.02
    local base_y = y + s * 0.76

    canvas:rect(cx - s * 0.28, base_y, s * 0.56, s * 0.08, layer, C.black)
    canvas:rect(cx - s * 0.16, base_y - s * 0.07, s * 0.32, s * 0.08, layer, C.black)
    canvas:rect(pole_x, top + s * 0.1, math_max(1, s * 0.07), base_y - top - s * 0.1, layer + 0.01, C.black)

    local tip_y = top + s * 0.21 + wave * s * 0.04
    canvas:tri(pole_x + s * 0.03, top, pole_x + s * 0.03, top + s * 0.4, cx - s * 0.36, tip_y, layer + 0.1, C.flag)
    canvas:tri(pole_x + s * 0.03, top, pole_x + s * 0.03, top + s * 0.16, cx - s * 0.2, top + s * 0.12 + wave * s * 0.02, layer + 0.11, C.flag, 180, 1, 0.35)
end

local function draw_cross(canvas, cx, cy, s, layer)
    local d = s * 0.36
    canvas:line(cx - d, cy - d, cx + d, cy + d, math_max(1.5, s * 0.1), layer, C.red)
    canvas:line(cx - d, cy + d, cx + d, cy - d, math_max(1.5, s * 0.1), layer, C.red)
end

-- Desktop, window chrome ---------------------------------------------------------

function MinesweeperView:_draw_desktop(canvas, t)
    canvas:vgradient(0, 0, RENDER_SIZE, TASKBAR_Y, 0.4, C.desktop, C.desktop_dark, 255, 255, 24)
    canvas:glow(140, 90, 260, 0.5, C.light, 16, 6)

    -- Taskbar.
    canvas:rect(0, TASKBAR_Y, RENDER_SIZE, RENDER_SIZE - TASKBAR_Y, 0.6, C.face)
    canvas:rect(0, TASKBAR_Y, RENDER_SIZE, 1, 0.61, C.face_light)
    canvas:rect(0, TASKBAR_Y + 1, RENDER_SIZE, 1, 0.61, C.light)

    panel(canvas, 3, TASKBAR_Y + 4, 58, 22, 0.62, false)
    draw_mine(canvas, 15, TASKBAR_Y + 15, 14, 0.62)
    self:_text("Start", 24, TASKBAR_Y + 4, 36, 22, 12, C.text_black, "left", 1)

    panel(canvas, 66, TASKBAR_Y + 4, 150, 22, 0.62, true)
    canvas:rect(68, TASKBAR_Y + 6, 146, 18, 0.63, C.face_light, 255)
    draw_mine(canvas, 78, TASKBAR_Y + 15, 12, 0.62)
    self:_text("Minesweeper", 88, TASKBAR_Y + 4, 120, 22, 12, C.text_black, "left", 1)

    bevel(canvas, RENDER_SIZE - 84, TASKBAR_Y + 4, 81, 22, 1, 0.62, true)
    local blink = math_floor(t * 2) % 2 == 0 and ":" or " "
    local minutes = math_floor(self._game:timer_value() / 60)
    local seconds = self._game:timer_value() % 60
    self:_text(string.format("%02d%s%02d", minutes, blink, seconds), RENDER_SIZE - 84, TASKBAR_Y + 4, 81, 22, 12, C.text_black, "center", 1)
end

function MinesweeperView:_draw_title_bar(canvas, L, t)
    local title = L.title
    canvas:hgradient(title.x, title.y, title.w, title.h, 3.1, C.title_a, C.title_b, 255, 255, 24)
    canvas:rect(title.x, title.y, title.w, title.h * 0.45, 3.11, C.light, 22)
    draw_mine(canvas, title.x + 11, title.y + title.h * 0.5, 14, 3.2)
    self:_text("Minesweeper", title.x + 22, title.y, 200, title.h, 13, C.text_white, "left", 4)

    local press = self._game:ui_press()
    local kind = self._game:hover()

    local function chrome_button(r, pressed)
        panel(canvas, r.x, r.y, r.w, r.h, 3.2, pressed)
        return pressed and 1 or 0
    end

    local off = chrome_button(L.minimize_button, false)
    canvas:rect(L.minimize_button.x + 4 + off, L.minimize_button.y + 9 + off, 7, 2, 3.25, C.black)
    off = chrome_button(L.maximize_button, false)
    local mb = L.maximize_button
    canvas:rect(mb.x + 4, mb.y + 3, 9, 1, 3.25, C.shadow)
    canvas:rect(mb.x + 4, mb.y + 3, 1, 8, 3.25, C.shadow)
    canvas:rect(mb.x + 12, mb.y + 3, 1, 8, 3.25, C.shadow)
    canvas:rect(mb.x + 4, mb.y + 10, 9, 1, 3.25, C.shadow)
    canvas:rect(mb.x + 4, mb.y + 4, 9, 1, 3.25, C.shadow)

    local close_pressed = press == "close" and kind == "close"
    off = chrome_button(L.close_button, close_pressed)
    local cb = L.close_button
    canvas:line(cb.x + 4 + off, cb.y + 3 + off, cb.x + 12 + off, cb.y + 11 + off, 1.8, 3.3, C.black)
    canvas:line(cb.x + 4 + off, cb.y + 11 + off, cb.x + 12 + off, cb.y + 3 + off, 1.8, 3.3, C.black)
end

function MinesweeperView:_draw_menu_bar(canvas, L)
    local game = self._game
    local open = game:menu()
    local mb = L.menubar
    canvas:rect(mb.x, mb.y, mb.w, mb.h, 3.1, C.face)

    local function title(r, label, id)
        local active = open == id
        if active then
            canvas:rect(r.x, r.y, r.w, r.h, 3.12, C.highlight)
        end
        local color = active and C.text_white or C.text_black
        self:_text(label, r.x, r.y, r.w, r.h, 12, color, "center", 4, "machine_medium")
        canvas:rect(r.x + r.w * 0.5 - 13, r.y + r.h - 4, 7, 1, 3.13, color)
    end

    title(L.menu_game, "Game", "game")
    title(L.menu_help, "Help", "help")
end

function MinesweeperView:_draw_client(canvas, L, t)
    local client = L.client
    local window = L.window

    canvas:soft_rect(window.x + 6, window.y + 8, window.w, window.h, 10, 2, C.black, 120, 5)
    canvas:rect(window.x, window.y, window.w, window.h, 3, C.face)
    bevel(canvas, window.x, window.y, window.w, window.h, 1, 3.01, false, true)

    canvas:vgradient(client.x, client.y, client.w, client.h, 3.05, C.face_light, C.face_dark, 255, 255, 12)
    bevel(canvas, client.x, client.y, client.w, client.h, 3, 3.06, false)

    local header = L.header
    bevel(canvas, header.x, header.y, header.w, header.h, 2, 3.07, true)
    bevel(canvas, L.board_frame.x, L.board_frame.y, L.board_frame.w, L.board_frame.h, 3, 3.07, true)

    local game = self._game
    local glow = 1
    if self._win_at then
        glow = 1 + math_max(0, math_sin((t - self._win_at) * 12)) * 1.5 * math_max(0, 1 - (t - self._win_at) * 0.5)
    end
    self:_draw_counter(canvas, L.mine_counter, game:mines_left(), glow)
    self:_draw_counter(canvas, L.timer, game:timer_value(), glow)
    self:_draw_face(canvas, L.face, t)
end

function MinesweeperView:_draw_face(canvas, r, t)
    local face = self._game:face()
    local pressed = face == "pressed"
    local off = pressed and 1 or 0

    canvas:rect(r.x, r.y, r.w, r.h, 4.2, C.face)
    if pressed then
        canvas:rect(r.x, r.y, r.w, 1, 4.21, C.shadow)
        canvas:rect(r.x, r.y, 1, r.h, 4.21, C.shadow)
    else
        bevel(canvas, r.x, r.y, r.w, r.h, 2, 4.21, false, true)
    end

    local cx, cy = r.x + r.w * 0.5 + off, r.y + r.h * 0.5 + off
    local rad = 11.5

    if face == "cool" and self._win_at then
        canvas:glow(cx, cy, 26, 4.3, C.yellow, 90 + math_sin(t * 4) * 30, 4)
    end

    canvas:circle(cx, cy, rad + 1, 4.4, C.black, 255, 1, 0, 24)
    canvas:circle(cx, cy, rad, 4.41, C.yellow_dark, 255, 1, 0, 24)
    canvas:circle(cx - 1, cy - 1, rad - 1.5, 4.42, C.yellow, 255, 1, 0, 24)
    canvas:circle(cx - 4, cy - 5, 3.5, 4.43, C.light, 120, 1, 0, 10)

    if face == "dead" then
        for side = -1, 1, 2 do
            local ex = cx + side * 4
            canvas:line(ex - 2, cy - 5, ex + 2, cy - 1, 1.4, 4.5, C.black)
            canvas:line(ex - 2, cy - 1, ex + 2, cy - 5, 1.4, 4.5, C.black)
        end
        canvas:ring(cx, cy + 7, 5, 1.5, 4.5, C.black, 255, 8, math_pi * 1.15, math_pi * 1.85)
    elseif face == "cool" then
        canvas:rect(cx - 9, cy - 5, 18, 1.5, 4.5, C.black)
        for side = -1, 1, 2 do
            canvas:ellipse(cx + side * 4.5, cy - 3, 4, 3, 4.5, C.black, 255, 1, 0, 10)
        end
        local sweep = ((t - (self._win_at or t)) * 0.8) % 2
        if sweep < 1 then
            canvas:line(cx - 8 + sweep * 16, cy - 5, cx - 10 + sweep * 16, cy - 1, 1.2, 4.6, C.light, 220)
        end
        canvas:line(cx - 12, cy - 4, cx - 9, cy - 5, 1, 4.5, C.black)
        canvas:line(cx + 12, cy - 4, cx + 9, cy - 5, 1, 4.5, C.black)
        canvas:ring(cx, cy + 1, 6, 1.5, 4.5, C.black, 255, 10, math_pi * 0.2, math_pi * 0.8)
    elseif face == "surprised" then
        for side = -1, 1, 2 do
            canvas:circle(cx + side * 4, cy - 3, 1.6, 4.5, C.black, 255, 1, 0, 8)
        end
        canvas:ring(cx, cy + 5, 2.6, 1.4, 4.5, C.black, 255, 10)
    else
        local blink = (t % 4.3) < 0.12
        for side = -1, 1, 2 do
            if blink then
                canvas:rect(cx + side * 4 - 1.5, cy - 3.5, 3, 1, 4.5, C.black)
            else
                canvas:circle(cx + side * 4, cy - 3.5, 1.5, 4.5, C.black, 255, 1, 0, 8)
            end
        end
        canvas:ring(cx, cy + 1, 6, 1.5, 4.5, C.black, 255, 10, math_pi * 0.2, math_pi * 0.8)
    end
end

-- Board -----------------------------------------------------------------------------

function MinesweeperView:_draw_board(canvas, L, t)
    local game = self._game
    local board = L.board
    local s = L.cell
    local cols, rows = game:cols(), game:rows()
    local COVERED, REVEALED, FLAGGED, QUESTION = game:state_codes()
    local status = game:status()
    local exploded = game:exploded()
    local now = self._time
    local px = s * 0.08
    local gw, gh = 6 * px, 8 * px
    local bev = math_max(2, math_floor(s * 0.1 + 0.5))

    -- Revealed floor and its grid.
    canvas:rect(board.x, board.y, board.w, board.h, 4, C.face)
    for c = 0, cols do
        canvas:rect(board.x + c * s - 0.5, board.y, 1, board.h, 4.02, C.shadow)
    end
    for r = 0, rows do
        canvas:rect(board.x, board.y + r * s - 0.5, board.w, 1, 4.02, C.shadow)
    end

    local lookup = self._pressed_lookup
    for k in pairs(lookup) do lookup[k] = nil end
    local pressed_count = game:pressed_cells(pressed_cells)
    for i = 1, pressed_count do lookup[pressed_cells[i]] = true end

    local hover_kind, hover_col, hover_row = game:hover()
    local keys = game:cursor_mode() == "keys"
    local cursor_col, cursor_row = game:cursor_cell()

    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local index = row * cols + col + 1
            local state, mine, adjacent = game:cell(index)
            local x = board.x + col * s
            local y = board.y + row * s
            local cx, cy = x + s * 0.5, y + s * 0.5

            local reveal_time = self._reveal_at[index]
            local covered_look = state ~= REVEALED
            local pop = nil

            if state == REVEALED and reveal_time then
                local k = (now - reveal_time) / 0.16
                if k < 1 then
                    covered_look = true
                    pop = math_max(0, k)
                else
                    self._reveal_at[index] = nil
                end
            end

            if state == REVEALED and not covered_look then
                if adjacent > 0 then
                    local color = NUMBER_COLORS[adjacent]
                    canvas:rect(x + 1.5, y + 1.5, s - 2, s - 2, 4.05, color, 12)
                    glyph(canvas, tostring(adjacent), cx - gw * 0.5, cy - gh * 0.5, px, 4.1, color)
                end
            elseif lookup[index] then
                -- Held down: looks opened but blank.
                if state == QUESTION then
                    glyph(canvas, "?", cx - gw * 0.5, cy - gh * 0.5, px, 4.1, C.black)
                end
            else
                local mine_time = self._mine_at[index]
                local show_mine = status == "lost" and mine and state ~= FLAGGED and (not mine_time or now >= mine_time)

                if index == exploded then
                    local pulse = 0.75 + math_sin(t * 8) * 0.25
                    canvas:rect(x + 0.5, y + 0.5, s - 1, s - 1, 4.05, C.red, 255, pulse)
                    draw_mine(canvas, cx, cy, s, 4.1, 1)
                elseif show_mine then
                    draw_mine(canvas, cx, cy, s, 4.1, mine_time and math_max(0, 1 - (now - mine_time) * 2) or 0)
                else
                    local scale = 1
                    local alpha = 255
                    if pop then
                        scale = 1 - pop * pop * 0.55
                        alpha = 255 * (1 - pop)
                    end

                    local inset = (1 - scale) * s * 0.5
                    local tx, ty, ts = x + inset, y + inset - (pop and pop * s * 0.15 or 0), s - inset * 2
                    local hovered = not keys and hover_kind == "cell" and hover_col == col and hover_row == row and not game:is_finished()

                    if pop and state == REVEALED and adjacent > 0 then
                        glyph(canvas, tostring(adjacent), cx - gw * 0.5, cy - gh * 0.5, px, 4.1, NUMBER_COLORS[adjacent], 255 * pop)
                    end

                    -- Raised square in three rects: light edge, dark edge, face.
                    canvas:rect(tx, ty, ts, ts, 4.2, C.light, alpha)
                    canvas:rect(tx + bev, ty + bev, ts - bev, ts - bev, 4.21, C.shadow, alpha)
                    canvas:rect(tx + bev, ty + bev, ts - bev * 2, ts - bev * 2, 4.22, hovered and C.hover or C.face, alpha, hovered and 0.92 or 1)

                    if state == FLAGGED and not pop then
                        local wrong = status == "lost" and not mine
                        local drop = 0
                        local placed = self._flag_at[index]
                        if placed then
                            local k = (now - placed) / 0.25
                            if k < 1 then
                                drop = (1 - k) * (1 - k) * s * 0.5
                            else
                                self._flag_at[index] = nil
                            end
                        end
                        if wrong then
                            draw_mine(canvas, cx, cy, s * 0.9, 4.3)
                            draw_cross(canvas, cx, cy, s, 4.7)
                        else
                            draw_flag(canvas, x, y, s, 4.3, math_sin(t * 5 + col + row * 0.7), drop)
                        end
                    elseif state == QUESTION and not pop then
                        glyph(canvas, "?", cx - gw * 0.5, cy - gh * 0.5, px, 4.3, C.black)
                    end
                end
            end
        end
    end

    -- Keyboard / controller cursor.
    if keys and not game:is_finished() and not game:menu() and not game:dialog() then
        local x = board.x + cursor_col * s
        local y = board.y + cursor_row * s
        local pulse = (math_sin(t * 6) + 1) * 0.5
        canvas:soft_rect(x, y, s, s, 5, 4.5, C.cursor, 70 + pulse * 60, 3)
        for k = 0, math_floor(s / 3) do
            canvas:rect(x + k * 3, y + 1, 1.5, 1, 4.55, C.black)
            canvas:rect(x + k * 3, y + s - 2, 1.5, 1, 4.55, C.black)
            canvas:rect(x + 1, y + k * 3, 1, 1.5, 4.55, C.black)
            canvas:rect(x + s - 2, y + k * 3, 1, 1.5, 4.55, C.black)
        end
    end

    -- Sheen sweeping over the board on a win.
    if self._win_at then
        local k = (now - self._win_at) / 1.2
        if k < 1 then
            local sx = board.x - 60 + k * (board.w + 120)
            canvas:quad(sx, board.y, sx + 40, board.y, sx + 10, board.y + board.h, sx - 30, board.y + board.h, 4.8, C.light, 90 * (1 - k))
        end
    end
end

-- Puffs when the other mines appear after a loss.
function MinesweeperView:_update_mine_puffs(L)
    local now = self._time
    local cols = self._game:cols()
    for index, at in pairs(self._mine_at) do
        if now >= at then
            local i = index - 1
            local cx = L.board.x + (i % cols + 0.5) * L.cell
            local cy = L.board.y + (math_floor(i / cols) + 0.5) * L.cell
            self._particles:burst(cx, cy, 5, 20, 110, 0.25, 0.5, 1.6, C.fire, "spark", 3)
            self._particles:emit(cx, cy, 0, -8, 0.8, L.cell * 0.45, C.smoke, "smoke", 1)
            self._mine_at[index] = nil
            self._shaker:add(0.04)
        end
    end
end

function MinesweeperView:_draw_confetti(canvas, dt)
    local confetti = self._confetti
    for i = #confetti, 1, -1 do
        local c = confetti[i]
        c.vy = c.vy + 30 * dt
        c.x = c.x + (c.vx + math_sin(self._time * 3 + c.phase) * 30) * dt
        c.y = c.y + c.vy * dt
        c.angle = c.angle + c.spin * dt
        if c.y > TASKBAR_Y + 10 then
            table.remove(confetti, i)
        else
            local w = c.size * math_abs(math_cos(c.angle))
            canvas:rect(c.x - w * 0.5, c.y - c.size * 0.3, math_max(0.8, w), c.size * 0.6, 7.5, c.color, 235)
        end
    end
end

-- Menus and dialogs ---------------------------------------------------------------

function MinesweeperView:_draw_checkmark(canvas, x, y, layer, color)
    canvas:line(x, y + 3, x + 2.5, y + 6, 1.8, layer, color)
    canvas:line(x + 2.5, y + 6, x + 7, y, 1.8, layer, color)
end

function MinesweeperView:_draw_menu(canvas, L)
    local game = self._game
    local list = L.menu_items
    if not list then return end

    local box = list.box
    canvas:rect(box.x + 3, box.y + 3, box.w, box.h, 7.9, C.black, 90)
    panel(canvas, box.x, box.y, box.w, box.h, 8, false)

    local hover = game:menu_hover()
    for i = 1, #list do
        local entry = list[i]
        local item = entry.item
        local r = entry.rect
        if item.separator then
            canvas:rect(r.x + 2, r.y + r.h * 0.5 - 1, r.w - 4, 1, 8.1, C.shadow)
            canvas:rect(r.x + 2, r.y + r.h * 0.5, r.w - 4, 1, 8.1, C.light)
        else
            local active = hover == i
            if active then
                canvas:rect(r.x, r.y, r.w, r.h, 8.1, C.highlight)
            end
            local color = active and C.text_white or C.text_black

            local checked = false
            if item.check == "level" then
                checked = game:level() == item.id
            elseif item.check == "marks" then
                checked = game:marks_enabled()
            end
            if checked then
                self:_draw_checkmark(canvas, r.x + 7, r.y + r.h * 0.5 - 4, 8.2, color)
            end

            self:_text(item.label, r.x + 22, r.y, r.w - 60, r.h, 12, color, "left", 8.5, "machine_medium")
            if item.key then
                self:_text(item.key, r.x + r.w - 48, r.y, 40, r.h, 12, color, "right", 8.5, "machine_medium")
            end
        end
    end
end

function MinesweeperView:_draw_button(canvas, r, label, focused, pressed, is_default)
    local off = pressed and 1 or 0
    if is_default then
        canvas:rect(r.x - 1, r.y - 1, r.w + 2, r.h + 2, 9.2, C.black)
    end
    panel(canvas, r.x, r.y, r.w, r.h, 9.21, pressed)
    if focused then
        for k = 0, math_floor((r.w - 10) / 2) do
            canvas:rect(r.x + 5 + k * 2, r.y + 4, 1, 1, 9.25, C.black)
            canvas:rect(r.x + 5 + k * 2, r.y + r.h - 5, 1, 1, 9.25, C.black)
        end
    end
    self:_text(label, r.x + off, r.y + off, r.w, r.h, 12, C.text_black, "center", 10.5, "machine_medium")
end

function MinesweeperView:_draw_dialog(canvas, L, t)
    local game = self._game
    local D = L.dialog
    local dialog = game:dialog()
    if not D or not dialog then return end

    local box = D.box
    canvas:rect(0, 0, RENDER_SIZE, TASKBAR_Y, 8.8, C.black, 40)
    canvas:soft_rect(box.x + 5, box.y + 7, box.w, box.h, 8, 8.9, C.black, 120, 4)
    canvas:rect(box.x, box.y, box.w, box.h, 9, C.face)
    bevel(canvas, box.x, box.y, box.w, box.h, 1, 9.01, false, true)
    canvas:hgradient(D.title.x, D.title.y, D.title.w, D.title.h, 9.1, C.title_a, C.title_b, 255, 255, 16)

    local titles = { custom = "Custom Field", best = "Fastest Mine Sweepers", record = "Minesweeper", about = "About Minesweeper", how_to = "How to Play" }
    self:_text(titles[dialog.kind] or "Minesweeper", D.title.x + 6, D.title.y, D.title.w - 30, D.title.h, 12, C.text_white, "left", 10.5)

    panel(canvas, D.close_button.x, D.close_button.y, D.close_button.w, D.close_button.h, 9.2, false)
    local cb = D.close_button
    canvas:line(cb.x + 4, cb.y + 3, cb.x + 11, cb.y + 10, 1.6, 9.3, C.black)
    canvas:line(cb.x + 4, cb.y + 10, cb.x + 11, cb.y + 3, 1.6, 9.3, C.black)

    local press = game:ui_press()
    local hover_kind, hover_a = game:hover()
    local body_x, body_y = box.x + 16, box.y + 32

    if dialog.kind == "custom" then
        local values = dialog.values
        for i = 1, #D.fields do
            local f = D.fields[i]
            local focused = dialog.focus == i
            self:_text(f.label, f.label_rect.x, f.label_rect.y, f.label_rect.w, f.label_rect.h, 12, C.text_black, "left", 10.5, "machine_medium")
            canvas:rect(f.box.x, f.box.y, f.box.w, f.box.h, 9.2, C.light)
            bevel(canvas, f.box.x, f.box.y, f.box.w, f.box.h, 1, 9.21, true, true)
            if focused then
                canvas:rect(f.box.x + 3, f.box.y + 3, f.box.w - 6, f.box.h - 6, 9.22, C.highlight)
            end
            self:_text(tostring(values[i]), f.box.x + 4, f.box.y, f.box.w - 8, f.box.h, 12, focused and C.text_white or C.text_black, "left", 10.5, "machine_medium")
            panel(canvas, f.up.x, f.up.y, f.up.w, f.up.h, 9.2, hover_kind == "field_up" and hover_a == i and self._pointer_state and self._pointer_state.left)
            panel(canvas, f.down.x, f.down.y, f.down.w, f.down.h, 9.2, hover_kind == "field_down" and hover_a == i and self._pointer_state and self._pointer_state.left)
            canvas:tri(f.up.x + 5, f.up.y + 8.5, f.up.x + 13, f.up.y + 8.5, f.up.x + 9, f.up.y + 4, 9.3, C.black)
            canvas:tri(f.down.x + 5, f.down.y + 3.5, f.down.x + 13, f.down.y + 3.5, f.down.x + 9, f.down.y + 8, 9.3, C.black)
        end
    elseif dialog.kind == "best" then
        local levels = game:levels()
        for i = 1, #levels do
            local level = levels[i]
            local best = game:best_time(level)
            local y = body_y + (i - 1) * 26
            self:_text(game:level_name(level) .. ":", body_x, y, 110, 22, 12, C.text_black, "left", 10.5, "machine_medium")
            self:_text(best and (best .. " seconds") or "999 seconds", body_x + 110, y, 100, 22, 12, C.text_black, "left", 10.5, "machine_medium")
            self:_text(best and "You" or "Anonymous", body_x + 205, y, 80, 22, 12, C.text_black, "left", 10.5, "machine_medium")
        end
    elseif dialog.kind == "record" then
        local level = game:level_name(game:record_level())
        draw_mine(canvas, body_x + 14, body_y + 22, 26, 9.3, 0.6 + math_sin(t * 4) * 0.3)
        self:_text("You have the fastest time", body_x + 40, body_y + 2, 220, 22, 12, C.text_black, "left", 10.5, "machine_medium")
        self:_text("for " .. string.lower(level) .. " level: " .. game:timer_value() .. " seconds.", body_x + 40, body_y + 22, 230, 22, 12, C.text_black, "left", 10.5, "machine_medium")
        self:_text("The auspex salutes you.", body_x + 40, body_y + 46, 220, 22, 12, C.text_black, "left", 10.5, "machine_medium")
    elseif dialog.kind == "about" then
        draw_mine(canvas, body_x + 18, body_y + 26, 32, 9.3)
        self:_text("Minesweeper", body_x + 46, body_y + 4, 240, 22, 14, C.text_black, "left", 10.5)
        self:_text("Mourningstar Waiting Games edition", body_x + 46, body_y + 26, 250, 22, 12, C.text_black, "left", 10.5, "machine_medium")
        self:_text("A tribute to the Windows 95 classic.", body_x + 46, body_y + 46, 250, 22, 12, C.text_black, "left", 10.5, "machine_medium")
        self:_text("Rendered on an Imperial auspex.", body_x + 46, body_y + 66, 250, 22, 12, C.text_black, "left", 10.5, "machine_medium")
    elseif dialog.kind == "how_to" then
        local lines = {
            "Open every square that is not a mine.",
            "Numbers show how many mines touch a square.",
            "Left click: open.   Right click: flag / ?",
            "Both buttons or middle click on a number:",
            "   open its neighbours when the flags match.",
            "Keys: WASD/Arrows move, Space open, F/E flag.",
            "1/2/3 level, 4 marks, R new game, Tab menu.",
            "Click the face to start a new game.",
        }
        for i = 1, #lines do
            self:_text(lines[i], body_x, body_y + (i - 1) * 21, box.w - 32, 20, 12, C.text_black, "left", 10.5, "machine_medium")
        end
    end

    for i = 1, #D.buttons do
        local b = D.buttons[i]
        local pressed = press == ("button" .. i) and hover_kind == "dialog_button" and hover_a == i
        local focused
        if dialog.kind == "custom" then
            focused = (dialog.focus == 4 and b.id == "ok") or (dialog.focus == 5 and b.id == "cancel")
        elseif dialog.kind == "best" then
            focused = (dialog.focus == 1 and b.id == "reset") or (dialog.focus == 2 and b.id == "ok")
        else
            focused = true
        end
        self:_draw_button(canvas, b.rect, b.label, focused, pressed, b.id == "ok")
    end
end

-- Main draw ---------------------------------------------------------------------------

function MinesweeperView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local game = self._game
    self:_reset_texts()

    if not game then
        MinesweeperView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
        return
    end

    dt = math_min(dt or 0.016, 0.05)
    self._time = self._time + dt

    local base = self:_scenegraph_world_position("scanner_base")
    self:_process_pointer(input_service, ui_renderer, base)
    self:_handle_events()

    local L = game:layout()
    self:_update_mine_puffs(L)
    self._particles:update(dt)
    self._shaker:update(dt, 6)

    local canvas = self._canvas
    if canvas:begin(ui_renderer, base) then
        local time = self._time

        self:_draw_desktop(canvas, time)

        canvas:set_shake(self._shaker.x, self._shaker.y)
        self._text_dx, self._text_dy = self._shaker.x, self._shaker.y
        self:_draw_client(canvas, L, time)
        self:_draw_title_bar(canvas, L, time)
        self:_draw_menu_bar(canvas, L)
        canvas:set_clip(L.board.x, L.board.y, L.board.x + L.board.w, L.board.y + L.board.h)
        self:_draw_board(canvas, L, time)
        canvas:reset_clip()
        self._particles:draw(canvas, 7)
        canvas:set_shake(0, 0)
        self._text_dx, self._text_dy = 0, 0

        self:_draw_confetti(canvas, dt)
        self:_draw_menu(canvas, L)
        self:_draw_dialog(canvas, L, time)

        self:_text("LMB open   RMB flag   Both / MMB chord   WASD + Space / F   1-3 level   R new   Tab menu",
            8, TASKBAR_Y - 26, RENDER_SIZE - 16, 20, 11, C.hint, "center", 1)

        canvas:crt(0, 0, RENDER_SIZE, RENDER_SIZE, time, 11.5, {
            tint = C.hint, scan_alpha = 12, sweep_alpha = 10, vignette_depth = 60, vignette_alpha = 110,
            noise_count = 6, noise_alpha = 25, flicker = false,
        })
        canvas:finish()
    end

    MinesweeperView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

function MinesweeperView:destroy()
    self._canvas = nil
    self._particles = nil
    MinesweeperView.super.destroy(self)
end

return MinesweeperView
