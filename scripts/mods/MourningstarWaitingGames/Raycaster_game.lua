local math_abs = math.abs
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_sin = math.sin
local math_sqrt = math.sqrt

local MAP_WIDTH = 19
local MAP_HEIGHT = 15
local MOVE_SPEED = 2.75
local STRAFE_SPEED = 2.45
local TURN_SPEED = 2.6
local MOUSE_LOOK_SENSITIVITY = 0.001
local CONTROLLER_LOOK_SENSITIVITY = 1.15
local DASH_SPEED = 8.8
local DASH_TIME = 0.32
local DASH_COST = 34
local FERVOR_REGEN = 8
local PLAYER_RADIUS = 0.18
local ENEMY_RADIUS = 0.16
local MAX_HEALTH = 100
local MAX_FERVOR = 100
local PICKUP_RADIUS = 0.36
local EXIT_RADIUS = 0.42
local COMBO_WINDOW = 3.4
local TWO_PI = math_pi * 2

local function math_atan2(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 then return math.atan(y / x) + (y >= 0 and math_pi or -math_pi) end
    if y > 0 then return math_pi * 0.5 end
    if y < 0 then return -math_pi * 0.5 end

    return 0
end

local SECTOR_NAMES = {
    "The Brass Ossuary",
    "Choir of Static",
    "Reliquary Nine",
    "The Sanguine Archive",
    "Vault of Last Light",
    "The Hollow Basilica",
}

local CARDINAL_DIRECTIONS = {
    { 2, 0 },
    { -2, 0 },
    { 0, 2 },
    { 0, -2 },
}

local RaycasterGame = {}
RaycasterGame.__index = RaycasterGame

local function normalize_angle(angle)
    angle = angle % TWO_PI

    if angle > math_pi then
        angle = angle - TWO_PI
    end

    return angle
end

local function distance_sq(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by

    return dx * dx + dy * dy
end

local function tile_center(col, row)
    return col - 0.5, row - 0.5
end

local function cell_key(col, row)
    return (row - 1) * MAP_WIDTH + col
end

function RaycasterGame:new()
    return setmetatable({
        _level = 1,
        _level_name = "",
        _theme = 1,
        _map = {},
        _width = MAP_WIDTH,
        _height = MAP_HEIGHT,
        _player = { x = 1.5, y = 1.5, angle = 0 },
        _pickups = {},
        _enemies = {},
        _effects = {},
        _exit = { x = 1.5, y = 1.5 },
        _score = 0,
        _health = MAX_HEALTH,
        _fervor = MAX_FERVOR,
        _sigils = 0,
        _sigils_required = 3,
        _combo = 0,
        _combo_time = 0,
        _best_multiplier = 1,
        _time_left = 0,
        _state = "idle",
        _time = 0,
        _shake = 0,
        _dash = 0,
        _dash_cooldown = 0,
        _damage_invulnerability = 0,
        _message = "",
        _message_time = 0,
        _portal_hint_cooldown = 0,
        _seed = 1,
        _columns = {},
        _objective = {},
        _pickup_callback = nil,
        _purge_callback = nil,
        _sector_callback = nil,
    }, RaycasterGame)
end

function RaycasterGame:start()
    self._level = 1
    self._score = 0
    self._health = MAX_HEALTH
    self._fervor = MAX_FERVOR
    self._state = "playing"
    self._time = 0
    self._shake = 0
    self._dash = 0
    self._dash_cooldown = 0
    self._damage_invulnerability = 0
    self._combo = 0
    self._combo_time = 0
    self._best_multiplier = 1
    self._seed = math.random(1, 2147483000)
    self:_load_level()
end

function RaycasterGame:set_pickup_callback(callback)
    self._pickup_callback = callback
end

function RaycasterGame:set_purge_callback(callback)
    self._purge_callback = callback
end

function RaycasterGame:set_sector_callback(callback)
    self._sector_callback = callback
end

function RaycasterGame:update(dt)
    if self._state == "idle" then
        self:start()
        return
    end

    if self._state ~= "playing" then
        return
    end

    dt = math_min(dt or 0.016, 0.05)
    self._time = self._time + dt
    self._time_left = math_max(0, self._time_left - dt)
    self._shake = math_max(0, self._shake - dt * 5.5)
    self._dash_cooldown = math_max(0, self._dash_cooldown - dt)
    self._damage_invulnerability = math_max(0, self._damage_invulnerability - dt)
    self._message_time = math_max(0, self._message_time - dt)
    self._portal_hint_cooldown = math_max(0, self._portal_hint_cooldown - dt)

    if self._combo_time > 0 then
        self._combo_time = math_max(0, self._combo_time - dt)
        if self._combo_time == 0 then
            self._combo = 0
        end
    end

    if self._dash > 0 then
        local dash_dt = math_min(dt, self._dash)
        self._dash = math_max(0, self._dash - dt)
        self:_move_vector(
            math_cos(self._player.angle) * DASH_SPEED * dash_dt,
            math_sin(self._player.angle) * DASH_SPEED * dash_dt
        )
        self:_purge_nearby_enemies()
    else
        self._fervor = math_min(MAX_FERVOR, self._fervor + FERVOR_REGEN * dt)
    end

    self:_update_enemies(dt)
    if self._state ~= "playing" then return end

    self:_update_effects(dt)
    self:_collect_pickups()
    self:_check_exit()

    if self._time_left <= 0 then
        self._health = 0
        self._state = "dead"
        self:_set_message("THE PURGE CONSUMES YOU", 5)
    end
end

function RaycasterGame:move_forward(dt, strength)
    self:_move(1, 0, dt or 0.016, strength)
end

function RaycasterGame:move_backward(dt, strength)
    self:_move(-1, 0, dt or 0.016, strength)
end

function RaycasterGame:strafe(dir, dt, strength)
    self:_move(0, dir, dt or 0.016, strength)
end

function RaycasterGame:move_axes(forward, strafe, dt)
    local length = math_sqrt(forward * forward + strafe * strafe)

    if length > 1 then
        forward = forward / length
        strafe = strafe / length
    end

    self:_move(forward, strafe, dt or 0.016, 1)
end

function RaycasterGame:turn(dir, dt)
    if self._state ~= "playing" then return end

    self._player.angle = normalize_angle(self._player.angle + dir * TURN_SPEED * (dt or 0.016))
end

function RaycasterGame:look(delta, is_controller)
    if self._state ~= "playing" or not delta then return end

    local sensitivity = is_controller and CONTROLLER_LOOK_SENSITIVITY or MOUSE_LOOK_SENSITIVITY

    self._player.angle = normalize_angle(self._player.angle + delta * sensitivity)
end

function RaycasterGame:dash()
    if self._state ~= "playing" or self._dash > 0 or self._dash_cooldown > 0 then
        return false
    end

    if self._fervor < DASH_COST then
        self:_set_message("FERVOR DEPLETED", 0.8)
        return false
    end

    self._fervor = self._fervor - DASH_COST
    self._dash = DASH_TIME
    self._dash_cooldown = DASH_TIME + 0.12
    self._shake = math_min(1, self._shake + 0.16)
    self:_spawn_burst(self._player.x, self._player.y, "dash", 8)

    return true
end

function RaycasterGame:fire()
    return self:dash()
end

function RaycasterGame:use()
    return self:dash()
end

function RaycasterGame:score() return self._score end
function RaycasterGame:health() return math_floor(self._health + 0.5) end
function RaycasterGame:ammo() return math_floor(self._fervor + 0.5) end
function RaycasterGame:fervor() return self._fervor end
function RaycasterGame:level() return self._level end
function RaycasterGame:level_name() return self._level_name end
function RaycasterGame:theme() return self._theme end
function RaycasterGame:state() return self._state end
function RaycasterGame:is_game_over() return self._state == "dead" end
function RaycasterGame:time() return self._time end
function RaycasterGame:time_left() return self._time_left end
function RaycasterGame:shake() return self._shake end
function RaycasterGame:message() return self._message end
function RaycasterGame:message_time() return self._message_time end
function RaycasterGame:combo() return self._combo end
function RaycasterGame:combo_time() return self._combo_time end
function RaycasterGame:best_multiplier() return self._best_multiplier end
function RaycasterGame:sigils() return self._sigils end
function RaycasterGame:sigils_required() return self._sigils_required end
function RaycasterGame:portal_open() return self._sigils >= self._sigils_required end
function RaycasterGame:dash_active() return self._dash > 0 end

function RaycasterGame:multiplier()
    return math_min(7, 1 + math_floor(self._combo / 4))
end

function RaycasterGame:player()
    return self._player
end

function RaycasterGame:render_entities()
    return {
        pickups = self._pickups,
        enemies = self._enemies,
        effects = self._effects,
        exit = self._exit,
        map = self._map,
        width = self._width,
        height = self._height,
    }
end

function RaycasterGame:objective()
    local best = nil
    local best_distance_sq = 1e30

    if not self:portal_open() then
        for i = 1, #self._pickups do
            local pickup = self._pickups[i]

            if pickup.kind == "sigil" and not pickup.taken then
                local d = distance_sq(self._player.x, self._player.y, pickup.x, pickup.y)

                if d < best_distance_sq then
                    best = pickup
                    best_distance_sq = d
                end
            end
        end
    else
        best = self._exit
        best_distance_sq = distance_sq(self._player.x, self._player.y, best.x, best.y)
    end

    if not best then return nil end

    local dx = best.x - self._player.x
    local dy = best.y - self._player.y
    local objective = self._objective

    objective.kind = self:portal_open() and "VAULT" or "SIGIL"
    objective.angle = normalize_angle(math_atan2(dy, dx) - self._player.angle)
    objective.distance = math_sqrt(best_distance_sq)

    return objective
end

function RaycasterGame:cast_columns(column_count, fov)
    column_count = math_max(1, math_floor(column_count or 1))
    fov = fov or math_pi * 0.4

    local columns = self._columns
    local start_angle = self._player.angle - fov * 0.5

    for column = 1, column_count do
        local t = column_count == 1 and 0.5 or (column - 1) / (column_count - 1)
        local angle = start_angle + fov * t

        columns[column] = columns[column] or {}
        self:_cast_ray(angle, columns[column])
    end

    return columns
end

function RaycasterGame:_random()
    self._seed = self._seed * 48271 % 2147483647

    return self._seed / 2147483647
end

function RaycasterGame:_random_index(count)
    return math_min(count, math_floor(self:_random() * count) + 1)
end

function RaycasterGame:_load_level()
    self._level_name = SECTOR_NAMES[(self._level - 1) % #SECTOR_NAMES + 1]
    self._theme = (self._level - 1) % 3 + 1
    self._sigils = 0
    self._sigils_required = math_min(6, 3 + math_floor((self._level - 1) / 2))
    self._time_left = math_max(48, 68 - self._level * 1.25) + self._sigils_required * 2
    self._pickups = {}
    self._enemies = {}
    self._effects = {}
    self._dash = 0
    self._damage_invulnerability = 0.7

    self:_generate_maze()
    self:_populate_level()
    self:_set_message(string.format("SECTOR %02d // %s", self._level, self._level_name), 2.5)
end

function RaycasterGame:_generate_maze()
    local map = {}

    for row = 1, MAP_HEIGHT do
        map[row] = {}
        for col = 1, MAP_WIDTH do
            map[row][col] = "#"
        end
    end

    local stack = { { col = 2, row = 2 } }
    map[2][2] = "."

    while #stack > 0 do
        local current = stack[#stack]
        local candidates = {}

        for i = 1, #CARDINAL_DIRECTIONS do
            local direction = CARDINAL_DIRECTIONS[i]
            local col = current.col + direction[1]
            local row = current.row + direction[2]

            if col >= 2 and col <= MAP_WIDTH - 1 and row >= 2 and row <= MAP_HEIGHT - 1 and map[row][col] == "#" then
                candidates[#candidates + 1] = { col = col, row = row }
            end
        end

        if #candidates == 0 then
            stack[#stack] = nil
        else
            local next_cell = candidates[self:_random_index(#candidates)]
            local wall_col = (current.col + next_cell.col) * 0.5
            local wall_row = (current.row + next_cell.row) * 0.5

            map[wall_row][wall_col] = "."
            map[next_cell.row][next_cell.col] = "."
            stack[#stack + 1] = next_cell
        end
    end

    local loops_to_open = 7 + math_min(8, self._level)
    local opened = 0
    local attempts = 0

    while opened < loops_to_open and attempts < 300 do
        attempts = attempts + 1

        local col = 2 + self:_random_index(MAP_WIDTH - 3) - 1
        local row = 2 + self:_random_index(MAP_HEIGHT - 3) - 1

        if map[row][col] == "#" then
            local horizontal = map[row][col - 1] == "." and map[row][col + 1] == "."
            local vertical = map[row - 1][col] == "." and map[row + 1][col] == "."

            if horizontal ~= vertical then
                map[row][col] = "."
                opened = opened + 1
            end
        end
    end

    self._map = map
end

function RaycasterGame:_populate_level()
    local distances = self:_distances_from(2, 2)
    local candidates = {}
    local farthest = { col = 2, row = 2, distance = 0 }

    for row = 2, MAP_HEIGHT - 1 do
        for col = 2, MAP_WIDTH - 1 do
            if self._map[row][col] == "." then
                local distance = distances[cell_key(col, row)] or 0

                if distance > farthest.distance then
                    farthest = { col = col, row = row, distance = distance }
                end

                if distance >= 3 then
                    candidates[#candidates + 1] = { col = col, row = row, distance = distance }
                end
            end
        end
    end

    self._map[farthest.row][farthest.col] = "X"
    self._exit.x, self._exit.y = tile_center(farthest.col, farthest.row)
    self._player.x, self._player.y = tile_center(2, 2)
    self._player.angle = self:_starting_angle()

    table.sort(candidates, function(a, b) return a.distance > b.distance end)

    local occupied = {
        [cell_key(2, 2)] = true,
        [cell_key(farthest.col, farthest.row)] = true,
    }

    for i = 1, self._sigils_required do
        local span = math_max(1, math_floor(#candidates / self._sigils_required))
        local start_index = math_min(#candidates, 1 + (i - 1) * span)
        local end_index = math_min(#candidates, start_index + math_max(1, math_floor(span * 0.55)))
        local chosen = self:_take_candidate(candidates, occupied, start_index, end_index)

        if chosen then
            self:_add_pickup("sigil", chosen.col, chosen.row)
        end
    end

    local shard_count = math_min(28, 13 + self._level * 2)
    for i = 1, shard_count do
        local chosen = self:_take_candidate(candidates, occupied, 1, #candidates)
        if chosen then self:_add_pickup("shard", chosen.col, chosen.row) end
    end

    local utility_count = self._level < 3 and 2 or 3
    for i = 1, utility_count do
        local chosen = self:_take_candidate(candidates, occupied, 1, #candidates)
        if chosen then self:_add_pickup(i == 1 and "health" or "fervor", chosen.col, chosen.row) end
    end

    local enemy_count = math_min(11, 2 + self._level)
    for i = 1, enemy_count do
        local chosen = self:_take_candidate(candidates, occupied, 1, #candidates, 6)

        if chosen then
            local x, y = tile_center(chosen.col, chosen.row)
            self._enemies[#self._enemies + 1] = {
                x = x,
                y = y,
                spawn_x = x,
                spawn_y = y,
                alive = true,
                phase = self:_random() * TWO_PI,
                wander_angle = self:_random() * TWO_PI,
                turn_timer = self:_random() * 2,
                stun = 0,
            }
        end
    end
end

function RaycasterGame:_distances_from(start_col, start_row)
    local distances = { [cell_key(start_col, start_row)] = 0 }
    local queue = { { col = start_col, row = start_row } }
    local head = 1

    while head <= #queue do
        local current = queue[head]
        local current_distance = distances[cell_key(current.col, current.row)]
        head = head + 1

        local neighbors = {
            { current.col + 1, current.row },
            { current.col - 1, current.row },
            { current.col, current.row + 1 },
            { current.col, current.row - 1 },
        }

        for i = 1, #neighbors do
            local neighbor = neighbors[i]
            local col = neighbor[1]
            local row = neighbor[2]
            local key = cell_key(col, row)

            if not distances[key] and self._map[row] and self._map[row][col] == "." then
                distances[key] = current_distance + 1
                queue[#queue + 1] = { col = col, row = row }
            end
        end
    end

    return distances
end

function RaycasterGame:_starting_angle()
    if self._map[2][3] == "." then return 0 end
    if self._map[3][2] == "." then return math_pi * 0.5 end

    return 0
end

function RaycasterGame:_take_candidate(candidates, occupied, first_index, last_index, minimum_distance)
    if #candidates == 0 then return nil end

    first_index = math_max(1, math_min(first_index or 1, #candidates))
    last_index = math_max(first_index, math_min(last_index or #candidates, #candidates))

    for attempt = 1, 50 do
        local index = first_index + self:_random_index(last_index - first_index + 1) - 1
        local candidate = candidates[index]
        local key = candidate and cell_key(candidate.col, candidate.row)

        if candidate and not occupied[key] and (not minimum_distance or candidate.distance >= minimum_distance) then
            occupied[key] = true
            return candidate
        end
    end

    for i = 1, #candidates do
        local candidate = candidates[i]
        local key = cell_key(candidate.col, candidate.row)

        if not occupied[key] and (not minimum_distance or candidate.distance >= minimum_distance) then
            occupied[key] = true
            return candidate
        end
    end

    return nil
end

function RaycasterGame:_add_pickup(kind, col, row)
    local x, y = tile_center(col, row)

    self._pickups[#self._pickups + 1] = {
        x = x,
        y = y,
        kind = kind,
        taken = false,
        phase = self:_random() * TWO_PI,
    }
end

function RaycasterGame:_move(forward, strafe, dt, strength)
    if self._state ~= "playing" then return end

    strength = strength or 1

    local angle = self._player.angle
    local speed_bonus = 1 + math_min(12, self._combo) * 0.012
    local forward_distance = forward * MOVE_SPEED * speed_bonus * dt * strength
    local strafe_distance = strafe * STRAFE_SPEED * speed_bonus * dt * strength
    local dx = math_cos(angle) * forward_distance + math_cos(angle + math_pi * 0.5) * strafe_distance
    local dy = math_sin(angle) * forward_distance + math_sin(angle + math_pi * 0.5) * strafe_distance

    self:_move_vector(dx, dy)
    self:_collect_pickups()
    self:_check_exit()
end

function RaycasterGame:_move_vector(dx, dy)
    self:_move_axis(dx, 0)
    self:_move_axis(0, dy)
end

function RaycasterGame:_move_axis(dx, dy)
    local next_x = self._player.x + dx
    local next_y = self._player.y + dy

    if not self:_blocked_at(next_x, next_y, PLAYER_RADIUS) then
        self._player.x = next_x
        self._player.y = next_y
    elseif self._dash > 0 then
        self._shake = math_min(1, self._shake + 0.08)
    end
end

function RaycasterGame:_blocked_at(x, y, radius, portal_always_blocks)
    local min_x = x - radius
    local max_x = x + radius
    local min_y = y - radius
    local max_y = y + radius

    return self:_tile_blocks(self:_tile_at(math_floor(min_x) + 1, math_floor(min_y) + 1), portal_always_blocks)
        or self:_tile_blocks(self:_tile_at(math_floor(max_x) + 1, math_floor(min_y) + 1), portal_always_blocks)
        or self:_tile_blocks(self:_tile_at(math_floor(min_x) + 1, math_floor(max_y) + 1), portal_always_blocks)
        or self:_tile_blocks(self:_tile_at(math_floor(max_x) + 1, math_floor(max_y) + 1), portal_always_blocks)
end

function RaycasterGame:_tile_blocks(tile, portal_always_blocks)
    return tile == "#" or (tile == "X" and (portal_always_blocks or not self:portal_open()))
end

function RaycasterGame:_tile_at(col, row)
    if row < 1 or row > self._height or col < 1 or col > self._width then
        return "#"
    end

    return self._map[row][col] or "#"
end

function RaycasterGame:_collect_pickups()
    for i = 1, #self._pickups do
        local pickup = self._pickups[i]

        if not pickup.taken and distance_sq(self._player.x, self._player.y, pickup.x, pickup.y) <= PICKUP_RADIUS * PICKUP_RADIUS then
            pickup.taken = true

            if pickup.kind == "shard" then
                self:_add_combo(1)
                self._score = self._score + 25 * self:multiplier()
                self._fervor = math_min(MAX_FERVOR, self._fervor + 5)
                self._time_left = self._time_left + 0.8
                self:_set_message(string.format("RESONANCE CHAIN x%d", self:multiplier()), 0.65)
            elseif pickup.kind == "sigil" then
                self:_add_combo(3)
                self._sigils = self._sigils + 1
                self._score = self._score + 250 * self:multiplier()
                self._fervor = math_min(MAX_FERVOR, self._fervor + 28)
                self._time_left = self._time_left + 8

                if self:portal_open() then
                    self:_set_message("ALL SIGILS CLAIMED // VAULT OPEN", 2.3)
                else
                    self:_set_message(string.format("SIGIL CLAIMED // %d REMAIN", self._sigils_required - self._sigils), 1.5)
                end
            elseif pickup.kind == "health" then
                self._health = math_min(MAX_HEALTH, self._health + 32)
                self._score = self._score + 75
                self:_set_message("MARTYR'S GRACE // INTEGRITY RESTORED", 1.4)
            else
                self._fervor = MAX_FERVOR
                self._score = self._score + 75
                self:_set_message("FERVOR OVERCHARGED", 1.2)
            end

            self:_spawn_burst(pickup.x, pickup.y, pickup.kind, pickup.kind == "sigil" and 22 or 12)
            if self._pickup_callback then self._pickup_callback(pickup.kind) end
        end
    end
end

function RaycasterGame:_add_combo(amount)
    if self._combo_time <= 0 then
        self._combo = amount
    else
        self._combo = math_min(24, self._combo + amount)
    end

    self._combo_time = COMBO_WINDOW
    self._best_multiplier = math_max(self._best_multiplier, self:multiplier())
end

function RaycasterGame:_check_exit()
    local distance = distance_sq(self._player.x, self._player.y, self._exit.x, self._exit.y)

    if distance <= 0.85 * 0.85 and not self:portal_open() then
        if self._portal_hint_cooldown <= 0 then
            self._portal_hint_cooldown = 1.4
            self:_set_message(string.format("VAULT SEALED // %d SIGILS REMAIN", self._sigils_required - self._sigils), 1.2)
        end

        return
    end

    if distance <= EXIT_RADIUS * EXIT_RADIUS and self:portal_open() then
        self._score = self._score + 500 * self._level * self:multiplier()
        self._health = math_min(MAX_HEALTH, self._health + 12)
        self._fervor = math_min(MAX_FERVOR, self._fervor + 35)
        self._level = self._level + 1

        if self._sector_callback then self._sector_callback() end
        self:_load_level()
    end
end

function RaycasterGame:_update_enemies(dt)
    local player = self._player
    local enemy_speed = math_min(1.65, 0.72 + self._level * 0.065)

    for i = 1, #self._enemies do
        local enemy = self._enemies[i]

        if enemy.alive then
            enemy.phase = enemy.phase + dt * (2.2 + i * 0.03)
            enemy.stun = math_max(0, enemy.stun - dt)
            enemy.turn_timer = enemy.turn_timer - dt

            local dx = player.x - enemy.x
            local dy = player.y - enemy.y
            local distance_squared = dx * dx + dy * dy

            if enemy.stun <= 0 then
                local angle
                local speed = enemy_speed * 0.38

                if distance_squared < 9 * 9 and self:_has_line_of_sight(enemy.x, enemy.y, player.x, player.y) then
                    angle = math_atan2(dy, dx)
                    speed = enemy_speed
                else
                    if enemy.turn_timer <= 0 then
                        enemy.turn_timer = 0.8 + self:_random() * 2.2
                        enemy.wander_angle = enemy.wander_angle + (self:_random() - 0.5) * 2.4
                    end
                    angle = enemy.wander_angle
                end

                local move_x = math_cos(angle) * speed * dt
                local move_y = math_sin(angle) * speed * dt

                if not self:_enemy_move_axis(enemy, move_x, 0) then
                    enemy.wander_angle = math_pi - enemy.wander_angle
                end
                if not self:_enemy_move_axis(enemy, 0, move_y) then
                    enemy.wander_angle = -enemy.wander_angle
                end
            end

            if distance_sq(player.x, player.y, enemy.x, enemy.y) <= 0.48 * 0.48 then
                if self._dash > 0 then
                    self:_purge_enemy(enemy)
                elseif self._damage_invulnerability <= 0 then
                    self:_hurt_player(enemy)
                end
            end
        end
    end
end

function RaycasterGame:_enemy_move_axis(enemy, dx, dy)
    local next_x = enemy.x + dx
    local next_y = enemy.y + dy
    local blocked = self:_blocked_at(next_x, next_y, ENEMY_RADIUS, true)

    if not blocked then
        enemy.x = next_x
        enemy.y = next_y
        return true
    end

    return false
end

function RaycasterGame:_purge_nearby_enemies()
    for i = 1, #self._enemies do
        local enemy = self._enemies[i]

        if enemy.alive and distance_sq(self._player.x, self._player.y, enemy.x, enemy.y) <= 0.64 * 0.64 then
            self:_purge_enemy(enemy)
        end
    end
end

function RaycasterGame:_purge_enemy(enemy)
    enemy.alive = false
    self:_add_combo(2)
    self._score = self._score + 150 * self:multiplier()
    self._fervor = math_min(MAX_FERVOR, self._fervor + 18)
    self._time_left = self._time_left + 3
    self._shake = math_min(1, self._shake + 0.42)
    self:_spawn_burst(enemy.x, enemy.y, "purge", 28)
    self:_set_message(string.format("CORRUPTION PURGED // x%d", self:multiplier()), 1.1)

    if self._purge_callback then self._purge_callback() end
end

function RaycasterGame:_hurt_player(enemy)
    local damage = math_min(30, 15 + math_floor(self._level / 3) * 2)

    self._health = math_max(0, self._health - damage)
    self._time_left = math_max(0, self._time_left - 3)
    self._combo = 0
    self._combo_time = 0
    self._damage_invulnerability = 1.05
    self._shake = 1
    enemy.stun = 1.1

    local angle = math_atan2(self._player.y - enemy.y, self._player.x - enemy.x)
    self:_move_vector(math_cos(angle) * 0.38, math_sin(angle) * 0.38)
    self:_set_message("CORRUPTION BREACH // CHAIN LOST", 1.4)

    if self._health <= 0 then
        self._state = "dead"
        self:_set_message("PENITENT LOST", 5)
    end
end

function RaycasterGame:_update_effects(dt)
    for i = #self._effects, 1, -1 do
        local effect = self._effects[i]

        effect.x = effect.x + effect.vx * dt
        effect.y = effect.y + effect.vy * dt
        effect.z = effect.z + effect.vz * dt
        effect.vx = effect.vx * (1 - dt * 1.8)
        effect.vy = effect.vy * (1 - dt * 1.8)
        effect.vz = effect.vz - dt * 0.8
        effect.life = effect.life - dt

        if effect.life <= 0 then
            table.remove(self._effects, i)
        end
    end
end

function RaycasterGame:_spawn_burst(x, y, kind, count)
    for i = 1, count do
        if #self._effects >= 90 then
            table.remove(self._effects, 1)
        end

        local angle = self:_random() * TWO_PI
        local speed = 0.25 + self:_random() * 1.25
        local life = 0.35 + self:_random() * 0.65

        self._effects[#self._effects + 1] = {
            x = x,
            y = y,
            z = 0.15 + self:_random() * 0.75,
            vx = math_cos(angle) * speed,
            vy = math_sin(angle) * speed,
            vz = 0.1 + self:_random() * 0.8,
            size = 0.018 + self:_random() * 0.05,
            life = life,
            max_life = life,
            kind = kind,
        }
    end
end

function RaycasterGame:_set_message(message, duration)
    self._message = message
    self._message_time = duration or 1
end

function RaycasterGame:_has_line_of_sight(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math_sqrt(dx * dx + dy * dy)

    if distance <= 0 then return true end

    local steps = math_max(1, math_floor(distance * 12))

    for i = 1, steps - 1 do
        local t = i / steps
        local tile = self:_tile_at(math_floor(x1 + dx * t) + 1, math_floor(y1 + dy * t) + 1)

        if tile == "#" or tile == "X" then
            return false
        end
    end

    return true
end

function RaycasterGame:_cast_ray(angle, out)
    local ray_dir_x = math_cos(angle)
    local ray_dir_y = math_sin(angle)
    local map_x = math_floor(self._player.x) + 1
    local map_y = math_floor(self._player.y) + 1
    local delta_dist_x = ray_dir_x == 0 and 1e30 or math_abs(1 / ray_dir_x)
    local delta_dist_y = ray_dir_y == 0 and 1e30 or math_abs(1 / ray_dir_y)
    local step_x, step_y, side_dist_x, side_dist_y

    if ray_dir_x < 0 then
        step_x = -1
        side_dist_x = (self._player.x - (map_x - 1)) * delta_dist_x
    else
        step_x = 1
        side_dist_x = (map_x - self._player.x) * delta_dist_x
    end

    if ray_dir_y < 0 then
        step_y = -1
        side_dist_y = (self._player.y - (map_y - 1)) * delta_dist_y
    else
        step_y = 1
        side_dist_y = (map_y - self._player.y) * delta_dist_y
    end

    local side = "x"
    local tile = "."

    for i = 1, 128 do
        if side_dist_x < side_dist_y then
            side_dist_x = side_dist_x + delta_dist_x
            map_x = map_x + step_x
            side = "x"
        else
            side_dist_y = side_dist_y + delta_dist_y
            map_y = map_y + step_y
            side = "y"
        end

        tile = self:_tile_at(map_x, map_y)

        if tile == "#" or tile == "X" then
            break
        end
    end

    local distance
    if side == "x" then
        distance = (map_x - 1 - self._player.x + (1 - step_x) * 0.5) / ray_dir_x
    else
        distance = (map_y - 1 - self._player.y + (1 - step_y) * 0.5) / ray_dir_y
    end

    distance = math_max(0.0001, distance)

    local hit_x = self._player.x + ray_dir_x * distance
    local hit_y = self._player.y + ray_dir_y * distance

    out.distance = distance
    out.corrected_distance = distance * math_cos(normalize_angle(angle - self._player.angle))
    out.tile = tile
    out.side = side
    out.map_x = map_x
    out.map_y = map_y
    out.wall_x = side == "x" and hit_y - math_floor(hit_y) or hit_x - math_floor(hit_x)
    out.angle = normalize_angle(angle)

    return out
end

function RaycasterGame:_set_player(x, y, angle)
    self._player.x = x
    self._player.y = y
    self._player.angle = angle or self._player.angle
end

function RaycasterGame:_debug_tile(col, row)
    return self:_tile_at(col, row)
end

function RaycasterGame:_debug_set_tile(col, row, tile)
    if self._map[row] then self._map[row][col] = tile end
end

function RaycasterGame:_debug_hurt(amount)
    self._health = math_max(0, self._health - amount)
end

function RaycasterGame:_debug_set_stats(health, fervor)
    self._health = health or self._health
    self._fervor = fervor or self._fervor
end

function RaycasterGame:_debug_add_pickup(kind, x, y)
    self._pickups[#self._pickups + 1] = {
        x = x,
        y = y,
        kind = kind,
        taken = false,
        phase = 0,
    }
end

return RaycasterGame
