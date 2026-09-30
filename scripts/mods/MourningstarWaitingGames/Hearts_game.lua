-- Hearts with Windows 95 rules and flow: four players, passing, tricks and shooting the moon.
-- Pure logic: table layout, hit testing, computer players, menus and dialogs live here so the
-- view only renders.
local mod = get_mod("MourningstarWaitingGames")
local Win95 = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_win95")

local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_random = math.random

local rect = Win95.rect
local inside = Win95.inside
local clamp = Win95.clamp

local CLUBS, DIAMONDS, HEARTS, SPADES = 1, 2, 3, 4
local SOUTH, WEST, NORTH, EAST = 1, 2, 3, 4
local QUEEN = 51
local TWO_CLUBS = 2
local END_SCORE = 100

local NAMES = { "You", "Pauline", "Michele", "Ben" }
local SUIT_NAMES = { "Clubs", "Diamonds", "Hearts", "Spades" }
local SUIT_SINGULAR = { "a Club", "a Diamond", "a Heart", "a Spade" }
local RANK_NAMES = { [11] = "Jack", [12] = "Queen", [13] = "King", [14] = "Ace" }
-- Display order in a hand: clubs, diamonds, spades, hearts, so the colours alternate.
local SORT_SUIT = { 1, 2, 4, 3 }
local PASS_ORDER = { "left", "right", "across", "none" }
local PASS_OFFSET = { left = 1, across = 2, right = 3 }
local PASS_LABEL = { left = "Pass Left", right = "Pass Right", across = "Pass Across" }
local PASS_WORDS = { left = "to the left", right = "to the right", across = "across", none = "no passing" }

-- Same ids as Cards.BACKS; kept here so the logic does not load drawing code.
local BACKS = {
    { id = "blue", name = "Blue Weave" },
    { id = "red", name = "Red Weave" },
    { id = "aquila", name = "Aquila" },
    { id = "fish", name = "Fish" },
    { id = "castle", name = "Castle" },
    { id = "robot", name = "Robot" },
}

local DEAL_TIME = 1.3
local AI_DELAY = 0.6
local AI_DELAY_FAST = 0.24
local HOLD_TIME = 1.0
local HOLD_TIME_FAST = 0.55
local SWEEP_TIME = 0.42
local SWEEP_TIME_FAST = 0.3
local RECEIVED_AUTO = 0.8
local HAND_END_TIME = 0.7
local MOON_TIME = 2.8
local GAME_END_TIME = 2.6

local CLIENT_W, CLIENT_H = 584, 462
local CARD_W, CARD_H = 56, 76
local SMALL_W, SMALL_H = 44, 60
local FAN_GAP = 29
local BACK_GAP = 13
local RAISE = 18
local PLATE_W, PLATE_H = 84, 46
local SCORE_ROWS = 10

-- Difficulty 1-10. Below 5 players sometimes pick a random legal card; 5 is the classic
-- heuristic player; above 5 they search: sampled deals times candidate cards, played out.
local DEFAULT_LEVEL = 5
local MISTAKES = { 0.6, 0.42, 0.26, 0.12, 0, 0.1, 0.05, 0.02, 0, 0 }
local SEARCH_SAMPLES = { [6] = 12, [7] = 24, [8] = 50, [9] = 100, [10] = 200 }
-- The search runs as a job spread over the frames a computer player spends thinking, so even the
-- strongest level never stalls a frame.
local ROLLOUTS_PER_UPDATE = 30
local ROLLOUTS_WHEN_LATE = 60

local HeartsGame = {}
HeartsGame.__index = HeartsGame

-- Cards --------------------------------------------------------------------------------------

-- Ids match the Cards module: (suit - 1) * 13 + rank with rank 1 = Ace. Hearts plays aces high.
local function suit_of(card) return math_floor((card - 1) / 13) + 1 end

local function rank_of(card)
    local r = (card - 1) % 13 + 1
    return r == 1 and 14 or r
end

local function card_id(suit, rank) return (suit - 1) * 13 + (rank == 14 and 1 or rank) end

local function card_points(card)
    if card == QUEEN then return 13 end
    return suit_of(card) == HEARTS and 1 or 0
end

local function card_name(card)
    local r = rank_of(card)
    return (RANK_NAMES[r] or tostring(r)) .. " of " .. SUIT_NAMES[suit_of(card)]
end

local function sort_key(card) return SORT_SUIT[suit_of(card)] * 16 + rank_of(card) end
local function by_display(a, b) return sort_key(a) < sort_key(b) end
local function by_rank(a, b) return rank_of(a) < rank_of(b) end

local function next_seat(seat) return seat % 4 + 1 end

local function remove_card(list, card)
    for i = 1, #list do
        if list[i] == card then
            table.remove(list, i)
            return true
        end
    end
    return false
end

local function has_suit(hand, suit)
    for i = 1, #hand do
        if suit_of(hand[i]) == suit then return true end
    end
    return false
end

local function only_hearts(hand)
    for i = 1, #hand do
        if suit_of(hand[i]) ~= HEARTS then return false end
    end
    return true
end

local function only_points(hand)
    for i = 1, #hand do
        if card_points(hand[i]) == 0 then return false end
    end
    return true
end

local function suit_count(hand, suit)
    local n = 0
    for i = 1, #hand do
        if suit_of(hand[i]) == suit then n = n + 1 end
    end
    return n
end

