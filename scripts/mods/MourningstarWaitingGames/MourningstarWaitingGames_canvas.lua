-- Immediate-mode vector canvas and particle system drawn straight into the view's Gui.
-- Uses only material-free Gui primitives (Gui.rect / Gui.triangle), the same path as
-- NoosphereBreach_renderer, so no extra packages are required.
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_random = math.random
local math_sin = math.sin
local math_sqrt = math.sqrt

local TAU = math_pi * 2

local unit_circles = {}

local function unit_circle(segments)
    local circle = unit_circles[segments]

    if not circle then
        circle = {}
        for i = 0, segments do
            local angle = i / segments * TAU
            circle[i * 2 + 1] = math_cos(angle)
            circle[i * 2 + 2] = math_sin(angle)
        end
        unit_circles[segments] = circle
    end

    return circle
end

local function clamp_byte(value)
    if value < 0 then return 0 end
    if value > 255 then return 255 end
    return value
end

local function segments_for(radius)
    if radius < 4 then return 8 end
    if radius < 10 then return 12 end
    if radius < 24 then return 18 end
    if radius < 60 then return 24 end
    return 32
end

local Canvas = {}
Canvas.__index = Canvas

function Canvas.new(width, height, max_submissions)
    return setmetatable({
        _w = width,
        _h = height,
        _limit = max_submissions or 3000,
        _count = 0,
        _gui = nil,
        _scale = 1,
        _base_layer = 0,
        _layer_scale = 1,
        _ox = 0,
        _oy = 0,
        _dx = 0,
        _dy = 0,
        _cx0 = 0,
        _cy0 = 0,
        _cx1 = width,
        _cy1 = height,
    }, Canvas)
end

function Canvas:begin(ui_renderer, origin, layer_offset)
    local gui = ui_renderer and ui_renderer.gui

    if not gui or not origin then
        self._gui = nil
        return false
    end

    local render_settings = ui_renderer.render_settings

    self._gui = gui
    self._scale = ui_renderer.scale or 1
    self._base_layer = (render_settings and render_settings.start_layer or 0) + (origin[3] or 0) + (layer_offset or 0)
    self._ox = origin[1] or 0
    self._oy = origin[2] or 0
    self._dx = 0
    self._dy = 0
    self._count = 0
    self._cx0 = 0
    self._cy0 = 0
    self._cx1 = self._w
    self._cy1 = self._h

    return true
end

-- Gui orders rects and triangles by whole layers; a scale above 1 turns small
-- fractional layer steps into distinct layers so shapes stack predictably.
function Canvas:set_layer_scale(scale)
    self._layer_scale = scale or 1
end

function Canvas:finish()
    self._gui = nil
end

function Canvas:set_shake(dx, dy)
    self._dx = dx or 0
    self._dy = dy or 0
end

function Canvas:set_clip(x0, y0, x1, y1)
    self._cx0 = x0
    self._cy0 = y0
    self._cx1 = x1
    self._cy1 = y1
end

function Canvas:reset_clip()
    self._cx0 = 0
    self._cy0 = 0
    self._cx1 = self._w
    self._cy1 = self._h
end

function Canvas:get_clip()
    return self._cx0, self._cy0, self._cx1, self._cy1
end

function Canvas:submissions()
    return self._count
end

function Canvas:has_budget(amount)
    return self._gui ~= nil and self._count + (amount or 1) <= self._limit
end

-- Raw primitives -----------------------------------------------------------

local clip_a = {}
local clip_b = {}

