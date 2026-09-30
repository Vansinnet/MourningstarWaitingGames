-- Klondike Solitaire with Windows 95 rules, scoring, menus and dialogs.
-- Pure logic: layout, hit testing, drag state and the win cascade live here; the view only renders.
local mod = get_mod("MourningstarWaitingGames")
local Win95 = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_win95")

local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_random = math.random

local rect = Win95.rect
local inside = Win95.inside

-- Pile indices: stock, waste, four foundations (suit stacks), seven tableau columns.
local STOCK, WASTE = 1, 2
local FOUNDATION = 3
local TABLEAU = 7
local PILES = 13

local CARD_W, CARD_H = 66, 90
local CLIENT_W, CLIENT_H = 576, 470
local WINDOW_Y = 4
local TOP_MARGIN = 12
local ROW_GAP = 16
local DOWN_OFFSET = 5
local UP_OFFSET = 17
local MIN_UP_OFFSET = 8
local MIN_DOWN_OFFSET = 2
local FAN_OFFSET = 14
local BOTTOM_MARGIN = 6

local DOUBLE_CLICK = 0.45
local DRAG_THRESHOLD = 3
local AUTOPLAY_STEP = 0.12

local CASCADE_STEP = 1 / 60
local CASCADE_DELAY = 0.8
local GRAVITY = 1150
local BOUNCE = 0.74
local STAMP_CAP = 720
local STAMP_SPACING = 6

local BACKS = {
    { id = "blue", name = "Blue Weave" },
    { id = "red", name = "Red Weave" },
    { id = "aquila", name = "Aquila" },
    { id = "fish", name = "Fish" },
    { id = "castle", name = "Castle" },
    { id = "robot", name = "Robot" },
}
local BACK_NAMES = {}
for i = 1, #BACKS do BACK_NAMES[BACKS[i].id] = BACKS[i].name end

-- Keyboard cursor neighbours: top row order, the pile above each tableau column, the column below each top pile.
local TOP_ORDER = { STOCK, WASTE, FOUNDATION, FOUNDATION + 1, FOUNDATION + 2, FOUNDATION + 3 }
local ABOVE = { STOCK, WASTE, WASTE, FOUNDATION, FOUNDATION + 1, FOUNDATION + 2, FOUNDATION + 3 }
local BELOW = { [STOCK] = TABLEAU, [WASTE] = TABLEAU + 1, [FOUNDATION] = TABLEAU + 3,
    [FOUNDATION + 1] = TABLEAU + 4, [FOUNDATION + 2] = TABLEAU + 5, [FOUNDATION + 3] = TABLEAU + 6 }

local SolitaireGame = {}
SolitaireGame.__index = SolitaireGame

local function suit_of(card) return math_floor((card - 1) / 13) + 1 end
local function rank_of(card) return (card - 1) % 13 + 1 end
local function is_red(card)
    local s = suit_of(card)
    return s == 2 or s == 3
end

local function is_foundation(p) return p >= FOUNDATION and p < TABLEAU end
local function is_tableau(p) return p >= TABLEAU end

local function money(value)
    if value < 0 then return "-$" .. -value end
    return "$" .. value
end

-- options: get(key), set(key, value), on_sound(kind)
function SolitaireGame:new(options)
    local game = setmetatable({}, SolitaireGame)
    game._options = options or {}
    game._time = 0
    game._events = {}
    game._event_count = 0

    local get = game._options.get
    local function setting(key, default)
        if not get then return default end
        local value = get(key)
        if value == nil then return default end
        return value
    end

    game._draw = tonumber(setting("solitaire_draw", 3)) == 1 and 1 or 3
    local scoring = setting("solitaire_scoring", "standard")
    if scoring ~= "vegas" and scoring ~= "none" then scoring = "standard" end
    game._scoring = scoring
    game._timed = setting("solitaire_timed", true) == true
    game._status_bar = setting("solitaire_status_bar", true) == true
    game._outline = setting("solitaire_outline", false) == true
    game._keep_score = setting("solitaire_keep_score", false) == true
    local back = setting("solitaire_back", "blue")
    game._back = BACK_NAMES[back] and back or "blue"
    game._vegas_total = tonumber(setting("solitaire_vegas_score", 0)) or 0

    game._piles = {}
    for p = 1, PILES do game._piles[p] = {} end
    game._up = {}
    game._pos_x = {}
    game._pos_y = {}
    game._deal_order = {}
    game._score = 0
    game._elapsed = 0
    game._timer_running = false
    game._penalty_ticks = 0
    game._recycles = 0
    game._waste_fan = 0
    game._status = "playing"
    game._moves = 0
    game._bonus = 0
    game._new_best = false

    game._pointer_x = -1
    game._pointer_y = -1
    game._cursor_mode = "pointer"
    game._cursor = { pile = TABLEAU, depth = 1 }
    game._select = nil
    game._drag = nil
    game._press = nil
    game._last_click = { pile = nil, time = -10 }
    game._close_requested = false

    game._shell = Win95.shell({
        client_w = CLIENT_W,
        client_h = CLIENT_H,
        y = WINDOW_Y,
        status = game._status_bar,
        menus = {
            {
                id = "game", label = "Game", width = 180, items = {
                    { id = "deal", label = "Deal", key = "R" },
                    { separator = true },
                    { id = "undo", label = "Undo", key = "Q", enabled = function() return game:can_undo() end },
                    { id = "deck", label = "Deck..." },
                    { id = "options", label = "Options..." },
                    { separator = true },
                    { id = "exit", label = "Exit", key = "Esc" },
                },
            },
            {
                id = "help", label = "Help", width = 180, items = {
                    { id = "how_to", label = "How to Play..." },
                    { separator = true },
                    { id = "about", label = "About Solitaire..." },
                },
            },
        },
        on_command = function(id) game:_command(id) end,
        on_dialog = function(dialog, id) return game:_dialog_result(dialog, id) end,
    })

    game:_build_layout()
    return game
