local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_random = math.random

local BOARD_W = 10
local BOARD_H = 20

local PIECE_TYPES = { "I", "O", "T", "S", "Z", "J", "L" }

local PIECES = {
    I = {
        { {0,0,0,0}, {1,1,1,1}, {0,0,0,0}, {0,0,0,0} },
        { {0,0,1,0}, {0,0,1,0}, {0,0,1,0}, {0,0,1,0} },
        { {0,0,0,0}, {0,0,0,0}, {1,1,1,1}, {0,0,0,0} },
        { {0,1,0,0}, {0,1,0,0}, {0,1,0,0}, {0,1,0,0} },
    },
    O = {
        { {1,1}, {1,1} }, { {1,1}, {1,1} }, { {1,1}, {1,1} }, { {1,1}, {1,1} },
    },
    T = {
        { {0,1,0}, {1,1,1}, {0,0,0} },
        { {0,1,0}, {0,1,1}, {0,1,0} },
        { {0,0,0}, {1,1,1}, {0,1,0} },
        { {0,1,0}, {1,1,0}, {0,1,0} },
    },
    S = {
        { {0,1,1}, {1,1,0}, {0,0,0} },
        { {0,1,0}, {0,1,1}, {0,0,1} },
        { {0,0,0}, {0,1,1}, {1,1,0} },
        { {1,0,0}, {1,1,0}, {0,1,0} },
    },
    Z = {
        { {1,1,0}, {0,1,1}, {0,0,0} },
        { {0,0,1}, {0,1,1}, {0,1,0} },
        { {0,0,0}, {1,1,0}, {0,1,1} },
        { {0,1,0}, {1,1,0}, {1,0,0} },
    },
    J = {
        { {1,0,0}, {1,1,1}, {0,0,0} },
        { {0,1,1}, {0,1,0}, {0,1,0} },
        { {0,0,0}, {1,1,1}, {0,0,1} },
        { {0,1,0}, {0,1,0}, {1,1,0} },
    },
    L = {
        { {0,0,1}, {1,1,1}, {0,0,0} },
        { {0,1,0}, {0,1,0}, {0,1,1} },
        { {0,0,0}, {1,1,1}, {1,0,0} },
        { {1,1,0}, {0,1,0}, {0,1,0} },
    },
}

local PIECE_COLORS = { I = 1, O = 2, T = 3, S = 4, Z = 5, J = 6, L = 7 }

local INITIAL_FALL_MS = 1000
local MIN_FALL_MS = 70
local LOCK_DELAY_MS = 500
local CLEAR_DELAY_MS = 360
local MAX_LOCK_MOVES = 15
local SCORE_TABLE = { 0, 100, 300, 500, 800 }
local TETRIS_B2B_BONUS = 1.5

local NORMAL_KICKS = {
    { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, -1 }, { 1, -1 }, { -1, -1 }, { 2, 0 }, { -2, 0 },
}

local I_KICKS = {
    { 0, 0 }, { 1, 0 }, { -1, 0 }, { 2, 0 }, { -2, 0 }, { 0, -1 }, { 1, -1 }, { -1, -1 }, { 0, -2 },
}

local TetrisGame = {}
TetrisGame.__index = TetrisGame

function TetrisGame:new()
    local self = setmetatable({
        _board = {},
        _piece_type = nil,
        _piece_rot = 0,
        _piece_col = 0,
        _piece_row = 0,
        _score = 0,
        _lines = 0,
        _level = 0,
        _fall_timer = 0,
        _lock_timer = 0,
        _is_locked = false,
        _game_over = false,
        _active = false,
        _lock_moves = 0,
        _on_land = nil,
        _on_clear = nil,
        _bag = {},
        _next_queue = {},
        _hold_type = nil,
        _hold_used = false,
        _clearing_rows = {},
        _clear_timer = 0,
        _combo = -1,
        _b2b = false,
        _last_clear = 0,
        _time = 0,
        _shake = 0,
        _drop_flash = 0,
    }, TetrisGame)
    self:_reset_board()
    return self
