-- Run: lua5.1 skifree_game_test.lua [dir]   (or luajit); dir defaults to /mnt/user-data/outputs/mwg/
local dir = arg and arg[1] or "/mnt/user-data/outputs/mwg/"
if dir:sub(-1) ~= "/" then dir = dir .. "/" end
get_mod = function()
    return { io_dofile = function(_, p) return dofile(dir .. p:match("([^/]+)$") .. ".lua") end }
end
local Game = dofile(dir .. "SkiFree_game.lua")

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

local function new_game(settings, seed)
    local store = settings or {}
    local sounds = {}
    local game = Game:new({
        get = function(key) return store[key] end,
        set = function(key, value) store[key] = value end,
        on_sound = function(kind) sounds[#sounds + 1] = kind end,
        seed = seed or 99,
    })
    game:start()
    return game, store, sounds
end

-- An empty mountain so physics can be tested in isolation.
local function clear_world(game)
    game._generate = function() return {} end
    game._chunks = {}
    game._chunk_count = 0
    game._movers = {}
    game._next_spawn = 1e12
end

local function place(game, kind, x, y)
    local list = game:_chunk(math.floor(x / 192), math.floor(y / 192))
    local o = { kind = kind, x = x, y = y, var = 0 }
    list[#list + 1] = o
    return o
end

local function run(game, seconds, dt)
    dt = dt or 1 / 60
    for _ = 1, math.floor(seconds / dt + 0.5) do game:update(dt) end
end

local function events(game)
    local list = {}
    game:drain_events(function(kind, x, y, value) list[#list + 1] = { kind = kind, x = x, y = y, value = value } end)
    return list
end

local function has_event(list, kind)
    for i = 1, #list do if list[i].kind == kind then return list[i] end end
    return nil
end

local function click(game, x, y)
    game:pointer_input(x, y, { left = true, left_pressed = true })
    game:pointer_input(x, y, { left = false, left_released = true })
end

local function skier_to_screen(game, dx, dy)
    local sx, sy = game:skier_screen()
    return sx + dx, sy + dy
end

-- Tests ---------------------------------------------------------------------------------------

test("new game starts standing sideways at the top with a stopped clock", function()
    local game = new_game({ skifree_highscore = 1234 })
    local x, y, z = game:position()
    assert(x == 0 and y == 0 and z == 0)
    assert(game:dir() == 3 and game:speed() == 0 and game:state() == "ski")
    assert(not game:started() and game:elapsed() == 0)
    assert(game:best() == 1234)
    run(game, 2)
    assert(not game:started() and game:elapsed() == 0, "no movement, no clock")
    assert(game:is_game_over() == false)
end)

test("left/right rotate one step, down points straight downhill", function()
    local game = new_game()
    clear_world(game)
    game:key_press("left")
    assert(game:dir() == 2)
    game:key_press("left", true)
    assert(game:dir() == 1, "repeats keep rotating")
    game:key_press("down")
    assert(game:dir() == 0)
    for _ = 1, 5 do game:key_press("left") end
    assert(game:dir() == -3, "clamped at hard left")
    game:key_press("right")
    assert(game:dir() == -2)
end)

test("pressing further into sideways steps the skier sideways", function()
    local game = new_game()
    clear_world(game)
    local x0 = game:position()
    game:key_press("right")
    assert(game:dir() == 3)
    local x1 = game:position()
    assert(x1 > x0, "shuffled right")
    for _ = 1, 6 do game:key_press("left") end
    local x2 = game:position()
    game:key_press("left")
    local x3 = game:position()
    assert(game:dir() == -3 and x3 < x2, "shuffled left")
end)

test("speed depends on direction and sideways stops", function()
    local speeds = {}
    for d = 0, 3 do
        local game = new_game()
        clear_world(game)
        game._dir = d
        game:key_press("down")
        game._dir = d == 3 and 3 or d
        if d == 3 then game._speed = 150 end
        run(game, 3)
        speeds[d] = game:speed()
    end
    local vmax = new_game():max_speed()
    assert(math.abs(speeds[0] - vmax) < 1, "straight down reaches max " .. speeds[0])
    assert(speeds[1] < speeds[0] and speeds[2] < speeds[1], "steeper is faster")
    assert(speeds[3] == 0, "sideways stops: " .. speeds[3])
end)

test("clock starts on the first movement and formats m:ss.cc", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 1.5)
    assert(game:started())
    assert(math.abs(game:elapsed() - 1.5) < 0.05, "elapsed " .. game:elapsed())
    assert(Game.format_time(83.456) == "1:23.46")
    assert(Game.format_time(0) == "0:00.00")
    assert(Game.format_time(600) == "10:00.00")
end)

test("distance counts metres downhill", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 5)
    local _, y = game:position()
    assert(math.abs(game:distance() - y / game:px_per_m()) < 1e-6)
    assert(game:distance() > 50)
    assert(game:max_distance() >= game:distance())
end)

test("up brakes while moving and walks uphill when sideways", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 3)
    local fast = game:speed()
    game:key_hold("up", true)
    run(game, 0.2)
    assert(game:speed() < fast - 50, "braking")
    run(game, 1)
    assert(game:speed() == 0, "stopped by the brake")
    game:key_hold("up", false)
    game._dir = 3
    local _, y0 = game:position()
    game:key_hold("up", true)
    run(game, 1)
    local _, y1 = game:position()
    assert(y1 < y0 - 30, "walked uphill " .. (y0 - y1))
    assert(game:walking())
    game:key_hold("up", false)
    run(game, 0.5)
    local _, y2 = game:position()
    assert(math.abs(y2 - y1) < 12, "stops walking when released")
    -- A single tap walks a little.
    local _, y3 = game:position()
    game:key_press("up")
    run(game, 0.5)
    local _, y4 = game:position()
    assert(y4 < y3 - 3 and y4 > y3 - 20, "tap walk " .. (y3 - y4))
end)

test("walking is blocked by obstacles instead of crashing", function()
    local game = new_game()
    clear_world(game)
    place(game, "tree_small", 0, -20)
    game:key_hold("up", true)
    run(game, 2)
    local _, y = game:position()
    assert(game:state() == "ski", "no crash")
    assert(y > -20, "blocked below the tree: " .. y)
end)

test("Shift makes the skier faster and F toggles until a crash", function()
    local game = new_game()
    clear_world(game)
    local vmax, vturbo = game:max_speed()
    game:key_press("down")
    game:key_hold("fast", true)
    run(game, 4)
    assert(game:turbo() and math.abs(game:speed() - vturbo) < 1)
    game:key_hold("fast", false)
    run(game, 3)
    assert(math.abs(game:speed() - vmax) < 1, "back to normal speed")
    game:key_press("alt")
    assert(game:turbo())
    run(game, 3)
    assert(game:speed() > vmax + 50)
    local x, y = game:position()
    place(game, "rock", x, y + 20)
    run(game, 0.5)
    assert(game:state() == "crash" and not game:turbo(), "crash ends the F boost")
end)

test("hitting a tree crashes, the skier gets up and can ski on", function()
    local game, _, sounds = new_game()
    clear_world(game)
    place(game, "tree_big", 0, 150)
    game:key_press("down")
    run(game, 2)
    assert(game:state() == "crash", "crashed")
    local ev = events(game)
    local crash = has_event(ev, "crash")
    assert(crash and crash.value == "tree_big")
    assert(game:speed() == 0)
    assert(sounds[#sounds] == "crash")
    run(game, 1.5)
    assert(game:state() == "ski", "got up")
    run(game, 2)
    assert(game:state() == "ski" and game:speed() > 100, "skis on through the tree it hit")
end)

test("a key press after a moment gets up early", function()
    local game = new_game()
    clear_world(game)
    place(game, "rock", 0, 60)
    game:key_press("down")
    run(game, 1.2)
    assert(game:state() == "crash")
    run(game, 0.7)
    game:key_press("left")
    run(game, 0.45)
    assert(game:state() == "ski")
end)

test("space hops over rocks but not into trees", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 3)
    local x, y = game:position()
    place(game, "rock", x, y + 45)
    game:key_press("confirm")
    assert(game:state() == "air")
    run(game, 1)
    assert(game:state() == "ski", "landed, no crash")
    local ev = events(game)
    assert(not has_event(ev, "crash"))
    x, y = game:position()
    place(game, "tree_big", x, y + 45)
    game:key_press("confirm")
    run(game, 1)
    assert(game:state() == "crash", "trees are too tall to hop")
end)

test("ramps launch big jumps and tricks score style on a clean landing", function()
    local game, _, sounds = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 3)
    local x, y = game:position()
    place(game, "ramp", x, y + 30)
    run(game, 0.2)
    assert(game:state() == "air" and game:jump_kind() == "ramp")
    local peak = 0
    game:key_press("confirm")
    for _ = 1, 30 do
        game:update(1 / 60)
        local _, _, z = game:position()
        if z > peak then peak = z end
    end
    assert(game:pending_style() == 10, "spread eagle pending: " .. game:pending_style())
    for _ = 1, 200 do
        if game:state() ~= "air" then break end
        game:update(1 / 60)
        local _, _, z = game:position()
        if z > peak then peak = z end
    end
    assert(peak > 40, "big air: " .. peak)
    assert(game:state() == "ski", "clean landing")
    assert(game:style() == 15, "10 trick + 5 ramp = " .. game:style())
    local land = has_event(events(game), "land")
    assert(land and land.value == 15)
    assert(sounds[#sounds] == "style")
end)

test("multiple tricks add a combo bonus; repeats score half", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 3)
    game:_launch(400, "ramp")
    game:key_press("confirm")
    run(game, 0.4)
    game:key_press("confirm")
    run(game, 0.4)
    game:key_press("down")
    run(game, 0.4)
    assert(game:pending_style() == 10 + 12 + 5, "down cycles back to a half-score spread: " .. game:pending_style())
    for _ = 1, 400 do
        if game:state() ~= "air" then break end
        game:update(1 / 60)
    end
    assert(game:state() == "ski")
    assert(game:style() == 27 + 5 + 10, "style " .. game:style())
end)

test("landing in the middle of a trick is a crash and loses the style", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 3)
    game:_launch(160, "ramp")
    run(game, 0.55)
    game:key_press("up")
    local trick = game:trick()
    assert(trick, "trick started with up")
    run(game, 0.5)
    assert(game:state() == "crash", "mid-trick landing crashes")
    assert(game:style() == 0 and game:pending_style() == 0)
    local crash = has_event(events(game), "crash")
    assert(crash and crash.value == "trick", "crash kind " .. tostring(crash and crash.value))
end)

test("holding a trick key does not auto-repeat tricks", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 2)
    game:_launch(300, "ramp")
    game:key_press("confirm")
    local t1 = game:trick()
    game:key_press("confirm", true)
    game:key_press("up", true)
    assert(game:trick() == t1, "repeats ignored in the air")
end)

