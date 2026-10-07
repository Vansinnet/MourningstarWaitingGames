-- Run: lua5.1 solitaire_game_test.lua [mod_dir]   (also runs under luajit)
local DIR = arg and arg[1] or "/mnt/user-data/outputs/mwg/"
if DIR:sub(-1) ~= "/" then DIR = DIR .. "/" end
get_mod = function()
    return { io_dofile = function(_, p) return dofile(DIR .. p:match("([^/]+)$") .. ".lua") end }
end
local Game = dofile(DIR .. "Solitaire_game.lua")
local passed, failed = 0, 0

local function test(name, run)
    math.randomseed(1234)
    local ok, err = pcall(run)
    if ok then
        passed = passed + 1
        print("PASS: " .. name)
    else
        failed = failed + 1
        print("FAIL: " .. name .. ": " .. tostring(err))
    end
end

local STOCK, WASTE, F1, T1 = 1, 2, 3, 7
local CLUBS, DIAMONDS, HEARTS, SPADES = 1, 2, 3, 4

local function card(suit, rank) return (suit - 1) * 13 + rank end

local function new_game(settings)
    local store = settings or {}
    local sounds = {}
    local game = Game:new({
        get = function(key) return store[key] end,
        set = function(key, value) store[key] = value end,
        on_sound = function(kind) sounds[#sounds + 1] = kind end,
    })
    game:start()
    game:drain_events(function() end)
    return game, store, sounds
end

-- Replaces the table with a fixed layout. spec[pile] = { { card, face_up }, ... }; unlisted cards go to the stock.
local function setup(game, spec)
    local used = {}
    for p = 1, 13 do
        local pile = game:pile(p)
        for i = #pile, 1, -1 do pile[i] = nil end
    end
    for p, list in pairs(spec) do
        local pile = game:pile(p)
        for i = 1, #list do
            pile[i] = list[i][1]
            game._up[list[i][1]] = list[i][2] and true or false
            used[list[i][1]] = true
        end
    end
    if not spec[STOCK] then
        local stock = game:pile(STOCK)
        for c = 1, 52 do
            if not used[c] then
                stock[#stock + 1] = c
                game._up[c] = false
            end
        end
    end
    game._waste_fan = math.min(3, #game:pile(WASTE))
    game._undo = nil
    game:_relayout()
    game:drain_events(function() end)
end

local function fill_foundation(game, f, suit, top_rank, spec)
    spec[f] = {}
    for r = 1, top_rank do spec[f][r] = { card(suit, r), true } end
end

local function events(game)
    local list = {}
    game:drain_events(function(kind, a, b, c, d) list[#list + 1] = { kind = kind, a = a, b = b, c = c, d = d } end)
    return list
end

local function has_event(list, kind)
    for i = 1, #list do if list[i].kind == kind then return list[i] end end
end

local function spot(game, c)
    local x, y = game:card_position(c)
    return x + 30, y + 8
end

local function press(game, x, y) game:pointer_input(x, y, { left = true, left_pressed = true }) end
local function hold(game, x, y) game:pointer_input(x, y, { left = true }) end
local function release(game, x, y) game:pointer_input(x, y, { left = false, left_released = true }) end
local function click(game, x, y)
    press(game, x, y)
    release(game, x, y)
end
local function right_click(game, x, y)
    game:pointer_input(x, y, { right = true, right_pressed = true })
    game:pointer_input(x, y, { right = false, right_released = true })
end
local function drag(game, x1, y1, x2, y2)
    press(game, x1, y1)
    for k = 1, 5 do hold(game, x1 + (x2 - x1) * k / 5, y1 + (y2 - y1) * k / 5) end
    release(game, x2, y2)
end

local function count_cards(game)
    local seen, n = {}, 0
    for p = 1, 13 do
        local pile = game:pile(p)
        for i = 1, #pile do
            assert(not seen[pile[i]], "duplicate card " .. pile[i])
            seen[pile[i]] = true
            n = n + 1
        end
    end
    return n
end

local function rank(c) return (c - 1) % 13 + 1 end
local function suit(c) return math.floor((c - 1) / 13) + 1 end
local function red(c) return suit(c) == 2 or suit(c) == 3 end

local function check_invariants(game, label)
    assert(count_cards(game) == 52, label .. ": card count")
    for f = F1, F1 + 3 do
        local pile = game:pile(f)
        for i = 1, #pile do
            assert(rank(pile[i]) == i and suit(pile[i]) == suit(pile[1]), label .. ": foundation order")
        end
    end
    for p = T1, 13 do
        local pile = game:pile(p)
        local seen_up = false
        for i = 1, #pile do
            local up = game:is_face_up(pile[i])
            if seen_up then assert(up, label .. ": face-down card above a face-up one") end
            if up and seen_up then
                local below = pile[i - 1]
                assert(rank(pile[i]) == rank(below) - 1 and red(pile[i]) ~= red(below), label .. ": tableau run order")
            end
            seen_up = seen_up or up
        end
    end
    for _, c in ipairs(game:pile(STOCK)) do assert(not game:is_face_up(c), label .. ": stock face up") end
    for _, c in ipairs(game:pile(WASTE)) do assert(game:is_face_up(c), label .. ": waste face down") end
    if game:scoring() == "standard" then assert(game:score() >= 0, label .. ": negative score") end
end

-- Deal --------------------------------------------------------------------------------------

test("deal lays out Klondike: 1..7 cards, top face up, 24 in stock", function()
    local game = new_game()
    for c = 1, 7 do
        local pile = game:pile(T1 + c - 1)
        assert(#pile == c, "column " .. c .. " has " .. #pile)
        for i = 1, c do
            assert(game:is_face_up(pile[i]) == (i == c), "only the top card is face up")
        end
    end
    assert(#game:pile(STOCK) == 24 and #game:pile(WASTE) == 0)
    for f = F1, F1 + 3 do assert(#game:pile(f) == 0) end
    assert(count_cards(game) == 52)
    check_invariants(game, "deal")
end)

test("defaults match Windows 95: Draw Three, Standard, timed, status bar", function()
    local game = new_game()
    assert(game:draw_count() == 3 and game:scoring() == "standard" and game:timed() and game:status_bar())
    assert(not game:outline_dragging() and not game:keep_score() and game:back() == "blue")
    assert(game:score() == 0 and game:status() == "playing" and not game:is_game_over())
end)

test("settings are read back from the options", function()
    local game = new_game({ solitaire_draw = 1, solitaire_scoring = "vegas", solitaire_timed = false,
        solitaire_status_bar = false, solitaire_outline = true, solitaire_back = "robot" })
    assert(game:draw_count() == 1 and game:scoring() == "vegas" and not game:timed())
    assert(not game:status_bar() and game:outline_dragging() and game:back() == "robot")
    assert(game:shell():layout().status == nil, "no status bar")
    assert(game:score() == -52)
end)

-- Rules ------------------------------------------------------------------------------------------

test("tableau builds down in alternating colours", function()
    local game = new_game()
    setup(game, {
        [T1] = { { card(SPADES, 8), true } },
        [T1 + 1] = { { card(HEARTS, 7), true } },
        [T1 + 2] = { { card(CLUBS, 7), true } },
        [T1 + 3] = { { card(HEARTS, 6), true } },
    })
    assert(game:can_move(T1 + 1, 1, T1), "red 7 on black 8")
    assert(not game:can_move(T1 + 2, 1, T1), "black 7 on black 8")
    assert(not game:can_move(T1 + 3, 1, T1), "6 on 8")
    assert(game:can_move(T1 + 3, 1, T1 + 2), "red 6 on black 7")
    assert(game:move(T1 + 1, 1, T1))
    assert(#game:pile(T1) == 2 and #game:pile(T1 + 1) == 0)
end)

test("only a King or a run from a King fills an empty column", function()
    local game = new_game()
    setup(game, {
        [T1] = {},
        [T1 + 1] = { { card(HEARTS, 12), true } },
        [T1 + 2] = { { card(CLUBS, 2), false }, { card(SPADES, 13), true }, { card(HEARTS, 12), true } },
    })
    game:pile(T1 + 1)[1] = card(DIAMONDS, 12)
    game._up[card(DIAMONDS, 12)] = true
    game:_relayout()
    assert(not game:can_move(T1 + 1, 1, T1), "queen may not fill")
    assert(game:can_move(T1 + 2, 2, T1), "king run may fill")
    assert(game:move(T1 + 2, 2, T1))
    assert(#game:pile(T1) == 2 and game:pile(T1)[1] == card(SPADES, 13))
end)

test("face-down cards are never picked up and not turned automatically", function()
    local game = new_game()
    setup(game, {
        [T1] = { { card(CLUBS, 5), false }, { card(HEARTS, 9), true } },
        [T1 + 1] = { { card(SPADES, 10), true } },
    })
    assert(not game:can_move(T1, 1, T1 + 1), "face-down card cannot move")
    assert(game:move(T1, 2, T1 + 1))
    assert(not game:is_face_up(card(CLUBS, 5)), "stays face down until clicked")
    local before = game:score()
    assert(game:flip(T1))
    assert(game:is_face_up(card(CLUBS, 5)) and game:score() == before + 5, "turning over scores +5")
    assert(not game:flip(T1), "already face up")
end)

test("foundations build up by suit from the Ace", function()
    local game = new_game()
    setup(game, {
        [T1] = { { card(HEARTS, 2), true } },
        [T1 + 1] = { { card(HEARTS, 1), true } },
        [T1 + 2] = { { card(SPADES, 2), true } },
    })
    assert(not game:can_move(T1, 1, F1), "two on an empty stack")
    assert(game:send_to_foundation(T1 + 1))
    assert(#game:pile(F1) == 1)
    assert(not game:can_move(T1 + 2, 1, F1), "wrong suit")
    assert(game:send_to_foundation(T1))
    assert(#game:pile(F1) == 2 and game:pile(F1)[2] == card(HEARTS, 2))
end)

test("runs move to the foundation one card at a time only", function()
    local game = new_game()
    setup(game, {
        [F1] = { { card(CLUBS, 1), true } },
        [T1] = { { card(DIAMONDS, 3), true }, { card(CLUBS, 2), true } },
    })
    assert(not game:can_move(T1, 1, F1), "a run cannot go up")
    assert(game:can_move(T1, 2, F1))
end)

test("foundation cards can come back to the table but not to another stack", function()
    local game = new_game()
    local spec = { [T1] = { { card(SPADES, 4), true } }, [F1 + 1] = {} }
    fill_foundation(game, F1, HEARTS, 3, spec)
    setup(game, spec)
    assert(game:can_move(F1, 3, T1), "3 of hearts on 4 of spades")
    assert(not game:can_move(F1, 2, T1), "only the top card")
    setup(game, { [F1] = { { card(CLUBS, 1), true } } })
    assert(not game:can_move(F1, 1, F1 + 1), "ace between stacks")
end)

-- Stock ------------------------------------------------------------------------------------------

test("Draw Three deals three to a fanned waste, Draw One deals one", function()
    local game = new_game()
    assert(game:stock_click())
    assert(#game:pile(WASTE) == 3 and #game:pile(STOCK) == 21 and game:waste_fan() == 3)
    local waste = game:pile(WASTE)
    local x1 = game:card_position(waste[1])
    local x3 = game:card_position(waste[3])
    assert(x3 > x1, "top three fanned")
    for _, c in ipairs(waste) do assert(game:is_face_up(c)) end

    local g1 = new_game({ solitaire_draw = 1 })
    g1:stock_click()
    assert(#g1:pile(WASTE) == 1 and #g1:pile(STOCK) == 23)
end)

test("playing the top waste card shrinks the fan", function()
    local game = new_game()
    setup(game, {
        [STOCK] = { { card(CLUBS, 9), false }, { card(CLUBS, 3), false }, { card(HEARTS, 12), false } },
        [T1] = { { card(SPADES, 13), true } },
        [WASTE] = {},
    })
    game:stock_click()
    assert(game:pile(WASTE)[3] == card(CLUBS, 9), "stock top is dealt first, last dealt on top")
    game:pile(WASTE)[3], game:pile(WASTE)[1] = game:pile(WASTE)[1], game:pile(WASTE)[3]
    game:_relayout()
    assert(game:move(WASTE, 3, T1), "queen of hearts onto king of spades")
    assert(game:waste_fan() == 2)
end)

test("an empty stock turns the waste over in its original order", function()
    local game = new_game()
    local order = {}
    for i = 1, 8 do game:stock_click() end
    for i, c in ipairs(game:pile(WASTE)) do order[i] = c end
    assert(#game:pile(STOCK) == 0)
    assert(game:stock_click(), "recycle")
    assert(#game:pile(WASTE) == 0 and #game:pile(STOCK) == 24)
    game:stock_click()
    local waste = game:pile(WASTE)
    assert(waste[1] == order[1] and waste[3] == order[3], "same cards come round again")
end)

test("Standard recycle costs 100 in Draw One and 20 in Draw Three, never below zero", function()
    local game = new_game()
    game._score = 150
    for _ = 1, 8 do game:stock_click() end
    game:stock_click()
    assert(game:score() == 130, "draw three: -20, got " .. game:score())

    local g1 = new_game({ solitaire_draw = 1 })
    g1._score = 150
    for _ = 1, 24 do g1:stock_click() end
    g1:stock_click()
    assert(g1:score() == 50, "draw one: -100")
    for _ = 1, 24 do g1:stock_click() end
    g1:stock_click()
    assert(g1:score() == 0, "never below zero")
    assert(g1:stock_mark() == nil)
end)

test("Vegas: -$52 per deal, +$5 per card home, pass limits and the cross", function()
    local game = new_game({ solitaire_scoring = "vegas" })
    assert(game:score() == -52)
    assert(game:passes_left() == 2)
    for round = 1, 2 do
        for _ = 1, 8 do game:stock_click() end
        assert(game:stock_click(), "recycle " .. round)
    end
    for _ = 1, 8 do game:stock_click() end
    assert(game:stock_mark() == "empty", "no passes left shows a cross")
    assert(not game:stock_click(), "third recycle refused")
    assert(game:score() == -52, "no recycle penalty in Vegas")

    local g1 = new_game({ solitaire_scoring = "vegas", solitaire_draw = 1 })
    for _ = 1, 24 do g1:stock_click() end
    assert(g1:stock_mark() == "empty" and not g1:stock_click(), "Draw One: a single pass")

    setup(game, { [T1] = { { card(CLUBS, 1), true } }, [T1 + 1] = { { card(HEARTS, 3), true } } })
    assert(game:send_to_foundation(T1))
    assert(game:score() == -47, "+5 per card, got " .. game:score())
    setup(game, { [F1] = { { card(DIAMONDS, 1), true }, { card(DIAMONDS, 2), true } }, [T1] = { { card(SPADES, 3), true } } })
    game._score = -47
    assert(game:move(F1, 2, T1))
    assert(game:score() == -52, "-5 taking a card back")
end)

test("Keep score makes Vegas cumulative across deals and persists it", function()
    local game, store = new_game({ solitaire_scoring = "vegas", solitaire_keep_score = true, solitaire_vegas_score = 30 })
    assert(game:score() == -22, "carried $30 minus $52, got " .. game:score())
    assert(store.solitaire_vegas_score == -22, "persisted immediately")
    setup(game, { [T1] = { { card(CLUBS, 1), true } } })
    game:send_to_foundation(T1)
    assert(store.solitaire_vegas_score == -17)
    game:deal()
    assert(game:score() == -69 and store.solitaire_vegas_score == -69)

    local plain = new_game({ solitaire_scoring = "vegas", solitaire_vegas_score = 30 })
    plain:deal()
    assert(plain:score() == -52, "without Keep score every deal starts at -$52")
end)

-- Standard scoring --------------------------------------------------------------------------------

test("Standard scoring table", function()
    local game = new_game()
    setup(game, {
        [WASTE] = { { card(HEARTS, 1), true }, { card(DIAMONDS, 9), true } },
        [T1] = { { card(CLUBS, 10), true } },
        [T1 + 1] = { { card(SPADES, 1), true } },
        [T1 + 2] = { { card(CLUBS, 5), false }, { card(CLUBS, 3), true } },
    })
    game._waste_fan = 2
    assert(game:move(WASTE, 2, T1) and game:score() == 5, "waste to tableau +5")
    assert(game:send_to_foundation(WASTE) and game:score() == 15, "waste to foundation +10")
    assert(game:send_to_foundation(T1 + 1) and game:score() == 25, "tableau to foundation +10")
    setup(game, { [F1] = { { card(HEARTS, 1), true }, { card(HEARTS, 2), true } }, [T1] = { { card(SPADES, 3), true } } })
    game._score = 25
    assert(game:move(F1, 2, T1) and game:score() == 10, "foundation to tableau -15")
    assert(game:move(T1, 2, F1) and game:score() == 20, "and back up +10")
    game._score = 5
    setup(game, { [F1] = { { card(HEARTS, 1), true }, { card(HEARTS, 2), true } }, [T1] = { { card(SPADES, 3), true } } })
    game._score = 5
    game:move(F1, 2, T1)
    assert(game:score() == 0, "clamped at zero")
end)

test("None scoring shows no score", function()
    local game = new_game({ solitaire_scoring = "none" })
    setup(game, { [T1] = { { card(CLUBS, 1), true } } })
    game:send_to_foundation(T1)
    assert(game:score() == 0 and game:score_text() == nil)
    assert(game:summary():find("Cards home: 1/52"))
end)

test("Timed game loses 2 points every 10 seconds once play starts", function()
    local game = new_game()
    game:update(30)
    assert(game:time_value() == 0, "timer waits for the first move")
    game._score = 100
    game:stock_click()
    game:update(9.5)
    assert(game:score() == 100)
    game:update(0.6)
    assert(game:score() == 98 and game:time_value() == 10)
    game:update(25)
    assert(game:score() == 94)
    game._score = 1
    game:update(10)
    assert(game:score() == 0, "not below zero")

    local untimed = new_game({ solitaire_timed = false })
    untimed._score = 50
    untimed:stock_click()
    untimed:update(60)
    assert(untimed:score() == 50, "no penalty when untimed")
end)

test("the timer pauses while a dialog is open", function()
    local game = new_game()
    game:stock_click()
    game:update(5)
    game:_command("about")
    game:update(20)
    assert(game:time_value() == 5)
    game:ui_back()
    game:update(1)
    assert(game:time_value() == 6)
end)

-- Winning -------------------------------------------------------------------------------------------

local function near_win(game)
    local spec = {}
    for f = 0, 3 do fill_foundation(game, F1 + f, f + 1, 12, spec) end
    for s = 1, 4 do spec[T1 + s - 1] = { { card(s, 13), true } } end
    setup(game, spec)
end

test("win: time bonus 700000 / seconds at 30 seconds or more", function()
    local game, store, sounds = new_game()
    near_win(game)
    game._score = 400
    assert(game:send_to_foundation(T1), "the first move starts the clock")
    game:update(100)
    assert(game:score() == 390, "ten 10-second penalties")
    for s = 2, 4 do assert(game:send_to_foundation(T1 + s - 1)) end
    assert(game:status() == "won" and game:is_won())
    assert(game:bonus() == 7000, "700000 / 100 = 7000, got " .. game:bonus())
    assert(game:score() == 390 + 30 + 7000)
    assert(store.solitaire_highscore == 7420, "best standard score persisted")
    assert(game:new_best())
    assert(sounds[#sounds] == "win")
    local ev = events(game)
    assert(has_event(ev, "win").a == 7000)

    local quick = new_game()
    near_win(quick)
    quick:send_to_foundation(T1)
    quick:update(29)
    for s = 2, 4 do quick:send_to_foundation(T1 + s - 1) end
    assert(quick:status() == "won" and quick:bonus() == 0, "no bonus under 30 seconds")
end)

test("highscore only rises and only for Standard wins", function()
    local game, store = new_game({ solitaire_highscore = 99999 })
    near_win(game)
    for s = 1, 4 do game:send_to_foundation(T1 + s - 1) end
    assert(store.solitaire_highscore == 99999 and not game:new_best())

    local vegas, vstore = new_game({ solitaire_scoring = "vegas" })
    near_win(vegas)
    for s = 1, 4 do vegas:send_to_foundation(T1 + s - 1) end
    assert(vegas:status() == "won" and vstore.solitaire_highscore == nil)
end)

test("the bouncing cascade launches kings first and ends with Deal Again", function()
    local game = new_game()
    near_win(game)
    for s = 1, 4 do game:send_to_foundation(T1 + s - 1) end
    local c = game:cascade()
    assert(c and not c.done)
    assert(not game:can_undo(), "no undo after a win")
    game:update(1)
    local launched = {}
    local guard = 0
    while game:cascade() and not game:cascade().done and guard < 20000 do
        game:update(1 / 30)
        game:drain_events(function(kind, a) if kind == "launch" then launched[#launched + 1] = a end end)
        guard = guard + 1
        assert(c.stamp_count <= c.cap, "trail is capped")
    end
    assert(#launched == 52, "every card flies, got " .. #launched)
    assert(rank(launched[1]) == 13 and rank(launched[4]) == 13 and rank(launched[5]) == 12, "kings first")
    assert(suit(launched[1]) ~= suit(launched[2]), "cycles through the stacks")
    local d = game:shell():dialog()
    assert(d and d.kind == "again", "Deal Again? dialog")
    game:key_press("confirm")
    assert(game:status() == "playing" and #game:pile(STOCK) == 24, "Yes deals again")
end)

test("a dialog opened during the cascade pauses it", function()
    local game = new_game()
    near_win(game)
    for s = 1, 4 do game:send_to_foundation(T1 + s - 1) end
    game:update(1)
    game:_command("options")
    for _ = 1, 3000 do game:update(0.1) end
    assert(game:shell():dialog().kind == "options", "options dialog survives")
    assert(not game:cascade().done)
    game:ui_back()
    game:update(0.1)
    assert(game:cascade().launched > 0)
end)

test("any key or click skips the cascade; No keeps the finished table", function()
    local game = new_game()
    near_win(game)
    for s = 1, 4 do game:send_to_foundation(T1 + s - 1) end
    game:update(2)
    game:key_press("left")
    assert(game:cascade().done and game:shell():dialog().kind == "again")
    assert(not game:card_hidden(card(CLUBS, 13)), "cards return to the stacks")
    game:ui_back()
    assert(game:shell():dialog() == nil and game:cascade() == nil)
    assert(game:status() == "won" and game:foundation_count() == 52, "No leaves the won table")

    local g2 = new_game()
    near_win(g2)
    for s = 1, 4 do g2:send_to_foundation(T1 + s - 1) end
    g2:update(2)
    local L = g2:layout()
    click(g2, L.client.x + 100, L.client.y + 300)
    assert(g2:cascade().done, "a click skips too")
    local D = g2:shell():layout().dialog
    click(g2, D.buttons[1].rect.x + 5, D.buttons[1].rect.y + 5)
    assert(g2:status() == "playing", "clicking Yes deals")
end)

-- Undo ---------------------------------------------------------------------------------------------

test("undo restores cards, faces and score; one level only", function()
    local game = new_game()
    assert(not game:can_undo())
    local undo_item = game:shell():menus()[1].items[3]
    assert(undo_item.id == "undo" and not game:shell():item_enabled(undo_item), "menu item disabled")
    setup(game, {
        [T1] = { { card(CLUBS, 4), false }, { card(HEARTS, 1), true } },
        [T1 + 1] = { { card(SPADES, 9), true } },
    })
    assert(game:send_to_foundation(T1) and game:score() == 10)
    assert(game:shell():item_enabled(undo_item))
    assert(game:flip(T1) and game:score() == 15)
    assert(game:undo())
    assert(not game:is_face_up(card(CLUBS, 4)) and game:score() == 10, "flip undone")
    assert(not game:undo(), "only one level")
    assert(#game:pile(F1) == 1)
end)

test("undo reverts a stock recycle and its penalty", function()
    local game = new_game({ solitaire_draw = 1 })
    game._score = 300
    for _ = 1, 24 do game:stock_click() end
    game:stock_click()
    assert(game:score() == 200)
    game:undo()
    assert(game:score() == 300 and #game:pile(WASTE) == 24 and #game:pile(STOCK) == 0)
end)

test("Q undoes and R deals from the keyboard", function()
    local game = new_game()
    game:stock_click()
    game:key_press("undo")
    assert(#game:pile(WASTE) == 0 and #game:pile(STOCK) == 24)
    local first = game:pile(T1)[1]
    game:key_press("new")
    assert(#game:pile(STOCK) == 24 and has_event(events(game), "deal"))
end)

-- Mouse --------------------------------------------------------------------------------------------

test("clicking the stock deals and clicking a face-down top card turns it", function()
    local game = new_game()
    local r = game:layout().piles[STOCK]
    click(game, r.x + 20, r.y + 20)
    assert(#game:pile(WASTE) == 3)
    setup(game, { [T1] = { { card(CLUBS, 4), false } } })
    local x, y = spot(game, card(CLUBS, 4))
    click(game, x, y)
    assert(game:is_face_up(card(CLUBS, 4)))
end)

test("drag and drop moves a run; an illegal drop returns it", function()
    local game = new_game()
    setup(game, {
        [T1] = { { card(CLUBS, 2), false }, { card(HEARTS, 9), true }, { card(SPADES, 8), true } },
        [T1 + 2] = { { card(CLUBS, 10), true } },
        [T1 + 4] = { { card(DIAMONDS, 10), true } },
    })
    local x, y = spot(game, card(HEARTS, 9))
    local tx, ty = game:card_position(card(DIAMONDS, 10))
    drag(game, x, y, tx + 30, ty + 30)
    assert(#game:pile(T1) == 3, "red 9 on red 10 refused")
    assert(has_event(events(game), "return"))
    tx, ty = game:card_position(card(CLUBS, 10))
    press(game, x, y)
    hold(game, x + 50, y + 20)
    local d = game:drag()
    assert(d and d.active and d.index == 2, "dragging the run")
    hold(game, tx + 30, ty + 30)
    assert(game:drag().target == T1 + 2, "hover target found")
    assert(game:is_legal_target(T1 + 2) and not game:is_legal_target(T1 + 4))
    release(game, tx + 30, ty + 30)
    assert(#game:pile(T1) == 1 and #game:pile(T1 + 2) == 3, "run moved")
    assert(game:drag() == nil)
end)

test("the grab offset is preserved while dragging", function()
    local game = new_game()
    setup(game, { [T1] = { { card(HEARTS, 9), true } } })
    local cx, cy = game:card_position(card(HEARTS, 9))
    press(game, cx + 12, cy + 40)
    hold(game, cx + 112, cy + 90)
    local d = game:drag()
    assert(d.x == cx + 100 and d.y == cy + 50)
end)

test("click a card, then click its destination", function()
    local game = new_game()
    setup(game, {
        [T1] = { { card(HEARTS, 9), true } },
        [T1 + 3] = { { card(SPADES, 10), true } },
    })
    local x, y = spot(game, card(HEARTS, 9))
    click(game, x, y)
    local p, i = game:selection()
    assert(p == T1 and i == 1, "selected")
    game:update(1)
    local tx, ty = spot(game, card(SPADES, 10))
    click(game, tx, ty)
    assert(#game:pile(T1 + 3) == 2 and game:selection() == nil)

    click(game, tx, ty + 17)
    assert(game:selection() == T1 + 3)
    game:update(1)
    click(game, tx, ty + 17)
    assert(game:selection() == nil, "clicking it again deselects")
end)

test("double-click sends a card to its suit stack", function()
    local game = new_game()
    setup(game, { [T1] = { { card(CLUBS, 7), true }, { card(HEARTS, 1), false } } })
    local x, y = spot(game, card(HEARTS, 1))
    click(game, x, y)
    assert(game:is_face_up(card(HEARTS, 1)), "first click turns it")
    game:update(0.2)
    click(game, x, y)
    assert(#game:pile(F1) == 1, "second click (double) sends it up")

    setup(game, { [T1] = { { card(HEARTS, 2), true } }, [F1] = { { card(HEARTS, 1), true } } })
    x, y = spot(game, card(HEARTS, 2))
    game:update(1)
    click(game, x, y)
    game:update(0.8)
    click(game, x, y)
    assert(#game:pile(F1) == 1, "too slow is not a double-click")
    game:update(0.1)
    click(game, x, y)
    assert(#game:pile(F1) == 2)
end)

test("right-click plays every possible card, one after another", function()
    local game = new_game()
    setup(game, {
        [T1] = { { card(CLUBS, 1), true } },
        [T1 + 1] = { { card(CLUBS, 3), true }, { card(CLUBS, 2), true } },
        [WASTE] = { { card(HEARTS, 1), true } },
        [T1 + 2] = { { card(SPADES, 5), false } },
    })
    game._score = 0
    local L = game:layout()
    local sounds = {}
    game._options.on_sound = function(kind) sounds[#sounds + 1] = kind end
    right_click(game, L.client.x + 300, L.client.y + 400)
    game:update(0)
    assert(game:foundation_count() == 1, "first card goes at once")
    for _ = 1, 20 do game:update(0.05) end
    assert(game:foundation_count() == 4, "all four eventually, got " .. game:foundation_count())
    assert(not game:is_face_up(card(SPADES, 5)), "does not turn cards")
    assert(game:score() == 40)
    assert(#sounds == 1, "one blip for the whole chain")
    game:undo()
    assert(game:foundation_count() == 0 and game:score() == 0, "undo reverts the whole autoplay")
end)

test("pointer over the menu bar opens menus instead of touching cards", function()
    local game = new_game()
    local r = game:shell():layout().menu_titles[1]
    click(game, r.x + 5, r.y + 5)
    assert(game:shell():menu() == 1)
    local items = game:shell():layout().menu_items
    click(game, items[#items].rect.x + 10, items[#items].rect.y + 5)
    assert(game:consume_close_request(), "Exit")
    assert(not game:consume_close_request(), "only once")
end)

test("the window close button requests close", function()
    local game = new_game()
    local cb = game:shell():layout().close_button
    click(game, cb.x + 4, cb.y + 4)
    assert(game:consume_close_request())
end)

-- Keyboard -----------------------------------------------------------------------------------------

test("keyboard cursor walks the table", function()
    local game = new_game()
    assert(game:cursor() == T1)
    game:key_press("left")
    assert(game:cursor() == 13, "wraps to column 7")
    game:key_press("up")
    assert(game:cursor() == F1 + 3, "above column 7 is the last suit stack")
    game:key_press("right")
    assert(game:cursor() == STOCK, "top row wraps")
    game:key_press("right")
    assert(game:cursor() == WASTE)
    game:key_press("right")
    assert(game:cursor() == F1, "skips the gap")
    game:key_press("down")
    assert(game:cursor() == T1 + 3)
    assert(game:cursor_mode() == "keys")
end)

test("confirm deals from the stock, turns cards, picks up and drops", function()
    local game = new_game()
    setup(game, {
        [T1] = { { card(CLUBS, 4), false } },
        [T1 + 1] = { { card(HEARTS, 9), true } },
        [T1 + 2] = { { card(SPADES, 10), true } },
    })
    game:key_press("confirm")
    assert(game:is_face_up(card(CLUBS, 4)), "turned")
    game:key_press("right")
    game:key_press("confirm")
    assert(game:selection() == T1 + 1)
    game:key_press("left")
    game:key_press("confirm")
    assert(game:selection() == nil and #game:pile(T1 + 1) == 1, "illegal drop returns")
    assert(has_event(events(game), "invalid"))
    game:key_press("right")
    game:key_press("confirm")
    game:key_press("right")
    game:key_press("confirm")
    assert(#game:pile(T1 + 2) == 2, "dropped on the ten")
    game:key_press("up")
    game:key_press("up")
    game:key_press("up")
    assert(game:cursor() == WASTE)
    game:key_press("left")
    game:key_press("confirm")
    assert(#game:pile(WASTE) == 3, "confirm on the stock deals")
end)

test("up and down on a column choose how many cards to pick up", function()
    local game = new_game()
    setup(game, {
        [T1] = { { card(CLUBS, 5), false }, { card(HEARTS, 10), true }, { card(SPADES, 9), true }, { card(DIAMONDS, 8), true } },
        [T1 + 1] = { { card(CLUBS, 11), true } },
    })
    game:key_press("up")
    game:key_press("up")
    local p, depth = game:cursor()
    assert(p == T1 and depth == 3)
    game:key_press("up")
    assert(game:cursor() == STOCK, "past the run goes to the top row")
    game:key_press("down")
    game:key_press("up")
    game:key_press("up")
    game:key_press("down")
    p, depth = game:cursor()
    assert(depth == 2)
    game:key_press("up")
    game:key_press("confirm")
    local sp, si = game:selection()
    assert(sp == T1 and si == 2, "picked the whole run")
    game:key_press("right")
    game:key_press("confirm")
    assert(#game:pile(T1 + 1) == 4 and #game:pile(T1) == 1)
end)

test("E sends the card under the cursor (or the held card) to its stack", function()
    local game = new_game()
    setup(game, {
        [T1] = { { card(HEARTS, 1), true } },
        [WASTE] = { { card(SPADES, 1), true } },
        [T1 + 1] = { { card(CLUBS, 1), true } },
    })
    game:key_press("alt")
    assert(game:foundation_count() == 1)
    game:key_press("up")
    game:key_press("alt")
    assert(game:foundation_count() == 2, "stock position means the waste")
    game:key_press("down")
    game:key_press("right")
    game:key_press("confirm")
    assert(game:selection() == T1 + 1)
    game:key_press("alt")
    assert(game:foundation_count() == 3 and game:selection() == nil)
end)

test("Tab opens the Game menu and keys drive it", function()
    local game = new_game()
    game:key_press("menu")
    assert(game:shell():menu() == 1 and game:shell():menu_hover() == 1)
    game:key_press("down")
    assert(game:shell():menu_hover() == 4, "skips the separator and the disabled Undo")
    game:key_press("down")
    game:key_press("confirm")
    assert(game:shell():dialog().kind == "options")
    game:key_press("new")
    assert(game:shell():dialog().kind == "options", "R is ignored under a dialog")
    game:ui_back()
    game:key_press("menu")
    game:key_press("new")
    assert(game:shell():menu() == nil, "R closes the menu and deals")
end)

-- Dialogs -------------------------------------------------------------------------------------------

test("Options: changing Draw deals a new game and everything persists", function()
    local game, store = new_game()
    game:stock_click()
    game:_command("options")
    local d = game:shell():dialog()
    assert(d.kind == "options" and d.values.draw == 3 and d.values.scoring == "standard")
    local D = game:shell():layout().dialog
    local keep
    for i = 1, #D.controls do if D.controls[i].spec.id == "keep" then keep = D.controls[i].spec end end
    assert(not game:shell():control_enabled(keep), "Keep score disabled outside Vegas")
    d.values.scoring = "vegas"
    assert(game:shell():control_enabled(keep), "enabled with Vegas")
    d.values.scoring = "standard"
    d.values.draw = 1
    d.values.timed = false
    d.values.outline = true
    game:key_press("down")
    for _ = 1, 20 do
        local kind, index = game:shell():dialog_focus()
        if kind == "button" and D.buttons[index].spec.id == "ok" then break end
        game:key_press("down")
    end
    game:key_press("confirm")
    assert(game:shell():dialog() == nil)
    assert(game:draw_count() == 1 and #game:pile(WASTE) == 0, "new deal")
    assert(store.solitaire_draw == 1 and store.solitaire_timed == false and store.solitaire_outline == true)
    assert(store.solitaire_scoring == "standard")
end)

test("Options: toggling only the status bar keeps the game and moves no cards", function()
    local game, store = new_game()
    game:stock_click()
    local c = game:pile(T1)[1]
    local x, y = game:card_position(c)
    game:_command("options")
    game:shell():dialog().values.status = false
    game:_dialog_result(game:shell():dialog(), "ok")
    assert(#game:pile(WASTE) == 3, "same game")
    assert(store.solitaire_status_bar == false and game:shell():layout().status == nil)
    local x2, y2 = game:card_position(c)
    assert(x == x2 and y == y2)
end)

test("Options: Cancel changes nothing", function()
    local game, store = new_game()
    game:_command("options")
    game:shell():dialog().values.draw = 1
    game:ui_back()
    assert(game:draw_count() == 3 and store.solitaire_draw == nil)
end)

test("Options: switching to Vegas with Keep score starts the tally at -$52", function()
    local game, store = new_game()
    game._score = 500
    game:_command("options")
    local v = game:shell():dialog().values
    v.scoring, v.keep = "vegas", true
    game:_dialog_result(game:shell():dialog(), "ok")
    assert(game:scoring() == "vegas" and game:score() == -52, "got " .. game:score())
    assert(store.solitaire_vegas_score == -52 and store.solitaire_keep_score == true)
end)

test("Deck: choosing a back by click and by keys persists it", function()
    local game, store = new_game()
    game:_command("deck")
    local d = game:shell():dialog()
    assert(d.kind == "deck" and d.values.back == "blue")
    local D = game:shell():layout().dialog
    assert(#D.controls == 6)
    local tile = D.controls[4].rect
    click(game, tile.x + 5, tile.y + 5)
    assert(d.values.back == "fish")
    game:key_press("right")
    assert(d.values.back == "castle")
    game:_dialog_result(d, "ok")
    game:shell():close_dialog()
    assert(game:back() == "castle" and store.solitaire_back == "castle")
    assert(game:back_name() == "Castle")
end)

test("Help dialogs open and close", function()
    local game = new_game()
    game:_command("how_to")
    assert(game:shell():dialog().kind == "how_to")
    game:key_press("confirm")
    assert(game:shell():dialog() == nil)
    game:_command("about")
    assert(game:shell():dialog().title == "About Solitaire")
end)

test("Esc backs out of dialog, menu, selection, then lets the game close", function()
    local game = new_game()
    setup(game, { [T1] = { { card(HEARTS, 9), true } } })
    game:key_press("confirm")
    game:_command("about")
    assert(game:ui_back() and game:shell():dialog() == nil)
    game:key_press("menu")
    assert(game:ui_back() and game:shell():menu() == nil)
    assert(game:selection() == T1)
    assert(game:ui_back() and game:selection() == nil)
    assert(game:ui_back() == false)
end)

test("summary line", function()
    local game = new_game()
    game._score = 125
    game._elapsed = 184
    assert(game:summary() == "[Solitaire] Score: 125  Time: 184s  Cards home: 0/52", game:summary())
    local vegas = new_game({ solitaire_scoring = "vegas" })
    assert(vegas:summary():find("Vegas: %-%$52"))
end)

test("sounds are sparse: moves and wins only", function()
    local game, _, sounds = new_game()
    game:stock_click()
    assert(#sounds == 0, "dealing from the stock is silent")
    setup(game, { [T1] = { { card(HEARTS, 1), true } } })
    game:send_to_foundation(T1)
    assert(sounds[#sounds] == "move")
end)

-- Randomised play ------------------------------------------------------------------------------------

test("randomised play keeps the table consistent", function()
    local game = new_game()
    local L = game:layout()
    local keys = { "left", "right", "up", "down", "confirm", "alt", "confirm", "undo" }
    local wins = 0
    for step = 1, 40000 do
        local r = math.random()
        if r < 0.25 then
            local from, to = math.random(1, 13), math.random(1, 13)
            local n = #game:pile(from)
            if n > 0 then game:move(from, math.random(1, n), to) end
        elseif r < 0.35 then
            game:stock_click()
        elseif r < 0.42 then
            game:flip(math.random(7, 13))
        elseif r < 0.5 then
            game:send_to_foundation(math.random(1, 13))
        elseif r < 0.7 then
            local x = L.client.x + math.random() * L.client.w
            local y = L.client.y + math.random() * L.client.h
            if math.random() < 0.5 then
                drag(game, x, y, L.client.x + math.random() * L.client.w, L.client.y + math.random() * L.client.h)
            else
                click(game, x, y)
            end
        elseif r < 0.9 then
            game:key_press(keys[math.random(1, #keys)], math.random() < 0.1)
        elseif r < 0.905 then
            right_click(game, L.client.x + 200, L.client.y + 300)
        elseif r < 0.906 then
            game:deal()
        elseif r < 0.91 then
            game:ui_back()
        else
            game:update(math.random() * 0.2)
        end
        game:drain_events(function() end)
        if game:status() == "won" then
            wins = wins + 1
            game:deal()
        end
        if game:shell():dialog() then game:shell():close_dialog() end
        if step % 97 == 0 then check_invariants(game, "step " .. step) end
    end
    check_invariants(game, "end")
end)

test("a greedy player can win a deal (end to end)", function()
    local won = false
    for seed = 1, 60 do
        math.randomseed(seed)
        local game = new_game({ solitaire_draw = 1 })
        for _ = 1, 3000 do
            local moved = false
            for p = 2, 13 do
                if not moved and (p < 3 or p > 6) then moved = game:send_to_foundation(p) end
            end
            for p = 7, 13 do
                if not moved then moved = game:flip(p) end
            end
            for from = 2, 13 do
                if not moved and (from < 3 or from > 6) then
                    local pile = game:pile(from)
                    for i = 1, #pile do
                        if not moved and game:is_face_up(pile[i]) and (i == 1 or not game:is_face_up(pile[i - 1]) or from == 2) then
                            for to = 7, 13 do
                                if not moved and not (i == 1 and #game:pile(to) == 0) then moved = game:move(from, i, to) end
                            end
                        end
                    end
                end
            end
            if not moved and not game:stock_click() then break end
            if game:status() == "won" then break end
        end
        if game:status() == "won" then
            won = true
            check_invariants(game, "won")
            assert(game:foundation_count() == 52)
            break
        end
    end
    assert(won, "some deal should be winnable by a greedy player")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
