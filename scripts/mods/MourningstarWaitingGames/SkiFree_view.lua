local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")
local Gfx = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_canvas")
local Win95 = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_win95")

local math_abs = math.abs
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_random = math.random
local math_sin = math.sin
local math_sqrt = math.sqrt

local RENDER_SIZE = 600
local TEXT_POOL = 90
local TEXT_PREFIX = "sf_text_"
local TASKBAR_Y = Win95.TASKBAR_Y
local PX = 2

local C = {
    snow_top = { 255, 214, 228, 246 },
    snow_bottom = { 255, 248, 251, 255 },
    speck = { 255, 176, 196, 228 },
    drift = { 255, 150, 176, 220 },
    sparkle = { 255, 255, 255, 255 },
    sparkle_blue = { 255, 150, 210, 255 },
    track = { 255, 138, 160, 198 },
    shadow = { 255, 96, 122, 172 },
    crater = { 255, 176, 194, 224 },
    powder = { 255, 226, 236, 255 },
    powder_blue = { 255, 178, 204, 246 },
    puff = { 255, 244, 248, 255 },
    flake = { 255, 255, 255, 255 },
    flake_edge = { 255, 150, 172, 214 },
    streak = { 255, 150, 180, 230 },
    red = { 255, 220, 20, 30 },
    cable = { 255, 52, 56, 72 },
    cable_light = { 255, 150, 156, 176 },
    black = { 255, 0, 0, 0 },
    white = { 255, 255, 255, 255 },
    stats_bg = { 255, 255, 255, 255 },
    stats_bg2 = { 255, 236, 242, 252 },
    text_black = { 255, 0, 0, 0 },
    text_white = { 255, 255, 255, 255 },
    text_red = { 255, 200, 20, 20 },
    text_blue = { 255, 20, 60, 190 },
    text_green = { 255, 20, 130, 40 },
    text_orange = { 255, 220, 110, 0 },
    text_shadow = { 255, 40, 50, 80 },
    tooltip = { 255, 255, 255, 225 },
    gold = { 255, 255, 214, 60 },
    confetti = {
        { 255, 236, 48, 48 }, { 255, 250, 146, 30 }, { 255, 250, 226, 40 },
        { 255, 60, 190, 72 }, { 255, 50, 120, 232 }, { 255, 150, 64, 204 },
    },
    banner = {
        start = { { 255, 210, 30, 44 }, { 255, 150, 16, 30 } },
        slalom = { { 255, 30, 80, 210 }, { 255, 16, 44, 140 } },
        freestyle = { { 255, 140, 56, 200 }, { 255, 90, 30, 140 } },
    },
}

-- Pixel art -----------------------------------------------------------------------------------

local P = {
    k = { 255, 28, 30, 48 },
    w = { 255, 255, 255, 255 },
    e = { 255, 218, 230, 246 },
    E = { 255, 170, 192, 222 },
    h = { 255, 226, 38, 52 },
    H = { 255, 150, 20, 40 },
    f = { 255, 250, 200, 156 },
    F = { 255, 212, 148, 110 },
    g = { 255, 36, 52, 100 },
    G = { 255, 130, 220, 255 },
    j = { 255, 220, 44, 150 },
    J = { 255, 146, 20, 104 },
    y = { 255, 255, 214, 40 },
    Y = { 255, 200, 150, 20 },
    p = { 255, 50, 84, 206 },
    P = { 255, 28, 44, 128 },
    b = { 255, 54, 52, 64 },
    s = { 255, 245, 112, 24 },
    S = { 255, 176, 64, 12 },
    l = { 255, 120, 126, 142 },
    d = { 255, 16, 84, 52 },
    m = { 255, 34, 132, 68 },
    n = { 255, 94, 182, 84 },
    o = { 255, 124, 80, 44 },
    O = { 255, 78, 48, 28 },
    u = { 255, 110, 100, 94 },
    U = { 255, 70, 62, 58 },
    r = { 255, 132, 134, 150 },
    R = { 255, 90, 92, 110 },
    q = { 255, 190, 192, 206 },
    ["1"] = { 255, 236, 48, 48 },
    ["2"] = { 255, 250, 146, 30 },
    ["3"] = { 255, 250, 226, 40 },
    ["4"] = { 255, 60, 190, 72 },
    ["5"] = { 255, 50, 120, 232 },
    ["6"] = { 255, 150, 64, 204 },
    c = { 255, 168, 110, 58 },
    C = { 255, 108, 64, 34 },
    t = { 255, 240, 110, 130 },
    v = { 255, 62, 178, 86 },
    V = { 255, 30, 112, 54 },
    x = { 255, 40, 150, 230 },
    X = { 255, 20, 90, 160 },
    z = { 255, 150, 164, 190 },
    Z = { 255, 206, 160, 98 },
    W = { 255, 140, 96, 52 },
    M = { 255, 190, 24, 44 },
    i = { 255, 112, 118, 136 },
    I = { 255, 66, 70, 88 },
    a = { 255, 180, 186, 202 },
    B = { 255, 40, 96, 232 },
    N = { 255, 20, 44, 140 },
    K = { 255, 104, 116, 150 },
}

local function grid(w, h)
    local g = { w = w, h = h }
    for y = 1, h do
        local row = {}
        for x = 1, w do row[x] = "." end
        g[y] = row
    end
    return g
end

local function put(g, x, y, ch)
    x, y = math_floor(x + 0.5), math_floor(y + 0.5)
    if x >= 0 and y >= 0 and x < g.w and y < g.h then g[y + 1][x + 1] = ch end
end

local function stamp(g, rows, ox, oy)
    for y = 1, #rows do
        local line = rows[y]
        for x = 1, #line do
            local ch = line:sub(x, x)
            if ch ~= "." then put(g, ox + x - 1, oy + y - 1, ch) end
        end
    end
end

local function line(g, x0, y0, x1, y1, ch, tip)
    local n = math_max(1, math_floor(math_max(math_abs(x1 - x0), math_abs(y1 - y0)) + 0.5))
    for i = 0, n do
        local t = i / n
        put(g, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, (tip and i == n) and tip or ch)
    end
end

local function rows_of(g)
    local out = {}
    for y = 1, g.h do out[y] = table.concat(g[y]) end
    return out
end