test("moguls bump the skier into a small hop", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 3)
    local x, y = game:position()
    place(game, "mogul", x, y + 25)
    run(game, 0.2)
    assert(game:state() == "air" and game:jump_kind() == "bump")
    run(game, 1)
    assert(game:state() == "ski")
end)

test("flags wobble instead of crashing", function()
    local game = new_game()
    clear_world(game)
    local flag = place(game, "flag", 0, 150)
    flag.color, flag.side = "red", -1
    game:key_press("down")
    run(game, 2)
    assert(game:state() == "ski")
    assert(flag.hit_at, "flag knocked")
    assert(has_event(events(game), "flag"))
end)

test("chairlift poles are solid", function()
    local game = new_game()
    clear_world(game)
    place(game, "lift_pole", 0, 150)
    game:key_press("down")
    run(game, 2)
    assert(game:state() == "crash")
end)

test("the chairlift has poles along its line, deterministic per seed", function()
    local game = new_game(nil, 7)
    local lx, spacing, gap, offset = game:lift_constants()
    local list = game:_chunk(math.floor(lx / 192), math.floor((offset + gap * 3) / 192))
    local found = false
    for _, o in ipairs(list) do
        if o.kind == "lift_pole" and o.x == lx then found = true end
    end
    assert(found, "pole in its chunk")
    assert(game:lift_near(lx + spacing * 2 + 100) == lx + spacing * 2)
end)

