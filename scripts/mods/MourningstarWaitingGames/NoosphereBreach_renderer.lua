local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_sin = math.sin
local math_sqrt = math.sqrt

local CANVAS_W = 600
local CANVAS_H = 480
local MAX_ENVIRONMENT_SUBMISSIONS = 2600
local MAX_SUBMISSIONS = 5200
local MAX_ENTITIES = 128

local COLORS = {
    floor_a = { 255, 3, 17, 20 },
    floor_b = { 255, 5, 25, 28 },
    floor_recess = { 255, 2, 11, 16 },
    chassis = { 255, 8, 24, 31 },
    brass = { 210, 158, 134, 79 },
    floor_edge = { 175, 20, 125, 118 },
    circuit = { 130, 35, 225, 190 },
    circuit_hot = { 210, 125, 255, 210 },
    corruption = { 235, 74, 10, 71 },
    corruption_hot = { 235, 245, 36, 180 },
    wall_top = { 255, 38, 81, 78 },
    wall_left = { 255, 15, 38, 43 },
    wall_right = { 255, 22, 52, 51 },
    wall_edge = { 220, 100, 205, 176 },
    shadow = { 145, 0, 0, 0 },
    player = { 255, 37, 225, 205 },
    player_hot = { 255, 208, 255, 238 },
    player_dark = { 255, 9, 57, 61 },
    dash = { 225, 65, 210, 255 },
    wisp = { 235, 219, 53, 205 },
    wisp_hot = { 255, 255, 177, 237 },
    sentry = { 255, 236, 74, 44 },
    sentry_hot = { 255, 255, 210, 87 },
    sentry_dark = { 255, 78, 21, 23 },
    cortex = { 255, 147, 62, 235 },
    cortex_hot = { 255, 240, 200, 255 },
    cortex_dark = { 255, 39, 15, 65 },
    projectile = { 255, 205, 255, 232 },
    enemy_projectile = { 255, 255, 67, 112 },
    warning = { 210, 255, 47, 65 },
    particle = { 220, 83, 238, 203 },
    white = { 255, 245, 255, 250 },
}

local function sort_queue(queue, count)
    for i = 2, count do
        local entry = queue[i]
        local j = i - 1

        while j >= 1 do
            local previous = queue[j]
            local follows = previous.depth > entry.depth
                or previous.depth == entry.depth and previous.order > entry.order

            if not follows then break end

            queue[j + 1] = previous
            j = j - 1
        end

        queue[j + 1] = entry
    end
end

local function cell_at(map, x, y)
    local row = map and map[y]

    if type(row) == "string" then
        return string.sub(row, x, x)
    elseif type(row) == "table" then
        return row[x]
    end

    return nil
end

local function cell_kind(cell)
    if type(cell) == "table" then
        return cell.kind or cell.type or cell.tile
    end

    return cell
end

local function is_wall(cell)
    if type(cell) == "table" and cell.wall ~= nil then
        return cell.wall
    end

    local kind = cell_kind(cell)

    return kind == "#" or kind == "wall" or kind == "WALL" or kind == 1
end

local function is_corrupted(cell)
    if type(cell) == "table" and cell.corrupted ~= nil then
        return cell.corrupted
    end

    local kind = cell_kind(cell)

    return kind == "~" or kind == "X" or kind == "corrupt" or kind == "corrupted" or kind == 2
end

local function color_with_alpha(color, alpha, brightness)
    local a = math_floor(math_max(0, math_min(color[1], alpha)))

    if brightness and brightness ~= 1 then
        return Color(a,
            math_floor(math_min(255, color[2] * brightness)),
            math_floor(math_min(255, color[3] * brightness)),
            math_floor(math_min(255, color[4] * brightness)))
    end

    return Color(a, color[2], color[3], color[4])
end

local CIRCLE_SEGMENTS = {}
for segments = 6, 32, 2 do
    local points = {}
    for i = 0, segments do
        local angle = i / segments * math_pi * 2
        points[i * 2 + 1] = math_cos(angle)
        points[i * 2 + 2] = math_sin(angle)
    end
    CIRCLE_SEGMENTS[segments] = points
end

local NoosphereBreachRenderer = {}
NoosphereBreachRenderer.__index = NoosphereBreachRenderer

function NoosphereBreachRenderer.new()
    local self = setmetatable({}, NoosphereBreachRenderer)

    self._queue = {}
    self._queue_count = 0
    self._submission_count = 0
    self._submission_limit = MAX_SUBMISSIONS
    self._origin_x = 0
    self._origin_y = 0
    self._scale = 1
    self._base_layer = 0
    self._tile_w = 34
    self._tile_h = 17
    self._map_w = 1
    self._map_h = 1
    self._map_left = 0
    self._map_top = 88
    self._center_x = CANVAS_W * 0.5
    self._shake_x = 0
    self._shake_y = 0
    self._light_x = 0
    self._light_y = 0
    self._fx = {}
    self._known_enemies = {}
    self._seen_enemies = {}

    return self
end

function NoosphereBreachRenderer:_can_submit(amount)
    return self._submission_count + (amount or 1) <= self._submission_limit
end

