local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")
local Gfx = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_canvas")
local Win95 = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_win95")
local Cards = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_cards")

local math_abs = math.abs
local math_cos = math.cos
local math_exp = math.exp
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_random = math.random
local math_sin = math.sin

local RENDER_SIZE = 600
local TEXT_POOL = 110
local TEXT_PREFIX = "hearts_text_"
local TASKBAR_Y = Win95.TASKBAR_Y
local DEAL_STAGGER = 0.02
local MOTION_SPEED = 13
local SOUTH, WEST, NORTH, EAST = 1, 2, 3, 4
local QUEEN = 51
local HINT = "Click cards   A/D + Space select or play   W/S button   E pass/OK   R new game   1 score   Tab menu"

local C = Win95.C
local P = {
    felt_top = { 255, 0, 116, 56 },
    felt_bottom = { 255, 0, 74, 36 },
    felt_glow = { 255, 90, 200, 120 },
    felt_edge = { 255, 0, 30, 12 },
    plate = { 255, 0, 20, 8 },
    plate_light = { 255, 150, 230, 170 },
    plate_dark = { 255, 0, 0, 0 },
    name = { 255, 255, 255, 255 },
    score = { 255, 255, 214, 90 },
    turn = { 255, 255, 220, 90 },
    heart = { 255, 232, 24, 48 },
    heart_shine = { 255, 255, 160, 170 },
    spade = { 255, 12, 12, 20 },
    white = { 255, 255, 255, 255 },
    gold = { 255, 255, 210, 80 },
    gold_dark = { 255, 150, 100, 10 },
    select = { 255, 255, 228, 100 },
    received = { 255, 110, 220, 255 },
    hover = { 255, 255, 255, 255 },
    focus = { 255, 255, 222, 60 },
    dim = { 255, 0, 22, 8 },
    winner = { 255, 255, 236, 140 },
    violet = { 255, 170, 110, 255 },
    smoke = { 255, 24, 12, 36 },
    pink = { 255, 255, 110, 150 },
    black = { 255, 0, 0, 0 },
    arrow = { 255, 255, 214, 70 },
    banner_mid = { 255, 0, 27, 13 },
    arrow_edge = { 255, 90, 50, 0 },
    shade = { 255, 0, 0, 0 },
    row_alt = { 255, 236, 240, 248 },
    grid = { 255, 200, 200, 200 },
    moon = { 255, 255, 214, 60 },
    fireworks = {
        { 255, 255, 210, 60 }, { 255, 255, 70, 90 }, { 255, 255, 120, 210 },
        { 255, 90, 210, 255 }, { 255, 255, 255, 255 }, { 255, 120, 255, 130 },
    },
    confetti = {
        { 255, 255, 30, 60 }, { 255, 0, 200, 0 }, { 255, 0, 90, 255 },
        { 255, 255, 220, 0 }, { 255, 255, 0, 200 }, { 255, 0, 230, 230 },
    },
}

local HEART = Win95.sprite({
    ".rr.rr.",
    "rwrrrrr",
    "rrrrrrr",
    ".rrrrr.",
    "..rrr..",
    "...r...",
}, { r = "r", w = "w" })
local HEART_PLAIN = Win95.sprite({
    ".rr.rr.",
    "rrrrrrr",
    "rrrrrrr",
    ".rrrrr.",
    "..rrr..",
    "...r...",
}, { r = "r" })
local HEART_COLORS = { r = P.heart, w = P.heart_shine }
local EMPTY_HEART_COLORS = { r = { 70, 150, 255, 170 }, w = { 70, 150, 255, 170 } }

local SPADE = Win95.sprite({
    "...k...",
    "..kkk..",
    ".kkkkk.",
    "kkkkkkk",
    "kkkkkkk",
    "kk.k.kk",
    "..kkk..",
}, { k = "k" })
local SPADE_COLORS = { k = P.spade }
local SPADE_GLOW_COLORS = { k = P.violet }
local EMPTY_SPADE_COLORS = { k = { 60, 150, 255, 170 } }

local Q_GLYPH = Win95.sprite({ ".##.", "#..#", "#..#", "#.##", ".###" }, { ["#"] = "k" })

local ICON = Win95.sprite({
    "kkkkkkkk.....",
    "kbbbbbbk.....",
    "kbwbbwbk.....",
    "kbbkkkkkkkkk.",
    "kbbkwwwwwwwk.",
    "kbwkwrrwrrwk.",
    "kbbkrsrrrrrk.",
    "kbbkrrrrrrrk.",
    "kbwkwrrrrrwk.",
    "kbbkwwrrrwwk.",
    "kkkkwwwrwwwk.",
    "...kwwwwwwwk.",
    "...kkkkkkkkk.",
}, {
    k = { 255, 0, 0, 0 }, b = { 255, 30, 70, 190 }, w = { 255, 255, 255, 255 },
    r = { 255, 220, 20, 40 }, s = { 255, 255, 160, 170 },
})

local function draw_icon(canvas, cx, cy, size, layer)
    local px = size / 13
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

Win95.add_text_widgets(UIWidget, widget_definitions, TEXT_PREFIX, TEXT_POOL, RENDER_SIZE)

AuspexFrame.add(widget_definitions, {
    render_size = RENDER_SIZE,
    outline_size = { 620, 620 },
    backdrop_alpha = 250,
    alpha = 150,
})

local definitions = { scenegraph_definition = scenegraph, widget_definitions = widget_definitions }

local HeartsView = class("HeartsView", "BaseView")

-- Per-frame card scratch, indexed by card id.
local HAND, TRICK, SWEEP = 1, 2, 3
local visible, zone, zone_seat = {}, {}, {}
local tx, ty, tw, th, tface = {}, {}, {}, {}, {}
local px, py, pflip, near, settled, anchored = {}, {}, {}, {}, {}, {}
local flying = {}
local draw_blur_card
local clip_a, clip_b = {}, {}

function HeartsView:init(settings, context)
    HeartsView.super.init(self, definitions, settings, context)

    self._game = context.game
    self._no_cursor = false
    self._canvas = Gfx.Canvas.new(RENDER_SIZE, RENDER_SIZE, 14000)
    self._canvas:set_layer_scale(10)
    self._particles = Gfx.Particles.new(520)
    self._shaker = Gfx.Shaker.new()
    self._motion = Cards.motion(MOTION_SPEED)
    self._text = Win95.text_pool(self, TEXT_PREFIX, TEXT_POOL)
    self._time = 0
    self._cw, self._ch = {}, {}
    self._resident = {}
    self._deal_order = {}
    self._deal_t0 = nil
    self._wiggle = {}
    self._card_opts = {}
    self._floaters = {}
    self._rockets = {}
    self._confetti = {}
    self._fireworks_until = 0
    self._next_rocket = 0
    self._banner = nil
    self._plate_flash = { -10, -10, -10, -10 }
    self._heart_pop = { {}, {}, {}, {} }
    self._shown_hearts = { 0, 0, 0, 0 }
    self._queen_at = -10
    self._queen_seat = nil
    self._table_flash = -10
    self._popups = {}
    self._sx, self._sy = 0, 0
    self._status_segments = { { text = "", w = 470 }, { text = "" } }
    self._desktop_opts = { app = "Hearts", icon = draw_icon, clock = "00:00" }
    self._window_opts = { title = "Hearts", icon = draw_icon, status = self._status_segments }
    self._dialog_cb = function(canvas, D, dialog, text, t) self:_draw_dialog_content(canvas, D, dialog, text, t) end
