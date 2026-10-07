-- Run: lua5.1 hearts_game_test.lua [mod_script_dir]   (also runs under luajit)
local DIR = arg and arg[1] or "/mnt/user-data/outputs/mwg/"
if DIR:sub(-1) ~= "/" then DIR = DIR .. "/" end
get_mod = function()
    return { io_dofile = function(_, p) return dofile(DIR .. p:match("([^/]+)$") .. ".lua") end }
end
local Game = dofile(DIR .. "Hearts_game.lua")

local SOUTH, WEST, NORTH, EAST = 1, 2, 3, 4
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

local SUITS = { C = 1, D = 2, H = 3, S = 4 }
local RANKS = { T = 10, J = 11, Q = 12, K = 13, A = 14 }
-- "QS" -> Queen of Spades, "TH" -> Ten of Hearts, "2C" -> Two of Clubs.
local function C(text)
    local r = RANKS[text:sub(1, 1)] or tonumber(text:sub(1, 1))
    return Game.card_id(SUITS[text:sub(2, 2)], r)
end
local function cards(list)
    local out = {}
    for word in list:gmatch("%S+") do out[#out + 1] = C(word) end
    return out
end

local function new_game(extra)
    local store = extra and extra.store or {}
    local sounds = {}
    local options = {
        get = function(key) return store[key] end,
        set = function(key, value) store[key] = value end,
        on_sound = function(kind) sounds[#sounds + 1] = kind end,
    }
    if extra then
        options.policy = extra.policy
        options.autoplay = extra.autoplay
    end
    local game = Game:new(options)
    game:start()
    return game, store, sounds
end

local function run_until(game, predicate, dt, limit)
    for _ = 1, limit or 20000 do
        if predicate() then return true end
        game:update(dt or 0.05)
    end
    return predicate()
end

local function contains(list, card)
    for i = 1, #list do
        if list[i] == card then return true end
    end
    return false
end

-- Puts the game into the play phase with fixed hands; every other card counts as already played.
local function setup_play(game, hands, opts)
    opts = opts or {}
    local used = {}
    for seat = 1, 4 do
        local hand = hands[seat] and cards(hands[seat]) or {}
        game._hands[seat] = hand
        for i = 1, #hand do used[hand[i]] = true end
    end
    game._played = {}
    for c = 1, 52 do
        if not used[c] then game._played[c] = true end
    end
    game._phase = "play"
    game._tricks_played = opts.tricks or 5
    game._hearts_broken = opts.broken or false
    game._points = opts.points or { 0, 0, 0, 0 }
    game._void = { {}, {}, {}, {} }
    game._shooter = { false, false, false, false }
    local trick = game._trick
    trick.count, trick.led, trick.leader = 0, nil, opts.turn or SOUTH
    game._turn = opts.turn or SOUTH
    game._timer = 0
end

-- Plays the given cards in order, starting with the current turn.
local function play_all(game, list)
    for word in list:gmatch("%S+") do
        local seat = game:turn()
        local ok, why = game:play_card(seat, C(word))
        assert(ok, "could not play " .. word .. " for seat " .. tostring(seat) .. ": " .. tostring(why))
    end
end

local function random_policy(_, _, legal)
    return legal[math.random(1, #legal)]
end

-- Rules ------------------------------------------------------------------------------------

test("deal gives 13 sorted cards to each player from one deck", function()
    local game = new_game()
    eq(game:phase(), "deal")
    local seen = {}
    for seat = 1, 4 do
        local hand = game:hand(seat)
        eq(#hand, 13, "hand size")
        for i = 1, 13 do
            assert(not seen[hand[i]], "duplicate card")
            seen[hand[i]] = true
        end
    end
    for c = 1, 52 do assert(seen[c], "missing card " .. c) end
    local south = game:hand(SOUTH)
    local order = { 1, 2, 4, 3 }
    for i = 2, 13 do
        local a, b = south[i - 1], south[i]
        local ka = order[Game.suit_of(a)] * 16 + Game.rank_of(a)
        local kb = order[Game.suit_of(b)] * 16 + Game.rank_of(b)
        assert(ka < kb, "hand not sorted clubs, diamonds, spades, hearts")
    end
    run_until(game, function() return game:phase() == "pass" end)
    eq(game:phase(), "pass")
    eq(game:button_label(), "Pass Left")
    assert(game:status_text():find("Pauline"), "status names the receiver: " .. game:status_text())
end)

test("pass directions cycle left, right, across, none", function()
    local game = new_game()
    eq(game:pass_target(SOUTH, "left"), WEST)
    eq(game:pass_target(WEST, "left"), NORTH)
    eq(game:pass_target(EAST, "left"), SOUTH)
    eq(game:pass_target(SOUTH, "right"), EAST)
    eq(game:pass_target(NORTH, "right"), WEST)
    eq(game:pass_target(SOUTH, "across"), NORTH)
    eq(game:pass_target(WEST, "across"), EAST)
    local expected = { "left", "right", "across", "none", "left" }
    for hand = 1, 5 do
        eq(game:pass_dir(), expected[hand], "hand " .. hand)
        game:_deal()
    end
end)

test("passing moves three cards to the left and shows the received cards raised", function()
    local game = new_game()
    run_until(game, function() return game:phase() == "pass" end)
    local before = {}
    for seat = 1, 4 do
        before[seat] = {}
        for i, c in ipairs(game:hand(seat)) do before[seat][i] = c end
    end
    local give = { before[SOUTH][1], before[SOUTH][5], before[SOUTH][13] }
    assert(not game:button_enabled(), "button disabled before three cards")
    for i = 1, 3 do assert(game:toggle_select(give[i])) end
    assert(game:button_enabled())
    assert(not game:toggle_select(before[SOUTH][2]), "a fourth card can't be selected")
    assert(game:toggle_select(give[3]) and game:selected_count() == 2, "clicking again lowers the card")
    game:toggle_select(give[3])
    game:press_button()
    eq(game:phase(), "received")
    eq(game:button_label(), "OK")
    for i = 1, 3 do
        assert(contains(game:hand(WEST), give[i]), "Pauline received the card")
        assert(not contains(game:hand(SOUTH), give[i]), "card left South")
    end
    local raised = 0
    for _, c in ipairs(game:hand(SOUTH)) do
        if game:is_received(c) then
            raised = raised + 1
            assert(not contains(before[SOUTH], c), "received card is new")
            assert(contains(before[EAST], c), "South receives from Ben when passing left")
            eq(game:raise_of(c), game:layout().raise)
        end
    end
    eq(raised, 3)
    eq(game:received_from(), EAST)
    assert(game:status_text():find("Ben passed you"), game:status_text())
    for seat = 1, 4 do eq(#game:hand(seat), 13) end
    game:press_button()
    eq(game:phase(), "play")
end)

test("no-pass hand starts play with the holder of the 2 of Clubs", function()
    local game = new_game()
    for _ = 1, 3 do game:_deal() end
    eq(game:pass_dir(), "none")
    run_until(game, function() return game:phase() ~= "deal" end)
    eq(game:phase(), "play")
    local leader = game:turn()
    assert(contains(game:hand(leader), Game.TWO_CLUBS), "leader holds the 2 of Clubs")
    local legal = game:legal_cards(leader)
    eq(#legal, 1)
    eq(legal[1], Game.TWO_CLUBS)
end)

test("must lead the 2 of Clubs and follow suit", function()
    local game = new_game()
    setup_play(game, {
        "2C 5C 9D QS 3H", "7C KD 4S 5H 6H", "8C 2D 3D 4D 5D", "AC 6S 7S 8S 9S",
    }, { tricks = 0, turn = SOUTH })
    eq(game:illegal_reason(SOUTH, C("5C")), "You must lead the 2 of Clubs.")
    assert(game:play_card(SOUTH, C("2C")))
    eq(game:turn(), WEST)
    eq(game:illegal_reason(WEST, C("KD")), "You must follow suit.")
    assert(game:can_play(WEST, C("7C")))
end)

test("no points on the first trick unless only points remain", function()
    local game = new_game()
    setup_play(game, {
        "2C 5C", "QS 5H 9D", "QH KH AH", "3C 4C",
    }, { tricks = 0, turn = SOUTH })
    play_all(game, "2C")
    eq(game:illegal_reason(WEST, C("QS")), "You can't play points on the first trick.")
    eq(game:illegal_reason(WEST, C("5H")), "You can't play points on the first trick.")
    assert(game:can_play(WEST, C("9D")))
    play_all(game, "9D")
    assert(game:can_play(NORTH, C("AH")), "only hearts: any may be played")
    play_all(game, "AH")
    assert(game:hearts_broken(), "a heart on the first trick breaks hearts")
end)

test("hearts can't be led until broken; the Queen of Spades may be led", function()
    local game = new_game()
    setup_play(game, { "2H 9H QS 4D", "5C", "6C", "7C" }, { tricks = 3, turn = SOUTH })
    eq(game:illegal_reason(SOUTH, C("2H")), "Hearts have not been broken.")
    assert(game:can_play(SOUTH, C("QS")))
    assert(game:can_play(SOUTH, C("4D")))
    setup_play(game, { "2H 9H", "5C", "6C", "7C" }, { tricks = 3, turn = SOUTH })
    assert(game:can_play(SOUTH, C("2H")), "only hearts left")
    setup_play(game, { "2H 9H 4D", "5C", "6C", "7C" }, { tricks = 3, turn = SOUTH, broken = true })
    assert(game:can_play(SOUTH, C("2H")), "broken")
end)

test("a discarded heart breaks hearts and the Queen does not", function()
    local game = new_game()
    setup_play(game, { "4D 3S", "5D 9S", "QS 2H", "6D 8S" }, { tricks = 3, turn = SOUTH })
    play_all(game, "4D 5D QS")
    assert(not game:hearts_broken(), "Queen does not break hearts")
    play_all(game, "6D")
    game:update(5); game:update(5)
    eq(game:turn(), EAST, "highest diamond wins")
    play_all(game, "8S 3S 9S 2H")
    assert(game:hearts_broken())
end)

test("trick goes to the highest card of the led suit", function()
    local game = new_game()
    setup_play(game, { "5D 2C", "AS 3C", "KD 4C", "9D 5C" }, { tricks = 3, turn = SOUTH })
    play_all(game, "5D AS KD 9D")
    eq(game:phase(), "trick")
    eq(game:trick_winner(), NORTH)
    assert(game:status_text():find("Michele takes the trick"), game:status_text())
    run_until(game, function() return game:phase() == "play" end)
    eq(game:turn(), NORTH, "winner leads")
    eq(game:tricks_won(NORTH), 1)
    eq(game:trick().count, 0)
end)

test("points: hearts 1, Queen 13, collected when the trick is swept", function()
    local game = new_game()
    setup_play(game, { "5S 2C", "QS 3C", "KS 4C", "3H 5C" }, { tricks = 3, turn = SOUTH, broken = true })
    play_all(game, "5S QS KS 3H")
    eq(game:trick_winner(), NORTH)
    run_until(game, function() return game:phase() == "play" end)
    eq(game:points(NORTH), 14)
    eq(game:hearts_taken(NORTH), 1)
    eq(game:queen_taker(), NORTH)
end)

-- Scoring --------------------------------------------------------------------------------------

test("hand scores add up and the next hand passes right", function()
    local game = new_game()
    game._points = { 3, 13, 10, 0 }
    game._tricks_played = 13
    game:_end_hand()
    eq(game:phase(), "hand_end")
    run_until(game, function() return game:shell():dialog() ~= nil end)
    local dialog = game:shell():dialog()
    eq(dialog.kind, "score")
    assert(not dialog.final)
    eq(game:total(SOUTH), 3); eq(game:total(WEST), 13); eq(game:total(NORTH), 10); eq(game:total(EAST), 0)
    eq(#game:history(), 1)
    game:shell():key("confirm")
    eq(game:shell():dialog(), nil)
    eq(game:hand_number(), 2)
    eq(game:pass_dir(), "right")
end)

test("shooting the moon gives everyone else 26", function()
    local game, _, sounds = new_game()
    game._points = { 0, 0, 26, 0 }
    game._tricks_played = 13
    game:_end_hand()
    eq(game:moon(), NORTH)
    eq(game:total(NORTH), 0)
    eq(game:total(SOUTH), 26); eq(game:total(WEST), 26); eq(game:total(EAST), 26)
    assert(game:status_text():find("Michele shot the moon"), game:status_text())
    eq(sounds[#sounds], "lose")
    run_until(game, function() return game:shell():dialog() ~= nil end)
    assert(game:shell():dialog().message:find("shot the moon"))
end)

test("game ends at 100 with the lowest score winning, ties shared", function()
    local game, store = new_game()
    game._totals = { 40, 95, 60, 40 }
    game._points = { 4, 10, 12, 0 }
    game._tricks_played = 13
    game:_end_hand()
    local winners = game:winners()
    assert(winners, "game over")
    eq(#winners, 1); eq(winners[1], EAST)
    eq(store.hearts_played, 1)
    eq(store.hearts_highscore, nil, "Ben won, not you")
    run_until(game, function() return game:shell():dialog() ~= nil end)
    local dialog = game:shell():dialog()
    assert(dialog.final and dialog.message == "Ben wins!", tostring(dialog.message))
    game:ui_back()
    eq(game:phase(), "over")
    eq(game:button_label(), "New Game")

    game, store = new_game()
    game._totals = { 50, 99, 50, 70 }
    game._points = { 5, 5, 5, 11 }
    game._tricks_played = 13
    game:_end_hand()
    winners = game:winners()
    eq(#winners, 2)
    eq(winners[1], SOUTH); eq(winners[2], NORTH)
    eq(store.hearts_highscore, 1, "a shared win counts")
    run_until(game, function() return game:shell():dialog() ~= nil end)
    eq(game:shell():dialog().message, "You and Michele share the win!")
    game:key_press("new")
    eq(game:shell():dialog(), nil)
    eq(game:hand_number(), 1)
    eq(game:total(SOUTH), 0)
end)

test("99 points does not end the game", function()
    local game = new_game()
    game._totals = { 90, 0, 0, 0 }
    game._points = { 9, 17, 0, 0 }
    game._tricks_played = 13
    game:_end_hand()
    eq(game:winners(), nil)
end)

-- Computer players ------------------------------------------------------------------------------

test("AI passes the Queen, Ace and King of Spades when short in spades", function()
    local game = new_game()
    game._hands[WEST] = cards("QS AS 5S KH 9H 3H AD JD 7D 4D TC 6C 2C")
    local pass = game:_ai_pass(WEST)
    assert(contains(pass, C("QS")) and contains(pass, C("AS")), "dumps dangerous spades")
    eq(#pass, 3)
end)

test("AI keeps the Queen with long spades and voids a short suit", function()
    local game = new_game()
    game._hands[WEST] = cards("QS 2S 3S 4S 7S 9S AH KD QD AC 5C 3C 2C")
    local pass = game:_ai_pass(WEST)
    assert(not contains(pass, C("QS")), "Queen guarded by four low spades")
    assert(contains(pass, C("KD")) and contains(pass, C("QD")), "voids diamonds")
    assert(contains(pass, C("AH")), "passes the Ace of Hearts")
end)

test("AI ducks under the winning card and sheds its highest safe card", function()
    local game = new_game()
    setup_play(game, { "KD 4C", "2D 9D JD 3C", "AD", "3D 6D" }, { tricks = 4, turn = SOUTH, broken = true })
    game._points = { 0, 0, 3, 2 }
    play_all(game, "KD")
    eq(game:_ai_choose(WEST), C("JD"), "highest diamond under the King")
end)

test("AI drops the Queen of Spades on the King", function()
    local game = new_game()
    setup_play(game, { "KS 4C", "QS 3S 3C", "7D", "8D" }, { tricks = 4, turn = SOUTH })
    game._points = { 1, 0, 0, 0 }
    play_all(game, "KS")
    eq(game:_ai_choose(WEST), C("QS"))
end)

test("AI discards the Queen, then high spades, then high hearts when void", function()
    local game = new_game()
    setup_play(game, { "5D", "QS AH 2H 3C", "6D", "7D" }, { tricks = 4, turn = SOUTH, broken = true })
    game._points = { 0, 2, 0, 1 }
    play_all(game, "5D")
    eq(game:_ai_choose(WEST), C("QS"))

    setup_play(game, { "5D", "AS KS 9H 3C", "6D", "7D QS" }, { tricks = 4, turn = SOUTH, broken = true })
    game._points = { 0, 2, 0, 1 }
    play_all(game, "5D")
    eq(game:_ai_choose(WEST), C("AS"), "Ace of Spades while the Queen is out")

    setup_play(game, { "5D", "KH 9H 3C", "6D", "7D" }, { tricks = 4, turn = SOUTH, broken = true })
    game._points = { 0, 2, 0, 1 }
    play_all(game, "5D")
    eq(game:_ai_choose(WEST), C("KH"))
end)

test("AI plays high when last on a trick without points", function()
    local game = new_game()
    setup_play(game, { "5C", "9C", "2C", "AC 3C 4D" }, { tricks = 4, turn = SOUTH })
    game._points = { 0, 2, 3, 0 }
    play_all(game, "5C 9C 2C")
    eq(game:_ai_choose(EAST), C("AC"))
end)

test("AI never leads a spade that could pull the Queen onto its King", function()
    local game = new_game()
    for _ = 1, 30 do
        setup_play(game, { "KS 3S 4C 7D", "QS 8S 9C", "TC JC 2D", "5C 6C 3D 4D" }, { tricks = 8, turn = SOUTH })
        game._points = { 0, 2, 3, 0 }
        local card = game:_ai_choose(SOUTH)
        assert(card ~= C("KS"), "never leads the King of Spades into the Queen")
    end
end)

test("moon defence: take a trick from the would-be shooter", function()
    local game = new_game()
    setup_play(game, { "2D 9D", "QH 4C", "KH 5C", "AH 3C" }, { tricks = 9, turn = EAST, broken = true })
    game._points = { 0, 0, 20, 0 }
    -- Michele (North) holds every point; the Ace of Hearts leads to take a point back.
    eq(game:_ai_choose(EAST), C("AH"))

    setup_play(game, { "2D 9D", "QH 4C", "KH 5C", "AH 3C" }, { tricks = 9, turn = NORTH, broken = true })
    game._points = { 0, 0, 20, 0 }
    play_all(game, "KH")
    eq(game:_ai_choose(EAST), C("AH"), "beats the shooter's heart")

    setup_play(game, { "2D 9D", "QH 4C", "KC 5C", "3H 7S" }, { tricks = 9, turn = NORTH, broken = true })
    game._points = { 0, 0, 20, 0 }
    play_all(game, "KC")
    eq(game:_ai_choose(EAST), C("7S"), "no heart for the shooter when void")
end)

test("AI shooting the moon plays its winners", function()
    local game = new_game()
    setup_play(game, { "2D 3D", "AH KH", "4D 5D", "6D 7D" }, { tricks = 11, turn = WEST, broken = true })
    game._points = { 0, 24, 0, 0 }
    game._shooter[WEST] = true
    eq(game:_ai_choose(WEST), C("AH"))
end)

-- Interface ----------------------------------------------------------------------------------------

local function click(game, x, y)
    game:pointer_input(x, y, { left = true, left_pressed = true })
    game:pointer_input(x, y, { left = false, left_released = true })
end

local function card_point(game, index)
    local n = #game:hand(SOUTH)
    local x, y, w = game:hand_slot(SOUTH, index, n)
    local card = game:hand(SOUTH)[index]
    return x + (index == n and w * 0.5 or 6), y + 30 - game:raise_of(card)
end

test("mouse: select three cards, pass, accept, play a legal card", function()
    local game = new_game()
    run_until(game, function() return game:phase() == "pass" end)
    for i = 1, 3 do
        local x, y = card_point(game, i * 3)
        click(game, x, y)
    end
    eq(game:selected_count(), 3)
    local b = game:layout().button
    click(game, b.x + 10, b.y + 10)
    eq(game:phase(), "received")
    click(game, b.x + 10, b.y + 10)
    eq(game:phase(), "play")
    run_until(game, function() return game:turn() == SOUTH end)
    eq(game:turn(), SOUTH)
    local hand = game:hand(SOUTH)
    local illegal, legal
    for i = 1, #hand do
        if game:can_play(SOUTH, hand[i]) then legal = legal or i else illegal = illegal or i end
    end
    if illegal then
        local x, y = card_point(game, illegal)
        click(game, x, y)
        eq(game:turn(), SOUTH, "illegal click does not play")
        assert(game:status_text():find("must") or game:status_text():find("broken") or game:status_text():find("first trick"), game:status_text())
    end
    local count = #hand
    local x, y = card_point(game, legal)
    click(game, x, y)
    eq(#game:hand(SOUTH), count - 1, "legal click plays")
end)

test("keyboard: move, select, pass with E, confirm plays", function()
    local game = new_game()
    run_until(game, function() return game:phase() == "pass" end)
    game:key_press("left")
    game:key_press("confirm")
    game:key_press("right")
    game:key_press("confirm")
    game:key_press("right", true)
    game:key_press("confirm")
    eq(game:selected_count(), 3)
    eq(game:cursor_mode(), "keys")
    game:key_press("up")
    local _, on_button = game:focus()
    assert(on_button, "up focuses the pass button")
    game:key_press("confirm")
    eq(game:phase(), "received")
    game:key_press("confirm")
    eq(game:phase(), "play")
    run_until(game, function() return game:turn() == SOUTH end)
    local hand = game:hand(SOUTH)
    for i = 1, #hand do
        if game:can_play(SOUTH, hand[i]) then
            game._focus = i
            break
        end
    end
    local count = #hand
    game:key_press("confirm")
    eq(#game:hand(SOUTH), count - 1)
end)

test("menus, dialogs and settings", function()
    local game, store = new_game()
    game:key_press("menu")
    eq(game:shell():menu(), 1)
    assert(game:ui_back())
    eq(game:shell():menu(), nil)
    assert(not game:ui_back(), "Esc with nothing open closes the game")

    game:_command("dim")
    eq(store.hearts_dim, false)
    game:_command("fast")
    eq(store.hearts_fast, true)
    game:_command("deck")
    local dialog = game:shell():dialog()
    eq(dialog.kind, "deck")
    game:key_press("right")
    eq(dialog.values.back, "red")
    game:key_press("right")
    eq(dialog.values.back, "aquila")
    local D = game:shell():layout().dialog
    for i = 1, #D.buttons do
        if D.buttons[i].spec.id == "ok" then
            local r = D.buttons[i].rect
            click(game, r.x + 5, r.y + 5)
        end
    end
    eq(game:shell():dialog(), nil)
    eq(game:back(), "aquila")
    eq(store.hearts_back, "aquila")

    local again = Game:new({ get = function(k) return store[k] end, set = function(k, v) store[k] = v end })
    eq(again:back(), "aquila")
    assert(not again:dim_enabled() and again:fast_enabled(), "settings persist")

    game:key_press("1")
    eq(game:shell():dialog().kind, "score")
    game:key_press("confirm")
    eq(game:shell():dialog(), nil)
    for _, id in ipairs({ "how_to", "about" }) do
        game:_command(id)
        eq(game:shell():dialog().kind, id)
        game:ui_back()
    end

    local L = game:shell():layout()
    click(game, L.close_button.x + 3, L.close_button.y + 3)
    assert(game:consume_close_request())
    assert(not game:consume_close_request(), "only once")
    game:_command("exit")
    assert(game:consume_close_request())
    eq(game:is_game_over(), false)
    assert(game:summary():find("^%[Hearts%]"), game:summary())
end)

test("the table waits while a menu or dialog is open", function()
    local game = new_game()
    run_until(game, function() return game:phase() == "pass" end)
    game:_command("about")
    for _ = 1, 100 do game:update(0.1) end
    eq(game:phase(), "pass")
    game:ui_back()
    for i = 1, 3 do game:toggle_select(game:hand(SOUTH)[i]) end
    game:pass_cards(); game:accept_received()
    local hand_sizes = #game:hand(WEST) + #game:hand(NORTH) + #game:hand(EAST)
    game:key_press("menu")
    for _ = 1, 100 do game:update(0.1) end
    eq(#game:hand(WEST) + #game:hand(NORTH) + #game:hand(EAST), hand_sizes, "nobody plays behind the menu")
end)

-- Whole games ------------------------------------------------------------------------------------

-- Plays complete games; checks every hand has 13 tricks and scores that sum to 26 (78 on a moon).
local function simulate(games, extra, dt)
    local stats = { games = 0, hands = 0, moons = 0, totals = { 0, 0, 0, 0 }, wins = { 0, 0, 0, 0 } }
    for _ = 1, games do
        local game = new_game(extra)
        local hands_done = 0
        local steps = 0
        while true do
            steps = steps + 1
            assert(steps < 20000, "game did not finish (deadlock?) in phase " .. game:phase())
            local dialog = game:shell():dialog()
            if dialog then
                assert(dialog.kind == "score", "unexpected dialog " .. tostring(dialog.kind))
                if dialog.final then
                    game:ui_back()
                    break
                end
                game:shell():key("confirm")
            end
            local phase = game:phase()
            if phase == "hand_end" and game._hand_checked ~= game:hand_number() then
                game._hand_checked = game:hand_number()
                hands_done = hands_done + 1
                eq(game:tricks_played(), 13, "tricks per hand")
                local sum, tricks = 0, 0
                for s = 1, 4 do
                    sum = sum + game:points(s)
                    tricks = tricks + game:tricks_won(s)
                    eq(#game:hand(s), 0, "hands empty")
                    eq(#game._taken[s], game:tricks_won(s) * 4, "taken cards")
                end
                eq(sum, 26, "points per hand")
                eq(tricks, 13)
                local row = game:history()[#game:history()]
                local added = row.added[1] + row.added[2] + row.added[3] + row.added[4]
                if row.moon then
                    eq(added, 78, "moon adds 78")
                    stats.moons = stats.moons + 1
                else
                    eq(added, 26, "hand adds 26")
                end
            end
            if phase == "play" then
                local total = game:trick().count
                for s = 1, 4 do total = total + #game:hand(s) + #game._taken[s] end
                eq(total, 52, "card conservation")
            end
            game:update(dt or 1)
        end
        local winners = game:winners()
        assert(winners and #winners >= 1, "winners")
        local low, high = math.huge, 0
        for s = 1, 4 do
            low = math.min(low, game:total(s))
            high = math.max(high, game:total(s))
            stats.totals[s] = stats.totals[s] + game:total(s)
        end
        assert(high >= 100, "someone reached 100")
        for i = 1, #winners do
            eq(game:total(winners[i]), low, "winner has the lowest score")
            stats.wins[winners[i]] = stats.wins[winners[i]] + 1
        end
        eq(game:phase(), "over")
        stats.games = stats.games + 1
        stats.hands = stats.hands + hands_done
    end
    return stats
end

test("300 complete games of random legal play finish with consistent scores", function()
    math.randomseed(11)
    local stats = simulate(300, { autoplay = true, policy = random_policy })
    print(string.format("  random: %d games, %d hands, %d moons", stats.games, stats.hands, stats.moons))
end)

test("200 complete games of AI play finish with consistent scores", function()
    math.randomseed(23)
    local stats = simulate(200, { autoplay = true })
    print(string.format("  ai: %d games, %d hands, %d moons, avg %.1f/%.1f/%.1f/%.1f",
        stats.games, stats.hands, stats.moons,
        stats.totals[1] / stats.games, stats.totals[2] / stats.games, stats.totals[3] / stats.games, stats.totals[4] / stats.games))
end)

test("the AI clearly beats a random player", function()
    math.randomseed(5)
    local random_south = function(game, seat, legal)
        if seat == SOUTH then return legal[math.random(1, #legal)] end
        return nil
    end
    local stats = { games = 0, south = 0, others = 0 }
    for _ = 1, 150 do
        local game = new_game({ autoplay = true })
        -- South plays randomly, the others use the real AI.
        game._policy = nil
        local choose = game._ai_choose
        game._ai_choose = function(self, seat)
            if seat == SOUTH then
                local legal = self:legal_cards(seat)
                return random_south(self, seat, legal)
            end
            return choose(self, seat)
        end
        local steps = 0
        while not game:winners() or game:shell():dialog() do
            steps = steps + 1
            assert(steps < 20000, "stuck")
            local dialog = game:shell():dialog()
            if dialog then
                if dialog.final then game:ui_back() break end
                game:shell():key("confirm")
            end
            game:update(1)
        end
        stats.games = stats.games + 1
        stats.south = stats.south + game:total(SOUTH)
        stats.others = stats.others + (game:total(WEST) + game:total(NORTH) + game:total(EAST)) / 3
    end
    local south, others = stats.south / stats.games, stats.others / stats.games
    print(string.format("  random South averages %.1f, AI players %.1f", south, others))
    assert(south > others * 1.3, "AI should score clearly lower than random play")
end)

test("interface fuzz: random clicks and keys keep the game consistent", function()
    math.randomseed(99)
    local game = new_game()
    local keys = { "left", "right", "up", "down", "confirm", "confirm", "alt", "alt", "undo", "1", "2" }
    local L = game:shell():layout()
    local button = game:layout().button
    local held = false
    local max_hand = 0
    local tricks = 0
    for step = 1, 80000 do
        local r = math.random()
        if r < 0.45 then
            local x, y
            local where = math.random()
            if where < 0.6 then
                x = L.client.x + math.random() * L.client.w
                y = L.client.y + L.client.h * (0.7 + math.random() * 0.3)
            elseif where < 0.8 then
                x, y = button.x + math.random() * button.w, button.y + math.random() * button.h
            else
                x, y = math.random(0, 600), math.random(0, 600)
            end
            local down = math.random() < 0.5
            game:pointer_input(x, y, { left = down, left_pressed = down and not held, left_released = held and not down })
            held = down
        elseif r < 0.62 then
            game:key_press(keys[math.random(1, #keys)], math.random() < 0.2)
        elseif r < 0.625 then
            game:ui_back()
        elseif r < 0.6252 then
            game:key_press("new")
        elseif r < 0.627 then
            game:key_press("menu")
        else
            game:update(math.random() * 0.3)
        end
        game:drain_events(function(kind) if kind == "taken" then tricks = tricks + 1 end end)
        game:consume_close_request()
        local total = game:trick().count
        for s = 1, 4 do total = total + #game:hand(s) + #game._taken[s] end
        eq(total, 52, "card conservation at step " .. step)
        assert(type(game:status_text()) == "string")
        max_hand = math.max(max_hand, game:hand_number())
    end
    print(string.format("  fuzz reached hand %d, %d tricks taken", max_hand, tricks))
    assert(tricks >= 26, "fuzz should play through several hands")
end)

-- Difficulty -----------------------------------------------------------------------------------

test("difficulty dialog sets and persists the level", function()
    local game, store = new_game()
    eq(game:level(), 5, "default level")
    game:_command("difficulty")
    local dialog = game:shell():dialog()
    eq(dialog.kind, "difficulty")
    dialog.values.level = 9
    game:shell():ui_back()
    eq(game:level(), 5, "cancel keeps the level")
    game:_command("difficulty")
    game:shell():dialog().values.level = 9
    game:shell():_button_by_id("ok")
    eq(game:level(), 9)
    eq(store.hearts_level, 9, "persisted")
    local again = new_game({ store = store })
    eq(again:level(), 9, "restored")
end)

test("search players never look at hidden hands", function()
    -- West to lead in the middle of a hand. The other three hands are dealt two different ways
    -- with the same public information; with the same random seed the choice must match.
    local west = "2C 9C KD 3D 7S QH 4H"
    local deals = {
        { "5C 8C JD 6D 2S 9H 3H", "AC TC QD 4D KS 5H 8H", "3C 7C AD 9D AS 2H JH" },
        { "AC 7C AD 4D 2S 5H JH", "3C 8C QD 9D AS 9H 2H", "5C TC JD 6D KS 3H 8H" },
    }
    local picks = {}
    for k = 1, 2 do
        local game = new_game({ policy = nil })
        game._options.levels = { 5, 10, 5, 5 }
        setup_play(game, { deals[k][1], west, deals[k][2], deals[k][3] }, { turn = WEST, tricks = 6, broken = true })
        math.randomseed(1234)
        picks[k] = game:_ai_choose(WEST)
    end
    eq(picks[1], picks[2], "same public view, same card")
end)

test("search spreads its work over frames", function()
    local game = new_game()
    game._options.levels = { 10, 10, 10, 10 }
    game._autoplay = true
    local calls, worst = 0, 0
    local rollout = game._rollout
    game._rollout = function(self, ...)
        calls = calls + 1
        return rollout(self, ...)
    end
    for _ = 1, 3000 do
        local d = game:shell():dialog()
        if d then break end
        calls = 0
        game:update(1 / 60)
        if calls > worst then worst = calls end
    end
    assert(worst > 0, "search ran")
    assert(worst <= 60, "at most 60 play-outs per update, got " .. worst)
end)

test("a whole game at level 8 finishes with valid scores", function()
    local game = new_game({ autoplay = true })
    game._options.levels = { 8, 8, 8, 8 }
    local hands = 0
    for _ = 1, 400000 do
        local d = game:shell():dialog()
        if d then
            if d.final then break end
            hands = hands + 1
            local sum = 0
            local row = game:history()[#game:history()]
            for s = 1, 4 do sum = sum + row.added[s] end
            assert(sum == 26 or sum == 78, "hand adds 26 or 78")
            game:shell():key("confirm")
        end
        game:update(0.25)
    end
    assert(game:shell():dialog() and game:shell():dialog().final, "game ended")
    assert(hands >= 2)
end)

print(string.format("%d scenarios passed; %d failed", passed, failed))
if failed > 0 then os.exit(1) end