-- Sutherland-Hodgman against one rectangle edge; axis 1 = x, 2 = y.
local function clip_edge(src, count, dst, axis, bound, keep_greater)
    local out = 0

    if count == 0 then return 0 end

    local px, py = src[count * 2 - 1], src[count * 2]
    local pv = axis == 1 and px or py
    local p_in = (keep_greater and pv >= bound) or (not keep_greater and pv <= bound)

    for i = 1, count do
        local cx, cy = src[i * 2 - 1], src[i * 2]
        local cv = axis == 1 and cx or cy
        local c_in = (keep_greater and cv >= bound) or (not keep_greater and cv <= bound)

        if c_in ~= p_in then
            local t = (bound - pv) / (cv - pv)
            out = out + 1
            dst[out * 2 - 1] = px + (cx - px) * t
            dst[out * 2] = py + (cy - py) * t
        end

        if c_in then
            out = out + 1
            dst[out * 2 - 1] = cx
            dst[out * 2] = cy
        end

        px, py, pv, p_in = cx, cy, cv, c_in
    end

    return out
end

function Canvas:_submit_tri(x1, y1, x2, y2, x3, y3, layer, color)
    local scale = self._scale
    local ox = self._ox
    local oy = self._oy

    Gui.triangle(self._gui,
        Vector3((ox + x1) * scale, 0, (oy + y1) * scale),
        Vector3((ox + x2) * scale, 0, (oy + y2) * scale),
        Vector3((ox + x3) * scale, 0, (oy + y3) * scale),
        self._base_layer + layer * self._layer_scale,
        color)
    self._count = self._count + 1
end

function Canvas:tri_raw(x1, y1, x2, y2, x3, y3, layer, a, r, g, b)
    if a < 1 or not self._gui or self._count >= self._limit then return end

    local dx = self._dx
    local dy = self._dy
    x1, y1, x2, y2, x3, y3 = x1 + dx, y1 + dy, x2 + dx, y2 + dy, x3 + dx, y3 + dy

    local cx0, cy0, cx1, cy1 = self._cx0, self._cy0, self._cx1, self._cy1

    if (x1 < cx0 and x2 < cx0 and x3 < cx0) or (x1 > cx1 and x2 > cx1 and x3 > cx1)
        or (y1 < cy0 and y2 < cy0 and y3 < cy0) or (y1 > cy1 and y2 > cy1 and y3 > cy1) then
        return
    end

    local color = Color(math_floor(clamp_byte(a)), math_floor(clamp_byte(r)), math_floor(clamp_byte(g)), math_floor(clamp_byte(b)))

    if x1 >= cx0 and x2 >= cx0 and x3 >= cx0 and x1 <= cx1 and x2 <= cx1 and x3 <= cx1
        and y1 >= cy0 and y2 >= cy0 and y3 >= cy0 and y1 <= cy1 and y2 <= cy1 and y3 <= cy1 then
        self:_submit_tri(x1, y1, x2, y2, x3, y3, layer, color)
        return
    end

    local a_pts, b_pts = clip_a, clip_b
    a_pts[1], a_pts[2], a_pts[3], a_pts[4], a_pts[5], a_pts[6] = x1, y1, x2, y2, x3, y3

    local n = clip_edge(a_pts, 3, b_pts, 1, cx0, true)
    n = clip_edge(b_pts, n, a_pts, 1, cx1, false)
    n = clip_edge(a_pts, n, b_pts, 2, cy0, true)
    n = clip_edge(b_pts, n, a_pts, 2, cy1, false)

    for i = 2, n - 1 do
        if self._count >= self._limit then return end
        self:_submit_tri(a_pts[1], a_pts[2], a_pts[i * 2 - 1], a_pts[i * 2], a_pts[i * 2 + 1], a_pts[i * 2 + 2], layer, color)
    end
end

function Canvas:rect_raw(x, y, width, height, layer, a, r, g, b)
    if a < 1 or not self._gui or self._count >= self._limit then return end

    x = x + self._dx
    y = y + self._dy

    local x2 = x + width
    local y2 = y + height

    if x < self._cx0 then x = self._cx0 end
    if y < self._cy0 then y = self._cy0 end
    if x2 > self._cx1 then x2 = self._cx1 end
    if y2 > self._cy1 then y2 = self._cy1 end
    if x2 <= x or y2 <= y then return end

    local scale = self._scale

    Gui.rect(self._gui,
        Vector3((self._ox + x) * scale, (self._oy + y) * scale, self._base_layer + layer * self._layer_scale),
        Vector2((x2 - x) * scale, (y2 - y) * scale),
        Color(math_floor(clamp_byte(a)), math_floor(clamp_byte(r)), math_floor(clamp_byte(g)), math_floor(clamp_byte(b))))
    self._count = self._count + 1
