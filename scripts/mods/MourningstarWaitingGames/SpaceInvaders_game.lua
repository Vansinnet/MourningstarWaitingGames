local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min

local GAME_W, GAME_H = 600, 600
local PLAYER_W, PLAYER_H, PLAYER_Y = 38, 20, 546
local PLAYER_BULLET_W, PLAYER_BULLET_H = 4, 14
local ENEMY_BULLET_W, ENEMY_BULLET_H = 5, 14
local ENEMY_COLS, ENEMY_ROWS = 11, 5
local ENEMY_W, ENEMY_H = 30, 22
local ENEMY_PITCH_X, ENEMY_PITCH_Y = 46, 40
local ENEMY_START_X, ENEMY_START_Y = 58, 82
local ENEMY_LIMIT_LEFT, ENEMY_LIMIT_RIGHT, INVASION_Y = 24, 576, 500
local SHIELD_COUNT, SHIELD_BLOCK, SHIELD_Y = 4, 6, 405
local SHIELD_MASK = {
    "0011111100",
    "0111111110",
    "1111111111",
    "1111111111",
    "1111111111",
    "1111101111",
    "1111001111",
    "1110000111",
}
local MYSTERY_W, MYSTERY_H, MYSTERY_Y = 50, 20, 44
local TICK = 1 / 60
local MAX_TICKS = 120
local SCALE_X, SCALE_Y = ENEMY_PITCH_X / 16, ENEMY_PITCH_Y / 16
local PLAYER_SPEED = SCALE_X * 60
local INVADER_SCORES = { 30, 20, 20, 10, 10 }

-- ROM evidence: computerarcheology.com/Arcade/SpaceInvaders/Code.html
-- ColFireTable (1D00), SaucerScrTab (1D54, wraps at 1D63), AlienStartTable (1DA3).
local FIRE_COLUMNS = { 1, 7, 1, 1, 1, 4, 11, 1, 6, 3, 1, 1, 11, 9, 2, 8, 2, 11, 4, 7, 10 }
local MYSTERY_SCORES = { 100, 50, 50, 100, 150, 100, 100, 50, 300, 100, 100, 100, 50, 150, 100 }
local WAVE_STARTS = { 0x60, 0x50, 0x48, 0x48, 0x48, 0x40, 0x40, 0x40 }

local function overlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

local function vertical_hit_time(a, b, dy)
    if a.x >= b.x + b.w or a.x + a.w <= b.x then return math.huge end
    if a.y < b.y + b.h and a.y + a.h > b.y then return 0 end
    if dy > 0 and a.y + a.h <= b.y then return (b.y - a.y - a.h) / dy end
    if dy < 0 and a.y >= b.y + b.h then return (b.y + b.h - a.y) / dy end
    return math.huge
end

local InvadersGame = {}
InvadersGame.__index = InvadersGame

function InvadersGame:new()
    local game = setmetatable({}, InvadersGame)
    game:start()
    return game
end

function InvadersGame:start()
    self._player_x = (GAME_W - PLAYER_W) * 0.5
    self._player_alive = true
    self._score, self._lives, self._wave = 0, 3, 0
    self._bonus_awarded = false
    self._state, self._state_ticks = "idle", 66
    self._level_text = "WAVE 1"
    self._time, self._shake, self._accumulator = 0, 0, 0
    self._inputs, self._input_head, self._input_tail = {}, 1, 0
    self._input_epoch = 0
    self._pending_move, self._pending_fire = 0, false
    self._mystery_hit_ticks = 0
    self:_spawn_wave()
end

function InvadersGame:score() return self._score end
function InvadersGame:lives() return self._lives end
function InvadersGame:wave() return self._wave end
function InvadersGame:state() return self._state end
function InvadersGame:level_text() return self._level_text end
function InvadersGame:is_game_over() return self._state == "dead" end
function InvadersGame:is_playing() return self._state == "playing" end
function InvadersGame:shake() return self._shake end
function InvadersGame:time() return self._time end
function InvadersGame:mystery_hit_ticks() return self._mystery_hit_ticks or 0 end
function InvadersGame:mystery_x() return self._mystery_x end

-- The host submits input before update(dt), using the same frame dt.
-- Held movement spans transitions; only fire edges are invalidated by an epoch.
-- Fire is an edge, never a held state; an edge while the shot slot is busy is discarded.
function InvadersGame:move_left(dt)
    self._pending_move = self._pending_move - math_max(0, dt or TICK)
