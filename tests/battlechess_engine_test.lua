-- Run: lua5.1 battlechess_engine_test.lua [mod_script_dir] [full|quick] [leaf|full|off]   (also under luajit)
-- "full" (default under LuaJIT, "quick" turns it off) adds perft(5) and the strength ladder.
local DIR = arg and arg[1] or "/mnt/user-data/outputs/mwg/"
if DIR:sub(-1) ~= "/" then DIR = DIR .. "/" end
local MODE = arg and arg[2]
local FULL = MODE == "full" or (rawget(_G, "jit") ~= nil and MODE ~= "quick")
local Engine = dofile(DIR .. "BattleChess_engine.lua")
-- optional 3rd argument: LuaJIT mode "leaf" (default), "full" or "off"
if arg and arg[3] then print("jit mode: " .. Engine.set_jit_mode(arg[3])) end

local passed, failed = 0, 0
local clock = os.clock

local function test(name, run)
    local t0 = clock()
    local ok, err = pcall(run)
    local dt = clock() - t0
    if ok then
        passed = passed + 1
        print(string.format("PASS: %s (%.2fs)", name, dt))
    else
        failed = failed + 1
        print("FAIL: " .. name .. ": " .. tostring(err))
    end
end

local function eq(a, b, msg)
    if a ~= b then error((msg or "values differ") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

local function truthy(v, msg)
    if not v then error(msg or "expected a true value", 2) end
end

local function sq(name) return Engine.parse_square(name) end

local function play(pos, list)
    for word in list:gmatch("%S+") do
        local mv = pos:move_from_san(word) or pos:move_from_uci(word)
        if not mv then error("illegal move in script: " .. word .. " at " .. pos:fen(), 2) end
        truthy(pos:make_move(mv), "make_move failed for " .. word)
    end
    return pos
end

local function legal_in(pos, move)
    if not move then return false end
    local moves = pos:legal_moves()
    for i = 1, #moves do
        local m = moves[i]
        if m.from == move.from and m.to == move.to and m.promo == move.promo then return true end
    end
    return false
end

-- Runs a search job to completion with a fixed per-frame budget; returns move, frames, job.
local function think(pos, level, budget, opts)
    local job = Engine.search(pos, level, opts)
    local frames = 0
    local mv
    repeat
        mv = job:step(budget or 2000)
        frames = frames + 1
        local p = job:progress()
        if p < 0 or p > 1 then error("progress out of range: " .. tostring(p)) end
        if frames > 2000000 then error("search never finished") end
    until mv ~= nil
    if job.error then error("search error: " .. job.error) end
    return mv, frames, job
end

---------------------------------------------------------------------------------------------------
-- Perft
---------------------------------------------------------------------------------------------------
local PERFT = {
    { name = "start", fen = Engine.START_FEN, counts = { 20, 400, 8902, 197281 } },
    { name = "kiwipete", fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
        counts = { 48, 2039, 97862 } },
    { name = "position 3", fen = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", counts = { 14, 191, 2812, 43238 } },
    { name = "position 4", fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
        counts = { 6, 264, 9467 } },
    { name = "position 5", fen = "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
        counts = { 44, 1486, 62379 } },
}
for _, t in ipairs(PERFT) do
    test("perft " .. t.name, function()
        local pos = assert(Engine.new(t.fen))
        for d, expected in ipairs(t.counts) do
            eq(pos:perft(d), expected, t.name .. " depth " .. d)
        end
        eq(pos:fen(), t.fen, "perft must leave the position unchanged")
    end)
end
if FULL then
    test("perft start depth 5", function()
        local pos = Engine.new()
        local t0 = clock()
        eq(pos:perft(5), 4865609, "start depth 5")
        print(string.format("      perft(5): %.2fs, %.0f nodes/s", clock() - t0, 4865609 / (clock() - t0)))
    end)
end

---------------------------------------------------------------------------------------------------
-- FEN, make/undo, hashing
---------------------------------------------------------------------------------------------------
test("FEN round trip", function()
    local fens = {
        Engine.START_FEN,
        "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
        "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2",
        "rnbqkbnr/pppp1ppp/8/8/3Pp3/8/PPP1PPPP/RNBQKBNR b Kq d3 0 3",
        "8/8/8/8/8/8/8/K6k w - - 57 99",
        "r3k3/8/8/8/8/8/8/4K2R b Kq - 12 40",
    }
    for _, f in ipairs(fens) do eq(assert(Engine.new(f)):fen(), f) end
    eq(Engine.new():fen(), Engine.START_FEN)
    -- invalid FENs are rejected
    truthy(Engine.new("8/8/8/8/8/8/8/8 w - - 0 1") == nil, "no kings")
    truthy(Engine.new("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP w KQkq - 0 1") == nil, "missing rank")
    truthy(Engine.new("k7/8/8/8/8/8/8/K6Q w - - 0 1") == nil, "side not to move in check")
end)

test("basic queries", function()
    local pos = Engine.new()
    eq(pos:piece_at(sq("e1")), "K")
    eq(pos:piece_at(sq("d8")), "q")
    eq(pos:piece_at(sq("e4")), nil)
    eq(pos:turn(), "w")
    eq(pos:king_square("w"), sq("e1"))
    eq(pos:king_square("b"), sq("e8"))
    eq(pos:in_check(), false)
    eq(pos:status(), "play")
    eq(pos:history_size(), 0)
    eq(pos:last_move(), nil)
    eq(pos:undo(), nil)
    local out = { 1, 2, 3 }
    for i = 1, 40 do out[i] = i end
    local moves = pos:legal_moves(out)
    truthy(moves == out, "fills the given table")
    eq(#out, 20, "trimmed")
    eq(#pos:legal_moves_from(sq("g1")), 2)
    eq(#pos:legal_moves_from(sq("e2")), 2)
    eq(#pos:legal_moves_from(sq("e1")), 0)
    eq(#pos:legal_moves_from(sq("e4")), 0)
end)

test("move tables: double push, en passant, castling, promotion", function()
    local pos = Engine.new()
    local mv = pos:find_move(sq("e2"), sq("e4"))
    eq(mv.piece, "P")
    eq(mv.double, true)
    eq(mv.captured, nil)
    play(pos, "e4 a6 e5 d5")
    local ep = pos:find_move(sq("e5"), sq("d6"))
    eq(ep.ep, true)
    eq(ep.captured, "p")
    eq(ep.captured_sq, sq("d5"))
    eq(ep.to, sq("d6"))
    truthy(pos:make_move(ep))
    eq(pos:piece_at(sq("d5")), nil)
    eq(pos:piece_at(sq("d6")), "P")
    eq(pos:last_move().ep, true)
    pos:undo()
    eq(pos:piece_at(sq("d5")), "p")

    local c = Engine.new("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
    local k = c:find_move(sq("e1"), sq("g1"))
    eq(k.castle, "K")
    eq(k.rook_from, sq("h1"))
    eq(k.rook_to, sq("f1"))
    local q = c:find_move(sq("e1"), sq("c1"))
    eq(q.castle, "Q")
    eq(q.rook_from, sq("a1"))
    eq(q.rook_to, sq("d1"))
    c:make_move(q)
    eq(c:piece_at(sq("d1")), "R")
    eq(c:piece_at(sq("c1")), "K")
    eq(c:fen(), "r3k2r/8/8/8/8/8/8/2KR3R b kq - 1 1")
    local bk = c:find_move(sq("e8"), sq("g8"))
    eq(bk.castle, "K")
    eq(bk.rook_from, sq("h8"))
    eq(bk.rook_to, sq("f8"))

    local p = Engine.new("1n5k/P7/8/8/8/8/8/K7 w - - 0 1")
    local dq = p:find_move(sq("a7"), sq("a8"))
    eq(dq.promo, "Q", "nil promo defaults to queen")
    local dn = p:find_move(sq("a7"), sq("a8"), "n")
    eq(dn.promo, "N")
    local cx = p:find_move(sq("a7"), sq("b8"), "r")
    eq(cx.promo, "R")
    eq(cx.captured, "n")
    eq(p:find_move(sq("a7"), sq("a8"), "k"), nil)
    eq(p:find_move(sq("a1"), sq("a3")), nil)
    eq(#p:legal_moves_from(sq("a7")), 8)
    p:make_move(dn)
    eq(p:piece_at(sq("a8")), "N")
    p:undo()
    eq(p:piece_at(sq("a7")), "P")
    local bp = Engine.new("k7/8/8/8/8/8/p7/7K b - - 0 1")
    eq(bp:find_move(sq("a2"), sq("a1")).promo, "q")
    -- illegal moves are refused and leave the position unchanged
    local s = Engine.new()
    local f = s:fen()
    eq(s:make_move({ from = sq("e2"), to = sq("e5") }), false)
    eq(s:fen(), f)
    -- a plain {from, to} table works too
    eq(s:make_move({ from = sq("g1"), to = sq("f3") }), true)
end)

test("random games: undo restores FEN and hash exactly, incremental hash is correct", function()
    local seed = 12345
    local function rnd(n)
        seed = (seed * 16807) % 2147483647
        return seed % n + 1
    end
    for game = 1, 30 do
        local pos = Engine.new()
        local fens, keys = {}, {}
        local plies = 0
        for ply = 1, 200 do
            fens[ply] = pos:fen()
            keys[ply] = pos:key()
            truthy(Engine.verify_hash(pos), "hash mismatch at ply " .. ply)
            if pos:status() ~= "play" then break end
            local moves = pos:legal_moves()
            local mv = moves[rnd(#moves)]
            truthy(pos:make_move(mv))
            plies = plies + 1
            eq(pos:history_size(), plies)
            eq(pos:last_move(), mv)
            -- clone must be independent and carry the repetition history
            if ply % 37 == 0 then
                local c = pos:clone()
                eq(c:fen(), pos:fen())
                eq(c:key(), pos:key())
                eq(c:history_size(), pos:history_size())
                local cm = c:legal_moves()
                if #cm > 0 then c:make_move(cm[1]) end
                eq(pos:fen(), fens[ply] and pos:fen())
            end
        end
        for ply = plies, 1, -1 do
            truthy(pos:undo())
            eq(pos:fen(), fens[ply], "fen after undo")
            eq(pos:key(), keys[ply], "hash after undo")
        end
        eq(pos:history_size(), 0)
        eq(game > 0, true)
    end
end)

test("hash: transpositions match, side/castling/en passant distinguished", function()
    local a = play(Engine.new(), "Nf3 Nf6 Nc3 Nc6")
    local b = play(Engine.new(), "Nc3 Nc6 Nf3 Nf6")
    eq(a:key(), b:key())
    local c = play(Engine.new(), "e4")
    local d = Engine.new("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1")
    eq(c:key(), d:key(), "ep square without a capturing pawn does not change the key")
    local e = Engine.new("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1")
    truthy(e:key() ~= d:key(), "side to move")
    local f = Engine.new("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b Qkq - 0 1")
    truthy(f:key() ~= d:key(), "castling rights")
    local g = play(Engine.new("rnbqkbnr/ppp1pppp/8/8/3p4/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"), "e4")
    local h = Engine.new("rnbqkbnr/ppp1pppp/8/8/3pP3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1")
    truthy(g:key() ~= h:key(), "capturable en passant square changes the key")
end)

---------------------------------------------------------------------------------------------------
-- Status
---------------------------------------------------------------------------------------------------
test("status: checkmate, stalemate", function()
    local pos = play(Engine.new(), "f3 e5 g4 Qh4")
    eq(pos:status(), "checkmate")
    eq(pos:in_check(), true)
    eq(pos:result(), "0-1")
    eq(#pos:legal_moves(), 0)
    local st = Engine.new("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
    eq(st:status(), "stalemate")
    eq(st:in_check(), false)
    eq(st:result(), "1/2-1/2")
    local sm = play(Engine.new(), "e4 e5 Bc4 Nc6 Qh5 Nf6 Qxf7")
    eq(sm:status(), "checkmate")
    eq(sm:result(), "1-0")
end)

test("status: fifty-move rule (mate on the last move wins)", function()
    local pos = Engine.new("8/8/4k3/8/8/3K4/8/7R w - - 99 80")
    eq(pos:status(), "play")
    play(pos, "Rh2")
    eq(pos:status(), "fifty")
    pos:undo()
    play(pos, "Kd4")
    eq(pos:status(), "fifty")
    local mate = Engine.new("7k/8/6K1/8/8/8/8/R7 w - - 99 80")
    play(mate, "Ra8")
    eq(mate:status(), "checkmate", "checkmate beats the fifty-move rule")
    local reset = Engine.new("8/8/4k3/8/8/3K4/4P3/7R w - - 99 80")
    play(reset, "e4")
    eq(reset:status(), "play", "pawn move resets the clock")
end)

test("status: threefold repetition", function()
    local pos = Engine.new()
    play(pos, "Nf3 Nf6 Ng1 Ng8")
    eq(pos:status(), "play")
    eq(pos:repetition_count(), 2)
    play(pos, "Nf3 Nf6 Ng1")
    eq(pos:status(), "play")
    play(pos, "Ng8")
    eq(pos:repetition_count(), 3)
    eq(pos:status(), "repetition")
    pos:undo()
    eq(pos:status(), "play")
    -- lost castling rights make positions different
    local c = Engine.new("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
    play(c, "Kf1 Kf8 Ke1 Ke8 Kf1 Kf8 Ke1 Ke8")
    eq(c:repetition_count(), 2, "first position had castling rights")
    eq(c:status(), "play")
    play(c, "Kf1 Kf8 Ke1 Ke8")
    eq(c:status(), "repetition")
end)

test("status: insufficient material", function()
    local cases = {
        { "8/8/4k3/8/8/3K4/8/8 w - - 0 1", "material" }, -- K v K
        { "8/8/4k3/8/8/3K4/8/5B2 w - - 0 1", "material" }, -- KB v K
        { "8/8/4k3/8/8/3K4/8/5N2 b - - 0 1", "material" }, -- KN v K
        { "8/8/4k3/8/2b5/3K4/8/5B2 w - - 0 1", "material" }, -- KB v KB, both on light squares
        { "8/2b5/4k3/8/8/3K4/7B/2B5 w - - 0 1", "material" }, -- bishops all on dark squares
        { "8/8/4k3/2b5/8/3K4/8/5B2 w - - 0 1", "play" }, -- KB v KB, opposite colours
        { "8/8/4k3/8/8/3K4/8/4NN2 w - - 0 1", "play" }, -- KNN v K
        { "8/8/4k3/8/8/3K4/8/4NB2 w - - 0 1", "play" }, -- KBN v K
        { "8/8/4k3/8/8/3K4/4P3/8 w - - 0 1", "play" }, -- KP v K
        { "8/8/4k3/8/8/3K4/8/5R2 w - - 0 1", "play" }, -- KR v K
        { "8/8/4k3/8/8/3K4/5n2/5N2 w - - 0 1", "play" }, -- KN v KN
    }
    for _, c in ipairs(cases) do
        eq(assert(Engine.new(c[1])):status(), c[2], c[1])
    end
    -- reached by a capture
    local pos = Engine.new("8/8/4k3/8/8/3K4/8/3nB3 w - - 0 1")
    play(pos, "Bd2 Nc3 Bh6")
    eq(pos:status(), "play")
    local pos2 = Engine.new("8/8/8/4k3/8/3K4/4r3/4B3 w - - 0 1")
    play(pos2, "Kxe2")
    eq(pos2:status(), "material")
end)

---------------------------------------------------------------------------------------------------
-- SAN
---------------------------------------------------------------------------------------------------
test("SAN strings", function()
    local pos = Engine.new()
    eq(pos:san(pos:find_move(sq("g1"), sq("f3"))), "Nf3")
    eq(pos:san(pos:find_move(sq("e2"), sq("e4"))), "e4")
    play(pos, "e4 d5")
    eq(pos:san(pos:find_move(sq("e4"), sq("d5"))), "exd5")
    -- file disambiguation: knights b1 and f3 can both reach d2
    local d = Engine.new("4k3/8/8/8/8/5N2/8/1N2K3 w - - 0 1")
    eq(d:san(d:find_move(sq("b1"), sq("d2"))), "Nbd2")
    eq(d:san(d:find_move(sq("f3"), sq("d2"))), "Nfd2")
    -- rank disambiguation: rooks a1 and a5 both reach a3
    local r = Engine.new("4k3/8/8/R7/8/8/8/R3K3 w - - 0 1")
    eq(r:san(r:find_move(sq("a1"), sq("a3"))), "R1a3")
    eq(r:san(r:find_move(sq("a5"), sq("a3"))), "R5a3")
    -- full square disambiguation: queens on e4, h4 and h1 reach e1
    local q = Engine.new("8/8/k7/8/4Q2Q/8/8/1K5Q w - - 0 1")
    eq(q:san(q:find_move(sq("h4"), sq("e1"))), "Qh4e1")
    eq(q:san(q:find_move(sq("e4"), sq("e1"))), "Qee1")
    eq(q:san(q:find_move(sq("h1"), sq("e1"))), "Q1e1")
    -- a pinned piece does not cause disambiguation
    local pin = Engine.new("4k3/8/8/8/8/2N3N1/8/4K3 w - - 0 1")
    eq(pin:san(pin:find_move(sq("g3"), sq("e2"))), "Nge2")
    local pin2 = Engine.new("4k3/8/8/b7/8/2N5/8/4K1N1 w - - 0 1")
    eq(pin2:san(pin2:find_move(sq("g1"), sq("e2"))), "Ne2")
    -- promotions, capture-promotions, checks and mates
    local pr = Engine.new("1n5k/P7/8/8/8/8/8/K7 w - - 0 1")
    eq(pr:san(pr:find_move(sq("a7"), sq("a8"))), "a8=Q")
    eq(pr:san(pr:find_move(sq("a7"), sq("a8"), "n")), "a8=N")
    eq(pr:san(pr:find_move(sq("a7"), sq("b8"), "r")), "axb8=R+")
    -- castling
    local c = Engine.new("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
    eq(c:san(c:find_move(sq("e1"), sq("g1"))), "O-O")
    eq(c:san(c:find_move(sq("e1"), sq("c1"))), "O-O-O")
    local cc = Engine.new("5k2/8/8/8/8/8/8/4K2R w K - 0 1")
    eq(cc:san(cc:find_move(sq("e1"), sq("g1"))), "O-O+")
    -- en passant
    local e = Engine.new("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2")
    eq(e:san(e:find_move(sq("e5"), sq("d6"))), "exd6")
    -- mate
    local m = Engine.new("6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1")
    eq(m:san(m:find_move(sq("d1"), sq("d8"))), "Rd8#")
    local fm = play(Engine.new(), "f3 e5 g4")
    eq(fm:san(fm:find_move(sq("d8"), sq("h4"))), "Qh4#")
    -- SAN parsing round trip over all moves of a busy position
    local k = Engine.new("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
    local moves = k:legal_moves()
    local seen = {}
    for i = 1, #moves do
        local s = k:san(moves[i])
        truthy(not seen[s], "SAN must be unique: " .. s)
        seen[s] = true
        local back = k:move_from_san(s)
        eq(back and back.id, moves[i].id, "SAN parse " .. s)
    end
end)

---------------------------------------------------------------------------------------------------
-- Opening book
---------------------------------------------------------------------------------------------------
test("opening book lines are legal", function()
    eq(Engine.book_errors(), 0)
    local start = Engine.book_moves(Engine.new())
    truthy(#start >= 3, "several first moves")
    local after = Engine.book_moves(play(Engine.new(), "e4 e5 Nf3"))
    truthy(#after >= 1)
    eq(#Engine.book_moves(Engine.new("8/8/4k3/8/8/3K4/4P3/8 w - - 0 1")), 0)
end)

---------------------------------------------------------------------------------------------------
-- AI
---------------------------------------------------------------------------------------------------
-- Does the side to move force mate within n moves (full-width check, used to validate engine moves)?
local function forces_mate(pos, n)
    local moves = pos:legal_moves()
    for i = 1, #moves do
        pos:make_move(moves[i])
        local st = pos:status()
        local ok = false
        if st == "checkmate" then
            ok = true
        elseif st == "play" and n > 1 then
            ok = true
            local replies = pos:legal_moves()
            for j = 1, #replies do
                pos:make_move(replies[j])
                local sub = forces_mate(pos, n - 1)
                pos:undo()
                if not sub then
                    ok = false
                    break
                end
            end
        end
        pos:undo()
        if ok then return true, moves[i] end
    end
    return false
end

local function mates_after(pos, mv, n)
    pos:make_move(mv)
    local st = pos:status()
    local ok
    if st == "checkmate" then
        ok = true
    elseif st ~= "play" or n <= 1 then
        ok = false
    else
        ok = true
        local replies = pos:legal_moves()
        for j = 1, #replies do
            pos:make_move(replies[j])
            if not forces_mate(pos, n - 1) then ok = false end
            pos:undo()
            if not ok then break end
        end
    end
    pos:undo()
    return ok
end

test("AI: mate in 1 at levels 5..10", function()
    local fens = {
        "6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1",
        "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4",
        "3k4/8/3K4/8/8/8/8/7R w - - 0 1",
        "rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq - 0 2",
    }
    for level = 5, 10 do
        for _, f in ipairs(fens) do
            local pos = Engine.new(f)
            local mv = think(pos, level, 2000, { seed = level })
            pos:make_move(mv)
            eq(pos:status(), "checkmate", "level " .. level .. " " .. f)
        end
    end
end)

test("AI: mate in 2 at levels 5..10", function()
    local fens = {
        -- Legal-style: Nf6+ gxf6 Bxf7#
        "r2qkb1r/pp2nppp/3p4/2pNN1B1/2BnP3/3P4/PPP2PPP/R2bK2R w KQkq - 1 1",
        -- queen sacrifice: Qd8+ Bxd8 Re8#
        "r1b2k1r/ppp1bppp/8/1B1Q4/5q2/2P5/PPP2PPP/R3R1K1 w - - 1 1",
        -- rook ladder
        "7k/8/8/8/8/8/R7/1R4K1 w - - 0 1",
    }
    for _, f in ipairs(fens) do
        local pos = Engine.new(f)
        truthy(not forces_mate(pos, 1), "test position must not have a mate in 1: " .. f)
        truthy(forces_mate(pos, 2), "test position must have a mate in 2: " .. f)
    end
    for level = 5, 10 do
        for _, f in ipairs(fens) do
            local pos = Engine.new(f)
            local mv, _, job = think(pos, level, 2000, { seed = 7 })
            truthy(mates_after(pos, mv, 2), "level " .. level .. " chose " .. pos:san(mv) .. " in " .. f)
            truthy(job.score > 29000, "mate score reported")
        end
    end
end)

test("AI: takes a hanging queen, avoids hanging its own", function()
    local pos = Engine.new("rnb1kbnr/pppp1ppp/8/8/3q4/2N2N2/PPPPPPPP/R1BQKB1R w KQkq - 0 1")
    for level = 4, 10 do
        local mv = think(pos, level, 2000, { seed = 3 })
        eq(pos:san(mv), "Nxd4", "level " .. level)
    end
    -- black to move, queen attacked by a pawn: must move it (or trade it) rather than lose it
    local p2 = Engine.new("rnb1kbnr/pppp1ppp/8/4q3/3P4/2N5/PPP1PPPP/R1BQKBNR b KQkq - 0 3")
    for level = 5, 10 do
        local mv = think(p2, level, 2000, { seed = 3 })
        eq(mv.from, sq("e5"), "level " .. level .. " must save the queen, played " .. p2:san(mv))
    end
end)

test("AI: time-sliced job is deterministic for any budget", function()
    local fens = {
        "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
        "r1bq1rk1/ppp2ppp/2np1n2/2b1p3/2B1P3/2PP1N2/PP3PPP/RNBQ1RK1 w - - 0 7",
    }
    for _, f in ipairs(fens) do
        for _, level in ipairs({ 3, 6, 8 }) do
            local ref, ref_nodes
            for _, budget in ipairs({ 7, 97, 2000, 1000000 }) do
                local pos = Engine.new(f)
                local mv, _, job = think(pos, level, budget, { seed = 99 })
                truthy(legal_in(pos, mv), "legal")
                eq(pos:fen(), f, "search must not change the caller's position")
                if ref then
                    eq(mv.id, ref.id, "same move for budget " .. budget .. " level " .. level)
                    eq(job.nodes, ref_nodes, "same node count")
                else
                    ref, ref_nodes = mv, job.nodes
                end
            end
        end
    end
end)

test("AI: job API (progress, best_so_far, repeated step, no-move positions)", function()
    local pos = Engine.new("r1bq1rk1/ppp2ppp/2np1n2/2b1p3/2B1P3/2PP1N2/PP3PPP/RNBQ1RK1 w - - 0 7")
    local job = Engine.search(pos, 7, { seed = 1 })
    eq(job:progress(), 0)
    local mv = job:step(500)
    eq(mv, nil, "still thinking after 500 nodes")
    local last = 0
    local seen_best = false
    repeat
        mv = job:step(1500)
        local p = job:progress()
        truthy(p >= 0 and p <= 1)
        if job:best_so_far() then
            seen_best = true
            truthy(legal_in(pos, job:best_so_far()))
        end
        last = p
    until mv
    truthy(seen_best, "best_so_far available while thinking")
    eq(job:progress(), 1)
    eq(job:step(10), mv, "further steps return the same move")
    eq(job:best_so_far(), mv)
    truthy(job:done())
    -- position keeps working while a job runs: caller may mutate its own position
    local p2 = Engine.new()
    local j2 = Engine.search(p2, 6, { seed = 5, book = false })
    j2:step(100)
    play(p2, "e4 e5")
    local m2 = j2:run(3000)
    truthy(legal_in(Engine.new(), m2), "move is legal in the position given to search")
    -- no legal moves: step returns false (never nil forever)
    local mated = play(Engine.new(), "f3 e5 g4 Qh4")
    local j3 = Engine.search(mated, 5)
    eq(j3:step(2000), false)
    eq(j3:progress(), 1)
    -- a single legal reply is returned immediately
    local forced = Engine.new("k7/8/8/8/8/8/1r6/K1r5 w - - 0 1")
    local j4 = Engine.search(forced, 10)
    local m4 = j4:step(1)
    truthy(m4 and m4.to == sq("b2"), "only move Kxb2")
end)

test("AI: understands draws (repetition / fifty)", function()
    -- white is lost on material; repeating the position to claim a draw is best
    local pos = Engine.new("6k1/6pp/8/8/8/8/q7/5QK1 w - - 0 1")
    local mv = think(pos, 8, 2000, { seed = 1 })
    truthy(legal_in(pos, mv))
    -- black, a queen up, must not complete a threefold repetition
    local p = Engine.new("kq6/8/8/8/8/8/8/7K w - - 0 1")
    play(p, "Kg1 Ka7 Kh1 Ka8 Kg1 Ka7 Kh1")
    eq(p:repetition_count(), 2)
    local m = think(p, 7, 2000, { seed = 1 })
    p:make_move(m)
    truthy(p:status() ~= "repetition", "avoids repetition when winning, played " .. Engine.uci(m))
    -- and a side with nothing better takes the fifty-move draw / never errors near it
    local f = Engine.new("8/8/4k3/8/8/3K4/8/7R b - - 98 80")
    local fm = think(f, 6, 2000, { seed = 1 })
    truthy(legal_in(f, fm))
end)

test("AI: converts KQ v K and KR v K before the fifty-move rule", function()
    for _, c in ipairs({ { "8/8/8/4k3/8/8/8/3QK3 w - - 0 1", 6 }, { "8/8/8/4k3/8/8/8/4K2R w - - 0 1", 8 } }) do
        local pos = Engine.new(c[1])
        local plies = 0
        while pos:status() == "play" and plies < 150 do
            local level = pos:turn() == "w" and c[2] or 4
            pos:make_move(think(pos, level, 100000, { seed = plies }))
            plies = plies + 1
        end
        eq(pos:status(), "checkmate", c[1] .. " at level " .. c[2])
        print(string.format("      %s: mate after %d plies at level %d", c[1], plies, c[2]))
    end
end)

test("AI: levels 1..10 return legal moves (frames at 2000 nodes/frame)", function()
    local fens = {
        Engine.START_FEN,
        "r1bq1rk1/ppp2ppp/2np1n2/2b1p3/2B1P3/2PP1N2/PP3PPP/RNBQ1RK1 w - - 0 7",
        "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
        "8/5pk1/6p1/8/3K4/8/5PP1/8 w - - 0 1",
    }
    local rows = {}
    for level = 1, 10 do
        local total_frames, total_nodes, max_frames, t0 = 0, 0, 0, clock()
        for i, f in ipairs(fens) do
            local pos = Engine.new(f)
            local mv, frames, job = think(pos, level, 2000, { seed = level * 10 + i, book = false })
            truthy(legal_in(pos, mv), "level " .. level)
            total_frames = total_frames + frames
            total_nodes = total_nodes + (job.nodes or 0)
            if frames > max_frames then max_frames = frames end
        end
        local dt = clock() - t0
        rows[#rows + 1] = string.format(
            "      level %2d: avg %6.0f nodes = %4.0f frames at N=1000, %4.0f at N=2000 (max %4d); %.3fs CPU/move",
            level, total_nodes / #fens, total_nodes / #fens / 1000, total_frames / #fens, max_frames, dt / #fens)
    end
    for _, r in ipairs(rows) do print(r) end
end)

-- Plays a game between two levels; returns "1-0", "0-1" or "1/2-1/2" (adjudicated as a draw after
-- max_plies) and the number of plies.
local function play_game(white_level, black_level, seed, max_plies, opening)
    local pos = Engine.new()
    if opening then play(pos, opening) end
    local plies = 0
    while pos:status() == "play" and plies < (max_plies or 400) do
        local level = pos:turn() == "w" and white_level or black_level
        local mv = think(pos, level, 50000, { seed = seed + plies })
        truthy(legal_in(pos, mv), "engine move must be legal")
        truthy(pos:make_move(mv))
        plies = plies + 1
    end
    return pos:result() or "1/2-1/2", plies, pos:status()
end

test("AI: engine-vs-engine games at low levels play to completion", function()
    local finished = 0
    for g = 1, 4 do
        local lw, lb = ({ 1, 2, 1, 3 })[g], ({ 1, 1, 3, 2 })[g]
        local res, plies, st = play_game(lw, lb, g * 1000, 2000)
        print(string.format("      L%d vs L%d: %s after %d plies (%s)", lw, lb, res, plies, st))
        truthy(st ~= "play", "game must reach a final status")
        finished = finished + 1
    end
    eq(finished, 4)
end)

if FULL then
    test("AI: strength ladder", function()
        local openings = { "e4 e5", "d4 d5", "e4 c5", "c4 e5", "Nf3 d5", "e4 e6" }
        local function match(high, low, games)
            local score = 0
            for g = 1, games do
                local op = openings[(g - 1) % #openings + 1]
                local white_high = g % 2 == 1
                local res, plies = play_game(white_high and high or low, white_high and low or high, g * 7919, 300, op)
                local s
                if res == "1/2-1/2" then
                    s = 0.5
                elseif (res == "1-0") == white_high then
                    s = 1
                else
                    s = 0
                end
                score = score + s
                print(string.format("      L%d vs L%d game %d (%s, L%d white): %s in %d plies", high, low, g, op,
                    white_high and high or low, res, plies))
            end
            print(string.format("      L%d scored %.1f / %d against L%d", high, score, games, low))
            return score
        end
        local s83 = match(8, 3, 6)
        truthy(s83 >= 5, "level 8 must beat level 3 clearly")
        local s51 = match(5, 1, 4)
        truthy(s51 >= 3.5, "level 5 must beat level 1 clearly")
    end)
end

test("performance: nodes/second and per-step time at 2000 nodes", function()
    local fens = {
        "r1bq1rk1/ppp2ppp/2np1n2/2b1p3/2B1P3/2PP1N2/PP3PPP/RNBQ1RK1 w - - 0 7",
        "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
    }
    local nodes, time, steps, worst = 0, 0, 0, 0
    local times = {}
    for _, f in ipairs(fens) do
        local job = Engine.search(Engine.new(f), 9, { seed = 1, book = false })
        local mv
        repeat
            local t0 = clock()
            mv = job:step(2000)
            local dt = clock() - t0
            time = time + dt
            steps = steps + 1
            times[#times + 1] = dt
            if dt > worst then worst = dt end
        until mv
        nodes = nodes + job.nodes
    end
    table.sort(times)
    print(string.format("      %d nodes in %.2fs = %.0f nodes/s; per step(2000): median %.2f ms, p95 %.2f ms, max %.2f ms",
        nodes, time, nodes / time, times[math.floor(#times / 2) + 1] * 1000,
        times[math.floor(#times * 0.95) + 1] * 1000, worst * 1000))
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