end

-- Color helpers ------------------------------------------------------------

-- Returns a, r, g, b for color scaled by brightness and optional white mix.
local function shade(color, alpha, brightness, white)
    local a = alpha or color[1]
    brightness = brightness or 1
    white = white or 0
    local r = color[2] * brightness
    local g = color[3] * brightness
    local b = color[4] * brightness

    if white > 0 then
        r = r + (255 - r) * white
        g = g + (255 - g) * white
        b = b + (255 - b) * white
    end

    return a, r, g, b
end

Canvas.shade = shade

function Canvas.lerp_color(out, c1, c2, t)
    out[1] = c1[1] + (c2[1] - c1[1]) * t
    out[2] = c1[2] + (c2[2] - c1[2]) * t
    out[3] = c1[3] + (c2[3] - c1[3]) * t
    out[4] = c1[4] + (c2[4] - c1[4]) * t
    return out
end

function Canvas.hsv(out, h, s, v, a)
    h = (h % 1) * 6
    local i = math_floor(h)
    local f = h - i
    local p = v * (1 - s)
    local q = v * (1 - s * f)
    local t = v * (1 - s * (1 - f))
    local r, g, b

    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end

    out[1] = a or 255
    out[2] = r * 255
    out[3] = g * 255
    out[4] = b * 255
    return out
end

-- Shapes -------------------------------------------------------------------

function Canvas:rect(x, y, width, height, layer, color, alpha, brightness, white)
    local a, r, g, b = shade(color, alpha, brightness, white)
    self:rect_raw(x, y, width, height, layer, a, r, g, b)
end

function Canvas:tri(x1, y1, x2, y2, x3, y3, layer, color, alpha, brightness, white)
    local a, r, g, b = shade(color, alpha, brightness, white)
    self:tri_raw(x1, y1, x2, y2, x3, y3, layer, a, r, g, b)
end

function Canvas:quad(x1, y1, x2, y2, x3, y3, x4, y4, layer, color, alpha, brightness, white)
    local a, r, g, b = shade(color, alpha, brightness, white)
    self:tri_raw(x1, y1, x2, y2, x3, y3, layer, a, r, g, b)
    self:tri_raw(x1, y1, x3, y3, x4, y4, layer, a, r, g, b)
end

function Canvas:line(x1, y1, x2, y2, thickness, layer, color, alpha, brightness, white)
    local ddx = x2 - x1
    local ddy = y2 - y1
    local length = math_sqrt(ddx * ddx + ddy * ddy)

    if length < 0.05 then return end

    local half = thickness * 0.5
    local nx = -ddy / length * half
    local ny = ddx / length * half
    local a, r, g, b = shade(color, alpha, brightness, white)

    self:tri_raw(x1 + nx, y1 + ny, x2 + nx, y2 + ny, x2 - nx, y2 - ny, layer, a, r, g, b)
    self:tri_raw(x1 + nx, y1 + ny, x2 - nx, y2 - ny, x1 - nx, y1 - ny, layer, a, r, g, b)
end

-- Line with a soft halo: wide faint passes under a bright thin core.
function Canvas:glow_line(x1, y1, x2, y2, thickness, layer, color, alpha, spread)
    spread = spread or 3
    alpha = alpha or color[1]
    self:line(x1, y1, x2, y2, thickness * spread * 2, layer - 0.02, color, alpha * 0.12)
    self:line(x1, y1, x2, y2, thickness * spread, layer - 0.01, color, alpha * 0.25)
    self:line(x1, y1, x2, y2, thickness, layer, color, alpha)
    self:line(x1, y1, x2, y2, math_max(0.6, thickness * 0.4), layer + 0.01, color, alpha, 1, 0.65)