end

function HeartsView:dialogue_system() return nil end
function HeartsView:is_using_input() return false end

function HeartsView:update(dt, t, input_service)
    if self._game then self._game:update(dt) end
    return HeartsView.super.update(self, dt, t, input_service)
end

-- Input ---------------------------------------------------------------------------------------

local function input_value(input_service, action)
    if not input_service or not input_service.get then return false end
    local ok, value = pcall(input_service.get, input_service, action)
    if not ok then return false end
    return value == true or (type(value) == "number" and value > 0)
end

function HeartsView:_process_pointer(input_service, ui_renderer, base)
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

-- Events ----------------------------------------------------------------------------------------

local function slot_center(L, seat)
    local s = L.trick[seat]
    return s.x + L.card_w * 0.5, s.y + L.card_h * 0.5
end

local function plate_center(L, seat)
    local r = L.plate[seat]
    return r.x + r.w * 0.5, r.y + r.h * 0.5
end

function HeartsView:_floater(x, y, vx, vy, life, size, kind, gravity)
    local list = self._floaters
    local f = { x = x, y = y, vx = vx, vy = vy, life = life, max = life, size = size, kind = kind, gravity = gravity or 0, spin = math_random() * 6 }
    list[#list + 1] = f
    if #list > 90 then table.remove(list, 1) end
end

function HeartsView:_burst_floaters(x, y, count, kind, speed, size, gravity)
    for _ = 1, count do
        local a = math_random() * math_pi * 2
        local v = speed * (0.35 + math_random() * 0.65)
        self:_floater(x, y, math_cos(a) * v, math_sin(a) * v - speed * 0.3, 0.9 + math_random() * 0.7, size * (0.7 + math_random() * 0.6), kind, gravity)
    end
end

function HeartsView:_banner_show(title, subtitle, style, duration)
    self._banner = { title = title, subtitle = subtitle, style = style, t0 = self._time, duration = duration }
end

function HeartsView:_handle_events(game)
    local L = game:layout()
    local now = self._time
    local particles = self._particles

    game:drain_events(function(kind, a, b)
        if kind == "new_game" then
            self._banner = nil
            self._fireworks_until = 0
            self._confetti = {}
            self._floaters = {}
            self._popups = {}
            particles:clear()
        elseif kind == "deal" then
            self:_start_deal(game, L)
        elseif kind == "hearts_broken" then
            local x, y = slot_center(L, a)
            particles:flash(x, y, 70, 0.45, P.pink)
            particles:shockwave(x, y, 70, 0.55, P.heart, 3)
            self:_burst_floaters(x, y, 16, "heart", 170, 1.6, 160)
            self._shaker:add(0.18)
        elseif kind == "queen_played" then
            local x, y = slot_center(L, a)
            particles:burst(x, y, 10, 10, 60, 0.6, 1.2, 12, P.smoke, "smoke", 1, -30)
            particles:shockwave(x, y, 46, 0.4, P.violet, 2)
            self._shaker:add(0.12)
        elseif kind == "taken" then
            self._plate_flash[a] = now
            if (b or 0) > 0 then
                local x, y = plate_center(L, a)
                particles:burst(x, y, 8, 30, 110, 0.3, 0.6, 1.6, P.heart, "spark", 3)
                local popups = self._popups
                popups[#popups + 1] = { text = "+" .. b, x = x, y = L.plate[a].y - 4, t0 = now, color = b >= 13 and P.violet or P.pink }
                if #popups > 6 then table.remove(popups, 1) end
            end
        elseif kind == "queen" then
            local x, y = plate_center(L, a)
            self._queen_at = now
            self._queen_seat = a
            self._table_flash = now
            particles:flash(x, y, 120, 0.6, P.violet)
            particles:shockwave(x, y, 140, 0.8, P.violet, 5)
            particles:shockwave(x, y, 70, 0.5, P.white, 2)
            particles:burst(x, y, 40, 90, 380, 0.4, 1.0, 2.2, P.violet, "spark", 2)
            particles:burst(x, y, 12, 10, 80, 0.8, 1.6, 16, P.smoke, "smoke", 1, -40)
            self:_burst_floaters(x, y, 18, "spade", 230, 2, 220)
            self._shaker:add(0.75)
        elseif kind == "moon" then
            local name = a == SOUTH and "You" or game:name(a)
            self:_banner_show(name .. " shot the moon!", a == SOUTH and "Everyone else takes 26 points." or ("Everyone else takes 26 points, " .. name .. " takes none."), "moon", 2.9)
            self._fireworks_until = now + 2.6
            self._next_rocket = now
            self._shaker:add(0.35)
            if a == SOUTH then self:_spawn_confetti(L) end
        elseif kind == "game_over" then
            local winners = game:winners() or {}
            local title, subtitle
            if #winners == 1 then
                title = winners[1] == SOUTH and "You win!" or (game:name(winners[1]) .. " wins!")
            else
                local names = {}
                for i = 1, #winners do names[i] = game:name(winners[i]) end
                title = table.concat(names, " & ") .. " win!"
            end
            if a then
                subtitle = "Final score: " .. game:total(SOUTH) .. " points. Well played!"
                self:_spawn_confetti(L)
                self._fireworks_until = now + 6
            else
                subtitle = "You finished with " .. game:total(SOUTH) .. " points."
                self._fireworks_until = now + 1.6
            end
            self._next_rocket = now + 0.2
            self:_banner_show(title, subtitle, a and "win" or "lose", nil)
        elseif kind == "pass" then
            self:_snap_hidden_hands(game)
        elseif kind == "illegal" then
            self._wiggle[a] = now
        end
    end)
end

function HeartsView:_start_deal(game, L)
    local motion = self._motion
    motion:clear()
    self._resident = {}
    self._deal_t0 = self._time
    self._shown_hearts = { 0, 0, 0, 0 }
    self._heart_pop = { {}, {}, {}, {} }
    self._queen_at = -10
    local dx, dy = L.deck.x + L.card_w * 0.5, L.deck.y + L.card_h * 0.5
    for seat = 1, 4 do
        local hand = game:hand(seat)
        local turn = (seat - WEST) % 4
        for i = 1, #hand do
            local card = hand[i]
            local order = (i - 1) * 4 + turn
            self._deal_order[card] = order
            motion:place(card, dx, dy, false)
            motion:delay(card, order * DEAL_STAGGER)
            self._cw[card], self._ch[card] = L.card_w, L.card_h
        end
    end
end

-- The computer players re-sort their face-down hands after a pass; that is invisible, so the
-- cards they kept jump straight to their new places and only the passed cards travel.
function HeartsView:_snap_hidden_hands(game)
    local motion = self._motion
    local resident = self._resident
    for seat = WEST, EAST do
        local hand = game:hand(seat)
        local n = #hand
        for i = 1, n do
            local card = hand[i]
            if resident[card] == seat then
                local x, y, w, h = game:hand_slot(seat, i, n)
                motion:place(card, x + w * 0.5, y + h * 0.5, false)
            end
        end
    end
end

function HeartsView:_spawn_confetti(L)
    local confetti = self._confetti
    local window = L.window
    for i = 1, 120 do
        confetti[i] = {
            x = window.x + math_random() * window.w,
            y = window.y - math_random() * 220,
            vx = (math_random() - 0.5) * 60,
            vy = 60 + math_random() * 120,
            spin = (math_random() - 0.5) * 10,
            angle = math_random() * math_pi * 2,
            size = 3 + math_random() * 4,
            color = P.confetti[(i % #P.confetti) + 1],
            phase = math_random() * 6,
        }
    end
end

-- Effects -------------------------------------------------------------------------------------------

function HeartsView:_update_effects(game, dt)
    local now = self._time
    local L = game:layout()
    local c = L.client

    local floaters = self._floaters
    for i = #floaters, 1, -1 do
        local f = floaters[i]
        f.life = f.life - dt
        if f.life <= 0 then
            table.remove(floaters, i)
        else
            local damping = 1 / (1 + 1.6 * dt)
            f.vx = f.vx * damping
            f.vy = f.vy * damping + f.gravity * dt
            f.x = f.x + f.vx * dt
            f.y = f.y + f.vy * dt
        end
    end

    if now < self._fireworks_until and now >= self._next_rocket then
        self._next_rocket = now + 0.22 + math_random() * 0.25
        local rockets = self._rockets
        rockets[#rockets + 1] = {
            x = c.x + 60 + math_random() * (c.w - 120), y = c.y + c.h - 10,
            vx = (math_random() - 0.5) * 70, vy = -(250 + math_random() * 110),
            fuse = 0.55 + math_random() * 0.35,
            color = P.fireworks[math_random(1, #P.fireworks)],
        }
    end

    local rockets = self._rockets
    local particles = self._particles
    for i = #rockets, 1, -1 do
        local r = rockets[i]
        r.fuse = r.fuse - dt
        r.vy = r.vy + 170 * dt
        r.x = r.x + r.vx * dt
        r.y = r.y + r.vy * dt
        particles:emit(r.x, r.y, (math_random() - 0.5) * 20, 30, 0.35, 1.3, r.color, "ember", 3)
        if r.fuse <= 0 then
            particles:burst(r.x, r.y, 34, 60, 220, 0.6, 1.3, 2, r.color, "spark", 1.8, 90)
            particles:shockwave(r.x, r.y, 60, 0.5, r.color, 2)
            particles:flash(r.x, r.y, 50, 0.3, r.color)
            if math_random() < 0.35 then self:_burst_floaters(r.x, r.y, 6, "heart", 120, 1.4, 120) end
            table.remove(rockets, i)
        end
    end

    -- Hearts on the name plates pop in one by one as the tricks arrive.
    for seat = 1, 4 do
        local have = game:hearts_taken(seat)
        local shown = self._shown_hearts[seat]
        if have > shown then
            local pops = self._heart_pop[seat]
            for k = shown + 1, have do pops[k] = now + (k - shown - 1) * 0.07 end
            self._shown_hearts[seat] = have
        elseif have < shown then
            self._shown_hearts[seat] = have
        end
    end
end

-- Cards -----------------------------------------------------------------------------------------------

local function rounded(canvas, x, y, w, h, layer, color, alpha)
    canvas:rect(x + 2, y, w - 4, h, layer, color, alpha)
    canvas:rect(x + 1, y + 1, w - 2, h - 2, layer, color, alpha)
    canvas:rect(x, y + 2, w, h - 4, layer, color, alpha)
end

-- Main colours of each card back, for cards whizzing across the table (a motion-blurred back).
local BACK_TINT = {
    blue = { { 255, 20, 70, 190 }, { 255, 10, 35, 120 } },
    red = { { 255, 190, 25, 35 }, { 255, 110, 10, 20 } },
    aquila = { { 255, 150, 10, 25 }, { 255, 60, 0, 10 } },
    fish = { { 255, 0, 170, 200 }, { 255, 0, 70, 130 } },
    castle = { { 255, 8, 14, 50 }, { 255, 40, 50, 120 } },
    robot = { { 255, 90, 120, 160 }, { 255, 40, 60, 90 } },
}

local SUIT_TINT = { { 255, 0, 0, 0 }, { 255, 210, 0, 0 }, { 255, 210, 0, 0 }, { 255, 0, 0, 0 } }

-- Simplified card for fast flights (a motion-blurred look); flip squashes it like Cards.draw_card.
draw_blur_card = function(canvas, x, y, w, h, layer, card, flip, back, alpha)
    local a = alpha or 255
    local sx = math_abs(flip * 2 - 1)
    local dw = math_max(2, w * sx)
    x = x + (w - dw) * 0.5
    canvas:rect(x + 2, y + 3, dw, h, layer, P.black, a * 0.2)
    if dw < 6 then
        canvas:rect(x, y, dw, h, layer, P.black, a)
        return
    end
    rounded(canvas, x, y, dw, h, layer, P.black, a)
    rounded(canvas, x + 1, y + 1, dw - 2, h - 2, layer, P.white, a)
    local i = math_max(2, math_min(dw, h) * 0.07)
    if flip < 0.5 then
        local tint = BACK_TINT[back] or BACK_TINT.blue
        local iw, ih = dw - i * 2, h - i * 2
        canvas:vgradient(x + i, y + i, iw, ih, layer, tint[1], tint[2], a, a, 3)
        for k = 1, 3 do
            canvas:rect(x + i, y + i + ih * k * 0.25 - 1, iw, 2, layer, P.white, a * 0.2)
            canvas:rect(x + i + iw * k * 0.25 - 1, y + i, 2, ih, layer, P.white, a * 0.2)
        end
    else
        local suit = math_floor((card - 1) / 13) + 1
        local u = w / 66
        canvas:rect(x + 4 * u * sx, y + 4 * u, 7 * u * sx, 16 * u, layer, SUIT_TINT[suit], a)
        canvas:rect(x + dw - 11 * u * sx, y + h - 20 * u, 7 * u * sx, 16 * u, layer, SUIT_TINT[suit], a)
        canvas:rect(x + dw * 0.3, y + h * 0.3, dw * 0.4, h * 0.4, layer, SUIT_TINT[suit], a * 0.35)
    end
end

function HeartsView:_lift(game, index, keys, focus, focus_button, hover)
    if not game:card_active(index) then return 0 end
    if keys then
        return (focus == index and not focus_button) and 8 or 0
    end
    return hover == index and 7 or 0
end

function HeartsView:_update_cards(game, dt)
    local L = game:layout()
    local phase = game:phase()
    local motion = self._motion
    local hover = game:hover()
    local focus, focus_button = game:focus()
    local keys = game:cursor_mode() == "keys"

    for c = 1, 52 do visible[c] = false end

    for seat = 1, 4 do
        local hand = game:hand(seat)
        local n = #hand
        for i = 1, n do
            local card = hand[i]
            local x, y, w, h = game:hand_slot(seat, i, n)
            if seat == SOUTH then
                y = y - game:raise_of(card) - self:_lift(game, i, keys, focus, focus_button, hover)
            end
            visible[card] = true
            zone[card], zone_seat[card] = HAND, seat
            tx[card], ty[card], tw[card], th[card] = x + w * 0.5, y + h * 0.5, w, h
            tface[card] = seat == SOUTH
        end
    end

    local trick = game:trick()
    local winner = game:trick_winner()
    for i = 1, trick.count do
        local card = trick.cards[i]
        local seat = trick.seats[i]
        visible[card] = true
        zone_seat[card] = seat
        tface[card] = true
        if phase == "sweep" and winner then
            local x, y = plate_center(L, winner)
            zone[card] = SWEEP
            tx[card], ty[card], tw[card], th[card] = x, y, L.card_w * 0.45, L.card_h * 0.45
        else
            local s = L.trick[seat]
            zone[card] = TRICK
            tx[card], ty[card], tw[card], th[card] = s.x + L.card_w * 0.5, s.y + L.card_h * 0.5, L.card_w, L.card_h
        end
    end

    local k = 1 - math_exp(-dt * MOTION_SPEED * 2.5)
    local cw, ch = self._cw, self._ch
    for card = 1, 52 do
        if visible[card] then
            local x, y, flip = motion:step(card, tx[card], ty[card], tface[card], dt)
            local w, h = cw[card] or tw[card], ch[card] or th[card]
            w = w + (tw[card] - w) * k
            h = h + (th[card] - h) * k
            if math_abs(w - tw[card]) < 0.2 then w = tw[card] end
            if math_abs(h - th[card]) < 0.2 then h = th[card] end
            cw[card], ch[card] = w, h
            local wig = self._wiggle[card]
            if wig then
                local age = self._time - wig
                if age < 0.4 then
                    x = x + math_sin(age * 55) * 4 * (1 - age / 0.4)
                else
                    self._wiggle[card] = nil
                end
            end
            px[card], py[card], pflip[card] = x, y, flip
            local dx, dy = tx[card] - x, ty[card] - y
            local d2 = dx * dx + dy * dy
            local flat = flip == 0 or flip == 1
            near[card] = d2 < 36 and flat
            settled[card] = d2 < 0.3 and flat and w == tw[card] and h == th[card]
            -- Cards that arrived in a hand stay drawn with it while it re-sorts.
            local resident = self._resident
            if zone[card] ~= HAND then
                resident[card] = nil
            elseif near[card] then
                resident[card] = zone_seat[card]
            elseif resident[card] ~= zone_seat[card] then
                resident[card] = nil
            end
            anchored[card] = flat and zone[card] == HAND and (resident[card] ~= nil or d2 < 1600)
        end
    end
end

function HeartsView:_waiting(card)
    local t0 = self._deal_t0
    local order = self._deal_order[card]
    return t0 ~= nil and order ~= nil and self._time < t0 + order * DEAL_STAGGER
end

-- Parts of card a left uncovered by card b drawn on top of it (b the same size), as up to two
-- clip boxes: the strip beside b plus the band above or below it. Returns how many boxes are in
-- clip_a/clip_b (0 when b hides a completely), or nil when a must be drawn whole.
function HeartsView:_uncovered(a, b)
    if not b or not anchored[a] or not anchored[b] or self:_waiting(b) then return nil end
    local cw, ch = self._cw, self._ch
    local w, h = cw[a], ch[a]
    if w ~= cw[b] or h ~= ch[b] then return nil end
    local ax, ay = px[a] - w * 0.5, py[a] - h * 0.5
    local bx, by = px[b] - w * 0.5, py[b] - h * 0.5
    local dx, dy = bx - ax, by - ay
    if math_abs(dx) >= w or math_abs(dy) >= h then return nil end
    local sx, sy = self._sx, self._sy
    local n = 0
    local x0, x1 = ax - 4, ax + w + 4
    if dx >= 0.5 then
        n = 1
        clip_a[1], clip_a[2], clip_a[3], clip_a[4] = ax - 4 + sx, ay - 4 + sy, bx + sx, ay + h + 4 + sy
        x0 = bx
    elseif dx <= -0.5 then
        n = 1
        clip_a[1], clip_a[2], clip_a[3], clip_a[4] = bx + w + sx, ay - 4 + sy, ax + w + 4 + sx, ay + h + 4 + sy
        x1 = bx + w
    end
    if math_abs(dy) >= 0.5 then
        n = n + 1
        local r = n == 1 and clip_a or clip_b
        if dy > 0 then
            r[1], r[2], r[3], r[4] = x0 + sx, ay - 4 + sy, x1 + sx, by + sy
        else
            r[1], r[2], r[3], r[4] = x0 + sx, by + h + sy, x1 + sx, ay + h + 4 + sy
        end
    end
    return n
end

-- The card drawn over hand[i]: the next one already in the hand (cards still flying in are skipped,
-- they land on top later anyway).
function HeartsView:_cover(hand, i)
    local a = hand[i]
    local w, h = self._cw[a], self._ch[a]
    for j = i + 1, #hand do
        local card = hand[j]
        if anchored[card] and self._cw[card] == w and self._ch[card] == h and not self:_waiting(card) then return card end
    end
    return nil
end

-- Draws a card through the regions _uncovered found (or whole); fn(x, y, w, h) runs per region.
function HeartsView:_draw_card_parts(canvas, card, layer, cover, fn)
    local n = self:_uncovered(card, cover)
    if not n then
        local x, y, w, h = self:_draw_card(canvas, card, layer)
        if fn then fn(self, canvas, card, x, y, w, h, layer) end
        return
    end
    local x0, y0, x1, y1 = canvas:get_clip()
    for i = 1, n do
        local r = i == 1 and clip_a or clip_b
        canvas:set_clip(math_max(x0, r[1]), math_max(y0, r[2]), math_min(x1, r[3]), math_min(y1, r[4]))
        local x, y, w, h = self:_draw_card(canvas, card, layer)
        if fn then fn(self, canvas, card, x, y, w, h, layer) end
    end
    canvas:set_clip(x0, y0, x1, y1)
end

function HeartsView:_draw_card(canvas, card, layer, clip, alpha)
    local w, h = self._cw[card], self._ch[card]
    local x, y = px[card] - w * 0.5, py[card] - h * 0.5
    if not near[card] and not anchored[card] then
        local dx, dy = tx[card] - px[card], ty[card] - py[card]
        local flip = pflip[card]
        if dx * dx + dy * dy > 1600 or (flip > 0 and flip < 1) then
            draw_blur_card(canvas, x, y, w, h, layer, card, pflip[card], self._game:back(), alpha)
            return x, y, w, h
        end
    end
    local opts = self._card_opts
    opts.clip, opts.alpha = clip, alpha
    Cards.draw_card(canvas, x, y, w, h, card, pflip[card], layer, self._game:back(), self._time, opts)
    return x, y, w, h
end

local function frame(canvas, x, y, w, h, t, layer, color, alpha)
    canvas:rect(x - t, y - t, w + t * 2, t, layer, color, alpha)
    canvas:rect(x - t, y + h, w + t * 2, t, layer, color, alpha)
    canvas:rect(x - t, y, t, h, layer, color, alpha)
    canvas:rect(x + w, y, t, h, layer, color, alpha)
end

function HeartsView:_draw_hands(canvas, game, L, t)
    local nfly = 0

    for seat = WEST, EAST do
        local hand = game:hand(seat)
        local n = #hand
        for i = 1, n do
            local card = hand[i]
            if not self:_waiting(card) then
                if anchored[card] then
                    self:_draw_card_parts(canvas, card, 3.6, self:_cover(hand, i))
                else
                    nfly = nfly + 1
                    flying[nfly] = card
                end
            end
        end
    end

    local trick = game:trick()
    local phase = game:phase()
    local winner = game:trick_winner()
    local sweeping = phase == "sweep"
    for i = 1, trick.count do
        local card = trick.cards[i]
        if not sweeping then
            if near[card] then
                if phase == "trick" and winner == trick.seats[i] and settled[card] then
                    local w, h = self._cw[card], self._ch[card]
                    Cards.draw_highlight(canvas, px[card] - w * 0.5, py[card] - h * 0.5, w, h, 4.1, P.winner, t, 1)
                end
                self:_draw_card(canvas, card, 4.2)
            else
                nfly = nfly + 1
                flying[nfly] = card
            end
        end
    end

    self:_draw_south(canvas, game, L, t)

    local hand = game:hand(SOUTH)
    for i = 1, #hand do
        local card = hand[i]
        if not anchored[card] and not self:_waiting(card) then
            nfly = nfly + 1
            flying[nfly] = card
        end
    end

    -- Undealt part of the deck.
    if self._deal_t0 and self._time < self._deal_t0 + 52 * DEAL_STAGGER then
        local x, y = L.deck.x, L.deck.y
        local left = 1 - (self._time - self._deal_t0) / (52 * DEAL_STAGGER)
        local thick = math_floor(left * 4)
        for k = thick, 1, -1 do
            rounded(canvas, x + k, y + k, L.card_w, L.card_h, 5, P.black, 200)
            rounded(canvas, x + k, y + k - 1, L.card_w, L.card_h, 5, P.white, 255)
        end
        Cards.draw_back(canvas, x, y, L.card_w, L.card_h, game:back(), 5, t)
    end

    for i = 1, nfly do
        self:_draw_card(canvas, flying[i], 5)
    end

    if sweeping then
        local k = game:phase_progress()
        local alpha = 255 * (1 - k * k)
        for i = 1, trick.count do
            self:_draw_card(canvas, trick.cards[i], 5.1, nil, alpha)
        end
    end
end

function HeartsView:_draw_south(canvas, game, L, t)
    local hand = game:hand(SOUTH)
    local n = #hand
    local keys = game:cursor_mode() == "keys"
    local focus, focus_button = game:focus()
    local hover = game:hover()
    local phase = game:phase()
    local modal = game:shell():is_modal()
    local pulse = (math_sin(t * 6) + 1) * 0.5

    -- Glows under raised, received and focused cards.
    for i = 1, n do
        local card = hand[i]
        if anchored[card] and not self:_waiting(card) then
            local w, h = self._cw[card], self._ch[card]
            local x, y = px[card] - w * 0.5, py[card] - h * 0.5
            if game:is_selected(card) then
                canvas:soft_rect(x, y, w, h, 7, 4.5, P.select, 150 + pulse * 50, 4)
            elseif game:is_received(card) then
                canvas:soft_rect(x, y, w, h, 7, 4.5, P.received, 150 + pulse * 60, 4)
            elseif not modal and game:card_active(i) and ((keys and focus == i and not focus_button) or (not keys and hover == i)) then
                canvas:soft_rect(x, y, w, h, 6, 4.5, keys and P.focus or P.hover, keys and (110 + pulse * 80) or 90, 4)
            end
        end
    end

    local playing = phase == "play" or phase == "pass"
    for i = 1, n do
        local card = hand[i]
        if anchored[card] and not self:_waiting(card) then
            local dimmed = game:card_dimmed(card)
            self:_draw_card_parts(canvas, card, 4.6, self:_cover(hand, i), dimmed and self._dim_overlay or nil)
            if keys and playing and not modal and focus == i and not focus_button then
                local w, h = self._cw[card], self._ch[card]
                local x, y = px[card] - w * 0.5, py[card] - h * 0.5
                frame(canvas, x, y, w, h, 2, 4.6, P.focus, 170 + pulse * 85)
                frame(canvas, x - 2, y - 2, w + 4, h + 4, 1, 4.6, P.black, 120)
            end
        end
    end
end

function HeartsView._dim_overlay(self, canvas, card, x, y, w, h, layer)
    rounded(canvas, x, y, w, h, layer, P.dim, 105)
end

-- Table -------------------------------------------------------------------------------------------------

function HeartsView:_draw_felt(canvas, L, t)
    local c = L.client
    canvas:vgradient(c.x, c.y, c.w, c.h, 3.05, P.felt_top, P.felt_bottom, 255, 255, 20)
    canvas:glow(L.cx, L.cy + 10, 250, 3.15, P.felt_glow, 40, 4)
    canvas:vignette(c.x, c.y, c.w, c.h, 26, 3.2, 90, 5, P.felt_edge)
    Win95.bevel(canvas, c.x, c.y, c.w, c.h, 1, 3.2, true)

    -- Faint card-suit watermark in the middle of the table.
    local a = 20
    Win95.draw_sprite(canvas, HEART, L.cx - 44, L.cy - 18, 5, 3.21, HEART_COLORS, a)
    Win95.draw_sprite(canvas, SPADE, L.cx + 10, L.cy - 18, 5, 3.21, SPADE_COLORS, a * 1.6)
end

function HeartsView:_draw_plate(canvas, game, L, seat, t)
    local text = self._text
    local r = L.plate[seat]
    local now = self._time
    local flash = math_max(0, 1 - (now - self._plate_flash[seat]) / 0.45)
    local turn = game:turn() == seat and game:phase() == "play"
    local pulse = (math_sin(t * 5) + 1) * 0.5

    if turn then
        canvas:soft_rect(r.x, r.y, r.w, r.h, 6, 3.35, P.turn, 110 + pulse * 90, 4)
    end
    canvas:rect(r.x, r.y, r.w, r.h, 3.4, P.plate, 150)
    if flash > 0 then canvas:rect(r.x, r.y, r.w, r.h, 3.4, P.gold, 90 * flash) end
    canvas:rect(r.x, r.y, r.w, 1, 3.41, P.plate_light, 110)
    canvas:rect(r.x, r.y, 1, r.h, 3.41, P.plate_light, 110)
    canvas:rect(r.x, r.y + r.h - 1, r.w, 1, 3.41, P.plate_dark, 150)
    canvas:rect(r.x + r.w - 1, r.y, 1, r.h, 3.41, P.plate_dark, 150)
    canvas:rect(r.x + 4, r.y + 19, r.w - 8, 1, 3.41, P.plate_light, 45)

    text:draw(game:name(seat), r.x + 6, r.y + 1, r.w - 34, 18, 12, turn and P.turn or P.name, "left", 3.45)
    text:draw(tostring(game:total(seat)), r.x + r.w - 32, r.y + 1, 27, 18, 12, P.score, "right", 3.45)

    local count = game:hearts_taken(seat)
    local pops = self._heart_pop[seat]
    for k = 1, 13 do
        local col, row = (k - 1) % 7, math_floor((k - 1) / 7)
        local x = r.x + 4 + col * 9.5 + 4.2
        local y = r.y + 25 + row * 10 + 3.6
        local at = k <= count and (pops[k] or 0) or nil
        if at and now >= at then
            local age = now - at
            local s = age < 0.25 and (1.2 + (1 - age / 0.25) * 1.4) or 1.2
            if age < 0.6 then canvas:rect(x - 5, y - 5, 10, 10, 3.42, P.heart, 120 * (1 - age / 0.6)) end
            Win95.draw_sprite(canvas, HEART, x - 3.5 * s, y - 3 * s, s, 3.43, HEART_COLORS)
        else
            Win95.draw_sprite(canvas, HEART_PLAIN, x - 4.2, y - 3.6, 1.2, 3.42, EMPTY_HEART_COLORS)
        end
    end

    local qx, qy = r.x + r.w - 13, r.y + 25
    if game:queen_taker() == seat then
        local age = now - self._queen_at
        local s = age < 0.3 and (1 + (1 - age / 0.3) * 1.5) or 1
        local w, h = 10 * s, 18 * s
        local x = qx + 5 - w * 0.5
        local y = qy + 9 - h * 0.5
        if age < 1.5 then canvas:soft_rect(x, y, w, h, 4, 3.42, P.violet, 200 * (1 - age / 1.5), 3) end
        canvas:rect(x, y, w, h, 3.43, P.black)
        canvas:rect(x + s, y + s, w - 2 * s, h - 2 * s, 3.43, P.white)
        Win95.draw_sprite(canvas, Q_GLYPH, x + 3 * s, y + 2 * s, s, 3.43, SPADE_COLORS)
        Win95.draw_sprite(canvas, SPADE, x + 1.5 * s, y + 9 * s, s, 3.43, SPADE_COLORS)
    else
        canvas:rect(qx, qy, 10, 18, 3.42, P.plate_light, 22)
        Win95.draw_sprite(canvas, SPADE, qx + 1.5, qy + 7, 1, 3.42, EMPTY_SPADE_COLORS)
    end
end

function HeartsView:_draw_arrow(canvas, L, dir, t)
    local ax, ay = L.arrow.x, L.arrow.y
    local dx, dy = 0, -1
    if dir == "left" then dx, dy = -1, 0 elseif dir == "right" then dx, dy = 1, 0 end
    local nx, ny = -dy, dx
    local bob = math_sin(t * 4) * 4
    local cx, cy = ax + dx * bob, ay + dy * bob

    canvas:glow(cx, cy, 44, 5.3, P.arrow, 50, 5)
    local function arrow(grow, layer, color)
        local tipx, tipy = cx + dx * (26 + grow), cy + dy * (26 + grow)
        local bx, by = cx + dx * 6, cy + dy * 6
        local ex, ey = cx - dx * (24 + grow), cy - dy * (24 + grow)
        local sw, hw = 5.5 + grow, 14 + grow * 1.6
        canvas:quad(ex + nx * sw, ey + ny * sw, bx + nx * sw, by + ny * sw, bx - nx * sw, by - ny * sw, ex - nx * sw, ey - ny * sw, layer, color)
        canvas:tri(bx + nx * hw, by + ny * hw, tipx, tipy, bx - nx * hw, by - ny * hw, layer, color)
    end
    arrow(2, 5.4, P.arrow_edge)
    arrow(0, 5.5, P.arrow)
    local sx, sy = cx - dx * 2 + nx * 2.5, cy - dy * 2 + ny * 2.5
    canvas:line(sx - dx * 18, sy - dy * 18, sx + dx * 8, sy + dy * 8, 2, 5.6, P.white, 150)
end

-- Faint outline where the next card will land, brighter on the player's own turn.
function HeartsView:_draw_turn_slot(canvas, game, L, t)
    local seat = game:turn()
    if not seat or game:phase() ~= "play" then return end
    local s = L.trick[seat]
    local pulse = (math_sin(t * 5) + 1) * 0.5
    local mine = seat == SOUTH
    local a = mine and (70 + pulse * 70) or (25 + pulse * 25)
    local w, h = L.card_w, L.card_h
    rounded(canvas, s.x, s.y, w, h, 3.5, P.shade, mine and 40 or 20)
    frame(canvas, s.x + 1, s.y + 1, w - 2, h - 2, 1, 3.51, mine and P.turn or P.white, a)
end

function HeartsView:_draw_center(canvas, game, L, t)
    self:_draw_turn_slot(canvas, game, L, t)
    local label = game:button_label()
    if not label then return end
    local phase = game:phase()
    if phase == "pass" then self:_draw_arrow(canvas, L, game:pass_dir(), t) end

    local b = L.button
    local enabled = game:button_enabled()
    local keys = game:cursor_mode() == "keys"
    local _, focus_button = game:focus()
    if enabled then
        local pulse = (math_sin(t * 4) + 1) * 0.5
        canvas:soft_rect(b.x, b.y, b.w, b.h, 7, 5.5, P.gold, 60 + pulse * 70, 4)
    end
    local focused = keys and focus_button
    Win95.button(canvas, self._text, b, label, focused, game:button_pressed(), true, 5.6, enabled)
end

function HeartsView:_draw_banner(canvas, L, t)
    local b = self._banner
    if not b then return end
    local now = self._time
    local age = now - b.t0
    local k_in = math_min(1, age / 0.35)
    local k_out = 1
    if b.duration then
        k_out = math_max(0, math_min(1, (b.t0 + b.duration - now) / 0.45))
        if k_out <= 0 then
            self._banner = nil
            return
        end
    end
    local ease = 1 - (1 - k_in) * (1 - k_in)
    local a = ease * k_out
    local c = L.client
    local cy = L.cy - 62
    local h = 64 * ease
    local half = c.w * 0.5
    local gold = b.style == "lose" and P.white or P.gold

    canvas:hgradient(c.x, cy - h * 0.5, half, h, 7.3, P.shade, P.shade, 0, 185 * a, 24)
    canvas:hgradient(c.x + half, cy - h * 0.5, half, h, 7.3, P.shade, P.shade, 185 * a, 0, 24)
    canvas:hgradient(c.x, cy - h * 0.5 - 2, half, 2, 7.31, gold, gold, 0, 255 * a, 24)
    canvas:hgradient(c.x + half, cy - h * 0.5 - 2, half, 2, 7.31, gold, gold, 255 * a, 0, 24)
    canvas:hgradient(c.x, cy + h * 0.5, half, 2, 7.31, gold, gold, 0, 255 * a, 24)
    canvas:hgradient(c.x + half, cy + h * 0.5, half, 2, 7.31, gold, gold, 255 * a, 0, 24)

    local sweep = (age * 0.6) % 1.6
    if sweep < 1 then
        local sx = c.x + sweep * c.w
        canvas:rect(sx - 20, cy - h * 0.5, 40, h, 7.32, P.white, 26 * a)
        canvas:rect(sx - 6, cy - h * 0.5, 12, h, 7.32, P.white, 30 * a)
    end

    local text = self._text
    local tw = Win95.text_width(b.title, 24)
    local bob = math_sin(t * 3) * 2
    local icon_y = cy - 18 + bob
    if b.style == "moon" then
        local mx = L.cx - tw * 0.5 - 30
        canvas:glow(mx, icon_y + 8, 26, 7.4, P.moon, 90 * a, 4)
        canvas:circle(mx, icon_y + 8, 11, 7.4, P.moon, 255 * a)
        canvas:circle(mx + 5, icon_y + 5, 9.5, 7.5, P.banner_mid, 255 * a)
        Win95.draw_sprite(canvas, HEART, L.cx + tw * 0.5 + 16, icon_y + 2, 2.6, 7.4, HEART_COLORS, 255 * a)
    else
        Win95.draw_sprite(canvas, HEART, L.cx - tw * 0.5 - 36, icon_y + 2, 2.6, 7.4, HEART_COLORS, 255 * a)
        Win95.draw_sprite(canvas, HEART, L.cx + tw * 0.5 + 18, icon_y + 2, 2.6, 7.4, HEART_COLORS, 255 * a)
    end

    text:draw(b.title, c.x + 1, cy - 29 + 1, c.w, 34, 24, P.black, "center", 7.55, nil, 200 * a)
    text:draw(b.title, c.x, cy - 29, c.w, 34, 24, gold, "center", 7.6, nil, 255 * a)
    if b.subtitle then
        text:draw(b.subtitle, c.x, cy + 5, c.w, 20, 12, P.white, "center", 7.6, nil, 235 * a)
    end
end

function HeartsView:_draw_queen_hit(canvas, L, t)
    local age = self._time - self._table_flash
    if age < 0.4 then
        local c = L.client
        canvas:rect(c.x, c.y, c.w, c.h, 7.15, P.violet, 120 * (1 - age / 0.4))
    end
    local qa = self._time - self._queen_at
    local seat = self._queen_seat
    if seat and qa < 0.8 then
        local x, y = plate_center(L, seat)
        local k = qa / 0.8
        local s = 4 + k * 9
        local alpha = 230 * (1 - k) * (1 - k)
        Win95.draw_sprite(canvas, SPADE, x - 3.5 * s - 2, y - 3.5 * s - 2, s + 0.6, 7.25, SPADE_GLOW_COLORS, alpha * 0.7)
        Win95.draw_sprite(canvas, SPADE, x - 3.5 * s, y - 3.5 * s, s, 7.26, SPADE_COLORS, alpha)
    end
end

function HeartsView:_draw_popups(canvas)
    local popups = self._popups
    local text = self._text
    local now = self._time
    for i = #popups, 1, -1 do
        local p = popups[i]
        local age = now - p.t0
        if age > 1.3 then
            table.remove(popups, i)
        else
            local k = age / 1.3
            local y = p.y - 26 * (1 - (1 - k) * (1 - k))
            local alpha = 255 * math_min(1, (1 - k) * 2.5)
            local size = age < 0.15 and (14 + (1 - age / 0.15) * 8) or 14
            text:draw(p.text, p.x - 40 + 1, y - 10 + 1, 80, 20, size, P.black, "center", 7.6, nil, alpha * 0.8)
            text:draw(p.text, p.x - 40, y - 10, 80, 20, size, p.color, "center", 7.65, nil, alpha)
        end
    end
end

function HeartsView:_draw_floaters(canvas)
    local floaters = self._floaters
    for i = 1, #floaters do
        local f = floaters[i]
        local k = f.life / f.max
        local alpha = 255 * math_min(1, k * 2.5)
        local s = f.size * (0.6 + k * 0.4)
        if f.kind == "heart" then
            Win95.draw_sprite(canvas, HEART, f.x - 3.5 * s, f.y - 3 * s, s, 7.2, HEART_COLORS, alpha)
        else
            Win95.draw_sprite(canvas, SPADE, f.x - 3.5 * s - 1, f.y - 3.5 * s - 1, s + 0.3, 7.2, SPADE_GLOW_COLORS, alpha * 0.8)
            Win95.draw_sprite(canvas, SPADE, f.x - 3.5 * s, f.y - 3.5 * s, s, 7.21, SPADE_COLORS, alpha)
        end
    end
end

function HeartsView:_draw_rockets(canvas)
    local rockets = self._rockets
    for i = 1, #rockets do
        local r = rockets[i]
        canvas:line(r.x, r.y, r.x - r.vx * 0.05, r.y - r.vy * 0.05, 2, 7, r.color, 230)
        canvas:rect(r.x - 1.5, r.y - 1.5, 3, 3, 7.05, P.white)
    end
end

function HeartsView:_draw_confetti(canvas, dt)
    local confetti = self._confetti
    local now = self._time
    for i = #confetti, 1, -1 do
        local c = confetti[i]
        c.vy = c.vy + 30 * dt
        c.x = c.x + (c.vx + math_sin(now * 3 + c.phase) * 30) * dt
        c.y = c.y + c.vy * dt
        c.angle = c.angle + c.spin * dt
        if c.y > TASKBAR_Y + 10 then
            table.remove(confetti, i)
        else
            local w = c.size * math_abs(math_cos(c.angle))
            canvas:rect(c.x - w * 0.5, c.y - c.size * 0.3, math_max(0.8, w), c.size * 0.6, 7.5, c.color, 235)
        end
    end
end

-- Dialogs ------------------------------------------------------------------------------------------------

function HeartsView:_draw_dialog_content(canvas, D, dialog, text, t)
    if dialog.kind == "score" then
        self:_draw_score_sheet(canvas, D, dialog, text, t)
    elseif dialog.kind == "deck" then
        self:_draw_deck_dialog(canvas, D, dialog, text, t)
    elseif dialog.kind == "about" then
        local box = D.box
        canvas:glow(box.x + 34, box.y + 64, 30, 9.2, P.heart, 60 + math_sin(t * 3) * 25, 4)
        draw_icon(canvas, box.x + 34, box.y + 64, 34, 9.3)
    end
end

function HeartsView:_draw_score_sheet(canvas, D, dialog, text, t)
    local game = self._game
    local box = D.box
    local x, y, w = box.x, box.y, box.w
    local winners = dialog.final and game:winners() or nil

    if dialog.final then
        local won = false
        for i = 1, #winners do
            if winners[i] == SOUTH then won = true end
        end
        canvas:glow(x + 30, y + 44, 22, 9.2, won and P.gold or P.heart, 70 + math_sin(t * 4) * 30, 4)
        draw_icon(canvas, x + 30, y + 44, 24, 9.3)
    end
    local mx = dialog.final and x + 50 or x + 16
    text:draw(dialog.message or "", mx, y + 28, w - (mx - x) - 16, 22, 14, C.text_black, "left", 10.5)
    text:draw(dialog.detail or "", mx, y + 48, w - (mx - x) - 16, 16, 11, C.text_gray, "left", 10.5)

    local history = game:history()
    local rows = dialog.rows_shown or 1
    local first = math_max(1, #history - rows + 1)
    local fx, fy = x + 14, y + 70
    local fw, fh = w - 28, 24 + rows * 17 + 4
    Win95.field(canvas, fx, fy, fw, fh, 9.2)

    local hand_w = 48
    local col_w = (fw - 4 - hand_w) / 4
    canvas:vgradient(fx + 2, fy + 2, fw - 4, 20, 9.21, C.face_light, C.face_dark, 255, 255, 3)
    canvas:rect(fx + 2, fy + 22, fw - 4, 1, 9.22, C.shadow)
    text:draw("Hand", fx + 2, fy + 2, hand_w, 20, 11, C.text_black, "center", 10.5)

    for s = 1, 4 do
        local cx = fx + 2 + hand_w + (s - 1) * col_w
        canvas:rect(cx, fy + 2, 1, fh - 4, 9.22, P.grid)
        local is_winner = false
        if winners then
            for i = 1, #winners do
                if winners[i] == s then is_winner = true end
            end
        end
        if is_winner then
            canvas:rect(cx + 1, fy + 2, col_w - 1, 20, 9.215, P.gold)
        end
        text:draw(game:name(s), cx, fy + 2, col_w, 20, 12, C.text_black, "center", 10.5)
    end

    if #history == 0 then
        text:draw("-", fx + 2, fy + 25, hand_w, 16, 11, C.text_gray, "center", 10.5)
        return
    end

    local last = history[#history]
    local low = math.huge
    for s = 1, 4 do low = math_min(low, last.totals[s]) end

    for j = 0, rows - 1 do
        local index = first + j
        local row = history[index]
        if not row then break end
        local ry = fy + 24 + j * 17
        local latest = index == #history
        if j % 2 == 1 then canvas:rect(fx + 2, ry, fw - 4, 17, 9.21, P.row_alt) end
        local label = tostring(row.hand)
        text:draw(label, fx + 2, ry, hand_w, 17, 11, C.text_gray, "center", 10.5)
        if row.moon then
            local mxp, myp = fx + hand_w - 6, ry + 8.5
            canvas:circle(mxp, myp, 4.5, 9.3, P.moon, 255, 1, 0, 12)
            canvas:circle(mxp + 2, myp - 1.5, 3.8, 9.4, j % 2 == 1 and P.row_alt or C.field, 255, 1, 0, 12)
        end
        for s = 1, 4 do
            local cx = fx + 2 + hand_w + (s - 1) * col_w
            local value = row.totals[s]
            local color = C.text_black
            if latest and value == low then
                canvas:rect(cx + 2, ry + 1, col_w - 3, 15, 9.22, C.highlight)
                color = C.text_white
            end
            if latest then
                text:draw(tostring(value), cx, ry, col_w * 0.55, 17, 12, color, "right", 10.5)
                local added = row.added[s]
                text:draw("+" .. added, cx + col_w * 0.58, ry, col_w * 0.4, 17, 10, latest and value == low and C.text_white or C.text_gray, "left", 10.5)
            else
                text:draw(tostring(value), cx, ry, col_w * 0.55, 17, 11, color, "right", 10.5)
            end
        end
    end
end

function HeartsView:_draw_deck_dialog(canvas, D, dialog, text, t)
    local shell = self._game:shell()
    local focus_kind, focus_index = shell:dialog_focus()
    local hover_kind, hover_a = shell:hover()
    local chosen = nil
    for i = 1, #D.controls do
        local control = D.controls[i]
        local spec = control.spec
        if spec.type == "tile" then
            local r = control.rect
            local selected = dialog.values.back == spec.value
            local lift = (hover_kind == "dialog_control" and hover_a == i) and 2 or 0
            if selected then
                chosen = spec.label
                canvas:rect(r.x - 4, r.y - 4 - lift, r.w + 8, r.h + 8, 9.2, C.highlight)
            end
            Cards.draw_back(canvas, r.x, r.y - lift, r.w, r.h, spec.value, 9.2, t)
            if focus_kind == "control" and focus_index == i then
                Win95.dotted_rect(canvas, r.x - 7, r.y - 7 - lift, r.w + 14, r.h + 14, 9.25, C.black)
            end
        end
    end
    if chosen then
        text:draw(chosen, D.box.x + 16, D.box.y + 130, D.box.w - 32, 18, 12, C.text_black, "center", 10.5)
    end
end

-- Main draw ------------------------------------------------------------------------------------------------

function HeartsView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local game = self._game
    local text = self._text
    text:reset()

    if not game then
        HeartsView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
        return
    end

    dt = math_min(dt or 0.016, 0.05)
    self._time = self._time + dt

    local base = self:_scenegraph_world_position("scanner_base")
    self:_process_pointer(input_service, ui_renderer, base)
    self:_handle_events(game)
    self:_update_effects(game, dt)
    self._particles:update(dt)
    self._shaker:update(dt, 7)
    self:_update_cards(game, dt)

    local canvas = self._canvas
    if canvas:begin(ui_renderer, base) then
        local time = self._time
        local L = game:layout()
        local shell = game:shell()

        local seconds = math_floor(game:time())
        local blink = math_floor(time * 2) % 2 == 0 and ":" or " "
        self._desktop_opts.clock = string.format("%02d%s%02d", math_floor(seconds / 60) % 100, blink, seconds % 60)
        Win95.draw_desktop(canvas, text, time, self._desktop_opts)

        local sx, sy = self._shaker.x, self._shaker.y
        self._sx, self._sy = sx, sy
        canvas:set_shake(sx, sy)
        text:set_offset(sx, sy)

        local segments = self._status_segments
        segments[1].text = game:status_text()
        segments[1].w = L.client.w - 86
        segments[2].text = (game:hand_number() > 0 and ("Hand " .. game:hand_number() .. "  ") or "") .. "Lv " .. game:level()
        Win95.draw_window(canvas, text, shell, time, self._window_opts)

        local c = L.client
        canvas:set_clip(c.x + sx, c.y + sy, c.x + c.w + sx, c.y + c.h + sy)
        self:_draw_felt(canvas, L, time)
        for seat = 1, 4 do self:_draw_plate(canvas, game, L, seat, time) end
        self:_draw_hands(canvas, game, L, time)
        self:_draw_center(canvas, game, L, time)
        self._particles:draw(canvas, 7)
        self:_draw_rockets(canvas)
        self:_draw_queen_hit(canvas, L, time)
        self:_draw_floaters(canvas)
        self:_draw_popups(canvas)
        self:_draw_banner(canvas, L, time)
        canvas:reset_clip()

        canvas:set_shake(0, 0)
        text:set_offset(0, 0)
        self._sx, self._sy = 0, 0
        self:_draw_confetti(canvas, dt)

        Win95.draw_menu(canvas, text, shell)
        Win95.draw_dialog(canvas, text, shell, time, self._dialog_cb)
        Win95.draw_hint(canvas, text, HINT)

        canvas:crt(0, 0, RENDER_SIZE, RENDER_SIZE, time, 11.5, {
            tint = C.hint, scan_alpha = 12, sweep_alpha = 10, vignette_depth = 60, vignette_alpha = 110,
            noise_count = 6, noise_alpha = 25, flicker = false,
        })
        canvas:finish()
    end

    HeartsView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

function HeartsView:destroy()
    self._canvas = nil
    self._particles = nil
    HeartsView.super.destroy(self)
end

return HeartsView