test("world chunks are deterministic and regenerate identically", function()
    local a = new_game(nil, 4242)
    local b = new_game(nil, 4242)
    local c = new_game(nil, 4243)
    local la, lb, lc = a:_chunk(3, 40), b:_chunk(3, 40), c:_chunk(3, 40)
    assert(#la == #lb)
    for i = 1, #la do assert(la[i].kind == lb[i].kind and la[i].x == lb[i].x and la[i].y == lb[i].y) end
    local same = #la == #lc
    if same then
        for i = 1, #la do if la[i].x ~= lc[i].x then same = false end end
    end
    assert(not same, "different seed, different slope")
    a._chunks = {}
    a._chunk_count = 0
    local again = a:_chunk(3, 40)
    assert(#again == #la and again[1].x == la[1].x)
end)

test("obstacles get denser further down", function()
    local game = new_game(nil, 11)
    local function count(cy)
        local n = 0
        for cx = -12, 12 do
            for _, o in ipairs(game:_chunk(cx, cy)) do
                if o.kind ~= "lift_pole" and o.kind ~= "flag" and o.kind ~= "banner_pole" then n = n + 1 end
            end
        end
        return n
    end
    local near, far = count(20) + count(21), count(200) + count(201)
    assert(far > near * 1.4, "near " .. near .. " far " .. far)
end)

test("the start area is kept clear", function()
    local game = new_game(nil, 5)
    for cx = -1, 0 do
        for cy = 0, 1 do
            for _, o in ipairs(game:_chunk(cx, cy)) do
                if o.kind ~= "banner_pole" and o.kind ~= "sign" and o.kind ~= "lift_pole" and o.kind ~= "flag" then
                    assert(not (math.abs(o.x) < 150 and o.y > -120 and o.y < 250), o.kind .. " at " .. o.x .. "," .. o.y)
                end
            end
        end
    end
end)

test("slalom: gates passed, missed gates add 5 s, best time is stored", function()
    local game, store = new_game()
    clear_world(game)
    local gates, count = game:slalom_gates()
    assert(count == 20)
    game._x, game._y = -340, 250
    game._dir, game._speed = 0, 150
    local passed_x = true
    for i = 1, 4000 do
        local x, y = game:position()
        local s = game:slalom()
        local g = gates[math.min(count, s.next_gate)]
        if s.next_gate <= count then
            local target = g.x
            if s.next_gate == 3 or s.next_gate == 4 then target = g.x + 80 end
            game._x = x + math.max(-3, math.min(3, target - x))
        else
            game._x = x + math.max(-3, math.min(3, -340 - x))
        end
        game:update(1 / 60)
        local _, result = game:slalom()
        if result then break end
    end
    local s, result = game:slalom()
    assert(result, "finished")
    assert(result.missed == 2, "missed " .. result.missed)
    assert(math.abs(result.total - (result.time + 10)) < 1e-6)
    assert(result.record and store.skifree_slalom_best, "record saved")
    assert(math.abs(store.skifree_slalom_best - result.total) < 0.01)
    local ev = events(game)
    assert(has_event(ev, "slalom_start") and has_event(ev, "slalom_finish"))
    assert(not s.active)
end)

test("slalom run is abandoned when walking back above the start", function()
    local game = new_game()
    clear_world(game)
    game._x, game._y = -340, 280
    game._dir, game._speed = 0, 120
    run(game, 0.5)
    assert(game:slalom().active)
    game._y = 200
    run(game, 0.05)
    assert(not game:slalom().active)
    assert(has_event(events(game), "slalom_abort"))
end)

test("no Yeti before 2000 m", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    game._y = 1990 * 12 - 200
    game._max_y = game._y
    run(game, 0.5)
    assert(game:yeti() == nil)
end)

test("the Yeti appears after 2000 m, catches a stopped skier and eats him", function()
    local game, store, sounds = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 1)
    game._y = 2000 * 12 + 10
    game._max_y = game._y
    run(game, 0.1)
    assert(game:yeti(), "yeti spawned")
    assert(has_event(events(game), "yeti"))
    -- Stop and wait.
    game._dir = 3
    run(game, 6)
    assert(game:state() == "eaten" or game:state() == "over", "state " .. game:state())
    assert(sounds[#sounds] == "lose" or sounds[#sounds - 1] == "lose")
    run(game, 4)
    assert(game:state() == "over")
    local dialog = game:shell():dialog()
    assert(dialog and dialog.kind == "over", "game over message box")
    assert(store.skifree_highscore == math.floor(game:max_distance()))
    local ev = events(game)
    local chomps = 0
    for _, e in ipairs(ev) do if e.kind == "chomp" then chomps = chomps + 1 end end
    assert(chomps == 3, "chomp animation " .. chomps)
    assert(game:summary():find("eaten by the Yeti"))
end)

test("walking uphill toward the Yeti gets you caught fast", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 1)
    game._y = 2100 * 12
    game._max_y = game._y
    run(game, 0.05)
    assert(game:yeti())
    game._dir, game._speed = 3, 0
    game:key_hold("up", true)
    run(game, 3)
    assert(game:state() == "eaten" or game:state() == "over")
end)

test("normal skiing loses to the Yeti; the fast key pulls away for a while", function()
    local function chase(turbo)
        local game = new_game()
        clear_world(game)
        game:key_press("down")
        game:key_hold("fast", turbo)
        run(game, 4)
        game._y = 2000 * 12 + 10
        game._max_y = game._y
        run(game, 0.05)
        local yeti = game:yeti()
        local x, y = game:position()
        local d0 = math.sqrt((yeti.x - x) ^ 2 + (yeti.y - y) ^ 2)
        run(game, 3)
        if game:state() ~= "ski" then return 0, d0 end
        x, y = game:position()
        return math.sqrt((yeti.x - x) ^ 2 + (yeti.y - y) ^ 2), d0
    end
    local d_normal, start = chase(false)
    local d_fast = chase(true)
    assert(d_normal < start, "yeti gains on a normal skier")
    assert(d_fast > start, "fast skier pulls away " .. d_fast .. " vs " .. start)
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    game:key_hold("fast", true)
    run(game, 4)
    game._y = 2000 * 12 + 10
    game._max_y = game._y
    run(game, 90)
    assert(game:state() ~= "ski", "eventually even the fast skier is caught")
end)

test("the Yeti cannot grab a skier high in the air", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 1)
    game._y = 2000 * 12 + 10
    game._max_y = game._y
    run(game, 0.05)
    local yeti = game:yeti()
    game:_launch(600, "ramp")
    run(game, 0.3)
    local x, y = game:position()
    yeti.x, yeti.y = x, y
    game:_step_yeti(0.001)
    assert(game:state() == "air", "too high to catch")
end)

test("Play Again and Exit on the game over message box", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 1)
    game._y = 2000 * 12 + 10
    game._max_y = game._y
    game._dir = 3
    run(game, 12)
    assert(game:state() == "over")
    game:key_press("confirm")
    assert(game:state() == "ski" and game:distance() == 0, "Play Again is the default button")
    assert(game:shell():dialog() == nil)
    clear_world(game)
    game:key_press("down")
    run(game, 1)
    game._y = 2000 * 12 + 10
    game._max_y = game._y
    game._dir = 3
    run(game, 12)
    local D = game:layout().dialog
    local exit_button
    for _, b in ipairs(D.buttons) do if b.spec.id == "exit" then exit_button = b.rect end end
    click(game, exit_button.x + 5, exit_button.y + 5)
    assert(game:consume_close_request(), "Exit closes the game")
    assert(not game:consume_close_request(), "only once")
end)

