-- Run: lua5.1 battlechess_game_test.lua [mod_script_dir]   (also runs under luajit)
local DIR = arg and arg[1] or "/mnt/user-data/outputs/mwg/"
if DIR:sub(-1) ~= "/" then DIR = DIR .. "/" end
get_mod = function()
    return { io_dofile = function(_, p) return dofile(DIR .. p:match("([^/]+)$") .. ".lua") end }
end
local Game = dofile(DIR .. "BattleChess_game.lua")
local Engine = dofile(DIR .. "BattleChess_engine.lua")
local D3 = dofile(DIR .. "BattleChess_3d.lua")
local Figures = dofile(DIR .. "BattleChess_figures.lua")

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

local function eq(a, b, msg)
    if a ~= b then error((msg or "values differ") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

local function near(a, b, eps, msg)
    if math.abs(a - b) > (eps or 1e-6) then error((msg or "not near") .. ": " .. tostring(a) .. " vs " .. tostring(b), 2) end
end

local function sq(name) return (name:byte(2) - 49) * 8 + (name:byte(1) - 97) end

local function new_game(settings)
    local store, sounds = {}, {}
    for k, v in pairs(settings or {}) do store[k] = v end
    if store.battlechess_level == nil then store.battlechess_level = 1 end
    local game = Game:new({
        get = function(k) return store[k] end,
        set = function(k, v) store[k] = v end,
        on_sound = function(kind) sounds[#sounds + 1] = kind end,
    })
    game:start()
    return game, store, sounds
end

local function load_fen(game, fen)
    game._pos = Engine.new(fen)
    game._job, game._ai_move, game._seq, game._over = nil, nil, nil, nil
    game:select(nil)
    game:_sync_actors()
    game:_maybe_think()
end

local function run(game, seconds)
    for _ = 1, math.floor(seconds * 60 + 0.5) do game:update(1 / 60) end
end

local function run_until(game, pred, seconds)
    for _ = 1, math.floor((seconds or 30) * 60) do
        if pred() then return true end
        game:update(1 / 60)
    end
    return pred()
end

local function events(game)
    local list = {}
    game:drain_events(function(ev) list[#list + 1] = ev.kind end)
    return list
end

local function has(list, kind)
    for i = 1, #list do if list[i] == kind then return true end end
    return false
end

local function idle(game)
    return not game:in_sequence() and not game:is_thinking() and not game._ai_move
end

local function screen_of(game, square, h)
    local x, z = Game.sq_xz(square)
    return game:camera():project(x, h or 0, z)
end

-- 3D module ------------------------------------------------------------------------------------------

test("matrices compose like the transforms they describe", function()
    local a = D3.mat_set({}, 1, 2, 3, 0, math.pi / 2, 0)
    local x, y, z = D3.mat_point(a, 0, 0, 1)
    near(x, 2, 1e-9, "yaw 90 turns +z into +x"); near(y, 2, 1e-9); near(z, 3, 1e-9)
    local b = D3.mat_set({}, 0, 0, 0, 0, 0, 0, 2)
    local c = D3.mat_mul({}, a, b)
    x, y, z = D3.mat_point(c, 0, 1, 0)
    near(x, 1, 1e-9); near(y, 4, 1e-9, "scale then translate"); near(z, 3, 1e-9)
end)

test("camera projection and plane unprojection round-trip", function()
    local cam = D3.camera()
    cam:set_viewport(10, 20, 500, 400)
    for _, v in ipairs({ { 0, 0.8, 12 }, { 1.2, 0.5, 9 }, { -2.5, 1.2, 15 }, { 3, 0.4, 7 } }) do
        cam.yaw, cam.pitch, cam.dist = v[1], v[2], v[3]
        cam:update()
        for _, p in ipairs({ { 0, 0 }, { 3.2, -1.4 }, { -3.7, 3.9 } }) do
            local sx, sy = cam:project(p[1], 0, p[2])
            assert(sx, "point in front of camera")
            local wx, wz = cam:unproject_plane(sx, sy, 0)
            near(wx, p[1], 1e-6); near(wz, p[2], 1e-6)
        end
    end
    assert(D3.point_in_quad(5, 5, 0, 0, 10, 0, 10, 10, 0, 10))
    assert(D3.point_in_quad(5, 5, 0, 0, 0, 10, 10, 10, 10, 0), "either winding")
    assert(not D3.point_in_quad(11, 5, 0, 0, 10, 0, 10, 10, 0, 10))
end)

test("closed meshes are oriented outwards and back faces are culled", function()
    local m = D3.mesh()
    m:box(-1, -1, -1, 1, 1, 1, 1)
    eq(m:faces(), 12)
    local cam = D3.camera()
    cam:set_viewport(0, 0, 400, 400)
    cam.yaw, cam.pitch, cam.dist = 0.4, 0.5, 8
    cam:update()
    local R = D3.renderer()
    R:begin(cam)
    R:mesh(m, D3.mat(), { { 200, 200, 200 } })
    -- a camera sees at most three faces of a box: six triangles
    assert(R:count() >= 4 and R:count() <= 6, "visible faces " .. R:count())
    R:discard()
end)

-- Figures -----------------------------------------------------------------------------------------------

local function finite_frame(renderer)
    for i = 1, renderer:count() do
        for _, arr in ipairs({ renderer.X1, renderer.Y1, renderer.X2, renderer.Y2, renderer.X3, renderer.Y3, renderer.R, renderer.G, renderer.B }) do
            local v = arr[i]
            if v ~= v or v == math.huge or v == -math.huge then return false end
        end
    end
    return true
end

test("every figure builds within the triangle budget and draws in every animation", function()
    local cam = D3.camera()
    cam:set_viewport(0, 0, 400, 400)
    cam.yaw, cam.pitch, cam.dist, cam.ty = 0.7, 0.4, 3, 0.5
    cam:update()
    local R = D3.renderer()
    local pose = Figures.new_pose()
    local anims = { "idle", "walk", "hop", "attack", "topple", "cheer", "promote" }
    for _, kind in ipairs({ "p", "n", "b", "r", "q", "k" }) do
        local tris = Figures.triangles(kind)
        assert(tris >= 60 and tris <= 200, kind .. " has " .. tris .. " triangles")
        for _, side in ipairs({ "w", "b" }) do
            for _, anim in ipairs(anims) do
                for t = 0, 2, 0.25 do
                    local a = { kind = kind, side = side, x = 0, z = 0, yaw = 0.3, anim = anim, anim_t = t, walk = t, hop = t / 2, id = 4 }
                    R:begin(cam)
                    Figures.animate(a, pose, t)
                    Figures.draw(R, a, pose)
                    assert(R:count() > 20, kind .. " " .. anim .. " draws")
                    assert(finite_frame(R), kind .. " " .. anim .. " finite")
                    R:discard()
                end
            end
            for style in pairs(Figures.DEATH) do
                for t = 0, Figures.DEATH[style], 0.2 do
                    local a = { kind = kind, side = side, x = 0, z = 0, yaw = 0, anim = "die", anim_t = t, style = style, id = 1 }
                    R:begin(cam)
                    Figures.animate(a, pose, t)
                    Figures.draw(R, a, pose)
                    assert(finite_frame(R), kind .. " " .. style .. " finite")
                    R:discard()
                end
                -- the victim is fully gone once its death has played out
                local a = { kind = kind, side = side, x = 0, z = 0, yaw = 0, anim = "die", anim_t = Figures.DEATH[style], style = style, id = 1 }
                Figures.animate(a, pose, 0)
                assert(pose.alpha <= 0.01, style .. " fades out")
            end
        end
    end
end)

test("death styles depend on the killing blow and the victim", function()
    eq(Figures.death_style("p", "r"), "crumble", "golems crumble")
    eq(Figures.death_style("q", "q"), "sparkle", "queens vanish in sparkles")
    eq(Figures.death_style("q", "n"), "ash", "the queen's bolt burns to ash")
    eq(Figures.death_style("r", "p"), "squash", "golem smash")
    eq(Figures.death_style("b", "k"), "dizzy", "mace bonk")
    eq(Figures.death_style("n", "b"), "fall")
end)

-- Game flow ------------------------------------------------------------------------------------------------

test("a new game sets up 32 figures and waits for White", function()
    local game = new_game()
    eq(#game:actors(), 32)
    eq(game:position():turn(), "w")
    assert(game:can_act(), "human can act")
    assert(not game:is_thinking())
    eq(game:status_segments()[1].text, "Your move (White)")
    local a = game:actor_at(sq("e1"))
    eq(a.kind, "k"); eq(a.side, "w")
    eq(game:actor_at(sq("d8")).kind, "q")
end)

test("selecting shows legal destinations; illegal clicks do nothing", function()
    local game = new_game()
    assert(game:activate(sq("e2")), "select pawn")
    eq(game:selected(), sq("e2"))
    eq(game:target_count(), 2)
    assert(game:targets()[sq("e3")] and game:targets()[sq("e4")])
    assert(not game:activate(sq("e5")), "illegal target ignored")
    eq(game:selected(), sq("e2"), "selection kept")
    assert(not game:activate(sq("d7")), "enemy piece cannot be selected")
    eq(game:position():history_size(), 0)
    assert(game:activate(sq("g1")), "switch to knight")
    eq(game:target_count(), 2)
    assert(game:activate(sq("g1")), "clicking the selected piece again")
    eq(game:selected(), nil, "deselected")
    assert(game:activate(sq("b1")))
    assert(game:ui_back(), "Esc deselects first")
    eq(game:selected(), nil)
    assert(not game:ui_back(), "then Esc leaves the game")
end)

test("a move walks the figure and the computer answers via update()", function()
    local game = new_game()
    game:drain_events(function() end)
    game:activate(sq("e2"))
    assert(game:activate(sq("e4")), "move")
    eq(game:position():piece_at(sq("e4")), "P")
    assert(game:in_sequence(), "walk animation running")
    assert(game:is_thinking(), "computer thinks during the animation")
    eq(game:actor_at(sq("e4")).kind, "p", "logical board updated at once")
    local moved = false
    for _ = 1, 30 do
        game:update(1 / 60)
        local a = game:actor_at(sq("e4"))
        if a.z > -2.5 then moved = true end
    end
    assert(moved, "the pawn is walking")
    assert(run_until(game, function() return game:position():history_size() == 2 and idle(game) end, 40), "computer replied")
    eq(game:position():turn(), "w")
    assert(game:can_act())
    eq(#game:actors(), 32)
    local a = game:actor_at(sq("e4"))
    near(a.x, 0.5, 1e-9); near(a.z, -0.5, 1e-9)
    assert(game:status_segments()[2].text:find("^Last: 1%.%.%. "), "last move shown in SAN: " .. game:status_segments()[2].text)
end)

test("the computer plays the first move when you play Black", function()
    local game, store = new_game({ battlechess_black = true })
    eq(game:human_side(), "b")
    assert(game:is_thinking(), "white (computer) thinks at once")
    assert(not game:can_act())
    assert(run_until(game, function() return game:position():history_size() == 1 and idle(game) end, 30))
    eq(game:position():turn(), "b")
    assert(game:can_act())
    assert(math.abs(math.abs(game:user_camera().yaw) - math.pi) < 1e-6, "camera looks from Black's side")
end)

test("captures play a battle that can be skipped", function()
    local game = new_game()
    load_fen(game, "4k3/8/8/6b1/8/5N2/8/4K3 w - - 0 1")
    game:drain_events(function() end)
    assert(game:try_move(sq("f3"), sq("g5")), "Nxg5")
    local kinds = {}
    local saw_battle, saw_hit = false, false
    for _ = 1, 60 * 3 do
        game:update(1 / 60)
        if game:battle() then saw_battle = true end
        for _, k in ipairs(events(game)) do
            if k == "hit" then saw_hit = true end
            kinds[#kinds + 1] = k
        end
        if saw_hit then break end
    end
    assert(saw_battle, "battle camera engaged")
    assert(saw_hit, "the blow landed")
    assert(game:in_sequence())
    assert(game:camera().dist < 6, "camera closed in")
    game:key_press("confirm")
    assert(not game:in_sequence(), "Space skips to the end")
    eq(game:battle(), nil)
    eq(#game:actors(), 2 + 1, "victim removed")
    local a = game:actor_at(sq("g5"))
    eq(a.kind, "n")
    near(a.x, 2.5, 1e-9); near(a.z, 0.5, 1e-9)
end)

test("Esc or a right click during a battle skips it instead of leaving", function()
    local game = new_game({ battlechess_two = true })
    load_fen(game, "4k3/pp6/8/6b1/8/5N2/PP6/4K3 w - - 0 1")
    game:try_move(sq("f3"), sq("g5"))
    assert(run_until(game, function() return game:battle() ~= nil end, 5))
    assert(game:ui_back(), "Esc handled")
    assert(not game:in_sequence(), "skipped")
    eq(game:shell():dialog(), nil, "no game over here")
    load_fen(game, "4k3/pp6/8/6b1/8/5N2/PP6/4K3 w - - 0 1")
    game:try_move(sq("f3"), sq("g5"))
    assert(run_until(game, function() return game:battle() ~= nil end, 5))
    local c = game:layout().client
    local x, y = c.x + 50, c.y + 50
    game:pointer_input(x, y, { right = true, right_pressed = true })
    game:pointer_input(x, y, { right_released = true })
    assert(not game:in_sequence(), "right click skipped")
end)

test("a full battle finishes on its own in a few seconds", function()
    for _, case in ipairs({
        { "4k3/8/q7/8/8/8/8/R3K3 w - - 0 1", "a1", "a6", "sparkle" },
        { "4k3/r7/8/8/8/8/8/Q3K3 w - - 0 1", "a1", "a7", "crumble" },
        { "4k3/8/8/3p4/8/8/8/3QK3 w - - 0 1", "d1", "d5", "ash" },
        { "4k3/8/8/6n1/8/8/8/2B1K3 w - - 0 1", "c1", "g5", "dizzy" },
        { "4k3/8/8/8/n7/8/8/R3K3 w - - 0 1", "a1", "a4", "squash" },
        { "4k3/8/8/8/8/8/4p3/4K3 w - - 0 1", "e1", "e2", "fall" },
    }) do
        local game = new_game({ battlechess_two = true })
        load_fen(game, case[1])
        assert(game:try_move(sq(case[2]), sq(case[3])), "move " .. case[2] .. case[3])
        local style
        local t = 0
        local battle_time = 0
        while game:in_sequence() and t < 12 do
            game:update(1 / 60)
            t = t + 1 / 60
            if game:battle() then battle_time = battle_time + 1 / 60 end
            game:drain_events(function(ev) if ev.kind == "hit" then style = ev.s:match("^(%a+)") end end)
        end
        eq(style, case[4], "death style for " .. case[2] .. case[3])
        assert(not game:in_sequence(), "sequence ended")
        assert(battle_time >= 2.5 and battle_time <= 4.5, "battle lasted " .. battle_time)
        eq(game:actor_at(sq(case[3])).kind, game:position():piece_at(sq(case[3])):lower())
        local pieces = 0
        for s = 0, 63 do if game:position():piece_at(s) then pieces = pieces + 1 end end
        eq(#game:actors(), pieces, "one figure per piece")
    end
end)

test("with battle animations off a capture is instant with a burst", function()
    local game, store = new_game({ battlechess_two = true })
    game:_command("anims")
    eq(store.battlechess_anims, false, "persisted")
    load_fen(game, "4k3/8/8/6b1/8/5N2/8/4K3 w - - 0 1")
    game:drain_events(function() end)
    game:try_move(sq("f3"), sq("g5"))
    local list = {}
    local battle = false
    for _ = 1, 180 do
        game:update(1 / 60)
        if game:battle() then battle = true end
        for _, k in ipairs(events(game)) do list[#list + 1] = k end
    end
    assert(not battle, "no battle")
    assert(has(list, "poof"), "small burst")
    assert(not game:in_sequence())
    eq(#game:actors(), 3)
end)

test("promotion asks for the piece in a Win95 dialog", function()
    local game = new_game({ battlechess_two = true })
    load_fen(game, "8/1P3k2/8/8/8/8/5K2/8 w - - 0 1")
    game:activate(sq("b7"))
    game:activate(sq("b8"))
    local d = game:shell():dialog()
    assert(d and d.kind == "promote", "promotion dialog")
    eq(d.values.piece, "q", "queen preselected")
    game:key_press("right")
    eq(d.values.piece, "r", "arrow keys move through the radios")
    game:key_press("right"); game:key_press("right")
    eq(d.values.piece, "n")
    assert(game:ui_back(), "Esc cancels")
    eq(game:position():piece_at(sq("b7")), "P", "no move on cancel")
    eq(game:selected(), sq("b7"), "the pawn stays selected")
    game:activate(sq("b8"))
    d = game:shell():dialog()
    d.values.piece = "n"
    game:_dialog_button(d, "ok")
    game:shell():close_dialog()
    eq(game:position():piece_at(sq("b8")), "N", "promoted to a knight")
    assert(run_until(game, function() return not game:in_sequence() end, 10))
    eq(game:actor_at(sq("b8")).kind, "n", "figure changed too")
end)

test("undo takes back the last move pair against the computer", function()
    local game = new_game()
    assert(not game:can_undo())
    game:try_move(sq("d2"), sq("d4"))
    assert(game:can_undo(), "undo while the computer thinks")
    assert(game:undo())
    eq(game:position():history_size(), 0)
    assert(not game:is_thinking(), "search cancelled")
    eq(game:position():piece_at(sq("d2")), "P")
    eq(game:actor_at(sq("d2")).kind, "p")
    game:try_move(sq("d2"), sq("d4"))
    assert(run_until(game, function() return game:position():history_size() == 2 and idle(game) end, 30))
    game:key_press("undo")
    eq(game:position():history_size(), 0, "both plies taken back")
    eq(game:position():turn(), "w")
    eq(#game:actors(), 32)
end)

test("two players: the camera turns to the side to move", function()
    local game = new_game({ battlechess_two = true })
    game:try_move(sq("e2"), sq("e4"))
    assert(run_until(game, function() return not game:in_sequence() end, 5))
    near(math.abs(game:user_camera().yaw), math.pi, 1e-9, "Black's view")
    game:try_move(sq("e7"), sq("e5"))
    game:skip()
    near(game:user_camera().yaw, 0, 1e-9, "back to White")
    game:rotate_camera(1.2, 0)
    game:try_move(sq("g1"), sq("f3"))
    game:skip()
    near(game:user_camera().yaw, 1.2, 1e-9, "a free camera is left alone")
end)

test("undo in two-player mode takes back one move", function()
    local game = new_game({ battlechess_two = true })
    game:try_move(sq("e2"), sq("e4"))
    game:skip()
    game:try_move(sq("e7"), sq("e5"))
    game:skip()
    game:undo()
    eq(game:position():history_size(), 1)
    eq(game:position():turn(), "b")
end)

test("checkmate topples the king, shows the result and counts the win", function()
    local game, store, sounds = new_game()
    load_fen(game, "6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1")
    assert(game:try_move(sq("a1"), sq("a8")))
    assert(not game:is_thinking(), "no search after mate")
    assert(run_until(game, function() local d = game:shell():dialog(); return d and d.kind == "over" end, 15), "game over dialog")
    eq(game:result_text(), "Checkmate! White wins.")
    eq(game:wins(), 1)
    eq(store.battlechess_highscore, 1, "wins persisted")
    assert(has(sounds, "win"))
    local king = game:actor_at(sq("g8"))
    eq(king.anim, "topple", "the losing king lies on the ground")
    eq(game:status_segments()[1].text, "Checkmate! White wins.")
    assert(not game:can_act())
    game:key_press("new")
    eq(game:position():history_size(), 0, "R starts a new game")
    eq(game:shell():dialog(), nil)
end)

test("losing to the computer does not count as a win", function()
    local game, store, sounds = new_game()
    load_fen(game, "6k1/8/8/8/8/8/r4PPP/6K1 b - - 0 1")
    assert(game:is_thinking(), "the computer is to move")
    game._job = nil
    game._ai_move = game:position():find_move(sq("a2"), sq("a1"))
    assert(game._ai_move, "Ra1#")
    assert(run_until(game, function() local d = game:shell():dialog(); return d and d.kind == "over" end, 15))
    eq(game:result_text(), "Checkmate! Black wins.")
    eq(game:wins(), 0)
    eq(store.battlechess_highscore, nil)
    assert(has(sounds, "lose"))
end)

test("stalemate is a draw", function()
    local game = new_game({ battlechess_two = true })
    load_fen(game, "7k/8/6Q1/8/8/8/8/K7 w - - 0 1")
    game:try_move(sq("g6"), sq("f7"))
    assert(run_until(game, function() return game:shell():dialog() ~= nil end, 10))
    eq(game:result_text(), "Stalemate. The game is a draw.")
end)

test("castling walks the king and then the rook around it", function()
    local game = new_game({ battlechess_two = true })
    load_fen(game, "4k3/8/8/8/8/8/8/4K2R w K - 0 1")
    assert(game:try_move(sq("e1"), sq("g1")))
    local rook = game:actor_at(sq("f1"))
    eq(rook.kind, "r")
    local min_z = 0
    assert(run_until(game, function()
        min_z = math.min(min_z, rook.z)
        return not game:in_sequence()
    end, 10))
    assert(min_z < -3.8, "rook stepped behind the king")
    near(rook.x, 1.5, 1e-9)
    near(rook.z, -3.5, 1e-9)
    eq(game:actor_at(sq("g1")).kind, "k")
end)

test("en passant: the captured pawn beside the square falls", function()
    local game = new_game({ battlechess_two = true })
    load_fen(game, "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2")
    assert(game:try_move(sq("e5"), sq("d6")))
    assert(run_until(game, function() return not game:in_sequence() end, 12))
    eq(game:position():piece_at(sq("d5")), nil)
    eq(game:actor_at(sq("d5")), nil)
    eq(#game:actors(), 3)
end)

test("the keyboard cursor moves relative to the camera", function()
    local game = new_game()
    run(game, 1)
    game:key_press("up")
    local c0 = game:cursor()
    game:key_press("up")
    eq(game:cursor(), c0 + 8, "up goes away from the viewer (towards Black)")
    game:key_press("right")
    eq(game:cursor(), c0 + 9)
    game:set_camera_preset("cam_black")
    run(game, 3)
    local c1 = game:cursor()
    game:key_press("up")
    eq(game:cursor(), c1 - 8, "seen from Black, up goes towards White")
    game:key_press("right")
    eq(game:cursor(), c1 - 9)
end)

test("keyboard play: cursor and Space select and move", function()
    local game = new_game()
    run(game, 0.5)
    game:key_press("confirm")
    local _, visible = game:cursor()
    assert(visible, "first Space shows the cursor")
    game._cursor = sq("g1")
    game:key_press("confirm")
    eq(game:selected(), sq("g1"))
    game._cursor = sq("f3")
    game:key_press("confirm")
    eq(game:position():piece_at(sq("f3")), "N")
end)

test("camera orbit is clamped and presets cycle", function()
    local game = new_game()
    game:rotate_camera(0, 10)
    near(game:user_camera().pitch, Game.PITCH_MAX, 1e-9)
    game:rotate_camera(0, -10)
    near(game:user_camera().pitch, Game.PITCH_MIN, 1e-9)
    for _ = 1, 30 do game:key_press("1") end
    near(game:user_camera().dist, Game.DIST_MIN, 1e-9)
    for _ = 1, 30 do game:key_press("2") end
    near(game:user_camera().dist, Game.DIST_MAX, 1e-9)
    game:key_press("4")
    near(game:user_camera().yaw, 0, 1e-9)
    game:key_press("alt")
    near(math.abs(game:user_camera().yaw), math.pi, 1e-9, "E: black side")
    game:key_press("alt"); game:key_press("alt")
    near(game:user_camera().yaw, math.pi / 2, 1e-9, "side view")
    game:key_hold("fast", true)
    local yaw = game:user_camera().yaw
    game:key_press("left")
    assert(math.abs(game:user_camera().yaw - yaw) > 0.1, "Shift+arrow rotates")
    game:key_hold("fast", false)
    run(game, 3)
    near(game:camera().yaw, game:user_camera().yaw, 1e-3, "camera eases to the target")
end)

test("right-drag rotates the camera, a right click deselects", function()
    local game = new_game()
    run(game, 1)
    local c = game:layout().client
    local x, y = c.x + c.w / 2, c.y + c.h / 2
    game:activate(sq("e2"))
    local yaw = game:user_camera().yaw
    game:pointer_input(x, y, { right = true, right_pressed = true })
    for i = 1, 10 do game:pointer_input(x + i * 8, y + i * 3, { right = true }) end
    game:pointer_input(x + 80, y + 30, { right_released = true })
    assert(math.abs(game:user_camera().yaw - yaw) > 0.3, "dragged yaw")
    eq(game:selected(), sq("e2"), "a drag keeps the selection")
    game:pointer_input(x, y, { right = true, right_pressed = true })
    game:pointer_input(x, y, { right_released = true })
    eq(game:selected(), nil, "right click deselects")
end)

test("picking maps the pointer to the right square from many angles", function()
    local game = new_game()
    local cam_yaws = { 0, math.pi, 0.7, -1.9, math.pi / 2 }
    local pitches = { Game.PITCH_MIN, 0.7, Game.PITCH_MAX }
    for _, yaw in ipairs(cam_yaws) do
        for _, pitch in ipairs(pitches) do
            local u = game:user_camera()
            u.yaw, u.pitch, u.dist = yaw, pitch, 13
            game._cam_goal = nil
            game:_snap_camera()
            run(game, 0.1)
            for s = 0, 63 do
                local sx, sy = screen_of(game, s)
                eq(game:square_at(sx, sy), s, string.format("square %d at yaw %.2f pitch %.2f", s, yaw, pitch))
                -- corners of the square's projected quad map back to it too
                local x, z = Game.sq_xz(s)
                local qx, qy = game:camera():project(x + 0.4, 0, z - 0.4)
                eq(game:square_at(qx, qy), s)
            end
        end
    end
    -- clicking a figure's head picks its square even when the head overlaps another square
    game:reset_camera()
    run(game, 3)
    local hx, hy = screen_of(game, sq("d1"), Figures.HEIGHT.q * 0.8)
    eq(game:pick(hx, hy), sq("d1"), "queen's head")
    assert(game:square_at(hx, hy) ~= sq("d1"), "the head is drawn over another square")
    local c = game:layout().client
    eq(game:pick(c.x + 2, c.y + 2), nil, "hall, not the board")
end)

test("mouse play through the shell: click a piece, then a square", function()
    local game = new_game()
    run(game, 3)
    local x, y = screen_of(game, sq("b1"), 0.4)
    game:pointer_input(x, y, { left = true, left_pressed = true })
    game:pointer_input(x, y, {})
    eq(game:selected(), sq("b1"))
    x, y = screen_of(game, sq("c3"))
    game:pointer_input(x, y, { left = true, left_pressed = true })
    game:pointer_input(x, y, {})
    eq(game:position():piece_at(sq("c3")), "N")
    -- a click during the animation skips it
    game:pointer_input(x, y, { left = true, left_pressed = true })
    game:pointer_input(x, y, {})
    assert(not game:in_sequence())
end)

test("menus, options and dialogs", function()
    local game, store = new_game()
    game:key_press("menu")
    eq(game:shell():menu(), 1, "Tab opens the Game menu")
    game:key_press("menu")
    eq(game:shell():menu(), nil)
    game:_command("difficulty")
    local d = game:shell():dialog()
    eq(d.kind, "difficulty")
    d.values.level = 7
    game:_dialog_button(d, "ok")
    game:shell():close_dialog()
    eq(game:level(), 7)
    eq(store.battlechess_level, 7)
    game:_command("two")
    assert(game:two_players())
    eq(store.battlechess_two, true)
    game:_command("two")
    game:_command("black")
    eq(store.battlechess_black, true)
    assert(game:is_thinking(), "new game as Black: the computer moves first")
    game:_command("how_to")
    eq(game:shell():dialog().kind, "how_to")
    assert(game:ui_back())
    game:_command("about")
    eq(game:shell():dialog().kind, "about")
    game:key_press("confirm")
    eq(game:shell():dialog(), nil, "Space closes the about box")
    game:_command("zoom_in")
    game:_command("cam_side")
    game:_command("reset_camera")
    assert(not game:consume_close_request())
    game:_command("exit")
    assert(game:consume_close_request(), "Exit closes the window")
    assert(not game:consume_close_request(), "only once")
    assert(not game:is_game_over())
end)

test("settings are restored from the options", function()
    local game = new_game({ battlechess_level = 9, battlechess_anims = false, battlechess_two = true, battlechess_highscore = 4 })
    eq(game:level(), 9)
    eq(game:animations(), false)
    assert(game:two_players())
    eq(game:wins(), 4)
    assert(game:summary():find("^%[Battle Chess%] Moves: 0"), game:summary())
    assert(game:summary():find("Wins: 4"))
end)

test("random play for many frames never breaks (fuzz)", function()
    math.randomseed(11)
    local game = new_game()
    local c = game:layout().client
    local keys = { "left", "right", "up", "down", "confirm", "alt", "undo", "1", "2", "3", "4", "menu" }
    local held = {}
    local played = 0
    local max_history = 0
    game:_command("anims")
    for frame = 1, 6000 do
        if frame == 3000 then game:_command("anims") end
        max_history = math.max(max_history, game:position():history_size())
        local r = math.random()
        local input = {}
        if r < 0.05 then input.left, input.left_pressed = true, true
        elseif r < 0.07 then input.right, input.right_pressed = true, true end
        local x = c.x + math.random() * c.w
        local y = c.y - 40 + math.random() * (c.h + 60)
        if math.random() < 0.03 then
            -- aim at one of our own pieces or a legal target now and then
            local s = math.random(0, 63)
            local sx, sy = screen_of(game, s)
            if sx then x, y = sx, sy end
        end
        game:pointer_input(x, y, input)
        if math.random() < 0.03 then game:key_press(keys[math.random(#keys)], math.random() < 0.2) end
        if math.random() < 0.01 then
            local k = ({ "fast", "left", "confirm" })[math.random(3)]
            held[k] = not held[k]
            game:key_hold(k, held[k])
        end
        if math.random() < 0.0015 then game:key_press("new") end
        if game:can_act() and math.random() < 0.08 then
            -- play a random legal move with the mouse
            local moves = game:position():legal_moves()
            if #moves > 0 then
                local m = moves[math.random(#moves)]
                local fx, fy = screen_of(game, m.from, 0.1)
                local tx, ty = screen_of(game, m.to)
                if fx and tx then
                    game:pointer_input(fx, fy, { left = true, left_pressed = true })
                    game:pointer_input(fx, fy, {})
                    game:pointer_input(tx, ty, { left = true, left_pressed = true })
                    game:pointer_input(tx, ty, {})
                    local d = game:shell():dialog()
                    if d and d.kind == "promote" then game:key_press(math.random() < 0.5 and "confirm" or "right") end
                    played = played + 1
                end
            end
        end
        if game:shell():dialog() and math.random() < 0.05 then game:ui_back() end
        game:update(1 / 60)
        local cam = game:camera()
        assert(cam.yaw == cam.yaw and cam.pitch == cam.pitch and cam.dist == cam.dist, "camera finite")
        for _, a in ipairs(game:actors()) do
            assert(a.x == a.x and a.z == a.z, "actor position finite")
        end
    end
    if os.getenv("FUZZ_VERBOSE") then print("fuzz", played, max_history, game:position():fen()) end
    assert(max_history >= 20, "the fuzz actually played: " .. max_history)
end)

-- 2D board ---------------------------------------------------------------------------------------------

local function center2d(game, square)
    local b = game:layout().board2d
    local file, rank = square % 8, math.floor(square / 8)
    local col, row
    if game:board_flipped() then col, row = 7 - file, rank else col, row = file, 7 - rank end
    return b.x + (col + 0.5) * b.sq, b.y + (row + 0.5) * b.sq
end

test("3D is the default; View > 2D Board switches and persists", function()
    local game, store = new_game()
    eq(game:board2d(), false, "3D by default")
    game:_command("board2d")
    eq(game:board2d(), true)
    eq(store.battlechess_2d, true, "persisted")
    local again = new_game({ battlechess_2d = true })
    eq(again:board2d(), true, "restored")
    again:_command("board3d")
    eq(again:board2d(), false)
end)

test("2D picking maps the pointer to squares in both orientations", function()
    local game = new_game({ battlechess_2d = true })
    for _, name in ipairs({ "a1", "h1", "e4", "d5", "a8", "h8" }) do
        local x, y = center2d(game, sq(name))
        eq(game:square_at(x, y), sq(name), name)
    end
    game:rotate_view()
    eq(game:board_flipped(), true, "3 flips the 2D board")
    for _, name in ipairs({ "a1", "h8", "c6" }) do
        local x, y = center2d(game, sq(name))
        eq(game:square_at(x, y), sq(name), "flipped " .. name)
    end
    local black = new_game({ battlechess_2d = true, battlechess_black = true })
    eq(black:board_flipped(), true, "Black plays from the bottom")
end)

test("2D moves glide and captures skip the battle", function()
    local game = new_game({ battlechess_2d = true, battlechess_level = 1 })
    game._two_players = true
    load_fen(game, "4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1")
    events(game)
    assert(game:try_move(sq("e4"), sq("d5")))
    local ok = run_until(game, function() return not game:in_sequence() end, 2)
    assert(ok, "capture finished quickly")
    local list = events(game)
    assert(not has(list, "battle"), "no battle on the flat board")
    assert(has(list, "poof"), "capture burst")
    eq(game:position():piece_at(sq("d5")), "P")
end)

test("2D drag and drop plays a move", function()
    local game = new_game({ battlechess_2d = true })
    local x0, y0 = center2d(game, sq("e2"))
    local x1, y1 = center2d(game, sq("e4"))
    game:pointer_input(x0, y0, { left = true, left_pressed = true })
    eq(game:selected(), sq("e2"))
    game:pointer_input((x0 + x1) / 2, (y0 + y1) / 2, { left = true })
    assert(game:drag_piece() == sq("e2"), "dragging")
    game:pointer_input(x1, y1, { left = false, left_released = true })
    eq(game:position():piece_at(sq("e4")), "P", "move played on release")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