end

function Canvas:ellipse(cx, cy, rx, ry, layer, color, alpha, brightness, white, segments)
    segments = segments or segments_for(math_max(rx, ry))
    local circle = unit_circle(segments)
    local a, r, g, b = shade(color, alpha, brightness, white)

    for i = 0, segments - 1 do
        local j = i * 2
        self:tri_raw(cx, cy,
            cx + circle[j + 1] * rx, cy + circle[j + 2] * ry,
            cx + circle[j + 3] * rx, cy + circle[j + 4] * ry,
            layer, a, r, g, b)
    end
end

function Canvas:circle(cx, cy, radius, layer, color, alpha, brightness, white, segments)
    self:ellipse(cx, cy, radius, radius, layer, color, alpha, brightness, white, segments)
end

function Canvas:ring(cx, cy, radius, thickness, layer, color, alpha, segments, from_angle, to_angle, brightness, white)
    segments = segments or segments_for(radius)
    from_angle = from_angle or 0
    to_angle = to_angle or TAU

    local a, r, g, b = shade(color, alpha, brightness, white)
    local inner = math_max(0, radius - thickness * 0.5)
    local outer = radius + thickness * 0.5
    local step = (to_angle - from_angle) / segments
    local c0 = math_cos(from_angle)
    local s0 = math_sin(from_angle)

    for i = 1, segments do
        local angle = from_angle + step * i
        local c1 = math_cos(angle)
        local s1 = math_sin(angle)
        local ax, ay = cx + c0 * outer, cy + s0 * outer
        local bx, by = cx + c1 * outer, cy + s1 * outer
        local qx, qy = cx + c1 * inner, cy + s1 * inner
        local dx, dy = cx + c0 * inner, cy + s0 * inner

        self:tri_raw(ax, ay, bx, by, qx, qy, layer, a, r, g, b)
        self:tri_raw(ax, ay, qx, qy, dx, dy, layer, a, r, g, b)
        c0, s0 = c1, s1
    end
end

-- Soft radial glow built from stacked translucent discs.
function Canvas:glow(cx, cy, radius, layer, color, alpha, steps, brightness, white)
    alpha = alpha or color[1]

    if radius < 0.5 or alpha < 2 then return end

    steps = steps or math_max(3, math_min(8, math_floor(radius / 10) + 2))

    local per_step = alpha / steps
    local segments = segments_for(radius)

    for i = steps, 1, -1 do
        local rr = radius * (i / steps) ^ 1.25
        self:ellipse(cx, cy, rr, rr, layer + (steps - i) * 0.001, color, per_step, brightness, white, segments)
    end
end

-- Radial glow with a hot white-ish core, useful for projectiles and pickups.
function Canvas:orb(cx, cy, radius, layer, color, alpha, halo)
    alpha = alpha or color[1]
    halo = halo or 3
    self:glow(cx, cy, radius * halo, layer - 0.02, color, alpha * 0.45, 4)
    self:circle(cx, cy, radius, layer, color, alpha)
    self:circle(cx - radius * 0.25, cy - radius * 0.25, radius * 0.55, layer + 0.01, color, alpha, 1, 0.55)
    self:circle(cx - radius * 0.38, cy - radius * 0.38, radius * 0.2, layer + 0.02, color, alpha * 0.9, 1, 0.95)
end

function Canvas:soft_rect(x, y, width, height, spread, layer, color, alpha, steps)
    steps = steps or 4
    alpha = alpha or color[1]
    local per_step = alpha / steps

    for i = steps, 1, -1 do
        local grow = spread * i / steps
        self:rect(x - grow, y - grow, width + grow * 2, height + grow * 2, layer + (steps - i) * 0.001, color, per_step)
    end
