-- Breakout in the plain Windows 95 style: teal field, red bricks, a white paddle and ball.
-- Pure logic: physics, levels, layout, menus and dialogs. The view only renders and forwards input.
local mod = get_mod("MourningstarWaitingGames")
local Win95 = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_win95")

local math_abs = math.abs
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_random = math.random
local math_sin = math.sin
local math_sqrt = math.sqrt

local CLIENT_W, CLIENT_H = 560, 470
local STEP = 1 / 240

local COLS = 10
local BRICK_W = 48
local BRICK_H = 13
local BRICK_GAP = 3
local BRICK_TOP = 40
local ROW_PITCH = 16
local FIELD_LEFT = math_floor((CLIENT_W - (COLS * BRICK_W + (COLS - 1) * BRICK_GAP)) * 0.5)

local PADDLE_W = 56
local PADDLE_H = 8
local PADDLE_Y = CLIENT_H - 34
local PADDLE_SPEED = 430
local PADDLE_FAST = 650
local BALL_R = 4.5
local BALL_SPEED = 250
local BALL_SPEED_STEP = 4
local BALL_SPEED_MAX = 470
local MAX_BOUNCE = math_pi * 0.36
local LIVES = 3
local LEVEL_PAUSE = 1.6
local LOST_PAUSE = 1.1

-- Level layouts: one string per row, "#" = brick, "=" = tough brick (two hits), "." = gap.
local LEVELS = {
    { "##########", "#.#.#.#.#.", "##########" },
    { "##########", "##########", ".########.", "..######..", "...####..." },
    { "==========", "#.#.##.#.#", "##########", "#.#.##.#.#", "##########" },
    { "#.#.#.#.#.", ".#.#.#.#.#", "#.#.#.#.#.", ".#.#.#.#.#", "==========", "##########" },
    { "....==....", "...####...", "..######..", ".########.", "##########", "=#=#==#=#=" },
    { "==========", "#........#", "#.======.#", "#.#....#.#", "#.######.#", "#........#", "##########" },
    { "##########", "=========.", "##########", ".=========", "##########", "==========" },
    { "=#=#=#=#=#", "#=#=#=#=#=", "=#=#=#=#=#", "#=#=#=#=#=", "==========", "##########", "==========" },
}

local BreakoutGame = {}
BreakoutGame.__index = BreakoutGame

local rect = Win95.rect
local clamp = Win95.clamp

-- options: get(key), set(key, value), on_sound(kind)
function BreakoutGame:new(options)
    local game = setmetatable({}, BreakoutGame)
    game._options = options or {}
    game._events = {}
    game._event_count = 0
    game._held = {}
    game._close_requested = false
    game._pointer_x, game._pointer_y = -1, -1
    game._pointer_seen = false
    game._control = "mouse"
    game._time = 0
    game._acc = 0

    local get = game._options.get
    game._best = tonumber(get and get("breakout_highscore")) or 0

    game._shell = Win95.shell({
        client_w = CLIENT_W,
        client_h = CLIENT_H,
        menus = {
            { id = "game", label = "Game", width = 176, items = {
                { id = "new", label = "New Game", key = "R" },
                { id = "pause", label = "Pause", check = function() return game._paused end,
                    enabled = function() return game._state ~= "over" end },
                { separator = true },
                { id = "exit", label = "Exit", key = "Esc" },
            } },
            { id = "help", label = "Help", width = 176, items = {
                { id = "how_to", label = "How to Play..." },
                { separator = true },
                { id = "about", label = "About Breakout..." },
            } },
        },
        on_command = function(id) game:_command(id) end,
        on_dialog = function(dialog, id) return game:_dialog_button(dialog, id) end,
    })
    game._layout = { client = game._shell:layout().client }
    return game
end

function BreakoutGame:start()
    self:new_game()
end

function BreakoutGame:_persist(key, value)
    local set = self._options.set
    if set then set(key, value) end
end

function BreakoutGame:_sound(kind)
    local on_sound = self._options.on_sound
    if on_sound then on_sound(kind) end
end

function BreakoutGame:_event(kind, x, y, value)
    local n = self._event_count + 1
    local e = self._events[n]
    if not e then
        e = {}
        self._events[n] = e
    end
    e.kind, e.x, e.y, e.value = kind, x, y, value
    self._event_count = n
end

