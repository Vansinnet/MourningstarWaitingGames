-- Minesweeper with Windows 95 rules and application behaviour.
-- Pure logic: layout, hit testing, menus and dialogs live here so the view only renders.
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_random = math.random

local LEVELS = {
    beginner = { cols = 9, rows = 9, mines = 10 },
    intermediate = { cols = 16, rows = 16, mines = 40 },
    expert = { cols = 30, rows = 16, mines = 99 },
}
local LEVEL_ORDER = { "beginner", "intermediate", "expert" }
local LEVEL_NAMES = { beginner = "Beginner", intermediate = "Intermediate", expert = "Expert", custom = "Custom" }

-- Windows 95 Custom Field limits.
local MIN_ROWS, MAX_ROWS = 9, 24
local MIN_COLS, MAX_COLS = 9, 30
local MIN_MINES = 10
local MAX_TIME = 999

local COVERED, REVEALED, FLAGGED, QUESTION = 0, 1, 2, 3

local CANVAS = 600
local FRAME = 4
local TITLE_H = 22
local MENU_H = 20
local PAD = 9
local HEADER_H = 46
local SUNKEN = 3
local MIN_CLIENT_W = 214

local GAME_MENU = {
    { id = "new", label = "New", key = "R" },
    { separator = true },
    { id = "beginner", label = "Beginner", key = "1", check = "level" },
    { id = "intermediate", label = "Intermediate", key = "2", check = "level" },
    { id = "expert", label = "Expert", key = "3", check = "level" },
    { id = "custom", label = "Custom...", check = "level" },
    { separator = true },
    { id = "marks", label = "Marks (?)", key = "4", check = "marks" },
    { separator = true },
    { id = "best", label = "Best Times..." },
    { separator = true },
    { id = "exit", label = "Exit", key = "Esc" },
}
local HELP_MENU = {
    { id = "how_to", label = "How to Play..." },
    { separator = true },
    { id = "about", label = "About Minesweeper..." },
}
local MENU_ITEM_H = 20
local MENU_SEP_H = 8
local MENU_W = 196

local MinesweeperGame = {}
MinesweeperGame.__index = MinesweeperGame

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function inside(rect, x, y)
    return rect and x >= rect.x and y >= rect.y and x < rect.x + rect.w and y < rect.y + rect.h
end

