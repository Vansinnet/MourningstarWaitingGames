-- Battle Chess rules engine and time-sliced computer player.
-- Pure Lua 5.1 / LuaJIT: no bit library, no goto, no os/io, no engine globals. Loadable with dofile.
-- Written from scratch for this mod (MIT). Uses only textbook ideas: 10x12 mailbox board, additive
-- Zobrist-style hashing, piece-square tables (Michniewski's "Simplified Evaluation Function" values),
-- alpha-beta/PVS with iterative deepening, quiescence with MVV-LVA, killers/history, null move, LMR and a
-- transposition table.
--
-- Public squares are 0..63 (sq = rank * 8 + file, a1 = 0, h8 = 63). Pieces are "PNBRQK" / "pnbrqk".
-- See the API summary at the bottom of this file.
local Engine = {}

local math_floor = math.floor
local math_abs = math.abs
local math_min = math.min
local math_random = math.random
local co_create = coroutine.create
local co_resume = coroutine.resume
local co_yield = coroutine.yield
local co_status = coroutine.status
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local type = type
local string_sub = string.sub
local string_byte = string.byte
local table_concat = table.concat

Engine.START_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

---------------------------------------------------------------------------------------------------
-- LuaJIT notes (see Engine.set_jit_mode at the end of the file).
-- A recursive alpha-beta search makes LuaJIT's trace tree explode: every branch in the inlined
-- make/unmake/gen code forks a new side trace in every caller trace. That fills the machine-code area
-- shared with the whole game and forces whole-VM trace flushes, which would slow down the game too.
-- Default ("leaf" mode, when the jit library is visible): the recursive search runs interpreted while the
-- hot leaf functions (move generation, make/unmake, attack tests, evaluation) are compiled, each into
-- a small, stable set of traces. If the jit library is not visible, "full" mode is used instead: a
-- call to a builtin the recorder does not compile (coroutine.running) at the top of the hot functions
-- makes LuaJIT end the trace there and stitch a new one, which bounds the trace tree the same way.
local JIT = nil
do
    -- read the global through pcall: some mod environments raise errors for unknown globals
    local ok, j = pcall(function() return jit end)
    if ok and type(j) == "table" and type(j.off) == "function" and type(j.on) == "function" then JIT = j end
end
if JIT then JIT.off(true) end -- this main chunk (one-off table set-up) needs no compiled traces
local STITCH_ON = coroutine.running
local STITCH_OFF = function() end
local STITCH = STITCH_ON

---------------------------------------------------------------------------------------------------
-- Board geometry (10x12 mailbox). Internal index i = 21 + rank * 10 + file.
---------------------------------------------------------------------------------------------------
local OFF = 7
local HM = 2147483648 -- hashes are kept modulo 2^31

local SQ120, SQ64, FILE120, RANK120 = {}, {}, {}, {}
for i = 0, 119 do
    SQ64[i] = -1
    FILE120[i] = -1
    RANK120[i] = -1
end
for r = 0, 7 do
    for f = 0, 7 do
        local s = r * 8 + f
        local i = 21 + r * 10 + f
        SQ120[s] = i
        SQ64[i] = s
        FILE120[i] = f
        RANK120[i] = r
    end
end

-- Internal pieces: white 1..6 (P N B R Q K), black -1..-6, empty 0, off-board 7.
-- Arrays indexed by piece use p + 7 (1..13).
local PCHAR = {}
local PIECE_OF = {}
do
    local chars = "kqrbnp.PNBRQK"
    for p = -6, 6 do
        if p ~= 0 then
            local c = string_sub(chars, p + 7, p + 7)
            PCHAR[p + 7] = c
            PIECE_OF[c] = p
        end
    end
end
local PROMO_OF = { q = 5, r = 4, b = 3, n = 2, Q = 5, R = 4, B = 3, N = 2 }
local FILE_CHARS = "abcdefgh"

local KN_OFF = { -21, -19, -12, -8, 8, 12, 19, 21 }
local K_OFF = { -11, -10, -9, -1, 1, 9, 10, 11 }
local B_DIR = { -11, -9, 9, 11 }
local R_DIR = { -10, -1, 1, 10 }

-- Move codes: from + to * 128 + promo * 16384 + flag * 131072
-- promo = piece type 2..5 (or 0); flag 0 normal, 1 en passant, 2 double push, 3 castle.
local FT = 128
local PR = 16384
local FL = 131072

-- Castling rights: WK = 1, WQ = 2, BK = 4, BQ = 8. AND16[a * 16 + b] = a AND b (no bit ops).
local AND16 = {}
for a = 0, 15 do
    for c = 0, 15 do
        local r, bitv, x, y = 0, 1, a, c
        for _ = 1, 4 do
            if x % 2 == 1 and y % 2 == 1 then r = r + bitv end
            x = math_floor(x / 2)
            y = math_floor(y / 2)
            bitv = bitv * 2
        end
        AND16[a * 16 + c] = r
    end
end
local CMASK = {}
for i = 0, 119 do CMASK[i] = 15 end
CMASK[21] = 13 -- a1: lose WQ
CMASK[28] = 14 -- h1: lose WK
CMASK[25] = 12 -- e1: lose both white
CMASK[91] = 7 -- a8: lose BQ
CMASK[98] = 11 -- h8: lose BK
CMASK[95] = 3 -- e8: lose both black

---------------------------------------------------------------------------------------------------
-- Hash keys. Two independent 31-bit parts, combined additively modulo 2^31 (no XOR needed).
---------------------------------------------------------------------------------------------------
local zstate = 20260930
local function zrand()
    zstate = (zstate * 16807) % 2147483647
    return zstate
end
local Z1, Z2 = {}, {}
for p = 1, 13 do
    for i = 0, 119 do
        local k = p * 128 + i
        Z1[k] = zrand()
        Z2[k] = zrand()
    end
end
local ZS1, ZS2 = zrand(), zrand()
local ZC1, ZC2 = { [0] = 0 }, { [0] = 0 }
for c = 1, 15 do
    ZC1[c] = zrand()
    ZC2[c] = zrand()
end
local ZE1, ZE2 = {}, {}
for f = 0, 7 do
    ZE1[f] = zrand()
    ZE2[f] = zrand()
end

---------------------------------------------------------------------------------------------------
-- Evaluation tables. Piece-square values from the Chess Programming Wiki "Simplified Evaluation
-- Function" (listed from rank 8 down to rank 1, white's point of view).
---------------------------------------------------------------------------------------------------
local MAT_MG = { 100, 320, 330, 500, 900, 0 }
local MAT_EG = { 115, 305, 330, 520, 930, 0 }

local PST_PAWN = {
    0, 0, 0, 0, 0, 0, 0, 0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
}
local PST_PAWN_EG = {
    0, 0, 0, 0, 0, 0, 0, 0,
    60, 60, 60, 60, 60, 60, 60, 60,
    35, 35, 35, 35, 35, 35, 35, 35,
    20, 20, 20, 20, 20, 20, 20, 20,
    10, 10, 10, 10, 10, 10, 10, 10,
    5, 5, 5, 5, 5, 5, 5, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
}
local PST_KNIGHT = {
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
}
local PST_BISHOP = {
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
}
local PST_ROOK = {
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, 10, 10, 10, 10, 5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    0, 0, 0, 5, 5, 0, 0, 0,
}
local PST_QUEEN = {
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -5, 0, 5, 5, 5, 5, 0, -5,
    0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
}
local PST_KING_MG = {
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    20, 20, 0, 0, 0, 0, 20, 20,
    20, 30, 10, 0, 0, 10, 30, 20,
}
local PST_KING_EG = {
    -50, -40, -30, -20, -20, -30, -40, -50,
    -30, -20, -10, 0, 0, -10, -20, -30,
    -30, -10, 20, 30, 30, 20, -10, -30,
    -30, -10, 30, 40, 40, 30, -10, -30,
    -30, -10, 30, 40, 40, 30, -10, -30,
    -30, -10, 20, 30, 30, 20, -10, -30,
    -30, -30, 0, 0, 0, 0, -30, -30,
    -50, -30, -30, -30, -30, -30, -30, -50,
}
local TABLES_MG = { PST_PAWN, PST_KNIGHT, PST_BISHOP, PST_ROOK, PST_QUEEN, PST_KING_MG }
local TABLES_EG = { PST_PAWN_EG, PST_KNIGHT, PST_BISHOP, PST_ROOK, PST_QUEEN, PST_KING_EG }

-- PMG/PEG[(p + 7) * 128 + i]: signed material + placement (white positive).
local PMG, PEG = {}, {}
for t = 1, 6 do
    for s = 0, 63 do
        local i = SQ120[s]
        local f, r = s % 8, math_floor(s / 8)
        local wi = (7 - r) * 8 + f + 1
        local bi = r * 8 + f + 1
        PMG[(t + 7) * 128 + i] = MAT_MG[t] + TABLES_MG[t][wi]
        PEG[(t + 7) * 128 + i] = MAT_EG[t] + TABLES_EG[t][wi]
        PMG[(-t + 7) * 128 + i] = -(MAT_MG[t] + TABLES_MG[t][bi])
        PEG[(-t + 7) * 128 + i] = -(MAT_EG[t] + TABLES_EG[t][bi])
    end
end

local PHASE = {} -- by p + 7
local VALUE = {} -- simple piece values by p + 7 (absolute)
local ATYPE = {} -- piece type 1..6 by p + 7
for p = -6, 6 do
    local t = math_abs(p)
    PHASE[p + 7] = (t == 2 or t == 3) and 1 or (t == 4 and 2 or (t == 5 and 4 or 0))
    VALUE[p + 7] = ({ [0] = 0, 100, 320, 330, 500, 900, 0 })[t]
    ATYPE[p + 7] = t
end
VALUE[OFF + 7] = 0
local PROMO_GAIN = { [0] = 0, 0, 220, 230, 400, 800 }

local CMD = {} -- centre manhattan distance
for i = 0, 119 do CMD[i] = 0 end
for s = 0, 63 do
    local f, r = s % 8, math_floor(s / 8)
    local df = f < 4 and 3 - f or f - 4
    local dr = r < 4 and 3 - r or r - 4
    CMD[SQ120[s]] = df + dr
end

local PASS_MG = { [-1] = 0, [0] = 0, 5, 10, 15, 25, 40, 60, 0, 0 }
local PASS_EG = { [-1] = 0, [0] = 0, 10, 15, 25, 45, 75, 120, 0, 0 }
local DOUBLED_MG, DOUBLED_EG = 10, 20
local ISO_MG, ISO_EG = 12, 15
local TEMPO = 10

---------------------------------------------------------------------------------------------------
-- Position
---------------------------------------------------------------------------------------------------
-- Note for maintainers: the hot functions below are written to be friendly to LuaJIT's trace compiler
-- (few data-dependent branches, lookup tables instead of if-chains). Branchy code makes the trace tree
-- explode and forces trace flushes, which would slow down the whole game, not just this module.

-- Lookup tables indexed by p + 7 (board values incl. off-board 7).
local ISPAWN, NONEMPTY, PHASE_W, PHASE_B, CI, COFF, WPAWN, BPAWN = {}, {}, {}, {}, {}, {}, {}, {}
for k = 0, 14 do
    local p = k - 7
    ISPAWN[k] = (p == 1 or p == -1) and 1 or 0
    NONEMPTY[k] = p ~= 0 and 1 or 0
    PHASE_W[k] = (p >= 1 and p <= 6) and PHASE[k] or 0
    PHASE_B[k] = (p <= -1 and p >= -6) and PHASE[k] or 0
    CI[k] = p > 0 and 1 or 2
    COFF[k] = p > 0 and 0 or 16
    WPAWN[k] = p == 1 and 1 or 0
    BPAWN[k] = p == -1 and 1 or 0
end
local HALF_KEEP = { [0] = 1, 0, 0 }
-- 0/1 flags for the branch-free generator
local ENEMYN, EMPTYN = {}, {}
for k = 0, 14 do
    ENEMYN[k] = (k >= 1 and k <= 6) and 1 or 0
    EMPTYN[k] = k == 7 and 1 or 0
end
local ISZERO = {}
for d = 0, 256 do ISZERO[d] = d == 128 and 1 or 0 end
-- indexed by square * stm + 200: pawn on its 7th rank (promotes next) / on its 2nd rank (may double push)
local PROMO_RANK, DOUBLE_RANK = {}, {}
for d = 0, 400 do
    PROMO_RANK[d] = 0
    DOUBLE_RANK[d] = 0
end
for i = 21, 98 do
    if RANK120[i] == 6 then PROMO_RANK[i + 200] = 1 end
    if RANK120[i] == 1 then PROMO_RANK[200 - i] = 1 end
    if RANK120[i] == 1 then DOUBLE_RANK[i + 200] = 1 end
    if RANK120[i] == 6 then DOUBLE_RANK[200 - i] = 1 end
end
local EPAWN = {} -- by x * stm + 7: 1 for an enemy pawn
for k = 0, 14 do EPAWN[k] = k == 6 and 1 or 0 end
local KW, KB = {}, {} -- 1 for the white / black king
for k = 0, 14 do
    KW[k] = k == 13 and 1 or 0
    KB[k] = k == 1 and 1 or 0
end

local Position = {}
Position.__index = Position

-- Undo record stride in pos.U (per ply): 1 move, 2 captured, 3 castle, 4 ep, 5 eph1, 6 eph2, 7 half,
-- 8 full, 9 h1, 10 h2, 11 ph, 12 mg, 13 eg, 14 phw, 15 phb
local US = 16

-- Piece list: pos.pl[1..16] white squares, pos.pl[17..32] black squares; pos.pn = { nwhite, nblack };
-- pos.pidx[square] = index into pos.pl; pos.cnt[p + 7] = number of pieces p.
local function blank_position()
    local b, pidx, cnt = {}, {}, {}
    for i = 0, 119 do
        b[i] = OFF
        pidx[i] = 0
    end
    for s = 0, 63 do b[SQ120[s]] = 0 end
    for k = 0, 14 do cnt[k] = 0 end
    return setmetatable({
        b = b, pidx = pidx, pl = {}, pn = { 0, 0 }, cnt = cnt,
        stm = 1, castle = 0, ep = 0, eph1 = 0, eph2 = 0, half = 0, full = 1,
        h1 = 0, h2 = 0, ph = 0, mg = 0, eg = 0, phw = 0, phb = 0, k1 = 0, k2 = 0,
        hply = 0, U = {}, kh = {}, mlist = {},
    }, Position)
end

local function list_add(pos, p, i)
    local c = CI[p + 7]
    local pn = pos.pn
    local n = pn[c] + 1
    pn[c] = n
    local li = COFF[p + 7] + n
    pos.pl[li] = i
    pos.pidx[i] = li
    local cnt = pos.cnt
    cnt[p + 7] = cnt[p + 7] + 1
end

local function put_piece(pos, p, i)
    pos.b[i] = p
    list_add(pos, p, i)
    pos.phw = pos.phw + PHASE_W[p + 7]
    pos.phb = pos.phb + PHASE_B[p + 7]
    if p == 6 then pos.k1 = i elseif p == -6 then pos.k2 = i end
    local k = (p + 7) * 128 + i
    pos.mg = pos.mg + PMG[k]
    pos.eg = pos.eg + PEG[k]
end

-- Full recomputation of both hash parts (used on setup and by tests to verify incremental keys).
local function compute_hash(pos)
    local b = pos.b
    local h1, h2, ph = 0, 0, 0
    for s = 0, 63 do
        local i = SQ120[s]
        local p = b[i]
        if p ~= 0 then
            local k = (p + 7) * 128 + i
            h1 = h1 + Z1[k]
            h2 = h2 + Z2[k]
            if p == 1 or p == -1 then ph = ph + Z1[k] end
        end
    end
    if pos.stm == -1 then
        h1 = h1 + ZS1
        h2 = h2 + ZS2
    end
    h1 = h1 + ZC1[pos.castle]
    h2 = h2 + ZC2[pos.castle]
    local e1, e2 = 0, 0
    local ep = pos.ep
    if ep ~= 0 then
        local stm = pos.stm
        local pawn_sq = ep - 10 * stm
        if b[pawn_sq - 1] == stm or b[pawn_sq + 1] == stm then
            e1, e2 = ZE1[FILE120[ep]], ZE2[FILE120[ep]]
        end
    end
    h1 = h1 + e1
    h2 = h2 + e2
    return h1 % HM, h2 % HM, ph % HM, e1, e2
end

-- Precomputed ray tables. For piece type t (2..6) on square i, entries start at GSTART[t * 128 + i];
-- GTO[idx] is a target square (0 ends the list) and GSKIP[idx] is the first entry of the next ray, so a
-- blocked ray is skipped in one step. One flat loop per piece keeps the trace compiler happy.
local GSTART, GTO, GSKIP = {}, {}, {}
do
    local idx = 1
    local ray_dirs = { [2] = KN_OFF, [3] = B_DIR, [4] = R_DIR, [5] = K_OFF, [6] = K_OFF }
    local sliding = { [2] = false, [3] = true, [4] = true, [5] = true, [6] = false }
    for t = 2, 6 do
        for s = 0, 63 do
            local i = SQ120[s]
            GSTART[t * 128 + i] = idx
            local dirs = ray_dirs[t]
            for k = 1, #dirs do
                local d = dirs[k]
                local first = idx
                local to = i + d
                while SQ64[to] and SQ64[to] >= 0 do
                    GTO[idx] = to
                    idx = idx + 1
                    if not sliding[t] then break end
                    to = to + d
                end
                for j = first, idx - 1 do GSKIP[j] = idx end
            end
            GTO[idx] = 0
            GSKIP[idx] = idx
            idx = idx + 1
        end
    end
end

-- Attack tables: for square i, entries from ASTART[i]: the 8 knight squares, then the 8 rays.
-- ACLASS[idx]: 1 knight, 2 diagonal first step "down" (a white pawn there attacks), 3 diagonal first
-- step "up" (a black pawn there attacks), 4 diagonal further, 5 orthogonal first step, 6 orthogonal
-- further. ATTACKS[(class * 2 + side) * 16 + x * by + 7] is 1 when a piece x of side `by`
-- (side 0 white, 1 black) standing there attacks i.
local ASTART, ATO, ASKIP, ACLASS = {}, {}, {}, {}
local ATTACKS = {}
do
    local idx = 1
    for s = 0, 63 do
        local i = SQ120[s]
        ASTART[i] = idx
        for k = 1, 8 do
            local to = i + KN_OFF[k]
            if SQ64[to] and SQ64[to] >= 0 then
                ATO[idx] = to
                ASKIP[idx] = idx + 1
                ACLASS[idx] = 1
                idx = idx + 1
            end
        end
        local dirs = { -11, -9, 9, 11, -10, -1, 1, 10 }
        for k = 1, 8 do
            local d = dirs[k]
            local first = idx
            local to = i + d
            local step = 1
            while SQ64[to] and SQ64[to] >= 0 do
                ATO[idx] = to
                if k <= 4 then
                    if step == 1 then ACLASS[idx] = d < 0 and 2 or 3 else ACLASS[idx] = 4 end
                else
                    ACLASS[idx] = step == 1 and 5 or 6
                end
                idx = idx + 1
                step = step + 1
                to = to + d
            end
            for j = first, idx - 1 do ASKIP[j] = idx end
        end
        ATO[idx] = 0
        ASKIP[idx] = idx
        ACLASS[idx] = 0
        idx = idx + 1
    end
    for k = 0, 7 * 2 * 16 + 31 do ATTACKS[k] = 0 end
    for side = 0, 1 do
        local function set(class, t) ATTACKS[(class * 2 + side) * 16 + t + 7] = 1 end
        set(1, 2)
        for _, class in ipairs({ 2, 3, 4 }) do
            set(class, 3)
            set(class, 5)
        end
        set(2, 6)
        set(3, 6)
        set(5, 6)
        set(5, 4)
        set(5, 5)
        set(6, 4)
        set(6, 5)
        -- pawns: white pawns attack upward, so they sit "down" (class 2) from the target square
        if side == 0 then set(2, 1) else set(3, 1) end
    end
end

-- Is square sq attacked by side `by` (1 white, -1 black)? One flat loop over the attack table.
local function attacked(b, sq, by)
    local idx = ASTART[sq]
    local s = ATO[idx]
    while s ~= 0 do
        local x = b[s]
        if x == 0 then
            idx = idx + 1
        else
            if ATTACKS[(ACLASS[idx] * 2 + (1 - by) / 2) * 16 + x * by + 7] == 1 then return true end
            idx = ASKIP[idx]
        end
        s = ATO[idx]
    end
    return false
end


-- Pseudo-legal move generation into list[n + 1 ..]; returns the new end index.
-- caps = true: captures, en passant and queen promotions only (quiescence).
-- Written as ONE flat loop (pieces and ray entries share it). Candidate moves are always written and
-- the end index advances by a 0/1 flag from a lookup table, so there are almost no data-dependent
-- branches: this keeps LuaJIT's trace tree small.
local function gen(pos, list, n, caps)
    STITCH()
    local b = pos.b
    local stm = pos.stm
    local off = COFF[stm + 7]
    local pl = pos.pl
    local li = off + 1
    local last = off + pos.pn[CI[stm + 7]]
    local ep = pos.ep
    local quiet = caps and 0 or 1
    local from, idx, to = 0, 0, 0
    while true do
        if to == 0 then
            if li > last then break end
            from = pl[li]
            li = li + 1
            local t = b[from] * stm
            if t == 1 then
                local fwd = 10 * stm
                local ahead = from + fwd
                local rr = PROMO_RANK[from * stm + 200]
                local cl, cr = ahead - 1, ahead + 1
                local fl = ENEMYN[b[cl] * stm + 7]
                local fr = ENEMYN[b[cr] * stm + 7]
                local fa = EMPTYN[b[ahead] + 7]
                if rr == 1 then
                    -- promotions (queen always, under-promotions only in full generation)
                    local base = from + ahead * FT
                    list[n + 1] = base + 5 * PR
                    n = n + fa
                    if quiet == 1 then
                        list[n + 1] = base + 4 * PR
                        list[n + 2] = base + 3 * PR
                        list[n + 3] = base + 2 * PR
                        n = n + 3 * fa
                    end
                    base = from + cl * FT
                    list[n + 1] = base + 5 * PR
                    n = n + fl
                    if quiet == 1 then
                        list[n + 1] = base + 4 * PR
                        list[n + 2] = base + 3 * PR
                        list[n + 3] = base + 2 * PR
                        n = n + 3 * fl
                    end
                    base = from + cr * FT
                    list[n + 1] = base + 5 * PR
                    n = n + fr
                    if quiet == 1 then
                        list[n + 1] = base + 4 * PR
                        list[n + 2] = base + 3 * PR
                        list[n + 3] = base + 2 * PR
                        n = n + 3 * fr
                    end
                else
                    local two = ahead + fwd
                    list[n + 1] = from + ahead * FT
                    n = n + fa * quiet
                    list[n + 1] = from + two * FT + 2 * FL
                    n = n + fa * quiet * DOUBLE_RANK[from * stm + 200] * EMPTYN[b[two] + 7]
                    list[n + 1] = from + cl * FT
                    n = n + fl
                    list[n + 1] = from + cl * FT + FL
                    n = n + ISZERO[cl - ep + 128]
                    list[n + 1] = from + cr * FT
                    n = n + fr
                    list[n + 1] = from + cr * FT + FL
                    n = n + ISZERO[cr - ep + 128]
                end
            else
                idx = GSTART[t * 128 + from]
                to = GTO[idx]
            end
        else
            local x = b[to]
            list[n + 1] = from + to * FT
            if x == 0 then
                n = n + quiet
                idx = idx + 1
            else
                n = n + ENEMYN[x * stm + 7]
                idx = GSKIP[idx]
            end
            to = GTO[idx]
        end
    end
    local castle = pos.castle
    if castle ~= 0 and not caps then
        if stm == 1 then
            if AND16[castle * 16 + 1] ~= 0 and b[26] == 0 and b[27] == 0
                and not attacked(b, 25, -1) and not attacked(b, 26, -1) then
                n = n + 1; list[n] = 25 + 27 * FT + 3 * FL
            end
            if AND16[castle * 16 + 2] ~= 0 and b[24] == 0 and b[23] == 0 and b[22] == 0
                and not attacked(b, 25, -1) and not attacked(b, 24, -1) then
                n = n + 1; list[n] = 25 + 23 * FT + 3 * FL
            end
        else
            if AND16[castle * 16 + 4] ~= 0 and b[96] == 0 and b[97] == 0
                and not attacked(b, 95, 1) and not attacked(b, 96, 1) then
                n = n + 1; list[n] = 95 + 97 * FT + 3 * FL
            end
            if AND16[castle * 16 + 8] ~= 0 and b[94] == 0 and b[93] == 0 and b[92] == 0
                and not attacked(b, 95, 1) and not attacked(b, 94, 1) then
                n = n + 1; list[n] = 95 + 93 * FT + 3 * FL
            end
        end
    end
    return n
end

-- Removes piece p on square i from hash, evaluation terms, counts and piece list (not from b[]).
local function lift(pos, p, i)
    local pk = p + 7
    local k = pk * 128 + i
    pos.h1 = pos.h1 - Z1[k]
    pos.h2 = pos.h2 - Z2[k]
    pos.mg = pos.mg - PMG[k]
    pos.eg = pos.eg - PEG[k]
    pos.ph = pos.ph - Z1[k] * ISPAWN[pk]
    pos.phw = pos.phw - PHASE_W[pk]
    pos.phb = pos.phb - PHASE_B[pk]
    local cnt = pos.cnt
    cnt[pk] = cnt[pk] - 1
    local c = CI[pk]
    local pn = pos.pn
    local n = pn[c]
    pn[c] = n - 1
    local pl, pidx = pos.pl, pos.pidx
    local li = pidx[i]
    local last = pl[COFF[pk] + n]
    pl[li] = last
    pidx[last] = li
end

-- Moves piece p from a to c in hash, evaluation terms and piece list (board updated by caller).
local function shift(pos, p, a, c)
    local k = (p + 7) * 128
    pos.h1 = pos.h1 - Z1[k + a] + Z1[k + c]
    pos.h2 = pos.h2 - Z2[k + a] + Z2[k + c]
    pos.mg = pos.mg - PMG[k + a] + PMG[k + c]
    pos.eg = pos.eg - PEG[k + a] + PEG[k + c]
    pos.ph = pos.ph + (Z1[k + c] - Z1[k + a]) * ISPAWN[p + 7]
    local pidx = pos.pidx
    local li = pidx[a]
    pidx[c] = li
    pos.pl[li] = c
end

local function make(pos, m)
    STITCH()
    local b = pos.b
    local from = m % 128
    local to = ((m - from) / 128) % 128
    local hi = (m - from - to * 128) / 16384 -- promo + 8 * flag
    local stm = pos.stm
    local p = b[from]
    local hp = pos.hply + 1
    pos.hply = hp
    local U = pos.U
    local o = hp * US
    U[o + 1] = m
    U[o + 3] = pos.castle
    U[o + 4] = pos.ep
    U[o + 5] = pos.eph1
    U[o + 6] = pos.eph2
    U[o + 7] = pos.half
    U[o + 8] = pos.full
    U[o + 9] = pos.h1
    U[o + 10] = pos.h2
    U[o + 11] = pos.ph
    U[o + 12] = pos.mg
    U[o + 13] = pos.eg
    U[o + 14] = pos.phw
    U[o + 15] = pos.phb
    pos.h1 = pos.h1 - pos.eph1
    pos.h2 = pos.h2 - pos.eph2
    pos.eph1 = 0
    pos.eph2 = 0
    pos.ep = 0

    local capsq = to
    if hi == 8 then capsq = to - 10 * stm end
    local cap = b[capsq]
    U[o + 2] = cap
    -- fifty-move clock: reset on pawn moves and captures (branch-free)
    pos.half = (pos.half + 1) * HALF_KEEP[ISPAWN[p + 7] + NONEMPTY[cap + 7]]
    if cap ~= 0 then
        lift(pos, cap, capsq)
        b[capsq] = 0
    end

    shift(pos, p, from, to)
    b[from] = 0
    b[to] = p

    if hi ~= 0 then
        if hi < 8 then
            -- promotion: replace the pawn with the new piece
            local np = hi * stm
            lift(pos, p, to)
            b[to] = np
            list_add(pos, np, to)
            local k = (np + 7) * 128 + to
            pos.h1 = pos.h1 + Z1[k]
            pos.h2 = pos.h2 + Z2[k]
            pos.mg = pos.mg + PMG[k]
            pos.eg = pos.eg + PEG[k]
            pos.phw = pos.phw + PHASE_W[np + 7]
            pos.phb = pos.phb + PHASE_B[np + 7]
        elseif hi == 16 then
            pos.ep = from + 10 * stm
            if b[to - 1] == -stm or b[to + 1] == -stm then
                local f = FILE120[to]
                pos.eph1 = ZE1[f]
                pos.eph2 = ZE2[f]
                pos.h1 = pos.h1 + ZE1[f]
                pos.h2 = pos.h2 + ZE2[f]
            end
        elseif hi == 24 then
            local rf, rt
            if to > from then
                rf, rt = from + 3, from + 1
            else
                rf, rt = from - 4, from - 1
            end
            local r = b[rf]
            shift(pos, r, rf, rt)
            b[rf] = 0
            b[rt] = r
        end
    end
    pos.k1 = pos.k1 + (to - from) * KW[p + 7]
    pos.k2 = pos.k2 + (to - from) * KB[p + 7]

    local castle = pos.castle
    local nc = AND16[AND16[castle * 16 + CMASK[from]] * 16 + CMASK[to]]
    pos.castle = nc
    pos.h1 = (pos.h1 - ZC1[castle] + ZC1[nc] + ZS1 * stm) % HM
    pos.h2 = (pos.h2 - ZC2[castle] + ZC2[nc] + ZS2 * stm) % HM
    pos.full = pos.full + (1 - stm) / 2
    pos.ph = pos.ph % HM
    pos.stm = -stm
    local kh = pos.kh
    kh[hp * 2] = pos.h1
    kh[hp * 2 + 1] = pos.h2
end

local function unmake(pos)
    STITCH()
    local hp = pos.hply
    local U = pos.U
    local o = hp * US
    local m = U[o + 1]
    local from = m % 128
    local to = ((m - from) / 128) % 128
    local hi = (m - from - to * 128) / 16384
    local b, pidx, pl, cnt = pos.b, pos.pidx, pos.pl, pos.cnt
    local stm = -pos.stm
    pos.stm = stm
    local p = b[to]
    if hi ~= 0 then
        if hi < 8 then
            -- undo promotion: the promoted piece becomes a pawn again (list slot is re-used)
            cnt[p + 7] = cnt[p + 7] - 1
            cnt[stm + 7] = cnt[stm + 7] + 1
            p = stm
        end
    end
    b[to] = 0
    b[from] = p
    local li = pidx[to]
    pidx[from] = li
    pl[li] = from
    if hi == 24 then
        local rf, rt
        if to > from then
            rf, rt = from + 3, from + 1
        else
            rf, rt = from - 4, from - 1
        end
        local r = b[rt]
        b[rt] = 0
        b[rf] = r
        local ri = pidx[rt]
        pidx[rf] = ri
        pl[ri] = rf
    end
    pos.k1 = pos.k1 + (from - to) * KW[p + 7]
    pos.k2 = pos.k2 + (from - to) * KB[p + 7]
    local cap = U[o + 2]
    if cap ~= 0 then
        local capsq = to
        if hi == 8 then capsq = to - 10 * stm end
        b[capsq] = cap
        local ck = cap + 7
        local c = CI[ck]
        local pn = pos.pn
        local n = pn[c] + 1
        pn[c] = n
        local cli = COFF[ck] + n
        pl[cli] = capsq
        pidx[capsq] = cli
        cnt[ck] = cnt[ck] + 1
    end
    pos.castle = U[o + 3]
    pos.ep = U[o + 4]
    pos.eph1 = U[o + 5]
    pos.eph2 = U[o + 6]
    pos.half = U[o + 7]
    pos.full = U[o + 8]
    pos.h1 = U[o + 9]
    pos.h2 = U[o + 10]
    pos.ph = U[o + 11]
    pos.mg = U[o + 12]
    pos.eg = U[o + 13]
    pos.phw = U[o + 14]
    pos.phb = U[o + 15]
    pos.hply = hp - 1
end

-- True when the side that just moved left its own king in check.
local function left_in_check(pos)
    local stm = pos.stm
    local k1 = pos.k1
    return attacked(pos.b, k1 + (pos.k2 - k1) * (1 + stm) / 2, stm)
end

local function in_check(pos)
    local stm = pos.stm
    local k1 = pos.k1
    return attacked(pos.b, k1 + (pos.k2 - k1) * (1 - stm) / 2, -stm)
end

-- ALIGNED[d + 120] is true when a square delta d could lie on a rank, file or diagonal (a superset).
-- A non-king move from a square not aligned with the mover's king, made while not in check and not en
-- passant, can never expose that king, so the legality test is skipped for it.
local ALIGNED = {}
for d = 0, 240 do ALIGNED[d] = false end
for k = 1, 7 do
    for _, step in ipairs({ 1, 9, 10, 11 }) do
        ALIGNED[120 + k * step] = true
        ALIGNED[120 - k * step] = true
    end
end

-- Call right after make(pos, m). ksq = the mover's king square before the move, chk = mover was in check.
local function illegal(pos, m, ksq, chk)
    local from = m % 128
    if chk or from == ksq or ALIGNED[from - ksq + 120] or (m >= FL and m < 2 * FL) then
        return left_in_check(pos)
    end
    return false
end

local function own_king(pos)
    local k1 = pos.k1
    return k1 + (pos.k2 - k1) * (1 - pos.stm) / 2
end

local GEN_BUF = {}
-- Legal move codes into out[1..n]; returns n.
local function legal_codes(pos, out)
    local n = gen(pos, GEN_BUF, 0, false)
    local ksq, chk = own_king(pos), in_check(pos)
    local c = 0
    for i = 1, n do
        local m = GEN_BUF[i]
        make(pos, m)
        if not illegal(pos, m, ksq, chk) then
            c = c + 1
            out[c] = m
        end
        unmake(pos)
    end
    return c
end

local function has_legal(pos)
    local n = gen(pos, GEN_BUF, 0, false)
    local ksq, chk = own_king(pos), in_check(pos)
    for i = 1, n do
        local m = GEN_BUF[i]
        make(pos, m)
        local ok = not illegal(pos, m, ksq, chk)
        unmake(pos)
        if ok then return true end
    end
    return false
end

local function is_rep(pos)
    local hp = pos.hply
    local lim = hp - pos.half
    if lim < 0 then lim = 0 end
    local i = hp - 4
    if i < lim then return false end
    local h1, h2, kh = pos.h1, pos.h2, pos.kh
    while i >= lim do
        if kh[i * 2] == h1 and kh[i * 2 + 1] == h2 then return true end
        i = i - 2
    end
    return false
end

local function repetition_count(pos)
    local hp = pos.hply
    local lim = hp - pos.half
    if lim < 0 then lim = 0 end
    local h1, h2, kh = pos.h1, pos.h2, pos.kh
    local c = 1
    local i = hp - 2
    while i >= lim do
        if kh[i * 2] == h1 and kh[i * 2 + 1] == h2 then c = c + 1 end
        i = i - 2
    end
    return c
end

-- Dead positions: K v K, K+minor v K, and bishops only (any number) all on one square colour.
local function insufficient(pos)
    local cnt = pos.cnt
    if cnt[8] + cnt[6] + cnt[11] + cnt[3] + cnt[12] + cnt[2] > 0 then return false end
    local knights = cnt[9] + cnt[5]
    local bishops = cnt[10] + cnt[4]
    if knights + bishops <= 1 then return true end
    if knights > 0 then return false end
    local b, pl = pos.b, pos.pl
    local light, dark = 0, 0
    for c = 1, 2 do
        local off = (c - 1) * 16
        for li = off + 1, off + pos.pn[c] do
            local s = pl[li]
            local t = b[s]
            if t == 3 or t == -3 then
                if (FILE120[s] + RANK120[s]) % 2 == 0 then dark = dark + 1 else light = light + 1 end
            end
        end
    end
    return light == 0 or dark == 0
end

---------------------------------------------------------------------------------------------------
-- Evaluation (centipawns, from the side to move's point of view)
---------------------------------------------------------------------------------------------------
local PC_SIZE = 16384
local PC_KEY, PC_MG, PC_EG, PC_FILE = {}, {}, {}, {}
for i = 1, PC_SIZE do
    PC_KEY[i] = -1
    PC_MG[i] = 0
    PC_EG[i] = 0
end
for i = 0, PC_SIZE * 8 + 16 do PC_FILE[i] = 0 end
local WC, BC, WMIN, WMAX, BMIN, BMAX = {}, {}, {}, {}, {}, {}

-- Rook file bonus by pawn-file code (1 = white pawn on file, 2 = black pawn, 3 = both).
local ROOK_W_MG = { [0] = 22, 0, 10, 0 }
local ROOK_B_MG = { [0] = 22, 10, 0, 0 }
local ROOK_W_EG = { [0] = 8, 0, 4, 0 }
local ROOK_B_EG = { [0] = 8, 4, 0, 0 }
local BPAIR_MG, BPAIR_EG = {}, {}
for i = 0, 10 do
    BPAIR_MG[i] = i >= 2 and 30 or 0
    BPAIR_EG[i] = i >= 2 and 45 or 0
end
local SHIELD_W, SHIELD_B = {}, {} -- 1 when a king on this square gets a pawn shield bonus
for i = 0, 119 do
    SHIELD_W[i] = (RANK120[i] == 0 or RANK120[i] == 1) and 1 or 0
    SHIELD_B[i] = (RANK120[i] == 6 or RANK120[i] == 7) and 1 or 0
end

local math_max = math.max
local function pawn_eval(pos, slot)
    for f = 0, 9 do
        WC[f] = 0; BC[f] = 0
        WMIN[f] = 8; BMIN[f] = 8
        WMAX[f] = -1; BMAX[f] = -1
    end
    local b, pl = pos.b, pos.pl
    -- branch-free accumulation (non-pawns contribute nothing)
    for li = 1, pos.pn[1] do
        local s = pl[li]
        local w = WPAWN[b[s] + 7]
        local f, r = FILE120[s] + 1, RANK120[s]
        WC[f] = WC[f] + w
        WMIN[f] = math_min(WMIN[f], r + 8 * (1 - w))
        WMAX[f] = math_max(WMAX[f], r * w - (1 - w))
    end
    for li = 17, 16 + pos.pn[2] do
        local s = pl[li]
        local w = BPAWN[b[s] + 7]
        local f, r = FILE120[s] + 1, RANK120[s]
        BC[f] = BC[f] + w
        BMIN[f] = math_min(BMIN[f], r + 8 * (1 - w))
        BMAX[f] = math_max(BMAX[f], r * w - (1 - w))
    end
    local mg, eg = 0, 0
    local fs = slot * 8 - 1
    for f = 1, 8 do
        local wc, bc = WC[f], BC[f]
        PC_FILE[fs + f] = math_min(wc, 1) + 2 * math_min(bc, 1)
        -- doubled
        local dw, db = math_max(wc - 1, 0), math_max(bc - 1, 0)
        mg = mg - DOUBLED_MG * (dw - db)
        eg = eg - DOUBLED_EG * (dw - db)
        -- isolated (1 when no friendly pawn on either neighbour file)
        local iw = wc * (1 - math_min(WC[f - 1] + WC[f + 1], 1))
        local ib = bc * (1 - math_min(BC[f - 1] + BC[f + 1], 1))
        mg = mg - ISO_MG * (iw - ib)
        eg = eg - ISO_EG * (iw - ib)
        -- passed: front-most pawn with no enemy pawn ahead on this or adjacent files
        local r = WMAX[f]
        local pw = math_min(math_max(r - math_max(BMAX[f - 1], BMAX[f], BMAX[f + 1]) + 1, 0), 1)
        local rb = BMIN[f]
        local pb = math_min(math_max(math_min(WMIN[f - 1], WMIN[f], WMIN[f + 1]) - rb + 1, 0), 1)
        mg = mg + pw * PASS_MG[r] - pb * PASS_MG[7 - rb]
        eg = eg + pw * PASS_EG[r] - pb * PASS_EG[7 - rb]
    end
    PC_KEY[slot] = pos.ph
    PC_MG[slot] = mg
    PC_EG[slot] = eg
end

-- Endgame adjustments (rare, kept out of the hot path): drawish material without pawns and driving a
-- lone king to the edge.
local function endgame_adjust(pos, s)
    local cnt = pos.cnt
    local k1, k2 = pos.k1, pos.k2
    local wp, bp = cnt[8], cnt[6]
    local wnpm = cnt[9] * 320 + cnt[10] * 330 + cnt[11] * 500 + cnt[12] * 900
    local bnpm = cnt[5] * 320 + cnt[4] * 330 + cnt[3] * 500 + cnt[2] * 900
    local df = FILE120[k1] - FILE120[k2]
    local dr = RANK120[k1] - RANK120[k2]
    if df < 0 then df = -df end
    if dr < 0 then dr = -dr end
    if s > 0 then
        if wp == 0 and (wnpm - bnpm < 400 or (bnpm == 0 and cnt[9] == 2 and wnpm == 640)) then
            s = math_floor(s / 8)
        elseif bp == 0 and bnpm == 0 and wnpm >= 500 then
            s = s + 10 * CMD[k2] + 4 * (14 - df - dr) + 200
        end
    elseif s < 0 then
        if bp == 0 and (bnpm - wnpm < 400 or (wnpm == 0 and cnt[5] == 2 and bnpm == 640)) then
            s = -math_floor(-s / 8)
        elseif wp == 0 and wnpm == 0 and bnpm >= 500 then
            s = s - 10 * CMD[k1] - 4 * (14 - df - dr) - 200
        end
    end
    return s
end

local function evaluate(pos)
    local b, cnt = pos.b, pos.cnt
    local mg, eg = pos.mg, pos.eg
    local ph = pos.ph
    local slot = ph % PC_SIZE + 1
    if PC_KEY[slot] ~= ph then pawn_eval(pos, slot) end
    mg = mg + PC_MG[slot] + BPAIR_MG[cnt[10]] - BPAIR_MG[cnt[4]]
    eg = eg + PC_EG[slot] + BPAIR_EG[cnt[10]] - BPAIR_EG[cnt[4]]

    -- rooks on open / half-open files
    if cnt[11] + cnt[3] > 0 then
        local pl = pos.pl
        local fs = slot * 8
        for li = 1, pos.pn[1] do
            local s = pl[li]
            if b[s] == 4 then
                local code = PC_FILE[fs + FILE120[s]]
                mg = mg + ROOK_W_MG[code]
                eg = eg + ROOK_W_EG[code]
            end
        end
        for li = 17, 16 + pos.pn[2] do
            local s = pl[li]
            if b[s] == -4 then
                local code = PC_FILE[fs + FILE120[s]]
                mg = mg - ROOK_B_MG[code]
                eg = eg - ROOK_B_EG[code]
            end
        end
    end

    -- king pawn shield (middlegame term, branch-free)
    local k1, k2 = pos.k1, pos.k2
    local a, c, d = WPAWN[b[k1 + 9] + 7], WPAWN[b[k1 + 10] + 7], WPAWN[b[k1 + 11] + 7]
    local sh = 12 * (a + c + d) + 6 * ((1 - a) * WPAWN[b[k1 + 19] + 7] + (1 - c) * WPAWN[b[k1 + 20] + 7]
        + (1 - d) * WPAWN[b[k1 + 21] + 7])
    mg = mg + sh * SHIELD_W[k1]
    a, c, d = BPAWN[b[k2 - 9] + 7], BPAWN[b[k2 - 10] + 7], BPAWN[b[k2 - 11] + 7]
    sh = 12 * (a + c + d) + 6 * ((1 - a) * BPAWN[b[k2 - 19] + 7] + (1 - c) * BPAWN[b[k2 - 20] + 7]
        + (1 - d) * BPAWN[b[k2 - 21] + 7])
    mg = mg - sh * SHIELD_B[k2]

    local phase = pos.phw + pos.phb
    if phase > 24 then phase = 24 end
    local s = math_floor((mg * phase + eg * (24 - phase)) / 24)
    if cnt[8] == 0 or cnt[6] == 0 then s = endgame_adjust(pos, s) end
    return s * pos.stm + TEMPO
end

---------------------------------------------------------------------------------------------------
-- FEN
---------------------------------------------------------------------------------------------------
local function square_name(s)
    return string_sub(FILE_CHARS, s % 8 + 1, s % 8 + 1) .. tostring(math_floor(s / 8) + 1)
end

local function parse_square(name)
    if type(name) ~= "string" or #name ~= 2 then return nil end
    local f = string_byte(name, 1) - 97
    local r = string_byte(name, 2) - 49
    if f < 0 or f > 7 or r < 0 or r > 7 then return nil end
    return r * 8 + f
end

local function from_fen(fen)
    if type(fen) ~= "string" then return nil, "FEN must be a string" end
    local parts = {}
    for w in fen:gmatch("%S+") do parts[#parts + 1] = w end
    if #parts < 1 then return nil, "empty FEN" end
    local pos = blank_position()
    local rank, file = 7, 0
    local placement = parts[1]
    for idx = 1, #placement do
        local c = string_sub(placement, idx, idx)
        if c == "/" then
            if file ~= 8 then return nil, "bad rank length" end
            rank = rank - 1
            file = 0
            if rank < 0 then return nil, "too many ranks" end
        elseif c:match("%d") then
            file = file + tonumber(c)
            if file > 8 then return nil, "bad rank length" end
        else
            local p = PIECE_OF[c]
            if not p or file > 7 then return nil, "bad piece placement" end
            if (p == 1 or p == -1) and (rank == 0 or rank == 7) then return nil, "pawn on back rank" end
            put_piece(pos, p, SQ120[rank * 8 + file])
            file = file + 1
        end
    end
    if rank ~= 0 or file ~= 8 then return nil, "incomplete placement" end
    local wk, bk = 0, 0
    for s = 0, 63 do
        local p = pos.b[SQ120[s]]
        if p == 6 then wk = wk + 1 elseif p == -6 then bk = bk + 1 end
    end
    if wk ~= 1 or bk ~= 1 then return nil, "need exactly one king per side" end
    local side = parts[2] or "w"
    if side == "w" then
        pos.stm = 1
    elseif side == "b" then
        pos.stm = -1
    else
        return nil, "bad side to move"
    end
    local cs = parts[3] or "-"
    local castle = 0
    local b = pos.b
    if cs ~= "-" then
        for idx = 1, #cs do
            local c = string_sub(cs, idx, idx)
            if c == "K" then
                if b[25] == 6 and b[28] == 4 then castle = castle + 1 end
            elseif c == "Q" then
                if b[25] == 6 and b[21] == 4 then castle = castle + 2 end
            elseif c == "k" then
                if b[95] == -6 and b[98] == -4 then castle = castle + 4 end
            elseif c == "q" then
                if b[95] == -6 and b[91] == -4 then castle = castle + 8 end
            else
                return nil, "bad castling field"
            end
        end
    end
    pos.castle = castle
    local eps = parts[4] or "-"
    if eps ~= "-" then
        local s = parse_square(eps)
        if not s then return nil, "bad en passant square" end
        local r = math_floor(s / 8)
        if (pos.stm == 1 and r ~= 5) or (pos.stm == -1 and r ~= 2) then return nil, "bad en passant rank" end
        pos.ep = SQ120[s]
    end
    pos.half = tonumber(parts[5] or "0") or 0
    pos.full = tonumber(parts[6] or "1") or 1
    if pos.full < 1 then pos.full = 1 end
    local h1, h2, ph, e1, e2 = compute_hash(pos)
    pos.h1, pos.h2, pos.ph, pos.eph1, pos.eph2 = h1, h2, ph, e1, e2
    pos.kh[0] = h1
    pos.kh[1] = h2
    -- The side that just moved must not be in check.
    if left_in_check(pos) then return nil, "side not to move is in check" end
    return pos
end

function Position:fen()
    local b = self.b
    local rows = {}
    for r = 7, 0, -1 do
        local row = {}
        local empty = 0
        for f = 0, 7 do
            local p = b[SQ120[r * 8 + f]]
            if p == 0 then
                empty = empty + 1
            else
                if empty > 0 then
                    row[#row + 1] = tostring(empty)
                    empty = 0
                end
                row[#row + 1] = PCHAR[p + 7]
            end
        end
        if empty > 0 then row[#row + 1] = tostring(empty) end
        rows[#rows + 1] = table_concat(row)
    end
    local c = self.castle
    local cs = ""
    if AND16[c * 16 + 1] ~= 0 then cs = cs .. "K" end
    if AND16[c * 16 + 2] ~= 0 then cs = cs .. "Q" end
    if AND16[c * 16 + 4] ~= 0 then cs = cs .. "k" end
    if AND16[c * 16 + 8] ~= 0 then cs = cs .. "q" end
    if cs == "" then cs = "-" end
    local ep = self.ep ~= 0 and square_name(SQ64[self.ep]) or "-"
    return table_concat(rows, "/") .. " " .. (self.stm == 1 and "w" or "b") .. " " .. cs .. " " .. ep
        .. " " .. tostring(self.half) .. " " .. tostring(self.full)
end

---------------------------------------------------------------------------------------------------
-- Public position API
---------------------------------------------------------------------------------------------------
local function copy_array(src, first, last)
    local dst = {}
    for i = first, last do dst[i] = src[i] end
    return dst
end

function Position:clone()
    local c = setmetatable({}, Position)
    for k, v in pairs(self) do
        if type(v) ~= "table" then c[k] = v end
    end
    c.b = copy_array(self.b, 0, 119)
    c.pidx = copy_array(self.pidx, 0, 119)
    c.pl = copy_array(self.pl, 1, 32)
    c.pn = { self.pn[1], self.pn[2] }
    c.cnt = copy_array(self.cnt, 0, 14)
    local hp = self.hply
    c.U = copy_array(self.U, US, hp * US + US - 1)
    c.kh = copy_array(self.kh, 0, hp * 2 + 1)
    c.mlist = copy_array(self.mlist, 1, hp)
    return c
end

-- Builds the plain move table the view reads. Must be called in the position before the move.
local function move_table(pos, m)
    local b = pos.b
    local from = m % 128
    local r1 = (m - from) / 128
    local to = r1 % 128
    local r2 = (r1 - to) / 128
    local pr = r2 % 8
    local fl = (r2 - pr) / 8
    local stm = pos.stm
    local p = b[from]
    local t = { from = SQ64[from], to = SQ64[to], piece = PCHAR[p + 7], id = m }
    if fl == 1 then
        local cs = to - 10 * stm
        t.captured = PCHAR[b[cs] + 7]
        t.captured_sq = SQ64[cs]
        t.ep = true
    elseif b[to] ~= 0 then
        t.captured = PCHAR[b[to] + 7]
        t.captured_sq = SQ64[to]
    end
    if pr ~= 0 then t.promo = PCHAR[pr * stm + 7] end
    if fl == 2 then t.double = true end
    if fl == 3 then
        if to > from then
            t.castle = "K"
            t.rook_from = SQ64[from + 3]
            t.rook_to = SQ64[from + 1]
        else
            t.castle = "Q"
            t.rook_from = SQ64[from - 4]
            t.rook_to = SQ64[from - 1]
        end
    end
    return t
end

local function code_parts(m)
    local from = m % 128
    local r1 = (m - from) / 128
    local to = r1 % 128
    local pr = ((r1 - to) / 128) % 8
    return SQ64[from], SQ64[to], pr
end

local CODE_BUF = {}

-- Finds the legal internal code for a move table (or {from, to, promo}); nil if illegal.
local function resolve(pos, move)
    if type(move) ~= "table" then return nil end
    local n = legal_codes(pos, CODE_BUF)
    local id = move.id
    if id then
        for i = 1, n do
            if CODE_BUF[i] == id then return id end
        end
    end
    local want = 0
    if move.promo then want = PROMO_OF[move.promo] or 0 end
    for i = 1, n do
        local m = CODE_BUF[i]
        local f, t, pr = code_parts(m)
        if f == move.from and t == move.to and pr == want then return m end
    end
    return nil
end

function Position:piece_at(sq)
    local i = SQ120[sq]
    if not i then return nil end
    local p = self.b[i]
    if p == 0 then return nil end
    return PCHAR[p + 7]
end

function Position:turn()
    return self.stm == 1 and "w" or "b"
end

function Position:king_square(color)
    if color == "b" then return SQ64[self.k2] end
    return SQ64[self.k1]
end

function Position:in_check()
    return in_check(self)
end

-- is_attacked(sq, by_color): is square sq attacked by pieces of by_color ("w"/"b")?
function Position:is_attacked(sq, by_color)
    return attacked(self.b, SQ120[sq], by_color == "b" and -1 or 1)
end

local function trim(out, n)
    local i = n + 1
    while out[i] ~= nil do
        out[i] = nil
        i = i + 1
    end
    return out
end

function Position:legal_moves(out)
    out = out or {}
    local n = legal_codes(self, CODE_BUF)
    for i = 1, n do out[i] = move_table(self, CODE_BUF[i]) end
    return trim(out, n)
end

function Position:legal_moves_from(sq, out)
    out = out or {}
    local i120 = SQ120[sq]
    local n = legal_codes(self, CODE_BUF)
    local c = 0
    for i = 1, n do
        local m = CODE_BUF[i]
        if m % 128 == i120 then
            c = c + 1
            out[c] = move_table(self, m)
        end
    end
    return trim(out, c)
end

function Position:find_move(from, to, promo)
    local want = 5
    if promo ~= nil then
        want = PROMO_OF[promo]
        if not want then return nil end
    end
    local n = legal_codes(self, CODE_BUF)
    local fi, ti = SQ120[from], SQ120[to]
    if not fi or not ti then return nil end
    for i = 1, n do
        local m = CODE_BUF[i]
        local f, t, pr = code_parts(m)
        if f == from and t == to and (pr == 0 or pr == want) then
            return move_table(self, m)
        end
    end
    return nil
end

-- Applies a legal move (a table from legal_moves/find_move, or any table with from/to/promo).
-- Returns true, or false if the move is not legal here (the position is then unchanged).
function Position:make_move(move)
    local m = resolve(self, move)
    if not m then return false end
    -- keep the caller's table when it is a complete move table for this move, so last_move() returns it
    local t = move
    if move.id ~= m or move.piece == nil then t = move_table(self, m) end
    make(self, m)
    self.mlist[self.hply] = t
    return true
end

-- Takes back the last move. Returns the undone move table, or nil if there is no history.
function Position:undo()
    local hp = self.hply
    if hp <= 0 then return nil end
    local t = self.mlist[hp]
    unmake(self)
    self.mlist[hp] = nil
    return t
end

function Position:history_size()
    return self.hply
end

function Position:last_move()
    if self.hply <= 0 then return nil end
    return self.mlist[self.hply]
end

function Position:history()
    local out = {}
    for i = 1, self.hply do out[i] = self.mlist[i] end
    return out
end

function Position:repetition_count()
    return repetition_count(self)
end

function Position:halfmove_clock()
    return self.half
end

function Position:fullmove_number()
    return self.full
end

function Position:insufficient_material()
    return insufficient(self)
end

function Position:status()
    if not has_legal(self) then
        return in_check(self) and "checkmate" or "stalemate"
    end
    if insufficient(self) then return "material" end
    if self.half >= 100 then return "fifty" end
    if repetition_count(self) >= 3 then return "repetition" end
    return "play"
end

-- "1-0", "0-1", "1/2-1/2" or nil while the game is running.
function Position:result()
    local st = self:status()
    if st == "play" then return nil end
    if st == "checkmate" then return self.stm == 1 and "0-1" or "1-0" end
    return "1/2-1/2"
end

-- Two hash parts (each 0 .. 2^31-1) and a combined string key.
function Position:hash()
    return self.h1, self.h2
end

function Position:key()
    return tostring(self.h1) .. ":" .. tostring(self.h2)
end

-- Static evaluation in centipawns from white's point of view (debug / UI "advantage" bar).
function Position:evaluate()
    return (evaluate(self) - TEMPO) * self.stm
end

local SAN_BUF = {}
local SAN_LETTER = { [2] = "N", [3] = "B", [4] = "R", [5] = "Q", [6] = "K" }

local function san_of_code(pos, m)
    local b = pos.b
    local from = m % 128
    local r1 = (m - from) / 128
    local to = r1 % 128
    local r2 = (r1 - to) / 128
    local pr = r2 % 8
    local fl = (r2 - pr) / 8
    local p = b[from]
    local t = p < 0 and -p or p
    local s
    if fl == 3 then
        s = to > from and "O-O" or "O-O-O"
    else
        local capture = b[to] ~= 0 or fl == 1
        local dest = square_name(SQ64[to])
        if t == 1 then
            s = ""
            if capture then s = string_sub(FILE_CHARS, FILE120[from] + 1, FILE120[from] + 1) .. "x" end
            s = s .. dest
            if pr ~= 0 then s = s .. "=" .. SAN_LETTER[pr] end
        else
            s = SAN_LETTER[t]
            -- disambiguation
            local n = legal_codes(pos, SAN_BUF)
            local same, same_file, same_rank = false, false, false
            for i = 1, n do
                local o = SAN_BUF[i]
                local of = o % 128
                local ot = ((o - of) / 128) % 128
                if o ~= m and ot == to and of ~= from and b[of] == p then
                    same = true
                    if FILE120[of] == FILE120[from] then same_file = true end
                    if RANK120[of] == RANK120[from] then same_rank = true end
                end
            end
            if same then
                if not same_file then
                    s = s .. string_sub(FILE_CHARS, FILE120[from] + 1, FILE120[from] + 1)
                elseif not same_rank then
                    s = s .. tostring(RANK120[from] + 1)
                else
                    s = s .. square_name(SQ64[from])
                end
            end
            if capture then s = s .. "x" end
            s = s .. dest
        end
    end
    make(pos, m)
    if in_check(pos) then
        s = s .. (has_legal(pos) and "+" or "#")
    end
    unmake(pos)
    return s
end

function Position:san(move)
    local m = resolve(self, move)
    if not m then return nil end
    return san_of_code(self, m)
end

-- Long algebraic / UCI string of a move table, e.g. "e2e4", "e7e8q".
function Engine.uci(move)
    local s = square_name(move.from) .. square_name(move.to)
    if move.promo then s = s .. string.lower(move.promo) end
    return s
end

function Position:uci(move)
    return Engine.uci(move)
end

-- Parses "e2e4" / "e7e8q" into a legal move table (or nil).
function Position:move_from_uci(str)
    if type(str) ~= "string" then return nil end
    local from = parse_square(string_sub(str, 1, 2))
    local to = parse_square(string_sub(str, 3, 4))
    if not from or not to then return nil end
    local promo = string_sub(str, 5, 5)
    if promo == "" then
        local mv = self:find_move(from, to, nil)
        if mv and mv.promo then return nil end
        return mv
    end
    return self:find_move(from, to, promo)
end

-- Parses SAN ("Nf3", "exd5", "e8=Q+", "O-O") into a legal move table (or nil).
function Position:move_from_san(str)
    if type(str) ~= "string" then return nil end
    local want = str:gsub("[+#!?]", ""):gsub("0", "O")
    local n = legal_codes(self, CODE_BUF)
    local codes = {}
    for i = 1, n do codes[i] = CODE_BUF[i] end
    for i = 1, n do
        local s = san_of_code(self, codes[i]):gsub("[+#]", "")
        if s == want then return move_table(self, codes[i]) end
    end
    return nil
end

local PERFT_BUF = {}
local function perft(pos, depth, base)
    local n = gen(pos, PERFT_BUF, base, false)
    local ksq, chk = own_king(pos), in_check(pos)
    local count = 0
    for i = base + 1, n do
        local m = PERFT_BUF[i]
        make(pos, m)
        if not illegal(pos, m, ksq, chk) then
            if depth <= 1 then
                count = count + 1
            else
                count = count + perft(pos, depth - 1, n)
            end
        end
        unmake(pos)
    end
    return count
end

function Position:perft(depth)
    if depth <= 0 then return 1 end
    return perft(self, depth, 0)
end

-- Per-move perft breakdown (debug): returns { ["e2e4"] = count, ... }
function Position:divide(depth)
    local out = {}
    local moves = self:legal_moves()
    for i = 1, #moves do
        local mv = moves[i]
        self:make_move(mv)
        out[Engine.uci(mv)] = depth > 1 and self:perft(depth - 1) or 1
        self:undo()
    end
    return out
end

---------------------------------------------------------------------------------------------------
-- Opening book (a handful of main lines, UCI moves). Built lazily into hash-key -> codes.
---------------------------------------------------------------------------------------------------
local BOOK_LINES = {
    "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7 f1e1 b7b5 a4b3 d7d6 c2c3 e8g8",
    "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 c2c3 g8f6 d2d3 d7d6 e1g1 e8g8",
    "e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f3d4 g8f6 d4c6 b7c6",
    "e2e4 e7e5 g1f3 g8f6 f3e5 d7d6 e5f3 f6e4 d2d4 d6d5 f1d3",
    "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6 c1e3 e7e5 d4b3",
    "e2e4 c7c5 g1f3 b8c6 d2d4 c5d4 f3d4 g8f6 b1c3 e7e5 d4b5 d7d6",
    "e2e4 e7e6 d2d4 d7d5 b1c3 g8f6 c1g5 f8e7 e4e5 f6d7 g5e7 d8e7",
    "e2e4 c7c6 d2d4 d7d5 b1c3 d5e4 c3e4 c8f5 e4g3 f5g6 h2h4 h7h6",
    "e2e4 d7d5 e4d5 d8d5 b1c3 d5a5 d2d4 g8f6 g1f3 c8f5",
    "e2e4 d7d6 d2d4 g8f6 b1c3 g7g6 g1f3 f8g7 f1e2 e8g8 e1g1",
    "d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c1g5 f8e7 e2e3 e8g8 g1f3 h7h6",
    "d2d4 d7d5 c2c4 c7c6 g1f3 g8f6 b1c3 d5c4 a2a4 c8f5 e2e3 e7e6",
    "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 g1f3 e8g8 f1e2 e7e5 e1g1 b8c6",
    "d2d4 g8f6 c2c4 e7e6 b1c3 f8b4 e2e3 e8g8 f1d3 d7d5 g1f3 c7c5",
    "d2d4 g8f6 c2c4 e7e6 g1f3 b7b6 g2g3 c8a6 b2b3 f8b4 c1d2 b4e7",
    "d2d4 d7d5 c1f4 g8f6 e2e3 c7c5 c2c3 b8c6 b1d2 e7e6 g1f3 f8d6",
    "c2c4 e7e5 b1c3 g8f6 g1f3 b8c6 g2g3 d7d5 c4d5 f6d5 f1g2 d5b6",
    "g1f3 d7d5 g2g3 g8f6 f1g2 e7e6 e1g1 f8e7 d2d3 e8g8",
}
Engine.BOOK_LINES = BOOK_LINES
local BOOK = nil

local function build_book()
    BOOK = {}
    local bad = 0
    for li = 1, #BOOK_LINES do
        local pos = from_fen(Engine.START_FEN)
        for word in BOOK_LINES[li]:gmatch("%S+") do
            local mv = pos:move_from_uci(word)
            if not mv then
                bad = bad + 1
                break
            end
            local key = pos:key()
            local list = BOOK[key]
            if not list then
                list = {}
                BOOK[key] = list
            end
            local dup = false
            for i = 1, #list do
                if list[i] == mv.id then dup = true end
            end
            if not dup then list[#list + 1] = mv.id end
            make(pos, mv.id)
        end
    end
    return bad
end

-- Returns the list of book moves (tables) for a position (empty when out of book).
function Engine.book_moves(pos)
    if not BOOK then build_book() end
    local out = {}
    local list = BOOK[pos:key()]
    if list then
        local n = legal_codes(pos, CODE_BUF)
        for i = 1, #list do
            for j = 1, n do
                if CODE_BUF[j] == list[i] then out[#out + 1] = move_table(pos, list[i]) end
            end
        end
    end
    return out
end

function Engine.book_errors()
    return build_book()
end

---------------------------------------------------------------------------------------------------
-- Search
---------------------------------------------------------------------------------------------------
local MATE = 30000
local MATE_BOUND = 29000
local INF = 32000
local MAXPLY = 96

-- Levels: depth = max iterative-deepening depth, nodes = node budget, rand = chance of a random move,
-- margin = pick randomly among moves scoring within this many centipawns of the best (levels with
-- `variety_moves` do this only during the first that many full moves: opening variety without
-- aimless endgames).
local LEVELS = {
    { depth = 1, nodes = 300, rand = 0.30, margin = 250 },
    { depth = 2, nodes = 1000, rand = 0.15, margin = 120 },
    { depth = 3, nodes = 3000, rand = 0.07, margin = 70 },
    { depth = 4, nodes = 8000, rand = 0.03, margin = 45 },
    { depth = 5, nodes = 20000, rand = 0, margin = 25, variety_moves = 12 },
    { depth = 6, nodes = 40000, rand = 0, margin = 15, variety_moves = 12 },
    { depth = 8, nodes = 80000, rand = 0, margin = 8, variety_moves = 12 },
    { depth = 10, nodes = 150000, rand = 0, margin = 4, variety_moves = 12 },
    { depth = 14, nodes = 250000, rand = 0, margin = 0 },
    { depth = 40, nodes = 400000, rand = 0, margin = 0 },
}
Engine.LEVELS = LEVELS
-- No new iteration is started after this fraction of the node limit has been used.
local SOFT_FRACTION = 0.55

-- Shared transposition table. Entries are tagged with a per-search id, so every search starts with a
-- logically empty table (deterministic results) without clearing memory.
local TT_SIZE = 131072
local TT_CHK, TT_MOVE, TT_SCORE, TT_DEPTH, TT_FLAG = {}, {}, {}, {}, {}
local tt_filled = 0
local tt_sid = 0
local SID_MUL = 2147483648

-- Park-Miller generator (exact in doubles). The seed is scrambled and the generator warmed up so that
-- small or similar seeds still give well-spread first values.
local function new_rng(seed)
    local s = (math_floor(seed) % 2147483647 * 69069 + 12345) % 2147483646 + 1
    for _ = 1, 4 do s = (s * 16807) % 2147483647 end
    return function()
        s = (s * 16807) % 2147483647
        return s / 2147483647
    end
end

local seed_counter = 0
local function default_seed()
    seed_counter = seed_counter + 1
    local r = 0
    if math_random then r = math_floor(math_random() * 2147483000) end
    return r + seed_counter * 7919
end

local VV = {} -- victim values for ordering by p + 7
for p = -6, 6 do VV[p + 7] = VALUE[p + 7] end
VV[6 + 7] = 0
VV[-6 + 7] = 0
local FUT_MARGIN = { [1] = 150, [2] = 320 }

local Job = {}
Job.__index = Job

local function create_searcher(sp, cfg, rng, job)
    local b = sp.b
    local kh = sp.kh
    local nodes = 0
    local yield_at = 0
    local hard_limit = cfg.nodes
    local enforce = false
    local stopped = false
    local MS, SS = {}, {}
    local K1, K2 = {}, {}
    local HIST = {}
    local sid_off = 0
    local RM, RS = {}, {}
    local nroot = 0
    local iter_best = nil

    local function pause()
        job.nodes = nodes
        local budget = co_yield()
        yield_at = nodes + (budget or 2000)
    end

    local qsearch
    qsearch = function(alpha, beta, ply, base)
        nodes = nodes + 1
        if nodes >= yield_at then pause() end
        if enforce and nodes >= hard_limit then stopped = true end
        if stopped then return 0 end
        local stand = evaluate(sp)
        if stand >= beta then return stand end
        if ply >= MAXPLY then return stand end
        if stand > alpha then alpha = stand end
        local stm = sp.stm
        local ksq = sp.k1 + (sp.k2 - sp.k1) * (1 - stm) / 2
        local chk = nil -- in-check status, computed lazily (only when a capture is actually tried)
        local n = gen(sp, MS, base, true)
        for i = base + 1, n do
            local m = MS[i]
            local ft = m % 16384
            local from = ft % 128
            local to = (ft - from) / 128
            local sc = VV[b[to] + 7] * 8 - ATYPE[b[from] + 7]
            if m - ft >= 16384 then
                if (m - ft) / 16384 == 8 then sc = sc + 800 else sc = sc + 6400 end
            end
            SS[i] = sc
        end
        local best = stand
        for i = base + 1, n do
            local bi, bs = i, SS[i]
            for j = i + 1, n do
                if SS[j] > bs then
                    bi = j
                    bs = SS[j]
                end
            end
            local m = MS[bi]
            if bi ~= i then
                MS[bi] = MS[i]
                SS[bi] = SS[i]
                MS[i] = m
                SS[i] = bs
            end
            local ft = m % 16384
            local from = ft % 128
            local to = (ft - from) / 128
            local extra = (m - ft) / 16384
            local gain
            if extra == 8 then
                gain = 100
            else
                gain = VV[b[to] + 7] + PROMO_GAIN[extra % 8]
            end
            local skip = false
            if stand + gain + 200 <= alpha then
                skip = true
            else
                -- losing capture onto a square an enemy pawn defends: skip
                local ahead = to + 10 * stm
                if VALUE[b[from] + 7] > gain + 50
                    and EPAWN[b[ahead - 1] * stm + 7] + EPAWN[b[ahead + 1] * stm + 7] > 0 then
                    skip = true
                end
            end
            if not skip then
                if chk == nil then chk = attacked(b, ksq, -stm) end
                make(sp, m)
                if illegal(sp, m, ksq, chk) then
                    unmake(sp)
                else
                    local s = -qsearch(-beta, -alpha, ply + 1, n)
                    unmake(sp)
                    if stopped then return 0 end
                    if s > best then
                        best = s
                        if s > alpha then
                            if s >= beta then return s end
                            alpha = s
                        end
                    end
                end
            end
        end
        return best
    end

    local search
    search = function(depth, alpha, beta, ply, base, null_ok)
        local stm = sp.stm
        local ksq = sp.k1 + (sp.k2 - sp.k1) * (1 - stm) / 2
        local incheck = attacked(b, ksq, -stm)
        if incheck then depth = depth + 1 end
        if depth <= 0 then return qsearch(alpha, beta, ply, base) end

        nodes = nodes + 1
        if nodes >= yield_at then pause() end
        if enforce and nodes >= hard_limit then stopped = true end
        if stopped then return 0 end

        if sp.half >= 100 and not incheck then return 0 end
        if is_rep(sp) then return 0 end
        if sp.pn[1] + sp.pn[2] <= 4 and insufficient(sp) then return 0 end
        local lo = -MATE + ply
        if alpha < lo then
            alpha = lo
            if lo >= beta then return lo end
        end
        local hi = MATE - ply - 1
        if beta > hi then
            beta = hi
            if alpha >= hi then return hi end
        end
        if ply >= MAXPLY then return evaluate(sp) end

        local pv = beta - alpha > 1
        local idx = sp.h1 % TT_SIZE + 1
        local chk = sp.h2 + sid_off
        local tt_mv = 0
        if TT_CHK[idx] == chk then
            tt_mv = TT_MOVE[idx]
            if not pv and TT_DEPTH[idx] >= depth then
                local s = TT_SCORE[idx]
                if s > MATE_BOUND then s = s - ply elseif s < -MATE_BOUND then s = s + ply end
                local f = TT_FLAG[idx]
                if f == 1 or (f == 2 and s >= beta) or (f == 3 and s <= alpha) then return s end
            end
        end

        local static = 0
        if not incheck then
            static = evaluate(sp)
            if not pv and beta < MATE_BOUND and beta > -MATE_BOUND then
                if depth <= 3 and static - 110 * depth >= beta then return static - 110 * depth end
                if null_ok and depth >= 3 and static >= beta and (stm == 1 and sp.phw or sp.phb) > 0 then
                    local s_ep, s_e1, s_e2, s_h1, s_h2, s_half = sp.ep, sp.eph1, sp.eph2, sp.h1, sp.h2, sp.half
                    local nh1, nh2 = s_h1 - s_e1, s_h2 - s_e2
                    if stm == 1 then
                        nh1 = nh1 + ZS1
                        nh2 = nh2 + ZS2
                    else
                        nh1 = nh1 - ZS1
                        nh2 = nh2 - ZS2
                    end
                    nh1 = nh1 % HM
                    nh2 = nh2 % HM
                    sp.h1 = nh1
                    sp.h2 = nh2
                    sp.ep = 0
                    sp.eph1 = 0
                    sp.eph2 = 0
                    sp.half = 0
                    sp.stm = -stm
                    local hp = sp.hply + 1
                    sp.hply = hp
                    kh[hp * 2] = nh1
                    kh[hp * 2 + 1] = nh2
                    local R = depth >= 7 and 3 or 2
                    local s = -search(depth - 1 - R, -beta, -beta + 1, ply + 1, base, false)
                    sp.hply = hp - 1
                    sp.stm = stm
                    sp.ep, sp.eph1, sp.eph2, sp.h1, sp.h2, sp.half = s_ep, s_e1, s_e2, s_h1, s_h2, s_half
                    if stopped then return 0 end
                    if s >= beta then
                        if s > MATE_BOUND then s = beta end
                        return s
                    end
                end
            end
        end

        local n = gen(sp, MS, base, false)
        local kl1, kl2 = K1[ply], K2[ply]
        for i = base + 1, n do
            local m = MS[i]
            local sc
            if m == tt_mv then
                sc = 3000000
            else
                local ft = m % 16384
                local from = ft % 128
                local to = (ft - from) / 128
                local victim = b[to]
                local extra = (m - ft) / 16384
                local promo = extra % 8
                if victim ~= 0 then
                    sc = 1000000 + VV[victim + 7] * 8 - ATYPE[b[from] + 7]
                    if promo == 5 then sc = sc + 6400 end
                elseif promo ~= 0 then
                    if promo == 5 then sc = 1006400 else sc = -100000 + promo end
                elseif extra == 8 then
                    sc = 1000000 + 800 - 1
                elseif m == kl1 then
                    sc = 900000
                elseif m == kl2 then
                    sc = 800000
                else
                    sc = HIST[ft] or 0
                end
            end
            SS[i] = sc
        end

        local best, best_mv, legal = -INF, 0, 0
        local old_alpha = alpha
        local U = sp.U
        for i = base + 1, n do
            local bi, bs = i, SS[i]
            for j = i + 1, n do
                if SS[j] > bs then
                    bi = j
                    bs = SS[j]
                end
            end
            local m = MS[bi]
            if bi ~= i then
                MS[bi] = MS[i]
                SS[bi] = SS[i]
                MS[i] = m
                SS[i] = bs
            end
            make(sp, m)
            if illegal(sp, m, ksq, incheck) then
                unmake(sp)
            else
                legal = legal + 1
                local quiet = U[sp.hply * US + 2] == 0 and m % FL < PR
                local s
                local skip = false
                if legal == 1 then
                    s = -search(depth - 1, -beta, -alpha, ply + 1, n, true)
                else
                    local r = 0
                    if quiet and not incheck and bs < 800000 then
                        local gives = attacked(b, sp.k1 + (sp.k2 - sp.k1) * (1 + stm) / 2, stm)
                        if not gives then
                            if depth <= 2 and not pv and static + FUT_MARGIN[depth] <= alpha and alpha > -MATE_BOUND then
                                skip = true
                            elseif depth >= 3 and legal > 3 then
                                r = 1
                                if legal > 8 and depth >= 5 then r = 2 end
                            end
                        end
                    end
                    if not skip then
                        s = -search(depth - 1 - r, -alpha - 1, -alpha, ply + 1, n, true)
                        if r > 0 and s > alpha and not stopped then
                            s = -search(depth - 1, -alpha - 1, -alpha, ply + 1, n, true)
                        end
                        if s > alpha and s < beta and not stopped then
                            s = -search(depth - 1, -beta, -alpha, ply + 1, n, true)
                        end
                    end
                end
                unmake(sp)
                if stopped then return 0 end
                if not skip and s > best then
                    best = s
                    best_mv = m
                    if s > alpha then
                        alpha = s
                        if s >= beta then
                            if quiet then
                                if kl1 ~= m then
                                    K2[ply] = kl1
                                    K1[ply] = m
                                end
                                local ft = m % 16384
                                local h = (HIST[ft] or 0) + depth * depth
                                if h > 700000 then h = 700000 end
                                HIST[ft] = h
                            end
                            break
                        end
                    end
                end
            end
        end
        if legal == 0 then
            if incheck then return -MATE + ply end
            return 0
        end
        if best == -INF then best = alpha end -- every move was futility-pruned
        local flag
        if best >= beta then
            flag = 2
        elseif best > old_alpha then
            flag = 1
        else
            flag = 3
        end
        local ts = best
        if ts > MATE_BOUND then ts = ts + ply elseif ts < -MATE_BOUND then ts = ts - ply end
        if TT_CHK[idx] ~= chk then
            TT_CHK[idx] = chk
            TT_DEPTH[idx] = depth
            TT_FLAG[idx] = flag
            TT_SCORE[idx] = ts
            TT_MOVE[idx] = best_mv
        elseif depth >= TT_DEPTH[idx] or flag == 1 then
            TT_DEPTH[idx] = depth
            TT_FLAG[idx] = flag
            TT_SCORE[idx] = ts
            if best_mv ~= 0 then TT_MOVE[idx] = best_mv end
        end
        return best
    end

    local function root(depth, alpha, beta, exact_all)
        local best, best_i = -INF, 0
        for i = 1, nroot do
            local m = RM[i]
            make(sp, m)
            local s
            if exact_all then
                s = -search(depth - 1, -INF, INF, 1, 0, true)
            elseif i == 1 then
                s = -search(depth - 1, -beta, -alpha, 1, 0, true)
            else
                s = -search(depth - 1, -alpha - 1, -alpha, 1, 0, true)
                if s > alpha and s < beta and not stopped then
                    s = -search(depth - 1, -beta, -alpha, 1, 0, true)
                end
            end
            unmake(sp)
            if stopped then break end
            RS[i] = s
            if s > best then
                best = s
                best_i = i
                if s > alpha then
                    if not exact_all then
                        alpha = s
                        iter_best = m
                        job.best_code = m
                    end
                end
            end
            if s >= beta and not exact_all then break end
        end
        return best, best_i
    end

    local function ensure_tt()
        while tt_filled < TT_SIZE do
            local last = math_min(TT_SIZE, tt_filled + 4096)
            for i = tt_filled + 1, last do
                TT_CHK[i] = -1
                TT_MOVE[i] = 0
                TT_SCORE[i] = 0
                TT_DEPTH[i] = -1
                TT_FLAG[i] = 0
            end
            tt_filled = last
            nodes = nodes + 400
            if nodes >= yield_at and tt_filled < TT_SIZE then pause() end
        end
        -- setup work must not change the search's node accounting
        yield_at = yield_at - nodes
        nodes = 0
    end

    local function root_order_score(m)
        local ft = m % 16384
        local from = ft % 128
        local to = (ft - from) / 128
        local sc = 0
        if b[to] ~= 0 then sc = 1000 + VV[b[to] + 7] - ATYPE[b[from] + 7] end
        if m - ft >= 16384 and ((m - ft) / 16384) % 8 == 5 then sc = sc + 900 end
        return sc
    end

    local function main(budget)
        yield_at = budget or 2000
        nroot = legal_codes(sp, RM)
        if nroot == 0 then return nil end
        job.best_code = RM[1]
        if nroot == 1 then return RM[1] end
        if cfg.book ~= false then
            if not BOOK then build_book() end
            local list = BOOK[sp:key()]
            if list then
                local ok = {}
                for i = 1, #list do
                    for j = 1, nroot do
                        if RM[j] == list[i] then ok[#ok + 1] = list[i] end
                    end
                end
                if #ok > 0 then
                    local pick = ok[math_floor(rng() * #ok) + 1]
                    job.best_code = pick
                    job.book = true
                    return pick
                end
            end
        end
        if cfg.rand > 0 and rng() < cfg.rand then
            local pick = RM[math_floor(rng() * nroot) + 1]
            job.best_code = pick
            job.random = true
            return pick
        end
        ensure_tt()
        tt_sid = tt_sid % 2000000 + 1
        sid_off = tt_sid * SID_MUL

        -- order root moves: captures / promotions first (stable insertion sort)
        for i = 1, nroot do RS[i] = root_order_score(RM[i]) end
        for i = 2, nroot do
            local m, s = RM[i], RS[i]
            local j = i - 1
            while j >= 1 and RS[j] < s do
                RM[j + 1] = RM[j]
                RS[j + 1] = RS[j]
                j = j - 1
            end
            RM[j + 1] = m
            RS[j + 1] = s
        end

        local best_code, best_score, completed = RM[1], 0, 0
        local soft_limit = math_floor(cfg.nodes * SOFT_FRACTION)
        for depth = 1, cfg.depth do
            iter_best = nil
            local alpha, beta = -INF, INF
            if depth >= 4 and math_abs(best_score) < MATE_BOUND then
                alpha = best_score - 40
                beta = best_score + 40
            end
            local s, bi
            while true do
                s, bi = root(depth, alpha, beta, depth == 1)
                if stopped then break end
                if s <= alpha then
                    alpha = -INF
                elseif s >= beta then
                    beta = INF
                else
                    break
                end
            end
            if stopped then
                if iter_best then best_code = iter_best end
                break
            end
            if depth == 1 then
                -- exact scores for every root move: sort them (stable) best first
                for i = 2, nroot do
                    local m, sc = RM[i], RS[i]
                    local j = i - 1
                    while j >= 1 and RS[j] < sc do
                        RM[j + 1] = RM[j]
                        RS[j + 1] = RS[j]
                        j = j - 1
                    end
                    RM[j + 1] = m
                    RS[j + 1] = sc
                end
                bi = 1
            elseif bi > 1 then
                local m, sc = RM[bi], RS[bi]
                for j = bi, 2, -1 do
                    RM[j] = RM[j - 1]
                    RS[j] = RS[j - 1]
                end
                RM[1] = m
                RS[1] = sc
            end
            best_code = RM[1]
            best_score = s
            completed = depth
            job.best_code = best_code
            job.depth = depth
            job.score = s
            enforce = true
            if nodes >= soft_limit then break end
            if math_abs(s) > MATE_BOUND and depth >= MATE - math_abs(s) + 2 then break end
            for k, v in pairs(HIST) do HIST[k] = math_floor(v / 4) end
        end

        -- Variety: choose among moves that score within `margin` of the best one.
        local margin = cfg.margin or 0
        if cfg.variety_moves and sp.full > cfg.variety_moves then margin = 0 end
        if margin > 0 and completed >= 1 and math_abs(best_score) < MATE_BOUND then
            local cands = { best_code }
            local bound = best_score - margin
            stopped = false
            enforce = true
            hard_limit = nodes + math_floor(cfg.nodes * 0.5) + 300
            for i = 1, nroot do
                local m = RM[i]
                if m ~= best_code then
                    make(sp, m)
                    local s = -search(completed - 1, -bound, -bound + 1, 1, 0, true)
                    unmake(sp)
                    if stopped then break end
                    if s >= bound then cands[#cands + 1] = m end
                end
            end
            job.candidates = #cands
            best_code = cands[math_floor(rng() * #cands) + 1]
        end
        job.nodes = nodes
        job.best_code = best_code
        return best_code
    end

    return main
end

-- Engine.search(pos, level [, opts]) -> job
--   opts: number (seed) or { seed = n, nodes = n, depth = n, book = false, rand = x, margin = x }
function Engine.search(pos, level, opts)
    level = math_floor(tonumber(level) or 5)
    if level < 1 then level = 1 elseif level > 10 then level = 10 end
    local base = LEVELS[level]
    local cfg = { depth = base.depth, nodes = base.nodes, rand = base.rand, margin = base.margin, book = true,
        variety_moves = base.variety_moves }
    local seed
    if type(opts) == "number" then
        seed = opts
    elseif type(opts) == "table" then
        seed = opts.seed
        if opts.nodes then cfg.nodes = opts.nodes end
        if opts.depth then cfg.depth = opts.depth end
        if opts.book == false then cfg.book = false end
        if opts.rand then cfg.rand = opts.rand end
        if opts.margin then
            cfg.margin = opts.margin
            cfg.variety_moves = nil
        end
    end
    seed = seed or default_seed()
    local job = setmetatable({
        level = level, limit = cfg.nodes, nodes = 0, depth = 0, score = 0,
        finished = false, result = nil, tables = {},
    }, Job)
    local sp = pos:clone()
    -- Plain move tables for every root move, built from the caller's position.
    local n = legal_codes(sp, CODE_BUF)
    for i = 1, n do
        local m = CODE_BUF[i]
        job.tables[m] = move_table(sp, m)
    end
    job.co = co_create(create_searcher(sp, cfg, new_rng(seed), job))
    return job
end

-- Advances the search by about `budget` nodes. Returns nil while thinking, then the chosen move
-- table (legal in the position given to Engine.search). Returns false if there is no legal move.
function Job:step(budget)
    if self.finished then return self.result end
    local ok, res = co_resume(self.co, budget or 2000)
    if not ok then
        -- Never leave the game without a move: fall back to the best known move.
        self.error = tostring(res)
        self.finished = true
        local t = self.best_code and self.tables[self.best_code]
        if not t then
            for _, v in pairs(self.tables) do
                t = v
                break
            end
        end
        self.result = t or false
        return self.result
    end
    if co_status(self.co) == "dead" then
        self.finished = true
        self.result = (res and self.tables[res]) or false
        return self.result
    end
    return nil
end

-- Runs the search to completion in one go (tests / non-interactive use).
function Job:run(budget)
    local mv
    repeat
        mv = self:step(budget or 100000)
    until mv ~= nil
    return mv
end

function Job:done()
    return self.finished
end

-- Approximate 0..1 (the search usually stops once it has used about 55% of its node limit).
function Job:progress()
    if self.finished then return 1 end
    local p = self.nodes / (self.limit * SOFT_FRACTION)
    if p > 0.99 then p = 0.99 end
    return p
end

function Job:best_so_far()
    if self.finished then return self.result or nil end
    return self.best_code and self.tables[self.best_code] or nil
end

---------------------------------------------------------------------------------------------------
-- Module API
---------------------------------------------------------------------------------------------------
function Engine.new(fen)
    return from_fen(fen or Engine.START_FEN)
end

Engine.square_name = square_name
Engine.parse_square = parse_square

-- Debug helper for tests: recomputes the hash from scratch and compares with the incremental one.
function Engine.verify_hash(pos)
    local h1, h2, ph = compute_hash(pos)
    return h1 == pos.h1 and h2 == pos.h2 and ph == pos.ph
end

Engine.Position = Position
Engine.Job = Job

-- Engine.set_jit_mode(mode) -> effective mode
--   "leaf" (default when LuaJIT's jit library is visible): search interpreted, leaf functions compiled.
--          Small and stable trace footprint (a few hundred traces), no trace flushes.
--   "full": everything may be compiled (hot functions are stitched). Usually ~20% faster in
--          isolation, but uses much more machine code and may trigger trace flushes in a big game.
--   "off":  the whole engine runs interpreted (no traces at all), roughly 2.5x slower.
-- Without the jit library (plain Lua 5.1, or a sandbox hiding it) the mode is always "full".
local HOT_FUNCTIONS = { gen, make, unmake, lift, shift, attacked, illegal, left_in_check, in_check,
    evaluate, pawn_eval, endgame_adjust, is_rep, insufficient, legal_codes, has_legal, list_add }
local jit_mode = "full"
function Engine.set_jit_mode(mode)
    if not JIT then
        jit_mode = "full"
        return jit_mode
    end
    if mode == "off" then
        for i = 1, #HOT_FUNCTIONS do pcall(JIT.off, HOT_FUNCTIONS[i]) end
        pcall(JIT.off, create_searcher, true)
        STITCH = STITCH_OFF
    elseif mode == "full" then
        for i = 1, #HOT_FUNCTIONS do pcall(JIT.on, HOT_FUNCTIONS[i]) end
        pcall(JIT.on, create_searcher, true)
        STITCH = STITCH_ON
    else
        mode = "leaf"
        for i = 1, #HOT_FUNCTIONS do pcall(JIT.on, HOT_FUNCTIONS[i]) end
        pcall(JIT.off, create_searcher, true)
        STITCH = STITCH_OFF
    end
    jit_mode = mode
    return jit_mode
end

function Engine.get_jit_mode()
    return jit_mode
end

Engine.set_jit_mode("leaf")

--[[ API summary
local Engine = dofile(".../BattleChess_engine.lua")
local pos = Engine.new([fen])          -- start position or FEN; returns nil, err for an invalid FEN
pos:fen() / pos:clone() / pos:piece_at(sq) -> "P".."k"|nil / pos:turn() -> "w"|"b"
pos:king_square("w"|"b") / pos:in_check() / pos:is_attacked(sq, by_color)
pos:legal_moves([out]) / pos:legal_moves_from(sq, [out])   -- fresh move tables, `out` filled + trimmed
pos:find_move(from, to, [promo])       -- promo "q"/"r"/"b"/"n"; nil = queen for promotions
pos:make_move(move) -> true|false      -- false (and no change) if the move is not legal here
pos:undo() -> move|nil / pos:history_size() / pos:last_move() / pos:history()
pos:status() -> "play"|"checkmate"|"stalemate"|"fifty"|"repetition"|"material"
pos:result() -> "1-0"|"0-1"|"1/2-1/2"|nil / pos:repetition_count() / pos:halfmove_clock()
pos:san(move) / pos:perft(depth) / pos:divide(depth) / pos:move_from_uci(s) / pos:move_from_san(s)
pos:evaluate() (centipawns, white's view) / pos:key() / pos:hash()
Engine.uci(move) / Engine.square_name(sq) / Engine.parse_square("e4") / Engine.book_moves(pos)

Move table: { from, to, piece, captured?, captured_sq?, promo?, castle? ("K"/"Q"), rook_from?, rook_to?,
              ep?, double?, id (internal move code) }

local job = Engine.search(pos, level [, seed_or_opts])   -- level 1..10; pos is copied
job:step(n) -> nil while thinking | move table when done | false when there is no legal move
job:progress() -> 0..1 / job:best_so_far() -> move|nil / job:done() / job:run([n]) (blocking)
job.depth / job.score (centipawns, side to move) / job.nodes / job.book / job.error (should stay nil)
opts: { seed = n, nodes = n, depth = n, book = false, rand = 0..1, margin = cp }
Engine.set_jit_mode("leaf"|"full"|"off") -- see the notes near the end of the file
]]

return Engine