function NoosphereBreachRenderer:_triangle(x1, y1, x2, y2, x3, y3, layer, color, alpha, brightness)
    if not self:_can_submit(1) then return end

    local min_x = math_min(x1, x2, x3)
    local max_x = math_max(x1, x2, x3)
    local min_y = math_min(y1, y2, y3)
    local max_y = math_max(y1, y2, y3)

    if max_x < 1 or min_x > CANVAS_W - 1 or max_y < 1 or min_y > CANVAS_H - 1 then return end

    local scale = self._scale
    local ox = self._origin_x
    local oy = self._origin_y
    local a = Vector3((ox + x1) * scale, 0, (oy + y1) * scale)
    local b = Vector3((ox + x2) * scale, 0, (oy + y2) * scale)
    local c = Vector3((ox + x3) * scale, 0, (oy + y3) * scale)

    Gui.triangle(self._gui, a, b, c, self._base_layer + layer, color_with_alpha(color, alpha or color[1], brightness))
    self._submission_count = self._submission_count + 1
end

function NoosphereBreachRenderer:_rect(x, y, width, height, layer, color, alpha, brightness)
    if not self:_can_submit(1) then return end

    local x2 = x + width
    local y2 = y + height

    if x2 <= 1 or x >= CANVAS_W - 1 or y2 <= 1 or y >= CANVAS_H - 1 then return end

    x = math_max(1, x)
    y = math_max(1, y)
    x2 = math_min(CANVAS_W - 1, x2)
    y2 = math_min(CANVAS_H - 1, y2)

    if x2 <= x or y2 <= y then return end

    local scale = self._scale
    local position = Vector3((self._origin_x + x) * scale, (self._origin_y + y) * scale, self._base_layer + layer)
    local size = Vector2((x2 - x) * scale, (y2 - y) * scale)

    Gui.rect(self._gui, position, size, color_with_alpha(color, alpha or color[1], brightness))
    self._submission_count = self._submission_count + 1
end

