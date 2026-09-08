local math_abs = math.abs
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_sin = math.sin
local math_sqrt = math.sqrt
local table_remove = table.remove

local MAP_WIDTH = 13
local MAP_HEIGHT = 13
local MAX_HEALTH = 100
local PLAYER_RADIUS = 0.24
local PLAYER_SPEED = 3.35
local PLAYER_FIRE_INTERVAL = 0.14
local PLAYER_PROJECTILE_SPEED = 9.5
local DASH_COOLDOWN = 2.0
local DASH_DURATION = 0.18
local DASH_SPEED = 10.5
local COMBO_WINDOW = 3.2
local CONTROLLER_DEADZONE = 0.22
local MOUSE_AIM_SENSITIVITY = 0.0025
local ORDINARY_WAVES = 4
local BOSS_WAVE = ORDINARY_WAVES + 1
local TWO_PI = math_pi * 2

local MAX_ENEMIES = 12
local MAX_PLAYER_PROJECTILES = 50
local MAX_ENEMY_PROJECTILES = 50
local MAX_PARTICLES = 120
local MAX_TELEGRAPHS = 24

local MAP_LAYOUT = {
    "#############",
    "#..~.....~..#",
    "#.#...#...#.#",
    "#...#...#...#",
    "#~.........~#",
    "#..#..#..#..#",
    "#.....~.....#",
    "#..#..#..#..#",
    "#~.........~#",
    "#...#...#...#",
    "#.#...#...#.#",
    "#..~.....~..#",
    "#############",
}

local SPAWN_POINTS = {
    { 1.5, 1.5 },
    { 6.5, 1.5 },
    { 11.5, 1.5 },
    { 1.5, 6.5 },
    { 11.5, 6.5 },
    { 1.5, 11.5 },
    { 6.5, 11.5 },
    { 11.5, 11.5 },
    { 3.5, 1.5 },
    { 9.5, 1.5 },
    { 3.5, 11.5 },
    { 9.5, 11.5 },
}

local function clamp(value, low, high)
    return math_max(low, math_min(high, value))
end