end

function InvadersGame:move_right(dt)
    self._pending_move = self._pending_move + math_max(0, dt or TICK)
end

function InvadersGame:fire()
    if self._state == "playing" and not self._player_bullet and self._shot_cleanup_ticks == 0 then
        self._pending_fire = true
    end
end

function InvadersGame:entities()
    return {
        player = self._player_alive and { x = self._player_x, y = PLAYER_Y, w = PLAYER_W, h = PLAYER_H } or nil,
        enemies = self._enemies,
        player_bullets = self._player_bullet and { self._player_bullet } or {},
        enemy_bullets = self._enemy_bullets,
        shields = self._shields,
        mystery = self._mystery_active and { x = self._mystery_x, y = MYSTERY_Y, w = MYSTERY_W, h = MYSTERY_H } or nil,
    }
end

function InvadersGame:update(dt)
    if self._state == "dead" or dt < 0 or dt ~= dt or dt == math.huge then return end
    if dt > 0 then
        local velocity = math_max(-1, math_min(1, self._pending_move / dt)) * PLAYER_SPEED
        local last = self._inputs[self._input_tail]
        if last and last.velocity == velocity and not self._pending_fire and last.epoch == self._input_epoch then
            last.remaining = last.remaining + dt
        else
            self._input_tail = self._input_tail + 1
            self._inputs[self._input_tail] = {
                remaining = dt, velocity = velocity, fire = self._pending_fire, epoch = self._input_epoch,
            }
        end
        self._pending_move, self._pending_fire = 0, false
        self._accumulator = self._accumulator + dt
    end

    -- Bound catch-up work, not elapsed time. update(0) can drain a hitch backlog.
    local ticks = math_min(MAX_TICKS, math_floor((self._accumulator + 1e-10) / TICK))
    for _ = 1, ticks do
        self._accumulator = math_max(0, self._accumulator - TICK)
        self:_tick()
        if self._state == "dead" then
            self._inputs, self._input_head, self._input_tail = {}, 1, 0
            self._accumulator = 0
            break
        end
    end
end

function InvadersGame:_consume_input()
    local remaining = TICK
    while remaining > 1e-10 do
        local input = self._inputs[self._input_head]
        if not input then break end
        local elapsed = math_min(remaining, input.remaining)
        if self._state == "playing" then
            if input.fire and input.epoch == self._input_epoch and not self._player_bullet and self._shot_cleanup_ticks == 0 then
                local y = PLAYER_Y - PLAYER_BULLET_H
                self._player_bullet = {
                    x = self._player_x + (PLAYER_W - PLAYER_BULLET_W) * 0.5,
                    y = y, py = y, w = PLAYER_BULLET_W, h = PLAYER_BULLET_H,
                }
            end
            self._player_x = math_max(16, math_min(GAME_W - PLAYER_W - 16, self._player_x + input.velocity * elapsed))
        end
        input.fire = false
        input.remaining = input.remaining - elapsed
        remaining = remaining - elapsed
        if input.remaining <= 1e-10 then
            self._inputs[self._input_head] = nil
            self._input_head = self._input_head + 1
        end
    end
    if self._input_head > self._input_tail then
        self._inputs, self._input_head, self._input_tail = {}, 1, 0
    end
end

function InvadersGame:_clear_transients()
    if self._mystery_hit_ticks and self._mystery_hit_ticks > 24 then
        self:_add_score(MYSTERY_SCORES[self._saucer_score_index])
    end
    self._player_bullet = nil
    self._shot_cleanup_ticks = 0
    self._enemy_bullets = {}
    self._mystery_active, self._mystery_hit_ticks = false, 0
    self._mystery_pending = false
    self._pending_fire = false
    self._input_epoch = self._input_epoch + 1
    for kind = 1, 3 do
        self._slots[kind].bullet = nil
        self._slots[kind].steps = 0
        self._slots[kind].cooldown = 0
    end
    self._slots[1].skip = true
end