end

function TetrisGame:start()
    self:_reset_board()
    self._score = 0
    self._lines = 0
    self._level = 0
    self._fall_timer = 0
    self._lock_timer = 0
    self._is_locked = false
    self._game_over = false
    self._active = true
    self._lock_moves = 0
    self._bag = {}
    self._next_queue = {}
    self._hold_type = nil
    self._hold_used = false
    self._clearing_rows = {}
    self._clear_timer = 0
    self._combo = -1
    self._b2b = false
    self._last_clear = 0
    self._time = 0
    self._shake = 0
    self._drop_flash = 0
    self:_fill_queue()
    self:_spawn_piece()
end

function TetrisGame:board() return self._board end
function TetrisGame:score() return self._score end
function TetrisGame:lines() return self._lines end
function TetrisGame:level() return self._level end
function TetrisGame:is_game_over() return self._game_over end
function TetrisGame:is_active() return self._active end
function TetrisGame:combo() return math_max(0, self._combo) end
function TetrisGame:is_b2b() return self._b2b end
function TetrisGame:last_clear() return self._last_clear end
function TetrisGame:time() return self._time end
function TetrisGame:shake() return self._shake end
function TetrisGame:drop_flash() return self._drop_flash end
function TetrisGame:clearing_rows() return self._clearing_rows end

function TetrisGame:lock_progress()
    if not self._is_locked then return 0 end
    return math_min(1, self._lock_timer / LOCK_DELAY_MS)
end

function TetrisGame:fall_interval()
    return math_max(MIN_FALL_MS, INITIAL_FALL_MS * 0.82 ^ self._level)
end

function TetrisGame:set_land_callback(fn) self._on_land = fn end
function TetrisGame:set_clear_callback(fn) self._on_clear = fn end

function TetrisGame:falling_piece_cells()
    return self:_piece_cells(self._piece_type, self._piece_rot, self._piece_col, self._piece_row)
end

function TetrisGame:ghost_piece_cells()
    if not self._piece_type or self._game_over then return {} end
    local row = self._piece_row

    while self:_piece_fits(self._piece_type, self._piece_rot, self._piece_col, row + 1) do
        row = row + 1
    end

    return self:_piece_cells(self._piece_type, self._piece_rot, self._piece_col, row)
end

function TetrisGame:next_piece_cells(slot)
    slot = slot or 1
    local piece_type = self._next_queue[slot]
    if not piece_type then return {} end
    return self:_preview_cells(piece_type)
end

function TetrisGame:hold_piece_cells()
    if not self._hold_type then return {} end
    return self:_preview_cells(self._hold_type)
end

function TetrisGame:hold_type() return self._hold_type end
function TetrisGame:can_hold() return not self._hold_used end

function TetrisGame:move(dx, dy)
    if not self:_can_act() then return false end
    local new_col = self._piece_col + dx
    local new_row = self._piece_row + dy

    if self:_piece_fits(self._piece_type, self._piece_rot, new_col, new_row) then
        self._piece_col = new_col
        self._piece_row = new_row
        self:_reset_lock_on_action()
        return true
    end

    return false
end

function TetrisGame:rotate(dir)
    if not self:_can_act() then return false end
    if self._piece_type == "O" then return true end

    local new_rot = (self._piece_rot + dir) % 4
    local kicks = self._piece_type == "I" and I_KICKS or NORMAL_KICKS

    for i = 1, #kicks do
        local kx, ky = kicks[i][1], kicks[i][2]

        if self:_piece_fits(self._piece_type, new_rot, self._piece_col + kx, self._piece_row + ky) then
            self._piece_col = self._piece_col + kx
            self._piece_row = self._piece_row + ky
            self._piece_rot = new_rot
            self:_reset_lock_on_action()
            return true
        end
    end

    return false
end

function TetrisGame:hold()
    if not self:_can_act() or self._hold_used then return false end

    local held = self._hold_type
    self._hold_type = self._piece_type
    self._hold_used = true

    if held then
        self:_spawn_specific_piece(held)
    else
        self:_spawn_piece()
    end

    self._drop_flash = 0.12
    return true