end

function Canvas:vgradient(x, y, width, height, layer, color_top, color_bottom, alpha_top, alpha_bottom, bands)
    bands = bands or math_max(2, math_min(48, math_floor(height / 6)))
    alpha_top = alpha_top or color_top[1]
    alpha_bottom = alpha_bottom or color_bottom[1]

    local band_h = height / bands

    for i = 0, bands - 1 do
        local t = (i + 0.5) / bands
        self:rect_raw(x, y + i * band_h, width, band_h + 0.35, layer,
            alpha_top + (alpha_bottom - alpha_top) * t,
            color_top[2] + (color_bottom[2] - color_top[2]) * t,
            color_top[3] + (color_bottom[3] - color_top[3]) * t,
            color_top[4] + (color_bottom[4] - color_top[4]) * t)
    end
end

function Canvas:hgradient(x, y, width, height, layer, color_left, color_right, alpha_left, alpha_right, bands)
    bands = bands or math_max(2, math_min(48, math_floor(width / 6)))
    alpha_left = alpha_left or color_left[1]
    alpha_right = alpha_right or color_right[1]

    local band_w = width / bands

    for i = 0, bands - 1 do
        local t = (i + 0.5) / bands
        self:rect_raw(x + i * band_w, y, band_w + 0.35, height, layer,
            alpha_left + (alpha_right - alpha_left) * t,
            color_left[2] + (color_right[2] - color_left[2]) * t,
            color_left[3] + (color_right[3] - color_left[3]) * t,
            color_left[4] + (color_right[4] - color_left[4]) * t)
    end
end

-- Convex polygon from flat coordinate array { x1, y1, x2, y2, ... }.
function Canvas:poly(points, count, layer, color, alpha, brightness, white, ox, oy)
    ox = ox or 0
    oy = oy or 0
    local a, r, g, b = shade(color, alpha, brightness, white)
    local x1 = points[1] + ox
    local y1 = points[2] + oy

    for i = 2, count - 1 do
        local j = i * 2
        self:tri_raw(x1, y1, points[j - 1] + ox, points[j] + oy, points[j + 1] + ox, points[j + 2] + oy, layer, a, r, g, b)
    end
end

function Canvas:polyline(points, count, closed, thickness, layer, color, alpha, brightness, white, ox, oy)
    ox = ox or 0
    oy = oy or 0
    local last = closed and count or count - 1

    for i = 1, last do
        local j = i * 2
        local k = (i % count) * 2
        self:line(points[j - 1] + ox, points[j] + oy, points[k + 1] + ox, points[k + 2] + oy, thickness, layer, color, alpha, brightness, white)
    end
end

-- Chiselled block: lit top/left, shaded bottom/right, inner face and gloss.
function Canvas:bevel_box(x, y, width, height, bevel, layer, color, alpha, light, dark)
    alpha = alpha or color[1]
    light = light or 0.55
    dark = dark or 0.42
    local x2 = x + width
    local y2 = y + height
    local ix = x + bevel
    local iy = y + bevel
    local ix2 = x2 - bevel
    local iy2 = y2 - bevel
    local a, r, g, b

    a, r, g, b = shade(color, alpha, 1, light)
    self:tri_raw(x, y, x2, y, ix2, iy, layer, a, r, g, b)
    self:tri_raw(x, y, ix2, iy, ix, iy, layer, a, r, g, b)
    a, r, g, b = shade(color, alpha, 1, light * 0.55)
    self:tri_raw(x, y, ix, iy, ix, iy2, layer, a, r, g, b)
    self:tri_raw(x, y, ix, iy2, x, y2, layer, a, r, g, b)
    a, r, g, b = shade(color, alpha, dark)
    self:tri_raw(x, y2, ix, iy2, ix2, iy2, layer, a, r, g, b)
    self:tri_raw(x, y2, ix2, iy2, x2, y2, layer, a, r, g, b)
    a, r, g, b = shade(color, alpha, dark * 1.35)
    self:tri_raw(x2, y, x2, y2, ix2, iy2, layer, a, r, g, b)
    self:tri_raw(x2, y, ix2, iy2, ix2, iy, layer, a, r, g, b)

    local face_h = iy2 - iy
    self:vgradient(ix, iy, ix2 - ix, face_h, layer + 0.01, color, color, alpha, alpha, 3)
    a, r, g, b = shade(color, alpha * 0.55, 1, 0.5)
    self:rect_raw(ix, iy, ix2 - ix, face_h * 0.38, layer + 0.02, a, r, g, b)
    a, r, g, b = shade(color, alpha * 0.35, 0.55)
    self:rect_raw(ix, iy + face_h * 0.72, ix2 - ix, face_h * 0.28, layer + 0.02, a, r, g, b)
    self:rect_raw(ix + 1, iy + 1, math_max(1, (ix2 - ix) * 0.28), 1.2, layer + 0.03, alpha * 0.85, 255, 255, 255)
