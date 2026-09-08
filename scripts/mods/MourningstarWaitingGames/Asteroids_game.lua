local math_abs = math.abs
local math_atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_random = math.random
local math_sin = math.sin
local math_sqrt = math.sqrt

local GAME_W = 600
local GAME_H = 600
local CENTER_X = GAME_W * 0.5
local CENTER_Y = GAME_H * 0.5
local TWO_PI = math_pi * 2

local SHIP_RADIUS = 13
local MAX_SPEED = 360
local THRUST = 430
local DRAG = 0.992
local TURN_SPEED = 4.6
local BULLET_SPEED = 470
local BULLET_LIFE = 1.05
local FIRE_COOLDOWN = 0.16
local INVULN_TIME = 2.1
local RESPAWN_TIME = 1.2
local MAX_LIVES = 3

local SIZE_RADIUS = { 42, 27, 16 }
local SIZE_SCORE = { 20, 50, 100 }
local SIZE_SPLITS = { 3, 2, 0 }

local function clamp_speed(vx, vy)
    local speed_sq = vx * vx + vy * vy
    local max_sq = MAX_SPEED * MAX_SPEED

    if speed_sq > max_sq then
        local scale = MAX_SPEED / math_sqrt(speed_sq)
        return vx * scale, vy * scale
    end

    return vx, vy
end

local function wrap_position(e, margin)
    margin = margin or 0

    if e.x < -margin then
        e.x = GAME_W + margin
    elseif e.x > GAME_W + margin then
        e.x = -margin
    end

    if e.y < -margin then
        e.y = GAME_H + margin
    elseif e.y > GAME_H + margin then
        e.y = -margin
    end
end