end

function TetrisGame:hard_drop()
    if not self:_can_act() then return false end
    local drop = 0

    while self:_piece_fits(self._piece_type, self._piece_rot, self._piece_col, self._piece_row + 1) do
        self._piece_row = self._piece_row + 1
        drop = drop + 1
    end

    self._score = self._score + drop * 2
    self._shake = math_min(1, self._shake + math_min(0.45, drop * 0.035))
    self._drop_flash = 0.18
    if self._on_land then self._on_land() end
    self:_lock_piece()
    return true
end

function TetrisGame:soft_drop()
    if self:move(0, 1) then
        self._score = self._score + 1
        return true
    end

    return false
end

function TetrisGame:update(dt)
    if not self._active or self._game_over then return end

    self._time = self._time + dt
    self._shake = math_max(0, self._shake - dt * 7)
    self._drop_flash = math_max(0, self._drop_flash - dt)

    if self._clear_timer > 0 then
        self._clear_timer = self._clear_timer - dt * 1000

        if self._clear_timer <= 0 then
            self:_finish_clear_lines()
            self:_spawn_piece()
        end

        return
    end

    self._fall_timer = self._fall_timer + dt * 1000
    local interval = self:fall_interval()

    while self._fall_timer >= interval do
        self._fall_timer = self._fall_timer - interval

        if self:_piece_fits(self._piece_type, self._piece_rot, self._piece_col, self._piece_row + 1) then
            self._piece_row = self._piece_row + 1
            self._is_locked = false
            self._lock_timer = 0
        elseif not self._is_locked then
            self._is_locked = true
            self._lock_timer = 0
            self._lock_moves = 0
            if self._on_land then self._on_land() end
        end
    end

    if self._is_locked then
        self._lock_timer = self._lock_timer + dt * 1000

        if self._lock_timer >= LOCK_DELAY_MS then
            self:_lock_piece()
        end
    end
end

function TetrisGame:_can_act()
    return self._active and not self._game_over and self._clear_timer <= 0 and self._piece_type ~= nil
end

function TetrisGame:_reset_board()
    for i = 1, BOARD_W * BOARD_H do
        self._board[i] = 0
    end
end