end

function SolitaireGame:start()
    self:deal()
end

-- Settings and events -----------------------------------------------------------

function SolitaireGame:_persist(key, value)
    local set = self._options.set
    if set then set(key, value) end
end

function SolitaireGame:_sound(kind)
    local on_sound = self._options.on_sound
    if on_sound then on_sound(kind) end
end

function SolitaireGame:_event(kind, a, b, c, d)
    local n = self._event_count + 1
    local e = self._events[n]
    if not e then
        e = {}
        self._events[n] = e
    end
    e.kind, e.a, e.b, e.c, e.d = kind, a, b, c, d
    self._event_count = n
end

function SolitaireGame:drain_events(callback)
    for i = 1, self._event_count do
        local e = self._events[i]
        callback(e.kind, e.a, e.b, e.c, e.d)
    end
    self._event_count = 0
end

function SolitaireGame:_save_vegas()
    if self._scoring == "vegas" and self._keep_score then
        self._vegas_total = self._score
        self:_persist("solitaire_vegas_score", self._score)
    end
end

function SolitaireGame:best_score()
    local get = self._options.get
    return tonumber(get and get("solitaire_highscore")) or 0
end

-- Layout ----------------------------------------------------------------------------

function SolitaireGame:_build_layout()
    local client = self._shell:layout().client
    local L = { client = client, card_w = CARD_W, card_h = CARD_H, piles = {}, columns = {} }
    local gap = (client.w - 7 * CARD_W) / 8

    for c = 0, 6 do
        L.columns[c] = math_floor(client.x + gap + c * (CARD_W + gap) + 0.5)
    end

    local top = client.y + TOP_MARGIN
    local row = top + CARD_H + ROW_GAP
    L.piles[STOCK] = rect(L.columns[0], top, CARD_W, CARD_H)
    L.piles[WASTE] = rect(L.columns[1], top, CARD_W, CARD_H)
    for f = 0, 3 do
        L.piles[FOUNDATION + f] = rect(L.columns[3 + f], top, CARD_W, CARD_H)
    end
    for c = 0, 6 do
        L.piles[TABLEAU + c] = rect(L.columns[c], row, CARD_W, CARD_H)
    end
    L.tableau_bottom = client.y + client.h - BOTTOM_MARGIN
    L.floor = client.y + client.h - CARD_H

    self._layout = L
    self:_relayout()
end

-- Recomputes where every card rests; the view animates towards these positions.
function SolitaireGame:_relayout()
    local L = self._layout
    local px, py, up = self._pos_x, self._pos_y, self._up

    for p = 1, PILES do
        local pile = self._piles[p]
        local base = L.piles[p]
        local n = #pile

        if p == WASTE then
            local fan = self._draw == 3 and math_min(math_max(self._waste_fan, 1), n, 3) or 1
            for i = 1, n do
                local k = i - (n - fan)
                px[pile[i]] = base.x + (k > 1 and (k - 1) * FAN_OFFSET or 0)
                py[pile[i]] = base.y
            end
        elseif is_tableau(p) then
            local downs, ups = 0, 0
            for i = 1, n - 1 do
                if up[pile[i]] then ups = ups + 1 else downs = downs + 1 end
            end
            local down_off, up_off = DOWN_OFFSET, UP_OFFSET
            local avail = L.tableau_bottom - base.y - CARD_H
            if downs * down_off + ups * up_off > avail and ups > 0 then
                up_off = math_max(MIN_UP_OFFSET, (avail - downs * down_off) / ups)
            end
            if downs * down_off + ups * up_off > avail and downs > 0 then
                down_off = math_max(MIN_DOWN_OFFSET, (avail - ups * up_off) / downs)
            end
            local y = base.y
            for i = 1, n do
                local card = pile[i]
                px[card] = base.x
                py[card] = math_floor(y + 0.5)
                y = y + (up[card] and up_off or down_off)
            end
        else
            for i = 1, n do
                px[pile[i]] = base.x
                py[pile[i]] = base.y
            end
        end
    end
end

-- Deal --------------------------------------------------------------------------------

function SolitaireGame:_end_interaction()
    self._select = nil
    self._drag = nil
    self._press = nil
    self._autoplay = nil
end

