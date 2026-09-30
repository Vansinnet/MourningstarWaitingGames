local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")
local Gfx = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_canvas")
local Win95 = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_win95")
local Cards = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_cards")

local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_sin = math.sin

local RENDER_SIZE = 600
local TEXT_POOL = 80
local CARD_W, CARD_H = 66, 90
local LIFT_X, LIFT_Y = -2, -5
local FULL_STAMPS = 130
local FADE_STAMPS = 110
local MAX_POPUPS = 8

-- Draw passes, in drawing order.
local PASS_HIDDEN, PASS_STATIC, PASS_WAIT, PASS_MOVE, PASS_LIFT, PASS_DRAG = 0, 1, 2, 3, 4, 5
local PASS_LAYER = { 4.0, 4.9, 5.0, 5.7, 6.5 }

local C = {
    felt = { 255, 0, 128, 0 },
    felt_light = { 255, 90, 215, 90 },
    felt_dark = { 255, 0, 34, 0 },
    speck_light = { 255, 150, 235, 150 },
    speck_dark = { 255, 0, 50, 0 },
    black = { 255, 0, 0, 0 },
    white = { 255, 255, 255, 255 },
    paper = { 255, 255, 255, 255 },
    edge = { 255, 214, 214, 214 },
    red = { 255, 210, 0, 0 },
    icon_blue = { 255, 20, 70, 190 },
    gold = { 255, 255, 214, 90 },
    spark = { 255, 255, 236, 140 },
    spark_white = { 255, 255, 255, 235 },
    dust = { 255, 200, 255, 200 },
    cursor = { 255, 255, 222, 60 },
    cursor_ok = { 255, 120, 255, 140 },
    cursor_bad = { 255, 255, 90, 70 },
    target = { 255, 255, 240, 150 },
    target_hot = { 255, 255, 250, 200 },
    lift = { 255, 255, 250, 210 },
    outline = { 255, 255, 127, 255 },
    popup_plus = { 255, 255, 238, 120 },
    popup_minus = { 255, 255, 130, 110 },
    popup_shadow = { 255, 0, 26, 8 },
    text_black = { 255, 0, 0, 0 },
    text_gray = { 255, 90, 90, 90 },
    highlight = { 255, 0, 0, 128 },
    confetti = {
        { 255, 255, 60, 60 }, { 255, 255, 220, 40 }, { 255, 60, 200, 255 },
        { 255, 255, 255, 255 }, { 255, 120, 255, 120 },
    },
}

local SUIT_TAB = { C.black, C.red, C.red, C.black }

-- The taskbar / title icon: a card back behind a heart.
local ICON = Win95.sprite({
    "kkkkkkkkk....",
    "kbbbbbbbk....",
    "kbwbwbwbk....",
    "kbbbbbbbk....",
    "kbwbkkkkkkkkk",
    "kbbbkwwwwwwwk",
    "kbwbkwrrwrrwk",
    "kbbbkwrrrrrwk",
    "kbwbkwrrrrrwk",
    "kbbbkwwrrrwwk",
    "kkkkkwwwrwwwk",
    "....kwwwwwwwk",
    "....kwwwwwwwk",
    "....kkkkkkkkk",
}, { k = C.black, b = C.icon_blue, w = C.white, r = C.red })

local function draw_icon(canvas, cx, cy, size, layer)
    local px = size / 14
    Win95.draw_sprite(canvas, ICON, cx - ICON.w * px * 0.5, cy - ICON.h * px * 0.5, px, layer)
end

local scenegraph = {
    screen = table.clone(UIWorkspaceSettings.screen),
    overlay_panel = {
        horizontal_alignment = "center", parent = "screen", vertical_alignment = "center",
        size = { RENDER_SIZE, RENDER_SIZE }, position = { 0, 0, 25 },
    },
    scanner_base = {
        horizontal_alignment = "center", parent = "overlay_panel", vertical_alignment = "center",
        size = { RENDER_SIZE, RENDER_SIZE }, position = { 0, 0, 5 },
    },
    center_pivot = {
        horizontal_alignment = "center", parent = "scanner_base", vertical_alignment = "center",
        size = { 0, 0 }, position = { 0, 0, 1 },
    },
}

local widget_definitions = {
    backdrop = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/backgrounds/default_square",
            style = { color = { 255, 0, 0, 0 } } },
    }, "scanner_base", nil, { RENDER_SIZE, RENDER_SIZE }),
}

Win95.add_text_widgets(UIWidget, widget_definitions, "sol_text_", TEXT_POOL, RENDER_SIZE)

AuspexFrame.add(widget_definitions, {
    render_size = RENDER_SIZE,
    outline_size = { 620, 620 },
    backdrop_alpha = 250,
    alpha = 150,
})

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }

local SolitaireView = class("SolitaireView", "BaseView")

local HOW_TO = {
    "Build the four suit stacks up from Ace to King.",
    "On the table, build down in alternating colours.",
    "Only a King (or a run from a King) fills an empty column.",
    "Click the deck to deal; click a face-down card to turn it.",
    "Drag cards, or click a card and then its destination.",
    "Double-click (or E) sends a card to its suit stack.",
    "Right-click plays every card it can to the suit stacks.",
    "Keys: WASD / arrows move, Space picks up and drops;",
    "  Up / Down on a column choose how many cards to take.",
    "R deals, Q undoes, Tab opens the menu, Esc backs out.",
}

function SolitaireView:init(settings, context)
    SolitaireView.super.init(self, definitions, settings, context)

    self._game = context.game
    -- A real mouse pointer, like the original.
    self._no_cursor = false
    self._canvas = Gfx.Canvas.new(RENDER_SIZE, RENDER_SIZE, 14000)
    -- Every 0.1 of a layer below becomes a whole Gui layer, so shapes and text stack reliably.
    self._canvas:set_layer_scale(10)
    self._particles = Gfx.Particles.new(360)
    self._shaker = Gfx.Shaker.new()
    self._text = Win95.text_pool(self, "sol_text_", TEXT_POOL)
    self._motion = Cards.motion(15)
    self._time = 0

    self._cx, self._cy, self._cf, self._cpass = {}, {}, {}, {}
    self._wait_until = {}
    self._land = {}
    self._popups = {}
    self._list = {}
    self._list_pile = {}
    self._list_index = {}
    self._skip = {}
    self._covered = {}
    self._covered_flip = {}
    self._clip = { 0, 0, 0, 0 }
    self._card_opts = {}
    self._win_at = nil
    self._confetti = {}

    local specks = {}
    local s = 90210
    for i = 1, 150 do
        s = (s * 16807) % 2147483647
        local x = (s % 10007) / 10007
        s = (s * 16807) % 2147483647
        local y = (s % 10007) / 10007
        s = (s * 16807) % 2147483647
        specks[i] = { x = x, y = y, w = 1 + s % 3, light = s % 5 < 2, alpha = 14 + s % 18 }
    end
    self._specks = specks

    self._segments = { { text = "" }, { text = "" }, { text = "" } }
    self._status = {}
    self._status_cache = {}
    self._desktop_opts = { app = "Solitaire", icon = draw_icon, clock = "00:00" }
    self._window_opts = { title = "Solitaire", icon = draw_icon, status = nil }
    self._dialog_custom = function(canvas, D, dialog, text, t)
        self:_draw_dialog_content(canvas, D, dialog, text, t)
    end
    self._on_event = function(kind, a, b, c, d)
        self:_event(kind, a, b, c, d)
    end
end

function SolitaireView:dialogue_system() return nil end
function SolitaireView:is_using_input() return false end

function SolitaireView:update(dt, t, input_service)
    if self._game then self._game:update(dt) end
    return SolitaireView.super.update(self, dt, t, input_service)
end

-- Input ---------------------------------------------------------------------------------

local function input_value(input_service, action)
    if not input_service or not input_service.get then return false end
    local ok, value = pcall(input_service.get, input_service, action)
    if not ok then return false end
    return value == true or (type(value) == "number" and value > 0)
end

function SolitaireView:_process_pointer(input_service, ui_renderer, base)
    if not input_service or not input_service.get then return end

    local ok, cursor = pcall(input_service.get, input_service, "cursor")
    if not ok or not cursor then return end

    local inverse = ui_renderer.inverse_scale or 1
    local x = cursor[1] * inverse - base[1]
    local y = cursor[2] * inverse - base[2]

    local input = self._pointer_state or {}
    self._pointer_state = input
    input.left = input_value(input_service, "left_hold")
    input.right = input_value(input_service, "right_hold")
    input.middle = input_value(input_service, "middle_hold")
    input.left_pressed = input_value(input_service, "left_pressed")
    input.right_pressed = input_value(input_service, "right_pressed")
    input.middle_pressed = input_value(input_service, "middle_pressed")
    input.left_released = input_value(input_service, "left_released")
    input.right_released = input_value(input_service, "right_released")
    input.middle_released = input_value(input_service, "middle_released")

    self._game:pointer_input(x, y, input)
end

-- Events -----------------------------------------------------------------------------------