function TetrisGame:_fill_queue()
    while #self._next_queue < 5 do
        if #self._bag == 0 then
            self:_refill_bag()
        end

        self._next_queue[#self._next_queue + 1] = table.remove(self._bag)
    end
end

function TetrisGame:_refill_bag()
    for i = 1, #PIECE_TYPES do
        self._bag[i] = PIECE_TYPES[i]
    end

    for i = #self._bag, 2, -1 do
        local j = math_random(i)
        self._bag[i], self._bag[j] = self._bag[j], self._bag[i]
    end
end

function TetrisGame:_spawn_piece()
    self:_fill_queue()
    local piece_type = table.remove(self._next_queue, 1)
    self:_fill_queue()
    self:_spawn_specific_piece(piece_type)
end

function TetrisGame:_spawn_specific_piece(piece_type)
    self._piece_type = piece_type
    self._piece_rot = 0
    self._piece_col = piece_type == "O" and 4 or 3
    self._piece_row = -1
    self._is_locked = false
    self._lock_timer = 0
    self._lock_moves = 0
    self._fall_timer = 0

    if not self:_piece_fits(self._piece_type, 0, self._piece_col, self._piece_row) then
        self._game_over = true
        self._active = false
    end
end

function TetrisGame:_reset_lock_on_action()
    if not self._is_locked then return end

    self._lock_timer = 0
    self._lock_moves = self._lock_moves + 1

    if self._lock_moves > MAX_LOCK_MOVES then
        self:_lock_piece()
    end
end

function TetrisGame:_lock_piece()
    if not self._piece_type then return end

    local grid = PIECES[self._piece_type][self._piece_rot + 1]

    for r = 1, #grid do
        for c = 1, #grid[r] do
            if grid[r][c] == 1 then
                local col = self._piece_col + c - 1
                local row = self._piece_row + r - 1

                if row >= 0 and row < BOARD_H and col >= 0 and col < BOARD_W then
                    self._board[row * BOARD_W + col + 1] = PIECE_COLORS[self._piece_type]
                end
            end
        end
    end

    self._piece_type = nil
    self._hold_used = false
    self:_start_clear_lines()

    if #self._clearing_rows == 0 then
        self._combo = -1
        self:_spawn_piece()
    else
        self._clear_timer = CLEAR_DELAY_MS
        if self._on_clear then self._on_clear() end
    end
end

function TetrisGame:_start_clear_lines()
    self._clearing_rows = {}

    for row = BOARD_H - 1, 0, -1 do
        local full = true

        for col = 0, BOARD_W - 1 do
            if self._board[row * BOARD_W + col + 1] == 0 then
                full = false
                break
            end
        end

        if full then
            self._clearing_rows[#self._clearing_rows + 1] = row
        end
    end
end

function TetrisGame:_finish_clear_lines()
    local cleared = #self._clearing_rows
    if cleared <= 0 then return end

    local clear_lookup = {}
    for i = 1, cleared do
        clear_lookup[self._clearing_rows[i]] = true
    end

    local write_row = BOARD_H - 1
    for read_row = BOARD_H - 1, 0, -1 do
        if not clear_lookup[read_row] then
            if write_row ~= read_row then
                for col = 0, BOARD_W - 1 do
                    self._board[write_row * BOARD_W + col + 1] = self._board[read_row * BOARD_W + col + 1]
                end
            end

            write_row = write_row - 1
        end
    end

    for row = write_row, 0, -1 do
        for col = 0, BOARD_W - 1 do
            self._board[row * BOARD_W + col + 1] = 0
        end
    end

    self._combo = self._combo + 1
    self._last_clear = cleared

    local points = SCORE_TABLE[cleared] * (self._level + 1)
    if cleared == 4 and self._b2b then
        points = math_floor(points * TETRIS_B2B_BONUS)
    end

    if self._combo > 0 then
        points = points + self._combo * 50 * (self._level + 1)
    end

    self._score = self._score + points
    self._lines = self._lines + cleared
    self._level = math_floor(self._lines / 10)
    self._b2b = cleared == 4 and true or cleared > 0 and false
    self._shake = math_min(1, self._shake + 0.2 + cleared * 0.18)
    self._drop_flash = 0.22
    self._clearing_rows = {}
end

function TetrisGame:_piece_cells(piece_type, rot, pcol, prow)
    if not piece_type then return {} end

    local cells = {}
    local color = PIECE_COLORS[piece_type]
    local grid = PIECES[piece_type][rot + 1]

    for r = 1, #grid do
        for c = 1, #grid[r] do
            if grid[r][c] == 1 then
                cells[#cells + 1] = {
                    col = pcol + c - 1,
                    row = prow + r - 1,
                    color = color,
                    type = piece_type,
                }
            end
        end
    end

    return cells
end

function TetrisGame:_preview_cells(piece_type)
    local cells = {}
    local color = PIECE_COLORS[piece_type]
    local grid = PIECES[piece_type][1]

    for r = 1, #grid do
        for c = 1, #grid[r] do
            if grid[r][c] == 1 then
                cells[#cells + 1] = {
                    col = c - 1,
                    row = r - 1,
                    color = color,
                    type = piece_type,
                }
            end
        end
    end

    return cells
end

function TetrisGame:_piece_fits(piece_type, rot, pcol, prow)
    local grid = PIECES[piece_type][rot + 1]

    for r = 1, #grid do
        for c = 1, #grid[r] do
            if grid[r][c] == 1 then
                local col = pcol + c - 1
                local row = prow + r - 1

                if col < 0 or col >= BOARD_W then return false end
                if row >= BOARD_H then return false end
                if row >= 0 and self._board[row * BOARD_W + col + 1] ~= 0 then return false end
            end
        end
    end

    return true
end

return TetrisGame