test("R starts a new game, also from the game over box; Esc keeps the eaten screen", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 1)
    game._y = 2000 * 12 + 10
    game._max_y = game._y
    game._dir = 3
    run(game, 12)
    assert(game:state() == "over")
    assert(game:ui_back() == true, "Esc closes the message box")
    assert(game:shell():dialog() == nil and game:state() == "over")
    assert(game:ui_back() == false, "then Esc leaves the game")
    game:key_press("new")
    assert(game:state() == "ski" and game:yeti() == nil)
end)

test("highscore keeps the best distance", function()
    local game, store = new_game({ skifree_highscore = 5000 })
    clear_world(game)
    game:key_press("down")
    run(game, 5)
    game:new_game()
    assert(store.skifree_highscore == 5000, "worse run does not overwrite")
    local game2, store2 = new_game({ skifree_highscore = 10 })
    clear_world(game2)
    game2:key_press("down")
    run(game2, 5)
    local metres = math.floor(game2:max_distance())
    game2:summary()
    assert(store2.skifree_highscore == metres, "saved " .. tostring(store2.skifree_highscore))
end)

test("summary line", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 2)
    local s = game:summary()
    assert(s:find("^%[SkiFree%] Distance: %d+ m  Style: 0  Time: 0:02%.%d%d  Best: %d+ m$"), s)