local function distance_sq(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by

    return dx * dx + dy * dy
end

local function atan2(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 then return math.atan(y / x) + (y >= 0 and math_pi or -math_pi) end
    if y > 0 then return math_pi * 0.5 end
    if y < 0 then return -math_pi * 0.5 end

    return 0
end

local function normalize(x, y)
    local length_sq = x * x + y * y

    if length_sq <= 0.000001 then
        return 0, 0, 0
    end

    local length = math_sqrt(length_sq)

    return x / length, y / length, length
end

local function clear_array(array)
    for i = #array, 1, -1 do
        array[i] = nil
    end
end

local function build_map()
    local map = {}

    for row = 1, MAP_HEIGHT do
        local tiles = {}
        local layout_row = MAP_LAYOUT[row]

        for col = 1, MAP_WIDTH do
            tiles[col] = layout_row:sub(col, col)
        end

        map[row] = tiles
    end

    return map
end

local NoosphereBreachGame = {}
NoosphereBreachGame.__index = NoosphereBreachGame

function NoosphereBreachGame:new()
    return setmetatable({
        _map = build_map(),
        _player = {
            x = 6.5,
            y = 6.5,
            vx = 0,
            vy = 0,
            angle = 0,
            size = PLAYER_RADIUS,
            radius = PLAYER_RADIUS,
            kind = "player",
            alive = true,
            health = MAX_HEALTH,
            max_health = MAX_HEALTH,
            phase = 1,
            aim_x = 8.5,
            aim_y = 6.5,
            invulnerability_time = 0,
            dash_time = 0,
        },
        _enemies = {},
        _player_projectiles = {},
        _enemy_projectiles = {},
        _particles = {},
        _telegraphs = {},
        _move_x = 0,
        _move_y = 0,
        _aim_x = 1,
        _aim_y = 0,
        _firing = false,
        _fire_timer = 0,
        _dash_timer = 0,
        _dash_cooldown = 0,
        _dash_x = 1,
        _dash_y = 0,
        _dash_id = 0,
        _invulnerability = 0,
        _score = 0,
        _wave = 0,
        _health = MAX_HEALTH,
        _combo = 0,
        _combo_time = 0,
        _best_multiplier = 1,
        _state = "idle",
        _state_timer = 0,
        _wave_active = false,
        _time = 0,
        _shake = 0,
        _message = "",
        _message_time = 0,
        _seed = 1357911,
        _hit_callback = nil,
        _kill_callback = nil,
        _wave_callback = nil,
    }, NoosphereBreachGame)
end

function NoosphereBreachGame:start()
    clear_array(self._enemies)
    clear_array(self._player_projectiles)
    clear_array(self._enemy_projectiles)
    clear_array(self._particles)
    clear_array(self._telegraphs)

    local player = self._player
    player.x = 6.5
    player.y = 6.5
    player.vx = 0
    player.vy = 0
    player.angle = 0
    player.alive = true
    player.health = MAX_HEALTH
    player.max_health = MAX_HEALTH
    player.phase = 1
    player.aim_x = 8.5
    player.aim_y = 6.5
    player.invulnerability_time = 0.8
    player.dash_time = 0

    self._move_x = 0
    self._move_y = 0
    self._aim_x = 1
    self._aim_y = 0
    self._firing = false
    self._fire_timer = 0
    self._dash_timer = 0
    self._dash_cooldown = 0
    self._dash_x = 1
    self._dash_y = 0
    self._dash_id = 0
    self._invulnerability = 0.8
    self._score = 0
    self._wave = 0
    self._health = MAX_HEALTH
    self._combo = 0
    self._combo_time = 0
    self._best_multiplier = 1
    self._state = "wave"
    self._state_timer = 1.4
    self._wave_active = false
    self._time = 0
    self._shake = 0
    self._seed = 1357911
    self:_set_message("NOOSPHERE LINK ESTABLISHED // WAVE 1", 1.4)
end

function NoosphereBreachGame:set_move(x, y)
    x = x or 0
    y = y or 0

    local nx, ny, length = normalize(x, y)

    if length > 1 then
        x = nx
        y = ny
    end

    self._move_x = x
    self._move_y = y
end

function NoosphereBreachGame:aim(x, y, is_controller)
    x = x or 0
    y = y or 0

    if is_controller then
        local nx, ny, length = normalize(x, y)

        if length > CONTROLLER_DEADZONE then
            self._aim_x = nx
            self._aim_y = ny
        end
    elseif x ~= 0 or y ~= 0 then
        local nx, ny, length = normalize(
            self._aim_x + x * MOUSE_AIM_SENSITIVITY,
            self._aim_y + y * MOUSE_AIM_SENSITIVITY
        )

        if length > 0 then
            self._aim_x = nx
            self._aim_y = ny
        end
    end

    self._player.angle = atan2(self._aim_y, self._aim_x)
end

function NoosphereBreachGame:set_firing(active)
    self._firing = active == true
end

function NoosphereBreachGame:dash()
    if self._state ~= "playing" or not self._player.alive or self._dash_cooldown > 0 then
        return false
    end

    local dx, dy, length = normalize(self._move_x, self._move_y)

    if length <= 0.05 then
        dx = self._aim_x
        dy = self._aim_y
    end

    self._dash_x = dx
    self._dash_y = dy
    self._dash_timer = DASH_DURATION
    self._dash_cooldown = DASH_COOLDOWN
    self._invulnerability = math_max(self._invulnerability, DASH_DURATION + 0.12)
    self._dash_id = self._dash_id + 1
    self._shake = math_min(1, self._shake + 0.18)
    self:_spawn_burst(self._player.x, self._player.y, "dash", 10, 2.8)

    return true
end

function NoosphereBreachGame:set_hit_callback(callback)
    self._hit_callback = type(callback) == "function" and callback or nil
end

function NoosphereBreachGame:set_kill_callback(callback)
    self._kill_callback = type(callback) == "function" and callback or nil
end

function NoosphereBreachGame:set_wave_callback(callback)
    self._wave_callback = type(callback) == "function" and callback or nil
end

function NoosphereBreachGame:score() return self._score end
function NoosphereBreachGame:wave() return self._wave end
function NoosphereBreachGame:health() return math_floor(self._health + 0.5) end
function NoosphereBreachGame:max_health() return MAX_HEALTH end
function NoosphereBreachGame:state() return self._state end
function NoosphereBreachGame:is_game_over() return self._state == "dead" or self._state == "victory" end
function NoosphereBreachGame:time() return self._time end
function NoosphereBreachGame:shake() return self._shake end
function NoosphereBreachGame:message() return self._message end
function NoosphereBreachGame:message_time() return self._message_time end
function NoosphereBreachGame:combo() return self._combo end
function NoosphereBreachGame:combo_time() return self._combo_time end
function NoosphereBreachGame:best_multiplier() return self._best_multiplier end
function NoosphereBreachGame:player() return self._player end
function NoosphereBreachGame:map() return self._map end
function NoosphereBreachGame:map_width() return MAP_WIDTH end
function NoosphereBreachGame:map_height() return MAP_HEIGHT end
function NoosphereBreachGame:enemies() return self._enemies end
function NoosphereBreachGame:player_projectiles() return self._player_projectiles end
function NoosphereBreachGame:enemy_projectiles() return self._enemy_projectiles end
function NoosphereBreachGame:particles() return self._particles end
function NoosphereBreachGame:telegraphs() return self._telegraphs end

function NoosphereBreachGame:dash_charge()
    return clamp(1 - self._dash_cooldown / DASH_COOLDOWN, 0, 1)
end

function NoosphereBreachGame:multiplier()
    return math_min(6, 1 + math_floor(self._combo / 3))
end

function NoosphereBreachGame:update(dt)
    if self._state == "idle" then
        self:start()
        return
    end

    if self:is_game_over() then
        dt = clamp(dt or 0.016, 0, 0.05)
        self._time = self._time + dt
        self._shake = math_max(0, self._shake - dt * 5.5)
        self:_update_particles(dt)
        return
    end

    dt = clamp(dt or 0.016, 0, 0.05)
    self._time = self._time + dt
    self._shake = math_max(0, self._shake - dt * 5.5)
    self._message_time = math_max(0, self._message_time - dt)
    self._dash_cooldown = math_max(0, self._dash_cooldown - dt)
    self._invulnerability = math_max(0, self._invulnerability - dt)
    self._fire_timer = math_max(0, self._fire_timer - dt)
    self._player.invulnerability_time = self._invulnerability
    self._player.dash_time = self._dash_timer
    self._player.aim_x = self._player.x + self._aim_x * 2
    self._player.aim_y = self._player.y + self._aim_y * 2

    if self._combo_time > 0 then
        self._combo_time = math_max(0, self._combo_time - dt)

        if self._combo_time == 0 then
            self._combo = 0
        end
    end

    self:_update_particles(dt)

    if self._state == "wave" or self._state == "boss_intro" then
        self._state_timer = self._state_timer - dt

        if self._state_timer <= 0 then
            if self._state == "boss_intro" then
                self:_spawn_boss()
            else
                self:_spawn_wave()
            end
        end

        return
    end

    self:_update_player(dt)

    if self._state ~= "playing" then return end

    if self._firing then
        self:_fire_player_weapon()
    end

    self:_update_telegraphs(dt)
    self:_update_enemies(dt)

    if self._state ~= "playing" then return end

    self:_update_player_projectiles(dt)
    self:_update_enemy_projectiles(dt)

    if self._state ~= "playing" then return end

    self:_check_enemy_contact()

    if self._state == "playing" and self._wave_active and #self._enemies == 0 then
        self:_begin_wave_transition()
    end
end

function NoosphereBreachGame:_random()
    self._seed = self._seed * 48271 % 2147483647

    return self._seed / 2147483647
end

function NoosphereBreachGame:_random_index(count)
    return math_min(count, math_floor(self:_random() * count) + 1)
end

function NoosphereBreachGame:_set_message(text, duration)
    self._message = text
    self._message_time = duration or 1.5
end

function NoosphereBreachGame:_tile_is_wall(col, row)
    if col < 1 or col > MAP_WIDTH or row < 1 or row > MAP_HEIGHT then
        return true
    end

    return self._map[row][col] == "#"
end

function NoosphereBreachGame:_point_is_wall(x, y)
    return self:_tile_is_wall(math_floor(x) + 1, math_floor(y) + 1)
end

function NoosphereBreachGame:_circle_hits_wall(x, y, radius)
    local min_col = math_floor(x - radius) + 1
    local max_col = math_floor(x + radius) + 1
    local min_row = math_floor(y - radius) + 1
    local max_row = math_floor(y + radius) + 1

    for row = min_row, max_row do
        for col = min_col, max_col do
            if self:_tile_is_wall(col, row) then
                local left = col - 1
                local right = col
                local top = row - 1
                local bottom = row
                local nearest_x = clamp(x, left, right)
                local nearest_y = clamp(y, top, bottom)

                if distance_sq(x, y, nearest_x, nearest_y) < radius * radius then
                    return true
                end
            end
        end
    end

    return false
end

function NoosphereBreachGame:_move_entity(entity, dx, dy, radius)
    local moved = false
    local next_x = entity.x + dx

    if not self:_circle_hits_wall(next_x, entity.y, radius) then
        entity.x = next_x
        moved = moved or dx ~= 0
    end

    local next_y = entity.y + dy

    if not self:_circle_hits_wall(entity.x, next_y, radius) then
        entity.y = next_y
        moved = moved or dy ~= 0
    end

    return moved
end

function NoosphereBreachGame:_update_player(dt)
    local player = self._player

    if self._dash_timer > 0 then
        local dash_dt = math_min(dt, self._dash_timer)
        local dx = self._dash_x * DASH_SPEED * dash_dt
        local dy = self._dash_y * DASH_SPEED * dash_dt

        self._dash_timer = math_max(0, self._dash_timer - dt)
        player.vx = self._dash_x * DASH_SPEED
        player.vy = self._dash_y * DASH_SPEED
        self:_move_entity(player, dx, dy, PLAYER_RADIUS)
        self:_dash_damage()

        if self:_random() < 0.8 then
            self:_spawn_particle(
                player.x - self._dash_x * 0.18,
                player.y - self._dash_y * 0.18,
                0.08,
                -self._dash_x * 1.8,
                -self._dash_y * 1.8,
                0.25,
                0.24,
                "dash",
                0.09
            )
        end
    else
        player.vx = self._move_x * PLAYER_SPEED
        player.vy = self._move_y * PLAYER_SPEED
        self:_move_entity(player, player.vx * dt, player.vy * dt, PLAYER_RADIUS)
    end

    player.angle = atan2(self._aim_y, self._aim_x)
    player.invulnerability_time = self._invulnerability
    player.dash_time = self._dash_timer
    player.aim_x = player.x + self._aim_x * 2
    player.aim_y = player.y + self._aim_y * 2
end

function NoosphereBreachGame:_fire_player_weapon()
    if self._fire_timer > 0 or #self._player_projectiles >= MAX_PLAYER_PROJECTILES then
        return
    end

    local player = self._player
    local x = player.x + self._aim_x * 0.34
    local y = player.y + self._aim_y * 0.34

    self._player_projectiles[#self._player_projectiles + 1] = {
        x = x,
        y = y,
        vx = self._aim_x * PLAYER_PROJECTILE_SPEED,
        vy = self._aim_y * PLAYER_PROJECTILE_SPEED,
        life = 1.35,
        max_life = 1.35,
        kind = "player_bolt",
        angle = player.angle,
        size = 0.09,
        radius = 0.09,
        damage = 20,
    }

    self._fire_timer = PLAYER_FIRE_INTERVAL
    self:_spawn_particle(x, y, 0.05, self._aim_x * 0.7, self._aim_y * 0.7, 0.35, 0.12, "muzzle", 0.13)
end

function NoosphereBreachGame:_dash_damage()
    local player = self._player

    for i = #self._enemies, 1, -1 do
        local enemy = self._enemies[i]
        local radius = PLAYER_RADIUS + enemy.radius

        if enemy.dash_hit_id ~= self._dash_id and distance_sq(player.x, player.y, enemy.x, enemy.y) <= radius * radius then
            enemy.dash_hit_id = self._dash_id
            self:_damage_enemy(i, 32, "dash")
        end
    end
end

function NoosphereBreachGame:_spawn_wave()
    self._wave = self._wave + 1
    self._state = "playing"
    self._wave_active = true
    self._invulnerability = math_max(self._invulnerability, 0.7)

    local count = math_min(MAX_ENEMIES, #SPAWN_POINTS, 2 + self._wave * 2)
    local sentries = math_min(count - 1, self._wave)

    for i = 1, count do
        local kind = i <= sentries and "sentry" or "wisp"
        local x, y = self:_find_spawn_position()

        self:_add_enemy(kind, x, y)
    end

    self:_set_message("WAVE " .. tostring(self._wave) .. " // BREACH DETECTED", 1.5)

    if self._wave_callback then
        self._wave_callback(self._wave, false)
    end
end

function NoosphereBreachGame:_spawn_boss()
    self._wave = BOSS_WAVE
    self._state = "playing"
    self._wave_active = true
    self._invulnerability = math_max(self._invulnerability, 1.0)
    clear_array(self._enemy_projectiles)
    clear_array(self._telegraphs)

    local health = 620

    self._enemies[#self._enemies + 1] = {
        x = 6.5,
        y = 1.6,
        vx = 0,
        vy = 0,
        angle = math_pi * 0.5,
        size = 0.68,
        radius = 0.62,
        kind = "cortex",
        alive = true,
        health = health,
        max_health = health,
        phase = 1,
        speed = 0.72,
        attack_timer = 1.1,
        attack_cycle = 0,
        contact_timer = 0,
        dash_hit_id = -1,
    }

    self:_set_message("WARNING // CORTEX MANIFEST", 2.6)
    self._shake = 0.8
    self:_spawn_burst(6.5, 1.6, "cortex", 36, 3.8)

    if self._wave_callback then
        self._wave_callback(self._wave, true)
    end
end

function NoosphereBreachGame:_begin_wave_transition()
    self._wave_active = false
    self._dash_timer = 0
    self._player.dash_time = 0
    clear_array(self._enemy_projectiles)
    clear_array(self._telegraphs)
    self._combo = 0
    self._combo_time = 0

    if self._wave >= ORDINARY_WAVES then
        self._state = "boss_intro"
        self._state_timer = 3.0
        self:_set_message("ANOMALY ASCENDANT // CORTEX INBOUND", 3.0)
        self._shake = math_max(self._shake, 0.45)
    else
        self._state = "wave"
        self._state_timer = 1.8
        self:_set_message("WAVE PURGED // STABILIZING", 1.8)
    end
end

function NoosphereBreachGame:_find_spawn_position()
    local player = self._player
    local start_index = self:_random_index(#SPAWN_POINTS)

    for offset = 0, #SPAWN_POINTS - 1 do
        local index = (start_index + offset - 1) % #SPAWN_POINTS + 1
        local point = SPAWN_POINTS[index]
        local clear = distance_sq(player.x, player.y, point[1], point[2]) > 16

        if clear then
            for i = 1, #self._enemies do
                local enemy = self._enemies[i]

                if distance_sq(enemy.x, enemy.y, point[1], point[2]) < 0.8 then
                    clear = false
                    break
                end
            end
        end

        if clear then
            return point[1], point[2]
        end
    end

    for offset = 0, #SPAWN_POINTS - 1 do
        local index = (start_index + offset - 1) % #SPAWN_POINTS + 1
        local point = SPAWN_POINTS[index]
        local clear = true

        for i = 1, #self._enemies do
            local enemy = self._enemies[i]

            if distance_sq(enemy.x, enemy.y, point[1], point[2]) < 0.8 then
                clear = false
                break
            end
        end

        if clear then
            return point[1], point[2]
        end
    end

    local fallback = SPAWN_POINTS[start_index]

    return fallback[1], fallback[2]
end

function NoosphereBreachGame:_add_enemy(kind, x, y)
    if #self._enemies >= MAX_ENEMIES then return end

    local wave = self._wave
    local is_sentry = kind == "sentry"
    local health = is_sentry and 48 + wave * 8 or 30 + wave * 6
    local radius = is_sentry and 0.31 or 0.26

    self._enemies[#self._enemies + 1] = {
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        angle = 0,
        size = radius,
        radius = radius,
        kind = kind,
        alive = true,
        health = health,
        max_health = health,
        phase = 1,
        speed = is_sentry and 0.82 + wave * 0.035 or 1.1 + wave * 0.07,
        attack_timer = is_sentry and 0.8 + self:_random() * 0.7 or 0,
        contact_timer = 0,
        strafe = self:_random() < 0.5 and -1 or 1,
        dash_hit_id = -1,
    }
end

function NoosphereBreachGame:_update_enemies(dt)
    for i = #self._enemies, 1, -1 do
        local enemy = self._enemies[i]

        if enemy.kind == "cortex" then
            self:_update_cortex(enemy, dt)
        elseif enemy.kind == "sentry" then
            self:_update_sentry(enemy, dt)
        else
            self:_update_wisp(enemy, dt)
        end

        enemy.contact_timer = math_max(0, enemy.contact_timer - dt)
    end
end

function NoosphereBreachGame:_update_wisp(enemy, dt)
    local player = self._player
    local dx, dy = normalize(player.x - enemy.x, player.y - enemy.y)
    local speed = enemy.speed

    enemy.vx = dx * speed
    enemy.vy = dy * speed
    enemy.angle = atan2(dy, dx)
    self:_move_entity(enemy, enemy.vx * dt, enemy.vy * dt, enemy.radius)
end

function NoosphereBreachGame:_update_sentry(enemy, dt)
    local player = self._player
    local to_x = player.x - enemy.x
    local to_y = player.y - enemy.y
    local dx, dy, distance = normalize(to_x, to_y)
    local move_x = 0
    local move_y = 0

    if distance < 3.1 then
        move_x = -dx
        move_y = -dy
    elseif distance > 5.4 then
        move_x = dx
        move_y = dy
    else
        move_x = -dy * enemy.strafe
        move_y = dx * enemy.strafe
    end

    enemy.vx = move_x * enemy.speed
    enemy.vy = move_y * enemy.speed
    enemy.angle = atan2(dy, dx)

    if not self:_move_entity(enemy, enemy.vx * dt, enemy.vy * dt, enemy.radius) then
        enemy.strafe = -enemy.strafe
    end

    enemy.attack_timer = enemy.attack_timer - dt

    if enemy.attack_timer <= 0 and distance < 8.5 then
        enemy.attack_timer = math_max(0.8, 1.8 - self._wave * 0.12) + self:_random() * 0.35
        self:_add_telegraph({
            x = enemy.x,
            y = enemy.y,
            angle = enemy.angle,
            length = 8.5,
            width = 0.16,
            radius = 0,
            life = 0.42,
            max_life = 0.42,
            kind = "sentry_shot",
            owner = enemy,
            damage = 12,
            speed = 5.4 + self._wave * 0.2,
        })
    end
end

function NoosphereBreachGame:_update_cortex(enemy, dt)
    local health_ratio = enemy.health / enemy.max_health
    local new_phase = health_ratio > 0.66 and 1 or health_ratio > 0.33 and 2 or 3

    if new_phase ~= enemy.phase then
        enemy.phase = new_phase
        enemy.attack_timer = 0.75
        self._shake = 0.9
        self:_set_message("CORTEX PHASE " .. tostring(new_phase) .. " // LOGIC FRACTURE", 1.8)
        self:_spawn_burst(enemy.x, enemy.y, "cortex_phase", 28, 3.4)
    end

    local player = self._player
    local dx, dy, distance = normalize(player.x - enemy.x, player.y - enemy.y)
    local move_x = 0
    local move_y = 0

    if distance > 4.6 then
        move_x = dx
        move_y = dy
    elseif distance < 3.0 then
        move_x = -dx
        move_y = -dy
    else
        local direction = math_sin(self._time * 0.65) >= 0 and 1 or -1
        move_x = -dy * direction
        move_y = dx * direction
    end

    local speed = enemy.speed + (enemy.phase - 1) * 0.13
    enemy.vx = move_x * speed
    enemy.vy = move_y * speed
    enemy.angle = atan2(dy, dx)
    self:_move_entity(enemy, enemy.vx * dt, enemy.vy * dt, enemy.radius)

    enemy.attack_timer = enemy.attack_timer - dt

    if enemy.attack_timer <= 0 then
        enemy.attack_cycle = enemy.attack_cycle + 1
        enemy.attack_timer = math_max(0.75, 1.6 - enemy.phase * 0.16)

        if enemy.attack_cycle % 3 == 0 then
            self:_telegraph_cortex_nova(enemy)
        elseif enemy.attack_cycle % 3 == 1 then
            self:_telegraph_cortex_spread(enemy)
        else
            self:_telegraph_cortex_lance(enemy)
        end
    end
end

function NoosphereBreachGame:_telegraph_cortex_spread(enemy)
    self:_add_telegraph({
        x = enemy.x,
        y = enemy.y,
        angle = enemy.angle,
        length = 10,
        width = 0.9 + enemy.phase * 0.16,
        radius = 0,
        life = 0.72,
        max_life = 0.72,
        kind = "cortex_spread",
        owner = enemy,
        count = 3 + enemy.phase * 2,
        damage = 10 + enemy.phase * 2,
        speed = 4.6 + enemy.phase * 0.35,
    })
end

function NoosphereBreachGame:_telegraph_cortex_nova(enemy)
    self:_add_telegraph({
        x = enemy.x,
        y = enemy.y,
        angle = 0,
        length = 0,
        width = 0.22,
        radius = 1.8 + enemy.phase * 0.45,
        life = 0.9,
        max_life = 0.9,
        kind = "cortex_nova",
        owner = enemy,
        count = 8 + enemy.phase * 4,
        damage = 9 + enemy.phase,
        speed = 3.7 + enemy.phase * 0.4,
    })
end

function NoosphereBreachGame:_telegraph_cortex_lance(enemy)
    self:_add_telegraph({
        x = enemy.x,
        y = enemy.y,
        angle = enemy.angle,
        length = 12,
        width = 0.24,
        radius = 0,
        life = 0.62,
        max_life = 0.62,
        kind = "cortex_lance",
        owner = enemy,
        count = enemy.phase,
        damage = 17,
        speed = 7.2,
    })
end

function NoosphereBreachGame:_add_telegraph(telegraph)
    if #self._telegraphs >= MAX_TELEGRAPHS then
        table_remove(self._telegraphs, 1)
    end

    self._telegraphs[#self._telegraphs + 1] = telegraph
end

function NoosphereBreachGame:_update_telegraphs(dt)
    for i = #self._telegraphs, 1, -1 do
        local telegraph = self._telegraphs[i]
        local owner = telegraph.owner

        if not owner or not owner.alive then
            table_remove(self._telegraphs, i)
        else
            telegraph.life = telegraph.life - dt

            if telegraph.kind ~= "sentry_shot" then
                telegraph.x = owner.x
                telegraph.y = owner.y
            end

            if telegraph.life <= 0 then
                self:_execute_telegraph(telegraph)
                table_remove(self._telegraphs, i)
            end
        end
    end
end

function NoosphereBreachGame:_execute_telegraph(telegraph)
    if telegraph.kind == "cortex_nova" then
        local count = telegraph.count
        local offset = self._time * 0.7

        for i = 1, count do
            local angle = offset + (i - 1) / count * TWO_PI
            self:_spawn_enemy_projectile(telegraph.x, telegraph.y, angle, telegraph.speed, telegraph.damage, "cortex_orb", 0.13)
        end
    elseif telegraph.kind == "cortex_spread" then
        local count = telegraph.count
        local spread = 0.22 + count * 0.055

        for i = 1, count do
            local t = count == 1 and 0 or (i - 1) / (count - 1) - 0.5
            local angle = telegraph.angle + t * spread

            self:_spawn_enemy_projectile(telegraph.x, telegraph.y, angle, telegraph.speed, telegraph.damage, "cortex_shard", 0.11)
        end
    elseif telegraph.kind == "cortex_lance" then
        for i = 1, telegraph.count do
            local offset = (i - (telegraph.count + 1) * 0.5) * 0.11
            self:_spawn_enemy_projectile(telegraph.x, telegraph.y, telegraph.angle + offset, telegraph.speed, telegraph.damage, "cortex_lance", 0.15)
        end
    else
        self:_spawn_enemy_projectile(
            telegraph.x,
            telegraph.y,
            telegraph.angle,
            telegraph.speed,
            telegraph.damage,
            "sentry_bolt",
            0.1
        )
    end
end

function NoosphereBreachGame:_spawn_enemy_projectile(x, y, angle, speed, damage, kind, radius)
    if #self._enemy_projectiles >= MAX_ENEMY_PROJECTILES then
        table_remove(self._enemy_projectiles, 1)
    end

    local nx = math_cos(angle)
    local ny = math_sin(angle)

    self._enemy_projectiles[#self._enemy_projectiles + 1] = {
        x = x + nx * 0.3,
        y = y + ny * 0.3,
        vx = nx * speed,
        vy = ny * speed,
        life = 3.4,
        max_life = 3.4,
        kind = kind,
        angle = angle,
        size = radius,
        radius = radius,
        damage = damage,
    }
end

function NoosphereBreachGame:_update_player_projectiles(dt)
    for i = #self._player_projectiles, 1, -1 do
        local projectile = self._player_projectiles[i]

        projectile.x = projectile.x + projectile.vx * dt
        projectile.y = projectile.y + projectile.vy * dt
        projectile.life = projectile.life - dt

        local remove = projectile.life <= 0 or self:_point_is_wall(projectile.x, projectile.y)

        if not remove then
            for enemy_index = #self._enemies, 1, -1 do
                local enemy = self._enemies[enemy_index]
                local radius = projectile.radius + enemy.radius

                if distance_sq(projectile.x, projectile.y, enemy.x, enemy.y) <= radius * radius then
                    self:_damage_enemy(enemy_index, projectile.damage, projectile.kind)
                    remove = true
                    break
                end
            end
        end

        if remove then
            table_remove(self._player_projectiles, i)
        end
    end
end

function NoosphereBreachGame:_update_enemy_projectiles(dt)
    local player = self._player

    for i = #self._enemy_projectiles, 1, -1 do
        local projectile = self._enemy_projectiles[i]

        projectile.x = projectile.x + projectile.vx * dt
        projectile.y = projectile.y + projectile.vy * dt
        projectile.life = projectile.life - dt

        local remove = projectile.life <= 0 or self:_point_is_wall(projectile.x, projectile.y)

        if not remove then
            local radius = projectile.radius + PLAYER_RADIUS

            if distance_sq(projectile.x, projectile.y, player.x, player.y) <= radius * radius then
                self:_damage_player(projectile.damage, projectile.kind)
                remove = true
            end
        end

        if remove then
            table_remove(self._enemy_projectiles, i)
        end
    end
end

function NoosphereBreachGame:_check_enemy_contact()
    local player = self._player

    for i = #self._enemies, 1, -1 do
        local enemy = self._enemies[i]
        local radius = PLAYER_RADIUS + enemy.radius

        if enemy.contact_timer <= 0 and distance_sq(player.x, player.y, enemy.x, enemy.y) <= radius * radius then
            local damage = enemy.kind == "cortex" and 22 or enemy.kind == "sentry" and 10 or 14

            if self:_damage_player(damage, enemy.kind) then
                enemy.contact_timer = enemy.kind == "cortex" and 0.8 or 1.0

                local dx, dy = normalize(player.x - enemy.x, player.y - enemy.y)
                self:_move_entity(player, dx * 0.35, dy * 0.35, PLAYER_RADIUS)
            end
        end
    end
end

function NoosphereBreachGame:_damage_enemy(index, damage, source)
    local enemy = self._enemies[index]

    if not enemy or not enemy.alive then return end

    enemy.health = math_max(0, enemy.health - damage)
    self._shake = math_min(1, self._shake + (enemy.kind == "cortex" and 0.08 or 0.035))
    self:_spawn_burst(enemy.x, enemy.y, "enemy_hit", enemy.kind == "cortex" and 4 or 2, 1.5)

    if enemy.health <= 0 then
        self:_kill_enemy(index, source)
    end
end

function NoosphereBreachGame:_kill_enemy(index, source)
    local enemy = self._enemies[index]
    local is_boss = enemy.kind == "cortex"
    local base_score = is_boss and 2500 or enemy.kind == "sentry" and 180 or 110

    enemy.alive = false
    self._combo = self._combo + 1
    self._combo_time = COMBO_WINDOW

    local multiplier = self:multiplier()
    local points = base_score * multiplier

    self._best_multiplier = math_max(self._best_multiplier, multiplier)
    self._score = self._score + points
    self._shake = is_boss and 1 or math_min(1, self._shake + 0.24)
    self:_spawn_burst(enemy.x, enemy.y, is_boss and "cortex_death" or "enemy_death", is_boss and 70 or 18, is_boss and 5.0 or 2.8)
    table_remove(self._enemies, index)

    if self._kill_callback then
        self._kill_callback(enemy, points, source)
    end

    if is_boss then
        clear_array(self._enemy_projectiles)
        clear_array(self._telegraphs)
        self._wave_active = false
        self._state = "victory"
        self:_set_message("CORTEX SILENCED // NOOSPHERE SECURED", 8)
    end
end

function NoosphereBreachGame:_damage_player(damage, source)
    if self._state ~= "playing" or self._invulnerability > 0 or not self._player.alive then
        return false
    end

    self._health = math_max(0, self._health - damage)
    self._player.health = self._health
    self._invulnerability = 0.55
    self._combo = 0
    self._combo_time = 0
    self._shake = math_min(1, self._shake + 0.65)
    self:_spawn_burst(self._player.x, self._player.y, "player_hit", 18, 3.2)

    if self._hit_callback then
        self._hit_callback(damage, source)
    end

    if self._health <= 0 then
        self._player.alive = false
        self._state = "dead"
        self._wave_active = false
        clear_array(self._telegraphs)
        self:_set_message("SIGNAL LOST // BREACH CONSUMED", 8)
        self._shake = 1
        self:_spawn_burst(self._player.x, self._player.y, "player_death", 46, 4.2)
    else
        self:_set_message("INTEGRITY " .. tostring(self:health()) .. "%", 0.75)
    end

    return true
end

function NoosphereBreachGame:_spawn_particle(x, y, z, vx, vy, vz, life, kind, size)
    if #self._particles >= MAX_PARTICLES then
        table_remove(self._particles, 1)
    end

    self._particles[#self._particles + 1] = {
        x = x,
        y = y,
        z = z,
        vx = vx,
        vy = vy,
        vz = vz,
        life = life,
        max_life = life,
        kind = kind,
        size = size,
    }
end

function NoosphereBreachGame:_spawn_burst(x, y, kind, count, speed)
    for i = 1, count do
        local angle = self:_random() * TWO_PI
        local particle_speed = speed * (0.3 + self:_random() * 0.7)
        local life = 0.25 + self:_random() * 0.55

        self:_spawn_particle(
            x,
            y,
            self:_random() * 0.18,
            math_cos(angle) * particle_speed,
            math_sin(angle) * particle_speed,
            0.25 + self:_random() * 0.9,
            life,
            kind,
            0.04 + self:_random() * 0.1
        )
    end
end

function NoosphereBreachGame:_update_particles(dt)
    for i = #self._particles, 1, -1 do
        local particle = self._particles[i]

        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.z = math_max(0, particle.z + particle.vz * dt)
        particle.vx = particle.vx * math_max(0, 1 - dt * 2.2)
        particle.vy = particle.vy * math_max(0, 1 - dt * 2.2)
        particle.vz = particle.vz - dt * 2.4
        particle.life = particle.life - dt

        if particle.life <= 0 then
            table_remove(self._particles, i)
        end
    end
end

return NoosphereBreachGame
