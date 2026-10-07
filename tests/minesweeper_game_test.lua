-- Run from workspace root: lua-5.5.0_Win64_bin/lua55.exe mods/active/MourningstarWaitingGames/tests/minesweeper_game_test.lua
local path = arg and arg[1] or "mods/active/MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Minesweeper_game.lua"
local Game = dofile(path)
local passed, failed = 0, 0

local function test(name, run)
    local ok, err = pcall(run)
    if ok then
        passed = passed + 1
        print("PASS: " .. name)
    else
        failed = failed + 1
        print("FAIL: " .. name .. ": " .. tostring(err))
    end
end

local function new_game(settings)
    local store = settings or {}
    local sounds = {}
    local game = Game:new({
        get = function(key) return store[key] end,
        set = function(key, value) store[key] = value end,
        on_sound = function(kind) sounds[#sounds + 1] = kind end,
    })
    game:start()
    return game, store, sounds
end

-- Replace the random mine layout with a fixed one; mines is a list of {col, row}.
local function set_mines(game, mines)
    local count = game:rows() * game:cols()
    for i = 1, count do game._mine[i] = false end
    for _, m in ipairs(mines) do game._mine[m[2] * game:cols() + m[1] + 1] = true end
    game._mine_total = #mines
    game:_count_adjacent()
end

local function state_at(game, col, row)
    local state = game:cell(row * game:cols() + col + 1)
    return state
end

local COVERED, REVEALED, FLAGGED, QUESTION = 0, 1, 2, 3

local function mine_count(game)
    local n = 0
    for i = 1, game:rows() * game:cols() do
        local _, mine = game:cell(i)
        if mine then n = n + 1 end
    end
    return n
end

test("standard levels use Windows 95 sizes", function()
    local game = new_game()
    assert(game:cols() == 9 and game:rows() == 9 and mine_count(game) == 10)
    game:set_level("intermediate")
    assert(game:cols() == 16 and game:rows() == 16 and mine_count(game) == 40)
    game:set_level("expert")
    assert(game:cols() == 30 and game:rows() == 16 and mine_count(game) == 99)
end)

test("first click on a mine moves it to the first free top-left square", function()
    local game = new_game()
    set_mines(game, { { 4, 4 }, { 0, 0 } })
    game:reveal(4, 4)
    assert(game:status() ~= "lost", "first click must be safe")
    local _, moved = game:cell(2)
    assert(moved, "mine should move to (1,0), the first free square")
    local _, old = game:cell(4 * 9 + 4 + 1)
    assert(not old)
    assert(mine_count(game) == 2)
end)

test("opening a zero floods to the numbered border", function()
    local game = new_game()
    set_mines(game, { { 8, 8 } })
    game:reveal(0, 0)
    assert(game:status() == "won", "only one mine: every other square opens")
    assert(state_at(game, 8, 8) == FLAGGED, "Windows flags the remaining mines on a win")
end)

test("right click cycles flag, question mark and blank", function()
    local game = new_game()
    set_mines(game, { { 1, 1 } })
    game:toggle_mark(3, 3)
    assert(state_at(game, 3, 3) == FLAGGED and game:mines_left() == 0)
    game:toggle_mark(3, 3)
    assert(state_at(game, 3, 3) == QUESTION and game:mines_left() == 1)
    game:toggle_mark(3, 3)
    assert(state_at(game, 3, 3) == COVERED)
end)

test("marks disabled skips question marks and clears existing ones", function()
    local game = new_game()
    game:toggle_mark(2, 2)
    game:toggle_mark(2, 2)
    assert(state_at(game, 2, 2) == QUESTION)
    game:toggle_marks()
    assert(state_at(game, 2, 2) == COVERED)
    game:toggle_mark(2, 2)
    game:toggle_mark(2, 2)
    assert(state_at(game, 2, 2) == COVERED)
end)

test("flagged squares cannot be opened; question marks can", function()
    local game = new_game()
    set_mines(game, { { 0, 0 }, { 8, 8 } })
    game:toggle_mark(0, 0)
    game:reveal(0, 0)
    assert(state_at(game, 0, 0) == FLAGGED)
    game:toggle_mark(4, 4)
    game:toggle_mark(4, 4)
    game:reveal(4, 4)
    assert(state_at(game, 4, 4) == REVEALED)
end)

test("chord opens neighbours when the flag count matches", function()
    local game = new_game()
    set_mines(game, { { 1, 0 }, { 8, 8 }, { 7, 8 } })
    game:reveal(1, 1)
    assert(state_at(game, 1, 1) == REVEALED)
    game:chord(1, 1)
    assert(state_at(game, 0, 1) == COVERED, "no chord without matching flags")
    game:toggle_mark(1, 0)
    game:chord(1, 1)
    assert(state_at(game, 0, 1) == REVEALED and state_at(game, 2, 2) == REVEALED)
end)

test("chord with a wrong flag detonates the unflagged mine", function()
    local game = new_game()
    set_mines(game, { { 1, 0 }, { 8, 8 } })
    game:reveal(1, 1)
    game:toggle_mark(0, 0)
    game:chord(1, 1)
    assert(game:status() == "lost")
    assert(game:exploded() == 2)
end)

test("loss freezes the board and the timer", function()
    local game = new_game()
    set_mines(game, { { 0, 0 }, { 8, 8 }, { 4, 5 } })
    game:reveal(4, 4)
    assert(game:status() == "playing")
    game:update(3.2)
    game:reveal(0, 0)
    assert(game:status() == "lost")
    local t = game:timer_value()
    game:update(5)
    assert(game:timer_value() == t, "timer must stop")
    game:toggle_mark(5, 5)
    assert(state_at(game, 5, 5) ~= FLAGGED, "board frozen")
end)

test("timer shows 1 after the first click and caps at 999", function()
    local game = new_game()
    assert(game:timer_value() == 0)
    set_mines(game, { { 0, 0 }, { 8, 8 }, { 4, 5 } })
    game:reveal(4, 4)
    assert(game:timer_value() == 1)
    game:update(2000)
    assert(game:timer_value() == 999)
end)

test("win stores a best time and opens the record dialog", function()
    local game, store = new_game()
    set_mines(game, { { 8, 8 } })
    game:reveal(0, 0)
    assert(store.minesweeper_best_beginner == 1)
    assert(game:dialog() and game:dialog().kind == "record")
    game:key_reveal()
    assert(game:dialog().kind == "best")
    game:key_reveal()
    assert(game:dialog() == nil)
end)

test("slower wins do not overwrite a record", function()
    local game, store = new_game({ minesweeper_best_beginner = 5 })
    set_mines(game, { { 8, 8 }, { 4, 5 } })
    game:reveal(4, 4)
    game:update(10)
    game:reveal(0, 0)
    assert(game:status() == "won")
    assert(store.minesweeper_best_beginner == 5)
    assert(game:dialog() == nil)
end)

test("custom field clamps to Windows limits", function()
    local game = new_game()
    game:set_custom(100, 3, 5000)
    assert(game:rows() == 24 and game:cols() == 9 and mine_count(game) == 23 * 8)
    game:set_custom(9, 9, 1)
    assert(mine_count(game) == 10)
end)

test("pointer left press and release reveals, right press flags", function()
    local game = new_game()
    set_mines(game, { { 0, 0 }, { 8, 8 } })
    local L = game:layout()
    local cx = L.board.x + L.cell * 4.5
    local cy = L.board.y + L.cell * 4.5
    game:pointer_input(cx, cy, { left = true, left_pressed = true })
    assert(state_at(game, 4, 4) == COVERED, "reveal happens on release")
    assert(game:face() == "surprised")
    game:pointer_input(cx, cy, { left = false, left_released = true })
    assert(state_at(game, 4, 4) == REVEALED)
    local fx = L.board.x + L.cell * 0.5
    game:pointer_input(fx, fx - L.board.x + L.board.y, { right = true, right_pressed = true })
    game:pointer_input(fx, fx - L.board.x + L.board.y, { right = false, right_released = true })
    assert(state_at(game, 0, 0) == FLAGGED)
end)

test("both buttons chord on release", function()
    local game = new_game()
    set_mines(game, { { 1, 0 }, { 8, 8 } })
    game:reveal(1, 1)
    game:toggle_mark(1, 0)
    local L = game:layout()
    local x, y = L.board.x + L.cell * 1.5, L.board.y + L.cell * 1.5
    game:pointer_input(x, y, { left = true, left_pressed = true })
    game:pointer_input(x, y, { left = true, right = true, right_pressed = true })
    local pressed = {}
    assert(game:pressed_cells(pressed) > 0)
    game:pointer_input(x, y, { left = false, right = true, left_released = true })
    assert(state_at(game, 0, 1) == REVEALED)
    assert(state_at(game, 1, 0) == FLAGGED, "the right press must not toggle during chord")
    game:pointer_input(x, y, { right = false, right_released = true })
end)

test("face click starts a new game", function()
    local game = new_game()
    set_mines(game, { { 0, 0 }, { 8, 8 }, { 4, 5 } })
    game:reveal(4, 4)
    local face = game:layout().face
    local x, y = face.x + 5, face.y + 5
    game:pointer_input(x, y, { left = true, left_pressed = true })
    assert(game:face() == "pressed")
    game:pointer_input(x, y, { left = false, left_released = true })
    assert(game:status() == "ready")
end)

test("menu opens on click and runs the item on release", function()
    local game = new_game()
    local L = game:layout()
    game:pointer_input(L.menu_game.x + 4, L.menu_game.y + 4, { left = true, left_pressed = true })
    assert(game:menu() == "game")
    game:pointer_input(L.menu_game.x + 4, L.menu_game.y + 4, { left = false, left_released = true })
    local items = game:layout().menu_items
    local expert = items[5].rect
    assert(items[5].item.id == "expert")
    game:pointer_input(expert.x + 5, expert.y + 5, { left = true, left_pressed = true })
    game:pointer_input(expert.x + 5, expert.y + 5, { left = false, left_released = true })
    assert(game:menu() == nil and game:level() == "expert" and game:cols() == 30)
end)

test("custom dialog through keyboard", function()
    local game = new_game()
    game:toggle_menu()
    for _ = 1, 4 do game:move_cursor(0, 1) end
    assert(game:layout().menu_items[game:menu_hover()].item.id == "custom")
    game:key_reveal()
    assert(game:dialog().kind == "custom")
    game:move_cursor(1, 0)
    game:key_reveal()
    assert(game:level() == "custom" and game:rows() == 21)
end)

test("Esc closes dialogs and menus before the game", function()
    local game = new_game()
    game:toggle_menu()
    assert(game:ui_back() == true and game:menu() == nil)
    assert(game:ui_back() == false)
end)

test("keyboard cursor wraps and reveals or chords", function()
    local game = new_game()
    set_mines(game, { { 0, 0 }, { 8, 8 } })
    local col, row = game:cursor_cell()
    game:move_cursor(-1, 0)
    local c2 = game:cursor_cell()
    assert(c2 == (col - 1) % 9)
    for _ = 1, 20 do game:move_cursor(1, 0) end
    game:key_reveal()
    assert(game:status() ~= "lost")
end)

test("expert layout fits the 600px canvas", function()
    local game = new_game()
    game:set_level("expert")
    local L = game:layout()
    assert(L.window.x >= 0 and L.window.x + L.window.w <= 600, "width")
    assert(L.window.y >= 0 and L.window.y + L.window.h <= 560, "height")
    game:set_custom(24, 30, 200)
    L = game:layout()
    assert(L.window.y + L.window.h <= 560 and L.window.x + L.window.w <= 600)
end)

print(string.format("%d scenarios passed; %d failed", passed, failed))
if failed > 0 then os.exit(1) end
