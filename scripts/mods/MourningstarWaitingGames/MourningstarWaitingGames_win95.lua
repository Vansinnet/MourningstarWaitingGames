-- Windows 95 desktop look shared by the desktop-app games (Solitaire, Hearts, SkiFree):
-- pixel sprites, window chrome, menus, dialogs, a text-widget pool, and the Shell that
-- owns menu and dialog interaction so each game only handles its own client area.
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_sin = math.sin

local Win95 = {}

local CANVAS = 600
local TASKBAR_Y = 572
local FRAME = 4
local TITLE_H = 22
local MENU_H = 20
local STATUS_H = 20
local MENU_ITEM_H = 20
local MENU_SEP_H = 8
local CHAR_W = 6.5

Win95.CANVAS = CANVAS
Win95.TASKBAR_Y = TASKBAR_Y
Win95.CHAR_W = CHAR_W

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
    highlight = { 255, 0, 0, 128 },
    text_white = { 255, 255, 255, 255 },
    text_black = { 255, 0, 0, 0 },
    text_gray = { 255, 128, 128, 128 },
    hint = { 255, 225, 255, 250 },
    field = { 255, 255, 255, 255 },
    logo_red = { 255, 240, 60, 30 },
    logo_green = { 255, 60, 190, 50 },
    logo_blue = { 255, 40, 110, 240 },
    logo_yellow = { 255, 255, 210, 30 },
}
Win95.C = C

-- Geometry -------------------------------------------------------------------------