local function distance_sq(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by

    return dx * dx + dy * dy
end

local function random_edge_position()
    local edge = math_random(4)

    if edge == 1 then
        return -40, math_random() * GAME_H
    elseif edge == 2 then
        return GAME_W + 40, math_random() * GAME_H
    elseif edge == 3 then
        return math_random() * GAME_W, -40
    end

    return math_random() * GAME_W, GAME_H + 40
end

local function random_angle()
    return math_random() * TWO_PI
end

local function build_rock_shape(size)
    local radius = SIZE_RADIUS[size]
    local points = 8 + math_random(4)
    local shape = {}

    for i = 1, points do
        local angle = (i - 1) / points * TWO_PI
        local r = radius * (0.68 + math_random() * 0.5)

        shape[i] = {
            x = math_cos(angle) * r,
            y = math_sin(angle) * r,
        }
    end

    return shape
end

local AsteroidsGame = {}
AsteroidsGame.__index = AsteroidsGame

function AsteroidsGame:new()
    return setmetatable({
        _ship = {},
        _bullets = {},
        _rocks = {},
        _particles = {},
        _debris = {},
        _stars = {},
        _score = 0,
        _lives = MAX_LIVES,
        _wave = 0,
        _fire_cooldown = 0,
        _invuln = 0,
        _respawn_timer = 0,
        _shake = 0,
        _state = "idle",
        _thrusting = false,
        _braking = false,
        _level_text = "",
        _time = 0,
    }, AsteroidsGame)
end

function AsteroidsGame:start()
    self._bullets = {}
    self._rocks = {}
    self._particles = {}
    self._debris = {}
    self._stars = {}
    self._score = 0
    self._lives = MAX_LIVES
    self._wave = 0
    self._fire_cooldown = 0
    self._invuln = INVULN_TIME
    self._respawn_timer = 0
    self._shake = 0
    self._state = "playing"
    self._thrusting = false
    self._braking = false
    self._level_text = "Wave 1"
    self._time = 0

    self:_reset_ship()
    self:_build_starfield()
    self:_spawn_wave()
end

function AsteroidsGame:score() return self._score end
function AsteroidsGame:lives() return self._lives end
function AsteroidsGame:wave() return self._wave end
function AsteroidsGame:state() return self._state end
function AsteroidsGame:level_text() return self._level_text end
function AsteroidsGame:is_game_over() return self._state == "dead" end
function AsteroidsGame:shake() return self._shake end
function AsteroidsGame:time() return self._time end

function AsteroidsGame:entities()
    return {
        ship = self._state ~= "dead" and self._ship or nil,
        bullets = self._bullets,
        rocks = self._rocks,
        particles = self._particles,
        debris = self._debris,
        stars = self._stars,
        thrusting = self._thrusting,
        braking = self._braking,
        invulnerable = self._invuln > 0,
    }
end

function AsteroidsGame:turn(dir, dt)
    if self._state ~= "playing" or not self._ship.alive then return end

    self._ship.angle = self._ship.angle + dir * TURN_SPEED * (dt or 0.016)
end

function AsteroidsGame:thrust(dt)
    if self._state ~= "playing" or not self._ship.alive then return end

    dt = dt or 0.016
    local angle = self._ship.angle

    self._ship.vx = self._ship.vx + math_cos(angle) * THRUST * dt
    self._ship.vy = self._ship.vy + math_sin(angle) * THRUST * dt
    self._ship.vx, self._ship.vy = clamp_speed(self._ship.vx, self._ship.vy)
    self._thrusting = true

    if math_random() < 0.85 then
        local back = angle + math_pi
        self:_spawn_particle(
            self._ship.x + math_cos(back) * 14,
            self._ship.y + math_sin(back) * 14,
            self._ship.vx * 0.25 + math_cos(back + (math_random() - 0.5) * 0.7) * (80 + math_random() * 120),
            self._ship.vy * 0.25 + math_sin(back + (math_random() - 0.5) * 0.7) * (80 + math_random() * 120),
            0.18 + math_random() * 0.18,
            3 + math_random() * 5,
            "flame"
        )
    end
end

function AsteroidsGame:brake(dt)
    if self._state ~= "playing" or not self._ship.alive then return end

    local damp = math_max(0.0, 1.0 - 2.9 * (dt or 0.016))

    self._ship.vx = self._ship.vx * damp
    self._ship.vy = self._ship.vy * damp
    self._braking = true
end

function AsteroidsGame:fire()
    if self._state ~= "playing" or not self._ship.alive then return end
    if self._fire_cooldown > 0 then return end
    if #self._bullets >= 12 then return end

    local angle = self._ship.angle
    local nx = math_cos(angle)
    local ny = math_sin(angle)

    self._bullets[#self._bullets + 1] = {
        x = self._ship.x + nx * 17,
        y = self._ship.y + ny * 17,
        px = self._ship.x + nx * 5,
        py = self._ship.y + ny * 5,
        vx = self._ship.vx * 0.45 + nx * BULLET_SPEED,
        vy = self._ship.vy * 0.45 + ny * BULLET_SPEED,
        life = BULLET_LIFE,
        max_life = BULLET_LIFE,
    }

    self._fire_cooldown = FIRE_COOLDOWN

    self:_spawn_particle(self._ship.x + nx * 20, self._ship.y + ny * 20, nx * 45, ny * 45, 0.12, 9, "muzzle")
end

function AsteroidsGame:update(dt)
    if self._state == "dead" then return end

    self._time = self._time + dt
    self._thrusting = false
    self._braking = false
    self._fire_cooldown = math_max(0, self._fire_cooldown - dt)
    self._invuln = math_max(0, self._invuln - dt)
    self._shake = math_max(0, self._shake - dt * 14)

    self:_update_stars(dt)
    self:_update_particles(dt)
    self:_update_debris(dt)
    self:_update_bullets(dt)
    self:_update_rocks(dt)

    if self._state == "respawn" then
        self._respawn_timer = self._respawn_timer - dt

        if self._respawn_timer <= 0 then
            self:_reset_ship()
            self._invuln = INVULN_TIME
            self._state = "playing"
        end

        return
    end

    if self._state ~= "playing" then return end

    self:_update_ship(dt)
    self:_collisions()

    if #self._rocks == 0 then
        self._level_text = "Wave " .. tostring(self._wave + 1)
        self:_spawn_wave()
        self._invuln = math_max(self._invuln, 1.0)
    end
end

function AsteroidsGame:_reset_ship()
    self._ship.x = CENTER_X
    self._ship.y = CENTER_Y
    self._ship.vx = 0
    self._ship.vy = 0
    self._ship.angle = -math_pi * 0.5
    self._ship.alive = true
end

function AsteroidsGame:_build_starfield()
    for i = 1, 90 do
        local layer = i <= 45 and 1 or i <= 72 and 2 or 3
        self._stars[i] = {
            x = math_random() * GAME_W,
            y = math_random() * GAME_H,
            layer = layer,
            pulse = math_random() * TWO_PI,
            size = layer + math_random() * layer,
        }
    end
end

function AsteroidsGame:_update_stars(dt)
    local ship = self._ship

    for i = 1, #self._stars do
        local star = self._stars[i]
        local parallax = star.layer * 0.015

        star.x = star.x - ship.vx * parallax * dt
        star.y = star.y - ship.vy * parallax * dt
        star.pulse = star.pulse + dt * (1 + star.layer * 0.35)
        wrap_position(star, 0)
    end
end

function AsteroidsGame:_spawn_wave()
    self._wave = self._wave + 1
    self._level_text = ""

    local count = math_min(12, 3 + self._wave)

    for i = 1, count do
        local x, y = random_edge_position()
        local angle = math_atan2(CENTER_Y - y, CENTER_X - x) + (math_random() - 0.5) * 1.4
        local speed = 35 + math_random() * (35 + self._wave * 8)

        self:_spawn_rock(x, y, 1, math_cos(angle) * speed, math_sin(angle) * speed)
    end
end

function AsteroidsGame:_spawn_rock(x, y, size, vx, vy)
    local radius = SIZE_RADIUS[size]

    self._rocks[#self._rocks + 1] = {
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        size = size,
        radius = radius,
        angle = random_angle(),
        spin = (math_random() - 0.5) * (1.1 + size * 0.25),
        shape = build_rock_shape(size),
        glow = math_random() * TWO_PI,
    }
end

function AsteroidsGame:_update_ship(dt)
    local ship = self._ship

    ship.x = ship.x + ship.vx * dt
    ship.y = ship.y + ship.vy * dt
    ship.vx = ship.vx * DRAG
    ship.vy = ship.vy * DRAG

    wrap_position(ship, SHIP_RADIUS)
end

function AsteroidsGame:_update_bullets(dt)
    for i = #self._bullets, 1, -1 do
        local b = self._bullets[i]

        b.px = b.x
        b.py = b.y
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.life = b.life - dt

        local wrapped = false

        if b.x < 0 then
            b.x = GAME_W
            wrapped = true
        elseif b.x > GAME_W then
            b.x = 0
            wrapped = true
        end

        if b.y < 0 then
            b.y = GAME_H
            wrapped = true
        elseif b.y > GAME_H then
            b.y = 0
            wrapped = true
        end

        if wrapped then
            b.px = b.x
            b.py = b.y
        end

        if b.life <= 0 then
            table.remove(self._bullets, i)
        end
    end
end

function AsteroidsGame:_update_rocks(dt)
    for i = 1, #self._rocks do
        local rock = self._rocks[i]

        rock.x = rock.x + rock.vx * dt
        rock.y = rock.y + rock.vy * dt
        rock.angle = rock.angle + rock.spin * dt
        rock.glow = rock.glow + dt
        wrap_position(rock, rock.radius)
    end
end

function AsteroidsGame:_update_particles(dt)
    for i = #self._particles, 1, -1 do
        local p = self._particles[i]

        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vx = p.vx * (1 - dt * 0.8)
        p.vy = p.vy * (1 - dt * 0.8)
        p.life = p.life - dt

        if p.life <= 0 then
            table.remove(self._particles, i)
        end
    end
end

function AsteroidsGame:_update_debris(dt)
    for i = #self._debris, 1, -1 do
        local d = self._debris[i]

        d.x = d.x + d.vx * dt
        d.y = d.y + d.vy * dt
        d.angle = d.angle + d.spin * dt
        d.life = d.life - dt

        if d.life <= 0 then
            table.remove(self._debris, i)
        end
    end
end

function AsteroidsGame:_collisions()
    for bi = #self._bullets, 1, -1 do
        local bullet = self._bullets[bi]
        local hit_index = nil

        for ri = #self._rocks, 1, -1 do
            local rock = self._rocks[ri]

            if distance_sq(bullet.x, bullet.y, rock.x, rock.y) <= rock.radius * rock.radius then
                hit_index = ri
                break
            end
        end

        if hit_index then
            local rock = self._rocks[hit_index]

            table.remove(self._bullets, bi)
            self:_destroy_rock(hit_index, bullet.vx * 0.05, bullet.vy * 0.05)
            self._score = self._score + SIZE_SCORE[rock.size]
        end
    end

    if self._invuln > 0 or not self._ship.alive then return end

    for i = 1, #self._rocks do
        local rock = self._rocks[i]
        local radius = rock.radius + SHIP_RADIUS * 0.8

        if distance_sq(self._ship.x, self._ship.y, rock.x, rock.y) <= radius * radius then
            self:_kill_ship()
            return
        end
    end
end

function AsteroidsGame:_destroy_rock(index, impulse_x, impulse_y)
    local rock = self._rocks[index]
    local size = rock.size

    table.remove(self._rocks, index)
    self._shake = math_min(1.0, self._shake + 0.28 + (4 - size) * 0.08)
    self:_spawn_explosion(rock.x, rock.y, size)

    local splits = SIZE_SPLITS[size]
    if splits > 0 then
        for i = 1, splits do
            local angle = random_angle()
            local speed = 75 + math_random() * (80 + self._wave * 8)

            self:_spawn_rock(
                rock.x + math_cos(angle) * 6,
                rock.y + math_sin(angle) * 6,
                size + 1,
                rock.vx * 0.35 + impulse_x + math_cos(angle) * speed,
                rock.vy * 0.35 + impulse_y + math_sin(angle) * speed
            )
        end
    end
end

function AsteroidsGame:_kill_ship()
    self._lives = self._lives - 1
    self._ship.alive = false
    self._shake = 1.0
    self:_spawn_explosion(self._ship.x, self._ship.y, 0)

    if self._lives <= 0 then
        self._state = "dead"
    else
        self._state = "respawn"
        self._respawn_timer = RESPAWN_TIME
    end
end

function AsteroidsGame:_spawn_particle(x, y, vx, vy, life, size, kind)
    if #self._particles >= 120 then
        table.remove(self._particles, 1)
    end

    self._particles[#self._particles + 1] = {
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        life = life,
        max_life = life,
        size = size,
        kind = kind,
    }
end

function AsteroidsGame:_spawn_debris(x, y, angle, speed, length, life)
    if #self._debris >= 70 then
        table.remove(self._debris, 1)
    end

    self._debris[#self._debris + 1] = {
        x = x,
        y = y,
        vx = math_cos(angle) * speed,
        vy = math_sin(angle) * speed,
        angle = angle,
        spin = (math_random() - 0.5) * 8,
        length = length,
        life = life,
        max_life = life,
    }
end

function AsteroidsGame:_spawn_explosion(x, y, rock_size)
    local count = rock_size == 0 and 44 or 16 + (4 - rock_size) * 10
    local base_speed = rock_size == 0 and 180 or 90 + (4 - rock_size) * 35

    for i = 1, count do
        local angle = random_angle()
        local speed = base_speed * (0.35 + math_random())

        self:_spawn_particle(
            x,
            y,
            math_cos(angle) * speed,
            math_sin(angle) * speed,
            0.35 + math_random() * 0.55,
            2 + math_random() * (rock_size == 0 and 8 or 5),
            rock_size == 0 and "ship" or "rock"
        )

        if i <= count * 0.45 then
            self:_spawn_debris(x, y, angle, speed * 0.75, 10 + math_random() * 22, 0.4 + math_random() * 0.55)
        end
    end
end

return AsteroidsGame