end

-- Screen treatments ----------------------------------------------------------

function Canvas:scanlines(x, y, width, height, spacing, layer, alpha, drift)
    spacing = spacing or 3
    drift = (drift or 0) % spacing

    for yy = y + drift, y + height, spacing do
        self:rect_raw(x, yy, width, 1, layer, alpha, 0, 0, 0)
    end
end

function Canvas:vignette(x, y, width, height, depth, layer, alpha, steps, color)
    steps = steps or 8
    local r, g, b = 0, 0, 0

    if color then r, g, b = color[2], color[3], color[4] end

    local band = depth / steps

    for i = 0, steps - 1 do
        local t = 1 - i / steps
        local a = alpha * t * t
        local inset = i * band
        self:rect_raw(x + inset, y + inset, width - inset * 2, band, layer, a, r, g, b)
        self:rect_raw(x + inset, y + height - inset - band, width - inset * 2, band, layer, a, r, g, b)
        self:rect_raw(x + inset, y + inset + band, band, height - inset * 2 - band * 2, layer, a, r, g, b)
        self:rect_raw(x + width - inset - band, y + inset + band, band, height - inset * 2 - band * 2, layer, a, r, g, b)
    end
end

-- Auspex sweep: a bright bar travelling down with a fading phosphor trail.
function Canvas:sweep(x, y, width, height, t, period, layer, color, alpha, trail)
    trail = trail or 70
    local p = (t % period) / period
    local sy = y + p * (height + trail) - trail * 0.2
    local bands = 10

    for i = 1, bands do
        local k = i / bands
        local yy = sy - trail * k
        local a = alpha * (1 - k) * (1 - k) * 0.5

        if yy + trail / bands > y and yy < y + height then
            local top = math_max(y, yy)
            local bottom = math_min(y + height, yy + trail / bands)
            if bottom > top then
                self:rect_raw(x, top, width, bottom - top, layer, a, color[2], color[3], color[4])
            end
        end
    end

    if sy > y and sy < y + height then
        self:rect_raw(x, sy, width, 1.5, layer + 0.01, alpha, color[2], color[3], color[4])
    end
end

-- Radar wedge sweeping around cx, cy with fading trail.
function Canvas:radar(cx, cy, radius, angle, layer, color, alpha, trail_angle, slices)
    slices = slices or 14
    trail_angle = trail_angle or 1.1

    for i = 0, slices - 1 do
        local a0 = angle - trail_angle * (i + 1) / slices
        local a1 = angle - trail_angle * i / slices
        local k = 1 - i / slices
        self:tri_raw(cx, cy,
            cx + math_cos(a0) * radius, cy + math_sin(a0) * radius,
            cx + math_cos(a1) * radius, cy + math_sin(a1) * radius,
            layer, alpha * k * k * 0.5, color[2], color[3], color[4])
    end

    self:line(cx, cy, cx + math_cos(angle) * radius, cy + math_sin(angle) * radius, 1.5, layer + 0.01, color, alpha)
