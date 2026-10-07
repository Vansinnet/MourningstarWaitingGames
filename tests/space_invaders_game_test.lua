-- Run from workspace root: lua-5.5.0_Win64_bin/lua55.exe mods/active/MourningstarWaitingGames/tests/space_invaders_game_test.lua
local Game = dofile("mods/active/MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/SpaceInvaders_game.lua")
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

local function equal(a, b, path)
    path = path or "state"
    assert(type(a) == type(b), path .. " type differs")
    if type(a) == "number" then
        assert(math.abs(a - b) < 1e-7, path .. ": " .. a .. " ~= " .. b)
    elseif type(a) == "table" then
        for key, value in pairs(a) do equal(value, b[key], path .. "." .. tostring(key)) end
        for key in pairs(b) do assert(a[key] ~= nil, path .. " unexpected " .. tostring(key)) end
    else
        assert(a == b, path .. " differs")
    end
end

local function playing(quiet)
    local game = Game:new()
    game:update(66 / 60)
    assert(game:is_playing(), "startup did not finish")
    if quiet then game._alien_fire_delay = 100000 end
    return game
end

local function player_shot(game, x, y)
    game._player_bullet = { x = x, y = y, py = y, w = 4, h = 14 }
end

local function enemy_shot(game, kind, x, y, dy)
    local bullet = { x = x, y = y, w = 5, h = 14, kind = kind, dy = dy or 0 }
    game._slots[kind].bullet, game._slots[kind].steps = bullet, 1
    game._enemy_bullets[#game._enemy_bullets + 1] = bullet
end

local function slots_valid(game)
    local entities, kinds = game:entities(), {}
    assert(#entities.player_bullets <= 1, "multiple player shots")
    assert(#entities.enemy_bullets <= 3, "more than three enemy shots")
    for _, bullet in ipairs(entities.enemy_bullets) do
        assert(bullet.kind >= 1 and bullet.kind <= 3 and not kinds[bullet.kind], "invalid/duplicate enemy kind")
        assert(game._slots[bullet.kind].bullet == bullet, "enemy shot lost slot ownership")
        kinds[bullet.kind] = true
    end
    for kind = 1, 3 do
        assert((game._slots[kind].bullet ~= nil) == (kinds[kind] == true), "orphaned slot")
    end
    assert(not ((game._mystery_active or game._mystery_hit_ticks > 0) and kinds[3]), "saucer shares kind 3")
end

local function snapshot(game)
    return {
        entities = game:entities(), score = game:score(), lives = game:lives(), wave = game:wave(),
        state = game:state(), time = game:time(), slots = game._slots,
        pointer = game._saucer_score_index, cleaned = game._shots_cleaned,
        mystery_timer = game._mystery_timer, mystery_hit = game._mystery_hit_ticks,
        cleanup = game._shot_cleanup_ticks, cursor = game._march_cursor,
    }
end

test("30/60/144 fps: movement, fire edges and active combat", function()
    local games = {}
    for _, fps in ipairs({ 30, 60, 144 }) do
        local game = playing()
        local checkpoints = {}
        -- Half-second boundaries align at every rate; input precedes its frame update.
        for segment = 1, 24 do
            for frame = 1, fps / 2 do
                if segment % 2 == 1 then game:move_left(1 / fps) else game:move_right(1 / fps) end
                if frame == 1 then game:fire() end
                game:update(1 / fps)
                slots_valid(game)
            end
            -- Snapshots contain live tables, so compare each checkpoint immediately below.
            checkpoints[segment] = snapshot(game)
            if fps ~= 30 then equal(checkpoints[segment], games[30][segment], "fps " .. fps .. " segment " .. segment) end
            -- Freeze the baseline without depending on a serializer or platform library.
            local function copy(value)
                if type(value) ~= "table" then return value end
                local result = {}
                for key, item in pairs(value) do result[key] = copy(item) end
                return result
            end
            checkpoints[segment] = copy(checkpoints[segment])
        end
        games[fps] = checkpoints
    end
end)

test("55-tick sequential bottom-left march", function()
    local game = playing(true)
    local original, moved = {}, {}
    for i, enemy in ipairs(game._enemies) do original[i] = enemy.x end
    for tick = 1, 55 do
        game:update(1 / 60)
        local expected = (4 - math.floor((tick - 1) / 11)) * 11 + (tick - 1) % 11 + 1
        local changed = 0
        for i, enemy in ipairs(game._enemies) do
            if enemy.x ~= original[i] and not moved[i] then
                assert(i == expected, "wrong march order at tick " .. tick)
                equal(enemy.x - original[i], 5.75, "march distance")
                moved[i], changed = true, changed + 1
            end
        end
        assert(changed == 1, "march must move exactly one new alien per tick")
    end
    game:update(1 / 60)
    equal(game._enemies[45].x - original[45], 11.5, "second pass")
end)

test("one player shot; busy edges discarded, misses clean up once", function()
    local game = playing(true)
    game._shields = {}
    game:fire(); game:update(1 / 144)
    assert(#game:entities().player_bullets == 0, "subtick fired early")
    game:update(2 / 144)
    assert(#game:entities().player_bullets == 1, "accepted edge must create exactly one shot")
    local bullet = game._player_bullet
    game:fire(); game:update(1 / 60)
    assert(game._player_bullet == bullet and game._saucer_score_index == 1, "busy edge replaced shot/advanced score")
    bullet.x, bullet.y = 16, 19
    game:update(1 / 60)
    assert(not game._player_bullet and game._saucer_score_index == 1, "miss skips cleanup delay")
    game:update(16 / 60)
    assert(game._saucer_score_index == 2, "miss not counted exactly once")
    game:update(1)
    assert(not game._player_bullet and game._saucer_score_index == 2, "stale edge/autofire")
end)

test("three distinct enemy slots and saucer ownership", function()
    local game = playing()
    game._alien_fire_delay, game._slots[1].skip = 0, false
    for kind = 1, 3 do
        for other = 1, kind - 1 do game._slots[other].steps = 100 end
        game:_enemy_shoot(kind)
        game:_enemy_shoot(kind)
    end
    assert(#game._enemy_bullets == 3, "three available kinds should fire")
    slots_valid(game)
    game._mystery_pending = true
    game:_move_mystery(3)
    assert(not game._mystery_active, "saucer spawned over kind 3")
    game:_remove_enemy_bullet(3)
    for _ = 1, 4 do game:_enemy_shoot(3) end
    game:_move_mystery(3)
    assert(game._mystery_active, "released kind 3 did not permit saucer")
    for _ = 1, 12 do game:update(1 / 60); slots_valid(game) end
    game._shields = {}
    player_shot(game, game._mystery_x + 10, 64)
    game:_move_bullets()
    assert(game._mystery_hit_ticks > 0, "saucer hit fixture missed")
    for _ = 1, 90 do game:update(1 / 60); slots_valid(game) end
end)

test("opposing shots intercept without score or player damage", function()
    local game = playing(true)
    game._shields = {}
    player_shot(game, 100, 330)
    enemy_shot(game, 1, 100, 300, 12.5)
    game:_move_bullets()
    assert(not game._player_bullet and #game._enemy_bullets == 0, "shots passed through each other")
    assert(game:score() == 0 and game:lives() == 3, "intercept damaged/scored")
    slots_valid(game)
end)

test("shield first surface, grazing and maximum-speed traversal", function()
    for _, upward in ipairs({ true, false }) do
        local game = playing(true)
        game._shields = {
            { x = 100, y = 370, w = 6, h = 6, alive = true },
            { x = 100, y = 400, w = 6, h = 6, alive = true },
        }
        if upward then player_shot(game, 102, 410) else enemy_shot(game, 1, 95.01, 347, 12.5) end
        game:_move_bullets()
        assert(game._shields[upward and 1 or 2].alive, "removed shield beyond first surface")
        assert(not game._shields[upward and 2 or 1].alive, "missed struck tile")
        assert(not game._player_bullet and #game._enemy_bullets == 0, "shot survived shield")
        assert(game._alive_count == 55 and game:score() == 0, "shield hit changed aliens/score")
    end
end)

test("march overruns bunker but preserves distant tiles", function()
    local game = playing(true)
    game._shields = {
        { x = 62, y = 265, w = 6, h = 6, alive = true },
        { x = 400, y = 405, w = 6, h = 6, alive = true },
    }
    game._ref_y = 260
    game:update(1 / 60)
    assert(not game._shields[1].alive and game._shields[2].alive, "incorrect bunker overrun")
end)

test("saucer scoring cycle includes misses and delayed 300 award", function()
    local game = playing(true)
    game._shields = {}
    for _ = 1, 7 do
        player_shot(game, 16, 19)
        game:update(17 / 60)
    end
    assert(game._saucer_score_index == 8 and game:score() == 0, "miss sequence")
    game._mystery_active, game._mystery_x = true, 100
    player_shot(game, 110, 64)
    game:_move_bullets()
    assert(game._saucer_score_index == 9 and game:score() == 0, "hit must advance pointer before delayed award")
    for _ = 1, 8 do game:_move_mystery(3) end
    assert(game:score() == 300, "eighth shot should award 300")
    for _ = 1, 15 do
        player_shot(game, 16, 19)
        game:update(17 / 60)
    end
    assert(game._saucer_score_index == 9 and game:score() == 300, "15-entry wrap/duplicate award")
end)

test("wave starts repeat after eight; clear transition preserves score and bonus", function()
    local game = playing(true)
    game:_add_score(1500)
    local starts = { 120, 96, 80, 72, 72, 72, 64, 64, 64, 96, 80, 72, 72, 72, 64, 64, 64 }
    for wave, height in ipairs(starts) do
        assert(game:wave() == wave and game._alive_count == 55, "wave population/index")
        equal(game._enemies[1].y, 82 + (120 - height) * 2.5, "wave " .. wave .. " height")
        assert(game._saucer_score_index == 1, "new wave did not reset scoring cycle")
        if wave < #starts then
            for _, enemy in ipairs(game._enemies) do enemy.alive = false end
            local last = game._enemies[1]
            last.alive, game._alive_count, game._shields = true, 1, {}
            player_shot(game, last.x, last.y + 22)
            enemy_shot(game, 1, 400, 520)
            game:_move_bullets()
            assert(game:state() == "wave", "last kill did not enter wave transition")
            slots_valid(game)
            assert(not game._player_bullet and #game._enemy_bullets == 0, "wave retained projectiles")
            local x = game._player_x
            game:move_left(82 / 60); game:fire(); game:update(82 / 60)
            assert(game:is_playing() and not game._player_bullet, "wave retained fire input")
            equal(game._player_x, x - 2.875, "held movement during wave's playable remainder")
            assert(game:score() == 1500 + wave * 30 and game:lives() == 4 and game._bonus_awarded, "wave lost score/bonus")
        end
    end
end)

test("death clears queued fire but keeps held movement; bonus once and restart", function()
    local game = playing(true)
    game:_add_score(1490)
    assert(game:lives() == 3 and not game._bonus_awarded, "early bonus")
    game:_add_score(10)
    assert(game:lives() == 4 and game._bonus_awarded, "missing threshold bonus")
    game:move_right(1 / 144); game:fire(); game:update(1 / 144)
    game:_kill_player()
    game:move_left(73 / 60); game:fire(); game:update(73 / 60)
    assert(game:is_playing() and game:lives() == 3 and game:score() == 1500, "death lost persistent state")
    equal(game._player_x, 278.125, "held movement during respawn's playable remainder")
    assert(not game._player_bullet, "death retained queued fire")
    game:_add_score(1500)
    assert(game:lives() == 3, "bonus awarded twice")
    game._lives = 1
    game:_kill_player(); game:update(72 / 60)
    assert(game:is_game_over() and game:lives() == 0, "last death did not end game")
    local time = game:time()
    game:fire(); game:move_right(1); game:update(1)
    equal(game:time(), time, "game over continued simulation")
    game._mystery_hit_ticks = 32
    game:start()
    equal(snapshot(game), snapshot(Game:new()), "restart")
    assert(not game._bonus_awarded, "restart retained bonus")
    game:update(67 / 60)
    assert(game:is_playing() and not game._player_bullet and game:score() == 0, "restart leaked pending input/award")
end)

test("startup/respawn/wave: held movement across one remaining transition tick", function()
    for _, state in ipairs({ "idle", "dying", "wave" }) do
        local games = {}
        for _, frames in ipairs({ 1, 2 }) do
            local game = state == "idle" and Game:new() or playing(true)
            if state ~= "idle" then
                game:fire()
                if state == "dying" then game:_kill_player() else game:_clear_transients() end
            end
            game._state, game._state_ticks = state, 1
            for _ = 1, frames do
                local dt = 2 / 60 / frames
                game:move_right(dt)
                game:update(dt)
            end
            equal(game._player_x, 283.875, state .. " playable movement")
            assert(game:is_playing() and not game._player_bullet, state .. " stale fire replayed")
            games[frames] = snapshot(game)
        end
        equal(games[1], games[2], state .. " batch vs split")
    end
end)

test("invasion settles pending UFO bonus but leaves zero lives", function()
    local game = playing(true)
    game._score, game._saucer_score_index, game._mystery_hit_ticks = 1400, 1, 32
    game._ref_y = 478
    game:update(1 / 60)
    assert(game:score() == 1500 and game._bonus_awarded, "pending UFO award lost")
    assert(game:is_game_over() and game:lives() == 0 and not game:entities().player, "bonus revived invaded player")
    assert(game._mystery_hit_ticks == 0, "pending award survived invasion")
    game:update(1)
    assert(game:score() == 1500 and game:lives() == 0, "invasion award repeated")
end)

for _, alien_first in ipairs({ true, false }) do
    test("exact first contact: " .. (alien_first and "alien before intercept" or "intercept before alien"), function()
        local game = playing(true)
        game._shields = {}
        local alien_time, intercept_time = 0.505, 0.515
        if not alien_first then alien_time, intercept_time = intercept_time, alien_time end
        local alien = game._enemies[1]
        -- Both events fall in the old 0.52 substep, only 0.1 px of player travel apart.
        alien.x, alien.y = 100, 330 - 22 - 10 * alien_time
        player_shot(game, 100, 330)
        enemy_shot(game, 1, 100, 330 - 14 - 22.5 * intercept_time, 12.5)
        game:_move_bullets()
        assert(alien.alive == not alien_first, "wrong earliest target")
        assert(game:score() == (alien_first and 30 or 0), "wrong first-contact score")
        assert(#game._enemy_bullets == (alien_first and 1 or 0), "wrong intercept outcome")
        assert(not game._player_bullet and game:lives() == 3, "shot survived/damaged player")
        slots_valid(game)
    end)
end

test("earlier shield destruction opens the later projectile's path", function()
    local game = playing(true)
    game._shields = { { x = 100, y = 400, w = 6, h = 6, alive = true } }
    -- Enemy hits at t=0.2; player would hit the same tile at t=0.5.
    enemy_shot(game, 1, 100, 383.5, 12.5)
    player_shot(game, 102, 411)
    game:_move_bullets()
    assert(not game._shields[1].alive and #game._enemy_bullets == 0, "first shot did not destroy shield")
    assert(game._player_bullet, "later shot hit already destroyed shield")
    equal(game._player_bullet.y, 401, "later shot must finish its full travel")
    slots_valid(game)
end)

for _, death_first in ipairs({ true, false }) do
    test("chronological transition: " .. (death_first and "death before last alien" or "last alien before death"), function()
        local game = playing(true)
        game._shields = {}
        for _, enemy in ipairs(game._enemies) do enemy.alive = false end
        local last = game._enemies[1]
        local death_time, alien_time = 0.505, 0.515
        if not death_first then death_time, alien_time = alien_time, death_time end
        last.alive, last.x, last.y, game._alive_count = true, 100, 330 - 22 - 10 * alien_time, 1
        player_shot(game, 100, 330)
        enemy_shot(game, 1, game._player_x, 546 - 14 - 12.5 * death_time, 12.5)
        game:_move_bullets()
        assert(game:state() == (death_first and "dying" or "wave"), "later impact won transition")
        assert(last.alive == death_first and game:score() == (death_first and 0 or 30), "later alien kill was applied/lost")
        assert(game:lives() == (death_first and 2 or 3), "later player death was applied/lost")
        assert(not game._player_bullet and #game._enemy_bullets == 0, "transition retained shots")
        slots_valid(game)
    end)
end

print(string.format("%d scenarios passed; %d failed", passed, failed))
if failed > 0 then os.exit(1) end
