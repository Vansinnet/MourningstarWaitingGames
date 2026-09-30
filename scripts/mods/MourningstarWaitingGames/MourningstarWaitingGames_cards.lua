-- Playing cards in the Windows 95 style for Solitaire and Hearts.
-- Every card is built from rects only, so a pile drawn on one layer stacks in painter order.
local mod = get_mod("MourningstarWaitingGames")
local Win95 = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_win95")

local math_abs = math.abs
local math_exp = math.exp
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_random = math.random
local math_sin = math.sin

local sprite = Win95.sprite
local mirror = Win95.mirror
local draw_sprite = Win95.draw_sprite

local Cards = {}

Cards.CLUBS, Cards.DIAMONDS, Cards.HEARTS, Cards.SPADES = 1, 2, 3, 4
Cards.SUIT_NAMES = { "Clubs", "Diamonds", "Hearts", "Spades" }
Cards.RANK_NAMES = { "Ace", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Jack", "Queen", "King" }

-- Card ids are 1..52: (suit - 1) * 13 + rank, rank 1 = Ace, 11-13 = Jack, Queen, King.
function Cards.id(suit, rank) return (suit - 1) * 13 + rank end
function Cards.suit(card) return math_floor((card - 1) / 13) + 1 end
function Cards.rank(card) return (card - 1) % 13 + 1 end
function Cards.is_red(card)
    local suit = Cards.suit(card)
    return suit == 2 or suit == 3
end
function Cards.name(card)
    return Cards.RANK_NAMES[Cards.rank(card)] .. " of " .. Cards.SUIT_NAMES[Cards.suit(card)]
end

function Cards.new_deck()
    local deck = {}
    for i = 1, 52 do deck[i] = i end
    return deck
end

function Cards.shuffle(list)
    for i = #list, 2, -1 do
        local j = math_random(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

-- Colours ------------------------------------------------------------------------------------

local C = {
    border = { 255, 0, 0, 0 },
    paper = { 255, 255, 255, 255 },
    paper_warm = { 255, 255, 236, 205 },
    red = { 255, 210, 0, 0 },
    black = { 255, 0, 0, 0 },
    shine = { 255, 255, 140, 140 },
    shine_black = { 255, 110, 110, 125 },
    shadow = { 255, 0, 0, 0 },
    gold = { 255, 240, 190, 50 },
    gold_dark = { 255, 170, 110, 20 },
    court_bg = { 255, 255, 250, 222 },
    slot = { 255, 0, 70, 0 },
    slot_fill = { 255, 0, 40, 0 },
}
Cards.C = C

local SUIT_COLORS = {
    { o = C.black, s = C.shine_black },
    { o = C.red, s = C.shine },
    { o = C.red, s = C.shine },
    { o = C.black, s = C.shine_black },
}

-- Court robes: primary, secondary.
local COURT_COLORS = {
    { r = { 255, 30, 60, 190 }, b = { 255, 205, 25, 30 } },
    { r = { 255, 205, 25, 30 }, b = { 255, 240, 190, 50 } },
    { r = { 255, 205, 25, 30 }, b = { 255, 30, 60, 190 } },
    { r = { 255, 30, 60, 190 }, b = { 255, 40, 40, 50 } },
}
local COURT_BASE = {
    k = { 255, 0, 0, 0 },
    y = { 255, 240, 190, 50 },
    s = { 255, 255, 214, 170 },
    h = { 255, 150, 85, 30 },
    w = { 255, 255, 255, 255 },
    g = { 255, 30, 140, 50 },
}
local court_palettes = {}
for suit = 1, 4 do
    local p = {}
    for k, v in pairs(COURT_BASE) do p[k] = v end
    p.r = COURT_COLORS[suit].r
    p.b = COURT_COLORS[suit].b
    p.m = SUIT_COLORS[suit].o
    court_palettes[suit] = p
end

-- Sprites ------------------------------------------------------------------------------------

local SUIT_PALETTE = { o = "o", s = "s" }

local SUITS = {
    sprite({
        ".....ooo.....",
        "....ooooo....",
        "....osooo....",
        "....ooooo....",
        ".ooo.ooo.ooo.",
        "osooo.o.ooooo",
        "ooooooooooooo",
        "ooooo.o.ooooo",
        ".ooo..o..ooo.",
        "......o......",
        ".....ooo.....",
        "...ooooooo...",
    }, SUIT_PALETTE),
    sprite({
        "......o......",
        ".....ooo.....",
        ".....ooo.....",
        "....osooo....",
        "...osooooo...",
        "..oooooooooo.",
        ".ooooooooooo.",
        "..ooooooooo..",
        "...ooooooo...",
        "....ooooo....",
        ".....ooo.....",
        ".....ooo.....",
        "......o......",
    }, SUIT_PALETTE),
    sprite({
        "..ooo...ooo..",
        ".osooo.ooooo.",
        "ossoooooooooo",
        "osooooooooooo",
        "ooooooooooooo",
        ".ooooooooooo.",
        ".ooooooooooo.",
        "..ooooooooo..",
        "...ooooooo...",
        "....ooooo....",
        ".....ooo.....",
        "......o......",
    }, SUIT_PALETTE),
    sprite({
        "......o......",
        ".....ooo.....",
        "....osooo....",
        "...osoooooo..",
        "..ooooooooo..",
        ".ooooooooooo.",
        "ooooooooooooo",
        "ooooooooooooo",
        "ooooooooooooo",
        ".oooo.o.oooo.",
        "..oo..o..oo..",
        ".....ooo.....",
        "...ooooooo...",
    }, SUIT_PALETTE),
}

local G = { ["#"] = "o" }
local RANKS = {
    sprite({ "..##..", ".####.", "##..##", "##..##", "######", "##..##", "##..##", "##..##" }, G),
    sprite({ ".####.", "##..##", "....##", "...##.", "..##..", ".##...", "##....", "######" }, G),
    sprite({ ".####.", "##..##", "....##", "..###.", "....##", "....##", "##..##", ".####." }, G),
    sprite({ "...##.", "..###.", ".####.", "##.##.", "######", "...##.", "...##.", "...##." }, G),
    sprite({ "######", "##....", "#####.", "....##", "....##", "....##", "##..##", ".####." }, G),
    sprite({ ".####.", "##....", "##....", "#####.", "##..##", "##..##", "##..##", ".####." }, G),
    sprite({ "######", "....##", "...##.", "...##.", "..##..", "..##..", ".##...", ".##..." }, G),
    sprite({ ".####.", "##..##", "##..##", ".####.", "##..##", "##..##", "##..##", ".####." }, G),
    sprite({ ".####.", "##..##", "##..##", "##..##", ".#####", "....##", "....##", ".####." }, G),
    sprite({ ".##..###.", "###.##.##", ".##.##.##", ".##.##.##", ".##.##.##", ".##.##.##", ".##.##.##", "####.###." }, G),
    sprite({ "..####", "....##", "....##", "....##", "....##", "##..##", "##..##", ".####." }, G),
    sprite({ ".####.", "##..##", "##..##", "##..##", "##..##", "##.###", ".####.", "....##" }, G),
    sprite({ "##..##", "##.##.", "####..", "###...", "####..", "##.##.", "##..##", "##..##" }, G),
}

local COURT_PALETTE = { k = "k", y = "y", s = "s", h = "h", w = "w", r = "r", b = "b", m = "m", g = "g" }

-- Upper halves of the court portraits; the lower half is the same image turned 180 degrees.
local COURTS = {
    [11] = sprite(mirror({
        "....bbbb",
        "...bbbbb",
        "..bbbyyy",
        ".kyyyyyy",
        "..khhhhh",
        "..hsssss",
        "..hskkss",
        "..hsssss",
        "..hssssr",
        "...sssss",
        "....ssss",
        "..yywwww",
        ".rryywwk",
        "rrrryybb",
        "rrrbyyrb",
        "rrrbbyrb",
        "rrbbbbyy",
    }), COURT_PALETTE),
    [12] = sprite(mirror({
        ".....y.y",
        "....yyyy",
        "...hyyry",
        "..hhhhhh",
        ".hhhssss",
        ".hhskkss",
        ".hhsssss",
        ".hhssssr",
        ".hhhssss",
        "hhhhhsss",
        "hhhbbwww",
        "hbbbwwmw",
        "hbbbbyyy",
        "bbbrbbbb",
        "bbrrrbbr",
        "brrrrrby",
        "brrrrrby",
    }), COURT_PALETTE),
    [13] = sprite(mirror({
        "...y...y",
        "...yy.yy",
        "...yyyyy",
        "..yrywyb",
        "..kkkkkk",
        "..hsssss",
        ".hsskkss",
        ".hssssss",
        ".hhsskkk",
        ".hhhhhhk",
        "..hhhhhh",
        "...hhhhh",
        ".wkwwwhh",
        "rrwwkwwh",
        "rrrryyyy",
        "brrrrrry",
        "bbrrrrrm",
    }), COURT_PALETTE),
}

-- Card backs -----------------------------------------------------------------------------

local BACK_SPRITES = {
    eagle = sprite(mirror({
        "y..........",
        "yy......y..",
        "yyy....yyy.",
        "yyyy..ykyy.",
        "yyyyy...yy.",
        ".yyyyy...yy",
        "..yyyyyyyyy",
        "...yyyyyyyy",
        "....yyy.yyy",
        ".....y..yyy",
        "........yyy",
        ".......y.yy",
        "......yy..y",
    }), { y = "y", k = "k" }),
    fish = sprite({
        "....oooo.....",
        "..oosooso...o",
        ".owkoosoooooo",
        "oooooosooo.oo",
        ".ooooosoooooo",
        "..oosooso...o",
        "....oooo.....",
    }, { o = "o", s = "s", w = "w", k = "k" }),
    castle = sprite({
        "k.k.k..............k.k.k",
        "kkkkk....k.k.k.....kkkkk",
        "kkkkk....kkkkk.....kkkkk",
        "kkykk....kkkkk.....kkykk",
        "kkkkk....kkykk.....kkkkk",
        "kkkkkk.k.kkkkk.k.kkkkkkk",
        "kkkkkkkkkkkkkkkkkkkkkkkk",
        "kkkkkkkkkkkkkkkkkkkkkkkk",
        "kkkykkkkkkkkkkkkkkkkykkk",
        "kkkkkkkkkk....kkkkkkkkkk",
        "kkkkkkkkk......kkkkkkkkk",
        "kkkkkkkkk......kkkkkkkkk",
    }, { k = "k", y = "y" }),
    moon = sprite({ ".www.", "wwwww", "wwwww", "wwwww", ".www." }, { w = "w" }),
    bat_up = sprite({ "k.....k", "kk.k.kk", ".kkkkk.", "...k..." }, { k = "k" }),
    bat_down = sprite({ "...k...", ".kkkkk.", "kk.k.kk", "k.....k" }, { k = "k" }),
    robot = sprite({
        ".....k.....",
        ".....k.....",
        "..kkkkkkk..",
        "..kgggggk..",
        "..kgegegk..",
        "..kgggggk..",
        "..kgkkkgk..",
        "..kkkkkkk..",
        "kkkgggggkkk",
        "k.kg123gk.k",
        "k.kgggggk.k",
        "k.kgggggk.k",
        "..kkkkkkk..",
        "..kk...kk..",
        ".kkk...kkk.",
    }, { k = "k", g = "g", e = "e", ["1"] = "l1", ["2"] = "l2", ["3"] = "l3" }),
}

local BACK_COLORS = {
    blue = { 255, 20, 70, 190 },
    blue_dark = { 255, 10, 35, 120 },
    red = { 255, 190, 25, 35 },
    red_dark = { 255, 110, 10, 20 },
    weave_light = { 255, 255, 255, 255 },
    crimson_top = { 255, 150, 10, 25 },
    crimson_bottom = { 255, 60, 0, 10 },
    sea_top = { 255, 0, 170, 200 },
    sea_bottom = { 255, 0, 70, 130 },
    weed = { 255, 20, 150, 70 },
    night_top = { 255, 8, 14, 50 },
    night_bottom = { 255, 40, 50, 120 },
    steel_top = { 255, 90, 120, 160 },
    steel_bottom = { 255, 40, 60, 90 },
}

local EAGLE_COLORS = { y = C.gold, k = { 255, 90, 10, 10 } }
local FISH_COLORS = { o = { 255, 255, 140, 20 }, s = { 255, 255, 220, 150 }, w = { 255, 255, 255, 255 }, k = { 255, 0, 0, 0 } }
local CASTLE_COLORS = { k = { 255, 12, 12, 24 }, y = { 255, 255, 220, 90 } }
local MOON_COLORS = { w = { 255, 255, 245, 190 } }
local BAT_COLORS = { k = { 255, 0, 0, 0 } }
local robot_colors = {
    k = { 255, 20, 25, 35 }, g = { 255, 170, 180, 195 }, e = { 255, 255, 60, 40 },
    l1 = { 255, 255, 40, 40 }, l2 = { 255, 40, 230, 60 }, l3 = { 255, 255, 220, 40 },
}
local LIGHT_OFF = { 255, 60, 60, 70 }
local LIGHT_ON = { { 255, 255, 40, 40 }, { 255, 40, 230, 60 }, { 255, 255, 220, 40 } }

Cards.BACKS = {
    { id = "blue", name = "Blue Weave" },
    { id = "red", name = "Red Weave" },
    { id = "aquila", name = "Aquila" },
    { id = "fish", name = "Fish" },
    { id = "castle", name = "Castle" },
    { id = "robot", name = "Robot" },
}

-- Drawing helpers ----------------------------------------------------------------------

local function rounded(canvas, x, y, w, h, layer, color, alpha)
    canvas:rect(x + 2, y, w - 4, h, layer, color, alpha)
    canvas:rect(x + 1, y + 1, w - 2, h - 2, layer, color, alpha)
    canvas:rect(x, y + 2, w, h - 4, layer, color, alpha)
end

local function blank(canvas, x, y, w, h, layer, alpha)
    rounded(canvas, x, y, w, h, layer, C.border, alpha)
    rounded(canvas, x + 1, y + 1, w - 2, h - 2, layer, C.paper, alpha)
end

-- Runs fn with the canvas clip narrowed to the given rect, then restores it.
local function with_clip(canvas, clip, fn, ...)
    if not clip then return fn(...) end
    local x0, y0, x1, y1 = canvas:get_clip()
    canvas:set_clip(math_max(x0, clip[1]), math_max(y0, clip[2]), math_min(x1, clip[3]), math_min(y1, clip[4]))
    fn(...)
    canvas:set_clip(x0, y0, x1, y1)
end

-- Pip centres as fractions of the card; true in the third slot turns the pip upside down.
local L, M, R = 0.29, 0.5, 0.71
local PIPS = {
    [2] = { { M, 0.2 }, { M, 0.8, true } },
    [3] = { { M, 0.2 }, { M, 0.5 }, { M, 0.8, true } },
    [4] = { { L, 0.2 }, { R, 0.2 }, { L, 0.8, true }, { R, 0.8, true } },
    [5] = { { L, 0.2 }, { R, 0.2 }, { M, 0.5 }, { L, 0.8, true }, { R, 0.8, true } },
    [6] = { { L, 0.2 }, { R, 0.2 }, { L, 0.5 }, { R, 0.5 }, { L, 0.8, true }, { R, 0.8, true } },
    [7] = { { L, 0.2 }, { R, 0.2 }, { M, 0.35 }, { L, 0.5 }, { R, 0.5 }, { L, 0.8, true }, { R, 0.8, true } },
    [8] = { { L, 0.2 }, { R, 0.2 }, { M, 0.35 }, { L, 0.5 }, { R, 0.5 }, { M, 0.65, true }, { L, 0.8, true }, { R, 0.8, true } },
    [9] = { { L, 0.2 }, { R, 0.2 }, { L, 0.4 }, { R, 0.4 }, { M, 0.5 }, { L, 0.6, true }, { R, 0.6, true }, { L, 0.8, true }, { R, 0.8, true } },
    [10] = { { L, 0.2 }, { R, 0.2 }, { M, 0.31 }, { L, 0.4 }, { R, 0.4 }, { L, 0.6, true }, { R, 0.6, true }, { M, 0.69, true }, { L, 0.8, true }, { R, 0.8, true } },
}

local function draw_index(canvas, card, x, y, w, h, u, sx, layer, alpha)
    local suit, rank = Cards.suit(card), Cards.rank(card)
    local colors = SUIT_COLORS[suit]
    local glyph = RANKS[rank]
    local gpx = 1.2 * u
    local gpx_x = gpx * sx * (rank == 10 and 0.72 or 1)
    local suit_px = 0.62 * u
    local gw = glyph.w * gpx_x
    local gh = glyph.h * gpx
    local sw = 13 * suit_px * sx
    local left = x + 3.5 * u * sx
    local top = y + 4 * u

    local cx = left + math_max(gw, sw) * 0.5
    draw_sprite(canvas, glyph, cx - gw * 0.5, top, gpx_x, layer, colors, alpha, false, false, gpx)
    draw_sprite(canvas, SUITS[suit], cx - sw * 0.5, top + gh + 2 * u, suit_px * sx, layer, colors, alpha, false, false, suit_px)

    local right = x + w - 3.5 * u * sx
    local bottom = y + h - 4 * u
    cx = right - math_max(gw, sw) * 0.5
    draw_sprite(canvas, glyph, cx - gw * 0.5, bottom - gh, gpx_x, layer, colors, alpha, true, true, gpx)
    draw_sprite(canvas, SUITS[suit], cx - sw * 0.5, bottom - gh - 2 * u - 13 * suit_px, suit_px * sx, layer, colors, alpha, true, true, suit_px)
end

local function draw_pip(canvas, suit, cx, cy, px, sx, layer, colors, alpha, flip)
    local s = SUITS[suit]
    draw_sprite(canvas, s, cx - s.w * px * sx * 0.5, cy - s.h * px * 0.5, px * sx, layer, colors, alpha, flip, flip, px)
end

local function draw_court(canvas, card, x, y, w, h, u, sx, layer, alpha)
    local suit, rank = Cards.suit(card), Cards.rank(card)
    local fx, fy = x + w * 0.2, y + h * 0.12
    local fw, fh = w * 0.6, h * 0.76

    canvas:rect(fx, fy, fw, fh, layer, C.gold_dark, alpha)
    canvas:rect(fx + u * sx, fy + u, fw - 2 * u * sx, fh - 2 * u, layer, C.court_bg, alpha)

    local portrait = COURTS[rank]
    local inner_w, inner_h = fw - 4 * u * sx, fh - 4 * u
    local px = math_min(inner_w / sx / portrait.w, inner_h * 0.5 / portrait.h)
    local pw, ph = portrait.w * px * sx, portrait.h * px
    local px_x = px * sx
    local left = fx + (fw - pw) * 0.5
    local mid = fy + fh * 0.5
    local palette = court_palettes[suit]

    draw_sprite(canvas, portrait, left, mid - ph, px_x, layer, palette, alpha, false, false, px)
    draw_sprite(canvas, portrait, left, mid, px_x, layer, palette, alpha, true, true, px)
    canvas:rect(fx + 2 * u * sx, mid - 0.5 * u, fw - 4 * u * sx, u, layer, C.gold_dark, alpha)

    local colors = SUIT_COLORS[suit]
    draw_pip(canvas, suit, fx + 5 * u * sx, fy + 5 * u, 0.5 * u, sx, layer, colors, alpha, false)
    draw_pip(canvas, suit, fx + fw - 5 * u * sx, fy + fh - 5 * u, 0.5 * u, sx, layer, colors, alpha, true)
end

-- Faces -------------------------------------------------------------------------------------

-- opts: alpha, sx (horizontal squash 0..1 for flips), shadow (default true), clip {x0, y0, x1, y1}
function Cards.draw_face(canvas, x, y, w, h, card, layer, opts)
    local alpha = opts and opts.alpha
    local sx = opts and opts.sx or 1
    local clip = opts and opts.clip
    with_clip(canvas, clip, Cards._draw_face, canvas, x, y, w, h, card, layer, alpha, sx, not (opts and opts.shadow == false))
end

function Cards._draw_face(canvas, x, y, w, h, card, layer, alpha, sx, shadow)
    local u = w / 66
    local dw = w * sx
    local dx = x + (w - dw) * 0.5

    if shadow then
        canvas:rect(dx + 1, y + 2, dw, h, layer, C.shadow, (alpha or 255) * 0.16)
        canvas:rect(dx + 2, y + 3, dw, h, layer, C.shadow, (alpha or 255) * 0.1)
    end

    if dw < 6 then
        canvas:rect(dx, y, math_max(1, dw), h, layer, C.border, alpha)
        return
    end

    blank(canvas, dx, y, dw, h, layer, alpha)
    canvas:vgradient(dx + 1, y + h * 0.45, dw - 2, h * 0.55 - 3, layer, C.paper_warm, C.paper_warm, 0, (alpha or 255) * 0.4, 6)

    local suit, rank = Cards.suit(card), Cards.rank(card)
    local colors = SUIT_COLORS[suit]
    draw_index(canvas, card, dx, y, dw, h, u, sx, layer, alpha)

    if rank == 1 then
        local big = suit == Cards.SPADES and 2.7 or 2.2
        local cx, cy = dx + dw * 0.5, y + h * 0.5
        if suit == Cards.SPADES then
            for k = 0, 15 do
                local a = k / 16 * math.pi * 2
                canvas:rect(cx + math.cos(a) * 21 * u * sx - u, cy + math.sin(a) * 25 * u - u, 2 * u, 2 * u, layer, C.gold, alpha)
            end
        end
        draw_pip(canvas, suit, cx, cy, big * u, sx, layer, colors, alpha, false)
    elseif rank <= 10 then
        local pips = PIPS[rank]
        local px = 0.95 * u
        for i = 1, #pips do
            local p = pips[i]
            draw_pip(canvas, suit, dx + dw * p[1], y + h * p[2], px, sx, layer, colors, alpha, p[3])
        end
    else
        draw_court(canvas, card, dx, y, dw, h, u, sx, layer, alpha)
    end
end

-- Cheap card silhouette for long trails (the Solitaire win cascade): outline, paper, the
-- top-left rank and a suit-coloured tab. About a dozen rects.
function Cards.draw_stamp(canvas, x, y, w, h, card, layer, alpha)
    local u = w / 66
    local suit, rank = Cards.suit(card), Cards.rank(card)
    local colors = SUIT_COLORS[suit]
    local glyph = RANKS[rank]
    local gpx = 1.2 * u

    canvas:rect(x, y, w, h, layer, C.border, alpha)
    canvas:rect(x + 1, y + 1, w - 2, h - 2, layer, C.paper, alpha)
    draw_sprite(canvas, glyph, x + 3.5 * u, y + 4 * u, gpx * (rank == 10 and 0.72 or 1), layer, colors, alpha, false, false, gpx)
    canvas:rect(x + 3.5 * u, y + 6 * u + glyph.h * gpx, 6 * u, 6 * u, layer, colors.o, alpha)
end

-- Backs --------------------------------------------------------------------------------------

local function weave(canvas, ix, iy, iw, ih, u, layer, base, dark, alpha)
    canvas:vgradient(ix, iy, iw, ih, layer, base, dark, alpha, alpha, 4)
    local step = 6 * u
    local band = 2 * u
    local a = alpha or 255
    for yy = iy + u, iy + ih - band, step do
        canvas:rect(ix, yy, iw, band, layer, BACK_COLORS.weave_light, a * 0.22)
    end
    for xx = ix + u, ix + iw - band, step do
        canvas:rect(xx, iy, band, ih, layer, BACK_COLORS.weave_light, a * 0.22)
    end
    local row = 0
    for yy = iy + u, iy + ih - band, step do
        local xx = ix + u + (row % 2) * step
        while xx <= ix + iw - band do
            canvas:rect(xx, yy, band, band, layer, BACK_COLORS.weave_light, a * 0.6)
            xx = xx + step * 2
        end
        row = row + 1
    end
end

local function stars(canvas, ix, iy, iw, ih, u, layer, t, alpha)
    for k = 1, 14 do
        local sxp = ix + ((k * 37) % 97) / 97 * iw
        local syp = iy + ((k * 53) % 89) / 89 * ih * 0.55
        local tw = t and (math_sin(t * 3 + k) + 1) * 0.5 or 0.6
        canvas:rect(sxp, syp, u, u, layer, BACK_COLORS.weave_light, (alpha or 255) * (0.35 + tw * 0.6))
    end
end

local function draw_back_design(canvas, back, ix, iy, iw, ih, u, layer, t, alpha)
    local a = alpha or 255
    if back == "red" then
        weave(canvas, ix, iy, iw, ih, u, layer, BACK_COLORS.red, BACK_COLORS.red_dark, alpha)
    elseif back == "aquila" then
        canvas:vgradient(ix, iy, iw, ih, layer, BACK_COLORS.crimson_top, BACK_COLORS.crimson_bottom, a, a, 5)
        local b = 2 * u
        canvas:rect(ix + b, iy + b, iw - 2 * b, u, layer, C.gold, a)
        canvas:rect(ix + b, iy + ih - b - u, iw - 2 * b, u, layer, C.gold, a)
        canvas:rect(ix + b, iy + b, u, ih - 2 * b, layer, C.gold, a)
        canvas:rect(ix + iw - b - u, iy + b, u, ih - 2 * b, layer, C.gold, a)
        local e = BACK_SPRITES.eagle
        local px = math_min((iw - 8 * u) / e.w, (ih - 8 * u) / e.h * 0.6)
        draw_sprite(canvas, e, ix + (iw - e.w * px) * 0.5, iy + (ih - e.h * px) * 0.5, px, layer, EAGLE_COLORS, alpha)
        local glint = t and ((t * 0.5) % 2) or 2
        if glint < 1 then
            canvas:rect(ix + glint * iw - 2 * u, iy, 3 * u, ih, layer, BACK_COLORS.weave_light, a * 0.18)
        end
    elseif back == "fish" then
        canvas:vgradient(ix, iy, iw, ih, layer, BACK_COLORS.sea_top, BACK_COLORS.sea_bottom, a, a, 5)
        for k = 0, 3 do
            local wx = ix + (k + 0.5) * iw / 4
            local sway = t and math_sin(t * 1.5 + k) * u or 0
            canvas:rect(wx + sway, iy + ih * 0.72, 1.5 * u, ih * 0.28, layer, BACK_COLORS.weed, a)
            canvas:rect(wx + sway * 1.6 - u, iy + ih * 0.8, 1.5 * u, ih * 0.1, layer, BACK_COLORS.weed, a)
        end
        local f = BACK_SPRITES.fish
        local px = (iw * 0.55) / f.w
        local bob = t and math_sin(t * 2) * u or 0
        draw_sprite(canvas, f, ix + (iw - f.w * px) * 0.5, iy + ih * 0.38 + bob, px, layer, FISH_COLORS, alpha)
        for k = 0, 4 do
            local phase = t and ((t * 0.35 + k * 0.21) % 1) or k * 0.2
            local bx = ix + iw * 0.3 + math_sin(k * 2.1 + phase * 6) * 2 * u
            local by = iy + ih * 0.4 - phase * ih * 0.4
            canvas:rect(bx, by, 1.6 * u, 1.6 * u, layer, BACK_COLORS.weave_light, a * 0.7 * (1 - phase))
        end
    elseif back == "castle" then
        canvas:vgradient(ix, iy, iw, ih, layer, BACK_COLORS.night_top, BACK_COLORS.night_bottom, a, a, 6)
        stars(canvas, ix, iy, iw, ih, u, layer, t, alpha)
        local m = BACK_SPRITES.moon
        draw_sprite(canvas, m, ix + iw * 0.62, iy + ih * 0.12, 1.4 * u, layer, MOON_COLORS, alpha)
        local c = BACK_SPRITES.castle
        local px = iw / c.w
        draw_sprite(canvas, c, ix, iy + ih - c.h * px, px, layer, CASTLE_COLORS, alpha)
        if t then
            local p = (t * 0.25) % 1
            local bat = math_floor(t * 8) % 2 == 0 and BACK_SPRITES.bat_up or BACK_SPRITES.bat_down
            draw_sprite(canvas, bat, ix + p * (iw - 7 * u), iy + ih * 0.3 + math_sin(t * 3) * 3 * u, u, layer, BAT_COLORS, alpha)
        end
    elseif back == "robot" then
        canvas:vgradient(ix, iy, iw, ih, layer, BACK_COLORS.steel_top, BACK_COLORS.steel_bottom, a, a, 5)
        for yy = iy + 4 * u, iy + ih - u, 6 * u do
            canvas:rect(ix, yy, iw, 0.8 * u, layer, BACK_COLORS.weave_light, a * 0.12)
        end
        local r = BACK_SPRITES.robot
        local px = math_min(iw * 0.7 / r.w, ih * 0.7 / r.h)
        local step = t and math_floor(t * 3) or 0
        for k = 1, 3 do
            robot_colors["l" .. k] = ((step + k) % 3 == 0) and LIGHT_OFF or LIGHT_ON[k]
        end
        draw_sprite(canvas, r, ix + (iw - r.w * px) * 0.5, iy + (ih - r.h * px) * 0.5, px, layer, robot_colors, alpha)
    else
        weave(canvas, ix, iy, iw, ih, u, layer, BACK_COLORS.blue, BACK_COLORS.blue_dark, alpha)
    end
end

-- back: an id from Cards.BACKS. t animates the fish, castle, robot and aquila backs.
-- opts: alpha, sx, shadow, clip
function Cards.draw_back(canvas, x, y, w, h, back, layer, t, opts)
    local alpha = opts and opts.alpha
    local sx = opts and opts.sx or 1
    local clip = opts and opts.clip
    with_clip(canvas, clip, Cards._draw_back, canvas, x, y, w, h, back, layer, t, alpha, sx, not (opts and opts.shadow == false))
end

function Cards._draw_back(canvas, x, y, w, h, back, layer, t, alpha, sx, shadow)
    local u = w / 66
    local dw = w * sx
    local dx = x + (w - dw) * 0.5

    if shadow then
        canvas:rect(dx + 1, y + 2, dw, h, layer, C.shadow, (alpha or 255) * 0.16)
        canvas:rect(dx + 2, y + 3, dw, h, layer, C.shadow, (alpha or 255) * 0.1)
    end

    if dw < 6 then
        canvas:rect(dx, y, math_max(1, dw), h, layer, C.border, alpha)
        return
    end

    blank(canvas, dx, y, dw, h, layer, alpha)
    local inset = 4 * u
    local ix, iy = dx + inset * sx, y + inset
    local iw, ih = dw - 2 * inset * sx, h - 2 * inset
    local x0, y0, x1, y1 = canvas:get_clip()
    canvas:set_clip(math_max(x0, ix), math_max(y0, iy), math_min(x1, ix + iw), math_min(y1, iy + ih))
    draw_back_design(canvas, back, ix, iy, iw, ih, u, layer, t, alpha)
    canvas:set_clip(x0, y0, x1, y1)
end

-- flip: 0 = back showing, 1 = face showing; values between turn the card over.
function Cards.draw_card(canvas, x, y, w, h, card, flip, layer, back, t, opts)
    local sx = math_abs(flip * 2 - 1)
    local o = opts or {}
    local previous = o.sx
    o.sx = sx * (previous or 1)
    if flip >= 0.5 then
        Cards.draw_face(canvas, x, y, w, h, card, layer, o)
    else
        Cards.draw_back(canvas, x, y, w, h, back, layer, t, o)
    end
    o.sx = previous
end

-- Empty pile marker. kind: "outline", "recycle" (a ring: the stock can be turned over) or
-- "empty" (a cross: no more passes).
function Cards.draw_slot(canvas, x, y, w, h, layer, kind, alpha)
    local a = alpha or 255
    rounded(canvas, x, y, w, h, layer, C.slot, a)
    rounded(canvas, x + 1, y + 1, w - 2, h - 2, layer + 0.001, C.slot_fill, a * 0.6)
    canvas:rect(x + 3, y + 3, w - 6, h * 0.35, layer + 0.002, C.slot, a * 0.25)
    local cx, cy = x + w * 0.5, y + h * 0.5
    local r = math_min(w, h) * 0.26
    if kind == "recycle" then
        canvas:ring(cx, cy, r, math_max(2, w * 0.07), layer + 0.1, C.slot, a * 0.9, 24)
    elseif kind == "empty" then
        canvas:line(cx - r, cy - r, cx + r, cy + r, math_max(2, w * 0.07), layer + 0.1, C.slot, a * 0.9)
        canvas:line(cx - r, cy + r, cx + r, cy - r, math_max(2, w * 0.07), layer + 0.1, C.slot, a * 0.9)
    end
end

-- Pulsing glow around a card, for selections and drop targets. Uses rects only.
function Cards.draw_highlight(canvas, x, y, w, h, layer, color, t, strength)
    local pulse = t and (math_sin(t * 6) + 1) * 0.5 or 1
    local k = (strength or 1) * (0.6 + pulse * 0.4)
    canvas:soft_rect(x, y, w, h, 6, layer, color, 150 * k, 3)
    canvas:rect(x - 2, y - 2, w + 4, 2, layer + 0.001, color, 255 * k)
    canvas:rect(x - 2, y + h, w + 4, 2, layer + 0.001, color, 255 * k)
    canvas:rect(x - 2, y, 2, h, layer + 0.001, color, 255 * k)
    canvas:rect(x + w, y, 2, h, layer + 0.001, color, 255 * k)
end

-- Motion ---------------------------------------------------------------------------------------

-- Smoothly moves each card towards the position its pile gives it, and turns it over when its
-- face-up state changes. Views call step() for every card they draw, every frame.
local Motion = {}
Motion.__index = Motion

function Cards.motion(speed)
    return setmetatable({ _cards = {}, _speed = speed or 14 }, Motion)
end

function Motion:clear()
    self._cards = {}
end

-- Places a card without animation.
function Motion:place(id, x, y, face_up)
    local c = self._cards[id]
    if not c then
        c = {}
        self._cards[id] = c
    end
    c.x, c.y = x, y
    c.flip = face_up and 1 or 0
    c.delay = 0
end

-- Holds a card where it is for a while before it starts moving (staggered deals).
function Motion:delay(id, seconds)
    local c = self._cards[id]
    if c then c.delay = seconds end
end

function Motion:known(id)
    return self._cards[id] ~= nil
end

-- Returns x, y, flip (0..1) and whether the card is still travelling.
function Motion:step(id, tx, ty, face_up, dt)
    local c = self._cards[id]
    if not c then
        self:place(id, tx, ty, face_up)
        return tx, ty, face_up and 1 or 0, false
    end

    if c.delay > 0 then
        c.delay = c.delay - dt
        return c.x, c.y, c.flip, true
    end

    local k = 1 - math_exp(-dt * self._speed)
    c.x = c.x + (tx - c.x) * k
    c.y = c.y + (ty - c.y) * k
    local dx, dy = tx - c.x, ty - c.y
    local moving = dx * dx + dy * dy > 0.25
    if not moving then c.x, c.y = tx, ty end

    local target = face_up and 1 or 0
    if c.flip ~= target then
        local rate = dt * 5
        if c.flip < target then c.flip = math_min(target, c.flip + rate) else c.flip = math_max(target, c.flip - rate) end
        moving = true
    end

    return c.x, c.y, c.flip, moving
end

function Motion:position(id)
    local c = self._cards[id]
    if c then return c.x, c.y, c.flip end
end

return Cards