end

-- Deterministic flicker noise specks; seed changes per frame bucket.
function Canvas:static_noise(x, y, width, height, count, seed, layer, color, alpha)
    local s = seed % 2147483646 + 1

    for _ = 1, count do
        s = (s * 16807) % 2147483647
        local px = x + (s % 10007) / 10007 * width
        s = (s * 16807) % 2147483647
        local py = y + (s % 10007) / 10007 * height
        s = (s * 16807) % 2147483647
        local w = 1 + (s % 7)
        self:rect_raw(px, py, w, 1, layer, alpha * (0.35 + (s % 13) / 20), color[2], color[3], color[4])
    end
end

-- Full auspex post-process: scanlines, rolling sweep, vignette, faint static.
function Canvas:crt(x, y, width, height, t, layer, opts)
    opts = opts or {}
    local tint = opts.tint or { 255, 60, 255, 170 }

    if opts.scanlines ~= false then
        self:scanlines(x, y, width, height, opts.spacing or 3, layer, opts.scan_alpha or 34, t * (opts.scan_speed or 9))
    end

    self:sweep(x, y, width, height, t, opts.sweep_period or 5.5, layer + 0.01, tint, opts.sweep_alpha or 26, opts.sweep_trail or 90)
    self:vignette(x, y, width, height, opts.vignette_depth or 70, layer + 0.02, opts.vignette_alpha or 150, 8)

    local flicker = 0.5 + 0.5 * math_sin(t * 61) * math_sin(t * 23.3)
    if opts.flicker ~= false then
        self:rect_raw(x, y, width, height, layer + 0.03, 3 + flicker * 5, tint[2], tint[3], tint[4])
    end

    if opts.noise ~= false then
        self:static_noise(x, y, width, height, opts.noise_count or 22, math_floor(t * 24) + 17, layer + 0.04, tint, opts.noise_alpha or 40)
    end
end

-- Particles ----------------------------------------------------------------

local Particles = {}
Particles.__index = Particles

function Particles.new(max_particles)
    local self = setmetatable({ _max = max_particles or 256, _count = 0, _items = {} }, Particles)

    for i = 1, self._max do
        self._items[i] = {}
    end

    return self
end

function Particles:clear()
    self._count = 0
end

function Particles:count()
    return self._count
end

function Particles:emit(x, y, vx, vy, life, size, color, kind, drag, gravity, spin)
    local index = self._count + 1

    if index > self._max then
        index = math_random(1, self._max)
    else
        self._count = index
    end

    local p = self._items[index]
    p.x = x
    p.y = y
    p.vx = vx or 0
    p.vy = vy or 0
    p.life = life
    p.max_life = life
    p.size = size or 2
    p.color = color
    p.kind = kind or "spark"
    p.drag = drag or 2.2
    p.gravity = gravity or 0
    p.spin = spin or 0
    p.angle = math_random() * TAU

    return p
end

function Particles:burst(x, y, count, speed_min, speed_max, life_min, life_max, size, color, kind, drag, gravity, angle, spread)
    angle = angle or 0
    spread = spread or TAU

    for _ = 1, count do
        local a = angle + (math_random() - 0.5) * spread
        local speed = speed_min + (speed_max - speed_min) * math_random()
        local life = life_min + (life_max - life_min) * math_random()
        self:emit(x, y, math_cos(a) * speed, math_sin(a) * speed, life, size * (0.6 + math_random() * 0.8), color, kind, drag, gravity, (math_random() - 0.5) * 14)
    end
end

function Particles:shockwave(x, y, radius, life, color, thickness)
    local p = self:emit(x, y, 0, 0, life, thickness or 3, color, "ring", 0, 0, 0)
    p.radius = radius
    return p
end