local function rect(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

local function inside(r, x, y)
    return r ~= nil and x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h
end

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

Win95.rect = rect
Win95.inside = inside
Win95.clamp = clamp

function Win95.text_width(value, size)
    return #value * (size or 12) * 0.54
end

-- Pixel sprites ---------------------------------------------------------------------

-- rows: strings of palette characters; palette maps a character to a colour table or to a
-- string key resolved at draw time (for tinting). Other characters are transparent.
-- Horizontal runs are merged downwards while consecutive rows repeat the same span.
function Win95.sprite(rows, palette)
    local runs = {}
    local open = {}
    local width = 0

    for y = 1, #rows do
        local line = rows[y]
        if #line > width then width = #line end
        local next_open = {}
        local x = 1

        while x <= #line do
            local ch = line:sub(x, x)
            local color = palette[ch]
            if color then
                local s = x
                while x <= #line and line:sub(x, x) == ch do x = x + 1 end
                local key = ch .. s .. ":" .. (x - s)
                local run = open[key]
                if run then
                    run[4] = run[4] + 1
                else
                    run = { s - 1, y - 1, x - s, 1, color }
                    runs[#runs + 1] = run
                end
                next_open[key] = run
            else
                x = x + 1
            end
        end

        open = next_open
    end

    return { w = width, h = #rows, runs = runs }
end

-- Builds rows mirrored around their last character: "abc" becomes "abcba".
function Win95.mirror(half_rows)
    local rows = {}
    for i = 1, #half_rows do
        local half = half_rows[i]
        rows[i] = half .. half:sub(1, #half - 1):reverse()
    end
    return rows
end

function Win95.draw_sprite(canvas, sprite, x, y, px, layer, colors, alpha, flip_x, flip_y, py)
    py = py or px
    local runs = sprite.runs
    local sw, sh = sprite.w, sprite.h

    for i = 1, #runs do
        local r = runs[i]
        local color = r[5]
        if type(color) == "string" then color = colors and colors[color] end
        if color then
            local rx = flip_x and (sw - r[1] - r[3]) or r[1]
            local ry = flip_y and (sh - r[2] - r[4]) or r[2]
            canvas:rect(x + rx * px, y + ry * py, r[3] * px, r[4] * py, layer, color, alpha and alpha * color[1] / 255 or nil)
        end
    end
end

-- Text pool --------------------------------------------------------------------------

function Win95.add_text_widgets(UIWidget, widget_definitions, prefix, count, render_size)
    for i = 1, count do
        widget_definitions[prefix .. i] = UIWidget.create_definition({
            {
                pass_type = "text", style_id = "text", value = "", value_id = "text",
                style = {
                    font_size = 13, font_type = "machine_medium",
                    text_horizontal_alignment = "left", text_vertical_alignment = "center",
                    text_color = { 255, 0, 0, 0 }, offset = { 0, 0, 6 }, size = { 100, 20 },
                },
            },
        }, "scanner_base", nil, { render_size, render_size })
    end
end

local TextPool = {}
TextPool.__index = TextPool

-- Widgets are created after the view package loads, so they are looked up lazily.
function Win95.text_pool(view, prefix, count)
    return setmetatable({ _view = view, _prefix = prefix, _count = count, _used = 0, _widgets = {}, _dx = 0, _dy = 0 }, TextPool)
end

function TextPool:_widget(index)
    local widget = self._widgets[index]
    if not widget then
        local by_name = self._view._widgets_by_name
        widget = by_name and by_name[self._prefix .. index]
        self._widgets[index] = widget
    end
    return widget
end

function TextPool:reset()
    for i = 1, self._used do
        local widget = self:_widget(i)
        if widget then widget.content.text = "" end
    end
    self._used = 0
end

function TextPool:set_offset(dx, dy)
    self._dx, self._dy = dx or 0, dy or 0
end

function TextPool:used()
    return self._used
end

-- z matches canvas layers: text at z sits above shapes on layer z and below layer z + 0.1.
function TextPool:draw(value, x, y, w, h, size, color, halign, z, font, alpha)
    local index = self._used + 1
    if index > self._count then return end
    local widget = self:_widget(index)
    if not widget then return end

    self._used = index
    local style = widget.style.text
    widget.content.text = value
    style.font_size = size or 13
    style.font_type = font or "machine_medium"
    style.text_horizontal_alignment = halign or "left"
    style.text_vertical_alignment = "center"
    style.offset[1] = x + self._dx
    style.offset[2] = y + self._dy
    style.offset[3] = (z or 6) * 10
    style.size[1] = w
    style.size[2] = h
    local tc = style.text_color
    tc[1] = alpha and math_floor(clamp(alpha, 0, 255) * color[1] / 255) or color[1]
    tc[2], tc[3], tc[4] = color[2], color[3], color[4]
end

-- Primitives ---------------------------------------------------------------------------

-- Windows 95 3D edge: raised when inverted is false.
function Win95.bevel(canvas, x, y, w, h, t, layer, inverted, outer)
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

function Win95.panel(canvas, x, y, w, h, layer, inverted)
    canvas:vgradient(x, y, w, h, layer, C.face_light, C.face_dark, 255, 255, 4)
    Win95.bevel(canvas, x, y, w, h, 1, layer + 0.01, inverted, true)
end

-- Sunken white field, as used by edit boxes and list boxes.
function Win95.field(canvas, x, y, w, h, layer, color)
    canvas:rect(x, y, w, h, layer, color or C.field)
    Win95.bevel(canvas, x, y, w, h, 1, layer + 0.001, true, true)
end

-- Etched line group box with its caption cut into the top edge.
function Win95.group(canvas, text, r, label, layer, background)
    local top = r.y + 7
    canvas:rect(r.x, top, r.w, 1, layer, C.shadow)
    canvas:rect(r.x, top + 1, r.w, 1, layer, C.light)
    canvas:rect(r.x, top, 1, r.h - 7, layer, C.shadow)
    canvas:rect(r.x + 1, top, 1, r.h - 7, layer, C.light)
    canvas:rect(r.x, r.y + r.h - 2, r.w, 1, layer, C.shadow)
    canvas:rect(r.x, r.y + r.h - 1, r.w, 1, layer, C.light)
    canvas:rect(r.x + r.w - 2, top, 1, r.h - 7, layer, C.shadow)
    canvas:rect(r.x + r.w - 1, top, 1, r.h - 7, layer, C.light)
    if label and label ~= "" then
        local w = Win95.text_width(label, 12) + 8
        canvas:rect(r.x + 7, top - 1, w, 4, layer + 0.001, background or C.face)
        text:draw(label, r.x + 10, r.y - 3, w, 20, 12, C.text_black, "left", layer + 1.3)
    end
end

function Win95.checkmark(canvas, x, y, layer, color)
    canvas:line(x, y + 3, x + 2.5, y + 6, 1.8, layer, color)
    canvas:line(x + 2.5, y + 6, x + 7, y, 1.8, layer, color)
end

local function dotted_rect(canvas, x, y, w, h, layer, color)
    for k = 0, math_floor((w - 1) / 2) do
        canvas:rect(x + k * 2, y, 1, 1, layer, color)
        canvas:rect(x + k * 2, y + h - 1, 1, 1, layer, color)
    end
    for k = 0, math_floor((h - 1) / 2) do
        canvas:rect(x, y + k * 2, 1, 1, layer, color)
        canvas:rect(x + w - 1, y + k * 2, 1, 1, layer, color)
    end
end
Win95.dotted_rect = dotted_rect

function Win95.button(canvas, text, r, label, focused, pressed, is_default, layer, enabled)
    layer = layer or 9.21
    local off = pressed and 1 or 0
    if is_default then
        canvas:rect(r.x - 1, r.y - 1, r.w + 2, r.h + 2, layer - 0.01, C.black)
    end
    Win95.panel(canvas, r.x, r.y, r.w, r.h, layer, pressed)
    if focused then
        dotted_rect(canvas, r.x + 4, r.y + 4, r.w - 8, r.h - 8, layer + 0.04, C.black)
    end
    local color = enabled == false and C.text_gray or C.text_black
    text:draw(label, r.x + off, r.y + off, r.w, r.h, 12, color, "center", layer + 1.29)
end

function Win95.checkbox(canvas, text, r, label, checked, focused, layer, enabled)
    layer = layer or 9.2
    local bx, by = r.x, r.y + math_floor((r.h - 13) * 0.5)
    Win95.field(canvas, bx, by, 13, 13, layer, enabled == false and C.face or C.field)
    if checked then Win95.checkmark(canvas, bx + 3, by + 3, layer + 0.1, enabled == false and C.shadow or C.black) end
    local tw = Win95.text_width(label, 12)
    if focused then dotted_rect(canvas, bx + 18, r.y + 2, tw + 6, r.h - 4, layer + 0.01, C.black) end
    text:draw(label, bx + 21, r.y, r.w - 21, r.h, 12, enabled == false and C.text_gray or C.text_black, "left", layer + 1.3)
end

function Win95.radio(canvas, text, r, label, selected, focused, layer, enabled)
    layer = layer or 9.2
    local cx, cy = r.x + 6, r.y + r.h * 0.5
    canvas:circle(cx, cy, 6.3, layer + 0.1, C.light, 255, 1, 0, 16)
    canvas:ring(cx, cy, 5.6, 1.4, layer + 0.11, C.shadow, 255, 10, math_pi * 0.75, math_pi * 1.75)
    canvas:ring(cx, cy, 4.6, 1.1, layer + 0.12, C.black, 255, 10, math_pi * 0.75, math_pi * 1.75)
    canvas:circle(cx, cy, 4, layer + 0.13, enabled == false and C.face or C.field, 255, 1, 0, 14)
    if selected then
        canvas:circle(cx, cy, 1.9, layer + 0.14, enabled == false and C.shadow or C.black, 255, 1, 0, 10)
    end
    local tw = Win95.text_width(label, 12)
    if focused then dotted_rect(canvas, r.x + 16, r.y + 2, tw + 6, r.h - 4, layer + 0.01, C.black) end
    text:draw(label, r.x + 19, r.y, r.w - 19, r.h, 12, enabled == false and C.text_gray or C.text_black, "left", layer + 1.3)
end

-- The four-colour flag on the Start button.
function Win95.logo(canvas, x, y, s, layer, t)
    local wave = t and math_sin(t * 2) * 0.4 or 0
    local q = s * 0.46
    canvas:rect(x, y + wave, q, q, layer, C.logo_red)
    canvas:rect(x + q + s * 0.08, y - wave, q, q, layer, C.logo_green)
    canvas:rect(x, y + q + s * 0.08 + wave, q, q, layer, C.logo_blue)
    canvas:rect(x + q + s * 0.08, y + q + s * 0.08 - wave, q, q, layer, C.logo_yellow)
end

-- Desktop and window chrome ----------------------------------------------------------------

-- opts: app (task button label), icon(canvas, cx, cy, size, layer), clock (string)
function Win95.draw_desktop(canvas, text, t, opts)
    canvas:vgradient(0, 0, CANVAS, TASKBAR_Y, 0.4, C.desktop, C.desktop_dark, 255, 255, 24)
    canvas:glow(140, 90, 260, 0.5, C.light, 16, 6)

    canvas:rect(0, TASKBAR_Y, CANVAS, CANVAS - TASKBAR_Y, 0.6, C.face)
    canvas:rect(0, TASKBAR_Y, CANVAS, 1, 0.61, C.face_light)
    canvas:rect(0, TASKBAR_Y + 1, CANVAS, 1, 0.61, C.light)

    Win95.panel(canvas, 3, TASKBAR_Y + 4, 58, 22, 0.62, false)
    Win95.logo(canvas, 8, TASKBAR_Y + 9, 12, 0.63, t)
    text:draw("Start", 24, TASKBAR_Y + 4, 36, 22, 12, C.text_black, "left", 1)

    local app = opts and opts.app
    if app then
        Win95.panel(canvas, 66, TASKBAR_Y + 4, 150, 22, 0.62, true)
        canvas:rect(68, TASKBAR_Y + 6, 146, 18, 0.63, C.face_light, 255)
        if opts.icon then opts.icon(canvas, 78, TASKBAR_Y + 15, 12, 0.64) end
        text:draw(app, 88, TASKBAR_Y + 4, 124, 22, 12, C.text_black, "left", 1)
    end

    Win95.bevel(canvas, CANVAS - 84, TASKBAR_Y + 4, 81, 22, 1, 0.62, true)
    local clock = opts and opts.clock
    if clock then
        text:draw(clock, CANVAS - 84, TASKBAR_Y + 4, 81, 22, 12, C.text_black, "center", 1)
    end
end

-- A one-line hint on the desktop, just above the taskbar.
function Win95.draw_hint(canvas, text, value)
    text:draw(value, 8, TASKBAR_Y - 22, CANVAS - 16, 18, 11, C.hint, "center", 1)
end

local function chrome_button(canvas, r, pressed, layer)
    Win95.panel(canvas, r.x, r.y, r.w, r.h, layer, pressed)
    return pressed and 1 or 0
end

-- opts: title, icon(canvas, cx, cy, size, layer), status = { { text =, w = } ... }
function Win95.draw_window(canvas, text, shell, t, opts)
    local L = shell:layout()
    local window, title = L.window, L.title

    canvas:soft_rect(window.x + 6, window.y + 8, window.w, window.h, 10, 2, C.black, 120, 5)
    canvas:rect(window.x, window.y, window.w, window.h, 3, C.face)
    Win95.bevel(canvas, window.x, window.y, window.w, window.h, 1, 3.01, false, true)

    canvas:hgradient(title.x, title.y, title.w, title.h, 3.1, C.title_a, C.title_b, 255, 255, 24)
    canvas:rect(title.x, title.y, title.w, title.h * 0.45, 3.11, C.light, 22)
    if opts.icon then opts.icon(canvas, title.x + 11, title.y + title.h * 0.5, 14, 3.2) end
    text:draw(opts.title or "", title.x + 22, title.y, title.w - 90, title.h, 13, C.text_white, "left", 4)

    local press, hover = shell:press(), shell:hover()

    local off = chrome_button(canvas, L.minimize_button, press == "minimize" and hover == "minimize", 3.2)
    canvas:rect(L.minimize_button.x + 4 + off, L.minimize_button.y + 9 + off, 7, 2, 3.25, C.black)

    local mb = L.maximize_button
    off = chrome_button(canvas, mb, press == "maximize" and hover == "maximize", 3.2)
    canvas:rect(mb.x + 4 + off, mb.y + 2 + off, 9, 2, 3.25, C.black)
    canvas:rect(mb.x + 4 + off, mb.y + 2 + off, 1, 9, 3.25, C.black)
    canvas:rect(mb.x + 12 + off, mb.y + 2 + off, 1, 9, 3.25, C.black)
    canvas:rect(mb.x + 4 + off, mb.y + 10 + off, 9, 1, 3.25, C.black)

    local cb = L.close_button
    off = chrome_button(canvas, cb, press == "close" and hover == "close", 3.2)
    canvas:line(cb.x + 4 + off, cb.y + 3 + off, cb.x + 12 + off, cb.y + 11 + off, 1.8, 3.3, C.black)
    canvas:line(cb.x + 4 + off, cb.y + 11 + off, cb.x + 12 + off, cb.y + 3 + off, 1.8, 3.3, C.black)

    local bar = L.menubar
    canvas:rect(bar.x, bar.y, bar.w, bar.h, 3.1, C.face)
    local open = shell:menu()
    local menus = shell:menus()
    for i = 1, #menus do
        local r = L.menu_titles[i]
        local active = open == i
        if active then canvas:rect(r.x, r.y, r.w, r.h, 3.12, C.highlight) end
        local color = active and C.text_white or C.text_black
        local label = menus[i].label
        text:draw(label, r.x, r.y, r.w, r.h, 12, color, "center", 4)
        local start = r.x + r.w * 0.5 - #label * CHAR_W * 0.5
        canvas:rect(start, r.y + r.h - 4, 7, 1, 3.13, color)
    end

    if L.status then
        local s = L.status
        canvas:rect(s.x, s.y, s.w, s.h, 3.1, C.face)
        canvas:rect(s.x, s.y, s.w, 1, 3.11, C.light)
        local segments = opts.status
        if segments then
            local x = s.x + 2
            for i = 1, #segments do
                local seg = segments[i]
                local w = seg.w or (s.w - (x - s.x) - 2)
                Win95.bevel(canvas, x, s.y + 3, w, s.h - 5, 1, 3.12, true)
                text:draw(seg.text or "", x + 5, s.y + 3, w - 8, s.h - 5, 11, C.text_black, seg.align or "left", 4)
                x = x + w + 3
            end
        end
    end
end

function Win95.draw_menu(canvas, text, shell)
    local L = shell:layout()
    local list = L.menu_items
    if not list then return end

    local box = list.box
    canvas:rect(box.x + 3, box.y + 3, box.w, box.h, 7.9, C.black, 90)
    Win95.panel(canvas, box.x, box.y, box.w, box.h, 8, false)

    local hover = shell:menu_hover()
    for i = 1, #list do
        local entry = list[i]
        local item = entry.item
        local r = entry.rect
        if item.separator then
            canvas:rect(r.x + 2, r.y + r.h * 0.5 - 1, r.w - 4, 1, 8.1, C.shadow)
            canvas:rect(r.x + 2, r.y + r.h * 0.5, r.w - 4, 1, 8.1, C.light)
        else
            local enabled = shell:item_enabled(item)
            local active = hover == i and enabled
            if hover == i then canvas:rect(r.x, r.y, r.w, r.h, 8.1, C.highlight) end
            local color = active and C.text_white or C.text_black
            if not enabled then color = hover == i and C.face_dark or C.text_gray end

            if shell:item_checked(item) then
                if item.radio then
                    canvas:circle(r.x + 10, r.y + r.h * 0.5, 2.6, 8.2, color, 255, 1, 0, 10)
                else
                    Win95.checkmark(canvas, r.x + 7, r.y + r.h * 0.5 - 4, 8.2, color)
                end
            end

            if not enabled and hover ~= i then
                text:draw(item.label, r.x + 23, r.y + 1, r.w - 70, r.h, 12, C.light, "left", 8.4)
            end
            text:draw(item.label, r.x + 22, r.y, r.w - 70, r.h, 12, color, "left", 8.5)
            if item.key then
                text:draw(item.key, r.x + r.w - 60, r.y, 52, r.h, 12, color, "right", 8.5)
            end
        end
    end
end

-- custom(canvas, D, dialog, text, t) draws game-specific dialog content.
function Win95.draw_dialog(canvas, text, shell, t, custom)
    local L = shell:layout()
    local D = L.dialog
    local dialog = shell:dialog()
    if not D or not dialog then return end

    local box = D.box
    canvas:rect(0, 0, CANVAS, TASKBAR_Y, 8.8, C.black, 40)
    canvas:soft_rect(box.x + 5, box.y + 7, box.w, box.h, 8, 8.9, C.black, 120, 4)
    canvas:rect(box.x, box.y, box.w, box.h, 9, C.face)
    Win95.bevel(canvas, box.x, box.y, box.w, box.h, 1, 9.01, false, true)
    canvas:hgradient(D.title.x, D.title.y, D.title.w, D.title.h, 9.1, C.title_a, C.title_b, 255, 255, 16)
    canvas:rect(D.title.x, D.title.y, D.title.w, D.title.h * 0.45, 9.11, C.light, 22)
    text:draw(dialog.title or "", D.title.x + 6, D.title.y, D.title.w - 30, D.title.h, 12, C.text_white, "left", 10.5)

    local cb = D.close_button
    local press, hover, hover_a = shell:press(), shell:hover()
    local off = chrome_button(canvas, cb, press == "close" and hover == "dialog_close", 9.2)
    canvas:line(cb.x + 4 + off, cb.y + 3 + off, cb.x + 11 + off, cb.y + 10 + off, 1.6, 9.3, C.black)
    canvas:line(cb.x + 4 + off, cb.y + 10 + off, cb.x + 11 + off, cb.y + 3 + off, 1.6, 9.3, C.black)

    local focus_kind, focus_index = shell:dialog_focus()
    local values = dialog.values

    for i = 1, #D.controls do
        local c = D.controls[i]
        local spec = c.spec
        local focused = focus_kind == "control" and focus_index == i
        local enabled = shell:control_enabled(spec)
        if spec.type == "group" then
            Win95.group(canvas, text, c.rect, spec.label, 9.15)
        elseif spec.type == "label" then
            text:draw(spec.label or "", c.rect.x, c.rect.y, c.rect.w, c.rect.h, spec.size or 12, spec.color or C.text_black, spec.align or "left", 10.5)
        elseif spec.type == "check" then
            Win95.checkbox(canvas, text, c.rect, spec.label, values[spec.id] and true or false, focused, 9.2, enabled)
        elseif spec.type == "radio" then
            Win95.radio(canvas, text, c.rect, spec.label, values[spec.group] == spec.value, focused, 9.2, enabled)
        end
    end

    if custom then custom(canvas, D, dialog, text, t) end

    for i = 1, #D.buttons do
        local b = D.buttons[i]
        local pressed = press == ("button" .. i) and hover == "dialog_button" and hover_a == i
        local focused = focus_kind == "button" and focus_index == i
        Win95.button(canvas, text, b.rect, b.spec.label, focused, pressed, b.spec.default, 9.21)
    end
end

-- Shell --------------------------------------------------------------------------------

local Shell = {}
Shell.__index = Shell

-- spec:
--   client_w, client_h: client area size; status: show a status bar; x, y: window position
--   menus: { { id, label, width, items = { { id, label, key, check = fn, radio = bool,
--            enabled = fn, separator = bool } } } }
--   on_command(id): a menu item was chosen
--   on_dialog(dialog, button_id): a dialog button was chosen; return true to keep it open
function Win95.shell(spec)
    local self = setmetatable({}, Shell)
    self._spec = spec
    self._menus = spec.menus or {}
    self._status = spec.status and true or false
    self._menu = nil
    self._menu_hover = nil
    self._dialog = nil
    self._held = { left = false, right = false, middle = false }
    self._press = nil
    self._suppress = false
    self._close_requested = false
    self._hover_kind = "none"
    self._hover_a = nil
    self._pointer_x = -1
    self._pointer_y = -1
    self._client_w = spec.client_w or 300
    self._client_h = spec.client_h or 200
    self:_build_layout()
    return self
end

function Shell:set_client_size(w, h)
    self._client_w, self._client_h = w, h
    self:_build_layout()
end

function Shell:set_status(visible)
    self._status = visible and true or false
    self:_build_layout()
end

function Shell:_build_layout()
    local spec = self._spec
    local cw, ch = self._client_w, self._client_h
    local status_h = self._status and STATUS_H or 0
    local ww = cw + FRAME * 2
    local wh = FRAME + TITLE_H + MENU_H + ch + status_h + FRAME
    local wx = spec.x or math_floor((CANVAS - ww) * 0.5)
    local wy = spec.y or math_max(0, math_floor((TASKBAR_Y - wh) * 0.5))

    local L = {}
    L.window = rect(wx, wy, ww, wh)
    L.title = rect(wx + FRAME, wy + FRAME, ww - FRAME * 2, TITLE_H)
    L.close_button = rect(L.title.x + L.title.w - 20, L.title.y + 3, 17, 15)
    L.maximize_button = rect(L.close_button.x - 19, L.title.y + 3, 17, 15)
    L.minimize_button = rect(L.close_button.x - 36, L.title.y + 3, 17, 15)
    L.menubar = rect(wx + FRAME, L.title.y + TITLE_H, ww - FRAME * 2, MENU_H)
    L.menu_titles = {}

    local mx = L.menubar.x + 2
    for i = 1, #self._menus do
        local w = math_floor(#self._menus[i].label * CHAR_W + 18)
        L.menu_titles[i] = rect(mx, L.menubar.y + 1, w, MENU_H - 2)
        mx = mx + w
    end

    L.client = rect(wx + FRAME, L.menubar.y + MENU_H, cw, ch)
    if status_h > 0 then
        L.status = rect(wx + FRAME, L.client.y + ch, cw, status_h)
    end

    self._layout = L
    self:_layout_menu()
    self:_layout_dialog()
end

function Shell:_layout_menu()
    local L = self._layout
    L.menu_items = nil

    local index = self._menu
    local menu = index and self._menus[index]
    if not menu then return end

    local items = menu.items
    local anchor = L.menu_titles[index]
    local height = 4
    for i = 1, #items do
        height = height + (items[i].separator and MENU_SEP_H or MENU_ITEM_H)
    end

    local box = rect(anchor.x, anchor.y + anchor.h, menu.width or 190, height)
    local list = { box = box }
    local y = box.y + 2
    for i = 1, #items do
        local h = items[i].separator and MENU_SEP_H or MENU_ITEM_H
        list[i] = { item = items[i], rect = rect(box.x + 2, y, box.w - 4, h) }
        y = y + h
    end

    L.menu_items = list
end

function Shell:_layout_dialog()
    local L = self._layout
    L.dialog = nil

    local d = self._dialog
    if not d then return end

    local w, h = d.w or 280, d.h or 150
    local x = d.x or math_floor((CANVAS - w) * 0.5)
    local y = d.y or math_floor(clamp(L.window.y + (L.window.h - h) * 0.5, 4, TASKBAR_Y - h - 4))

    local D = { box = rect(x, y, w, h) }
    D.title = rect(x + 3, y + 3, w - 6, 20)
    D.close_button = rect(D.title.x + D.title.w - 19, D.title.y + 3, 16, 14)
    D.body = rect(x + 12, y + 30, w - 24, h - 74)

    D.controls = {}
    local controls = d.controls or {}
    for i = 1, #controls do
        local c = controls[i]
        D.controls[i] = { spec = c, rect = rect(x + c.x, y + c.y, c.w or 120, c.h or 20) }
    end

    D.buttons = {}
    local buttons = d.buttons or { { id = "ok", label = "OK", default = true } }
    local total = 0
    for i = 1, #buttons do
        total = total + (buttons[i].w or 76) + (i > 1 and 8 or 0)
    end
    local bx = d.buttons_align == "center" and math_floor(x + (w - total) * 0.5) or x + w - 14 - total
    for i = 1, #buttons do
        local b = buttons[i]
        local bw = b.w or 76
        local r
        if b.x then
            r = rect(x + b.x, y + b.y, bw, b.h or 24)
        else
            r = rect(bx, y + h - 36, bw, 24)
            bx = bx + bw + 8
        end
        D.buttons[i] = { spec = b, rect = r }
    end

    D.focus_list = {}
    for i = 1, #D.controls do
        local t = D.controls[i].spec.type
        if t == "radio" or t == "check" or t == "tile" then
            D.focus_list[#D.focus_list + 1] = { kind = "control", index = i }
        end
    end
    for i = 1, #D.buttons do
        D.focus_list[#D.focus_list + 1] = { kind = "button", index = i }
    end

    L.dialog = D
end

function Shell:_refresh()
    self:_layout_menu()
    self:_layout_dialog()
end

-- Menus ---------------------------------------------------------------------------------

function Shell:item_enabled(item)
    if item.separator then return false end
    if item.enabled == nil then return true end
    if type(item.enabled) == "function" then return item.enabled() and true or false end
    return item.enabled and true or false
end

function Shell:item_checked(item)
    if type(item.check) == "function" then return item.check() and true or false end
    return false
end

function Shell:open_menu(index)
    if self._dialog then return end
    self._menu = index
    self._menu_hover = nil
    self:_refresh()
end

function Shell:close_menu()
    self._menu = nil
    self._menu_hover = nil
    self:_refresh()
end

function Shell:_menu_step(direction)
    local list = self._layout.menu_items
    if not list then return end

    local i = self._menu_hover or (direction > 0 and 0 or #list + 1)
    for _ = 1, #list do
        i = i + direction
        if i < 1 then i = #list end
        if i > #list then i = 1 end
        if self:item_enabled(list[i].item) then break end
    end
    self._menu_hover = i
end

function Shell:_activate_menu_item(index)
    local list = self._layout.menu_items
    local entry = list and list[index]
    if not entry or not self:item_enabled(entry.item) then return end

    self._menu = nil
    self._menu_hover = nil
    self:_refresh()

    local on_command = self._spec.on_command
    if on_command then on_command(entry.item.id) end
end

-- Dialogs -------------------------------------------------------------------------------

-- dialog: { kind, title, w, h, x, y, values = {}, controls = { { type = "group" | "label" |
--   "check" | "radio" | "tile", id, group, value, label, x, y, w, h, enabled = fn(values) } },
--   buttons = { { id, label, default, w, x, y } }, buttons_align = "center", focus }
function Shell:open_dialog(dialog)
    dialog.values = dialog.values or {}
    self._dialog = dialog
    self._menu = nil
    self._menu_hover = nil
    self._press = nil
    self:_refresh()

    if not dialog.focus then
        local D = self._layout.dialog
        dialog.focus = 1
        for i = 1, #D.focus_list do
            local f = D.focus_list[i]
            if f.kind == "button" and D.buttons[f.index].spec.default then
                dialog.focus = i
                break
            end
        end
        if D.focus_list[1] and D.focus_list[1].kind == "control" then dialog.focus = 1 end
    end
end

function Shell:close_dialog()
    self._dialog = nil
    self._press = nil
    self:_refresh()
end

function Shell:control_enabled(spec)
    if type(spec.enabled) == "function" then
        return spec.enabled(self._dialog and self._dialog.values or {}) and true or false
    end
    return spec.enabled ~= false
end

function Shell:dialog_focus()
    local D = self._layout.dialog
    local d = self._dialog
    if not D or not d then return nil end
    local f = D.focus_list[d.focus or 0]
    if not f then return nil end
    return f.kind, f.index
end

function Shell:_focus_to(kind, index)
    local D = self._layout.dialog
    if not D then return end
    for i = 1, #D.focus_list do
        local f = D.focus_list[i]
        if f.kind == kind and f.index == index then
            self._dialog.focus = i
            return
        end
    end
end

function Shell:_control_activate(index)
    local d = self._dialog
    local c = self._layout.dialog.controls[index]
    if not c or not self:control_enabled(c.spec) then return end
    local spec = c.spec

    if spec.type == "radio" or spec.type == "tile" then
        d.values[spec.group] = spec.value
    elseif spec.type == "check" then
        d.values[spec.id] = not d.values[spec.id]
    end

    if spec.on_change then spec.on_change(d.values) end
end

function Shell:_button_by_id(id)
    local d = self._dialog
    if not d then return end

    local keep = false
    local on_dialog = self._spec.on_dialog
    if on_dialog then keep = on_dialog(d, id) end

    if not keep and self._dialog == d then
        self._dialog = nil
    end
    self._press = nil
    self:_refresh()
end

function Shell:_button(index)
    local D = self._layout.dialog
    local b = D and D.buttons[index]
    if b then self:_button_by_id(b.spec.id) end
end

function Shell:_cancel_id()
    local d = self._dialog
    if d.cancel_id then return d.cancel_id end
    local buttons = d.buttons or { { id = "ok", default = true } }
    for i = 1, #buttons do
        if buttons[i].id == "cancel" then return "cancel" end
    end
    for i = 1, #buttons do
        if buttons[i].default then return buttons[i].id end
    end
    return buttons[1] and buttons[1].id or "ok"
end

-- Returns true when Esc closed a menu or dialog instead of reaching the game.
function Shell:ui_back()
    if self._dialog then
        self:_button_by_id(self:_cancel_id())
        return true
    end
    if self._menu then
        self:close_menu()
        return true
    end
    return false
end

-- Same-group neighbour of a radio or tile control, in declaration order.
function Shell:_group_step(index, direction)
    local D = self._layout.dialog
    local group = D.controls[index].spec.group
    local members = {}
    local at = 1
    for i = 1, #D.controls do
        local spec = D.controls[i].spec
        if spec.group == group and (spec.type == "radio" or spec.type == "tile") and self:control_enabled(spec) then
            members[#members + 1] = i
            if i == index then at = #members end
        end
    end
    if #members == 0 then return index end
    return members[(at - 1 + direction) % #members + 1]
end

function Shell:_dialog_key(key)
    local d = self._dialog
    local D = self._layout.dialog
    local n = #D.focus_list
    if n == 0 then
        if key == "confirm" then self:_button_by_id(self:_cancel_id()) end
        return
    end

    local f = D.focus_list[d.focus] or D.focus_list[1]

    if key == "up" or key == "down" then
        local step = key == "down" and 1 or -1
        local i = d.focus
        for _ = 1, n do
            i = (i - 1 + step) % n + 1
            local g = D.focus_list[i]
            if g.kind == "button" or self:control_enabled(D.controls[g.index].spec) then break end
        end
        d.focus = i
    elseif key == "left" or key == "right" then
        local step = key == "right" and 1 or -1
        if f.kind == "control" then
            local spec = D.controls[f.index].spec
            if spec.type == "radio" or spec.type == "tile" then
                local target = self:_group_step(f.index, step)
                self:_focus_to("control", target)
                self:_control_activate(target)
            end
        else
            local target = (f.index - 1 + step) % #D.buttons + 1
            self:_focus_to("button", target)
        end
    elseif key == "confirm" then
        if f.kind == "control" then
            self:_control_activate(f.index)
        else
            self:_button(f.index)
        end
    elseif key == "menu" then
        self:ui_back()
    end
end

-- Keyboard: key is "left", "right", "up", "down", "confirm" or "menu".
-- Returns true when a menu or dialog consumed the key.
function Shell:key(key)
    if self._dialog then
        self:_dialog_key(key)
        return true
    end

    if self._menu then
        if key == "up" or key == "down" then
            self:_menu_step(key == "down" and 1 or -1)
        elseif key == "left" or key == "right" then
            local n = #self._menus
            self._menu = (self._menu - 1 + (key == "right" and 1 or -1)) % n + 1
            self._menu_hover = nil
            self:_refresh()
            self:_menu_step(1)
        elseif key == "confirm" then
            if self._menu_hover then self:_activate_menu_item(self._menu_hover) end
        elseif key == "menu" then
            self:close_menu()
        end
        return true
    end

    if key == "menu" and #self._menus > 0 then
        self:open_menu(1)
        self:_menu_step(1)
        return true
    end

    return false
end

-- Pointer ---------------------------------------------------------------------------------

function Shell:_hover_target(x, y)
    local L = self._layout

    if L.dialog then
        local D = L.dialog
        for i = 1, #D.buttons do
            if inside(D.buttons[i].rect, x, y) then return "dialog_button", i end
        end
        for i = 1, #D.controls do
            local c = D.controls[i]
            local t = c.spec.type
            if (t == "radio" or t == "check" or t == "tile") and inside(c.rect, x, y) and self:control_enabled(c.spec) then
                return "dialog_control", i
            end
        end
        if inside(D.close_button, x, y) then return "dialog_close" end
        return "modal"
    end

    if L.menu_items and inside(L.menu_items.box, x, y) then
        for i = 1, #L.menu_items do
            if inside(L.menu_items[i].rect, x, y) then return "menu_item", i end
        end
        return "menu_box"
    end

    for i = 1, #L.menu_titles do
        if inside(L.menu_titles[i], x, y) then return "menu_title", i end
    end
    if inside(L.close_button, x, y) then return "close" end
    if inside(L.minimize_button, x, y) then return "minimize" end
    if inside(L.maximize_button, x, y) then return "maximize" end
    if inside(L.client, x, y) then return "client" end
    if inside(L.window, x, y) then return "chrome" end
    return "desktop"
end

-- input: { left, right, middle, left_pressed, right_pressed, middle_pressed, left_released,
-- right_released, middle_released }. Edges are completed from the held state in place, so the
-- game can read them after this call. Returns true when the shell consumed the pointer.
function Shell:pointer(x, y, input)
    local held = self._held
    local lp = (input.left_pressed or (input.left and not held.left)) and true or false
    local rp = (input.right_pressed or (input.right and not held.right)) and true or false
    local mp = (input.middle_pressed or (input.middle and not held.middle)) and true or false
    local lr = (input.left_released or (not input.left and held.left)) and true or false
    local rr = (input.right_released or (not input.right and held.right)) and true or false
    local mr = (input.middle_released or (not input.middle and held.middle)) and true or false
    held.left, held.right, held.middle = input.left and true or false, input.right and true or false, input.middle and true or false
    input.left_pressed, input.right_pressed, input.middle_pressed = lp, rp, mp
    input.left_released, input.right_released, input.middle_released = lr, rr, mr

    self._pointer_x, self._pointer_y = x, y
    local any_held = held.left or held.right or held.middle

    local kind, a = self:_hover_target(x, y)
    self._hover_kind, self._hover_a = kind, a

    if self._dialog then
        if lp then
            self._press = nil
            if kind == "dialog_button" then
                self._press = "button" .. a
                self:_focus_to("button", a)
            elseif kind == "dialog_close" then
                self._press = "close"
            elseif kind == "dialog_control" then
                self:_focus_to("control", a)
                self:_control_activate(a)
            end
        end
        if lr then
            if self._press and kind == "dialog_button" and self._press == "button" .. a then
                self:_button(a)
            elseif self._press == "close" and kind == "dialog_close" then
                self:ui_back()
            end
            self._press = nil
        end
        return true
    end

    if self._menu then
        if kind == "menu_item" then
            self._menu_hover = a
        elseif kind ~= "menu_box" then
            self._menu_hover = nil
        end

        if lp or rp then
            if kind == "menu_title" then
                if self._menu == a then self:close_menu() else self:open_menu(a) end
            elseif kind ~= "menu_item" and kind ~= "menu_box" then
                self:close_menu()
                self._suppress = true
            end
        elseif lr and kind == "menu_item" then
            self:_activate_menu_item(a)
        end
        if self._suppress and not any_held then self._suppress = false end
        return true
    end

    if self._suppress then
        if not any_held then self._suppress = false end
        return true
    end

    if lp and kind == "menu_title" then
        self:open_menu(a)
        return true
    end

    if lp and (kind == "close" or kind == "minimize" or kind == "maximize") then
        self._press = kind
    end
    if self._press then
        if lr then
            if self._press == kind and kind == "close" then self._close_requested = true end
            self._press = nil
        elseif not any_held then
            self._press = nil
        end
        return true
    end

    return false
end

-- Queries -----------------------------------------------------------------------------------

function Shell:layout() return self._layout end
function Shell:menus() return self._menus end
function Shell:menu() return self._menu end
function Shell:menu_id() return self._menu and self._menus[self._menu].id end
function Shell:menu_hover() return self._menu_hover end
function Shell:dialog() return self._dialog end
function Shell:press() return self._press end
function Shell:hover() return self._hover_kind, self._hover_a end
function Shell:pointer_position() return self._pointer_x, self._pointer_y end
function Shell:is_modal() return self._menu ~= nil or self._dialog ~= nil end
function Shell:status_visible() return self._status end
function Shell:request_close() self._close_requested = true end

function Shell:consume_close_request()
    local requested = self._close_requested
    self._close_requested = false
    return requested
end

return Win95