function SolitaireView:_top_position(p)
    local game = self._game
    local pile = game:pile(p)
    local top = pile[#pile]
    if top then return game:card_position(top) end
    local r = game:layout().piles[p]
    return r.x, r.y
end

function SolitaireView:_popup(value, x, y, color)
    local popups = self._popups
    if #popups >= MAX_POPUPS then table.remove(popups, 1) end
    popups[#popups + 1] = { text = value, x = x, y = y, at = self._time, color = color }
end

function SolitaireView:_handle_events()
    self._game:drain_events(self._on_event)
end

function SolitaireView:_event(kind, a, b, c, d)
    local game = self._game
    local now = self._time
    local particles = self._particles
    local motion = self._motion
    local L = game:layout()

    if kind == "deal" then
        motion:clear()
        particles:clear()
        for card in pairs(self._wait_until) do self._wait_until[card] = nil end
        for card in pairs(self._land) do self._land[card] = nil end
        for i = #self._popups, 1, -1 do self._popups[i] = nil end
        for i = #self._confetti, 1, -1 do self._confetti[i] = nil end
        self._win_at = nil
        local stock = L.piles[1]
        local order = game:deal_order()
        for k = 1, #order do
            local card = order[k]
            local delay = 0.15 + (k - 1) * 0.045
            motion:place(card, stock.x, stock.y, false)
            motion:delay(card, delay)
            self._wait_until[card] = now + delay
        end
    elseif kind == "move" then
        -- a: from, b: to, c: count, d: first card. Runs travel with a slight stagger.
        local pile = game:pile(b)
        local first = #pile - c + 1
        for i = first + 1, #pile do
            motion:delay(pile[i], (i - first) * 0.022)
        end
        if game:is_foundation(b) then self._land[d] = true end
    elseif kind == "flip" then
        local x, y = game:card_position(b)
        particles:burst(x + CARD_W * 0.5, y + 12, 8, 40, 140, 0.2, 0.45, 1.3, C.spark_white, "spark", 5)
    elseif kind == "recycle" then
        local r = L.piles[1]
        particles:shockwave(r.x + CARD_W * 0.5, r.y + CARD_H * 0.5, 44, 0.45, C.spark_white, 2)
    elseif kind == "score" then
        local x, y = self:_top_position(b)
        local value = a > 0 and ("+" .. a) or tostring(a)
        self:_popup(value, x + CARD_W * 0.5, y + CARD_H * 0.45, a > 0 and C.popup_plus or C.popup_minus)
    elseif kind == "invalid" then
        local x, y = self:_top_position(a)
        particles:flash(x + CARD_W * 0.5, y + CARD_H * 0.5, 50, 0.3, C.cursor_bad)
    elseif kind == "win" then
        self._win_at = now
        self._shaker:add(0.45)
        for f = 3, 6 do
            local r = L.piles[f]
            local cx, cy = r.x + CARD_W * 0.5, r.y + CARD_H * 0.5
            particles:flash(cx, cy, 70, 0.6, C.spark)
            particles:burst(cx, cy, 16, 80, 320, 0.4, 0.9, 2, C.spark, "spark", 3, 160)
        end
        local client = L.client
        local f1, f4 = L.piles[3], L.piles[6]
        particles:shockwave((f1.x + f4.x + CARD_W) * 0.5, f1.y + CARD_H * 0.5, 200, 0.9, C.spark, 3)
        if a and a > 0 then
            self:_popup("Time bonus +" .. a, client.x + client.w * 0.5, L.piles[3].y + CARD_H + 30, C.popup_plus)
        end
        self:_spawn_confetti(client)
    elseif kind == "launch" then
        local x, y = game:card_position(a)
        particles:flash(x + CARD_W * 0.5, y + CARD_H * 0.5, 46, 0.35, C.spark)
    elseif kind == "bounce" then
        particles:burst(a, b - 2, 6, 60, 190, 0.2, 0.5, 1.4, C.dust, "spark", 4, 380, -math_pi * 0.5, 2.2)
    end
end

function SolitaireView:_spawn_confetti(client)
    local confetti = self._confetti
    local s = 777
    for i = 1, 90 do
        s = (s * 16807) % 2147483647
        local r1 = (s % 1000) / 1000
        s = (s * 16807) % 2147483647
        local r2 = (s % 1000) / 1000
        confetti[i] = {
            x = client.x + r1 * client.w, y = client.y - r2 * 160,
            vx = (r2 - 0.5) * 50, vy = 50 + r1 * 110,
            spin = (r1 - 0.5) * 12, angle = r2 * 6,
            size = 3 + r1 * 4, color = C.confetti[i % #C.confetti + 1], phase = r1 * 6,
        }
    end
end

-- Card motion --------------------------------------------------------------------------------

function SolitaireView:_update_cards(dt)
    local game = self._game
    local motion = self._motion
    local _, _, _, _, piles = game:pile_ids()
    local sel_pile, sel_index = game:selection()
    local drag = game:drag()
    if drag and game:outline_dragging() then drag = nil end
    local now = self._time
    local cx, cy, cf, cpass = self._cx, self._cy, self._cf, self._cpass
    local land = self._land
    local wait = self._wait_until

    for p = 1, piles do
        local pile = game:pile(p)
        local fx, fy
        if drag and drag.pile == p then fx, fy = game:card_position(pile[drag.index]) end

        for i = 1, #pile do
            local card = pile[i]
            local tx, ty = game:card_position(card)
            local up = game:is_face_up(card)
            local pass = PASS_STATIC

            if game:card_hidden(card) then
                pass = PASS_HIDDEN
            elseif fx and i >= drag.index then
                tx, ty = drag.x + tx - fx, drag.y + ty - fy
                motion:place(card, tx, ty, up)
                pass = PASS_DRAG
            elseif sel_pile == p and i >= sel_index then
                tx, ty = tx + LIFT_X, ty + LIFT_Y
                pass = PASS_LIFT
            end

            local x, y, flip, moving = motion:step(card, tx, ty, up, dt)
            if pass == PASS_STATIC and moving then
                local until_t = wait[card]
                if until_t and now < until_t then
                    pass = PASS_WAIT
                else
                    pass = PASS_MOVE
                    wait[card] = nil
                end
            end

            if land[card] and not moving then
                land[card] = nil
                if game:is_foundation(p) then
                    local mx, my = x + CARD_W * 0.5, y + CARD_H * 0.5
                    self._particles:flash(mx, my, 44, 0.3, C.spark_white)
                    self._particles:burst(mx, my, 12, 70, 240, 0.25, 0.6, 1.6, C.spark, "spark", 4)
                end
            end

            cx[card], cy[card], cf[card], cpass[card] = x, y, flip, pass
        end
    end
end

-- Table ----------------------------------------------------------------------------------------

function SolitaireView:_draw_felt(canvas, client)
    local x, y, w, h = client.x, client.y, client.w, client.h
    canvas:rect(x, y, w, h, 3.05, C.felt)

    -- Soft light pooled in the middle of the table (triangles, so a layer above the felt).
    local cx, cy = x + w * 0.5, y + h * 0.44
    for k = 1, 5 do
        local f = 1.12 - k * 0.16
        canvas:ellipse(cx, cy, w * 0.62 * f, h * 0.6 * f, 3.2, C.felt_light, 13, 1, 0, 28)
    end

    local specks = self._specks
    for i = 1, #specks do
        local s = specks[i]
        canvas:rect(x + s.x * w, y + s.y * h, s.w, 1, 3.3, s.light and C.speck_light or C.speck_dark, s.alpha)
    end

    canvas:vignette(x, y, w, h, 40, 3.31, 120, 6, C.felt_dark)
end

function SolitaireView:_draw_slots(canvas, L)
    local game = self._game
    local _, _, _, _, piles = game:pile_ids()
    local cpass = self._cpass

    for p = 1, piles do
        local pile = game:pile(p)
        if #pile == 0 or cpass[pile[1]] ~= PASS_STATIC then
            local r = L.piles[p]
            local kind = "outline"
            if p == 1 then kind = game:stock_mark() or "outline" end
            Cards.draw_slot(canvas, r.x, r.y, r.w, r.h, 3.4, kind, 255)
        end
    end

    -- A thicker deck while plenty of cards remain in the stock.
    local stock = game:pile(1)
    local r = L.piles[1]
    local levels = math_min(3, math_floor(#stock / 8))
    for k = levels, 1, -1 do
        canvas:rect(r.x + k * 2, r.y + k, CARD_W, CARD_H, 3.9, C.black)
        canvas:rect(r.x + k * 2 + 1, r.y + k + 1, CARD_W - 2, CARD_H - 2, 3.9, C.edge)
    end
end

-- Pulsing glow around every pile the held or dragged cards may land on.
function SolitaireView:_draw_targets(canvas, L, t)
    local game = self._game
    local _, _, _, _, piles = game:pile_ids()
    local drag = game:drag()
    local hot = drag and drag.target
    local sel_pile = game:selection()
    if not drag and not sel_pile then return end

    for p = 1, piles do
        if game:is_legal_target(p) then
            local x, y = self:_drawn_top(p, L)
            local strong = p == hot
            Cards.draw_highlight(canvas, x, y, CARD_W, CARD_H, 3.8, strong and C.target_hot or C.target, t, strong and 1.2 or 0.5)
            if strong then self:_frame(canvas, x - 3, y - 3, CARD_W + 6, CARD_H + 6, 4.6, C.target_hot, 230) end
        end
    end
end

-- Where the top card of a pile is drawn right now (or its empty slot).
function SolitaireView:_drawn_top(p, L)
    local pile = self._game:pile(p)
    for i = #pile, 1, -1 do
        local card = pile[i]
        local pass = self._cpass[card]
        if pass == PASS_STATIC or pass == PASS_MOVE then return self._cx[card], self._cy[card] end
    end
    local r = L.piles[p]
    return r.x, r.y
end

function SolitaireView:_frame(canvas, x, y, w, h, layer, color, alpha)
    canvas:rect(x, y, w, 2, layer, color, alpha)
    canvas:rect(x, y + h - 2, w, 2, layer, color, alpha)
    canvas:rect(x, y + 2, 2, h - 4, layer, color, alpha)
    canvas:rect(x + w - 2, y + 2, 2, h - 4, layer, color, alpha)
end

-- Draws every card of one pass in pile order. Cards hidden exactly under a later card are skipped,
-- and cards overlapped by the next card of their pile are clipped to their visible strip.
function SolitaireView:_draw_pass(canvas, pass, t)
    local game = self._game
    local _, _, _, _, piles = game:pile_ids()
    local cx, cy, cf, cpass = self._cx, self._cy, self._cf, self._cpass
    local list, list_pile, list_index, skip = self._list, self._list_pile, self._list_index, self._skip
    local n = 0

    for p = 1, piles do
        local pile = game:pile(p)
        for i = 1, #pile do
            if cpass[pile[i]] == pass then
                n = n + 1
                list[n], list_pile[n], list_index[n] = pile[i], p, i
            end
        end
    end
    if n == 0 then return end

    local covered, covered_flip = self._covered, self._covered_flip
    for k in pairs(covered) do covered[k] = nil end
    for k in pairs(covered_flip) do covered_flip[k] = nil end

    for k = n, 1, -1 do
        local card = list[k]
        local yq = math_floor(cy[card] * 4 + 0.5)
        skip[k] = false
        if yq >= 0 and yq < 8192 then
            local key = math_floor(cx[card] * 4 + 0.5) * 8192 + yq
            local f = cf[card]
            local key_flip = key * 128 + math_floor(f * 127 + 0.5)
            if covered[key] or covered_flip[key_flip] then
                skip[k] = true
            else
                covered_flip[key_flip] = true
                if f == 0 or f == 1 then covered[key] = true end
            end
        end
    end

    local layer = PASS_LAYER[pass]
    local back = game:back()
    local opts = self._card_opts
    local clip = self._clip

    for k = 1, n do
        if not skip[k] then
            local card = list[k]
            local x, y, f = cx[card], cy[card], cf[card]
            local pile = game:pile(list_pile[k])
            local nxt = pile[list_index[k] + 1]
            local use_clip = nil

            if nxt then
                local np = cpass[nxt]
                local nf = cf[nxt]
                if np >= pass and (nf == 0 or nf == 1) then
                    local nx, ny = cx[nxt], cy[nxt]
                    if math_abs(nx - x) < 0.5 and ny > y and ny < y + CARD_H then
                        clip[1], clip[2], clip[3], clip[4] = x - 8, y - 8, x + CARD_W + 8, ny + 2
                        use_clip = clip
                    elseif math_abs(ny - y) < 0.5 and nx > x and nx < x + CARD_W then
                        clip[1], clip[2], clip[3], clip[4] = x - 8, y - 8, nx + 2, y + CARD_H + 8
                        use_clip = clip
                    end
                end
            end

            opts.clip = use_clip
            opts.shadow = nil
            Cards.draw_card(canvas, x, y, CARD_W, CARD_H, card, f, layer, back, t, opts)
        end
    end
    opts.clip = nil
end

-- Bounds of the cards from index to the top of pile p as currently drawn.
function SolitaireView:_run_bounds(p, index)
    local pile = self._game:pile(p)
    local first, last = pile[index], pile[#pile]
    if not first then return nil end
    local x, y = self._cx[first], self._cy[first]
    return x, y, CARD_W, self._cy[last] + CARD_H - y
end

function SolitaireView:_draw_lifted(canvas, t)
    local game = self._game
    local p, index = game:selection()
    if not p then return end
    local x, y, w, h = self:_run_bounds(p, index)
    if not x then return end
    canvas:soft_rect(x + 4, y + 9, w, h, 4, 5.5, C.black, 80, 3)
    Cards.draw_highlight(canvas, x, y, w, h, 5.55, C.lift, t, 1.1)
    self:_draw_pass(canvas, PASS_LIFT, t)
    local pulse = (math_sin(t * 6) + 1) * 0.5
    self:_frame(canvas, x - 1, y - 1, w + 2, h + 2, 5.8, C.lift, 120 + pulse * 80)
end

function SolitaireView:_draw_dragged(canvas, t)
    local game = self._game
    local drag = game:drag()
    if not drag then return end

    if game:outline_dragging() then
        local x, y, w, h = self:_run_bounds(drag.pile, drag.index)
        if not x then return end
        local ox, oy = game:card_position(game:pile(drag.pile)[drag.index])
        Win95.dotted_rect(canvas, drag.x + (x - ox), drag.y + (y - oy), w, h, 6.6, C.outline)
        Win95.dotted_rect(canvas, drag.x + (x - ox) + 1, drag.y + (y - oy) + 1, w - 2, h - 2, 6.6, C.outline)
        return
    end

    local x, y, w, h = self:_run_bounds(drag.pile, drag.index)
    if not x then return end
    canvas:soft_rect(x + 7, y + 11, w, h, 6, 6.4, C.black, 90, 4)
    self:_draw_pass(canvas, PASS_DRAG, t)
end

function SolitaireView:_draw_cursor(canvas, L, t)
    local game = self._game
    if game:cursor_mode() ~= "keys" or game:status() ~= "playing" then return end
    local shell = game:shell()
    if shell:dialog() or shell:menu() or game:drag() then return end

    local p, depth = game:cursor()
    local pile = game:pile(p)
    local x, y, w, h
    if #pile == 0 then
        local r = L.piles[p]
        x, y, w, h = r.x, r.y, r.w, r.h
    else
        local sel_pile, sel_index = game:selection()
        local index = #pile
        if sel_pile == p then
            index = sel_index
        elseif not sel_pile and game:is_tableau(p) then
            index = #pile - depth + 1
        end
        x, y, w, h = self:_run_bounds(p, index)
    end

    local color = C.cursor
    if game:selection() then
        color = game:is_legal_target(p) and C.cursor_ok or C.cursor_bad
    end
    local pulse = (math_sin(t * 6) + 1) * 0.5
    Cards.draw_highlight(canvas, x, y, w, h, 3.8, color, t, 0.9)
    self:_frame(canvas, x - 3, y - 3, w + 6, h + 6, 4.6, color, 170 + pulse * 85)

    local ax, ay = x + w * 0.5, y - 4 - pulse * 2
    canvas:tri(ax - 6, ay - 6, ax + 6, ay - 6, ax, ay, 4.7, color)
    canvas:tri(ax - 3, ay - 6, ax + 3, ay - 6, ax, ay - 3, 4.71, C.white, 110)
end

function SolitaireView:_draw_cascade(canvas, t)
    local c = self._game:cascade()
    if not c then return end

    local n = c.stamp_count
    if n > 0 then
        local cap = c.cap
        local oldest = (c.stamp_head - n) % cap
        local full_from = n - FULL_STAMPS
        local fade = math_max(0, math_min(FADE_STAMPS, n - (cap - FADE_STAMPS)))
        local sc, sx, sy = c.stamp_card, c.stamp_x, c.stamp_y
        for k = 1, n do
            local i = (oldest + k - 1) % cap + 1
            local alpha = k <= fade and 255 * k / (fade + 1) or nil
            local card, x, y = sc[i], sx[i], sy[i]
            if k > full_from then
                Cards.draw_stamp(canvas, x, y, CARD_W, CARD_H, card, 6.0, alpha)
            else
                canvas:rect(x, y, CARD_W, CARD_H, 6.0, C.black, alpha)
                canvas:rect(x + 1, y + 1, CARD_W - 2, CARD_H - 2, 6.0, C.paper, alpha)
                canvas:rect(x + 4, y + 5, 6, 9, 6.0, SUIT_TAB[math_floor((card - 1) / 13) + 1], alpha)
            end
        end
    end

    if c.card then
        Cards.draw_face(canvas, c.x, c.y, CARD_W, CARD_H, c.card, 6.1)
    end
end

function SolitaireView:_draw_popups(canvas)
    local popups = self._popups
    local text = self._text
    local now = self._time
    for i = #popups, 1, -1 do
        local p = popups[i]
        local age = now - p.at
        if age > 1.2 then
            table.remove(popups, i)
        else
            local rise = 1 - (1 - math_min(1, age / 0.9)) ^ 3
            local alpha = age < 0.75 and 255 or 255 * (1 - (age - 0.75) / 0.45)
            local y = p.y - rise * 34
            local pop = age < 0.12 and 1 + (0.12 - age) * 3 or 1
            local w = (Win95.text_width(p.text, 14) + 14) * pop
            local h = 19 * pop
            canvas:rect(p.x - w * 0.5 + 2, y - h * 0.5, w - 4, h, 7.35, C.popup_shadow, alpha * 0.78)
            canvas:rect(p.x - w * 0.5, y - h * 0.5 + 2, w, h - 4, 7.35, C.popup_shadow, alpha * 0.78)
            canvas:rect(p.x - w * 0.5 + 2, y - h * 0.5, w - 4, 1, 7.36, p.color, alpha * 0.6)
            text:draw(p.text, p.x - 80, y - 9, 160, 18, 14, p.color, "center", 7.4, nil, alpha)
        end
    end
end

function SolitaireView:_draw_confetti(canvas, dt, client)
    local confetti = self._confetti
    local bottom = client.y + client.h
    for i = #confetti, 1, -1 do
        local c = confetti[i]
        c.vy = c.vy + 30 * dt
        c.x = c.x + (c.vx + math_sin(self._time * 3 + c.phase) * 30) * dt
        c.y = c.y + c.vy * dt
        c.angle = c.angle + c.spin * dt
        if c.y > bottom + 10 then
            table.remove(confetti, i)
        else
            local w = c.size * math_abs(math.cos(c.angle))
            canvas:rect(c.x - w * 0.5, c.y - c.size * 0.3, math_max(0.8, w), c.size * 0.6, 7.2, c.color, 235)
        end
    end
end

-- Dialog contents ---------------------------------------------------------------------------------

function SolitaireView:_draw_dialog_content(canvas, D, dialog, text, t)
    local game = self._game
    local box = D.box
    local kind = dialog.kind

    if kind == "deck" then
        local shell = game:shell()
        local focus_kind, focus_index = shell:dialog_focus()
        local opts = self._card_opts
        opts.clip, opts.shadow = nil, nil
        local selected_name = nil
        for i = 1, #D.controls do
            local c = D.controls[i]
            local spec = c.spec
            if spec.type == "tile" then
                local r = c.rect
                local selected = dialog.values.back == spec.value
                if selected then
                    canvas:rect(r.x - 4, r.y - 4, r.w + 8, r.h + 8, 9.12, C.highlight)
                    selected_name = spec.label
                end
                Cards.draw_back(canvas, r.x, r.y, r.w, r.h, spec.value, 9.2, t, opts)
                if focus_kind == "control" and focus_index == i then
                    Win95.dotted_rect(canvas, r.x - 7, r.y - 7, r.w + 14, r.h + 14, 9.13, C.black)
                end
            end
        end
        if selected_name then
            text:draw(selected_name, box.x, box.y + 118, box.w, 20, 12, C.text_black, "center", 10.5)
        end
    elseif kind == "about" then
        draw_icon(canvas, box.x + 40, box.y + 64, 40, 9.2)
        local x = box.x + 76
        text:draw("Solitaire", x, box.y + 34, 240, 22, 15, C.text_black, "left", 10.5)
        text:draw("Mourningstar Waiting Games edition", x, box.y + 58, 250, 20, 12, C.text_black, "left", 10.5)
        text:draw("A tribute to the Windows 95 classic.", x, box.y + 78, 250, 20, 12, C.text_black, "left", 10.5)
        text:draw("Dealt on an Imperial auspex.", x, box.y + 98, 250, 20, 12, C.text_gray, "left", 10.5)
    elseif kind == "how_to" then
        for i = 1, #HOW_TO do
            text:draw(HOW_TO[i], box.x + 16, box.y + 30 + (i - 1) * 22, box.w - 32, 20, 12, C.text_black, "left", 10.5)
        end
    elseif kind == "again" then
        draw_icon(canvas, box.x + 38, box.y + 58, 34, 9.2)
        local glow = 0.5 + 0.5 * math_sin(t * 3)
        canvas:soft_rect(box.x + 24, box.y + 42, 28, 32, 6, 9.15, C.gold, 60 + glow * 50, 3)
        text:draw("Deal Again?", box.x + 70, box.y + 34, box.w - 84, 22, 14, C.text_black, "left", 10.5)
        local line
        local scoring = game:scoring()
        if scoring == "standard" then
            line = "Score: " .. game:score()
            if game:bonus() > 0 then line = line .. "   Bonus: " .. game:bonus() end
            if game:new_best() then line = line .. "   New best!" end
        elseif scoring == "vegas" then
            line = "Winnings: " .. game:money(game:score())
        else
            line = "Time: " .. game:time_value() .. " seconds"
        end
        text:draw(line, box.x + 70, box.y + 58, box.w - 84, 20, 11, C.text_gray, "left", 10.5)
    end
end

-- Status bar, hint and main draw ------------------------------------------------------------------

function SolitaireView:_status_segments(L)
    local game = self._game
    if not game:status_bar() then return nil end

    -- Strings are rebuilt only when what they show changes.
    local cache = self._status_cache
    local won, draw, passes = game:status() == "won", game:draw_count(), game:passes_left()
    local score_value, scoring, timed, seconds = game:score(), game:scoring(), game:timed(), game:time_value()
    if cache.won == won and cache.draw == draw and cache.passes == passes and cache.score == score_value
        and cache.scoring == scoring and cache.timed == timed and cache.seconds == seconds then
        return self._status
    end
    cache.won, cache.draw, cache.passes, cache.score = won, draw, passes, score_value
    cache.scoring, cache.timed, cache.seconds = scoring, timed, seconds

    local list = self._status
    for i = #list, 1, -1 do list[i] = nil end
    local seg = self._segments
    local total = L.client.w - 4

    local info
    if won then
        info = "Congratulations, you won!"
    else
        info = draw == 1 and "Draw One" or "Draw Three"
        if passes then
            if passes == 0 then
                info = info .. "   Last pass"
            else
                info = info .. "   " .. passes .. (passes == 1 and " more pass" or " more passes")
            end
        end
    end

    -- The last segment takes the remaining width, so only the earlier ones get explicit widths.
    local score = game:score_text()
    local time = timed and ("Time: " .. seconds) or nil
    local used = (score and 133 or 0) + (time and 113 or 0)

    seg[1].text, seg[1].w = info, used > 0 and (total - used) or nil
    list[1] = seg[1]
    if score then
        seg[2].text, seg[2].w = score, time and 130 or nil
        list[#list + 1] = seg[2]
    end
    if time then
        seg[3].text, seg[3].w = time, nil
        list[#list + 1] = seg[3]
    end
    return list
end

function SolitaireView:_hint()
    local game = self._game
    if game:cascade() then return "Click or press any key to skip the celebration" end
    if game:cursor_mode() == "keys" then
        return "WASD move   W/S depth   Space pick up / drop   E to suit stack   R deal   Q undo   Tab menu"
    end
    return "Drag or click to move   Dbl-click: to suit stack   Right-click: auto-play   R deal   Q undo   Tab menu"
end

function SolitaireView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local game = self._game
    local text = self._text
    text:reset()

    if not game then
        SolitaireView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
        return
    end

    dt = math_min(dt or 0.016, 0.05)
    self._time = self._time + dt

    local base = self:_scenegraph_world_position("scanner_base")
    self:_process_pointer(input_service, ui_renderer, base)
    self:_handle_events()
    self:_update_cards(dt)
    self._particles:update(dt)
    self._shaker:update(dt, 5)

    local canvas = self._canvas
    if canvas:begin(ui_renderer, base) then
        local time = self._time
        local shell = game:shell()
        local L = game:layout()
        local client = L.client

        local clock_key = game:time_value() * 2 + math_floor(time * 2) % 2
        if clock_key ~= self._clock_key then
            self._clock_key = clock_key
            local seconds = game:time_value()
            local colon = math_floor(time * 2) % 2 == 0 and ":" or " "
            self._desktop_opts.clock = string.format("%02d%s%02d", math_floor(seconds / 60) % 100, colon, seconds % 60)
        end
        Win95.draw_desktop(canvas, text, time, self._desktop_opts)

        local sx, sy = self._shaker.x, self._shaker.y
        canvas:set_shake(sx, sy)
        text:set_offset(sx, sy)

        self._window_opts.status = self:_status_segments(L)
        Win95.draw_window(canvas, text, shell, time, self._window_opts)

        canvas:set_clip(client.x, client.y, client.x + client.w, client.y + client.h)
        self:_draw_felt(canvas, client)
        self:_draw_slots(canvas, L)
        self:_draw_targets(canvas, L, time)
        self:_draw_pass(canvas, PASS_STATIC, time)
        self:_draw_cursor(canvas, L, time)
        self:_draw_pass(canvas, PASS_WAIT, time)
        self:_draw_pass(canvas, PASS_MOVE, time)
        self:_draw_lifted(canvas, time)
        self:_draw_cascade(canvas, time)
        self:_draw_dragged(canvas, time)
        self._particles:draw(canvas, 7)
        self:_draw_confetti(canvas, dt, client)
        self:_draw_popups(canvas)
        canvas:reset_clip()

        canvas:set_shake(0, 0)
        text:set_offset(0, 0)

        Win95.draw_menu(canvas, text, shell)
        Win95.draw_dialog(canvas, text, shell, time, self._dialog_custom)
        Win95.draw_hint(canvas, text, self:_hint())

        canvas:crt(0, 0, RENDER_SIZE, RENDER_SIZE, time, 11.5, {
            tint = Win95.C.hint, scan_alpha = 12, sweep_alpha = 10, vignette_depth = 60, vignette_alpha = 110,
            noise_count = 6, noise_alpha = 25, flicker = false,
        })
        canvas:finish()
    end

    SolitaireView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

function SolitaireView:destroy()
    self._canvas = nil
    self._particles = nil
    self._motion = nil
    SolitaireView.super.destroy(self)
end

return SolitaireView