local function Cards_shuffle(list)
    for i = #list, 2, -1 do
        local j = math_random(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

local function join_names(list)
    if #list == 1 then return list[1] end
    return table.concat(list, ", ", 1, #list - 1) .. " and " .. list[#list]
end

HeartsGame.suit_of = suit_of
HeartsGame.rank_of = rank_of
HeartsGame.card_id = card_id
HeartsGame.card_points = card_points
HeartsGame.card_name = card_name
HeartsGame.QUEEN = QUEEN
HeartsGame.TWO_CLUBS = TWO_CLUBS
HeartsGame.SOUTH, HeartsGame.WEST, HeartsGame.NORTH, HeartsGame.EAST = SOUTH, WEST, NORTH, EAST
HeartsGame.CLUBS, HeartsGame.DIAMONDS, HeartsGame.HEARTS, HeartsGame.SPADES = CLUBS, DIAMONDS, HEARTS, SPADES

-- Setup ----------------------------------------------------------------------------------------

-- options: get(key), set(key, value), on_sound(kind); tests may add policy(game, seat, legal) and autoplay.
function HeartsGame:new(options)
    local game = setmetatable({}, HeartsGame)
    game._options = options or {}
    local get = game._options.get

    game._back = "blue"
    local back = get and get("hearts_back")
    for i = 1, #BACKS do
        if BACKS[i].id == back then game._back = back end
    end
    local dim = get and get("hearts_dim")
    game._dim = dim == nil and true or dim == true
    game._fast = (get and get("hearts_fast")) == true
    game._level = clamp(math_floor(tonumber(get and get("hearts_level")) or DEFAULT_LEVEL), 1, 10)
    game._policy = game._options.policy
    game._autoplay = game._options.autoplay and true or false

    game._time = 0
    game._events = {}
    game._event_count = 0
    game._pointer_x, game._pointer_y = -1, -1
    game._cursor_mode = "pointer"
    game._focus = 1
    game._focus_button = false
    game._button_press = false
    game._hover_card = nil
    game._hover_button = false
    game._close_requested = false
    game._status = ""
    game._status_hold = 0
    game._pending_status = nil

    game._hands = { {}, {}, {}, {} }
    game._totals = { 0, 0, 0, 0 }
    game._history = {}
    game._hand_number = 0
    game._phase = "idle"
    game._timer = 0
    game._winners = nil
    game._trick = { count = 0, cards = {}, seats = {}, leader = SOUTH, led = nil }
    game:_reset_hand_state()

    game._shell = Win95.shell({
        client_w = CLIENT_W, client_h = CLIENT_H, status = true, x = 4, y = 8,
        menus = {
            { id = "game", label = "Game", width = 176, items = {
                { id = "new", label = "New Game", key = "R" },
                { id = "score", label = "Score...", key = "1" },
                { separator = true },
                { id = "exit", label = "Exit", key = "Esc" },
            } },
            { id = "options", label = "Options", width = 196, items = {
                { id = "dim", label = "Dim Illegal Cards", check = function() return game._dim end },
                { id = "fast", label = "Quick Play", check = function() return game._fast end },
                { separator = true },
                { id = "difficulty", label = "Difficulty..." },
                { id = "deck", label = "Deck..." },
            } },
            { id = "help", label = "Help", width = 176, items = {
                { id = "how_to", label = "How to Play..." },
                { separator = true },
                { id = "about", label = "About Hearts..." },
            } },
        },
        on_command = function(id) game:_command(id) end,
        on_dialog = function(dialog, id) return game:_dialog_button(dialog, id) end,
    })
    game:_build_layout()
    return game
end

function HeartsGame:start()
    self:new_game()
end

function HeartsGame:_persist(key, value)
    local set = self._options.set
    if set then set(key, value) end
end

function HeartsGame:_setting(key)
    local get = self._options.get
    return get and get(key)
end

function HeartsGame:_sound(kind)
    local on_sound = self._options.on_sound
    if on_sound then on_sound(kind) end
end

function HeartsGame:_event(kind, a, b)
    local n = self._event_count + 1
    local e = self._events[n]
    if not e then
        e = {}
        self._events[n] = e
    end
    e.kind, e.a, e.b = kind, a, b
    self._event_count = n
end

function HeartsGame:drain_events(callback)
    for i = 1, self._event_count do
        local e = self._events[i]
        callback(e.kind, e.a, e.b)
    end
    self._event_count = 0
end

-- Status bar: important messages are held for a while before routine turn prompts replace them.
function HeartsGame:_say(text, hold)
    self._status = text
    self._status_hold = self._time + (hold or 0)
    self._pending_status = nil
end

function HeartsGame:_say_soft(text)
    if self._time >= self._status_hold then
        self._status = text
        self._pending_status = nil
    else
        self._pending_status = text
    end
end

-- Layout ---------------------------------------------------------------------------------------

function HeartsGame:_build_layout()
    local S = self._shell:layout()
    local c = S.client
    local L = { client = c, window = S.window, card_w = CARD_W, card_h = CARD_H, small_w = SMALL_W, small_h = SMALL_H }

    L.cx = c.x + math_floor(c.w * 0.5)
    L.cy = c.y + 212
    L.south_y = c.y + c.h - CARD_H - 14
    L.north_y = c.y + 34
    L.west_x = c.x + 18
    L.east_x = c.x + c.w - 18 - SMALL_H
    L.raise = RAISE

    local tx, ty = L.cx - CARD_W * 0.5, L.cy - CARD_H * 0.5
    L.trick = {
        [SOUTH] = { x = tx, y = ty + 44 },
        [WEST] = { x = tx - 70, y = ty },
        [NORTH] = { x = tx, y = ty - 44 },
        [EAST] = { x = tx + 70, y = ty },
    }
    L.deck = { x = tx, y = ty }

    L.plate = {
        [SOUTH] = rect(c.x + 6, c.y + c.h - PLATE_H - 8, PLATE_W, PLATE_H),
        [WEST] = rect(c.x + 8, c.y + 58, PLATE_W, PLATE_H),
        [NORTH] = rect(L.cx - 100 - 12 - PLATE_W, L.north_y + 8, PLATE_W, PLATE_H),
        [EAST] = rect(c.x + c.w - 8 - PLATE_W, c.y + 58, PLATE_W, PLATE_H),
    }
    L.button = rect(L.cx - 54, L.cy - 12, 108, 25)
    L.arrow = { x = L.cx, y = L.cy - 58 }

    self._layout = L
end

-- Base position of card i of n in a seat's hand; South's cards are raised separately.
function HeartsGame:hand_slot(seat, i, n)
    local L = self._layout
    if seat == SOUTH then
        local total = CARD_W + (n - 1) * FAN_GAP
        return math_floor(L.cx - total * 0.5) + (i - 1) * FAN_GAP, L.south_y, CARD_W, CARD_H
    end
    local total = SMALL_W + (n - 1) * BACK_GAP
    local start = math_floor(-total * 0.5)
    if seat == NORTH then
        return L.cx + start + (n - i) * BACK_GAP, L.north_y, SMALL_W, SMALL_H
    elseif seat == WEST then
        return L.west_x, L.cy + start + (i - 1) * BACK_GAP, SMALL_H, SMALL_W
    end
    return L.east_x, L.cy + start + (n - i) * BACK_GAP, SMALL_H, SMALL_W
end

function HeartsGame:raise_of(card)
    if self._phase == "pass" and self._selected[card] then return RAISE end
    if self._phase == "received" and self._received[card] then return RAISE end
    return 0
end

-- Topmost of South's cards under the pointer.
function HeartsGame:card_at(x, y)
    local hand = self._hands[SOUTH]
    local n = #hand
    for i = n, 1, -1 do
        local cx, cy, w, h = self:hand_slot(SOUTH, i, n)
        cy = cy - self:raise_of(hand[i])
        if x >= cx and y >= cy and x < cx + w and y < cy + h then return i end
    end
    return nil
end

-- Game flow ------------------------------------------------------------------------------------

function HeartsGame:_reset_hand_state()
    self._taken = { {}, {}, {}, {} }
    self._points = { 0, 0, 0, 0 }
    self._hearts_taken = { 0, 0, 0, 0 }
    self._tricks_won = { 0, 0, 0, 0 }
    self._queen_taker = nil
    self._played = {}
    self._void = { {}, {}, {}, {} }
    self._suit_played = { 0, 0, 0, 0 }
    self._hearts_broken = false
    self._tricks_played = 0
    self._selected = {}
    self._selected_count = 0
    self._received = {}
    self._received_from = nil
    self._shooter = { false, false, false, false }
    self._passed = {}
    self._search_job = nil
    self._trick_winner = nil
    self._moon = nil
    local trick = self._trick
    trick.count, trick.led, trick.leader = 0, nil, SOUTH
end

function HeartsGame:new_game()
    self._shell:close_dialog()
    self._shell:close_menu()
    self._totals = { 0, 0, 0, 0 }
    self._history = {}
    self._hand_number = 0
    self._winners = nil
    self._focus = 1
    self._focus_button = false
    self:_event("new_game")
    self:_deal()
end

function HeartsGame:_deal()
    self._hand_number = self._hand_number + 1
    self._pass_dir = PASS_ORDER[(self._hand_number - 1) % 4 + 1]
    self:_reset_hand_state()

    local deck = {}
    for i = 1, 52 do deck[i] = i end
    for i = 52, 2, -1 do
        local j = math_random(1, i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    for seat = 1, 4 do
        local hand = {}
        for i = 1, 13 do hand[i] = deck[(i - 1) * 4 + seat] end
        table.sort(hand, by_display)
        self._hands[seat] = hand
    end

    self._phase = "deal"
    self._timer = DEAL_TIME
    self._focus = clamp(self._focus, 1, 13)
    self._focus_button = false
    self:_say("Dealing hand " .. self._hand_number .. "...")
    self:_event("deal", self._hand_number)
end

function HeartsGame:_after_deal()
    if self._pass_dir == "none" then
        self:_say("There is no passing this hand.", 1.8)
        self:_start_play()
        return
    end
    self._phase = "pass"
    self._selected = {}
    self._selected_count = 0
    self:_pass_status()
end

function HeartsGame:pass_target(seat, dir)
    local offset = PASS_OFFSET[dir or self._pass_dir]
    if not offset then return seat end
    return (seat - 1 + offset) % 4 + 1
end

function HeartsGame:_pass_status()
    local who = NAMES[self:pass_target(SOUTH)]
    local left = 3 - self._selected_count
    if left == 3 then
        self:_say_soft("Select three cards to pass to " .. who .. ".")
    elseif left > 0 then
        self:_say_soft("Select " .. left .. " more card" .. (left == 1 and "" or "s") .. " to pass to " .. who .. ".")
    else
        self:_say_soft("Click " .. PASS_LABEL[self._pass_dir] .. " to give these cards to " .. who .. ".")
    end
end

function HeartsGame:toggle_select(card)
    if self._phase ~= "pass" then return false end
    if self._selected[card] then
        self._selected[card] = nil
        self._selected_count = self._selected_count - 1
        self:_event("select", card, false)
    elseif self._selected_count < 3 then
        self._selected[card] = true
        self._selected_count = self._selected_count + 1
        self:_event("select", card, true)
    else
        self:_say("You can only pass three cards.", 1.4)
        return false
    end
    self._status_hold = 0
    self:_pass_status()
    return true
end

function HeartsGame:pass_cards()
    if self._phase ~= "pass" or self._selected_count ~= 3 then return false end

    local gifts = {}
    local hand = self._hands[SOUTH]
    gifts[SOUTH] = {}
    for i = 1, #hand do
        if self._selected[hand[i]] then gifts[SOUTH][#gifts[SOUTH] + 1] = hand[i] end
    end
    for seat = WEST, EAST do gifts[seat] = self:_ai_pass(seat) end
    for seat = 1, 4 do
        self._passed[seat] = { to = self:pass_target(seat), cards = { gifts[seat][1], gifts[seat][2], gifts[seat][3] } }
    end

    for seat = 1, 4 do
        for i = 1, 3 do remove_card(self._hands[seat], gifts[seat][i]) end
    end
    self._received = {}
    for seat = 1, 4 do
        local to = self:pass_target(seat)
        local target = self._hands[to]
        for i = 1, 3 do
            target[#target + 1] = gifts[seat][i]
            if to == SOUTH then self._received[gifts[seat][i]] = true end
        end
        if to == SOUTH then self._received_from = seat end
    end
    for seat = 1, 4 do table.sort(self._hands[seat], by_display) end

    self._selected = {}
    self._selected_count = 0
    self._phase = "received"
    self._timer = RECEIVED_AUTO
    self._focus_button = false

    local from = self._received_from
    local got = gifts[from]
    table.sort(got, by_display)
    self:_say(NAMES[from] .. " passed you the " .. card_name(got[1]) .. ", " .. card_name(got[2]) .. " and " .. card_name(got[3]) .. ".")
    self:_event("pass", self._pass_dir)
    self:_sound("move")
    return true
end

function HeartsGame:accept_received()
    if self._phase ~= "received" then return false end
    self._received = {}
    self:_start_play()
    return true
end

function HeartsGame:_start_play()
    for seat = 1, 4 do
        if (seat ~= SOUTH or self._autoplay) and not self._shooter[seat] then
            self._shooter[seat] = self:_moon_hand(self._hands[seat])
        end
    end

    local leader = SOUTH
    for seat = 1, 4 do
        local hand = self._hands[seat]
        for i = 1, #hand do
            if hand[i] == TWO_CLUBS then leader = seat end
        end
    end

    local trick = self._trick
    trick.count, trick.led, trick.leader = 0, nil, leader
    self._turn = leader
    self._phase = "play"
    self._timer = self:_ai_delay() + 0.3
    self._focus_button = false
    self:_turn_status()
    self:_event("turn", leader)
end

function HeartsGame:_ai_delay()
    local base = self._fast and AI_DELAY_FAST or AI_DELAY
    return base + math_random() * base * 0.35
end

-- On the player's turn the keyboard focus moves to the nearest card that may be played.
function HeartsGame:_snap_focus()
    local hand = self._hands[SOUTH]
    local n = #hand
    if n == 0 then return end
    local focus = clamp(self._focus, 1, n)
    self._focus = focus
    if self:can_play(SOUTH, hand[focus]) then return end
    for d = 1, n do
        if focus - d >= 1 and self:can_play(SOUTH, hand[focus - d]) then
            self._focus = focus - d
            return
        end
        if focus + d <= n and self:can_play(SOUTH, hand[focus + d]) then
            self._focus = focus + d
            return
        end
    end
end

function HeartsGame:_turn_status()
    local seat = self._turn
    local trick = self._trick
    if seat == SOUTH then self:_snap_focus() end
    if seat == SOUTH and not self._autoplay then
        if trick.count == 0 then
            if self._tricks_played == 0 then
                self:_say_soft("You have the 2 of Clubs. Click it to lead.")
            else
                self:_say_soft("Your lead. Select a card to play.")
            end
        elseif has_suit(self._hands[SOUTH], trick.led) then
            self:_say_soft("Your turn. Play " .. SUIT_SINGULAR[trick.led] .. ".")
        else
            self:_say_soft("Your turn. You have no " .. SUIT_NAMES[trick.led] .. ": play any card.")
        end
    elseif trick.count == 0 then
        if self._tricks_played == 0 then
            self:_say_soft(NAMES[seat] .. " leads the 2 of Clubs.")
        else
            self:_say_soft(NAMES[seat] .. " leads.")
        end
    else
        self:_say_soft("Waiting for " .. NAMES[seat] .. "...")
    end
end

-- Returns nil when seat may play card now, else the reason (as shown on the status bar).
function HeartsGame:illegal_reason(seat, card)
    local hand = self._hands[seat]
    local trick = self._trick
    local suit = suit_of(card)

    if trick.count == 0 then
        if self._tricks_played == 0 then
            if card ~= TWO_CLUBS then return "You must lead the 2 of Clubs." end
            return nil
        end
        if suit == HEARTS and not self._hearts_broken and not only_hearts(hand) then
            return "Hearts have not been broken."
        end
        return nil
    end

    if suit ~= trick.led and has_suit(hand, trick.led) then
        return "You must follow suit."
    end
    if self._tricks_played == 0 and card_points(card) > 0 and not only_points(hand) then
        return "You can't play points on the first trick."
    end
    return nil
end

function HeartsGame:can_play(seat, card)
    return self:illegal_reason(seat, card) == nil
end

function HeartsGame:legal_cards(seat, out)
    out = out or {}
    local n = 0
    local hand = self._hands[seat]
    for i = 1, #hand do
        if self:illegal_reason(seat, hand[i]) == nil then
            n = n + 1
            out[n] = hand[i]
        end
    end
    for i = #out, n + 1, -1 do out[i] = nil end
    return out
end

function HeartsGame:play_card(seat, card)
    if self._phase ~= "play" or self._turn ~= seat then return false end
    local reason = self:illegal_reason(seat, card)
    if reason then return false, reason end
    if not remove_card(self._hands[seat], card) then return false end

    local trick = self._trick
    local n = trick.count + 1
    trick.count = n
    trick.cards[n] = card
    trick.seats[n] = seat
    self._played[card] = true

    local suit = suit_of(card)
    if n == 1 then
        trick.led = suit
    elseif suit ~= trick.led then
        self._void[seat][trick.led] = true
    end
    self:_event("play", seat, card)

    if suit == HEARTS and not self._hearts_broken then
        self._hearts_broken = true
        self:_say("Hearts are broken!", 1.8)
        self:_event("hearts_broken", seat, card)
        self:_sound("move")
    end
    if card == QUEEN then self:_event("queen_played", seat, card) end

    if n < 4 then
        self._turn = next_seat(seat)
        self._timer = self:_ai_delay()
        self:_turn_status()
        self:_event("turn", self._turn)
        return true
    end

    local best, winner, points = 0, trick.leader, 0
    for i = 1, 4 do
        local c = trick.cards[i]
        points = points + card_points(c)
        if suit_of(c) == trick.led and rank_of(c) > best then
            best, winner = rank_of(c), trick.seats[i]
        end
    end
    self._trick_winner = winner
    self._turn = nil
    self._phase = "trick"
    self._timer = self._fast and HOLD_TIME_FAST or HOLD_TIME

    local subject = winner == SOUTH and "You take" or (NAMES[winner] .. " takes")
    local has_queen = false
    for i = 1, 4 do
        if trick.cards[i] == QUEEN then has_queen = true end
    end
    if has_queen then
        self:_say(subject .. " the Queen of Spades!", 2.4)
    elseif points > 0 then
        self:_say(subject .. " the trick: " .. points .. (points == 1 and " heart." or " hearts."), 1.4)
    else
        self:_say(subject .. " the trick.", 1.2)
    end
    self:_event("trick", winner, points)
    return true
end

function HeartsGame:_collect_trick()
    local trick = self._trick
    local winner = self._trick_winner
    local taken = self._taken[winner]
    local points, hearts, queen = 0, 0, false

    for i = 1, trick.count do
        local card = trick.cards[i]
        taken[#taken + 1] = card
        local p = card_points(card)
        points = points + p
        if card == QUEEN then queen = true elseif p > 0 then hearts = hearts + 1 end
        local suit = suit_of(card)
        self._suit_played[suit] = self._suit_played[suit] + 1
    end

    self._points[winner] = self._points[winner] + points
    self._hearts_taken[winner] = self._hearts_taken[winner] + hearts
    self._tricks_won[winner] = self._tricks_won[winner] + 1
    self._tricks_played = self._tricks_played + 1
    trick.count, trick.led, trick.leader = 0, nil, winner
    self._trick_winner = nil

    self:_event("taken", winner, points)
    if queen then
        self._queen_taker = winner
        self:_event("queen", winner)
        if winner == SOUTH then self:_sound("lose") end
    end

    local total = 0
    for s = 1, 4 do total = total + self._points[s] end
    for s = 1, 4 do
        if self._shooter[s] and self._points[s] < total then self._shooter[s] = false end
        -- A computer player holding every point late in the hand goes for the moon.
        if not self._shooter[s] and (s ~= SOUTH or self._autoplay) and total >= 16
            and self._points[s] == total and self._tricks_played >= 8 then
            self._shooter[s] = true
        end
    end

    if self._tricks_played >= 13 then
        self:_end_hand()
        return
    end

    self._phase = "play"
    self._turn = winner
    self._timer = self:_ai_delay()
    self:_turn_status()
    self:_event("turn", winner)
end

function HeartsGame:_end_hand()
    local moon = nil
    for s = 1, 4 do
        if self._points[s] == 26 then moon = s end
    end

    local added = {}
    for s = 1, 4 do
        if moon then
            added[s] = s == moon and 0 or 26
        else
            added[s] = self._points[s]
        end
        self._totals[s] = self._totals[s] + added[s]
    end
    self._history[#self._history + 1] = {
        hand = self._hand_number,
        totals = { self._totals[1], self._totals[2], self._totals[3], self._totals[4] },
        added = added,
        moon = moon,
    }
    self._moon = moon

    local high, low = 0, math.huge
    for s = 1, 4 do
        high = math_max(high, self._totals[s])
        low = math_min(low, self._totals[s])
    end

    self._phase = "hand_end"
    self._timer = HAND_END_TIME
    self._turn = nil

    if moon then
        self._timer = MOON_TIME
        self:_say(moon == SOUTH and "You shot the moon! Everyone else takes 26 points." or (NAMES[moon] .. " shot the moon!"), MOON_TIME)
        self:_event("moon", moon)
        self:_sound(moon == SOUTH and "win" or "lose")
    else
        self:_say("The hand is over.", HAND_END_TIME)
    end

    if high >= END_SCORE then
        local winners = {}
        for s = 1, 4 do
            if self._totals[s] == low then winners[#winners + 1] = s end
        end
        self._winners = winners
        self._timer = self._timer + GAME_END_TIME
        local won = false
        for i = 1, #winners do
            if winners[i] == SOUTH then won = true end
        end
        self:_persist("hearts_played", (tonumber(self:_setting("hearts_played")) or 0) + 1)
        if won then
            self:_persist("hearts_highscore", (tonumber(self:_setting("hearts_highscore")) or 0) + 1)
        end
        self:_event("game_over", won)
        self:_sound(won and "win" or "lose")
        self:_say(self:_winner_text() .. " Game over.", self._timer + 1)
    end
end

function HeartsGame:_winner_text()
    local winners = self._winners
    if not winners then return "" end
    local names = {}
    for i = 1, #winners do names[i] = NAMES[winners[i]] end
    if #winners == 1 then
        return winners[1] == SOUTH and "You win!" or (names[1] .. " wins!")
    end
    return join_names(names) .. " share the win!"
end

function HeartsGame:update(dt)
    dt = dt or 0
    self._time = self._time + dt
    if self._pending_status and self._time >= self._status_hold then
        self._status = self._pending_status
        self._pending_status = nil
    end

    -- Menus and dialogs are modal, as in Windows: the table waits.
    if self._shell:is_modal() then return end

    local phase = self._phase
    if phase == "deal" then
        self._timer = self._timer - dt
        if self._timer <= 0 then self:_after_deal() end
    elseif phase == "pass" then
        if self._autoplay then
            local cards = self:_ai_pass(SOUTH)
            for i = 1, 3 do self:toggle_select(cards[i]) end
            self:pass_cards()
        end
    elseif phase == "received" then
        if self._autoplay then
            self._timer = self._timer - dt
            if self._timer <= 0 then self:accept_received() end
        end
    elseif phase == "play" then
        local seat = self._turn
        if seat ~= SOUTH or self._autoplay then
            self._timer = self._timer - dt
            local card = self:_thinking(seat, self._timer <= 0)
            if card and self._timer <= 0 then
                self._search_job = nil
                self:play_card(seat, card)
            end
        end
    elseif phase == "trick" then
        self._timer = self._timer - dt
        if self._timer <= 0 then
            self._phase = "sweep"
            self._timer = self._fast and SWEEP_TIME_FAST or SWEEP_TIME
            self._sweep_time = self._timer
            self:_event("sweep", self._trick_winner)
        end
    elseif phase == "sweep" then
        self._timer = self._timer - dt
        if self._timer <= 0 then self:_collect_trick() end
    elseif phase == "hand_end" then
        self._timer = self._timer - dt
        if self._timer <= 0 then
            self._phase = "score"
            self:_open_score(true)
        end
    end
end

-- Computer players -------------------------------------------------------------------------------

local mine = {}
local ctx = {}
local scratch_legal = {}

function HeartsGame:_moon_hand(hand)
    local strength, low, hearts, top = 0, 0, 0, 0
    for i = 1, #hand do
        local card = hand[i]
        local r = rank_of(card)
        if r >= 10 then strength = strength + r - 9 end
        if r <= 6 then low = low + 1 end
        if suit_of(card) == HEARTS then
            hearts = hearts + 1
            if r >= 12 then top = top + 1 end
        end
    end
    return hearts >= 6 and top >= 3 and low <= 2 and strength >= 30
end

-- Passing: dump the dangerous spades when short in spades, high hearts, and try to void a short
-- side suit; low cards and spades that guard the Queen stay.
function HeartsGame:_pass_danger(card, left, passes)
    local suit, r = suit_of(card), rank_of(card)
    local low_spades, has_queen = 0, false
    for i = 1, #left do
        local c = left[i]
        if c == QUEEN then
            has_queen = true
        elseif suit_of(c) == SPADES and rank_of(c) < 12 then
            low_spades = low_spades + 1
        end
    end

    if card == QUEEN then return low_spades >= 4 and 5 or 100 end
    if suit == SPADES then
        if r > 12 then
            if has_queen and low_spades >= 3 then return 12 + r end
            if not has_queen and low_spades >= 4 then return 10 + r end
            return 70 + r
        end
        return r - 12
    end
    if suit == HEARTS then
        if r >= 10 then return 40 + (r - 10) * 8 end
        return r * 2
    end

    local d = r * 3
    local count = suit_count(left, suit)
    if count <= passes then d = d + 28 + (passes - count) * 6 end
    if r <= 6 then d = d - 10 end
    return d
end

function HeartsGame:_ai_pass(seat)
    local hand = self._hands[seat]
    local left = {}
    for i = 1, #hand do left[i] = hand[i] end
    local chosen = {}

    local level = self:level_of(seat)
    if level < 5 and math_random() < MISTAKES[level] then
        Cards_shuffle(left)
        return { left[1], left[2], left[3] }
    end

    if self:_moon_hand(hand) then
        self._shooter[seat] = true
        table.sort(left, function(a, b)
            local ha, hb = suit_of(a) == HEARTS, suit_of(b) == HEARTS
            if ha ~= hb then return hb end
            return rank_of(a) < rank_of(b)
        end)
        return { left[1], left[2], left[3] }
    end

    for pick = 1, 3 do
        local best, best_i, best_d = nil, nil, -math.huge
        for i = 1, #left do
            local d = self:_pass_danger(left[i], left, 4 - pick) + math_random() * 0.5
            if d > best_d then best, best_i, best_d = left[i], i, d end
        end
        chosen[pick] = best
        table.remove(left, best_i)
    end
    return chosen
end

-- Cards of suit not yet played and not in the thinking player's hand, above and below rank.
function HeartsGame:_outstanding(suit, rank)
    local higher, lower = 0, 0
    for r = 2, 14 do
        local c = card_id(suit, r)
        if not mine[c] and not self._played[c] then
            if r > rank then higher = higher + 1 elseif r < rank then lower = lower + 1 end
        end
    end
    return higher, lower
end

-- A single other player holding every point so far, late enough to be a real moon attempt.
function HeartsGame:_moon_threat(seat)
    local holder, total = nil, 0
    for s = 1, 4 do
        if self._points[s] > 0 then
            if holder then return nil end
            holder = s
            total = self._points[s]
        end
    end
    if not holder or holder == seat then return nil end
    if total >= 14 or (self._tricks_played >= 6 and total >= 6) or (self._tricks_played >= 8 and total >= 3) then
        return holder
    end
    return nil
end

function HeartsGame:_played_in_trick(seat)
    local trick = self._trick
    for i = 1, trick.count do
        if trick.seats[i] == seat then return true end
    end
    return false
end

function HeartsGame:_ai_context(seat)
    for i = 1, 52 do mine[i] = false end
    local hand = self._hands[seat]
    for i = 1, #hand do mine[hand[i]] = true end

    local trick = self._trick
    ctx.seat = seat
    ctx.hand = hand
    ctx.count = trick.count
    ctx.led = trick.led
    ctx.first = self._tricks_played == 0
    ctx.last = trick.count == 3

    local points, best, winner = 0, 0, nil
    for i = 1, trick.count do
        local card = trick.cards[i]
        points = points + card_points(card)
        if suit_of(card) == trick.led and rank_of(card) > best then
            best, winner = rank_of(card), trick.seats[i]
        end
    end
    ctx.points, ctx.winner_rank, ctx.winner_seat = points, best, winner
    ctx.q_mine = mine[QUEEN]
    ctx.q_out = not mine[QUEEN] and not self._played[QUEEN]
    ctx.high_spades = mine[card_id(SPADES, 14)] or mine[card_id(SPADES, 13)]
    ctx.threat = self:_moon_threat(seat)

    local out = ctx.q_out and 13 or 0
    for r = 2, 14 do
        local c = card_id(HEARTS, r)
        if not mine[c] and not self._played[c] then out = out + 1 end
    end
    ctx.points_out = out
    return ctx
end

-- Returns the computer player's card, or nil while a search is still running.
function HeartsGame:_thinking(seat, late)
    local job = self._search_job
    if job and (job.seat ~= seat or job.tricks ~= self._tricks_played or job.count ~= self._trick.count) then
        self._search_job = nil
        job = nil
    end
    if job then
        if job.result then return job.result end
        job.result = self:_search_step(late and ROLLOUTS_WHEN_LATE or ROLLOUTS_PER_UPDATE)
        return job.result
    end

    local legal = self:legal_cards(seat, scratch_legal)
    local level = self:level_of(seat)
    if #legal == 1 or self._policy or level <= 5 then
        if not late then return nil end
        return self:_ai_choose(seat)
    end
    job = self:_search_start(seat, legal, SEARCH_SAMPLES[level])
    job.result = nil
    if math_random() < MISTAKES[level] then job.result = legal[math_random(1, #legal)] end
    return job.result
end

function HeartsGame:_ai_choose(seat)
    local legal = self:legal_cards(seat, scratch_legal)
    if #legal == 1 then return legal[1] end
    if self._policy then return self._policy(self, seat, legal) end

    local level = self:level_of(seat)
    if math_random() < MISTAKES[level] then return legal[math_random(1, #legal)] end
    if level > 5 then return self:_ai_search(seat, legal, SEARCH_SAMPLES[level]) end

    local c = self:_ai_context(seat)
    if self._shooter[seat] then return self:_ai_shoot(legal, c) end
    if c.count == 0 then return self:_ai_lead(legal, c) end
    if suit_of(legal[1]) == c.led then return self:_ai_follow(legal, c) end
    return self:_ai_discard(legal, c)
end

function HeartsGame:_voids_against(seat, suit)
    local n = 0
    for s = 1, 4 do
        if s ~= seat and self._void[s][suit] then n = n + 1 end
    end
    return n
end

function HeartsGame:_ai_lead(legal, c)
    if c.threat then
        -- Stop a moon: lead a heart nobody can beat, taking a point ourselves.
        local best = nil
        for i = 1, #legal do
            local card = legal[i]
            if suit_of(card) == HEARTS and self:_outstanding(HEARTS, rank_of(card)) == 0 then
                best = card
            end
        end
        if best then return best end
    end

    local best, best_score = legal[1], math.huge
    for i = 1, #legal do
        local card = legal[i]
        local suit, r = suit_of(card), rank_of(card)
        local higher, lower = self:_outstanding(suit, r)
        local voids = self:_voids_against(c.seat, suit)
        local score = r

        if higher + lower == 0 then
            score = score + (c.points_out > 0 and 60 or 0)
        elseif higher == 0 then
            score = score + 30 + voids * 8
        else
            if lower == 0 then score = score - 5 end
            score = score + voids * 3
        end

        if suit == SPADES then
            if card == QUEEN then
                score = score + 80
            elseif c.q_mine then
                score = score + 20
            elseif c.q_out then
                if r > 12 then
                    score = score + 45
                elseif c.high_spades then
                    score = score + 12
                else
                    score = score - 7
                end
            end
        elseif suit == HEARTS then
            score = score + 6
            if lower == 0 and higher > 0 then score = score - 6 end
        else
            local count = suit_count(c.hand, suit)
            if count <= 2 and r <= 10 then score = score - (3 - count) * 2 end
        end

        score = score + math_random() * 0.8
        if score < best_score then best, best_score = card, score end
    end
    return best
end

local function highest(list, avoid)
    local best = nil
    for i = 1, #list do
        local card = list[i]
        if card ~= avoid and (not best or rank_of(card) > rank_of(best)) then best = card end
    end
    return best
end

local function lowest(list, avoid)
    local best = nil
    for i = 1, #list do
        local card = list[i]
        if card ~= avoid and (not best or rank_of(card) < rank_of(best)) then best = card end
    end
    return best
end

function HeartsGame:_ai_follow(legal, c)
    local wr = c.winner_rank

    -- The would-be shooter is winning a trick with points: take it from them.
    if c.threat and c.winner_seat == c.threat and (c.points > 0 or c.led == HEARTS) then
        local beat = nil
        for i = 1, #legal do
            local card = legal[i]
            if rank_of(card) > wr and card ~= QUEEN and (not beat or rank_of(card) < rank_of(beat)) then beat = card end
        end
        if beat then return beat end
    end

    -- Somebody already played the King or Ace of Spades: drop the Queen on them.
    if c.led == SPADES and c.q_mine and wr > 12 and c.winner_seat ~= c.threat then return QUEEN end

    if c.last and c.points == 0 then
        return highest(legal, QUEEN) or legal[1]
    end

    local duck = nil
    for i = 1, #legal do
        local card = legal[i]
        local r = rank_of(card)
        if r < wr and card ~= QUEEN and (not duck or r > rank_of(duck)) then duck = card end
    end
    if duck then return duck end

    -- Every card wins so far.
    if c.last or c.first then return highest(legal, QUEEN) or legal[1] end

    local suit = c.led
    local safe = suit ~= HEARTS and not (suit == SPADES and c.q_out) and self._suit_played[suit] == 0
    if safe then
        local seat = c.seat
        for _ = c.count + 2, 4 do
            seat = next_seat(seat)
            if self._void[seat][suit] then safe = false end
        end
    end
    if safe then return highest(legal, QUEEN) or legal[1] end
    return lowest(legal, QUEEN) or legal[1]
end

function HeartsGame:_ai_discard(legal, c)
    local threat = c.threat
    if threat and (c.winner_seat == threat or not self:_played_in_trick(threat)) then
        local best = nil
        for i = 1, #legal do
            local card = legal[i]
            if card_points(card) == 0 and (not best or rank_of(card) > rank_of(best)) then best = card end
        end
        if best then return best end
    end

    for i = 1, #legal do
        if legal[i] == QUEEN then return QUEEN end
    end
    if c.q_out then
        local ace, king = card_id(SPADES, 14), card_id(SPADES, 13)
        for i = 1, #legal do
            if legal[i] == ace then return ace end
        end
        for i = 1, #legal do
            if legal[i] == king then return king end
        end
    end

    local heart = nil
    for i = 1, #legal do
        local card = legal[i]
        if suit_of(card) == HEARTS and (not heart or rank_of(card) > rank_of(heart)) then heart = card end
    end
    if heart then return heart end

    local best, best_score = legal[1], -math.huge
    for i = 1, #legal do
        local card = legal[i]
        local suit = suit_of(card)
        local score = rank_of(card)
        if suit_count(c.hand, suit) <= 2 then score = score + 4 end
        if suit == SPADES and c.q_mine and rank_of(card) < 12 then score = score - 10 end
        if score > best_score then best, best_score = card, score end
    end
    return best
end

-- Going for the moon: win every trick, keep points away from the others.
function HeartsGame:_ai_shoot(legal, c)
    if c.count == 0 then
        local best = nil
        for i = 1, #legal do
            local card = legal[i]
            if self:_outstanding(suit_of(card), rank_of(card)) == 0 and (not best or rank_of(card) > rank_of(best)) then
                best = card
            end
        end
        return best or highest(legal) or legal[1]
    end
    if suit_of(legal[1]) == c.led then
        local top = highest(legal)
        if rank_of(top) > c.winner_rank then return top end
        return lowest(legal)
    end
    local best = nil
    for i = 1, #legal do
        local card = legal[i]
        if card_points(card) == 0 and (not best or rank_of(card) < rank_of(best)) then best = card end
    end
    return best or lowest(legal) or legal[1]
end

-- Look-ahead -------------------------------------------------------------------------------------
-- Stronger players deal the cards they cannot see at random, consistent with what is public at the
-- table (cards played, suits a player has shown out of, hand sizes, and the three cards they passed
-- themselves), then play the rest of the hand out for every legal card and keep the card with the
-- best average result. Only these sampled hands are used, never the real hands of other players.

local SUIT, RANK, PTS = {}, {}, {}
for c = 1, 52 do
    SUIT[c] = suit_of(c)
    RANK[c] = rank_of(c)
    PTS[c] = card_points(c)
end
local ACE_SPADES, KING_SPADES = card_id(SPADES, 14), card_id(SPADES, 13)

local sample_hands = { {}, {}, {}, {} }
local sample_n = { 0, 0, 0, 0 }
local sim_hands = { {}, {}, {}, {} }
local sim_n = { 0, 0, 0, 0 }
local sim_points = { 0, 0, 0, 0 }
local sim = { count = 0, led = 0, best = 0, winner = 0, points = 0, leader = 1, tricks = 0, broken = false, queen_out = true }
local unknown = {}
local buckets = { {}, {}, {}, {} }
local owner = {}
local seen = {}
local capacity = { 0, 0, 0, 0 }

-- Picks a legal card for a sampled hand with a quick rule of thumb.
local function sim_choose(hand, n, seat)
    local count, led = sim.count, sim.led
    local has_led, only_hearts, only_points, has_queen = false, true, true, false
    for i = 1, n do
        local c = hand[i]
        if SUIT[c] == led then has_led = true end
        if SUIT[c] ~= HEARTS then only_hearts = false end
        if PTS[c] == 0 then only_points = false end
        if c == QUEEN then has_queen = true end
    end

    if count == 0 then
        if sim.tricks == 0 then
            for i = 1, n do
                if hand[i] == TWO_CLUBS then return TWO_CLUBS end
            end
        end
        local best, best_score = hand[1], math.huge
        for i = 1, n do
            local c = hand[i]
            local suit, r = SUIT[c], RANK[c]
            if suit ~= HEARTS or sim.broken or only_hearts then
                local score = r
                if suit == HEARTS then score = score + 6 end
                if suit == SPADES and sim.queen_out then
                    if c == QUEEN then score = score + 40 elseif r > 12 then score = score + 30 end
                end
                if score < best_score then best, best_score = c, score end
            end
        end
        return best
    end

    if has_led then
        local wr = sim.best
        if led == SPADES and has_queen and wr > 12 then return QUEEN end
        local duck, high, low = nil, nil, nil
        for i = 1, n do
            local c = hand[i]
            if SUIT[c] == led and c ~= QUEEN then
                local r = RANK[c]
                if r < wr and (not duck or r > RANK[duck]) then duck = c end
                if not high or r > RANK[high] then high = c end
                if not low or r < RANK[low] then low = c end
            end
        end
        if not high then return QUEEN end
        if count == 3 and sim.points == 0 then return high end
        if duck then return duck end
        if count == 3 then return high end
        if led == HEARTS or (led == SPADES and sim.queen_out) then return low end
        -- Every card wins so far: shed the highest unless a later player can dump points on it.
        local s = seat
        for _ = count + 2, 4 do
            s = s % 4 + 1
            local other, m = sim_hands[s], sim_n[s]
            local void, points = true, false
            for i = 1, m do
                local c = other[i]
                if SUIT[c] == led then
                    void = false
                    break
                end
                if PTS[c] > 0 then points = true end
            end
            if void and points then return low end
        end
        return high
    end

    -- Void in the led suit: dump the most dangerous card allowed.
    local first = sim.tricks == 0 and not only_points
    if has_queen and not first then return QUEEN end
    local best, best_score = nil, -math.huge
    for i = 1, n do
        local c = hand[i]
        if not (first and PTS[c] > 0) then
            local r = RANK[c]
            local score = r
            if SUIT[c] == HEARTS then score = score + 14 end
            if (c == ACE_SPADES or c == KING_SPADES) and sim.queen_out then score = score + 30 end
            if score > best_score then best, best_score = c, score end
        end
    end
    return best or hand[1]
end

local function sim_play(seat, card)
    local hand, n = sim_hands[seat], sim_n[seat]
    for i = 1, n do
        if hand[i] == card then
            hand[i] = hand[n]
            hand[n] = nil
            break
        end
    end
    sim_n[seat] = n - 1

    local count = sim.count + 1
    sim.count = count
    if count == 1 then
        sim.led, sim.best, sim.winner, sim.points = SUIT[card], RANK[card], seat, PTS[card]
    else
        sim.points = sim.points + PTS[card]
        if SUIT[card] == sim.led and RANK[card] > sim.best then
            sim.best, sim.winner = RANK[card], seat
        end
    end
    if SUIT[card] == HEARTS then sim.broken = true end
    if card == QUEEN then sim.queen_out = false end

    if count == 4 then
        sim_points[sim.winner] = sim_points[sim.winner] + sim.points
        sim.tricks = sim.tricks + 1
        sim.count = 0
        sim.leader = sim.winner
        return sim.winner
    end
    return seat % 4 + 1
end

-- Deals the unseen cards to the other players; false when the constraints could not be met.
function HeartsGame:_sample(seat, ignore_voids)
    local hand = self._hands[seat]
    for s = 1, 4 do
        sample_n[s] = 0
        capacity[s] = s == seat and 0 or #self._hands[s]
    end
    for i = 1, #hand do sample_hands[seat][i] = hand[i] end
    sample_n[seat] = #hand

    for c = 1, 52 do
        seen[c] = false
        owner[c] = nil
    end
    for i = 1, #hand do seen[hand[i]] = true end

    local passed = self._passed[seat]
    if passed and passed.to ~= seat then
        for i = 1, 3 do
            local c = passed.cards[i]
            if c and not self._played[c] and not seen[c] then owner[c] = passed.to end
        end
    end

    for b = 1, 4 do
        local list = buckets[b]
        for i = #list, 1, -1 do list[i] = nil end
    end

    for c = 1, 52 do
        if not seen[c] and not self._played[c] then
            local s = owner[c]
            if s then
                if capacity[s] <= 0 then return false end
                sample_n[s] = sample_n[s] + 1
                sample_hands[s][sample_n[s]] = c
                capacity[s] = capacity[s] - 1
            else
                local eligible = 0
                for o = 1, 4 do
                    if o ~= seat and capacity[o] > 0 and (ignore_voids or not self._void[o][SUIT[c]]) then eligible = eligible + 1 end
                end
                if eligible == 0 then return false end
                local list = buckets[eligible]
                list[#list + 1] = c
            end
        end
    end

    -- Most constrained cards first, random order within a group.
    for b = 1, 3 do
        local list = buckets[b]
        for i = #list, 2, -1 do
            local j = math_random(1, i)
            list[i], list[j] = list[j], list[i]
        end
        for i = 1, #list do
            local c = list[i]
            local total = 0
            for o = 1, 4 do
                if o ~= seat and capacity[o] > 0 and (ignore_voids or not self._void[o][SUIT[c]]) then total = total + capacity[o] end
            end
            if total == 0 then return false end
            local pick = math_random(1, total)
            for o = 1, 4 do
                if o ~= seat and capacity[o] > 0 and (ignore_voids or not self._void[o][SUIT[c]]) then
                    pick = pick - capacity[o]
                    if pick <= 0 then
                        sample_n[o] = sample_n[o] + 1
                        sample_hands[o][sample_n[o]] = c
                        capacity[o] = capacity[o] - 1
                        break
                    end
                end
            end
        end
    end

    for s = 1, 4 do
        if s ~= seat and capacity[s] ~= 0 then return false end
    end
    return true
end

-- Plays the hand out from the current table with `card` for `seat`; returns that seat's result
-- relative to the others' average, with shooting the moon applied.
function HeartsGame:_rollout(seat, card)
    for s = 1, 4 do
        local src, dst = sample_hands[s], sim_hands[s]
        local n = sample_n[s]
        for i = 1, n do dst[i] = src[i] end
        for i = #dst, n + 1, -1 do dst[i] = nil end
        sim_n[s] = n
        sim_points[s] = 0
    end

    local trick = self._trick
    sim.count = trick.count
    sim.led = trick.led or 0
    sim.best, sim.winner, sim.points = 0, 0, 0
    for i = 1, trick.count do
        local c = trick.cards[i]
        sim.points = sim.points + PTS[c]
        if SUIT[c] == sim.led and RANK[c] > sim.best then sim.best, sim.winner = RANK[c], trick.seats[i] end
    end
    sim.tricks = self._tricks_played
    sim.broken = self._hearts_broken
    sim.queen_out = not self._played[QUEEN]

    local turn = sim_play(seat, card)
    while sim.tricks < 13 do
        local n = sim_n[turn]
        if n == 0 then break end
        turn = sim_play(turn, sim_choose(sim_hands[turn], n, turn))
    end

    local moon = nil
    for s = 1, 4 do
        if self._points[s] + sim_points[s] == 26 then moon = s end
    end
    local mine, others = 0, 0
    for s = 1, 4 do
        local p
        if moon then p = s == moon and 0 or 26 else p = self._points[s] + sim_points[s] end
        if s == seat then mine = p else others = others + p end
    end
    return mine - others / 3
end

function HeartsGame:_holds(seat, card)
    local hand = self._hands[seat]
    for i = 1, #hand do
        if hand[i] == card then return true end
    end
    return false
end

local search_legal = {}
local search_total = {}

function HeartsGame:_search_start(seat, legal, samples)
    local job = self._search_job or { cards = {}, totals = {} }
    self._search_job = job
    job.seat, job.samples, job.done, job.next = seat, samples, 0, 1
    job.tricks, job.count = self._tricks_played, self._trick.count

    -- Cards of one suit with nothing unseen between them win and lose the same tricks: try one.
    local cards, totals = job.cards, job.totals
    local n = 0
    for i = 1, #legal do
        local card = legal[i]
        local same = false
        if card ~= QUEEN and SUIT[card] ~= HEARTS then
            for j = 1, n do
                local other = cards[j]
                if other ~= QUEEN and SUIT[other] == SUIT[card] then
                    local lo, hi = RANK[other], RANK[card]
                    if lo > hi then lo, hi = hi, lo end
                    same = true
                    for r = lo + 1, hi - 1 do
                        local c = card_id(SUIT[card], r)
                        if not self._played[c] and not self:_holds(seat, c) then
                            same = false
                            break
                        end
                    end
                    if same then break end
                end
            end
        end
        if not same then
            n = n + 1
            cards[n] = card
            totals[n] = 0
        end
    end
    for i = #cards, n + 1, -1 do
        cards[i] = nil
        totals[i] = nil
    end
    job.n = n
    job.sampled = false
    return job
end

-- Advances the job by up to `budget` play-outs; returns the chosen card when finished.
function HeartsGame:_search_step(budget)
    local job = self._search_job
    local n = job.n
    if n == 1 then return job.cards[1] end

    while budget > 0 and job.done < job.samples do
        if not job.sampled then
            local ok = false
            for _ = 1, 7 do
                ok = self:_sample(job.seat, false)
                if ok then break end
            end
            if not ok then ok = self:_sample(job.seat, true) end
            if not ok then
                job.done = job.done + 1
            else
                job.sampled = true
                job.next = 1
            end
        else
            local i = job.next
            job.totals[i] = job.totals[i] + self:_rollout(job.seat, job.cards[i])
            budget = budget - 1
            if i >= n then
                job.sampled = false
                job.done = job.done + 1
            else
                job.next = i + 1
            end
        end
    end

    if job.done < job.samples then return nil end

    local best, best_value = job.cards[1], math.huge
    for i = 1, n do
        local value = job.totals[i] + math_random() * 0.01
        if value < best_value then best, best_value = job.cards[i], value end
    end
    return best
end

-- Synchronous search, used when a card is needed at once.
function HeartsGame:_ai_search(seat, legal, samples)
    self:_search_start(seat, legal, samples)
    local card
    repeat card = self:_search_step(1000000) until card
    self._search_job = nil
    return card
end

-- Menus and dialogs ----------------------------------------------------------------------------

function HeartsGame:_command(id)
    local shell = self._shell
    if id == "new" then
        self:new_game()
    elseif id == "score" then
        if not shell:dialog() then self:_open_score(false) end
    elseif id == "exit" then
        self._close_requested = true
    elseif id == "dim" then
        self._dim = not self._dim
        self:_persist("hearts_dim", self._dim)
    elseif id == "fast" then
        self._fast = not self._fast
        self:_persist("hearts_fast", self._fast)
    elseif id == "deck" then
        self:_open_deck()
    elseif id == "difficulty" then
        self:_open_difficulty()
    elseif id == "how_to" then
        self:_open_text("how_to", "How to Play", 452, {
            "The goal is the lowest score when someone reaches 100 points.",
            "Each heart you take is 1 point; the Queen of Spades is 13.",
            "Before a hand, pass three cards: left, right, across, then none.",
            "The 2 of Clubs leads the first trick. Follow suit if you can.",
            "No hearts or Queen of Spades on the first trick if avoidable.",
            "Hearts can't be led until a heart has been played.",
            "Take all 26 points to shoot the moon: the others get 26 each.",
            "Mouse: click cards to select or play them.",
            "Keys: A/D choose a card, Space select/play, W/S the button,",
            "E pass or OK, R new game, 1 score sheet, Tab menu.",
        })
    elseif id == "about" then
        self:_open_text("about", "About Hearts", 330, {
            "Mourningstar Waiting Games edition",
            "A tribute to the Windows 95 classic.",
            "Pauline, Michele and Ben play for the",
            "honour of the auspex.",
        }, 60)
    end
end

function HeartsGame:_open_text(kind, title, w, lines, indent)
    indent = indent or 16
    local controls = {}
    local top = kind == "about" and 58 or 34
    if kind == "about" then
        controls[1] = { type = "label", label = "Hearts", x = indent, y = 30, w = w - indent - 16, h = 24, size = 16 }
    end
    for i = 1, #lines do
        controls[#controls + 1] = { type = "label", label = lines[i], x = indent, y = top + (i - 1) * 20, w = w - indent - 12, h = 20 }
    end
    self._shell:open_dialog({
        kind = kind, title = title, w = w, h = top + #lines * 20 + 56,
        controls = controls, buttons_align = "center",
        buttons = { { id = "ok", label = "OK", default = true } },
    })
end

function HeartsGame:_open_deck()
    local controls = {
        { type = "label", label = "Select a card back:", x = 16, y = 30, w = 200, h = 18 },
    }
    for i = 1, #BACKS do
        controls[#controls + 1] = {
            type = "tile", group = "back", value = BACKS[i].id, label = BACKS[i].name,
            x = 18 + (i - 1) * 58, y = 56, w = 48, h = 66,
        }
    end
    self._shell:open_dialog({
        kind = "deck", title = "Deck", w = 368, h = 196,
        values = { back = self._back },
        controls = controls,
        buttons = { { id = "ok", label = "OK", default = true }, { id = "cancel", label = "Cancel" } },
    })
end

function HeartsGame:_open_difficulty()
    local controls = {
        { type = "label", label = "How well should Pauline, Michele and Ben play?", x = 16, y = 30, w = 330, h = 18 },
    }
    for level = 1, 10 do
        local row = level <= 5 and 0 or 1
        controls[#controls + 1] = {
            type = "radio", group = "level", value = level, label = tostring(level),
            x = 22 + ((level - 1) % 5) * 64, y = 56 + row * 26, w = 56, h = 22,
        }
    end
    controls[#controls + 1] = { type = "label", label = "1-4: casual, with mistakes.   5: the classic players.", x = 16, y = 112, w = 330, h = 18 }
    controls[#controls + 1] = { type = "label", label = "6-10: they think ahead; 10 plays really well.", x = 16, y = 130, w = 330, h = 18 }
    controls[#controls + 1] = { type = "label", label = "They never look at your cards, at any level.", x = 16, y = 148, w = 330, h = 18 }
    self._shell:open_dialog({
        kind = "difficulty", title = "Difficulty", w = 348, h = 214,
        values = { level = self._level },
        controls = controls,
        buttons = { { id = "ok", label = "OK", default = true }, { id = "cancel", label = "Cancel" } },
    })
end

function HeartsGame:_open_score(hand_end)
    local rows = #self._history
    local shown = math_max(1, math_min(rows, SCORE_ROWS))
    local final = hand_end and self._winners ~= nil
    local message, detail

    if final then
        message = self:_winner_text()
        detail = "Game over after " .. rows .. (rows == 1 and " hand." or " hands.")
    elseif hand_end then
        local last = self._history[rows]
        if last and last.moon then
            message = last.moon == SOUTH and "You shot the moon!" or (NAMES[last.moon] .. " shot the moon!")
        else
            message = "Hand " .. self._hand_number .. " is over."
        end
        local dir = PASS_ORDER[self._hand_number % 4 + 1]
        detail = dir == "none" and "Next hand: no passing." or ("Next hand: pass " .. PASS_WORDS[dir] .. ".")
    elseif rows == 0 then
        message = "No hands have been completed yet."
        detail = "The first player to reach 100 points ends the game."
    else
        message = "Scores after hand " .. rows .. "."
        detail = "The first player to reach 100 points ends the game."
    end

    local buttons
    if final then
        buttons = { { id = "new", label = "New Game", w = 86 }, { id = "ok", label = "OK", default = true } }
    else
        buttons = { { id = "ok", label = "OK", default = true } }
    end

    self._shell:open_dialog({
        kind = "score", title = "Score Sheet", w = 392, h = 142 + shown * 17,
        hand_end = hand_end, final = final, message = message, detail = detail,
        rows_shown = shown, buttons = buttons, cancel_id = "ok",
    })
end

function HeartsGame:_dialog_button(dialog, id)
    if dialog.kind == "score" and dialog.hand_end then
        if id == "new" then
            self:new_game()
        elseif dialog.final then
            self._phase = "over"
            self:_say(self:_winner_text() .. " Click New Game to play again.")
        else
            self:_deal()
        end
    elseif dialog.kind == "difficulty" and id == "ok" then
        self._level = clamp(math_floor(tonumber(dialog.values.level) or self._level), 1, 10)
        self:_persist("hearts_level", self._level)
        self:_say("Computer players: level " .. self._level .. ".")
    elseif dialog.kind == "deck" and id == "ok" then
        local back = dialog.values.back
        for i = 1, #BACKS do
            if BACKS[i].id == back then
                self._back = back
                self:_persist("hearts_back", back)
            end
        end
    end
    return false
end

function HeartsGame:consume_close_request()
    local shell_requested = self._shell:consume_close_request()
    local requested = self._close_requested or shell_requested
    self._close_requested = false
    return requested
end

function HeartsGame:ui_back()
    return self._shell:ui_back()
end

-- Centre button --------------------------------------------------------------------------------

function HeartsGame:button_label()
    local phase = self._phase
    if phase == "pass" then return PASS_LABEL[self._pass_dir] end
    if phase == "received" then return "OK" end
    if phase == "over" then return "New Game" end
    return nil
end

function HeartsGame:button_enabled()
    if self._phase == "pass" then return self._selected_count == 3 end
    return self:button_label() ~= nil
end

function HeartsGame:press_button()
    local phase = self._phase
    if phase == "pass" then
        if self._selected_count == 3 then
            self:pass_cards()
        else
            self:_say("Select three cards to pass first.", 1.4)
        end
    elseif phase == "received" then
        self:accept_received()
    elseif phase == "over" then
        self:new_game()
    end
end

-- Input ------------------------------------------------------------------------------------------

function HeartsGame:_click_card(index)
    local hand = self._hands[SOUTH]
    local card = hand[index]
    if not card then return end
    self._focus = index
    self._focus_button = false

    local phase = self._phase
    if phase == "pass" then
        self:toggle_select(card)
    elseif phase == "received" then
        self:_say("Click OK to accept the cards you were passed.", 1.4)
    elseif phase == "play" then
        if self._turn ~= SOUTH or self._autoplay then
            self:_say("Please wait for your turn.", 1)
            return
        end
        local reason = self:illegal_reason(SOUTH, card)
        if reason then
            self:_say(reason, 2)
            self:_event("illegal", card)
        else
            self:play_card(SOUTH, card)
        end
    end
end

function HeartsGame:_move_focus(step)
    local n = #self._hands[SOUTH]
    self._cursor_mode = "keys"
    self._focus_button = false
    if n == 0 then return end
    self._focus = clamp(self._focus + step, 1, n)
end

function HeartsGame:key_press(key, is_repeat)
    local shell = self._shell
    if (key == "left" or key == "right" or key == "up" or key == "down" or key == "confirm" or key == "menu") and shell:key(key) then
        return
    end
    if key == "menu" then return end

    if key == "new" then
        local dialog = shell:dialog()
        if dialog and not (dialog.kind == "score" and dialog.final) then return end
        if not is_repeat then self:new_game() end
        return
    end
    if shell:is_modal() then return end

    local phase = self._phase
    if key == "left" or key == "right" then
        self:_move_focus(key == "left" and -1 or 1)
    elseif key == "up" then
        self._cursor_mode = "keys"
        if self:button_label() then self._focus_button = true end
    elseif key == "down" then
        self._cursor_mode = "keys"
        self._focus_button = false
    elseif key == "confirm" then
        if is_repeat then return end
        self._cursor_mode = "keys"
        if (self._focus_button and self:button_label()) or phase == "received" or phase == "over" then
            self:press_button()
        else
            local n = #self._hands[SOUTH]
            if n > 0 then self:_click_card(clamp(self._focus, 1, n)) end
        end
    elseif key == "alt" then
        if not is_repeat and self:button_label() then self:press_button() end
    elseif key == "1" then
        self:_command("score")
    end
end

function HeartsGame:key_hold(key, held)
end

function HeartsGame:pointer_input(x, y, input)
    if math_abs(x - self._pointer_x) + math_abs(y - self._pointer_y) > 0.5 then
        self._cursor_mode = "pointer"
    end
    self._pointer_x, self._pointer_y = x, y

    if self._shell:pointer(x, y, input) then
        self._hover_card, self._hover_button, self._button_press = nil, false, false
        return
    end

    if input.left_pressed or input.right_pressed then self._cursor_mode = "pointer" end
    local on_button = self:button_label() ~= nil and inside(self._layout.button, x, y)
    local index = not on_button and self:card_at(x, y) or nil
    self._hover_card, self._hover_button = index, on_button

    if input.left_pressed then
        if on_button then
            self._button_press = true
        elseif index then
            self:_click_card(index)
        end
    end
    if input.left_released then
        if self._button_press and on_button and self:button_enabled() then self:press_button() end
        self._button_press = false
    elseif not input.left then
        self._button_press = false
    end
end

-- Queries for the view and the mod ------------------------------------------------------------------

function HeartsGame:shell() return self._shell end
function HeartsGame:layout() return self._layout end
function HeartsGame:phase() return self._phase end
function HeartsGame:hand(seat) return self._hands[seat] end
function HeartsGame:trick() return self._trick end
function HeartsGame:trick_winner() return self._trick_winner end
function HeartsGame:turn() return self._turn end
function HeartsGame:name(seat) return NAMES[seat] end
function HeartsGame:total(seat) return self._totals[seat] end
function HeartsGame:points(seat) return self._points[seat] end
function HeartsGame:hearts_taken(seat) return self._hearts_taken[seat] end
function HeartsGame:tricks_won(seat) return self._tricks_won[seat] end
function HeartsGame:queen_taker() return self._queen_taker end
function HeartsGame:hearts_broken() return self._hearts_broken end
function HeartsGame:tricks_played() return self._tricks_played end
function HeartsGame:history() return self._history end
function HeartsGame:hand_number() return self._hand_number end
function HeartsGame:pass_dir() return self._pass_dir end
function HeartsGame:status_text() return self._status end
function HeartsGame:back() return self._back end
function HeartsGame:backs() return BACKS end
function HeartsGame:dim_enabled() return self._dim end
function HeartsGame:fast_enabled() return self._fast end
function HeartsGame:winners() return self._winners end
function HeartsGame:moon() return self._moon end
function HeartsGame:is_selected(card) return self._selected[card] == true end
function HeartsGame:selected_count() return self._selected_count end
function HeartsGame:is_received(card) return self._received[card] == true end
function HeartsGame:received_from() return self._received_from end
function HeartsGame:cursor_mode() return self._cursor_mode end
function HeartsGame:focus() return self._focus, self._focus_button end
function HeartsGame:hover() return self._hover_card, self._hover_button end
function HeartsGame:button_pressed() return self._button_press and self._hover_button end
function HeartsGame:time() return self._time end
function HeartsGame:is_game_over() return false end
function HeartsGame:level() return self._level end
function HeartsGame:level_of(seat)
    local levels = self._options.levels
    return levels and levels[seat] or self._level
end

function HeartsGame:phase_progress()
    if self._phase == "sweep" and self._sweep_time and self._sweep_time > 0 then
        return clamp(1 - self._timer / self._sweep_time, 0, 1)
    end
    if self._phase == "deal" then return clamp(1 - self._timer / DEAL_TIME, 0, 1) end
    return 0
end

-- Whether South's card at index reacts to the pointer (hover lift, click).
function HeartsGame:card_active(index)
    local card = self._hands[SOUTH][index]
    if not card or self._shell:is_modal() then return false end
    if self._phase == "pass" then return true end
    return self._phase == "play" and self._turn == SOUTH and not self._autoplay and self:can_play(SOUTH, card)
end

-- Illegal cards are dimmed on the player's turn when the option is on.
function HeartsGame:card_dimmed(card)
    return self._dim and self._phase == "play" and self._turn == SOUTH and not self._autoplay and not self:can_play(SOUTH, card)
end

function HeartsGame:summary()
    local parts = {}
    for s = 1, 4 do parts[s] = NAMES[s] .. " " .. self._totals[s] end
    local won = tonumber(self:_setting("hearts_highscore")) or 0
    local head = self._winners and (self:_winner_text() .. "  ") or ("Hand " .. math_max(1, self._hand_number) .. "  ")
    return "[Hearts] " .. head .. table.concat(parts, "  ") .. "  Games won: " .. won
end

return HeartsGame