function SolitaireGame:deal()
    self:_end_interaction()
    self._cascade = nil

    local deck = {}
    for i = 1, 52 do deck[i] = i end
    for i = 52, 2, -1 do
        local j = math_random(1, i)
        deck[i], deck[j] = deck[j], deck[i]
    end

    for p = 1, PILES do
        local pile = self._piles[p]
        for i = #pile, 1, -1 do pile[i] = nil end
    end
    for c = 1, 52 do self._up[c] = false end

    local order = self._deal_order
    for i = #order, 1, -1 do order[i] = nil end

    local n = 52
    for row = 1, 7 do
        for col = row, 7 do
            local card = deck[n]
            n = n - 1
            local pile = self._piles[TABLEAU + col - 1]
            pile[#pile + 1] = card
            self._up[card] = col == row
            order[#order + 1] = card
        end
    end
    local stock = self._piles[STOCK]
    for i = 1, n do stock[i] = deck[i] end

    self._waste_fan = 0
    self._recycles = 0
    self._undo = nil
    self._status = "playing"
    self._elapsed = 0
    self._timer_running = false
    self._penalty_ticks = 0
    self._moves = 0
    self._bonus = 0
    self._new_best = false
    self._cursor.pile = TABLEAU
    self._cursor.depth = 1

    if self._scoring == "vegas" then
        self._score = (self._keep_score and self._vegas_total or 0) - 52
        self:_save_vegas()
    else
        self._score = 0
    end

    self:_relayout()
    self:_event("deal")
end

-- Rules ----------------------------------------------------------------------------------

function SolitaireGame:_can_pick(p, index)
    local pile = self._piles[p]
    local n = #pile
    if not index or index < 1 or index > n or p == STOCK then return false end
    if p == WASTE or is_foundation(p) then return index == n end
    return self._up[pile[index]] == true
end

-- True when the cards from index to the top of pile `from` may be placed on pile `to`.
function SolitaireGame:can_move(from, index, to)
    if from == to or not to or to < 1 or to > PILES then return false end
    if not self:_can_pick(from, index) then return false end

    local src = self._piles[from]
    local card = src[index]
    local dst = self._piles[to]
    local top = dst[#dst]

    if is_foundation(to) then
        if index ~= #src or is_foundation(from) then return false end
        if not top then return rank_of(card) == 1 end
        return suit_of(top) == suit_of(card) and rank_of(card) == rank_of(top) + 1
    elseif is_tableau(to) then
        if not top then return rank_of(card) == 13 end
        if not self._up[top] then return false end
        return is_red(top) ~= is_red(card) and rank_of(card) == rank_of(top) - 1
    end
    return false
end

function SolitaireGame:_passes()
    return self._draw == 1 and 1 or 3
end

function SolitaireGame:can_recycle()
    if #self._piles[STOCK] > 0 or #self._piles[WASTE] == 0 then return false end
    return self._scoring ~= "vegas" or self._recycles < self:_passes() - 1
end

-- What the empty stock slot shows: a ring while the waste can be turned over, a cross when not.
function SolitaireGame:stock_mark()
    if #self._piles[STOCK] > 0 then return nil end
    if self._scoring == "vegas" and self._recycles >= self:_passes() - 1 then return "empty" end
    return "recycle"
end

function SolitaireGame:passes_left()
    if self._scoring ~= "vegas" then return nil end
    return math_max(0, self:_passes() - self._recycles - 1)
end

function SolitaireGame:_start_timer()
    if self._status == "playing" then self._timer_running = true end
end

function SolitaireGame:_add_score(delta, pile)
    if self._scoring == "none" or delta == 0 then return end
    self._score = self._score + delta
    if self._scoring == "standard" and self._score < 0 then self._score = 0 end
    if self._scoring == "vegas" then self:_save_vegas() end
    self:_event("score", delta, pile)
end

function SolitaireGame:_move_score(from, to)
    if self._scoring == "standard" then
        if is_foundation(to) then return 10 end
        if is_tableau(to) and from == WASTE then return 5 end
        if is_tableau(to) and is_foundation(from) then return -15 end
    elseif self._scoring == "vegas" then
        if is_foundation(to) then return 5 end
        if is_foundation(from) then return -5 end
    end
    return 0
end

-- Undo keeps one level, like Windows: the whole table, the score and the stock passes.
function SolitaireGame:_snapshot()
    local s = { piles = {}, up = {} }
    for p = 1, PILES do
        local src, dst = self._piles[p], {}
        for i = 1, #src do dst[i] = src[i] end
        s.piles[p] = dst
    end
    for c = 1, 52 do s.up[c] = self._up[c] end
    s.score = self._score
    s.waste_fan = self._waste_fan
    s.recycles = self._recycles
    self._undo = s
end

function SolitaireGame:can_undo()
    return self._undo ~= nil and self._status == "playing" and not self._cascade
end

function SolitaireGame:undo()
    if not self:can_undo() then return false end
    local s = self._undo
    self:_end_interaction()
    for p = 1, PILES do
        local pile, saved = self._piles[p], s.piles[p]
        for i = #pile, 1, -1 do pile[i] = nil end
        for i = 1, #saved do pile[i] = saved[i] end
    end
    for c = 1, 52 do self._up[c] = s.up[c] end
    self._score = s.score
    self._waste_fan = s.waste_fan
    self._recycles = s.recycles
    self._undo = nil
    self:_save_vegas()
    self:_relayout()
    self:_event("undo")
    return true
end

-- Moves the cards from index to the top of `from` onto `to`. Returns false if illegal.
function SolitaireGame:move(from, index, to, no_snapshot)
    if self._status ~= "playing" or not self:can_move(from, index, to) then return false end
    if not no_snapshot then self:_snapshot() end

    local src, dst = self._piles[from], self._piles[to]
    local count = #src - index + 1
    local first = src[index]
    for i = index, #src do dst[#dst + 1] = src[i] end
    for i = #src, index, -1 do src[i] = nil end

    if from == WASTE then
        self._waste_fan = #src > 0 and math_max(1, self._waste_fan - 1) or 0
    end

    self._moves = self._moves + 1
    self:_start_timer()
    self:_relayout()
    self:_event("move", from, to, count, first)
    self:_add_score(self:_move_score(from, to), to)
    -- An autoplay chain blips once, not for every card.
    if not no_snapshot then self:_sound("move") end
    self:_check_win()
    return true
end

-- Turns over the face-down top card of a tableau column.
function SolitaireGame:flip(p)
    if self._status ~= "playing" or not is_tableau(p) then return false end
    local pile = self._piles[p]
    local card = pile[#pile]
    if not card or self._up[card] then return false end

    self:_snapshot()
    self._up[card] = true
    self:_start_timer()
    self:_relayout()
    self:_event("flip", p, card)
    if self._scoring == "standard" then self:_add_score(5, p) end
    return true
end

-- Deals one or three cards to the waste, or turns the waste over when the stock is empty.
function SolitaireGame:stock_click()
    if self._status ~= "playing" then return false end
    local stock, waste = self._piles[STOCK], self._piles[WASTE]

    if #stock > 0 then
        self:_snapshot()
        local n = math_min(self._draw, #stock)
        for _ = 1, n do
            local card = stock[#stock]
            stock[#stock] = nil
            waste[#waste + 1] = card
            self._up[card] = true
        end
        self._waste_fan = n
        self:_start_timer()
        self:_relayout()
        self:_event("stock", n)
        return true
    end

    if not self:can_recycle() then return false end

    self:_snapshot()
    for i = #waste, 1, -1 do
        local card = waste[i]
        stock[#stock + 1] = card
        self._up[card] = false
        waste[i] = nil
    end
    self._recycles = self._recycles + 1
    self._waste_fan = 0
    self:_start_timer()
    self:_relayout()
    self:_event("recycle")
    if self._scoring == "standard" then self:_add_score(self._draw == 1 and -100 or -20, STOCK) end
    self:_sound("move")
    return true
end

-- Sends the top card of pile p to a suit stack (double-click behaviour).
function SolitaireGame:send_to_foundation(p)
    if self._status ~= "playing" or not p or is_foundation(p) then return false end
    local n = #self._piles[p]
    if n == 0 then return false end
    for f = FOUNDATION, FOUNDATION + 3 do
        if self:can_move(p, n, f) then
            return self:move(p, n, f)
        end
    end
    return false
end

-- The next card that can go up during right-click autoplay: lowest rank first.
function SolitaireGame:_foundation_candidate()
    local best_from, best_to, best_rank
    for p = WASTE, PILES do
        if not is_foundation(p) then
            local pile = self._piles[p]
            local n = #pile
            if n > 0 and self._up[pile[n]] then
                local rank = rank_of(pile[n])
                if not best_rank or rank < best_rank then
                    for f = FOUNDATION, FOUNDATION + 3 do
                        if self:can_move(p, n, f) then
                            best_from, best_to, best_rank = p, f, rank
                            break
                        end
                    end
                end
            end
        end
    end
    return best_from, best_to
end

function SolitaireGame:autoplay()
    if self._status ~= "playing" or self._autoplay then return false end
    if not self:_foundation_candidate() then return false end
    self._autoplay = { timer = 0, first = true }
    return true
end

function SolitaireGame:_update_autoplay(dt)
    local ap = self._autoplay
    if not ap or self._drag or self._select then return end
    ap.timer = ap.timer - dt
    if ap.timer > 0 then return end

    local from, to = self:_foundation_candidate()
    if not from or self._status ~= "playing" then
        self._autoplay = nil
        return
    end
    self:move(from, #self._piles[from], to, not ap.first)
    ap.first = false
    ap.timer = AUTOPLAY_STEP
end

function SolitaireGame:_check_win()
    for f = FOUNDATION, FOUNDATION + 3 do
        if #self._piles[f] < 13 then return end
    end

    self._status = "won"
    self._timer_running = false
    self:_end_interaction()
    self._undo = nil

    local seconds = self:time_value()
    self._bonus = 0
    if self._scoring == "standard" and self._timed and seconds >= 30 then
        self._bonus = math_floor(700000 / seconds)
        self._score = self._score + self._bonus
    end

    if self._scoring == "standard" and self._score > self:best_score() then
        self._new_best = true
        self:_persist("solitaire_highscore", self._score)
    end

    self:_start_cascade()
    self:_event("win", self._bonus)
    self:_sound("win")
end

-- Timer -----------------------------------------------------------------------------------

function SolitaireGame:update(dt)
    dt = dt or 0
    self._time = self._time + dt

    if self._status == "playing" and self._timer_running and not self._shell:dialog() then
        self._elapsed = self._elapsed + dt
        local ticks = math_floor(self._elapsed / 10)
        while self._penalty_ticks < ticks do
            self._penalty_ticks = self._penalty_ticks + 1
            if self._timed and self._scoring == "standard" and self._score > 0 then
                self._score = math_max(0, self._score - 2)
            end
        end
    end

    -- Dialogs are modal: autoplay and the cascade wait behind them.
    if not self._shell:dialog() then
        self:_update_autoplay(dt)
        self:_update_cascade(dt)
    end
end

function SolitaireGame:time_value()
    return math_floor(self._elapsed)
end

-- Win cascade -------------------------------------------------------------------------------

function SolitaireGame:_start_cascade()
    local c = {
        order = {}, hidden = {}, next = 1, card = nil, delay = CASCADE_DELAY, acc = 0, done = false,
        stamp_card = {}, stamp_x = {}, stamp_y = {}, stamp_count = 0, stamp_head = 0, cap = STAMP_CAP,
        launched = 0,
    }
    for rank = 13, 1, -1 do
        for f = FOUNDATION, FOUNDATION + 3 do
            c.order[#c.order + 1] = self._piles[f][rank]
        end
    end
    self._cascade = c
end

function SolitaireGame:_stamp(c)
    local head = c.stamp_head % c.cap + 1
    c.stamp_head = head
    c.stamp_card[head], c.stamp_x[head], c.stamp_y[head] = c.card, c.x, c.y
    if c.stamp_count < c.cap then c.stamp_count = c.stamp_count + 1 end
    c.last_x, c.last_y = c.x, c.y
end

function SolitaireGame:_cascade_step(c)
    local L = self._layout
    local client = L.client

    if not c.card then
        if c.next > #c.order then
            self:_finish_cascade()
            return
        end
        local card = c.order[c.next]
        c.next = c.next + 1
        c.launched = c.launched + 1
        c.card = card
        c.hidden[card] = true
        c.x, c.y = self._pos_x[card], self._pos_y[card]
        local speed = 130 + math_random() * 190
        c.vx = math_random() < 0.5 and -speed or speed
        c.vy = -math_random() * 360
        self:_stamp(c)
        self:_event("launch", card)
        return
    end

    local h = CASCADE_STEP
    c.vy = c.vy + GRAVITY * h
    c.x = c.x + c.vx * h
    c.y = c.y + c.vy * h
    if c.y > L.floor then
        c.y = L.floor
        c.vy = -c.vy * BOUNCE
        if c.vy > -60 then c.vy = -60 - math_random() * 40 end
        self:_event("bounce", c.x + CARD_W * 0.5, c.y + CARD_H, c.card)
    end

    if c.x + CARD_W < client.x or c.x > client.x + client.w then
        c.card = nil
        return
    end

    local dx, dy = c.x - c.last_x, c.y - c.last_y
    if dx * dx + dy * dy >= STAMP_SPACING * STAMP_SPACING then self:_stamp(c) end
end

function SolitaireGame:_update_cascade(dt)
    local c = self._cascade
    if not c or c.done then return end

    if c.delay > 0 then
        c.delay = c.delay - dt
        return
    end

    c.acc = math_min(c.acc + dt, 0.1)
    while c.acc >= CASCADE_STEP and self._cascade == c and not c.done do
        c.acc = c.acc - CASCADE_STEP
        self:_cascade_step(c)
    end
end

-- Ends the cascade (or skips it) and asks to deal again; the trail stays behind the dialog.
function SolitaireGame:_finish_cascade()
    local c = self._cascade
    if not c or c.done then return end
    c.done = true
    c.card = nil
    for card in pairs(c.hidden) do c.hidden[card] = nil end
    self:_event("cascade_end")
    self._shell:open_dialog({
        kind = "again", title = "Solitaire", w = 270, h = 138,
        buttons = { { id = "yes", label = "Yes", default = true }, { id = "no", label = "No" } },
        buttons_align = "center", cancel_id = "no",
    })
end

-- Commands and dialogs -------------------------------------------------------------------------

function SolitaireGame:_command(id)
    if id == "deal" then
        self:deal()
    elseif id == "undo" then
        self:undo()
    elseif id == "deck" then
        self:_open_deck()
    elseif id == "options" then
        self:_open_options()
    elseif id == "exit" then
        self._close_requested = true
    elseif id == "how_to" then
        self._shell:open_dialog({ kind = "how_to", title = "How to Play", w = 420, h = 312, buttons_align = "center" })
    elseif id == "about" then
        self._shell:open_dialog({ kind = "about", title = "About Solitaire", w = 340, h = 176, buttons_align = "center" })
    end
end

function SolitaireGame:_open_options()
    local function vegas(values) return values.scoring == "vegas" end
    self._shell:open_dialog({
        kind = "options", title = "Options", w = 340, h = 236,
        values = {
            draw = self._draw, scoring = self._scoring, timed = self._timed,
            status = self._status_bar, outline = self._outline, keep = self._keep_score,
        },
        controls = {
            { type = "group", label = "Draw", x = 12, y = 30, w = 150, h = 74 },
            { type = "radio", group = "draw", value = 1, label = "Draw One", x = 24, y = 50, w = 128 },
            { type = "radio", group = "draw", value = 3, label = "Draw Three", x = 24, y = 74, w = 128 },
            { type = "group", label = "Scoring", x = 174, y = 30, w = 154, h = 98 },
            { type = "radio", group = "scoring", value = "standard", label = "Standard", x = 186, y = 50, w = 130 },
            { type = "radio", group = "scoring", value = "vegas", label = "Vegas", x = 186, y = 74, w = 130 },
            { type = "radio", group = "scoring", value = "none", label = "None", x = 186, y = 98, w = 130 },
            { type = "check", id = "timed", label = "Timed game", x = 16, y = 112, w = 150 },
            { type = "check", id = "status", label = "Status bar", x = 16, y = 136, w = 150 },
            { type = "check", id = "outline", label = "Outline dragging", x = 16, y = 160, w = 150 },
            { type = "check", id = "keep", label = "Keep score", x = 178, y = 136, w = 140, enabled = vegas },
        },
        buttons = { { id = "ok", label = "OK", default = true }, { id = "cancel", label = "Cancel" } },
    })
end

function SolitaireGame:_open_deck()
    local controls = {}
    for i = 1, #BACKS do
        controls[i] = { type = "tile", group = "back", value = BACKS[i].id, label = BACKS[i].name,
            x = 20 + (i - 1) * 64, y = 36, w = 54, h = 74 }
    end
    self._shell:open_dialog({
        kind = "deck", title = "Select Card Back", w = 422, h = 186,
        values = { back = self._back },
        controls = controls,
        buttons = { { id = "ok", label = "OK", default = true }, { id = "cancel", label = "Cancel" } },
    })
    -- Start keyboard focus on the current back, like Windows.
    local D = self._shell:layout().dialog
    for i = 1, #D.focus_list do
        local f = D.focus_list[i]
        if f.kind == "control" and D.controls[f.index].spec.value == self._back then
            self._shell:dialog().focus = i
        end
    end
end

function SolitaireGame:_apply_options(v)
    local draw = v.draw == 1 and 1 or 3
    local scoring = v.scoring
    if scoring ~= "vegas" and scoring ~= "none" then scoring = "standard" end
    local redeal = draw ~= self._draw or scoring ~= self._scoring

    self._draw = draw
    self._scoring = scoring
    self._timed = v.timed and true or false
    self._outline = v.outline and true or false
    self:_persist("solitaire_draw", draw)
    self:_persist("solitaire_scoring", scoring)
    self:_persist("solitaire_timed", self._timed)
    self:_persist("solitaire_outline", self._outline)

    local status = v.status and true or false
    if status ~= self._status_bar then
        self._status_bar = status
        self._shell:set_status(status)
        self:_build_layout()
        self:_persist("solitaire_status_bar", status)
    end

    -- Turning Keep score on carries the running Vegas score; otherwise the tally starts from zero.
    local keep = v.keep and true or false
    if keep ~= self._keep_score then
        self._keep_score = keep
        self:_persist("solitaire_keep_score", keep)
        if keep and not redeal then
            self:_save_vegas()
        else
            self._vegas_total = 0
            self:_persist("solitaire_vegas_score", 0)
        end
    end

    if redeal then self:deal() end
end

function SolitaireGame:set_back(id)
    if not BACK_NAMES[id] then return end
    self._back = id
    self:_persist("solitaire_back", id)
end

function SolitaireGame:_dialog_result(dialog, id)
    local kind = dialog.kind
    if kind == "options" and id == "ok" then
        self:_apply_options(dialog.values)
    elseif kind == "deck" and id == "ok" then
        self:set_back(dialog.values.back)
    elseif kind == "again" then
        self._cascade = nil
        if id == "yes" then self:deal() end
    end
    return false
end

function SolitaireGame:consume_close_request()
    local requested = self._close_requested or self._shell:consume_close_request()
    self._close_requested = false
    return requested
end

-- Returns true when Esc closed something instead of the game.
function SolitaireGame:ui_back()
    if self._shell:ui_back() then
        self._drag = nil
        return true
    end
    if self._cascade and not self._cascade.done then
        self:_finish_cascade()
        return true
    end
    if self._drag and self._drag.active then
        self._drag = nil
        self._press = nil
        self:_event("return")
        return true
    end
    if self._select then
        self._select = nil
        self:_event("return")
        return true
    end
    return false
end

-- Keyboard and controller --------------------------------------------------------------------

function SolitaireGame:_run_length(p)
    local pile = self._piles[p]
    local n = 0
    for i = #pile, 1, -1 do
        if not self._up[pile[i]] then break end
        n = n + 1
    end
    return n
end

function SolitaireGame:_cursor_depth()
    local c = self._cursor
    if not is_tableau(c.pile) then return 1 end
    return math_max(1, math_min(c.depth, self:_run_length(c.pile)))
end

function SolitaireGame:_cursor_step(dx, dy)
    local c = self._cursor
    local p = c.pile
    local holding = self._select ~= nil
    c.depth = self:_cursor_depth()

    if dx ~= 0 then
        if is_tableau(p) then
            c.pile = TABLEAU + (p - TABLEAU + dx) % 7
        else
            local at = 1
            for i = 1, #TOP_ORDER do
                if TOP_ORDER[i] == p then at = i end
            end
            c.pile = TOP_ORDER[(at - 1 + dx) % #TOP_ORDER + 1]
        end
        c.depth = 1
    elseif dy < 0 then
        if is_tableau(p) then
            if not holding and c.depth < self:_run_length(p) then
                c.depth = c.depth + 1
            else
                c.pile = ABOVE[p - TABLEAU + 1]
                c.depth = 1
            end
        end
    elseif dy > 0 then
        if not is_tableau(p) then
            c.pile = BELOW[p]
            c.depth = 1
        elseif not holding and c.depth > 1 then
            c.depth = c.depth - 1
        end
    end
end

function SolitaireGame:_key_confirm()
    local c = self._cursor
    local p = c.pile
    local sel = self._select

    if sel then
        self._select = nil
        if sel.pile == p then
            self:_event("return")
        elseif not self:move(sel.pile, sel.index, p) then
            self:_event("return")
            self:_event("invalid", p)
        end
        c.depth = 1
        return
    end

    if p == STOCK then
        self:stock_click()
        return
    end

    local pile = self._piles[p]
    local n = #pile
    if n == 0 then return end
    if not self._up[pile[n]] then
        self:flip(p)
        return
    end

    local index = n - self:_cursor_depth() + 1
    if self:_can_pick(p, index) then
        self._select = { pile = p, index = index }
        self:_event("pickup", p, index)
    end
end

function SolitaireGame:_key_alt()
    local sel = self._select
    if sel then
        self._select = nil
        if sel.index ~= #self._piles[sel.pile] or not self:send_to_foundation(sel.pile) then
            self:_event("return")
        end
        return
    end
    local p = self._cursor.pile
    if p == STOCK then p = WASTE end
    self:send_to_foundation(p)
end

-- key: left, right, up, down, confirm, alt, new, undo, menu, 1-4.
function SolitaireGame:key_press(key, is_repeat)
    if self._cascade and not self._cascade.done then
        if not is_repeat then self:_finish_cascade() end
        return
    end

    if key == "left" or key == "right" or key == "up" or key == "down" or key == "confirm" or key == "menu" then
        if self._shell:key(key) then
            self._drag = nil
            return
        end
    end

    if self._shell:dialog() then return end

    if key == "new" then
        if self._shell:menu() then self._shell:close_menu() end
        self:deal()
        return
    elseif key == "undo" then
        if self._shell:menu() then self._shell:close_menu() end
        self:undo()
        return
    end

    if self._shell:menu() or self._drag or self._status ~= "playing" then return end

    self._cursor_mode = "keys"
    if key == "left" then
        self:_cursor_step(-1, 0)
    elseif key == "right" then
        self:_cursor_step(1, 0)
    elseif key == "up" then
        self:_cursor_step(0, -1)
    elseif key == "down" then
        self:_cursor_step(0, 1)
    elseif key == "confirm" and not is_repeat then
        self:_key_confirm()
    elseif key == "alt" and not is_repeat then
        self:_key_alt()
    end
end

function SolitaireGame:key_hold(key, held)
end

-- Pointer ---------------------------------------------------------------------------------------

-- Topmost card of pile p under the point: its index, 0 for the empty slot, nil if missed.
function SolitaireGame:_hit_pile(p, x, y)
    local pile = self._piles[p]
    local px, py = self._pos_x, self._pos_y
    for i = #pile, 1, -1 do
        local card = pile[i]
        local cx, cy = px[card], py[card]
        if x >= cx and y >= cy and x < cx + CARD_W and y < cy + CARD_H then return i end
    end
    if inside(self._layout.piles[p], x, y) then return 0 end
    return nil
end

function SolitaireGame:hit_test(x, y)
    if not inside(self._layout.client, x, y) then return nil end
    for p = 1, PILES do
        local i = self:_hit_pile(p, x, y)
        if i then return p, i end
    end
    return nil
end

-- Where a dragged stack may land: the top card (or empty slot) of the pile, a little taller.
function SolitaireGame:_drop_rect(p)
    local pile = self._piles[p]
    local top = pile[#pile]
    if top then
        return self._pos_x[top], self._pos_y[top], CARD_W, CARD_H + (is_tableau(p) and 24 or 0)
    end
    local r = self._layout.piles[p]
    return r.x, r.y, r.w, r.h + (is_tableau(p) and 24 or 0)
end

-- The legal pile the dragged cards overlap most.
function SolitaireGame:_drop_target(d)
    local best, best_area = nil, 0
    for p = 1, PILES do
        if p ~= d.pile and self:can_move(d.pile, d.index, p) then
            local rx, ry, rw, rh = self:_drop_rect(p)
            local w = math_min(d.x + CARD_W, rx + rw) - math_max(d.x, rx)
            local h = math_min(d.y + CARD_H, ry + rh) - math_max(d.y, ry)
            if w > 0 and h > 0 and w * h > best_area then
                best, best_area = p, w * h
            end
        end
    end
    return best
end

function SolitaireGame:_pointer_press(x, y)
    local p, i = self:hit_test(x, y)
    local press = self._press or {}
    press.pile, press.index, press.x, press.y = p, i, x, y
    self._press = press
    self._drag = nil

    if p and i and i > 0 and self:_can_pick(p, i) then
        local card = self._piles[p][i]
        self._drag = {
            pile = p, index = i, card = card, active = false,
            grab_x = x - self._pos_x[card], grab_y = y - self._pos_y[card],
            x = self._pos_x[card], y = self._pos_y[card], target = nil,
        }
    end
end

function SolitaireGame:_pointer_move(x, y)
    local d = self._drag
    if not d then return end
    local press = self._press
    if not d.active then
        if not press or math_abs(x - press.x) + math_abs(y - press.y) < DRAG_THRESHOLD then return end
        -- The table may have changed under a pending press (autoplay, undo).
        if self._piles[d.pile][d.index] ~= d.card or not self:_can_pick(d.pile, d.index) then
            self._drag = nil
            return
        end
        d.active = true
        self._select = nil
        self:_event("pickup", d.pile, d.index)
    end
    d.x, d.y = x - d.grab_x, y - d.grab_y
    d.target = self:_drop_target(d)
end

function SolitaireGame:_click(p, i)
    local now = self._time
    local last = self._last_click
    local double = last.pile == p and now - last.time <= DOUBLE_CLICK
    last.pile, last.time = p, now
    if double then last.pile = nil end

    local pile = self._piles[p]
    local n = #pile
    local sel = self._select

    if sel then
        self._select = nil
        if sel.pile == p then
            if double and self:send_to_foundation(p) then return end
            if not double and i and i > 0 and i ~= sel.index and self:_can_pick(p, i) then
                self._select = { pile = p, index = i }
                self:_event("pickup", p, i)
                return
            end
            self:_event("return")
            return
        end
        if self:move(sel.pile, sel.index, p) then return end
        self:_event("return")
    end

    if p == STOCK then
        self:stock_click()
        return
    end
    if n > 0 and i == n and not self._up[pile[n]] then
        self:flip(p)
        return
    end
    if double and n > 0 and self:send_to_foundation(p) then return end
    if i and i > 0 and self:_can_pick(p, i) then
        self._select = { pile = p, index = i }
        self:_event("pickup", p, i)
    end
end

function SolitaireGame:_pointer_release(x, y)
    local press = self._press
    local d = self._drag
    self._press = nil
    self._drag = nil

    if d and d.active then
        local target = self:_drop_target(d)
        if not (target and self:move(d.pile, d.index, target)) then
            self:_event("return")
        end
        return
    end

    if not press or not press.pile then
        if self._select then
            self._select = nil
            self:_event("return")
        end
        return
    end

    local p, i = self:hit_test(x, y)
    if p ~= press.pile then
        p, i = press.pile, press.index
    end
    self:_click(p, i)
end

-- input: { left, right, middle, left_pressed, right_pressed, middle_pressed, left_released, right_released, middle_released }
function SolitaireGame:pointer_input(x, y, input)
    if math_abs(x - self._pointer_x) + math_abs(y - self._pointer_y) > 0.5 then
        self._cursor_mode = "pointer"
    end
    self._pointer_x, self._pointer_y = x, y

    if self._shell:pointer(x, y, input) then
        if self._drag then
            local active = self._drag.active
            self._drag = nil
            if active then self:_event("return") end
        end
        self._press = nil
        return
    end

    local lp, rp = input.left_pressed, input.right_pressed
    if lp or rp then self._cursor_mode = "pointer" end

    if self._cascade then
        if not self._cascade.done and (lp or rp or input.middle_pressed) then self:_finish_cascade() end
        return
    end
    if self._status ~= "playing" then return end

    if rp and not self._drag and inside(self._layout.client, x, y) then
        if self._select then
            self._select = nil
            self:_event("return")
        end
        self:autoplay()
    end

    if lp then self:_pointer_press(x, y) end
    if input.left then self:_pointer_move(x, y) end
    if input.left_released then self:_pointer_release(x, y) end
end

-- Queries for the renderer ----------------------------------------------------------------------

function SolitaireGame:shell() return self._shell end
function SolitaireGame:layout() return self._layout end
function SolitaireGame:pile(p) return self._piles[p] end
function SolitaireGame:is_face_up(card) return self._up[card] == true end
function SolitaireGame:card_position(card) return self._pos_x[card], self._pos_y[card] end
function SolitaireGame:deal_order() return self._deal_order end
function SolitaireGame:selection()
    local s = self._select
    if s then return s.pile, s.index end
end
function SolitaireGame:drag()
    local d = self._drag
    if d and d.active then return d end
end
function SolitaireGame:cursor() return self._cursor.pile, self:_cursor_depth() end
function SolitaireGame:cursor_mode() return self._cursor_mode end
function SolitaireGame:pointer() return self._pointer_x, self._pointer_y end
function SolitaireGame:status() return self._status end
function SolitaireGame:is_won() return self._status == "won" end
function SolitaireGame:is_game_over() return false end
function SolitaireGame:score() return self._score end
function SolitaireGame:bonus() return self._bonus end
function SolitaireGame:new_best() return self._new_best end
function SolitaireGame:scoring() return self._scoring end
function SolitaireGame:draw_count() return self._draw end
function SolitaireGame:timed() return self._timed end
function SolitaireGame:status_bar() return self._status_bar end
function SolitaireGame:outline_dragging() return self._outline end
function SolitaireGame:keep_score() return self._keep_score end
function SolitaireGame:back() return self._back end
function SolitaireGame:back_name(id) return BACK_NAMES[id or self._back] end
function SolitaireGame:backs() return BACKS end
function SolitaireGame:time() return self._time end
function SolitaireGame:moves() return self._moves end
function SolitaireGame:waste_fan() return self._waste_fan end
function SolitaireGame:cascade() return self._cascade end
function SolitaireGame:is_foundation(p) return is_foundation(p) end
function SolitaireGame:is_tableau(p) return is_tableau(p) end
function SolitaireGame:pile_ids() return STOCK, WASTE, FOUNDATION, TABLEAU, PILES end
function SolitaireGame:money(value) return money(value) end

function SolitaireGame:card_hidden(card)
    local c = self._cascade
    return c ~= nil and c.hidden[card] == true
end

-- True when the selected or dragged cards may be dropped on pile p.
function SolitaireGame:is_legal_target(p)
    local s = self._select or (self._drag and self._drag.active and self._drag)
    if not s then return false end
    return self:can_move(s.pile, s.index, p)
end

function SolitaireGame:foundation_count()
    local n = 0
    for f = FOUNDATION, FOUNDATION + 3 do n = n + #self._piles[f] end
    return n
end

function SolitaireGame:score_text()
    if self._scoring == "vegas" then return "Score: " .. money(self._score) end
    if self._scoring == "standard" then return "Score: " .. self._score end
    return nil
end

function SolitaireGame:summary()
    local home = self:foundation_count()
    local won = self._status == "won" and "  Won!" or ""
    local time = self._timed and string.format("  Time: %ds", self:time_value()) or ""
    if self._scoring == "vegas" then
        return string.format("[Solitaire] Vegas: %s  Cards home: %d/52%s", money(self._score), home, won)
    elseif self._scoring == "standard" then
        return string.format("[Solitaire] Score: %d%s  Cards home: %d/52%s", self._score, time, home, won)
    end
    return string.format("[Solitaire] Cards home: %d/52%s%s", home, time, won)
end

return SolitaireGame