local function outline(g, ch)
    local marks = {}
    for y = 1, g.h do
        for x = 1, g.w do
            if g[y][x] == "." then
                local near = (y > 1 and g[y - 1][x] ~= "." and g[y - 1][x] ~= ch)
                    or (y < g.h and g[y + 1][x] ~= "." and g[y + 1][x] ~= ch)
                    or (x > 1 and g[y][x - 1] ~= "." and g[y][x - 1] ~= ch)
                    or (x < g.w and g[y][x + 1] ~= "." and g[y][x + 1] ~= ch)
                if near then marks[#marks + 1] = { x, y } end
            end
        end
    end
    for i = 1, #marks do g[marks[i][2]][marks[i][1]] = ch end
end

-- Skis lie on the ground plane, squashed vertically by the oblique view.
local SQUASH = 0.62
local function skis(g, fx, fy, angle, spread, front, back)
    local dx, dy = math_sin(angle), math_cos(angle) * SQUASH
    local px, py = math_cos(angle), -math_sin(angle) * SQUASH
    for side = -1, 1, 2 do
        local bx, by = fx + px * spread * side, fy + py * spread * side
        line(g, bx - dx * back, by - dy * back, bx + dx * front, by + dy * front, "s", "S")
    end
end

local ROWS = {}
local ANCHOR = {}

local BODY_FRONT = {
    ".....ww.....", "....hhhh....", "...hhhhhh...", "...HHHHHH...", "...gGgggg...", "...ffffff...",
    "....FffF....", "..jjjjjjjj..", ".jjjyyyyjjj.", "jjjjjjjjjjjj", "fljJjjjjJjlf", ".l.jjjjjj.l.",
    ".l.pppppp.l.", ".l.ppPPpp.l.", ".l.pp..pp.l.", "...bb..bb...",
}
local BODY_BACK = {
    ".....ww.....", "....hhhh....", "...hhhhhh...", "...hhhhhh...", "...HHHHHH...", "...hhhhhh...",
    "....FFFF....", "..jjjjjjjj..", ".jjjjjjjjjj.", "jjjjyyyyjjjj", "fljjjjjjjjlf", ".l.jjjjjj.l.",
    ".l.pppppp.l.", ".l.ppPPpp.l.", ".l.pp..pp.l.", "...bb..bb...",
}
local BODY_TURN = {
    "......ww....", ".....hhhh...", "....hhhhhh..", "....HHHHHH..", "...Gggggff..", "...fffffff..",
    ".....fFFf...", "...jjjjjjj..", "..jyyyyjjjj.", ".jjjjjjjjjjj", ".fjJjjjjjJfl", "..ljjjjjjj.l",
    "..lppppppp.l", "..lppPPppp.l", "...pp..pp..l", "...bb..bb...",
}
local BODY_SIDE = {
    "......ww....", ".....hhhh...", "....hhhhhh..", "....HHHHHH..", "...gGgfff...", "...ffffff...",
    ".....ffF....", "....jjjjj...", "...jyyjjjj..", "...jjjjjjjl.", "...fjjjjJjl.", "....jjjjjjl.",
    "....ppppp.l.", "....ppPpp..l", "....pp.pp..l", "....bb.bb...",
}
local BODY_WALK = {
    "......ww....", ".....hhhh...", "....hhhhhh..", "....HHHHHH..", "...gGgfff...", "...ffffff...",
    ".....ffF....", "....jjjjj...", "...jyyjjjj..", "..ljjjjjjjl.", "..lfjjjjJfl.", "..l.jjjjj.l.",
    "..l.ppppp.l.", "....ppPppp..", "...pp...pp..", "...bb...bb..",
}

local SK_W, SK_H, FX, FY = 16, 22, 8, 16

local function skier_rows(body, angle, spread, front, back, oy)
    local g = grid(SK_W, SK_H)
    local ski_first = math_abs(angle) > 0.3
    if ski_first then skis(g, FX - 0.5, FY + 0.5 + (oy or 0), angle, spread, front, back) end
    stamp(g, body, 2, oy or 0)
    if not ski_first then skis(g, FX - 0.5, FY + 0.5, angle, spread, front, back) end
    return rows_of(g)
end

ROWS.ski_down = skier_rows(BODY_FRONT, 0, 2, 5, 1)
ROWS.ski_steep = skier_rows(BODY_TURN, -math_pi / 6, 2, 7, 3)
ROWS.ski_wide = skier_rows(BODY_TURN, -math_pi / 3, 1.6, 8, 5)
ROWS.ski_side = skier_rows(BODY_SIDE, -math_pi / 2, 0.6, 8, 6)
ROWS.back = skier_rows(BODY_BACK, 0, 2, 1, 5)
ROWS.walk1 = skier_rows(BODY_WALK, -math_pi / 2, 0.6, 8, 6)
do
    local body = {}
    for i = 1, #BODY_WALK do body[i] = BODY_WALK[i] end
    body[15] = "....pp.pp..."
    body[16] = "....bb.bb..."
    ROWS.walk2 = skier_rows(body, -math_pi / 2, 0.6, 8, 6, -1)
end

ROWS.air = {
    "................", ".......ww.......", "......hhhh......", ".....hhhhhh.....", ".....HHHHHH.....",
    ".....gGgggg.....", ".....ffffff.....", "......FffF......", "..l.jjjjjjjj.l..", "..lfjjyyyyjjfl..",
    "...ljjjjjjjjl...", "....ljjjjjjl....", ".....pppppp.....", "....ppPPPPpp....", "....pp....pp....",
    "....bb....bb....", "....ss....ss....", "....ss....ss....", "....ss....ss....", "....SS....SS....",
}
ROWS.spread = {
    "................", ".......ww.......", "......hhhh......", ".....hhhhhh.....", ".....HHHHHH.....",
    "l....gGgggg....l", ".l...ffffff...l.", "..f...FffF...f..", "..jjjjjjjjjjjj..", "....jjyyyyjj....",
    ".....jjjjjj.....", ".....jjjjjj.....", "....pppppppp....", "...ppp.PP.ppp...", "..pp........pp..",
    ".bb..........bb.", "s..............s", ".s............s.", "..s..........s..", "..S..........S..",
}
ROWS.daffy = {
    "................", ".......ww.......", "......hhhh......", ".....hhhhhh.....", ".....HHHHHH.....",
    ".....gGgggg.....", ".....ffffff.....", "......FffF......", "....jjjjjjjjl...", "...fjjyyyyjjfl..",
    "....jjjjjjjj.l..", ".....jjjjjj..l..", ".....pppppp.....", "....pppPPPpp....", "...ppp...ppp....",
    "S.bbp.....pbb...", ".sss.......sss..", "...ss........sS.",
}
ROWS.flip90 = {
    "................", "................", "................", "................", "................",
    "................", "..s.............", "..s.l...........", "..sbpp.jjj.hh...", "..sbppjjjjfhhhw.",
    "..sbppjyjjfghhw.", "..sbppjjjjfhhh..", "..s.l.fjj..hh...", "..S..l..........",
}
ROWS.fallen = {
    "................", "................", "................", "................", "................",
    "................", "................", "................", "................", "s..........l....",
    ".s....ww..l.....", "..s..hhhhl......", "...shhHgGf......", "..jjjjhhff..s...", ".fjjyyjjjbbs....",
    "..jjjjjppppsp...", "...ppppppbs.....", "...lSppp.s......", "..l.S...s.......", ".l...S.S........",
}
ROWS.sit = {
    "................", "................", "................", "................", "................",
    ".......ww.......", "......hhhh......", ".....hhhhhh.....", ".....HHHHHH.....", ".....gGgggg.....",
    ".....ffffff.....", "......FffF......", "....jjjjjjjj....", "...jjjyyyyjjj...", "..fljjjjjjjjlf..",
    "...ljjjjjjjjl...", "..pppppppppppp..", "..ppPPPPPPPPpp..", "sbbssssssssssbbs", "SsssssssssssssS.",
}
for _, name in ipairs({ "ski_down", "ski_steep", "ski_wide", "ski_side", "back", "walk1", "walk2", "air", "spread", "daffy", "flip90", "fallen", "sit" }) do
    ANCHOR[name] = { FX, FY }
end

ROWS.tree_small = {
    "......w.......", ".....wmn......", "....wmmnn.....", "....dmmmn.....", "...wwmmnnw....",
    "..dmmmmmnnn...", "...ddmmmmnn...", "..wwwmmmnnnw..", ".ddmmmmmmmnnn.", "..dddmmmmmnn..",
    ".wwddmmmmmnnww", "ddddmmmmmmmnnn", ".dddddmmmmmnn.", "...ddddmmmn...", "......Oo......",
    "......Oo......", ".....OOoo.....",
}
ANCHOR.tree_small = { 7, 17 }
ROWS.tree_big = {
    ".........w..........", "........wmn.........", "........dmn.........", ".......wmmnn........",
    ".......dmmmn........", "......wwmmnnw.......", ".....ddmmmmnnn......", "......ddmmmnn.......",
    ".....wwwmmmnnww.....", "....dddmmmmmnnnn....", ".....dddmmmmnnn.....", "....wwddmmmmmnnww...",
    "...dddddmmmmmnnnnn..", "....ddddmmmmmmnnn...", "...wwdddmmmmmmnnnww.", "..dddddmmmmmmmmnnnnn",
    "...ddddddmmmmmmnnnn.", "..wwdddddmmmmmmnnnww", ".ddddddddmmmmmmmnnnn", "dddddddddmmmmmmmmnnn",
    ".ddddddddmmmmmmmnnn.", "...dddddddmmmmmnn...", ".......ddOoomn......", ".........Ooo........",
    ".........Ooo........", "........OOooo.......",
}
ANCHOR.tree_big = { 10.5, 26 }
ROWS.tree_dead = {
    "......U.......", "..U...u...U...", "...u..u..u....", "...uu.u.u...U.", ".U...uuu...u..",
    "..u...uu..u...", "...uu.uuuu....", ".....uuu....U.", "..U..uuu...u..", "...u.uuu.uu...",
    "....uuuuu.....", "......uuU.....", "......uuU.....", "......uuU.....", ".....uuuUU....",
}
ANCHOR.tree_dead = { 7, 15 }
ROWS.stump = {
    "...WWWWWW...", ".WWZZZZZZWW.", "WZZZWWWWZZZW", ".WZZZZZZZZW.", ".oWWWWWWWWO.", ".ooooooooOO.",
    ".oOooooooOO.", "..OOOOOOOO..",
}
ANCHOR.stump = { 6, 8 }
ROWS.rock = {
    ".....wwww.....", "...wwqqqqww...", "..qqqrrrrrqq..", ".qrrrrrrrrrRR.", "qrrrrrrrrrRRRR",
    "rrrrrrrrRRRRRR", ".RRRRRRRRRRRR.",
}
ANCHOR.rock = { 7, 7 }
ROWS.mogul = {
    ".....wwwwww.....", "...wwwwwwwwwe...", "..wwwwwwwweeee..", ".wwwwwwweeeeeEE.", "eeeeeeeeeeEEEEEE",
    "..EEEEEEEEEEEE..",
}
ANCHOR.mogul = { 8, 6 }
ROWS.ramp = {
    "....6666666666....", "...555555555555...", "...444444444444...", "..33333333333333..",
    "..22222222222222..", ".1111111111111111.", ".1111111111111111.", "WZZZZZZZZZZZZZZZZW",
    "WWWWWWWWWWWWWWWWWW",
}
ANCHOR.ramp = { 9, 9 }
ROWS.flag_red = {
    ".hhhhh.", ".hhhhhk", ".hhhHHk", ".HH...k", "......k", "......k", "......k", "......k", "......k",
    "......k", "......k", ".....kk",
}
ROWS.flag_blue = {
    ".BBBBB.", ".BBBBBk", ".BBBNNk", ".NN...k", "......k", "......k", "......k", "......k", "......k",
    "......k", "......k", ".....kk",
}
ANCHOR.flag_red = { 6.5, 12 }
ANCHOR.flag_blue = { 6.5, 12 }
ROWS.sign = {
    "WWWWWWWWWWWWWWWWWWWWWWWWWWWW", "WZZZZZZZZZZZZZZZZZZZZZZZZZZW", "WZZZZZZZZZZZZZZZZZZZZZZZZZZW",
    "WZZZZZZZZZZZZZZZZZZZZZZZZZZW", "WZZZZZZZZZZZZZZZZZZZZZZZZZZW", "WZZZZZZZZZZZZZZZZZZZZZZZZZZW",
    "WZZZZZZZZZZZZZZZZZZZZZZZZZZW", "WWWWWWWWWWWWWWWWWWWWWWWWWWWW", ".............WO.............",
    ".............WO.............", ".............WO.............", ".............WO.............",
    "............WWOO............",
}
ANCHOR.sign = { 14, 13 }
ROWS.banner_pole = {}
for i = 1, 19 do ROWS.banner_pole[i] = i % 2 == 1 and "hh" or "ww" end
ROWS.banner_pole[20] = "kk"
ANCHOR.banner_pole = { 1, 20 }
ROWS.lift_pole = { "aIa.....................aIa", "iiiiiiiiiiiiiiiiiiiiiiiiiii", "IIIIIIIIIIIIIIIIIIIIIIIIIII", "...........IiaII..........." }
for i = 5, 27 do ROWS.lift_pole[i] = "............iaI............" end
ROWS.lift_pole[28] = "...........IiaII..........."
ROWS.lift_pole[29] = "..........IIiaIII.........."
ANCHOR.lift_pole = { 13.5, 29 }
ROWS.chair = { "....I....", "....I....", "....I....", "....I....", "IIIIIIIII", "I.......I", "IiiiiiiiI", "IaaaaaaaI", "I.......I" }
ROWS.chair_rider = { "....I....", "..hhIh...", ".hhhhhh..", ".fgGggf..", "IjjjjjjjI", "IjyyyyjjI", "IpppppppI", "IaaaaaaaI", "I.bb.bb.I" }
ANCHOR.chair = { 4.5, 0 }
ANCHOR.chair_rider = { 4.5, 0 }

ROWS.dog1 = { "..CC........", ".cccc.......", "kcccc.....c.", ".tccwccccc..", "...cwcccccc.", "...cc....cc.", "..c.c...c.c." }
ROWS.dog2 = { "..CC........", ".cccc.......", "kcccc......c", ".tccwccccccc", "...cwcccccc.", "....cc..cc..", "....cc..cc.." }
ROWS.dog_sit = { "..CC.......", ".cccc......", "kcccc......", "..cccc.....", "..cwccc....", "..cwcccc...", "..cc.cccc.c", "..cc.ccccc." }
ANCHOR.dog1 = { 6, 7 }
ANCHOR.dog2 = { 6, 7 }
ANCHOR.dog_sit = { 5.5, 8 }

do
    local BOARDER = {
        "......yy....", ".....yyyy...", ".....YYYY...", ".....gGgf...", ".....ffff...", "....vvvvvv..",
        "...fvvvvvvf.", "....vvvvvv..", "....VVvvVV..", "....ppppp...", "....pp.pp...", "...bb...bb..",
    }
    local g = grid(16, 16)
    stamp(g, BOARDER, 2, 1)
    line(g, 2, 13, 13, 13, "x")
    line(g, 3, 14, 12, 14, "X")
    ROWS.boarder = rows_of(g)
    g = grid(16, 16)
    local lean = {}
    for i = 1, #BOARDER do lean[i] = BOARDER[i] end
    lean[6] = "...fvvvvvv.."
    lean[7] = "....vvvvvvf."
    stamp(g, lean, 1, 1)
    line(g, 1, 12, 12, 14, "x")
    line(g, 2, 13, 12, 15, "X")
    ROWS.boarder_turn = rows_of(g)
    g = grid(16, 16)
    stamp(g, { "..yy..........", ".yyyYf.vvvv...", ".YgGfvvvvvvpp.", "..ff.vVvvVppbb" }, 1, 9)
    line(g, 12, 10, 14, 15, "x")
    ROWS.boarder_fallen = rows_of(g)
    ANCHOR.boarder = { 7.5, 14 }
    ANCHOR.boarder_turn = { 7, 14 }
    ANCHOR.boarder_fallen = { 7.5, 14 }
end

do
    local HEAD = {
        ".......w.ww.w.......", ".....wwwwwwwwww.....", "....wwwwwwwwwwwwe...", "...wwwzzzzzzzzwwwe..",
        "...wwzzzzzzzzzzwwe..", "..wwzzkkkzzkkkzzwwe.", "..wwzzkhkzzkhkzzwwe.", "..wwzzzzzzzzzzzzwwe.",
        "..wwzzzzzzzzzzzzwwe.", "...wwzzzzzzzzzzwwe..", "....wwwzzzzzzwwee...",
    }
    local MOUTH_SHUT = { ".......kkkkkk......." }
    local MOUTH_OPEN = {
        ".....kkkkkkkkkk.....", ".....kMwMwwMwMk.....", ".....kMMMMMMMMk.....", ".....kMMMMMMMMk.....",
        ".....kMwMwwMwMk.....", "......kkkkkkkk......",
    }
    local MOUTH_GRIN = { ".....kkkkkkkkkk.....", ".....kMwwwwwwMk.....", "......kkkkkkkk......" }
    local TORSO = {
        "..wwwwwwwwwwwwwwww..", ".wwwwwwwwwwwwwwwwwe.", ".wwwwwwwewwwwwwwwee.", ".wwwwwwwwwwwwwwweee.",
        ".wwwwewwwwwwwewwwee.", ".wwwwwwwwwwwwwwwwee.", "..wwwwwwwwwwwwwwee..", "..wwwwewwwwwewwwee..",
        "...wwwwwwwwwwwwee...", "....wwwwwwwwwwee....",
    }
    local LEGS_STAND = {
        "....wwwwe..wwwwe....", "....wwwwe..wwwwe....", "....wwwwe..wwwwe....", "....wwwe....wwwe....",
        "...zzzzz....zzzzz...", "...kzkzk....kzkzk...",
    }
    local LEGS_RUN1 = {
        "....wwwwe..wwwwe....", "...wwwwe...wwwwe....", "..wwwwe....wwwwe....", ".wwwe.......wwwe....",
        "zzzzz......zzzzz....", "kzkzk......kzkzk....",
    }
    local LEGS_RUN2 = {
        "....wwwwe..wwwwe....", "....wwwwe...wwwwe...", "....wwwwe....wwwwe..", "....wwwe.......wwwe.",
        "...zzzzz......zzzzz.", "...kzkzk......kzkzk.",
    }
    local LEGS_JUMP = {
        "....wwwwe..wwwwe....", "...wwwwe....wwwwe...", "..wwwe........wwwe..", ".zzzzz........zzzzz.",
        ".kzkzk........kzkzk.",
    }
    local ARMS = {
        up = { -7, {
            "zkz....................zkz", "zzz....................zzz", ".www..................www.",
            ".www..................www.", "..www................www..", "..www................www..",
            "..wwww..............wwww..", "...wwww............wwww...", "....www............www....",
        } },
        swing1 = { -5, {
            "zkz.......................", "zzz.......................", ".www......................",
            ".wwww.....................", "..wwww....................", "...www....................",
            "....................www...", "....................wwww..", ".....................wwww.",
            "......................www.", "......................www.", "......................zzz.",
            "......................zkz.",
        } },
        swing2 = { -5, {
            ".......................zkz", ".......................zzz", "......................www.",
            ".....................wwww.", "....................wwww..", "....................www...",
            "...www....................", "..wwww....................", ".wwww.....................",
            ".www......................", ".www......................", ".zzz......................",
            ".zkz......................",
        } },
        hold = { -4, {
            "......zz..........zz......", "......www........www......", ".....wwww........wwww.....",
            "....wwww..........wwww....", "...wwww............wwww...", "...www..............www...",
        } },
        down = { 1, {
            "...www..............www...", "..wwww..............wwww..", "..www................www..",
            ".www..................www.", ".www..................www.", ".zzz..................zzz.",
            ".zkz..................zkz.",
        } },
    }
    local HELD_SKIER = {
        "s...........s", ".s..ww.hh..s.", "..shhhhffjs..", "...hHgGfjbs..", "..jjjjyjjppb.", "...jjjjjpppbs",
        "..s.......s..",
    }
    local HELD_LEGS = { "s....s", ".sbbs.", "..pp..", "..pp..", "..pP.." }
    local HELD_SKIS = { "s...s", ".s.s.", "..b.." }

    local function yeti(legs, arms, mouth, held, hx, hy, jump)
        local g = grid(28, 36)
        local head_y = jump and 4 or 7
        local torso_y = head_y + 10
        stamp(g, legs or LEGS_STAND, 4, torso_y + 10)
        stamp(g, TORSO, 4, torso_y)
        stamp(g, HEAD, 4, head_y)
        stamp(g, mouth or MOUTH_SHUT, 4, head_y + (mouth == MOUTH_OPEN and 6 or 8))
        if arms then stamp(g, ARMS[arms][2], 1, torso_y + ARMS[arms][1]) end
        if held then stamp(g, held, hx, hy) end
        outline(g, "K")
        return rows_of(g)
    end

    ROWS.yeti_run1 = yeti(LEGS_RUN1, "swing1", MOUTH_OPEN)
    ROWS.yeti_run2 = yeti(LEGS_RUN2, "swing2", MOUTH_OPEN)
    ROWS.yeti_grab = yeti(nil, "up", MOUTH_GRIN, HELD_SKIER, 8, 1)
    ROWS.yeti_open = yeti(nil, "hold", MOUTH_OPEN, HELD_SKIER, 8, 10)
    ROWS.yeti_chomp1 = yeti(nil, "hold", MOUTH_SHUT, HELD_LEGS, 12, 11)
    ROWS.yeti_chomp2 = yeti(nil, "hold", MOUTH_SHUT, HELD_SKIS, 13, 13)
    ROWS.yeti_gulp = yeti(nil, "down", MOUTH_GRIN)
    ROWS.yeti_dance1 = yeti(LEGS_JUMP, "up", MOUTH_GRIN, nil, nil, nil, true)
    ROWS.yeti_dance2 = yeti(nil, "down", MOUTH_OPEN)
    for name in pairs(ROWS) do
        if name:sub(1, 5) == "yeti_" then ANCHOR[name] = { 14, 33 } end
    end
end

ROWS.icon = {
    "...hh...", "..hhhh..", "..gGgg..", ".jjjjjj.", "fjjyyjjf", "..pppp..", "s.p..p.s", ".ss..ss.",
}
ANCHOR.icon = { 4, 4 }

local SPR = {}
for name, rows in pairs(ROWS) do
    local sprite = Win95.sprite(rows, P)
    local anchor = ANCHOR[name] or { sprite.w * 0.5, sprite.h }
    SPR[name] = { sprite = sprite, ax = anchor[1], ay = anchor[2], w = sprite.w, h = sprite.h }
end

local SKIER_FRAMES = { [0] = "ski_down", [1] = "ski_steep", [2] = "ski_wide", [3] = "ski_side" }
local HELI_FRAMES = { "ski_side", "ski_down", "ski_side", "back" }
local HELI_FLIP = { false, false, true, false }

local TYPE_SPRITE = {
    tree_small = "tree_small", tree_big = "tree_big", tree_dead = "tree_dead", stump = "stump", rock = "rock",
    mogul = "mogul", ramp = "ramp", lift_pole = "lift_pole", sign = "sign", banner_pole = "banner_pole",
}
local FLAT = { mogul = true, ramp = true }
local SHADOW_W = {
    tree_small = 22, tree_big = 30, tree_dead = 16, stump = 20, rock = 24, lift_pole = 12, sign = 12,
    banner_pole = 6, flag = 6, dog = 16, boarder = 20,
}

local CRASH_LABELS = {
    tree_small = "Timber!", tree_big = "Ouch!", tree_dead = "Crack!", rock = "Ouch!", stump = "Oof!",
    dog = "Woof!", boarder = "Hey!", trick = "Wipeout!", lift_pole = "Clang!", sign = "Bonk!", banner_pole = "Bonk!",
}
local STAT_LABELS = { "Time:", "Dist:", "Speed:", "Style:" }
local HOW_TO = {
    "Ski down the mountain and dodge the obstacles.",
    "Left / Right (A / D): turn one step at a time.",
    "Down (S): point straight downhill.",
    "Up (W): brake; stopped sideways: walk uphill.",
    "Space or click: jump. In the air: tricks!",
    "Rainbow ramps launch big jumps. Finish every",
    "trick before landing for Style points.",
    "Shift (hold) or F: go faster.",
    "Mouse: the skier heads toward the pointer.",
    "Slalom on the left: pass between each pair",
    "of flags, 5 s penalty per missed gate.",
    "After 2000 m... beware of the Yeti.",
}

local HINT = "A/D turn   S down   W brake/walk   Space jump/trick   Shift/F fast   Mouse steers   R new   Tab menu"

-- Scenegraph and widgets ---------------------------------------------------------------------

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

local SkiFreeView = class("SkiFreeView", "BaseView")
SkiFreeView.ART = { P = P, ROWS = ROWS, ANCHOR = ANCHOR, SPR = SPR }

function SkiFreeView:init(settings, context)
    SkiFreeView.super.init(self, definitions, settings, context)

    self._game = context.game
    self._no_cursor = false
    self._canvas = Gfx.Canvas.new(RENDER_SIZE, RENDER_SIZE, 14000)
    self._canvas:set_layer_scale(10)
    self._particles = Gfx.Particles.new(260)
    self._shaker = Gfx.Shaker.new()
    self._text = Win95.text_pool(self, TEXT_PREFIX, TEXT_POOL)
    self._time = 0
    self._draw_list = {}
    self._skier_entry = { kind = "_skier", x = 0, y = 0 }
    self._yeti_entry = { kind = "_yeti", x = 0, y = 0 }
    self._tracks = {}
    self._track_head = 0
    self._track_count = 0
    self._track_break = true
    self._decals = {}
    self._floats = {}
    self._flakes = {}
    self._streaks = {}
    self._confetti = {}
    self._flash_t = nil
    self._flash_power = 0
    self._last_cam_x = nil
    self._last_cam_y = nil
    self._banner_msg = nil
    self._prints = {}
    self._yeti_last = nil
    self._yeti_step = 0
    self._dialog_cb = function(c, D, dialog, pool, tt) self:_dialog_content(c, D, dialog, pool, tt) end
    self:_init_flakes()
end

function SkiFreeView:dialogue_system() return nil end
function SkiFreeView:is_using_input() return false end

function SkiFreeView:update(dt, t, input_service)
    if self._game then self._game:update(dt) end
    return SkiFreeView.super.update(self, dt, t, input_service)
end

-- Input -----------------------------------------------------------------------------------------

local function input_value(input_service, action)
    if not input_service or not input_service.get then return false end
    local ok, value = pcall(input_service.get, input_service, action)
    if not ok then return false end
    return value == true or (type(value) == "number" and value > 0)
end

function SkiFreeView:_process_pointer(input_service, ui_renderer, base)
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

-- Effects state -------------------------------------------------------------------------------------

function SkiFreeView:_init_flakes()
    local flakes = self._flakes
    for i = 1, 46 do
        flakes[i] = {
            x = math_random() * 560,
            y = math_random() * 470,
            depth = 0.25 + math_random() * 0.75,
            phase = math_random() * 6.28,
        }
    end
end

function SkiFreeView:_float(text, x, y, color, size, life, tag)
    local floats = self._floats
    if tag then
        for i = #floats, 1, -1 do
            if floats[i].tag == tag then table.remove(floats, i) end
        end
    end
    if #floats >= 10 then table.remove(floats, 1) end
    floats[#floats + 1] = { text = text, x = x, y = y, color = color, size = size or 12, t = 0, life = life or 1.3, tag = tag }
end

function SkiFreeView:_flash(power)
    self._flash_t = 0
    self._flash_power = power
end

function SkiFreeView:_add_track_point(x, y, angle)
    local tracks = self._tracks
    local head = self._track_head % 180 + 1
    local p = tracks[head]
    if not p then
        p = {}
        tracks[head] = p
    end
    p.x, p.y = x, y
    p.nx, p.ny = math_cos(angle) * 3, -math_sin(angle) * 3 * 0.62
    p.t = self._game:clock()
    p.brk = self._track_break
    self._track_break = false
    self._track_head = head
    self._track_count = math_min(180, self._track_count + 1)
end

function SkiFreeView:_update_tracks()
    local game = self._game
    local x, y, z = game:position()
    local state = game:state()
    if state ~= "ski" or z > 0 or game:speed() < 4 then
        self._track_break = true
        return
    end
    local last = self._tracks[self._track_head]
    if not self._track_break and last then
        local dx, dy = x - last.x, y - last.y
        if dx * dx + dy * dy < 25 then return end
    end
    self:_add_track_point(x, y, game:direction_angle())
end

function SkiFreeView:_handle_events()
    local game = self._game
    local particles = self._particles
    local shaker = self._shaker

    game:drain_events(function(kind, x, y, value, extra)
        if kind == "new" then
            particles:clear()
            self._track_count = 0
            self._track_break = true
            self._decals = {}
            self._floats = {}
            self._streaks = {}
            self._confetti = {}
            self._flash_t = nil
            self._last_cam_x = nil
            self._prints = {}
            self._yeti_last = nil
        elseif kind == "spray" or kind == "turn" then
            local n = math_floor(math_min(14, 3 + value * 6))
            local angle = game:direction_angle()
            local sx, sy = math_cos(angle), -math_sin(angle)
            for i = 1, n do
                local side = i % 2 == 0 and 1 or -1
                local speed = 40 + math_random() * 90
                particles:emit(x + (math_random() - 0.5) * 8, y - 2,
                    sx * side * speed + (math_random() - 0.5) * 30, sy * side * speed - 30 - math_random() * 40,
                    0.35 + math_random() * 0.35, 2 + math_random() * 2, i % 2 == 0 and C.powder_blue or C.powder, "dot", 3, 160)
            end
        elseif kind == "crash" then
            particles:burst(x, y - 8, 22, 40, 190, 0.4, 0.9, 2.5, C.powder, "dot", 3, 140)
            particles:burst(x, y - 6, 10, 10, 60, 0.6, 1.1, 7, C.puff, "smoke", 2, -15)
            particles:shockwave(x, y - 4, 26, 0.35, C.powder_blue, 2)
            shaker:add((value == "air" or value == "trick") and 0.6 or 0.42)
            local decals = self._decals
            if #decals >= 12 then table.remove(decals, 1) end
            decals[#decals + 1] = { x = x, y = y, t = game:clock() }
            self:_float(CRASH_LABELS[value] or "Ouch!", x, y - 40, C.text_red, 12, 1.1, "crash")
            local o = extra
            if o and (o.kind == "tree_small" or o.kind == "tree_big" or o.kind == "tree_dead") then
                local top = o.kind == "tree_big" and 44 or 28
                for _ = 1, 14 do
                    particles:emit(o.x + (math_random() - 0.5) * 26, o.y - top + math_random() * 20, (math_random() - 0.5) * 30, 10 + math_random() * 30,
                        0.6 + math_random() * 0.6, 2 + math_random() * 1.5, math_random() < 0.5 and C.powder or C.white, "dot", 0.5, 160)
                end
            end
        elseif kind == "ramp" then
            for i = 1, 16 do
                local c = C.confetti[(i % 6) + 1]
                particles:emit(x + (math_random() - 0.5) * 24, y - 4, (math_random() - 0.5) * 120, -40 - math_random() * 110,
                    0.5 + math_random() * 0.4, 2 + math_random() * 1.5, c, "dot", 1.5, 220)
            end
            shaker:add(0.12)
        elseif kind == "hop" or kind == "bump" then
            particles:burst(x, y, kind == "bump" and 10 or 6, 20, 80, 0.25, 0.5, 2, C.powder, "dot", 3, 120)
        elseif kind == "land" or kind == "touchdown" then
            particles:burst(x, y, 14, 30, 120, 0.3, 0.6, 2.2, C.powder, "dot", 3, 120)
            particles:burst(x, y - 2, 5, 10, 40, 0.5, 0.8, 5, C.puff, "smoke", 2, -10)
            if kind == "land" and value and value > 0 then
                self:_float("+" .. value .. " style", x, y - 44, C.text_green, 13, 1.4)
                if value >= 40 then self:_confetti_burst(x, y - 30) end
            end
        elseif kind == "trick" then
            local trick = game:tricks()[extra or 0]
            self:_float((trick and trick.name or "Trick") .. " +" .. value, x, y - 50, C.text_blue, 12, 1.1, "trick")
            for i = 1, 8 do
                local a = i / 8 * math_pi * 2
                particles:emit(x, y - 16, math_cos(a) * 90, math_sin(a) * 90, 0.4, 2.2, C.gold, "dot", 3, 0)
            end
        elseif kind == "flag" then
            particles:burst(x, y - 10, 5, 20, 70, 0.25, 0.45, 1.8, C.powder, "dot", 3, 100)
        elseif kind == "gate" then
            if value then
                self:_float("+1 gate", x, y - 36, C.text_green, 11, 0.9)
                particles:burst(x, y - 14, 8, 30, 90, 0.3, 0.6, 2, C.gold, "dot", 2, 60)
            else
                self:_float("Missed! +5 s", x, y - 36, C.text_red, 12, 1.2)
            end
        elseif kind == "slalom_start" then
            self:_banner("Slalom started - pass between the flags!", 2.5)
        elseif kind == "slalom_finish" then
            local _, result = game:slalom()
            if result then
                local msg = "Slalom time " .. game.format_time(result.total)
                if result.missed > 0 then msg = msg .. "  (" .. result.missed .. " missed)" end
                if result.record then
                    msg = msg .. "  New record!"
                    self:_confetti_burst(x, y - 40)
                end
                self:_banner(msg, 5)
            end
        elseif kind == "slalom_abort" then
            self:_banner("Slalom abandoned", 2.5)
        elseif kind == "woof" then
            self:_float("Woof!", x + 4, y - 26, C.text_orange, 11, 0.9)
        elseif kind == "boarder_fall" then
            particles:burst(x, y - 6, 12, 30, 120, 0.3, 0.7, 2, C.powder, "dot", 3, 120)
        elseif kind == "yeti" then
            self:_flash(0.8)
            shaker:add(0.55)
            particles:burst(x, y - 20, 26, 60, 220, 0.5, 1.1, 2.6, C.powder, "dot", 2, 150)
            self:_banner("The Abominable Snow Monster is after you!", 3.5)
        elseif kind == "caught" then
            self:_flash(1)
            shaker:add(0.9)
            particles:burst(x, y - 16, 30, 60, 240, 0.5, 1.2, 2.8, C.powder, "dot", 2, 150)
        elseif kind == "chomp" then
            shaker:add(0.35)
            for i = 1, 7 do
                local c = i % 2 == 0 and P.j or P.s
                particles:emit(x + (math_random() - 0.5) * 10, y - 46, (math_random() - 0.5) * 160, -40 - math_random() * 90,
                    0.6 + math_random() * 0.4, 2.2, c, "dot", 1, 300)
            end
            self:_float(value == 3 and "GULP!" or "CHOMP!", x, y - 80, C.text_red, 14, 0.8, "chomp")
        elseif kind == "over" then
            self:_banner("Eaten by the Yeti!", 30)
        elseif kind == "milestone" then
            if value % 500 == 0 then
                self:_float(value .. " m", x, y - 56, C.text_blue, 14, 1.6)
            end
        elseif kind == "turbo_on" then
            particles:burst(x, y - 4, 10, 40, 140, 0.3, 0.5, 2, C.gold, "dot", 3, 60)
        elseif kind == "record" then
            self:_float("New best distance!", x, y - 60, C.text_orange, 14, 2)
            self:_confetti_burst(x, y - 40)
        elseif kind == "getup" then
            particles:burst(x, y, 6, 20, 60, 0.3, 0.5, 2, C.powder, "dot", 3, 100)
        end
    end)
end

function SkiFreeView:_banner(msg, life)
    self._banner_msg = { text = msg, t = 0, life = life }
end

function SkiFreeView:_confetti_burst(x, y)
    local confetti = self._confetti
    for i = 1, 40 do
        if #confetti >= 80 then break end
        local a = math_random() * math_pi * 2
        local speed = 60 + math_random() * 160
        confetti[#confetti + 1] = {
            x = x, y = y, vx = math_cos(a) * speed, vy = math_sin(a) * speed - 120,
            angle = math_random() * 6.28, spin = (math_random() - 0.5) * 12, size = 2 + math_random() * 2.5,
            color = C.confetti[(i % 6) + 1], life = 1.6 + math_random() * 0.6,
        }
    end
end

function SkiFreeView:_update_effects(dt, client)
    local game = self._game
    local cam_x, cam_y = game:camera()
    local dcx, dcy = 0, 0
    if self._last_cam_x then
        dcx, dcy = cam_x - self._last_cam_x, cam_y - self._last_cam_y
        if math_abs(dcx) > 200 or math_abs(dcy) > 200 then dcx, dcy = 0, 0 end
    end
    self._last_cam_x, self._last_cam_y = cam_x, cam_y

    local frozen = game:is_paused() or game:shell():is_modal()
    local fall = frozen and 0 or dt
    local flakes = self._flakes
    for i = 1, #flakes do
        local f = flakes[i]
        f.y = f.y + (18 + 30 * f.depth) * fall - dcy * f.depth * 0.35
        f.x = f.x + math_sin(self._time * 0.8 + f.phase) * 8 * fall - dcx * f.depth * 0.35
        if f.y > client.h + 4 then f.y = f.y - client.h - 8 end
        if f.y < -4 then f.y = f.y + client.h + 8 end
        if f.x > client.w + 4 then f.x = f.x - client.w - 8 end
        if f.x < -4 then f.x = f.x + client.w + 8 end
    end

    local floats = self._floats
    for i = #floats, 1, -1 do
        local f = floats[i]
        f.t = f.t + dt
        if f.t >= f.life then table.remove(floats, i) end
    end

    local confetti = self._confetti
    for i = #confetti, 1, -1 do
        local c = confetti[i]
        c.life = c.life - dt
        if c.life <= 0 then
            table.remove(confetti, i)
        else
            c.vy = c.vy + 260 * dt
            c.vx = c.vx * (1 - dt * 1.5)
            c.x = c.x + c.vx * dt
            c.y = c.y + c.vy * dt
            c.angle = c.angle + c.spin * dt
        end
    end

    local streaks = self._streaks
    for i = #streaks, 1, -1 do
        local s = streaks[i]
        s.t = s.t + dt
        if s.t >= s.life then table.remove(streaks, i) end
    end
    local vmax = game:max_speed()
    local speed = game:speed()
    local state = game:state()
    if not frozen and (state == "ski" or state == "air") and speed > vmax * 0.9 then
        local k = math_min(1, (speed - vmax * 0.9) / (vmax * 0.6))
        if math_random() < k * 0.9 and #streaks < 18 then
            local edge = math_random() * 0.36
            streaks[#streaks + 1] = {
                x = client.w * (math_random() < 0.5 and edge or 1 - edge), y = client.h * (0.3 + math_random() * 0.8),
                len = 18 + math_random() * 40 * k, t = 0, life = 0.25 + math_random() * 0.25, k = k,
            }
        end
    end

    local banner = self._banner_msg
    if banner then
        banner.t = banner.t + dt
        if banner.t >= banner.life then self._banner_msg = nil end
    end
    if self._flash_t then
        self._flash_t = self._flash_t + dt
        if self._flash_t > 1.2 then self._flash_t = nil end
    end

    if not frozen then
        self:_update_tracks()
        self:_update_yeti_steps()
    end
end

-- Yeti footprints and the rumble of his steps.
function SkiFreeView:_update_yeti_steps()
    local game = self._game
    local yeti = game:yeti()
    if not yeti or game:state() == "eaten" or game:state() == "over" then
        self._yeti_last = nil
        return
    end
    local last = self._yeti_last
    if not last then
        self._yeti_last = { x = yeti.x, y = yeti.y }
        return
    end
    local dx, dy = yeti.x - last.x, yeti.y - last.y
    local d2 = dx * dx + dy * dy
    if d2 > 400 * 400 then
        last.x, last.y = yeti.x, yeti.y
    elseif d2 > 24 * 24 then
        last.x, last.y = yeti.x, yeti.y
        self._yeti_step = self._yeti_step + 1
        local side = self._yeti_step % 2 == 0 and -1 or 1
        local prints = self._prints
        if #prints >= 26 then table.remove(prints, 1) end
        prints[#prints + 1] = { x = yeti.x + side * 7, y = yeti.y, t = game:clock() }
        local x, y = game:position()
        local dist = math_sqrt((yeti.x - x) ^ 2 + (yeti.y - y) ^ 2)
        if dist < 320 then self._shaker:add(0.1 * (1 - dist / 320)) end
    end
end

-- Drawing helpers -------------------------------------------------------------------------------------

local function draw_spr(canvas, name, sx, sy, layer, flip, alpha, flip_y)
    local s = SPR[name]
    if not s then return end
    local ax = flip and (s.w - s.ax) or s.ax
    local ay = flip_y and (s.h - s.ay) or s.ay
    Win95.draw_sprite(canvas, s.sprite, math_floor(sx - ax * PX + 0.5), math_floor(sy - ay * PX + 0.5), PX, layer, nil, alpha, flip, flip_y)
end

local function shadow(canvas, cx, cy, w, layer, alpha)
    if w < 2 then return end
    local h = math_max(2, w * 0.22)
    canvas:rect(cx - w * 0.5, cy - h * 0.5, w, h, layer, C.shadow, alpha * 0.55)
    canvas:rect(cx - w * 0.36, cy - h * 0.8, w * 0.72, h * 1.6, layer, C.shadow, alpha * 0.45)
end

local function draw_icon(canvas, cx, cy, size, layer)
    local s = SPR.icon
    local px = size / 8
    Win95.draw_sprite(canvas, s.sprite, cx - 4 * px, cy - 4 * px, px, layer)
end

local DESKTOP_OPTS = { app = "SkiFree", icon = draw_icon, clock = "" }
local WINDOW_OPTS = { title = "SkiFree", icon = draw_icon }
local CRT_OPTS = {
    tint = Win95.C.hint, scan_alpha = 12, sweep_alpha = 10, vignette_depth = 60, vignette_alpha = 110,
    noise_count = 6, noise_alpha = 25, flicker = false,
}

local function hash2(a, b)
    local h = (a * 73856093 + b * 19349663 + 83492791) % 1000003
    return h
end

function SkiFreeView:_world_text(value, x, y, w, h, size, color, halign, z, alpha)
    local client = self._client
    if x < client.x or y < client.y or x + w > client.x + client.w or y + h > client.y + client.h then return end
    self._text:draw(value, x, y, w, h, size, color, halign, z, nil, alpha)
end

-- Snow ------------------------------------------------------------------------------------------------

function SkiFreeView:_draw_snow(canvas, client, cam_x, cam_y, t)
    canvas:vgradient(client.x, client.y, client.w, client.h, 3.4, C.snow_top, C.snow_bottom, 255, 255, 16)

    -- Wind-blown drifts: faint blue bands anchored to the slope.
    local dcell = 150
    local dx0, dy0 = math_floor(cam_x / dcell), math_floor(cam_y / dcell)
    for cy = dy0, dy0 + math_floor(client.h / dcell) + 1 do
        for cx = dx0 - 1, dx0 + math_floor(client.w / dcell) + 1 do
            local h = hash2(cx + 911, cy - 377)
            if h % 3 ~= 0 then
                local w = 70 + h % 90
                local sx = math_floor(client.x - cam_x + cx * dcell + (h % 61))
                local sy = math_floor(client.y - cam_y + cy * dcell + ((h / 61) % 97))
                canvas:rect(sx, sy, w, 3, 3.41, C.drift, 30)
                canvas:rect(sx + w * 0.15, sy + 3, w * 0.7, 2, 3.41, C.drift, 22)
                canvas:rect(sx + w * 0.1, sy - 2, w * 0.55, 2, 3.41, C.white, 70)
            end
        end
    end

    local cell = 44
    local cx0 = math_floor(cam_x / cell)
    local cy0 = math_floor(cam_y / cell)
    local cols = math_floor(client.w / cell) + 1
    local rows = math_floor(client.h / cell) + 1
    local ox = client.x - cam_x
    local oy = client.y - cam_y
    for cy = cy0, cy0 + rows do
        for cx = cx0, cx0 + cols do
            local h = hash2(cx, cy)
            local wx = cx * cell + (h % 41)
            local wy = cy * cell + ((h / 41) % 43)
            local sx, sy = math_floor(ox + wx), math_floor(oy + wy)
            local kind = h % 7
            if kind < 4 then
                canvas:rect(sx, sy, kind == 0 and 3 or 2, 1, 3.45, C.speck, 70 + (h % 5) * 12)
                if kind == 1 then canvas:rect(sx + 5, sy + 3, 2, 1, 3.45, C.speck, 60) end
            elseif kind == 4 then
                local tw = math_sin(t * 2.6 + (h % 628) * 0.01)
                if tw > 0.35 then
                    local a = (tw - 0.35) / 0.65
                    local c = h % 2 == 0 and C.sparkle or C.sparkle_blue
                    canvas:rect(sx, sy, 1, 1, 3.46, c, 255 * a)
                    if a > 0.6 then
                        canvas:rect(sx - 1, sy, 3, 1, 3.45, c, 150 * a)
                        canvas:rect(sx, sy - 1, 1, 3, 3.45, c, 150 * a)
                    end
                end
            end
        end
    end
end

function SkiFreeView:_draw_tracks(canvas, ox, oy, client)
    local tracks = self._tracks
    local count = self._track_count
    if count < 2 then return end
    local now = self._game:clock()
    local head = self._track_head
    local x0, y0, x1, y1 = client.x - 10, client.y - 10, client.x + client.w + 10, client.y + client.h + 10
    local prev = nil
    for i = count - 1, 0, -1 do
        local index = (head - 1 - i) % 180 + 1
        local p = tracks[index]
        if prev and not p.brk then
            local age = now - p.t
            local alpha = 120 * (1 - age / 14)
            if alpha > 4 then
                local ax, ay = ox + prev.x, oy + prev.y
                local bx, by = ox + p.x, oy + p.y
                if not ((ax < x0 and bx < x0) or (ax > x1 and bx > x1) or (ay < y0 and by < y0) or (ay > y1 and by > y1)) then
                    canvas:line(ax + prev.nx, ay + prev.ny, bx + p.nx, by + p.ny, 1.6, 3.5, C.track, alpha)
                    canvas:line(ax - prev.nx, ay - prev.ny, bx - p.nx, by - p.ny, 1.6, 3.5, C.track, alpha)
                end
            end
        end
        prev = p
    end
end

-- World ------------------------------------------------------------------------------------------------

local function sort_by_y(a, b)
    if a.y == b.y then return a.x < b.x end
    return a.y < b.y
end

function SkiFreeView:_skier_pose()
    local game = self._game
    local state = game:state()
    local dir = game:dir()
    if state == "crash" then
        local t, total, getup = game:crash_phase()
        return t >= total - getup and "sit" or "fallen", dir > 0, false
    end
    if state == "air" then
        local trick, progress = game:trick()
        if trick == 1 then return "spread", false, false end
        if trick == 2 then return "daffy", dir > 0, false end
        if trick == 3 then
            local f = math_floor(progress * 8) % 4 + 1
            return HELI_FRAMES[f], HELI_FLIP[f], false
        end
        if trick == 4 then
            local f = math_floor(progress * 4) % 4
            if f == 0 then return "air", false, false end
            if f == 1 then return "flip90", dir > 0, false end
            if f == 2 then return "air", false, true end
            return "flip90", dir <= 0, true
        end
        if dir == 0 then return "air", false, false end
    end
    if state == "ski" and game:walking() and math_abs(dir) == 3 then
        return (math_floor(game:walk_phase() * 2) % 2 == 0) and "walk1" or "walk2", dir > 0, false
    end
    return SKIER_FRAMES[math_abs(dir)], dir > 0, false
end

function SkiFreeView:_yeti_pose()
    local game = self._game
    local yeti = game:yeti()
    local state = game:state()
    if state == "eaten" or state == "over" then
        local t = game:eat_time()
        if t < 0.5 then return "yeti_grab", false, 0 end
        if t < 0.85 then return "yeti_open", false, 0 end
        if t < 1.1 then return "yeti_chomp1", false, math_abs(math_sin(t * 40)) * 2 end
        if t < 1.35 then return "yeti_open", false, 0 end
        if t < 1.85 then return "yeti_chomp2", false, math_abs(math_sin(t * 40)) * 2 end
        if t < 2.3 then return "yeti_gulp", false, 0 end
        local phase = (t - 2.3) / 0.26
        local k = math_floor(phase) % 2
        local hop = k == 0 and math_sin((phase % 1) * math_pi) * 10 or 0
        return k == 0 and "yeti_dance1" or "yeti_dance2", math_floor(phase / 2) % 2 == 1, hop
    end
    local frame = math_floor(yeti.phase * 1.2) % 2 == 0 and "yeti_run1" or "yeti_run2"
    return frame, yeti.face > 0, math_abs(math_sin(yeti.phase * 1.2 * math_pi)) * 3
end

function SkiFreeView:_draw_object(canvas, o, sx, sy, clock)
    local kind = o.kind
    if o.hit_at and kind ~= "flag" then
        local k = clock - o.hit_at
        if k < 0.7 then sx = sx + math_floor(math_sin(k * 34) * (0.7 - k) * 5 + 0.5) end
    end
    if kind == "flag" then
        local wob = 0
        if o.hit_at then
            local k = clock - o.hit_at
            if k < 1.2 then wob = math_sin(k * 22) * (1.2 - k) * 4 end
        end
        shadow(canvas, sx + 2, sy, 8, 3.6, 70)
        draw_spr(canvas, o.color == "red" and "flag_red" or "flag_blue", sx + wob, sy, 4, o.side > 0)
    elseif kind == "dog" then
        shadow(canvas, sx, sy, SHADOW_W.dog, 3.6, 80)
        local frame
        if o.sit and o.sit > 0 then
            frame = "dog_sit"
        else
            frame = math_floor(o.phase * (o.flee and 14 or 8)) % 2 == 0 and "dog1" or "dog2"
        end
        draw_spr(canvas, frame, sx, sy, 4, o.vx > 0)
    elseif kind == "boarder" then
        shadow(canvas, sx, sy, SHADOW_W.boarder, 3.6, 80)
        if o.fallen then
            draw_spr(canvas, "boarder_fallen", sx, sy, 4, false)
        elseif math_abs(o.lean) > 0.25 then
            draw_spr(canvas, "boarder_turn", sx, sy, 4, o.lean > 0)
        else
            draw_spr(canvas, "boarder", sx, sy, 4, false)
        end
    else
        local name = TYPE_SPRITE[kind]
        if not name then return end
        local sw = SHADOW_W[kind]
        if sw then shadow(canvas, sx + 3, sy, sw, 3.6, 85) end
        draw_spr(canvas, name, sx, sy, FLAT[kind] and 3.8 or 4, o.var == 1 and not FLAT[kind] and kind ~= "sign" and kind ~= "lift_pole")
        if kind == "sign" and o.text then
            local label = o.arrow and o.arrow < 0 and ("< " .. o.text) or (o.text .. " >")
            self:_world_text(label, sx - 27, sy - 26 + 1, 54, 14, 10, C.text_shadow, "center", 4)
        end
    end
end

function SkiFreeView:_skier_shadow(canvas, sx, sy, z)
    local k = math_min(z, 110) / 110
    shadow(canvas, sx, sy + 1, 20 - 9 * k, 3.6, 120 - 50 * k)
end

function SkiFreeView:_draw_skier(canvas, sx, sy, layer)
    local game = self._game
    local _, _, z = game:position()
    local name, flip, flip_y = self:_skier_pose()
    local lift = math_floor(z + 0.5)
    if game:turbo() and game:state() == "ski" and game:speed() > 200 then
        local angle = game:direction_angle()
        local dx, dy = math_sin(angle), math_cos(angle)
        draw_spr(canvas, name, sx - dx * 10, sy - dy * 10 - lift, layer, flip, 60, flip_y)
        draw_spr(canvas, name, sx - dx * 5, sy - dy * 5 - lift, layer, flip, 110, flip_y)
    end
    local blink = 255
    if game:state() == "crash" then
        local t = game:crash_phase()
        if t < 0.15 then blink = 180 end
    end
    draw_spr(canvas, name, sx, sy - lift, layer, flip, blink < 255 and blink or nil, flip_y)
end

function SkiFreeView:_draw_world(canvas, client, t)
    local game = self._game
    local cam_x, cam_y = game:camera()
    local icx, icy = math_floor(cam_x + 0.5), math_floor(cam_y + 0.5)
    local ox, oy = client.x - icx, client.y - icy
    local clock = game:clock()

    self:_draw_snow(canvas, client, cam_x, cam_y, t)

    local decals = self._decals
    for i = 1, #decals do
        local d = decals[i]
        local age = clock - d.t
        local a = math_max(0, 1 - age / 20)
        if a > 0 then
            local dx, dy = ox + d.x, oy + d.y
            canvas:rect(dx - 10, dy - 3, 20, 6, 3.5, C.crater, 150 * a)
            canvas:rect(dx - 6, dy - 5, 12, 10, 3.5, C.crater, 110 * a)
            canvas:rect(dx - 7, dy - 1, 4, 2, 3.5, C.track, 90 * a)
            canvas:rect(dx + 3, dy, 5, 2, 3.5, C.track, 90 * a)
        end
    end
    self:_draw_tracks(canvas, ox, oy, client)
    local prints = self._prints
    for i = 1, #prints do
        local p = prints[i]
        local a = math_max(0, 1 - (clock - p.t) / 12)
        if a > 0 then
            local px, py = ox + p.x, oy + p.y
            canvas:rect(px - 4, py - 2, 8, 4, 3.5, C.crater, 200 * a)
            canvas:rect(px - 3, py - 3, 6, 6, 3.5, C.track, 70 * a)
            canvas:rect(px - 4, py - 5, 2, 2, 3.5, C.track, 90 * a)
            canvas:rect(px + 2, py - 5, 2, 2, 3.5, C.track, 90 * a)
        end
    end

    local list = self._draw_list
    local n = game:collect_visible(list)

    local gx, gy, z = game:position()
    local sx_skier, sy_skier = ox + gx, oy + gy
    local state = game:state()
    local skier_visible = state ~= "eaten" and state ~= "over"
    local high = z > 14
    if skier_visible and not high then
        local e = self._skier_entry
        e.x, e.y = gx, gy + (state == "crash" and 16 or 0.5)
        n = n + 1
        list[n] = e
    end
    local yeti = game:yeti()
    if yeti then
        local e = self._yeti_entry
        e.x, e.y = yeti.x, yeti.y
        n = n + 1
        list[n] = e
    end
    for i = n + 1, #list do list[i] = nil end
    table.sort(list, sort_by_y)

    for i = 1, n do
        local o = list[i]
        local sx, sy = ox + math_floor(o.x + 0.5), oy + math_floor(o.y + 0.5)
        if o == self._skier_entry then
            self:_skier_shadow(canvas, sx_skier, sy_skier, z)
            self:_draw_skier(canvas, sx_skier, sy_skier, 4)
        elseif o == self._yeti_entry then
            local name, flip, hop = self:_yeti_pose()
            shadow(canvas, sx, sy, 34 - hop, 3.6, 100)
            draw_spr(canvas, name, sx, sy - hop, 4, flip)
        else
            self:_draw_object(canvas, o, sx, sy, clock)
        end
    end

    if skier_visible and high then
        self:_skier_shadow(canvas, sx_skier, sy_skier, z)
        self:_draw_skier(canvas, sx_skier, sy_skier, 4.2)
    end

    self:_draw_lifts(canvas, client, ox, oy, cam_x, cam_y, clock)
    self:_draw_banners(canvas, client, ox, oy)

    -- Particles live in world space; the canvas offset carries them with the slope.
    local sh = self._shaker
    canvas:set_shake(sh.x + ox, sh.y + oy)
    self._particles:draw(canvas, 4.5)
    local confetti = self._confetti
    for i = 1, #confetti do
        local c = confetti[i]
        local w = c.size * math_abs(math_cos(c.angle))
        canvas:rect(c.x - w * 0.5, c.y - c.size * 0.3, math_max(0.8, w), c.size * 0.6, 4.55, c.color, 255 * math_min(1, c.life * 2))
    end
    canvas:set_shake(sh.x, sh.y)

    self:_draw_streaks(canvas, client)
    self:_draw_flakes(canvas, client)
end

function SkiFreeView:_draw_lifts(canvas, client, ox, oy, cam_x, cam_y, clock)
    local game = self._game
    local lx = game:lift_near(cam_x + client.w * 0.5)
    local sx = ox + lx
    if sx < client.x - 60 or sx > client.x + client.w + 60 then return end

    local top = client.y
    for side = -1, 1, 2 do
        local cx = sx + side * 24 - 1
        canvas:rect(cx, top, 2, client.h, 4.3, C.cable)
        canvas:rect(cx + (side < 0 and 0 or 1), top, 1, client.h, 4.3, C.cable_light, 120)
    end

    local spacing = 150
    local speed = 55
    local wy0, wy1 = cam_y - 60, cam_y + client.h + 80
    for side = -1, 1, 2 do
        local phase = (clock * speed * side) % spacing
        local k0 = math_floor((wy0 - phase) / spacing)
        local k1 = math_floor((wy1 - phase) / spacing)
        for k = k0, k1 do
            local wy = k * spacing + phase
            local gy = oy + wy
            local cx = sx + side * 24
            local rider = hash2(k, side + 5) % 3 == 0
            shadow(canvas, cx + 10, gy, 14, 3.6, 45)
            draw_spr(canvas, rider and "chair_rider" or "chair", cx, gy - 58, 4.3, side > 0)
        end
    end
end

function SkiFreeView:_draw_banners(canvas, client, ox, oy)
    local banners = self._game:banners()
    for i = 1, #banners do
        local b = banners[i]
        local sx, sy = ox + b.x, oy + b.y
        local x0, y0 = sx - b.w * 0.5, sy - 40
        if x0 + b.w > client.x and x0 < client.x + client.w and y0 + 16 > client.y and y0 < client.y + client.h then
            if b.style == "finish" then
                local cell = 6
                for cx = 0, math_floor(b.w / cell) - 1 do
                    for cy = 0, 2 do
                        local dark = (cx + cy) % 2 == 0
                        canvas:rect(x0 + cx * cell, y0 + cy * cell, cell, cell, 4.3, dark and C.black or C.white)
                    end
                end
                canvas:rect(x0 + b.w * 0.5 - 30, y0 + 2, 60, 14, 4.31, C.white)
                self:_world_text(b.text, x0, y0 + 2, b.w, 14, 12, C.text_black, "center", 4.31)
            else
                local cols = C.banner[b.style] or C.banner.start
                canvas:rect(x0 + 2, y0 + 3, b.w, 16, 4.3, C.black, 50)
                canvas:vgradient(x0, y0, b.w, 16, 4.3, cols[1], cols[2], 255, 255, 3)
                canvas:rect(x0, y0, b.w, 1, 4.31, C.white, 90)
                self:_world_text(b.text, x0, y0 + 1, b.w, 14, 12, C.text_white, "center", 4.31)
            end
        end
    end
end

function SkiFreeView:_draw_streaks(canvas, client)
    local game = self._game
    local angle = game:direction_angle()
    local dx, dy = math_sin(angle), math_cos(angle)
    local streaks = self._streaks
    for i = 1, #streaks do
        local s = streaks[i]
        local k = s.t / s.life
        local x = client.x + s.x - dx * k * 40
        local y = client.y + s.y - dy * k * 90
        local a = math_sin(k * math_pi) * 110 * s.k
        canvas:line(x, y, x - dx * s.len, y - dy * s.len, 1.4, 4.9, C.streak, a)
    end
end

function SkiFreeView:_draw_flakes(canvas, client)
    local flakes = self._flakes
    for i = 1, #flakes do
        local f = flakes[i]
        local x, y = client.x + math_floor(f.x), client.y + math_floor(f.y)
        local size = f.depth > 0.75 and 3 or 2
        canvas:rect(x + 1, y + 1, size, size, 5, C.flake_edge, 70 + f.depth * 90)
        canvas:rect(x, y, size, size, 5, C.flake, 170 + f.depth * 85)
    end
end

-- HUD -------------------------------------------------------------------------------------------

function SkiFreeView:_draw_stats(canvas, client)
    local game = self._game
    local text = self._text
    local w, h = 136, 74
    local x, y = client.x + client.w - w - 8, client.y + 8
    canvas:rect(x + 3, y + 3, w, h, 6, C.black, 45)
    canvas:vgradient(x, y, w, h, 6, C.stats_bg, C.stats_bg2, 245, 245, 4)
    canvas:rect(x, y, w, 1, 6.01, C.black)
    canvas:rect(x, y + h - 1, w, 1, 6.01, C.black)
    canvas:rect(x, y, 1, h, 6.01, C.black)
    canvas:rect(x + w - 1, y, 1, h, 6.01, C.black)

    for i = 1, 4 do
        local ly = y + 4 + (i - 1) * 16.5
        local value, color = nil, C.text_black
        if i == 1 then
            value = game.format_time(game:elapsed())
        elseif i == 2 then
            value = math_floor(game:distance()) .. "m"
        elseif i == 3 then
            value = math_floor(game:speed_ms() + 0.5) .. "m/s"
            if game:turbo() then color = C.text_orange end
        else
            value = tostring(game:style())
        end
        text:draw(STAT_LABELS[i], x + 8, ly, 60, 16, 12, C.text_black, "left", 6.05)
        text:draw(value, x + 50, ly, w - 58, 16, 12, color, "right", 6.05)
    end

    local pending = game:pending_style()
    if game:state() == "air" and pending > 0 then
        text:draw("+" .. pending, x, y + h + 2, w - 8, 16, 12, C.text_green, "right", 6.05)
    end
end

function SkiFreeView:_draw_slalom_hud(canvas, client)
    local game = self._game
    local s, result = game:slalom()
    local text = self._text
    if not s.active then return end
    local _, gates = game:slalom_gates()
    local x, y, w, h = client.x + 8, client.y + 8, 170, 40
    canvas:rect(x + 3, y + 3, w, h, 6, C.black, 45)
    canvas:vgradient(x, y, w, h, 6, C.stats_bg, C.stats_bg2, 235, 235, 3)
    Win95.bevel(canvas, x, y, w, h, 1, 6.01, false, true)
    text:draw("Slalom  " .. game.format_time(s.time), x + 8, y + 3, w - 16, 16, 12, C.text_blue, "left", 6.05)
    local miss = s.missed > 0 and ("  Missed " .. s.missed) or ""
    text:draw("Gate " .. math_min(gates, s.next_gate) .. "/" .. gates .. miss, x + 8, y + 20, w - 16, 16, 11, s.missed > 0 and C.text_red or C.text_black, "left", 6.05)
end

function SkiFreeView:_draw_floats(client, ox, oy)
    local floats = self._floats
    for i = 1, #floats do
        local f = floats[i]
        local k = f.t / f.life
        local a = 255 * math_min(1, (1 - k) * 3)
        local x = ox + f.x - 60
        local y = oy + f.y - k * 26
        self:_world_text(f.text, x + 1, y + 1, 120, 18, f.size, C.white, "center", 6.3, a * 0.9)
        self:_world_text(f.text, x, y, 120, 18, f.size, f.color, "center", 6.3, a)
    end
end

function SkiFreeView:_draw_overlays(canvas, client, t)
    local game = self._game
    local text = self._text

    if self._flash_t then
        local k = self._flash_t / 1.2
        local a = (1 - k) * (1 - k) * 150 * self._flash_power
        canvas:rect(client.x, client.y, client.w, client.h, 5.5, C.red, a * 0.45)
        canvas:vignette(client.x, client.y, client.w, client.h, 70, 5.51, a * 1.4, 6, C.red)
    end

    -- Off-screen Yeti warning arrow and a heartbeat vignette as he closes in.
    local yeti = game:yeti()
    local state = game:state()
    if yeti and state ~= "eaten" and state ~= "over" then
        local gx, gy = game:position()
        local near = 1 - math_min(1, math_sqrt((yeti.x - gx) ^ 2 + (yeti.y - gy) ^ 2) / 360)
        if near > 0 then
            local beat = math_max(0, math_sin(t * (6 + near * 6)))
            canvas:vignette(client.x, client.y, client.w, client.h, 60, 5.52, near * (60 + beat * 90), 6, C.red)
        end
        local cam_x, cam_y = game:camera()
        local yx, yy = client.x + yeti.x - cam_x, client.y + yeti.y - cam_y - 30
        local inside = yx > client.x and yx < client.x + client.w and yy > client.y and yy < client.y + client.h
        if not inside then
            local sx, sy = game:skier_screen()
            local dx, dy = yx - sx, yy - (sy - 16)
            local len = math_sqrt(dx * dx + dy * dy)
            if len > 1 then
                dx, dy = dx / len, dy / len
                local ex = math_max(client.x + 18, math_min(client.x + client.w - 18, sx + dx * 400))
                local ey = math_max(client.y + 18, math_min(client.y + client.h - 18, sy - 16 + dy * 400))
                local pulse = 0.6 + 0.4 * math_sin(t * 10)
                local px, py = -dy, dx
                canvas:glow(ex, ey, 22, 6.12, C.red, 70 * pulse, 4)
                canvas:tri(ex + dx * 12, ey + dy * 12, ex - dx * 6 + px * 9, ey - dy * 6 + py * 9, ex - dx * 6 - px * 9, ey - dy * 6 - py * 9, 6.2, C.red, 230 * pulse + 25)
                self:_world_text("!", ex - 10 - dx * 16, ey - 9 - dy * 16, 20, 18, 16, C.text_red, "center", 6.2)
            end
        end
    end

    local banner = self._banner_msg
    if banner then
        local k = banner.t
        local a = 255 * math_min(1, k * 4, (banner.life - k) * 2)
        local w = math_min(client.w - 40, Win95.text_width(banner.text, 13) + 40)
        local x = math_floor(client.x + (client.w - w) * 0.5)
        local y = client.y + client.h - 44
        canvas:rect(x + 3, y + 3, w, 24, 6.1, C.black, 40 * a / 255)
        canvas:rect(x, y, w, 24, 6.1, C.tooltip, a)
        canvas:rect(x, y, w, 1, 6.11, C.black, a)
        canvas:rect(x, y + 23, w, 1, 6.11, C.black, a)
        canvas:rect(x, y, 1, 24, 6.11, C.black, a)
        canvas:rect(x + w - 1, y, 1, 24, 6.11, C.black, a)
        text:draw(banner.text, x, y, w, 24, 13, C.text_black, "center", 6.15, nil, a)
    end

    if not game:started() and state == "ski" and not game:is_paused() then
        local w, h = 330, 42
        local x = math_floor(client.x + (client.w - w) * 0.5)
        local y = client.y + client.h - 96
        local bob = math_floor(math_sin(t * 3) * 2)
        canvas:rect(x + 3, y + 3 + bob, w, h, 6.1, C.black, 40)
        canvas:rect(x, y + bob, w, h, 6.1, C.tooltip)
        Win95.bevel(canvas, x, y + bob, w, h, 1, 6.11, false, true)
        text:draw("Press Down (S) or move the mouse to ski.", x, y + 3 + bob, w, 18, 12, C.text_black, "center", 6.15)
        text:draw("Beware of the Yeti after 2000 m!", x, y + 21 + bob, w, 18, 11, C.text_red, "center", 6.15)
    end

    if game:is_paused() then
        canvas:rect(client.x, client.y, client.w, client.h, 6.5, C.white, 120)
        local w, h = 220, 64
        local x = math_floor(client.x + (client.w - w) * 0.5)
        local y = math_floor(client.y + (client.h - h) * 0.5)
        Win95.panel(canvas, x, y, w, h, 6.6, false)
        text:draw("Paused", x, y + 8, w, 24, 16, C.text_black, "center", 6.7)
        text:draw("Press any key to continue", x, y + 34, w, 20, 12, C.text_black, "center", 6.7)
    end

    if state == "over" and not game:shell():dialog() then
        local w, h = 300, 26
        local x = math_floor(client.x + (client.w - w) * 0.5)
        local y = client.y + 60
        canvas:rect(x, y, w, h, 6.1, C.tooltip)
        Win95.bevel(canvas, x, y, w, h, 1, 6.11, false, true)
        text:draw("Press R, Space or click for a new game", x, y, w, h, 12, C.text_black, "center", 6.15)
    end
end

-- Dialog content -------------------------------------------------------------------------------------

function SkiFreeView:_dialog_content(canvas, D, dialog, text, t)
    local box = D.box
    local game = self._game
    local x, y = box.x + 16, box.y + 34
    if dialog.kind == "how_to" then
        for i = 1, #HOW_TO do
            text:draw(HOW_TO[i], x, y + (i - 1) * 17.5, box.w - 32, 18, 12, C.text_black, "left", 10.5)
        end
    elseif dialog.kind == "about" then
        local s = SPR.ski_steep
        Win95.draw_sprite(canvas, s.sprite, x, y + 4, 2, 9.3)
        text:draw("SkiFree", x + 50, y, 240, 24, 16, C.text_black, "left", 10.5)
        text:draw("Mourningstar Waiting Games edition", x + 50, y + 26, 260, 18, 12, C.text_black, "left", 10.5)
        text:draw("A tribute to Chris Pirih's 1991 classic.", x + 50, y + 46, 260, 18, 12, C.text_black, "left", 10.5)
        text:draw("Best distance: " .. game:best() .. " m", x + 50, y + 70, 260, 18, 12, C.text_black, "left", 10.5)
        local slalom = game:slalom_best()
        if slalom then
            text:draw("Best slalom: " .. game.format_time(slalom), x + 50, y + 88, 260, 18, 12, C.text_black, "left", 10.5)
        end
    elseif dialog.kind == "over" then
        local s = SPR.yeti_gulp
        Win95.draw_sprite(canvas, s.sprite, x - 10, y - 14, 2, 9.3)
        local tx = x + 52
        text:draw("You were eaten by the Yeti!", tx, y, 250, 20, 13, C.text_black, "left", 10.5)
        text:draw("Distance: " .. math_floor(game:max_distance()) .. " m    Style: " .. game:style(), tx, y + 24, 250, 18, 12, C.text_black, "left", 10.5)
        text:draw("Time: " .. game.format_time(game:elapsed()) .. "    Best: " .. game:best() .. " m", tx, y + 44, 250, 18, 12, C.text_black, "left", 10.5)
        if game:new_best() then
            text:draw("New best distance!", tx, y + 64, 250, 18, 12, C.text_red, "left", 10.5)
        end
    end
end

-- Main draw -------------------------------------------------------------------------------------------

function SkiFreeView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local game = self._game
    local text = self._text
    text:reset()

    if not game then
        SkiFreeView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
        return
    end

    dt = math_min(dt or 0.016, 0.05)
    self._time = self._time + dt

    local base = self:_scenegraph_world_position("scanner_base")
    self:_process_pointer(input_service, ui_renderer, base)
    self:_handle_events()

    local L = game:layout()
    local client = L.client
    self._client = client
    local frozen = game:is_paused() or game:shell():is_modal()
    if not frozen or game:state() == "over" or game:state() == "eaten" then
        self._particles:update(dt)
    end
    self._shaker:update(dt, 5)
    self:_update_effects(dt, client)

    local canvas = self._canvas
    if canvas:begin(ui_renderer, base) then
        local time = self._time
        local seconds = math_floor(game:elapsed())
        local blink = math_floor(time * 2) % 2 == 0 and ":" or " "
        DESKTOP_OPTS.clock = string.format("%02d%s%02d", math_floor(seconds / 60) % 100, blink, seconds % 60)
        Win95.draw_desktop(canvas, text, time, DESKTOP_OPTS)
        Win95.draw_window(canvas, text, game:shell(), time, WINDOW_OPTS)

        local sh = self._shaker
        canvas:set_clip(client.x, client.y, client.x + client.w, client.y + client.h)
        canvas:set_shake(sh.x, sh.y)
        text:set_offset(sh.x, sh.y)
        self:_draw_world(canvas, client, time)
        local cam_x, cam_y = game:camera()
        self:_draw_floats(client, client.x - math_floor(cam_x + 0.5), client.y - math_floor(cam_y + 0.5))
        canvas:set_shake(0, 0)
        text:set_offset(0, 0)
        self:_draw_overlays(canvas, client, time)
        self:_draw_stats(canvas, client)
        self:_draw_slalom_hud(canvas, client)
        canvas:reset_clip()

        Win95.draw_menu(canvas, text, game:shell())
        Win95.draw_dialog(canvas, text, game:shell(), time, self._dialog_cb)
        Win95.draw_hint(canvas, text, HINT)

        canvas:crt(0, 0, RENDER_SIZE, RENDER_SIZE, time, 11.5, CRT_OPTS)
        canvas:finish()
    end

    SkiFreeView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

function SkiFreeView:destroy()
    self._canvas = nil
    self._particles = nil
    SkiFreeView.super.destroy(self)
end

return SkiFreeView