function Particles:flash(x, y, radius, life, color)
    local p = self:emit(x, y, 0, 0, life, radius, color, "flash", 0, 0, 0)
    return p
end

function Particles:update(dt)
    local items = self._items
    local i = 1

    while i <= self._count do
        local p = items[i]
        p.life = p.life - dt

        if p.life <= 0 then
            items[i] = items[self._count]
            items[self._count] = p
            self._count = self._count - 1
        else
            local damping = 1 / (1 + p.drag * dt)
            p.vx = p.vx * damping
            p.vy = p.vy * damping + p.gravity * dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.angle = p.angle + p.spin * dt
            i = i + 1
        end
    end
end

function Particles:draw(canvas, layer)
    local items = self._items

    for i = 1, self._count do
        local p = items[i]
        local k = p.life / p.max_life
        local color = p.color
        local alpha = color[1] * k
        local kind = p.kind

        if kind == "spark" then
            local tail = 0.045 + (1 - k) * 0.02
            local x2 = p.x - p.vx * tail
            local y2 = p.y - p.vy * tail
            canvas:line(x2, y2, p.x, p.y, p.size * 2.6 * k + 0.6, layer - 0.01, color, alpha * 0.25)
            canvas:line(x2, y2, p.x, p.y, p.size * k + 0.5, layer, color, alpha, 1, 0.35 * k)
        elseif kind == "ember" then
            local size = p.size * (0.35 + k * 0.65)
            canvas:circle(p.x, p.y, size * 2.4, layer - 0.01, color, alpha * 0.22)
            canvas:rect(p.x - size * 0.5, p.y - size * 0.5, size, size, layer, color, alpha, 1, 0.45 * k)
        elseif kind == "ring" then
            local e = 1 - k
            local radius = (p.radius or 30) * (1 - (1 - e) * (1 - e) * (1 - e))
            canvas:ring(p.x, p.y, radius, p.size * (0.4 + k), layer, color, alpha)
            canvas:ring(p.x, p.y, radius * 0.93, p.size * 2.6 * k + 1, layer - 0.01, color, alpha * 0.22)
        elseif kind == "flash" then
            canvas:glow(p.x, p.y, p.size * (0.6 + (1 - k) * 0.6), layer, color, alpha, 5, 1, 0.3 * k)
        elseif kind == "shard" then
            local size = p.size * (0.5 + k * 0.5)
            local c = math_cos(p.angle) * size
            local s = math_sin(p.angle) * size
            canvas:tri(p.x + c, p.y + s, p.x - s * 0.6 - c * 0.4, p.y + c * 0.6 - s * 0.4, p.x + s * 0.6 - c * 0.4, p.y - c * 0.6 - s * 0.4, layer, color, alpha)
        elseif kind == "smoke" then
            local size = p.size * (1.8 - k * 0.8)
            canvas:circle(p.x, p.y, size, layer - 0.02, color, alpha * 0.3)
        else
            local size = p.size * (0.4 + k * 0.6)
            canvas:rect(p.x - size * 0.5, p.y - size * 0.5, size, size, layer, color, alpha)
        end
    end
end

-- Screen shake helper with decaying trauma.
local Shaker = {}
Shaker.__index = Shaker

function Shaker.new()
    return setmetatable({ trauma = 0, x = 0, y = 0, t = 0 }, Shaker)
end

function Shaker:add(amount)
    self.trauma = math_min(1, self.trauma + amount)
end

function Shaker:update(dt, magnitude)
    self.t = self.t + dt
    self.trauma = math_max(0, self.trauma - dt * 1.6)
    local power = self.trauma * self.trauma * (magnitude or 9)
    self.x = math_sin(self.t * 83.1) * math_cos(self.t * 41.7) * power
    self.y = math_sin(self.t * 71.3 + 1.7) * math_cos(self.t * 37.9) * power
end

return {
    Canvas = Canvas,
    Particles = Particles,
    Shaker = Shaker,
    unit_circle = unit_circle,
}