end)

test("Game > Pause freezes the slope; a key resumes", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 1)
    game:key_press("menu")
    assert(game:shell():menu() == 1)
    local _, y0 = game:position()
    run(game, 1)
    local _, y1 = game:position()
    assert(y0 == y1, "open menu pauses")
    game:key_press("down")
    assert(game:layout().menu_items[game:shell():menu_hover()].item.id == "pause")
    game:key_press("confirm")
    assert(game:is_paused() and game:shell():menu() == nil)
    run(game, 1)
    local _, y2 = game:position()
    assert(y2 == y1, "paused")
    game:key_press("left")
    assert(not game:is_paused(), "a key resumes")
    run(game, 0.5)
    local _, y3 = game:position()
    assert(y3 > y2)
    game:set_paused(true)
    assert(game:ui_back() == true and not game:is_paused(), "Esc resumes")
    assert(game:ui_back() == false)
end)

test("menus by pointer: New Game and How to Play", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 2)
    local L = game:layout()
    local title = L.menu_titles[1]
    click(game, title.x + 5, title.y + 5)
    assert(game:shell():menu() == 1)
    local item = game:layout().menu_items[1]
    assert(item.item.id == "new")
    game:pointer_input(item.rect.x + 5, item.rect.y + 5, { left = true, left_pressed = true })
    game:pointer_input(item.rect.x + 5, item.rect.y + 5, { left = false, left_released = true })
    assert(game:distance() == 0 and not game:started(), "new game")
    title = game:layout().menu_titles[2]
    click(game, title.x + 5, title.y + 5)
    assert(game:shell():menu() == 2)
    local how = game:layout().menu_items[1]
    click(game, how.rect.x + 5, how.rect.y + 5)
    local dialog = game:shell():dialog()
    assert(dialog and dialog.kind == "how_to")
    game:key_press("confirm")
    assert(game:shell():dialog() == nil)
    game:key_press("menu")
    game:key_press("right")
    game:key_press("down")
    game:key_press("confirm")
    assert(game:shell():dialog().kind == "about")
    assert(game:ui_back() == true and game:shell():dialog() == nil)