function InvadersGame:_spawn_wave()
    self._wave = self._wave + 1
    self._slots = {
        { steps = 0, cooldown = 0, skip = true },
        { steps = 0, cooldown = 0, column = 1 },
        { steps = 0, cooldown = 0, column = 7 },
    }
    self:_clear_transients()
    self._mystery_timer, self._mystery_pending = 1536, false
    self._mystery_x, self._mystery_dir = -MYSTERY_W, 1
    self._saucer_score_index, self._shots_cleaned = 1, 0
    self._shot_phase, self._alien_fire_delay = 0, 48
    self._march_cursor, self._march_frame = 55, 1
    self._enemy_dir, self._enemy_dx = 1, 2 * SCALE_X
    self._ref_rom_y = self._wave == 1 and 0x78 or WAVE_STARTS[(self._wave - 2) % #WAVE_STARTS + 1]
    self._ref_x = ENEMY_START_X
    self._ref_y = ENEMY_START_Y + 4 * ENEMY_PITCH_Y + (0x78 - self._ref_rom_y) * SCALE_Y
    self._enemies = {}
    for row = 1, ENEMY_ROWS do
        for col = 1, ENEMY_COLS do
            self._enemies[#self._enemies + 1] = {
                x = ENEMY_START_X + (col - 1) * ENEMY_PITCH_X,
                y = self._ref_y - (ENEMY_ROWS - row) * ENEMY_PITCH_Y,
                w = ENEMY_W, h = ENEMY_H, alive = true, row = row, col = col, frame = 1,
            }
        end
    end
    self._alive_count = ENEMY_COLS * ENEMY_ROWS
    self._alien_pause = 0
    self:_spawn_shields()
end

function InvadersGame:_spawn_shields()
    self._shields = {}
    local shield_w = #SHIELD_MASK[1] * SHIELD_BLOCK
    local spacing = (GAME_W - SHIELD_COUNT * shield_w) / (SHIELD_COUNT + 1)
    for shield = 1, SHIELD_COUNT do
        local base_x = spacing + (shield - 1) * (shield_w + spacing)
        for row = 1, #SHIELD_MASK do
            local line = SHIELD_MASK[row]
            for col = 1, #line do
                if line:sub(col, col) == "1" then
                    self._shields[#self._shields + 1] = {
                        x = base_x + (col - 1) * SHIELD_BLOCK,
                        y = SHIELD_Y + (row - 1) * SHIELD_BLOCK,
                        w = SHIELD_BLOCK, h = SHIELD_BLOCK, alive = true, shield = shield,
                    }
                end
            end
        end
    end
end

function InvadersGame:_move_enemies()
    if self._alive_count == 0 then return end
    if self._alien_pause > 0 then
        self._alien_pause = self._alien_pause - 1
        return
    end
    -- CursorNextAlien/MoveRefAlien: skip dead slots without spending a tick.
    for _ = 1, 55 do
        self._march_cursor = self._march_cursor + 1
        if self._march_cursor > 55 then
            self._march_cursor = 1
            local left, right = GAME_W, 0
            for i = 1, #self._enemies do
                local enemy = self._enemies[i]
                if enemy.alive then
                    left, right = math_min(left, enemy.x), math_max(right, enemy.x + ENEMY_W)
                end
            end
            if (self._enemy_dir > 0 and right + self._enemy_dx > ENEMY_LIMIT_RIGHT)
                or (self._enemy_dir < 0 and left + self._enemy_dx < ENEMY_LIMIT_LEFT) then
                self._enemy_dir = -self._enemy_dir
                -- RackBump/18F1 selects +3 only at the left edge, not at the kill.
                self._enemy_dx = self._enemy_dir * (self._enemy_dir > 0 and self._alive_count == 1 and 3 or 2) * SCALE_X
                self._ref_y = self._ref_y + 8 * SCALE_Y
                self._ref_rom_y = self._ref_rom_y - 8
            end
            self._ref_x = self._ref_x + self._enemy_dx
            self._march_frame = 3 - self._march_frame
        end
        local row = ENEMY_ROWS - math_floor((self._march_cursor - 1) / ENEMY_COLS)
        local col = (self._march_cursor - 1) % ENEMY_COLS + 1
        local enemy = self._enemies[(row - 1) * ENEMY_COLS + col]
        if enemy.alive then
            local old_x, old_y = enemy.x, enemy.y
            enemy.x = self._ref_x + (col - 1) * ENEMY_PITCH_X
            enemy.y = self._ref_y - (ENEMY_ROWS - row) * ENEMY_PITCH_Y
            enemy.frame = self._march_frame
            local swept = {
                x = math_min(old_x, enemy.x), y = math_min(old_y, enemy.y),
                w = ENEMY_W + math_abs(enemy.x - old_x), h = ENEMY_H + math_abs(enemy.y - old_y),
            }
            for i = 1, #self._shields do
                local block = self._shields[i]
                if block.alive and overlap(swept, block) then block.alive = false end
            end
            if enemy.y + ENEMY_H >= INVASION_Y then
                self:_clear_transients()
                self._lives, self._player_alive, self._state = 0, false, "dead"
                self._level_text, self._shake = "SECTOR LOST", 1
            end
            return
        end
    end
end

function InvadersGame:_cleanup_player_shot()
    -- EndOfBlowup (0436): advance on cleanup, including misses, never on fire.
    self._player_bullet, self._shot_cleanup_ticks = nil, 0
    self._saucer_score_index = self._saucer_score_index % #MYSTERY_SCORES + 1
    self._shots_cleaned = (self._shots_cleaned + 1) % 256
    if not self._mystery_active and self._mystery_hit_ticks == 0 then
        self._mystery_dir = self._shots_cleaned % 2 == 1 and 1 or -1
    end
end

function InvadersGame:_end_player_shot(ticks)
    self._player_bullet = nil
    self._shot_cleanup_ticks = ticks
    if ticks == 0 then self:_cleanup_player_shot() end
end

function InvadersGame:_add_score(points)
    self._score = self._score + points
    if not self._bonus_awarded and self._score >= 1500 then
        self._bonus_awarded = true
        self._lives = self._lives + 1
    end
end

function InvadersGame:_remove_enemy_bullet(index)
    local bullet = self._enemy_bullets[index]
    local slot = self._slots[bullet.kind]
    slot.bullet, slot.cooldown = nil, 4
    if bullet.kind == 1 then slot.skip = true end
    table.remove(self._enemy_bullets, index)
end

function InvadersGame:_enemy_shoot(kind)
    local slot = self._slots[kind]
    if slot.bullet then
        slot.steps = slot.steps + 1
        slot.bullet.dy = (self._alive_count <= 8 and 5 or 4) * SCALE_Y
        return
    end
    if slot.cooldown > 0 then
        slot.cooldown = slot.cooldown - 1
        if slot.cooldown == 0 then slot.steps = 0 end
        return
    end
    if kind == 1 and slot.skip then
        slot.skip = false
        return
    end
    if self._alien_fire_delay > 0 or (kind == 2 and self._alive_count == 1) then return end

    -- AShotReloadRate compares the BCD hundreds byte inclusively (170E/171C).
    -- Thus the actual boundaries are 300, 1100, 2100, 3100, not 200/1000/etc.
    local hundreds = math_floor(self._score / 100)
    local reload = hundreds <= 2 and 48 or hundreds <= 10 and 16 or hundreds <= 20 and 11 or hundreds <= 30 and 8 or 7
    for other = 1, 3 do
        local steps = self._slots[other].steps
        if other ~= kind and steps > 0 and steps <= reload then return end
    end
    local col
    if kind == 1 then
        col = math_max(1, math_min(ENEMY_COLS, math_floor((self._player_x + PLAYER_W * 0.5 - self._ref_x) / ENEMY_PITCH_X) + 1))
    else
        col = FIRE_COLUMNS[slot.column]
        slot.column = slot.column + 1
        if slot.column > (kind == 2 and 16 or 21) then slot.column = kind == 2 and 1 or 7 end
    end
    for row = ENEMY_ROWS, 1, -1 do
        local enemy = self._enemies[(row - 1) * ENEMY_COLS + col]
        if enemy.alive then
            local bullet = {
                x = enemy.x + (ENEMY_W - ENEMY_BULLET_W) * 0.5, y = enemy.y + ENEMY_H,
                w = ENEMY_BULLET_W, h = ENEMY_BULLET_H, kind = kind, dy = 0,
            }
            slot.bullet, slot.steps = bullet, 1
            self._enemy_bullets[#self._enemy_bullets + 1] = bullet
            return
        end
    end
end

function InvadersGame:_move_mystery(kind)
    -- TimeToSaucer runs even during a trip, but not while refAlienYr >= 78.
    -- Normalize its check-before-decrement to exactly 1536 eligible ticks.
    if self._ref_rom_y < 0x78 then
        self._mystery_timer = self._mystery_timer - 1
        if self._mystery_timer == 0 then
            self._mystery_timer, self._mystery_pending = 1536, true
        end
    end
    if kind ~= 3 then return end
    if self._mystery_hit_ticks > 0 then
        self._mystery_hit_ticks = self._mystery_hit_ticks - 1
        -- GameObj4 (070C) reads the pointer AFTER the hitting shot has cleaned up.
        if self._mystery_hit_ticks == 24 then self:_add_score(MYSTERY_SCORES[self._saucer_score_index]) end
        if self._mystery_hit_ticks == 0 then
            self._mystery_pending, self._mystery_dir = false, 1
        end
        return
    end
    if self._mystery_active then
        self._mystery_x = self._mystery_x + self._mystery_dir * 2 * SCALE_X
        if self._mystery_x > GAME_W or self._mystery_x + MYSTERY_W < 0 then
            self._mystery_active, self._mystery_pending, self._mystery_dir = false, false, 1
        end
    elseif self._mystery_pending and self._alive_count >= 8
        and not self._slots[3].bullet and self._slots[3].steps == 0 then
        self._mystery_active = true
        self._mystery_x = self._mystery_dir > 0 and -MYSTERY_W or GAME_W
    end
end

function InvadersGame:_damage_shield(struck, bullet, upward)
    local cx = math_max(struck.x, math_min(struck.x + struck.w, bullet.x + bullet.w * 0.5))
    local cy = upward and struck.y + struck.h or struck.y
    local radius = SHIELD_BLOCK * (upward and 1.35 or 1.7)
    struck.alive = false
    for i = 1, #self._shields do
        local block = self._shields[i]
        if block.alive and math_abs(block.x + block.w * 0.5 - cx) <= radius
            and math_abs(block.y + block.h * 0.5 - cy) <= radius then
            block.alive = false
        end
    end
end

function InvadersGame:_move_bullets()
    local bullet = self._player_bullet
    if not bullet and #self._enemy_bullets == 0 then return end
    if bullet then bullet.py = bullet.y end

    -- Tile positions never move. Keep conservative bounds even as tiles erode;
    -- a new shield collection (normally a new wave) rebuilds the broad phase.
    if self._shield_bounds_source ~= self._shields then
        local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
        for i = 1, #self._shields do
            local block = self._shields[i]
            left, top = math_min(left, block.x), math_min(top, block.y)
            right, bottom = math_max(right, block.x + block.w), math_max(bottom, block.y + block.h)
        end
        self._shield_left, self._shield_top, self._shield_right, self._shield_bottom = left, top, right, bottom
        self._shield_bounds_source = self._shields
    end

    local remaining = 1
    local player_dy = -4 * SCALE_Y
    local player_box = { x = self._player_x, y = PLAYER_Y, w = PLAYER_W, h = PLAYER_H }
    local mystery_box = { x = self._mystery_x, y = MYSTERY_Y, w = MYSTERY_W, h = MYSTERY_H }
    local hit_time, hit_index, hit_kind, hit_target = math.huge, 0, "", 0
    local function consider(time, index, kind, target)
        -- Exact ties keep candidate order; unequal times never use type priority.
        if time <= remaining and time < hit_time then
            hit_time, hit_index, hit_kind, hit_target = time, index, kind, target
        end
    end

    -- All shots advance to the earliest global impact before any damage. Every
    -- event destroys at least one of the at most four shots; recompute after each
    -- destruction so an erased bunker cannot stop a later shot in this tick.
    for _ = 1, 4 do
        hit_time, hit_index, hit_kind, hit_target = math.huge, 0, "", 0
        bullet = self._player_bullet
        for index = 0, #self._enemy_bullets do
            local moving = index == 0 and bullet or self._enemy_bullets[index]
            if moving then
                local dy = index == 0 and player_dy or moving.dy
                local end_y = moving.y + dy * remaining
                if moving.x < self._shield_right and moving.x + moving.w > self._shield_left
                    and math_min(moving.y, end_y) <= self._shield_bottom
                    and math_max(moving.y, end_y) + moving.h >= self._shield_top then
                    for i = 1, #self._shields do
                        local block = self._shields[i]
                        if block.alive then consider(vertical_hit_time(moving, block, dy), index, "shield", i) end
                    end
                end
                if index == 0 then
                    for i = 1, #self._enemies do
                        local enemy = self._enemies[i]
                        if enemy.alive then consider(vertical_hit_time(moving, enemy, dy), index, "alien", i) end
                    end
                    if self._mystery_active then
                        consider(vertical_hit_time(moving, mystery_box, dy), index, "mystery", 0)
                    end
                    consider(math_max(0, (18 - moving.y) / dy), index, "exit", 0)
                else
                    if bullet then
                        consider(vertical_hit_time(moving, bullet, dy - player_dy), index, "intercept", 0)
                    end
                    if self._player_alive then
                        consider(vertical_hit_time(moving, player_box, dy), index, "player", 0)
                    end
                    if moving.y >= GAME_H then
                        consider(0, index, "exit", 0)
                    elseif dy > 0 then
                        consider((GAME_H - moving.y) / dy, index, "exit", 0)
                    end
                end
            end
        end

        local elapsed = math_min(hit_time, remaining)
        if bullet then bullet.y = bullet.y + player_dy * elapsed end
        for i = 1, #self._enemy_bullets do
            local enemy_bullet = self._enemy_bullets[i]
            enemy_bullet.y = enemy_bullet.y + enemy_bullet.dy * elapsed
        end
        if hit_kind == "" then return end
        remaining = remaining - elapsed
        local moving = hit_index == 0 and bullet or self._enemy_bullets[hit_index]
        if hit_kind == "shield" then self:_damage_shield(self._shields[hit_target], moving, hit_index == 0) end
        if hit_kind == "player" then
            self:_kill_player()
            return
        elseif hit_index ~= 0 then
            self:_remove_enemy_bullet(hit_index)
            if hit_kind == "intercept" then self:_end_player_shot(16) end
        elseif hit_kind == "mystery" then
            self._mystery_active, self._mystery_hit_ticks = false, 32
            self:_end_player_shot(0)
            self._shake = math_min(1, self._shake + 0.45)
        else
            self:_end_player_shot(16)
            if hit_kind == "alien" then
                local enemy = self._enemies[hit_target]
                enemy.alive = false
                self._alive_count = self._alive_count - 1
                self:_add_score(INVADER_SCORES[enemy.row])
                self._alien_pause = 16
                self._shake = math_min(0.8, self._shake + 0.16)
                if self._alive_count == 0 then
                    self._state, self._state_ticks = "wave", 81
                    self._level_text = "WAVE " .. tostring(self._wave + 1)
                    self:_clear_transients()
                    return
                end
            end
        end
    end
end

function InvadersGame:_kill_player()
    if not self._player_alive then return end
    if self._player_bullet or self._shot_cleanup_ticks > 0 then self:_cleanup_player_shot() end
    self._player_alive, self._lives = false, self._lives - 1
    self._state, self._state_ticks, self._shake = "dying", 72, 1
    self:_clear_transients()
    self._alien_fire_delay = 48
end

function InvadersGame:_tick()
    self._time = self._time + TICK
    self._shake = math_max(0, self._shake - TICK * 8)
    if self._shot_cleanup_ticks > 0 then
        self._shot_cleanup_ticks = self._shot_cleanup_ticks - 1
        if self._shot_cleanup_ticks == 0 then self:_cleanup_player_shot() end
    end
    self:_consume_input()
    if self._state ~= "playing" then
        self._state_ticks = self._state_ticks - 1
        if self._state_ticks <= 0 then
            if self._state == "dying" then
                if self._lives <= 0 then self._state = "dead"; return end
                self._player_x, self._player_alive = (GAME_W - PLAYER_W) * 0.5, true
            elseif self._state == "wave" then
                self:_spawn_wave()
            end
            self._state, self._level_text = "playing", ""
        end
        return
    end
    self:_move_enemies()
    if self._state ~= "playing" then return end
    if self._alien_fire_delay > 0 then self._alien_fire_delay = self._alien_fire_delay - 1 end
    -- GameObj2/3/4: rolling, squiggly/saucer, plunger on successive 60 Hz ticks.
    local kind = self._shot_phase == 0 and 1 or self._shot_phase == 1 and 3 or 2
    self._shot_phase = (self._shot_phase + 1) % 3
    for i = 1, #self._enemy_bullets do self._enemy_bullets[i].dy = 0 end
    local saucer_owned_slot = self._mystery_active or self._mystery_hit_ticks > 0
    self:_move_mystery(kind)
    if kind ~= 3 or (not saucer_owned_slot and not self._mystery_active) then self:_enemy_shoot(kind) end
    self:_move_bullets()
end

return InvadersGame
