-- Run from workspace root: lua55.exe mods/active/MourningstarWaitingGames/tests/breakout_game_test.lua [scripts dir]
local dir = arg and arg[1] or "mods/active/MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/"
if dir:sub(-1) ~= "/" then dir = dir .. "/" end
get_mod = function()
    return { io_dofile = function(_, p) return dofile(dir .. p:match("([^/]+)$") .. ".lua") end }
end
local Game = dofile(dir .. "Breakout_game.lua")
local passed, failed = 0, 0

local function test(name, run)
    local ok, err = pcall(run)
    if ok then passed = passed + 1; print("PASS: " .. name)
    else failed = failed + 1; print("FAIL: " .. name .. ": " .. tostring(err)) end
end

local function new_game()
    local store, sounds = {}, {}
    local game = Game:new({
        get = function(k) return store[k] end,
        set = function(k, v) store[k] = v end,
        on_sound = function(kind) sounds[#sounds + 1] = kind end,
    })
    game:start()
    return game, store, sounds
end

local function run(game, seconds)
    for _ = 1, math.floor(seconds * 60) do game:update(1 / 60) end
end

test("level 1 is the classic three rows", function()
    local game = new_game()
    assert(game:bricks_left() == 25, "25 bricks, got " .. game:bricks_left())
    assert(game:state() == "serve" and game:lives() == 3 and game:level() == 1)
end)

test("the ball waits on the paddle until launched", function()
    local game = new_game()
    game:key_hold("right", true)
    run(game, 0.3)
    game:key_hold("right", false)
    local px, py, pw = game:paddle()
    local bx, by = game:ball()
    assert(math.abs(bx - (px + pw / 2)) < 0.01, "ball follows paddle")
    game:key_press("confirm")
    assert(game:state() == "play")
    run(game, 0.2)
    local _, by2 = game:ball()
    assert(by2 < by, "ball moves up")
end)

test("hitting a brick scores and removes it", function()
    local game = new_game()
    local b = game:bricks()[2]
    game._state = "play"
    game._ball_x, game._ball_y = b.x + b.w / 2, b.y + b.h + 10
    game._vx, game._vy = 0, -300
    run(game, 0.05)
    assert(not b.alive, "brick destroyed")
    assert(game:score() == 10)
    local _, vy = game:ball_velocity()
    assert(vy > 0, "ball bounces down")
end)

test("tough bricks take two hits", function()
    local game = new_game()
    game._level = 3
    game:_build_level()
    local b = game:bricks()[1]
    assert(b.max_hits == 2)
    game:_hit_brick(b)
    assert(b.alive and b.hits == 1)
    game._vx, game._vy = 100, -200
    game:_hit_brick(b)
    assert(not b.alive)
end)

test("paddle angle depends on the hit position", function()
    local game = new_game()
    local px, py, pw = game:paddle()
    game._state = "play"
    game._ball_x, game._ball_y = px + pw - 2, py - 8
    game._vx, game._vy = 0, 300
    run(game, 0.05)
    local vx, vy = game:ball_velocity()
    assert(vy < 0 and vx > 100, "right edge sends the ball right: " .. vx)
end)

test("losing all balls ends the game and stores the best score", function()
    local game, store = new_game()
    game._score = 420
    for life = 3, 1, -1 do
        game._state = "play"
        game._ball_x, game._ball_y = 20, 470
        game._vx, game._vy = 0, 300
        run(game, 0.2)
        if life > 1 then
            assert(game:lives() == life - 1)
            run(game, 1.5)
            assert(game:state() == "serve", "new serve after a lost ball")
        end
    end
    assert(game:state() == "over" and game:lives() == 0)
    assert(store.breakout_highscore == 420)
    assert(game:shell():dialog().kind == "over")
    game:shell():_button_by_id("again")
    assert(game:state() == "serve" and game:lives() == 3 and game:score() == 0)
end)

test("clearing the wall advances the level", function()
    local game = new_game()
    game._state = "play"
    game._vx, game._vy = 0, -300
    for _, b in ipairs(game:bricks()) do game:_hit_brick(b) end
    assert(game:state() == "cleared")
    run(game, 2)
    assert(game:level() == 2 and game:state() == "serve" and game:bricks_left() > 25)
end)

test("mouse steers the paddle and clicks launch", function()
    local game = new_game()
    local client = game:layout().client
    game:pointer_input(client.x + 100, client.y + 300, {})
    game:pointer_input(client.x + 120, client.y + 300, {})
    run(game, 0.05)
    local px, _, pw = game:paddle()
    assert(math.abs(px + pw / 2 - 120) < 0.01, "paddle centred on the pointer")
    game:pointer_input(client.x + 120, client.y + 300, { left = true, left_pressed = true })
    assert(game:state() == "play")
end)

test("pause, menus and Esc", function()
    local game = new_game()
    game:key_press("alt")
    assert(game:is_paused())
    assert(game:ui_back() == true and not game:is_paused())
    game:key_press("menu")
    assert(game:shell():menu() == 1)
    assert(game:ui_back() == true)
    assert(game:ui_back() == false, "Esc with nothing open leaves the game")
end)

test("long autoplay never escapes the field", function()
    local game = new_game()
    math.randomseed(3)
    local w, h = game:client_size()
    for i = 1, 60 * 240 do
        local bx = game:ball()
        game._paddle_x = math.max(0, math.min(w - 56, bx - 28 + math.sin(i * 0.01) * 20))
        game._control = "keys"
        if game:state() == "serve" then game:launch() end
        if game:state() == "over" then game:new_game() end
        game:update(1 / 60)
        local x, y = game:ball()
        assert(x == x and y == y, "no NaN")
        assert(x >= 0 and x <= w and y >= 0, "ball inside the field")
    end
    assert(game:level() >= 2, "autoplay clears walls, reached level " .. game:level())
end)

print(string.format("%d scenarios passed; %d failed", passed, failed))
if failed > 0 then os.exit(1) end