end)

test("window close button and Exit request a close", function()
    local game = new_game()
    local L = game:layout()
    click(game, L.close_button.x + 4, L.close_button.y + 4)
    assert(game:consume_close_request())
    game:key_press("menu")
    game:key_press("up")
    assert(game:layout().menu_items[game:shell():menu_hover()].item.id == "exit")
    game:key_press("confirm")
    assert(game:consume_close_request())
end)

test("mouse steers toward the pointer; keys override until it moves again", function()
    local game = new_game()
    clear_world(game)
    local x, y = skier_to_screen(game, -100, 60)
    game:pointer_input(x, y, {})
    game:pointer_input(x + 1, y, {})
    run(game, 0.1)
    assert(game:steer_mode() == "mouse")
    assert(game:dir() == -2, "down-left " .. game:dir())
    x, y = skier_to_screen(game, 3, 120)
    game:pointer_input(x, y, {})
    run(game, 0.05)
    assert(game:dir() == 0, "straight down")
    x, y = skier_to_screen(game, 80, -40)
    game:pointer_input(x, y, {})
    run(game, 0.05)
    assert(game:dir() == 3, "pointer above: stop sideways")
    game:key_press("down")
    assert(game:steer_mode() == "keys" and game:dir() == 0)
    game:pointer_input(x, y, {})
    run(game, 0.2)
    assert(game:dir() == 0, "still pointer: keys keep control")
    game:pointer_input(x - 2, y, {})
    run(game, 0.05)
    assert(game:steer_mode() == "mouse" and game:dir() == 3)
end)