function NoosphereBreachRenderer:_clip_line(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local t0 = 0
    local t1 = 1
    local p1, p2, p3, p4 = -dx, dx, -dy, dy
    local q1, q2, q3, q4 = x1 - 1, CANVAS_W - 1 - x1, y1 - 1, CANVAS_H - 1 - y1

    if p1 == 0 and q1 < 0 or p2 == 0 and q2 < 0 or p3 == 0 and q3 < 0 or p4 == 0 and q4 < 0 then
        return nil
    end

    if p1 ~= 0 then
        local r = q1 / p1
        if p1 < 0 then t0 = math_max(t0, r) else t1 = math_min(t1, r) end
    end
    if p2 ~= 0 then
        local r = q2 / p2
        if p2 < 0 then t0 = math_max(t0, r) else t1 = math_min(t1, r) end
    end
    if p3 ~= 0 then
        local r = q3 / p3
        if p3 < 0 then t0 = math_max(t0, r) else t1 = math_min(t1, r) end
    end
    if p4 ~= 0 then
        local r = q4 / p4
        if p4 < 0 then t0 = math_max(t0, r) else t1 = math_min(t1, r) end
    end

    if t0 > t1 then return nil end

    return x1 + dx * t0, y1 + dy * t0, x1 + dx * t1, y1 + dy * t1
end

function NoosphereBreachRenderer:_line(x1, y1, x2, y2, thickness, layer, color, alpha)
    if not self:_can_submit(2) then return end

    x1, y1, x2, y2 = self:_clip_line(x1, y1, x2, y2)

    if not x1 then return end

    local dx = x2 - x1
    local dy = y2 - y1
    local length = math_sqrt(dx * dx + dy * dy)

    if length < 0.1 then return end

    local half = thickness * 0.5
    local nx = -dy / length * half
    local ny = dx / length * half

    self:_triangle(x1 + nx, y1 + ny, x2 + nx, y2 + ny, x2 - nx, y2 - ny, layer, color, alpha)
    self:_triangle(x1 + nx, y1 + ny, x2 - nx, y2 - ny, x1 - nx, y1 - ny, layer, color, alpha)
end

function NoosphereBreachRenderer:_ring(x, y, radius_x, radius_y, segments, thickness, layer, color, alpha, phase)
    phase = phase or 0

    for i = 1, segments do
        local a1 = phase + (i - 1) / segments * math_pi * 2
        local a2 = phase + i / segments * math_pi * 2

        self:_line(
            x + math_cos(a1) * radius_x,
            y + math_sin(a1) * radius_y,
            x + math_cos(a2) * radius_x,
            y + math_sin(a2) * radius_y,
            thickness,
            layer,
            color,
            alpha
        )
    end
end

function NoosphereBreachRenderer:_circle(x, y, radius_x, radius_y, layer, color, alpha, brightness)
    if radius_x < 0.4 then return end

    local segments = radius_x < 5 and 8 or radius_x < 14 and 12 or radius_x < 40 and 18 or 24
    local points = CIRCLE_SEGMENTS[segments]

    for i = 0, segments - 1 do
        local j = i * 2
        self:_triangle(x, y,
            x + points[j + 1] * radius_x, y + points[j + 2] * radius_y,
            x + points[j + 3] * radius_x, y + points[j + 4] * radius_y,
            layer, color, alpha, brightness)
    end
end

-- Soft bloom made from stacked translucent discs.
function NoosphereBreachRenderer:_glow(x, y, radius, layer, color, alpha, steps, squash)
    steps = steps or 4
    squash = squash or 1
    local per_step = alpha / steps

    for i = steps, 1, -1 do
        local r = radius * (i / steps) ^ 1.25
        self:_circle(x, y, r, r * squash, layer + (steps - i) * 0.0005, color, per_step)
    end
end

function NoosphereBreachRenderer:_update_fx(game, time)
    local dt = self._last_time and math_max(0, math_min(0.1, time - self._last_time)) or 0
    self._last_time = time
    self._dt = dt

    local fx = self._fx
    for i = #fx, 1, -1 do
        local e = fx[i]
        e.life = e.life - dt
        if e.life <= 0 then table.remove(fx, i) end
    end

    local known = self._known_enemies
    local seen = self._seen_enemies
    for enemy in pairs(seen) do seen[enemy] = nil end

    local enemies = game:enemies() or {}
    for i = 1, #enemies do
        local enemy = enemies[i]
        if enemy.alive ~= false then seen[enemy] = true end
    end

    for enemy, info in pairs(known) do
        if not seen[enemy] then
            local kind = info.kind
            local color = (kind == "Sentry" or kind == "sentry") and COLORS.sentry_hot
                or (kind == "Cortex" or kind == "cortex") and COLORS.cortex_hot
                or COLORS.wisp_hot
            local big = kind == "Cortex" or kind == "cortex"
            if #fx < 40 then
                fx[#fx + 1] = { x = info.x, y = info.y, life = big and 1.2 or 0.55, max_life = big and 1.2 or 0.55, radius = big and 5 or 1.6, color = color }
            end
            known[enemy] = nil
        end
    end

    for i = 1, #enemies do
        local enemy = enemies[i]
        if enemy.alive ~= false then
            local info = known[enemy]
            if not info then
                info = {}
                known[enemy] = info
            end
            info.x, info.y, info.kind = enemy.x or 0, enemy.y or 0, enemy.kind
        end
    end
end

function NoosphereBreachRenderer:_draw_fx()
    local fx = self._fx

    for i = 1, #fx do
        local e = fx[i]
        local k = e.life / e.max_life
        local x, y = self:_project(e.x, e.y, 0)
        local grow = 1 - k * k * k
        local r = e.radius * self._tile_w * (0.3 + grow * 0.9)
        self:_ring(x, y, r, r * 0.62, 20, 2.5 * k + 0.5, 16.5, e.color, 230 * k, 0)
        self:_glow(x, y, r * 0.8, 16.4, e.color, 120 * k * k, 3, 0.62)
    end
end

function NoosphereBreachRenderer:_draw_post(time)
    local h = CANVAS_H
    local w = CANVAS_W
    local drift = (time * 9) % 3

    for y = 1 + drift, h - 1, 3 do
        self:_rect(1, y, w - 2, 1, 19, COLORS.shadow, 40)
    end

    local sweep = (time % 5) / 5 * (h + 80) - 40
    for i = 0, 7 do
        local yy = sweep - i * 8
        self:_rect(1, yy, w - 2, 8, 19.01, COLORS.circuit, (1 - i / 8) ^ 2 * 18)
    end

    for i = 0, 7 do
        local k = 1 - i / 8
        local a = 150 * k * k
        local inset = i * 9
        self:_rect(1 + inset, 1 + inset, w - 2 - inset * 2, 9, 19.02, COLORS.shadow, a)
        self:_rect(1 + inset, h - 10 - inset, w - 2 - inset * 2, 9, 19.02, COLORS.shadow, a)
        self:_rect(1 + inset, 10 + inset, 9, h - 20 - inset * 2, 19.02, COLORS.shadow, a)
        self:_rect(w - 10 - inset, 10 + inset, 9, h - 20 - inset * 2, 19.02, COLORS.shadow, a)
    end
end

function NoosphereBreachRenderer:_project(x, y, z)
    local screen_x = self._map_left + x * self._tile_w + self._shake_x
    local screen_y = self._map_top + y * self._tile_h + self._shake_y

    return screen_x, screen_y
end

function NoosphereBreachRenderer:_diamond(cx, cy, half_w, half_h, layer, color, alpha)
    self:_triangle(cx, cy - half_h, cx + half_w, cy, cx, cy + half_h, layer, color, alpha)
    self:_triangle(cx, cy - half_h, cx, cy + half_h, cx - half_w, cy, layer, color, alpha)
end

function NoosphereBreachRenderer:_draw_tile(x, y, cell, time)
    local world_x = x - 0.5
    local world_y = y - 0.5
    local cx, cy = self:_project(world_x, world_y, 0)
    local half_w = self._tile_w * 0.5
    local half_h = self._tile_h * 0.5
    local depth_layer = 3
    local corrupted = is_corrupted(cell)
    local base_color = corrupted and COLORS.corruption or (x + y) % 2 == 0 and COLORS.floor_a or COLORS.floor_b
    local ldx = (world_x - self._light_x)
    local ldy = (world_y - self._light_y)
    local light = 0.55 + 1.6 / (1 + (ldx * ldx + ldy * ldy) * 0.35)

    self:_rect(cx - half_w + 0.5, cy - half_h + 0.5, self._tile_w - 1, self._tile_h - 1, depth_layer, base_color, nil, light)

    if is_wall(cell) then return end

    self:_rect(cx - half_w + 2, cy - half_h + 2, self._tile_w - 4, 1, depth_layer + 0.005, COLORS.floor_edge, 38)
    if (x * 3 + y * 7) % 5 == 0 then
        self:_rect(cx - half_w + 4, cy - half_h + 5, self._tile_w - 8, self._tile_h - 10, depth_layer + 0.006, COLORS.floor_recess, 145)
        self:_rect(cx + half_w - 5, cy + half_h - 5, 2, 2, depth_layer + 0.007, COLORS.brass, 95)
    end

    if corrupted then
        local flicker = 100 + (math_sin(time * 4.7 + x * 2.1 + y) + 1) * 48
        self:_line(cx - half_w * 0.58, cy + half_h * 0.42, cx + half_w * 0.62, cy - half_h * 0.48, 1.2, depth_layer + 0.01, COLORS.corruption_hot, flicker)
        self:_line(cx - half_w * 0.18, cy - half_h * 0.65, cx + half_w * 0.24, cy + half_h * 0.61, 1, depth_layer + 0.01, COLORS.corruption_hot, flicker * 0.75)
    elseif (x * 7 + y * 11) % 4 == 0 then
        local branch = ((x * 13 + y * 5) % 5 - 2) * half_w * 0.12
        self:_line(cx - half_w * 0.62, cy, cx + branch, cy, 0.9, depth_layer + 0.01, COLORS.circuit, 80)
        self:_line(cx + branch, cy, cx + half_w * 0.62, cy - half_h * 0.52, 0.9, depth_layer + 0.01, COLORS.circuit, 80)
        local pulse = 105 + (math_sin(time * 1.8 - x * 0.8 - y * 0.6) + 1) * 55
        self:_rect(cx + branch - 2, cy - 2, 4, 4, depth_layer + 0.015, COLORS.circuit, pulse * 0.22)
        self:_rect(cx + branch - 1, cy - 1, 2, 2, depth_layer + 0.02, COLORS.circuit_hot, pulse)
    elseif (x + y * 3) % 7 == 0 then
        self:_line(cx - half_w * 0.42, cy + half_h * 0.3, cx + half_w * 0.42, cy - half_h * 0.3, 0.7, depth_layer + 0.01, COLORS.floor_edge, 65)
    end
end

function NoosphereBreachRenderer:_draw_wall(x, y, cell, time)
    if not is_wall(cell) then return end

    local world_x = x - 0.5
    local world_y = y - 0.5
    local cx, cy = self:_project(world_x, world_y, 0)
    local half_w = self._tile_w * 0.5
    local half_h = self._tile_h * 0.5
    local layer = 6

    self:_rect(cx - half_w + 2, cy - half_h + 4, self._tile_w, self._tile_h, layer - 0.02, COLORS.shadow, 115)
    self:_rect(cx - half_w + 0.5, cy - half_h + 0.5, self._tile_w - 1, self._tile_h - 1, layer, COLORS.wall_left)
    self:_rect(cx - half_w + 3, cy - half_h + 3, self._tile_w - 6, self._tile_h - 8, layer + 0.01, COLORS.wall_top)
    self:_rect(cx - half_w + 1, cy - half_h + 1, self._tile_w - 2, 1.2, layer + 0.02, COLORS.wall_edge, 190)
    self:_rect(cx - half_w + 1, cy - half_h + 1, 1.2, self._tile_h - 3, layer + 0.02, COLORS.wall_edge, 115)
    self:_rect(cx - half_w + 3, cy + half_h - 5, self._tile_w - 6, 3, layer + 0.02, COLORS.chassis)
    self:_rect(cx - half_w + 6, cy - 3, self._tile_w - 12, 6, layer + 0.02, COLORS.wall_left)
    self:_rect(cx - half_w + 5, cy - half_h + 5, 2, 2, layer + 0.03, COLORS.brass, 175)
    self:_rect(cx + half_w - 7, cy + half_h - 9, 2, 2, layer + 0.03, COLORS.brass, 125)

    if (x * 3 + y) % 4 == 0 then
        local pulse = 95 + (math_sin(time * 2.2 + x + y) + 1) * 35
        self:_line(cx - half_w * 0.45, cy, cx + half_w * 0.45, cy, 1, layer + 0.03, COLORS.circuit_hot, pulse)
    end
end

function NoosphereBreachRenderer:_draw_environment(map, map_w, map_h, time)
    self._submission_limit = MAX_ENVIRONMENT_SUBMISSIONS

    local left = self._map_left + self._shake_x
    local top = self._map_top + self._shake_y
    local width = map_w * self._tile_w
    local height = map_h * self._tile_h
    self:_rect(left - 6, top + 6, width + 12, height + 7, 1, COLORS.shadow, 145)
    self:_rect(left - 5, top - 5, width + 10, height + 10, 1.1, COLORS.chassis)
    self:_rect(left - 5, top - 5, width + 10, 1, 1.2, COLORS.wall_edge, 155)
    self:_rect(left - 5, top - 4, 1, height + 8, 1.2, COLORS.wall_edge, 85)
    self:_rect(left - 5, top + height + 4, width + 10, 3, 1.2, COLORS.wall_left)
    for i = 1, 9 do
        local y = top + height * i / 10
        self:_rect(left - 13, y, i == 5 and 6 or 3, 1, 2, COLORS.circuit, 100)
        self:_rect(left + width + 10, y, i == 5 and 6 or 3, 1, 2, COLORS.circuit, 100)
    end

    for diagonal = 2, map_w + map_h do
        local min_y = math_max(1, diagonal - map_w)
        local max_y = math_min(map_h, diagonal - 1)

        for y = min_y, max_y do
            local x = diagonal - y
            self:_draw_tile(x, y, cell_at(map, x, y), time)
        end
    end

    for diagonal = 2, map_w + map_h do
        local min_y = math_max(1, diagonal - map_w)
        local max_y = math_min(map_h, diagonal - 1)

        for y = min_y, max_y do
            local x = diagonal - y
            self:_draw_wall(x, y, cell_at(map, x, y), time)
        end
    end

    self._submission_limit = MAX_SUBMISSIONS
end

function NoosphereBreachRenderer:_queue_entity(entity, kind, order)
    if not entity or entity.alive == false or self._queue_count >= MAX_ENTITIES then return end

    local index = self._queue_count + 1
    local entry = self._queue[index]

    if not entry then
        entry = {}
        self._queue[index] = entry
    end

    entry.entity = entity
    entry.kind = kind or entity.kind or "Wisp"
    entry.depth = (entity.x or 0) + (entity.y or 0)
    entry.order = order or index
    self._queue_count = index
end

function NoosphereBreachRenderer:_draw_shadow(entity, size, layer)
    local x, y = self:_project(entity.x or 0, entity.y or 0, 0)
    local pulse = 0.9 + math_sin(self._time * 3 + (entity.phase or 0)) * 0.08

    self:_diamond(x + 2, y + 3, size * pulse, size * pulse * 0.65, layer, COLORS.shadow, 115)
end

function NoosphereBreachRenderer:_draw_health_pips(entity, x, y, width, layer, color)
    local health = entity.health
    local max_health = entity.max_health

    if not health or not max_health or max_health <= 0 or health >= max_health then return end

    local fraction = math_max(0, math_min(1, health / max_health))

    self:_rect(x - width * 0.5, y, width, 2.5, layer, COLORS.shadow, 175)
    self:_rect(x - width * 0.5, y, width * fraction, 2.5, layer + 0.01, color, 230)
end

function NoosphereBreachRenderer:_draw_player(player, layer)
    local x, y = self:_project(player.x or 0, player.y or 0, 0)
    local phase = self._time * 5.5 + (player.phase or 0)
    local size = math_max(9, (player.size or 0.24) * self._tile_w * 1.45)
    local invulnerable = player.invulnerable or player.invulnerability or (player.invulnerability_time and player.invulnerability_time > 0)
    local dashing = player.dashing or player.dash_active or (player.dash_time and player.dash_time > 0)
    local main_color = invulnerable and COLORS.dash or COLORS.player
    local angle = player.angle or 0
    local dx = math_cos(angle)
    local dy = math_sin(angle)
    local side_x = -dy
    local side_y = dx

    self:_glow(x, y, size * 5, 3.6, COLORS.player, 55, 5)
    self:_draw_shadow(player, size * 0.72, layer - 0.03)
    self:_glow(x, y, size * 2.2, layer - 0.02, main_color, 70, 3)

    if dashing then
        for i = 1, 3 do
            local distance = size * (0.65 + i * 0.5)
            self:_line(x - dx * distance, y - dy * distance, x - dx * size * 0.35, y - dy * size * 0.35, 2.5 - i * 0.45, layer - 0.01, COLORS.dash, 145 - i * 25)
        end
    end

    self:_triangle(
        x + dx * size,
        y + dy * size,
        x - dx * size * 0.58 + side_x * size * 0.66,
        y - dy * size * 0.58 + side_y * size * 0.66,
        x - dx * size * 0.58 - side_x * size * 0.66,
        y - dy * size * 0.58 - side_y * size * 0.66,
        layer,
        main_color,
        240
    )
    self:_triangle(x + dx * size, y + dy * size, x, y,
        x - dx * size * 0.58 - side_x * size * 0.66,
        y - dy * size * 0.58 - side_y * size * 0.66,
        layer + 0.005, COLORS.player_dark, 195)
    self:_line(x + dx * size, y + dy * size,
        x - dx * size * 0.58 + side_x * size * 0.66,
        y - dy * size * 0.58 + side_y * size * 0.66,
        1, layer + 0.006, COLORS.player_hot, 205)
    self:_diamond(x, y, size * 0.34, size * 0.34, layer + 0.01, COLORS.player_hot, 245)
    self:_line(x, y, x + dx * size * 1.35, y + dy * size * 1.35, 2.6, layer + 0.04, COLORS.player_hot, 250)

    if invulnerable then
        self:_ring(x, y, size * 1.18, size * 1.18, 10, 1.5, layer + 0.06, COLORS.dash, 145, phase * 0.2)
    end
end

function NoosphereBreachRenderer:_draw_wisp(enemy, layer)
    local x, y = self:_project(enemy.x or 0, enemy.y or 0, 0)
    local size = math_max(8, (enemy.size or 0.28) * self._tile_w * 1.25)
    local phase = self._time * 4.4 + (enemy.phase or 0)
    local flare = 0.85 + (math_sin(phase * 1.7) + 1) * 0.12

    self:_draw_shadow(enemy, size * 0.7, layer - 0.03)
    self:_glow(x, y, size * 2.6 * flare, layer - 0.02, COLORS.wisp, 80, 3)
    self:_glow(x, y, size * 3.2, 3.62, COLORS.wisp, 26, 3)
    self:_diamond(x, y, size * 1.1 * flare, size * 1.1 * flare, layer - 0.01, COLORS.wisp, 32)
    self:_diamond(x, y, size * 0.72, size * 0.72, layer, COLORS.wisp, 230)
    self:_triangle(x, y - size * 0.72, x, y + size * 0.72, x - size * 0.72, y, layer + 0.01, COLORS.cortex_dark, 170)
    self:_line(x - size * 0.72, y, x, y - size * 0.72, 1, layer + 0.02, COLORS.wisp_hot, 205)
    for side = -1, 1, 2 do
        self:_diamond(x + side * size * 0.94, y + math_sin(phase) * size * 0.25, size * 0.12, size * 0.24, layer + 0.02, COLORS.wisp_hot, 180)
    end
    self:_diamond(x, y, size * 0.28, size * 0.28, layer + 0.03, COLORS.wisp_hot, 255)
    self:_draw_health_pips(enemy, x, y - size * 1.25, size * 1.5, layer + 0.05, COLORS.wisp)
end

function NoosphereBreachRenderer:_draw_sentry(enemy, layer)
    local x, y = self:_project(enemy.x or 0, enemy.y or 0, 0)
    local size = math_max(9, (enemy.size or 0.34) * self._tile_w * 1.35)
    local phase = self._time * 3.1 + (enemy.phase or 0)
    local angle = enemy.angle or phase * 0.12
    local dx = math_cos(angle)
    local dy = math_sin(angle)

    self:_draw_shadow(enemy, size * 0.8, layer - 0.03)
    self:_glow(x, y, size * 2.2, layer - 0.02, COLORS.sentry, 60, 3)
    self:_glow(x, y, size * 3, 3.62, COLORS.sentry, 22, 3)
    self:_diamond(x, y, size * 0.82, size * 0.82, layer, COLORS.sentry_dark)
    self:_rect(x - size * 0.5, y - size * 0.5, size, size, layer + 0.01, COLORS.sentry, 235)
    self:_rect(x - size * 0.5, y - size * 0.5, size, 1.5, layer + 0.015, COLORS.sentry_hot, 210)
    self:_rect(x - size * 0.36, y - size * 0.25, size * 0.72, size * 0.61, layer + 0.02, COLORS.sentry_dark)
    self:_rect(x - size * 0.7, y - size * 0.36, size * 0.14, size * 0.72, layer + 0.02, COLORS.sentry_hot, 150)
    self:_rect(x + size * 0.56, y - size * 0.36, size * 0.14, size * 0.72, layer + 0.02, COLORS.sentry_hot, 150)
    self:_line(x, y, x + dx * size * 1.3, y + dy * size * 1.3, size * 0.2, layer + 0.04, COLORS.sentry, 255)
    self:_line(x, y, x + dx * size * 1.38, y + dy * size * 1.38, 1.7, layer + 0.05, COLORS.sentry_hot, 255)
    self:_diamond(x, y, size * 0.2, size * 0.2, layer + 0.06, COLORS.white, 245)
    self:_diamond(x, y, size * 0.35, size * 0.35, layer + 0.03, COLORS.sentry, 155 + math_sin(phase) * 35)
    self:_draw_health_pips(enemy, x, y - size * 1.35, size * 1.6, layer + 0.07, COLORS.sentry)
end

function NoosphereBreachRenderer:_draw_cortex(enemy, layer)
    local x, y = self:_project(enemy.x or 0, enemy.y or 0, 0)
    local size = math_max(18, (enemy.size or 0.68) * self._tile_w * 1.25)
    local phase = self._time * 2.4 + (enemy.phase or 0)
    local pulse = 0.92 + (math_sin(phase * 1.6) + 1) * 0.08

    self:_draw_shadow(enemy, size * 0.85, layer - 0.04)
    self:_glow(x, y, size * 2.8 * pulse, layer - 0.03, COLORS.cortex, 90, 5)
    self:_glow(x, y, size * 4, 3.62, COLORS.cortex, 35, 4)
    self:_ring(x, y, size * 1.05 * pulse, size * 1.05 * pulse, 12, 2.2, layer - 0.02, COLORS.cortex, 95, phase * 0.07)
    self:_diamond(x, y, size * 0.78, size * 0.78, layer, COLORS.cortex_dark)
    self:_diamond(x, y, size * 0.56, size * 0.56, layer + 0.01, COLORS.cortex, 240)
    self:_triangle(x, y - size * 0.56, x + size * 0.56, y, x, y + size * 0.56, layer + 0.015, COLORS.cortex_dark, 165)
    self:_line(x - size * 0.56, y, x, y - size * 0.56, 1.4, layer + 0.02, COLORS.cortex_hot, 200)

    for side = -1, 1, 2 do
        self:_line(x + side * size * 0.45, y, x + side * size * 1.1, y, 3, layer + 0.03, COLORS.cortex_hot, 175)
        self:_diamond(x + side * size * 0.88, y, size * 0.22, size * 0.42, layer + 0.035, COLORS.cortex_dark)
        self:_diamond(x + side * size * 0.88, y - size * 0.08, size * 0.10, size * 0.23, layer + 0.036, COLORS.cortex_hot, 220)
    end

    self:_diamond(x, y, size * 0.24, size * 0.24, layer + 0.04, COLORS.cortex_hot, 245)
    self:_ring(x, y, size * 0.42, size * 0.42, 8, 1.4, layer + 0.05, COLORS.cortex_hot, 175, -phase * 0.11)
    self:_draw_health_pips(enemy, x, y - size * 1.3, size * 1.8, layer + 0.07, COLORS.cortex)
end

function NoosphereBreachRenderer:_draw_entities(player, enemies)
    self._queue_count = 0

    if player then self:_queue_entity(player, "Player", 0) end

    enemies = enemies or {}
    for i = 1, #enemies do
        local enemy = enemies[i]
        self:_queue_entity(enemy, enemy and enemy.kind, i)
    end

    sort_queue(self._queue, self._queue_count)

    for i = 1, self._queue_count do
        local entry = self._queue[i]
        local kind = entry.kind
        local layer = 12 + i * 0.001

        if kind == "Player" or kind == "player" then
            self:_draw_player(entry.entity, layer)
        elseif kind == "Sentry" or kind == "sentry" then
            self:_draw_sentry(entry.entity, layer)
        elseif kind == "Cortex" or kind == "cortex" then
            self:_draw_cortex(entry.entity, layer)
        else
            self:_draw_wisp(entry.entity, layer)
        end
    end

    for i = self._queue_count + 1, #self._queue do
        self._queue[i].entity = nil
        self._queue[i].kind = nil
    end
end

function NoosphereBreachRenderer:_draw_telegraphs(telegraphs)
    telegraphs = telegraphs or {}

    for i = 1, math_min(#telegraphs, 32) do
        local telegraph = telegraphs[i]
        local life = telegraph.max_life and telegraph.max_life > 0 and telegraph.life / telegraph.max_life or 1
        local alpha = 55 + math_max(0, math_min(1, life)) * 100
        local x, y = self:_project(telegraph.x or 0, telegraph.y or 0, 0)
        local angle = telegraph.angle or 0
        local layer = 8

        if telegraph.radius and telegraph.radius > 0 then
            local radius = telegraph.radius * self._tile_w
            self:_ring(x, y, radius, radius, 16, 1.8, layer, COLORS.warning, alpha, self._time * 0.12)
            if telegraph.kind == "blast" or telegraph.kind == "cortex" or telegraph.kind == "cortex_nova" then
                local inner_radius = radius * (1 - life * 0.65)
                self:_ring(x, y, inner_radius, inner_radius, 12, 1.2, layer + 0.01, COLORS.warning, alpha * 0.7)
            end
        elseif telegraph.length and telegraph.length > 0 then
            local length = telegraph.length
            local width = (telegraph.width or 0.35) * 0.5
            local world_x = telegraph.x or 0
            local world_y = telegraph.y or 0
            local end_x = world_x + math_cos(angle) * length
            local end_y = world_y + math_sin(angle) * length
            local side_x = -math_sin(angle) * width
            local side_y = math_cos(angle) * width
            local start_left_x, start_left_y = self:_project(world_x + side_x, world_y + side_y, 0)
            local end_left_x, end_left_y = self:_project(end_x + side_x, end_y + side_y, 0)
            local start_right_x, start_right_y = self:_project(world_x - side_x, world_y - side_y, 0)
            local end_right_x, end_right_y = self:_project(end_x - side_x, end_y - side_y, 0)

            self:_line(start_left_x, start_left_y, end_left_x, end_left_y, 1.6, layer, COLORS.warning, alpha)
            self:_line(start_right_x, start_right_y, end_right_x, end_right_y, 1.6, layer, COLORS.warning, alpha)
            self:_line(end_left_x, end_left_y, end_right_x, end_right_y, 1.6, layer, COLORS.warning, alpha)
        end
    end
end

function NoosphereBreachRenderer:_draw_projectiles(projectiles, hostile)
    projectiles = projectiles or {}
    local color = hostile and COLORS.enemy_projectile or COLORS.projectile

    for i = 1, math_min(#projectiles, 80) do
        local projectile = projectiles[i]
        local layer = hostile and 16.075 or 16.08
        local x, y = self:_project(projectile.x or 0, projectile.y or 0, 0.42)
        local velocity_x = projectile.vx or 0
        local velocity_y = projectile.vy or 0
        local tail_x, tail_y = self:_project((projectile.x or 0) - velocity_x * 0.035, (projectile.y or 0) - velocity_y * 0.035, 0.42)
        local alpha = projectile.life and math_min(255, 105 + projectile.life * 150) or 240

        self:_line(tail_x, tail_y, x, y, hostile and 6 or 7, layer - 0.002, color, alpha * 0.25)
        self:_line(tail_x, tail_y, x, y, hostile and 2.4 or 2.8, layer, color, alpha)
        if i <= 36 then
            self:_glow(x, y, hostile and 9 or 8, layer - 0.003, color, 110, 2)
        end
        self:_rect(x - 1.5, y - 1.5, 3, 3, layer + 0.01, hostile and COLORS.warning or COLORS.white, 245)
    end
end

function NoosphereBreachRenderer:_draw_particles(particles)
    particles = particles or {}

    for i = 1, math_min(#particles, 100) do
        local particle = particles[i]
        local life = particle.max_life and particle.max_life > 0 and particle.life / particle.max_life or 1
        local x, y = self:_project(particle.x or 0, particle.y or 0, particle.z or 0)
        local layer = 16.085
        local size = math_max(1.2, math_min(7, particle.size or 2.5)) * (0.45 + life * 0.55)
        local kind = particle.kind
        local color = (kind == "corruption" or kind == "cortex" or kind == "cortex_phase" or kind == "cortex_death") and COLORS.corruption_hot
            or (kind == "hit" or kind == "player_hit") and COLORS.white
            or (kind == "enemy" or kind == "enemy_hit" or kind == "enemy_death") and COLORS.enemy_projectile
            or kind == "dash" and COLORS.dash
            or COLORS.particle

        if size > 3.8 then
            self:_circle(x, y, size * 2.2, size * 2.2, layer - 0.001, color, color[1] * life * 0.18)
            self:_diamond(x, y, size, size, layer, color, color[1] * life)
        else
            self:_rect(x - size * 0.5, y - size * 0.5, size, size, layer, color, color[1] * life)
        end
    end
end

function NoosphereBreachRenderer:_draw_aim(player)
    if not player then return end

    local aim_x = player.aim_x or (player.x or 0) + math_cos(player.angle or 0) * 2
    local aim_y = player.aim_y or (player.y or 0) + math_sin(player.angle or 0) * 2
    local x, y = self:_project(aim_x, aim_y, 0.02)
    local pulse = 5 + (math_sin(self._time * 6) + 1) * 1.5

    self:_ring(x, y, pulse, pulse, 10, 1.2, 17, COLORS.player_hot, 190, self._time * 0.25)
    self:_line(x - 10, y, x - 4, y, 1.2, 17.01, COLORS.player_hot, 205)
    self:_line(x + 4, y, x + 10, y, 1.2, 17.01, COLORS.player_hot, 205)
    self:_line(x, y - 7, x, y - 3, 1.2, 17.01, COLORS.player_hot, 205)
    self:_line(x, y + 3, x, y + 7, 1.2, 17.01, COLORS.player_hot, 205)
end

function NoosphereBreachRenderer:draw(ui_renderer, origin_x, origin_y, game)
    if not ui_renderer or not ui_renderer.gui or not game then return end

    local map = game:map() or {}
    local map_w = math_max(1, game:map_width() or 1)
    local map_h = math_max(1, game:map_height() or 1)
    local time = game:time() or 0
    local tile_size = math_max(18, math_min(40, 520 / map_w, 374 / map_h))
    local shake = math_max(0, game:shake() or 0)

    self._gui = ui_renderer.gui
    self._scale = ui_renderer.scale or 1
    local start_layer = ui_renderer.render_settings and (ui_renderer.render_settings.start_layer or 0) or 0
    self._base_layer = start_layer + 38
    self._origin_x = origin_x or 0
    self._origin_y = origin_y or 0
    self._tile_w = tile_size
    self._tile_h = tile_size
    self._map_w = map_w
    self._map_h = map_h
    self._map_left = (CANVAS_W - map_w * tile_size) * 0.5
    self._map_top = 72
    self._center_x = CANVAS_W * 0.5
    self._time = time
    self._shake_x = math_sin(time * 71) * shake * 6
    self._shake_y = math_cos(time * 57) * shake * 4
    self._submission_count = 0
    self._submission_limit = MAX_SUBMISSIONS

    local light_player = game:player()
    self._light_x = light_player and (light_player.x or 0) - 0.5 or 0
    self._light_y = light_player and (light_player.y or 0) - 0.5 or 0
    self:_update_fx(game, time)

    self:_draw_environment(map, map_w, map_h, time)
    self:_draw_telegraphs(game:telegraphs())
    self:_draw_entities(game:player(), game:enemies())
    self:_draw_projectiles(game:player_projectiles(), false)
    self:_draw_projectiles(game:enemy_projectiles(), true)
    self:_draw_particles(game:particles())
    self:_draw_fx()
    self:_draw_aim(game:player())
    self:_draw_post(time)
end

return NoosphereBreachRenderer