local function rect(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

local function max_mines(rows, cols)
    return (rows - 1) * (cols - 1)
end

-- options: get(key), set(key, value), on_sound(kind), on_close()
function MinesweeperGame:new(options)
    local game = setmetatable({}, MinesweeperGame)
    game._options = options or {}
    game._time = 0
    game._events = {}
    game._event_count = 0

    local get = game._options.get
    local level = get and get("minesweeper_level") or "beginner"
    if level ~= "custom" and not LEVELS[level] then level = "beginner" end
    local marks = get and get("minesweeper_marks")
    game._marks = marks == nil and true or marks == true
    game._custom = {
        rows = clamp(tonumber(get and get("minesweeper_custom_rows")) or 20, MIN_ROWS, MAX_ROWS),
        cols = clamp(tonumber(get and get("minesweeper_custom_cols")) or 30, MIN_COLS, MAX_COLS),
        mines = tonumber(get and get("minesweeper_custom_mines")) or 145,
    }
    game._custom.mines = clamp(game._custom.mines, MIN_MINES, max_mines(game._custom.rows, game._custom.cols))
    game._level = level

    game._pointer_x = -1
    game._pointer_y = -1
    game._cursor_mode = "pointer"
    game._menu = nil
    game._menu_hover = nil
    game._dialog = nil
    game._ui_press = nil
    game._mode = nil
    game._held = { left = false, right = false, middle = false }
    game._close_requested = false

    game:_apply_level()
    return game
end

function MinesweeperGame:start()
    self:_new_board()
end

-- Settings ------------------------------------------------------------------

function MinesweeperGame:_persist(key, value)
    local set = self._options.set
    if set then set(key, value) end
end

function MinesweeperGame:_sound(kind)
    local on_sound = self._options.on_sound
    if on_sound then on_sound(kind) end
end

function MinesweeperGame:_apply_level()
    local config = self._level == "custom" and self._custom or LEVELS[self._level]
    self._rows = config.rows
    self._cols = config.cols
    self._mine_total = config.mines
    self:_build_layout()
end

function MinesweeperGame:set_level(level)
    if level ~= "custom" and not LEVELS[level] then return end
    self._level = level
    self:_persist("minesweeper_level", level)
    self:_apply_level()
    self:_new_board()
end

function MinesweeperGame:set_custom(rows, cols, mines)
    rows = clamp(math_floor(rows), MIN_ROWS, MAX_ROWS)
    cols = clamp(math_floor(cols), MIN_COLS, MAX_COLS)
    mines = clamp(math_floor(mines), MIN_MINES, max_mines(rows, cols))
    self._custom.rows, self._custom.cols, self._custom.mines = rows, cols, mines
    self:_persist("minesweeper_custom_rows", rows)
    self:_persist("minesweeper_custom_cols", cols)
    self:_persist("minesweeper_custom_mines", mines)
    self:set_level("custom")
end

function MinesweeperGame:toggle_marks()
    self._marks = not self._marks
    self:_persist("minesweeper_marks", self._marks)

    if not self._marks then
        -- Windows clears existing question marks when marks are disabled.
        for i = 1, self._rows * self._cols do
            if self._state[i] == QUESTION then self._state[i] = COVERED end
        end
    end
end

function MinesweeperGame:best_time(level)
    local get = self._options.get
    local value = get and tonumber(get("minesweeper_best_" .. level))
    if value and value > 0 then return value end
    return nil
end

function MinesweeperGame:reset_best_times()
    for i = 1, #LEVEL_ORDER do
        self:_persist("minesweeper_best_" .. LEVEL_ORDER[i], 0)
    end
end

-- Board ---------------------------------------------------------------------

function MinesweeperGame:_index(col, row)
    return row * self._cols + col + 1
end

function MinesweeperGame:_coords(index)
    local i = index - 1
    return i % self._cols, math_floor(i / self._cols)
end

function MinesweeperGame:_new_board()
    local count = self._rows * self._cols
    self._mine = {}
    self._state = {}
    self._adjacent = {}
    self._reveal_depth = {}

    for i = 1, count do
        self._mine[i] = false
        self._state[i] = COVERED
        self._adjacent[i] = 0
        self._reveal_depth[i] = 0
    end

    -- Windows places the mines when the game starts and relocates one on a first-click hit.
    local placed = 0
    while placed < self._mine_total do
        local i = math_random(1, count)
        if not self._mine[i] then
            self._mine[i] = true
            placed = placed + 1
        end
    end

    self:_count_adjacent()
    self._status = "ready"
    self._elapsed = 0
    self._flags = 0
    self._revealed = 0
    self._exploded = nil
    self._first_click = true
    self._mode = nil
    self._menu = nil
    self._cursor_col = math_floor(self._cols / 2)
    self._cursor_row = math_floor(self._rows / 2)
    self:_event("new")
end

function MinesweeperGame:_count_adjacent()
    local cols, rows = self._cols, self._rows

    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local n = 0
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local c, r = col + dx, row + dy
                    if (dx ~= 0 or dy ~= 0) and c >= 0 and r >= 0 and c < cols and r < rows and self._mine[r * cols + c + 1] then
                        n = n + 1
                    end
                end
            end
            self._adjacent[row * cols + col + 1] = n
        end
    end
end

function MinesweeperGame:_event(kind, index, value)
    local n = self._event_count + 1
    local e = self._events[n]
    if not e then
        e = {}
        self._events[n] = e
    end
    e.kind, e.index, e.value = kind, index, value
    self._event_count = n
end

function MinesweeperGame:drain_events(callback)
    for i = 1, self._event_count do
        local e = self._events[i]
        callback(e.kind, e.index, e.value)
    end
    self._event_count = 0
end

function MinesweeperGame:_begin_if_needed(index)
    if not self._first_click then return end
    self._first_click = false

    if self._mine[index] then
        -- Windows moves the mine to the first free square, scanning from the top-left corner.
        for i = 1, self._rows * self._cols do
            if not self._mine[i] and i ~= index then
                self._mine[i] = true
                break
            end
        end
        self._mine[index] = false
        self:_count_adjacent()
    end

    self._status = "playing"
    self._elapsed = 0
end

function MinesweeperGame:_finished()
    return self._status == "won" or self._status == "lost"
end

function MinesweeperGame:reveal(col, row)
    if self:_finished() then return end
    if col < 0 or row < 0 or col >= self._cols or row >= self._rows then return end

    local index = self:_index(col, row)
    local state = self._state[index]
    if state == REVEALED or state == FLAGGED then return end

    self:_begin_if_needed(index)

    if self._mine[index] then
        self:_lose(index)
        return
    end

    self:_flood(index)
    self:_sound("reveal")
    self:_check_win()
end

function MinesweeperGame:_flood(start)
    local cols, rows = self._cols, self._rows
    local queue = { start }
    local depth = { [start] = 0 }
    local head = 1

    while queue[head] do
        local index = queue[head]
        head = head + 1

        local state = self._state[index]
        if state ~= REVEALED and state ~= FLAGGED and not self._mine[index] then
            self._state[index] = REVEALED
            self._revealed = self._revealed + 1
            self._reveal_depth[index] = depth[index]
            self:_event("reveal", index, depth[index])

            if self._adjacent[index] == 0 then
                local col, row = self:_coords(index)
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        local c, r = col + dx, row + dy
                        if (dx ~= 0 or dy ~= 0) and c >= 0 and r >= 0 and c < cols and r < rows then
                            local n = r * cols + c + 1
                            if depth[n] == nil and self._state[n] ~= REVEALED and self._state[n] ~= FLAGGED then
                                depth[n] = depth[index] + 1
                                queue[#queue + 1] = n
                            end
                        end
                    end
                end
            end
        end
    end
end

function MinesweeperGame:toggle_mark(col, row)
    if self:_finished() then return end
    if col < 0 or row < 0 or col >= self._cols or row >= self._rows then return end

    local index = self:_index(col, row)
    local state = self._state[index]

    if state == COVERED then
        self._state[index] = FLAGGED
        self._flags = self._flags + 1
        self:_event("flag", index, true)
    elseif state == FLAGGED then
        self._flags = self._flags - 1
        if self._marks then
            self._state[index] = QUESTION
            self:_event("question", index, true)
        else
            self._state[index] = COVERED
        end
        self:_event("flag", index, false)
    elseif state == QUESTION then
        self._state[index] = COVERED
    end
end

-- Revealing all neighbours of a satisfied number ("chording").
function MinesweeperGame:chord(col, row)
    if self:_finished() then return end
    if col < 0 or row < 0 or col >= self._cols or row >= self._rows then return end

    local index = self:_index(col, row)
    if self._state[index] ~= REVEALED or self._adjacent[index] == 0 then return end

    local flags = 0
    for dy = -1, 1 do
        for dx = -1, 1 do
            local c, r = col + dx, row + dy
            if c >= 0 and r >= 0 and c < self._cols and r < self._rows and self._state[self:_index(c, r)] == FLAGGED then
                flags = flags + 1
            end
        end
    end

    if flags ~= self._adjacent[index] then return end

    local hit = nil
    for dy = -1, 1 do
        for dx = -1, 1 do
            local c, r = col + dx, row + dy
            if c >= 0 and r >= 0 and c < self._cols and r < self._rows then
                local n = self:_index(c, r)
                local state = self._state[n]
                if state == COVERED or state == QUESTION then
                    if self._mine[n] then
                        hit = hit or n
                    else
                        self:_flood(n)
                    end
                end
            end
        end
    end

    if hit then
        self:_lose(hit)
        return
    end

    self:_sound("reveal")
    self:_check_win()
end

function MinesweeperGame:_lose(index)
    self._status = "lost"
    self._exploded = index
    self:_event("explode", index)

    local ex, ey = self:_coords(index)
    for i = 1, self._rows * self._cols do
        if self._mine[i] and i ~= index and self._state[i] ~= FLAGGED then
            local c, r = self:_coords(i)
            local d = math_max(math.abs(c - ex), math.abs(r - ey))
            self:_event("mine", i, d)
        end
    end

    self._mode = nil
    self:_sound("lose")
end

function MinesweeperGame:_check_win()
    if self._revealed < self._rows * self._cols - self._mine_total then return end

    self._status = "won"
    self._mode = nil

    -- Windows flags every remaining mine on a win.
    for i = 1, self._rows * self._cols do
        if self._mine[i] and self._state[i] ~= FLAGGED then
            self._state[i] = FLAGGED
            self:_event("flag", i, true)
        end
    end
    self._flags = self._mine_total

    local seconds = self:timer_value()
    self:_event("win", nil, seconds)
    self:_sound("win")

    if self._level ~= "custom" then
        local best = self:best_time(self._level)
        if not best or seconds < best then
            self:_persist("minesweeper_best_" .. self._level, seconds)
            self._record_level = self._level
            self._dialog = { kind = "record", focus = 1 }
            self:_refresh_layout()
            self:_event("record", nil, seconds)
        end
    end
end

-- Timer ---------------------------------------------------------------------

function MinesweeperGame:update(dt)
    dt = dt or 0
    self._time = self._time + dt

    if self._status == "playing" then
        self._elapsed = self._elapsed + dt
    end
end

function MinesweeperGame:timer_value()
    if self._status == "ready" then return 0 end
    -- The Windows counter shows 1 as soon as the first square is opened.
    return math_min(MAX_TIME, math_floor(self._elapsed) + 1)
end

-- Layout --------------------------------------------------------------------

function MinesweeperGame:_build_layout()
    local rows, cols = self._rows, self._cols
    local cell = math_floor(math_min(520 / cols, 360 / rows))
    cell = clamp(cell, 12, 32)

    local board_w = cols * cell
    local board_h = rows * cell
    local client_w = math_max(MIN_CLIENT_W, board_w + 2 * (PAD + SUNKEN))
    local client_h = PAD + HEADER_H + PAD + board_h + 2 * SUNKEN + PAD
    local window_w = client_w + 2 * FRAME
    local window_h = FRAME + TITLE_H + MENU_H + client_h + FRAME
    local wx = math_floor((CANVAS - window_w) * 0.5)
    local wy = math_floor((CANVAS - 44 - window_h) * 0.5) + 12

    local L = {}
    L.cell = cell
    L.window = rect(wx, wy, window_w, window_h)
    L.title = rect(wx + FRAME, wy + FRAME, window_w - FRAME * 2, TITLE_H)
    L.close_button = rect(L.title.x + L.title.w - 20, L.title.y + 3, 17, 15)
    L.minimize_button = rect(L.close_button.x - 36, L.title.y + 3, 17, 15)
    L.maximize_button = rect(L.close_button.x - 19, L.title.y + 3, 17, 15)
    L.menubar = rect(wx + FRAME, L.title.y + TITLE_H, window_w - FRAME * 2, MENU_H)
    L.menu_game = rect(L.menubar.x + 2, L.menubar.y + 1, 44, MENU_H - 2)
    L.menu_help = rect(L.menu_game.x + L.menu_game.w, L.menubar.y + 1, 38, MENU_H - 2)
    L.client = rect(wx + FRAME, L.menubar.y + MENU_H, client_w, client_h)
    L.header = rect(L.client.x + PAD, L.client.y + PAD, client_w - PAD * 2, HEADER_H)
    L.mine_counter = rect(L.header.x + 8, L.header.y + 8, 49, 30)
    L.timer = rect(L.header.x + L.header.w - 8 - 49, L.header.y + 8, 49, 30)
    L.face = rect(math_floor(L.header.x + L.header.w * 0.5 - 17), L.header.y + 6, 34, 34)
    L.board_frame = rect(math_floor(L.client.x + (client_w - board_w) * 0.5) - SUNKEN, L.header.y + HEADER_H + PAD, board_w + SUNKEN * 2, board_h + SUNKEN * 2)
    L.board = rect(L.board_frame.x + SUNKEN, L.board_frame.y + SUNKEN, board_w, board_h)

    self._layout = L
    self:_layout_menu()
    self:_layout_dialog()
end

function MinesweeperGame:_layout_menu()
    local L = self._layout
    local menu = self._menu
    L.menu_items = nil

    if not menu then return end

    local items = menu == "game" and GAME_MENU or HELP_MENU
    local anchor = menu == "game" and L.menu_game or L.menu_help
    local height = 4

    for i = 1, #items do
        height = height + (items[i].separator and MENU_SEP_H or MENU_ITEM_H)
    end

    local box = rect(anchor.x, anchor.y + anchor.h, MENU_W, height)
    local list = { box = box }
    local y = box.y + 2

    for i = 1, #items do
        local item = items[i]
        local h = item.separator and MENU_SEP_H or MENU_ITEM_H
        list[i] = { item = item, rect = rect(box.x + 2, y, box.w - 4, h) }
        y = y + h
    end

    L.menu_items = list
end

function MinesweeperGame:_layout_dialog()
    local L = self._layout
    local dialog = self._dialog
    L.dialog = nil

    if not dialog then return end

    local w, h = 280, 150
    if dialog.kind == "custom" then w, h = 250, 170
    elseif dialog.kind == "best" then w, h = 300, 176
    elseif dialog.kind == "how_to" then w, h = 360, 262
    elseif dialog.kind == "about" then w, h = 320, 168
    end

    local x = math_floor((CANVAS - w) * 0.5)
    local y = math_floor(L.window.y + (L.window.h - h) * 0.5)
    local D = { kind = dialog.kind, box = rect(x, y, w, h) }
    D.title = rect(x + 3, y + 3, w - 6, 20)
    D.close_button = rect(D.title.x + D.title.w - 19, D.title.y + 3, 16, 14)
    D.buttons = {}

    local function button(id, label, bx, by, bw)
        D.buttons[#D.buttons + 1] = { id = id, label = label, rect = rect(bx, by, bw or 76, 24) }
    end

    if dialog.kind == "custom" then
        D.fields = {}
        local labels = { "Height:", "Width:", "Mines:" }
        for i = 1, 3 do
            local fy = y + 36 + (i - 1) * 34
            D.fields[i] = {
                label = labels[i],
                label_rect = rect(x + 16, fy, 64, 24),
                box = rect(x + 80, fy, 58, 24),
                up = rect(x + 138, fy, 18, 12),
                down = rect(x + 138, fy + 12, 18, 12),
            }
        end
        button("ok", "OK", x + w - 92, y + 40)
        button("cancel", "Cancel", x + w - 92, y + 76)
    elseif dialog.kind == "best" then
        button("reset", "Reset Scores", x + 24, y + h - 36, 110)
        button("ok", "OK", x + w - 100, y + h - 36)
    else
        button("ok", "OK", math_floor(x + (w - 76) * 0.5), y + h - 36)
    end

    L.dialog = D
end

function MinesweeperGame:_refresh_layout()
    self:_layout_menu()
    self:_layout_dialog()
end

-- Commands ------------------------------------------------------------------

function MinesweeperGame:_command(id)
    self._menu = nil

    if id == "new" then
        self:_new_board()
    elseif id == "beginner" or id == "intermediate" or id == "expert" then
        self:set_level(id)
    elseif id == "custom" then
        self._dialog = {
            kind = "custom",
            focus = 1,
            values = { self._custom.rows, self._custom.cols, self._custom.mines },
        }
    elseif id == "marks" then
        self:toggle_marks()
    elseif id == "best" then
        self._dialog = { kind = "best", focus = 2 }
    elseif id == "how_to" then
        self._dialog = { kind = "how_to", focus = 1 }
    elseif id == "about" then
        self._dialog = { kind = "about", focus = 1 }
    elseif id == "exit" then
        self._close_requested = true
    end

    self:_refresh_layout()
end

function MinesweeperGame:_dialog_button(id)
    local dialog = self._dialog
    if not dialog then return end

    if dialog.kind == "custom" then
        if id == "ok" then
            local v = dialog.values
            self._dialog = nil
            self:set_custom(v[1], v[2], v[3])
        else
            self._dialog = nil
        end
    elseif dialog.kind == "best" then
        if id == "reset" then
            self:reset_best_times()
            return
        end
        self._dialog = nil
    elseif dialog.kind == "record" then
        self._dialog = { kind = "best", focus = 2 }
    else
        self._dialog = nil
    end

    self:_refresh_layout()
end

function MinesweeperGame:_adjust_field(field, delta)
    local dialog = self._dialog
    if not dialog or dialog.kind ~= "custom" then return end

    local v = dialog.values
    if field == 1 then
        v[1] = clamp(v[1] + delta, MIN_ROWS, MAX_ROWS)
    elseif field == 2 then
        v[2] = clamp(v[2] + delta, MIN_COLS, MAX_COLS)
    else
        v[3] = clamp(v[3] + delta, MIN_MINES, max_mines(v[1], v[2]))
    end
    v[3] = clamp(v[3], MIN_MINES, max_mines(v[1], v[2]))
end

function MinesweeperGame:consume_close_request()
    local requested = self._close_requested
    self._close_requested = false
    return requested
end

-- Returns true when Esc closed a menu or dialog instead of the game.
function MinesweeperGame:ui_back()
    if self._dialog then
        if self._dialog.kind == "record" then
            self:_dialog_button("ok")
        else
            self._dialog = nil
            self:_refresh_layout()
        end
        return true
    end

    if self._menu then
        self._menu = nil
        self:_refresh_layout()
        return true
    end

    return false
end

function MinesweeperGame:toggle_menu()
    if self._dialog then return end
    self._menu = self._menu == nil and "game" or nil
    self._menu_hover = self._menu and 1 or nil
    self:_refresh_layout()
end

-- Keyboard and controller -----------------------------------------------------

function MinesweeperGame:_menu_step(direction)
    local list = self._layout.menu_items
    if not list then return end

    local i = self._menu_hover or 0
    for _ = 1, #list do
        i = i + direction
        if i < 1 then i = #list end
        if i > #list then i = 1 end
        if not list[i].item.separator then break end
    end
    self._menu_hover = i
end

function MinesweeperGame:move_cursor(dx, dy)
    if self._dialog then
        local dialog = self._dialog
        if dialog.kind == "custom" then
            if dy ~= 0 then
                dialog.focus = clamp(dialog.focus + dy, 1, 5)
            elseif dx ~= 0 and dialog.focus <= 3 then
                self:_adjust_field(dialog.focus, dx)
            elseif dx ~= 0 then
                dialog.focus = dialog.focus == 4 and 5 or 4
            end
        elseif dialog.kind == "best" and dx ~= 0 then
            dialog.focus = dialog.focus == 1 and 2 or 1
        end
        return
    end

    if self._menu then
        if dy ~= 0 then
            self:_menu_step(dy)
        elseif dx ~= 0 then
            self._menu = self._menu == "game" and "help" or "game"
            self:_refresh_layout()
            self._menu_hover = 1
        end
        return
    end

    self._cursor_mode = "keys"
    self._cursor_col = (self._cursor_col + dx) % self._cols
    self._cursor_row = (self._cursor_row + dy) % self._rows
end

function MinesweeperGame:key_reveal()
    if self._dialog then
        local dialog = self._dialog
        local id
        if dialog.kind == "custom" then
            id = dialog.focus == 5 and "cancel" or "ok"
        elseif dialog.kind == "best" then
            id = dialog.focus == 1 and "reset" or "ok"
        else
            id = "ok"
        end
        self:_dialog_button(id)
        return
    end

    if self._menu then
        local list = self._layout.menu_items
        local entry = list and self._menu_hover and list[self._menu_hover]
        if entry and not entry.item.separator then
            self:_command(entry.item.id)
        end
        return
    end

    self._cursor_mode = "keys"
    local col, row = self._cursor_col, self._cursor_row
    local index = self:_index(col, row)

    if self._state[index] == REVEALED then
        self:chord(col, row)
    else
        self:reveal(col, row)
    end
end

function MinesweeperGame:key_flag()
    if self._dialog or self._menu then return end
    self._cursor_mode = "keys"
    self:toggle_mark(self._cursor_col, self._cursor_row)
end

function MinesweeperGame:key_new()
    if self._dialog then return end
    self._menu = nil
    self:_new_board()
    self:_refresh_layout()
end

function MinesweeperGame:key_level(level)
    if self._dialog then return end
    self._menu = nil
    self:set_level(level)
end

function MinesweeperGame:key_marks()
    if self._dialog then return end
    self:toggle_marks()
end

-- Pointer -------------------------------------------------------------------

function MinesweeperGame:cell_at(x, y)
    local board = self._layout.board
    if not inside(board, x, y) then return nil end

    local cell = self._layout.cell
    local col = math_floor((x - board.x) / cell)
    local row = math_floor((y - board.y) / cell)

    if col < 0 or row < 0 or col >= self._cols or row >= self._rows then return nil end
    return col, row
end

function MinesweeperGame:_hover_target(x, y)
    local L = self._layout

    if L.dialog then
        local D = L.dialog
        for i = 1, #D.buttons do
            if inside(D.buttons[i].rect, x, y) then return "dialog_button", i end
        end
        if D.fields then
            for i = 1, #D.fields do
                local f = D.fields[i]
                if inside(f.up, x, y) then return "field_up", i end
                if inside(f.down, x, y) then return "field_down", i end
                if inside(f.box, x, y) then return "field", i end
            end
        end
        if inside(D.close_button, x, y) then return "dialog_close" end
        return "modal"
    end

    if L.menu_items then
        if inside(L.menu_items.box, x, y) then
            for i = 1, #L.menu_items do
                if inside(L.menu_items[i].rect, x, y) then return "menu_item", i end
            end
            return "menu_box"
        end
    end

    if inside(L.menu_game, x, y) then return "menu_game" end
    if inside(L.menu_help, x, y) then return "menu_help" end
    if inside(L.close_button, x, y) then return "close" end
    if inside(L.face, x, y) then return "face" end

    local col, row = self:cell_at(x, y)
    if col then return "cell", col, row end

    return "none"
end

-- input: { left, right, middle, left_pressed, right_pressed, middle_pressed, left_released, right_released, middle_released }
function MinesweeperGame:pointer_input(x, y, input)
    if math.abs(x - self._pointer_x) + math.abs(y - self._pointer_y) > 0.5 then
        self._cursor_mode = "pointer"
    end
    self._pointer_x, self._pointer_y = x, y

    local held = self._held
    local lp = input.left_pressed or (input.left and not held.left)
    local rp = input.right_pressed or (input.right and not held.right)
    local mp = input.middle_pressed or (input.middle and not held.middle)
    local lr = input.left_released or (not input.left and held.left)
    local rr = input.right_released or (not input.right and held.right)
    local mr = input.middle_released or (not input.middle and held.middle)
    held.left, held.right, held.middle = input.left and true or false, input.right and true or false, input.middle and true or false

    if lp or rp or mp then self._cursor_mode = "pointer" end

    local kind, a, b = self:_hover_target(x, y)
    self._hover_kind, self._hover_a, self._hover_b = kind, a, b

    if self._menu and kind == "menu_item" then
        self._menu_hover = a
    elseif self._menu and kind ~= "menu_box" then
        self._menu_hover = nil
    end

    -- Menus and dialogs -----------------------------------------------------
    if self._dialog then
        if lp then
            self._ui_press = kind == "dialog_button" and ("button" .. a) or kind == "dialog_close" and "dialog_close" or nil
            if kind == "field_up" then self:_adjust_field(a, 1) end
            if kind == "field_down" then self:_adjust_field(a, -1) end
            if kind == "field" then self._dialog.focus = a end
        end
        if lr then
            if self._ui_press and kind == "dialog_button" and self._ui_press == "button" .. a then
                self:_dialog_button(self._layout.dialog.buttons[a].id)
            elseif self._ui_press == "dialog_close" and kind == "dialog_close" then
                self:ui_back()
            end
            self._ui_press = nil
        end
        return
    end

    if self._menu then
        if lp or rp then
            if kind == "menu_game" or kind == "menu_help" then
                local wanted = kind == "menu_game" and "game" or "help"
                self._menu = self._menu == wanted and nil or wanted
                self:_refresh_layout()
            elseif kind ~= "menu_item" and kind ~= "menu_box" then
                self._menu = nil
                self:_refresh_layout()
                self._mode = "suppressed"
            end
        elseif lr and kind == "menu_item" then
            local entry = self._layout.menu_items[a]
            if entry and not entry.item.separator then
                self:_command(entry.item.id)
            end
        end
        if not (input.left or input.right or input.middle) and self._mode == "suppressed" then self._mode = nil end
        return
    end

    if lp and (kind == "menu_game" or kind == "menu_help") then
        self._menu = kind == "menu_game" and "game" or "help"
        self._menu_hover = nil
        self:_refresh_layout()
        return
    end

    -- Window chrome ---------------------------------------------------------
    if lp and (kind == "face" or kind == "close") then
        self._ui_press = kind
        self._mode = "ui"
    end

    if self._mode == "ui" then
        if lr then
            if self._ui_press == kind then
                if kind == "face" then
                    self:_new_board()
                    self:_refresh_layout()
                elseif kind == "close" then
                    self._close_requested = true
                end
            end
            self._ui_press = nil
            self._mode = nil
        end
        return
    end

    -- Board -------------------------------------------------------------------
    local finished = self:_finished()

    if self._mode == "suppressed" then
        if not (input.left or input.right or input.middle) then self._mode = nil end
        return
    end

    if not finished then
        if mp or (lp and input.right) or (rp and input.left) then
            self._mode = "chord"
        elseif lp then
            self._mode = "left"
        end

        if rp and self._mode ~= "chord" and kind == "cell" then
            self:toggle_mark(a, b)
        end
    end

    if self._mode == "left" and lr then
        if kind == "cell" then self:reveal(a, b) end
        self._mode = input.right and "suppressed" or nil
    elseif self._mode == "chord" and (lr or rr or mr) then
        if kind == "cell" then self:chord(a, b) end
        self._mode = (input.left or input.right or input.middle) and "suppressed" or nil
    elseif self._mode and not (input.left or input.right or input.middle) then
        self._mode = nil
    end
end

-- Queries for the renderer ----------------------------------------------------

function MinesweeperGame:layout() return self._layout end
function MinesweeperGame:rows() return self._rows end
function MinesweeperGame:cols() return self._cols end
function MinesweeperGame:mine_total() return self._mine_total end
function MinesweeperGame:mines_left() return self._mine_total - self._flags end
function MinesweeperGame:status() return self._status end
function MinesweeperGame:level() return self._level end
function MinesweeperGame:level_name(level) return LEVEL_NAMES[level or self._level] end
function MinesweeperGame:levels() return LEVEL_ORDER end
function MinesweeperGame:marks_enabled() return self._marks end
function MinesweeperGame:time() return self._time end
function MinesweeperGame:score() return self._status == "won" and self:timer_value() or 0 end
function MinesweeperGame:is_game_over() return false end
function MinesweeperGame:is_finished() return self:_finished() end
function MinesweeperGame:exploded() return self._exploded end
function MinesweeperGame:menu() return self._menu end
function MinesweeperGame:menu_hover() return self._menu_hover end
function MinesweeperGame:dialog() return self._dialog end
function MinesweeperGame:record_level() return self._record_level end
function MinesweeperGame:cursor_mode() return self._cursor_mode end
function MinesweeperGame:cursor_cell() return self._cursor_col, self._cursor_row end
function MinesweeperGame:pointer() return self._pointer_x, self._pointer_y end
function MinesweeperGame:ui_press() return self._ui_press end
function MinesweeperGame:hover() return self._hover_kind, self._hover_a, self._hover_b end
function MinesweeperGame:game_menu() return GAME_MENU end
function MinesweeperGame:help_menu() return HELP_MENU end
function MinesweeperGame:custom_limits() return MIN_ROWS, MAX_ROWS, MIN_COLS, MAX_COLS, MIN_MINES end

function MinesweeperGame:cell(index)
    return self._state[index], self._mine[index], self._adjacent[index]
end

function MinesweeperGame:state_codes()
    return COVERED, REVEALED, FLAGGED, QUESTION
end

-- Cells shown depressed while a button is held, as in Windows.
function MinesweeperGame:pressed_cells(out)
    local n = 0
    if self:_finished() or self._menu or self._dialog then return 0 end
    if self._hover_kind ~= "cell" or self._cursor_mode ~= "pointer" then return 0 end

    local col, row = self._hover_a, self._hover_b

    if self._mode == "left" then
        local state = self._state[self:_index(col, row)]
        if state == COVERED or state == QUESTION then
            n = 1
            out[1] = self:_index(col, row)
        end
    elseif self._mode == "chord" then
        for dy = -1, 1 do
            for dx = -1, 1 do
                local c, r = col + dx, row + dy
                if c >= 0 and r >= 0 and c < self._cols and r < self._rows then
                    local i = self:_index(c, r)
                    local state = self._state[i]
                    if state == COVERED or state == QUESTION then
                        n = n + 1
                        out[n] = i
                    end
                end
            end
        end
    end

    return n
end

function MinesweeperGame:face()
    if self._ui_press == "face" and self._hover_kind == "face" then return "pressed" end
    if self._status == "lost" then return "dead" end
    if self._status == "won" then return "cool" end
    if (self._mode == "left" or self._mode == "chord") and self._hover_kind == "cell" then return "surprised" end
    return "smile"
end

return MinesweeperGame