test("left click in the slope jumps; clicks on the menu bar do not", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 2)
    local x, y = skier_to_screen(game, 0, 80)
    click(game, x, y)
    assert(game:state() == "air")
    run(game, 1)
    local L = game:layout()
    click(game, L.menubar.x + L.menubar.w - 20, L.menubar.y + 5)
    assert(game:state() == "ski")
end)

test("snowboarders and dogs crash the skier and react", function()
    local game = new_game()
    clear_world(game)
    game:key_press("down")
    run(game, 2)
    local x, y = game:position()
    local board = { kind = "boarder", x = x, y = y + 60, base = x, vy = 0, amp = 0, freq = 0, phase = 0, lean = 0, var = 0 }
    game._movers[1] = board
    run(game, 1)
    assert(game:state() == "crash")
    assert(board.fallen, "boarder falls too")
    run(game, 2)
    x, y = game:position()
    local dog = { kind = "dog", x = x, y = y + 60, vx = 0, turn = 10, sit = 0, phase = 0, var = 0 }
    game._movers[2] = dog
    run(game, 1)
    assert(game:state() == "crash")
    assert(dog.flee and dog.vx ~= 0, "dog runs off")
end)

test("moving hazards spawn as the skier descends", function()
    local game = new_game(nil, 3)
    game:key_press("down")
    game._y = 900 * 12
    game._max_y = game._y
    game._next_spawn = 0
    local kinds = {}
    for _ = 1, 60 * 30 do
        game:update(1 / 60)
        for _, m in ipairs(game:movers()) do kinds[m.kind] = true end
        if game:state() == "crash" then game._state = "ski"; game._crash_t = 0 end
        game._dir = 0
    end
    assert(kinds.dog and kinds.boarder, "dogs and boarders")
    assert(#game:movers() <= 8)
end)

test("chunks are evicted on long runs", function()
    local game = new_game()
    game:key_press("down")
    for _ = 1, 60 * 120 do
        game:update(1 / 60)
        if game:state() == "crash" then game._crash_t = 5 end
        game._dir = 0
        if game:yeti() then game._yeti = nil; game._max_y = 0 end
    end
    assert(game._chunk_count < 120, "chunk count " .. game._chunk_count)
end)

test("collect_visible returns what is on screen", function()
    local game = new_game(nil, 8)
    local out = {}
    local n = game:collect_visible(out)
    assert(n == #out and n > 5)
    local cam_x, cam_y = game:camera()
    local w, h = game:client_size()
    for i = 1, n do
        local o = out[i]
        assert(o.x > cam_x - 50 and o.x < cam_x + w + 50 and o.y > cam_y - 20 and o.y < cam_y + h + 90)
    end
end)

test("the window fits the canvas above the taskbar", function()
    local game = new_game()
    local L = game:layout()
    assert(L.window.x >= 0 and L.window.x + L.window.w <= 600)
    assert(L.window.y >= 0 and L.window.y + L.window.h <= 572 - 22, "leaves room for the hint")
    assert(L.client.w == 560 and L.client.h == 470)
end)

test("large dt is split into substeps without tunnelling", function()
    local game = new_game()
    clear_world(game)
    place(game, "stump", 0, 600)
    game:key_press("down")
    game:key_hold("fast", true)
    for _ = 1, 100 do
        game:update(0.1)
        if game:state() == "crash" then break end
    end
    assert(game:state() == "crash", "stump hit despite 100 ms frames")
end)

test("passing the previous best distance is announced once per run", function()
    local game = new_game({ skifree_highscore = 20 })
    clear_world(game)
    place(game, "rock", 0, 100)
    game:key_press("down")
    run(game, 5)
    assert(game:state() == "ski", "got up after the rock")
    assert(game:max_distance() > 30, "went past the old best")
    local ev = events(game)
    local count = 0
    for _, e in ipairs(ev) do if e.kind == "record" then count = count + 1 end end
    assert(count == 1, "one record event, got " .. count)
    local fresh = new_game()
    clear_world(fresh)
    place(fresh, "rock", 0, 100)
    fresh:key_press("down")
    run(fresh, 4)
    assert(not has_event(events(fresh), "record"), "no record on the very first run")
end)

print(string.format("%d scenarios passed; %d failed", passed, failed))
if failed > 0 then os.exit(1) end