function BreakoutGame:drain_events(callback)
    for i = 1, self._event_count do
        local e = self._events[i]
        callback(e.kind, e.x, e.y, e.value)
    end
    self._event_count = 0
end

-- Game flow ---------------------------------------------------------------------------------

function BreakoutGame:new_game()
    self._shell:close_dialog()
    self._score = 0
    self._lives = LIVES
    self._level = 1
    self._paused = false
    self._new_best = false
    self._paddle_x = (CLIENT_W - PADDLE_W) * 0.5
    self:_build_level()
    self:_serve()
    self:_event("new")
end

function BreakoutGame:_build_level()
    local layout = LEVELS[(self._level - 1) % #LEVELS + 1]
    local loops = math_floor((self._level - 1) / #LEVELS)
    self._bricks = {}
    self._bricks_left = 0
    for row = 1, #layout do
        local line = layout[row]
        for col = 1, COLS do
            local ch = line:sub(col, col)
            if ch == "#" or ch == "=" then
                local hits = ch == "=" and 2 or 1
                if loops > 0 then hits = hits + 1 end
                local b = {
                    x = FIELD_LEFT + (col - 1) * (BRICK_W + BRICK_GAP),
                    y = BRICK_TOP + (row - 1) * ROW_PITCH,
                    w = BRICK_W, h = BRICK_H,
                    hits = hits, max_hits = hits, row = row, alive = true,
                }
                self._bricks[#self._bricks + 1] = b
                self._bricks_left = self._bricks_left + 1
            end
        end
    end
    self._speed = math_min(BALL_SPEED_MAX, BALL_SPEED + (self._level - 1) * 18)
end

-- The ball waits on the paddle until it is launched.
function BreakoutGame:_serve()
    self._state = "serve"
    self._ball_x = self._paddle_x + PADDLE_W * 0.5
    self._ball_y = PADDLE_Y - BALL_R - 1
    self._vx, self._vy = 0, 0
    self._timer = 0
end

function BreakoutGame:launch()
    if self._state ~= "serve" or self._paused or self._shell:is_modal() then return end
    local angle = (math_random() - 0.5) * 0.7
    self._vx = math_sin(angle) * self._speed
    self._vy = -math_cos(angle) * self._speed
    self._state = "play"
    self:_event("launch", self._ball_x, self._ball_y)
    self:_sound("move")
end

function BreakoutGame:set_paused(paused)
    if self._state == "over" then paused = false end
    self._paused = paused and true or false
end

function BreakoutGame:_command(id)
    if id == "new" then
        self:new_game()
    elseif id == "pause" then
        self:set_paused(not self._paused)
    elseif id == "exit" then
        self._close_requested = true
    elseif id == "how_to" then
        self._shell:open_dialog({ kind = "how_to", title = "How to Play", w = 390, h = 250, buttons_align = "center" })
    elseif id == "about" then
        self._shell:open_dialog({ kind = "about", title = "About Breakout", w = 330, h = 170, buttons_align = "center" })
    end
end

function BreakoutGame:_dialog_button(dialog, id)
    if dialog.kind == "over" then
        if id == "again" then
            self:new_game()
        elseif id == "exit" then
            self._close_requested = true
        end
    end
    return false
end

function BreakoutGame:_game_over()
    self._state = "over"
    if self._score > self._best then
        self._best = self._score
        self._new_best = true
        self:_persist("breakout_highscore", self._score)
    end
    self:_event("over")
    self:_sound("lose")
    self._shell:open_dialog({
        kind = "over", title = "Breakout", w = 290, h = 150,
        buttons = { { id = "again", label = "Play Again", default = true, w = 90 }, { id = "exit", label = "Exit" } },
        cancel_id = "close",
    })
end

-- Physics -------------------------------------------------------------------------------------

function BreakoutGame:update(dt)
    dt = math_min(dt or 0, 0.1)
    self._time = self._time + dt
    if self._paused or self._shell:is_modal() or self._state == "over" then
        self._acc = 0
        return
    end

    self._acc = self._acc + dt
    while self._acc >= STEP do
        self._acc = self._acc - STEP
        self:_step(STEP)
        if self._state == "over" then
            self._acc = 0
            break
        end
    end
end

function BreakoutGame:_move_paddle(dt)
    local target = nil
    local dir = (self._held.right and 1 or 0) - (self._held.left and 1 or 0)
    if dir ~= 0 then
        self._control = "keys"
        local speed = self._held.fast and PADDLE_FAST or PADDLE_SPEED
        self._paddle_x = self._paddle_x + dir * speed * dt
    elseif self._control == "mouse" and self._pointer_seen then
        target = self._pointer_x - self._layout.client.x - PADDLE_W * 0.5
        self._paddle_x = target
    end
    self._paddle_x = clamp(self._paddle_x, 0, CLIENT_W - PADDLE_W)
end

function BreakoutGame:_step(dt)
    self:_move_paddle(dt)

    local state = self._state
    if state == "serve" then
        self._ball_x = self._paddle_x + PADDLE_W * 0.5
        self._ball_y = PADDLE_Y - BALL_R - 1
        return
    elseif state == "lost" or state == "cleared" then
        self._timer = self._timer - dt
        if self._timer <= 0 then
            if state == "cleared" then
                self._level = self._level + 1
                self:_build_level()
                self:_event("level", nil, nil, self._level)
            end
            self:_serve()
        end
        return
    end

    local x = self._ball_x + self._vx * dt
    local y = self._ball_y + self._vy * dt

    if x < BALL_R then
        x = BALL_R
        self._vx = math_abs(self._vx)
        self:_event("wall", x, y)
    elseif x > CLIENT_W - BALL_R then
        x = CLIENT_W - BALL_R
        self._vx = -math_abs(self._vx)
        self:_event("wall", x, y)
    end
    if y < BALL_R then
        y = BALL_R
        self._vy = math_abs(self._vy)
        self:_event("wall", x, y)
    end

    -- Paddle: the bounce angle depends on where the ball meets it, like the original.
    if self._vy > 0 and y + BALL_R >= PADDLE_Y and y - BALL_R <= PADDLE_Y + PADDLE_H
        and x >= self._paddle_x - BALL_R and x <= self._paddle_x + PADDLE_W + BALL_R then
        local hit = clamp((x - (self._paddle_x + PADDLE_W * 0.5)) / (PADDLE_W * 0.5 + BALL_R), -1, 1)
        local angle = hit * MAX_BOUNCE
        local speed = math_sqrt(self._vx * self._vx + self._vy * self._vy)
        self._vx = math_sin(angle) * speed
        self._vy = -math_cos(angle) * speed
        y = PADDLE_Y - BALL_R
        self:_event("paddle", x, y, hit)
        self:_sound("move")
    end

    self._ball_x, self._ball_y = x, y
    self:_collide_bricks()

    if self._ball_y - BALL_R > CLIENT_H then
        self._lives = self._lives - 1
        self:_event("lost", self._ball_x, CLIENT_H, self._lives)
        if self._lives <= 0 then
            self:_game_over()
        else
            self._state = "lost"
            self._timer = LOST_PAUSE
            self:_sound("lose")
        end
    end
end

function BreakoutGame:_collide_bricks()
    local x, y = self._ball_x, self._ball_y
    local bricks = self._bricks
    for i = 1, #bricks do
        local b = bricks[i]
        if b.alive then
            local cx = clamp(x, b.x, b.x + b.w)
            local cy = clamp(y, b.y, b.y + b.h)
            local dx, dy = x - cx, y - cy
            if dx * dx + dy * dy <= BALL_R * BALL_R then
                -- Bounce off the side the ball came through.
                local over_x = math_min(x + BALL_R - b.x, b.x + b.w - (x - BALL_R))
                local over_y = math_min(y + BALL_R - b.y, b.y + b.h - (y - BALL_R))
                if over_x < over_y then
                    if x < b.x + b.w * 0.5 then
                        self._vx = -math_abs(self._vx)
                        self._ball_x = b.x - BALL_R
                    else
                        self._vx = math_abs(self._vx)
                        self._ball_x = b.x + b.w + BALL_R
                    end
                else
                    if y < b.y + b.h * 0.5 then
                        self._vy = -math_abs(self._vy)
                        self._ball_y = b.y - BALL_R
                    else
                        self._vy = math_abs(self._vy)
                        self._ball_y = b.y + b.h + BALL_R
                    end
                end
                self:_hit_brick(b)
                return
            end
        end
    end
end

function BreakoutGame:_hit_brick(b)
    b.hits = b.hits - 1
    if b.hits > 0 then
        self._score = self._score + 5
        self:_event("crack", b.x + b.w * 0.5, b.y + b.h * 0.5, b.hits)
        self:_sound("move")
        return
    end

    b.alive = false
    self._bricks_left = self._bricks_left - 1
    local points = 10 * self._level
    self._score = self._score + points
    self:_event("brick", b.x + b.w * 0.5, b.y + b.h * 0.5, points)

    -- The ball speeds up a little with every brick.
    local speed = math_sqrt(self._vx * self._vx + self._vy * self._vy)
    local faster = math_min(BALL_SPEED_MAX, speed + BALL_SPEED_STEP)
    self._vx = self._vx / speed * faster
    self._vy = self._vy / speed * faster
    -- Avoid endless near-horizontal rallies.
    if math_abs(self._vy) < faster * 0.25 then
        local sign = self._vy < 0 and -1 or 1
        self._vy = sign * faster * 0.25
        self._vx = (self._vx < 0 and -1 or 1) * faster * math_sqrt(1 - 0.0625)
    end

    if self._bricks_left <= 0 then
        self._state = "cleared"
        self._timer = LEVEL_PAUSE
        self._score = self._score + 100 * self._level
        self:_event("cleared", nil, nil, self._level)
        self:_sound("win")
    end
end

-- Input -----------------------------------------------------------------------------------------

local SHELL_KEYS = { left = true, right = true, up = true, down = true, confirm = true, menu = true }

function BreakoutGame:key_press(key, is_repeat)
    if SHELL_KEYS[key] and self._shell:key(key) then return end
    if key == "new" then
        local dialog = self._shell:dialog()
        if dialog and dialog.kind ~= "over" then return end
        self:new_game()
        return
    end
    if self._shell:is_modal() then return end

    if key == "confirm" or key == "up" then
        if is_repeat then return end
        if self._paused then
            self:set_paused(false)
        else
            self:launch()
        end
    elseif key == "alt" or key == "down" then
        if not is_repeat and self._state ~= "over" then self:set_paused(not self._paused) end
    elseif key == "left" or key == "right" then
        self._control = "keys"
    end
end

function BreakoutGame:key_hold(key, held)
    self._held[key] = held and true or false
    if held and (key == "left" or key == "right") then self._control = "keys" end
end

function BreakoutGame:pointer_input(x, y, input)
    local moved = self._pointer_seen and math_abs(x - self._pointer_x) > 0.5
    self._pointer_x, self._pointer_y = x, y
    self._pointer_seen = true

    if self._shell:pointer(x, y, input) then return end

    local client = self._layout.client
    if not Win95.inside(client, x, y) then return end
    if moved then self._control = "mouse" end

    if input.left_pressed then
        self._control = "mouse"
        if self._paused then
            self:set_paused(false)
        else
            self:launch()
        end
    elseif input.right_pressed and self._state ~= "over" then
        self:set_paused(not self._paused)
    end
end

function BreakoutGame:ui_back()
    if self._shell:ui_back() then return true end
    if self._paused then
        self:set_paused(false)
        return true
    end
    return false
end

function BreakoutGame:consume_close_request()
    local requested = self._shell:consume_close_request() or self._close_requested
    self._close_requested = false
    return requested
end

function BreakoutGame:is_game_over() return false end

function BreakoutGame:summary()
    return string.format("[Breakout] Score: %d  Level: %d  Best: %d", self._score, self._level, self._best)
end

-- Queries for the renderer ---------------------------------------------------------------------

function BreakoutGame:shell() return self._shell end
function BreakoutGame:layout() return self._layout end
function BreakoutGame:bricks() return self._bricks end
function BreakoutGame:ball() return self._ball_x, self._ball_y, BALL_R end
function BreakoutGame:ball_velocity() return self._vx, self._vy end
function BreakoutGame:paddle() return self._paddle_x, PADDLE_Y, PADDLE_W, PADDLE_H end
function BreakoutGame:score() return self._score end
function BreakoutGame:lives() return self._lives end
function BreakoutGame:level() return self._level end
function BreakoutGame:best() return self._best end
function BreakoutGame:new_best() return self._new_best end
function BreakoutGame:state() return self._state end
function BreakoutGame:state_timer() return self._timer end
function BreakoutGame:is_paused() return self._paused end
function BreakoutGame:bricks_left() return self._bricks_left end
function BreakoutGame:client_size() return CLIENT_W, CLIENT_H end
function BreakoutGame:time() return self._time end

return BreakoutGame
