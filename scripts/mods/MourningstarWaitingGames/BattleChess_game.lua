-- Battle Chess: a tribute to the 1988 classic with medieval characters on a real 3D board.
-- Pure logic: turn flow, selection, the computer player (time sliced), camera state and picking, the
-- choreography of walks and battles, menus and dialogs. The view renders and forwards input.
local mod = get_mod("MourningstarWaitingGames")
local PATH = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/"
local Win95 = mod:io_dofile(PATH .. "MourningstarWaitingGames_win95")
local Engine = mod:io_dofile(PATH .. "BattleChess_engine")
local D3 = mod:io_dofile(PATH .. "BattleChess_3d")
local Figures = mod:io_dofile(PATH .. "BattleChess_figures")

local math_abs = math.abs
local math_atan2 = math.atan2
local math_cos = math.cos
local math_exp = math.exp
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_sin = math.sin
local math_sqrt = math.sqrt

local CLIENT_W, CLIENT_H = 560, 440
-- The flat 2D board (View > 2D Board) and the side panel next to it.
local BOARD2D_SIZE = 416
local BOARD2D_MARGIN = 12
-- Search nodes per frame: fewer while figures are animating so the frame stays light.
local NODES_PER_UPDATE = 800
local NODES_WHILE_ANIMATING = 400
local PITCH_MIN, PITCH_MAX = 0.35, 1.31
local DIST_MIN, DIST_MAX = 7, 20
local DEFAULT_PITCH, DEFAULT_DIST = 0.7, 14.2
local WALK_SPEED = { p = 2.3, n = 2.3, b = 2.2, r = 1.55, q = 2.4, k = 2.0 }
local PRESETS = {
    { id = "cam_white", label = "White Side", yaw = 0, pitch = DEFAULT_PITCH, dist = DEFAULT_DIST },
    { id = "cam_black", label = "Black Side", yaw = math_pi, pitch = DEFAULT_PITCH, dist = DEFAULT_DIST },
    { id = "cam_over", label = "Overview", yaw = 0, pitch = 1.3, dist = 15.5 },
    { id = "cam_side", label = "Side View", yaw = math_pi * 0.5, pitch = 0.6, dist = 14 },
}
local PROMO_NAMES = { q = "Queen", r = "Rook", b = "Bishop", n = "Knight" }
local SIDE_NAMES = { w = "White", b = "Black" }

local clamp = Win95.clamp

local BattleChessGame = {}
BattleChessGame.__index = BattleChessGame

local function sq_xz(sq)
    return sq % 8 - 3.5, math_floor(sq / 8) - 3.5
end

local function side_of(piece)
    return piece:upper() == piece and "w" or "b"
end

local function facing_yaw(side)
    return side == "w" and 0 or math_pi
end

local function yaw_to(x0, z0, x1, z1)
    return math_atan2(x1 - x0, z1 - z0)
end

BattleChessGame.sq_xz = sq_xz

-- options: get(key), set(key, value), on_sound(kind)
function BattleChessGame:new(options)
    local game = setmetatable({}, BattleChessGame)
    game._options = options or {}
    game._events = {}
    game._event_count = 0
    game._held = {}
    game._close_requested = false
    game._time = 0
    game._pointer_x, game._pointer_y = -1, -1
    game._next_id = 0
    game._scratch_moves = {}
    game._scratch_pose = Figures.new_pose()

    local get = game._options.get
    local function opt(key, default)
        local v = get and get(key)
        if v == nil then return default end
        return v
    end
    game._level = clamp(math_floor(tonumber(opt("battlechess_level", 3)) or 3), 1, 10)
    game._anims = opt("battlechess_anims", true) and true or false
    game._play_black = opt("battlechess_black", false) and true or false
    game._two_players = opt("battlechess_two", false) and true or false
    game._wins = tonumber(opt("battlechess_highscore", 0)) or 0
    game._board2d = opt("battlechess_2d", false) and true or false
    game._flip2d = false

    local function three_d() return not game._board2d end
    game._shell = Win95.shell({
        client_w = CLIENT_W,
        client_h = CLIENT_H,
        status = true,
        menus = {
            { id = "game", label = "Game", width = 176, items = {
                { id = "new", label = "New Game", key = "R" },
                { id = "undo", label = "Undo", key = "Q", enabled = function() return game:can_undo() end },
                { separator = true },
                { id = "exit", label = "Exit", key = "Esc" },
            } },
            { id = "view", label = "View", width = 186, items = {
                { id = "board3d", label = "3D Board", radio = true, check = function() return not game._board2d end },
                { id = "board2d", label = "2D Board", radio = true, check = function() return game._board2d end },
                { separator = true },
                { id = "cycle_view", label = "Next View", key = "E", enabled = three_d },
                { separator = true },
                { id = "cam_white", label = "White Side", enabled = three_d },
                { id = "cam_black", label = "Black Side", enabled = three_d },
                { id = "cam_over", label = "Overview", enabled = three_d },
                { id = "cam_side", label = "Side View", enabled = three_d },
                { separator = true },
                { id = "zoom_in", label = "Zoom In", key = "1", enabled = three_d },
                { id = "zoom_out", label = "Zoom Out", key = "2", enabled = three_d },
                { id = "rotate", label = "Rotate Board", key = "3" },
                { id = "reset_camera", label = "Reset Camera", key = "4", enabled = three_d },
            } },
            { id = "options", label = "Options", width = 196, items = {
                { id = "difficulty", label = "Difficulty..." },
                { id = "anims", label = "Battle Animations", check = function() return game._anims end },
                { id = "black", label = "Play as Black", check = function() return game._play_black end },
                { id = "two", label = "Two Players", check = function() return game._two_players end },
                { separator = true },
                { id = "reset_camera", label = "Reset Camera", enabled = three_d },
            } },
            { id = "help", label = "Help", width = 196, items = {
                { id = "how_to", label = "How to Play..." },
                { separator = true },
                { id = "about", label = "About Battle Chess..." },
            } },
        },
        on_command = function(id) game:_command(id) end,
        on_dialog = function(dialog, id) return game:_dialog_button(dialog, id) end,
    })
    game._layout = { client = game._shell:layout().client }
    local c = game._layout.client
    game._layout.board2d = { x = c.x + BOARD2D_MARGIN, y = c.y + math_floor((c.h - BOARD2D_SIZE) * 0.5), size = BOARD2D_SIZE, sq = BOARD2D_SIZE / 8 }
    game._layout.panel2d = { x = c.x + BOARD2D_MARGIN * 2 + BOARD2D_SIZE, y = c.y + BOARD2D_MARGIN, w = c.w - BOARD2D_MARGIN * 3 - BOARD2D_SIZE, h = c.h - BOARD2D_MARGIN * 2 }

    local client = game._layout.client
    game._cam = D3.camera()
    game._cam:set_viewport(client.x, client.y, client.w, client.h)
    game._user = { yaw = 0, pitch = DEFAULT_PITCH, dist = DEFAULT_DIST }
    game._cam_goal = nil
    game._cam_slow = 0
    game:_snap_camera()

    game._segments = { { text = "", w = 262 }, { text = "", w = 150 }, { text = "" } }
    return game
end

function BattleChessGame:start()
    self:new_game()
end

function BattleChessGame:_persist(key, value)
    local set = self._options.set
    if set then set(key, value) end
end

function BattleChessGame:_sound(kind)
    local on_sound = self._options.on_sound
    if on_sound then on_sound(kind) end
end

-- Events for the view: kind plus up to seven numbers and a string.
function BattleChessGame:_event(kind, a, b, c, d, e, f, s)
    local n = self._event_count + 1
    local ev = self._events[n]
    if not ev then
        ev = {}
        self._events[n] = ev
    end
    ev.kind, ev.a, ev.b, ev.c, ev.d, ev.e, ev.f, ev.s = kind, a, b, c, d, e, f, s
    self._event_count = n
end

function BattleChessGame:drain_events(callback)
    for i = 1, self._event_count do
        callback(self._events[i])
    end
    self._event_count = 0
end

-- Game flow ----------------------------------------------------------------------------------------------

function BattleChessGame:human_side()
    return self._play_black and "b" or "w"
end

function BattleChessGame:is_human_turn()
    if self._two_players then return true end
    return self._pos:turn() == self:human_side()
end

function BattleChessGame:new_game()
    self._shell:close_dialog()
    self._pos = Engine.new()
    self._job = nil
    self._ai_move = nil
    self._seq = nil
    self._over = nil
    self._result = nil
    self._selected = nil
    self._targets = {}
    self._target_count = 0
    self._last = nil
    self._last_san = ""
    self._battle = nil
    self._cursor = self._play_black and 51 or 12
    self._cursor_visible = false
    self._hover = nil
    self._message = nil
    self._actors = {}
    self._at = {}
    self:_sync_actors()
    local preset = self._play_black and PRESETS[2] or PRESETS[1]
    self:set_camera_preset(preset.id)
    self._cam_goal = nil
    self:_event("new")
    self:_maybe_think()
end

function BattleChessGame:_new_actor(piece, sq)
    self._next_id = self._next_id + 1
    local x, z = sq_xz(sq)
    local side = side_of(piece)
    return {
        id = self._next_id, kind = piece:lower(), side = side, sq = sq,
        x = x, y = 0, z = z, yaw = facing_yaw(side), anim = "idle", anim_t = 0,
        walk = 0, walk_k = 1, hop = 0, alive = true, alpha = 1,
    }
end

-- Makes the figures match the engine board exactly (after a sequence, a skip, undo or new game).
function BattleChessGame:_sync_actors()
    local pos = self._pos
    local old = self._actors
    local by_sq = {}
    for i = 1, #old do
        local a = old[i]
        if a.alive and a.sq then by_sq[a.sq] = a end
    end
    local actors, at = {}, {}
    for sq = 0, 63 do
        local piece = pos:piece_at(sq)
        if piece then
            local a = by_sq[sq]
            if not a or a.kind ~= piece:lower() or a.side ~= side_of(piece) then
                a = self:_new_actor(piece, sq)
            end
            local x, z = sq_xz(sq)
            a.sq, a.x, a.y, a.z = sq, x, 0, z
            a.yaw = facing_yaw(a.side)
            a.anim, a.anim_t, a.hop, a.alpha, a.alive, a.walk_k = "idle", 0, 0, 1, true, 1
            actors[#actors + 1] = a
            at[sq] = a
        end
    end
    self._actors = actors
    self._at = at
    if self._over and self._over.status == "checkmate" then
        local king = at[pos:king_square(pos:turn())]
        if king then king.anim, king.anim_t = "topple", 5 end
    end
end

function BattleChessGame:_maybe_think()
    if self._over or self._job or self._ai_move then return end
    if self:is_human_turn() then return end
    if self._pos:status() ~= "play" then return end
    self._job = Engine.search(self._pos, self._level)
end

function BattleChessGame:_cancel_think()
    self._job = nil
    self._ai_move = nil
end

function BattleChessGame:_move_number_prefix()
    local pos = self._pos
    local n = pos.fullmove_number and pos:fullmove_number() or math_floor(pos:history_size() / 2) + 1
    return self._pos:turn() == "w" and (n .. ". ") or (n .. "... ")
end

-- Applies a legal move to the engine and choreographs it.
function BattleChessGame:_play_move(move)
    local pos = self._pos
    local prefix = self:_move_number_prefix()
    local san = pos:san(move)
    if not pos:make_move(move) then return false end
    self._last = { from = move.from, to = move.to }
    self._last_san = prefix .. san
    self._selected = nil
    self._target_count = 0
    self:_sound("move")

    local status = pos:status()
    if status ~= "play" then
        self._over = { status = status, loser = pos:turn(), pending = true }
    end
    self:_choreograph(move)
    if pos:in_check() and status == "play" then self:_event("check", pos:king_square(pos:turn())) end
    self:_maybe_think()
    return true
end

-- Choreography -----------------------------------------------------------------------------------------------
-- A sequence is a list of steps run one after another; each step animates one or more actors.

local function add(seq, step) seq[#seq + 1] = step end

function BattleChessGame:_choreograph(move)
    local at = self._at
    local mover = at[move.from]
    local victim = move.captured and at[move.captured_sq or move.to] or nil
    local rook = move.castle and at[move.rook_from] or nil
    local seq = { i = 1, t = 0 }

    -- logical board first: the engine already moved
    at[move.from] = nil
    if victim then at[move.captured_sq or move.to] = nil; victim.sq = nil end
    if rook then at[move.rook_from] = nil; at[move.rook_to] = rook; rook.sq = move.rook_to end
    at[move.to] = mover
    mover.sq = move.to

    local x0, z0 = sq_xz(move.from)
    local x1, z1 = sq_xz(move.to)
    local kind = mover.kind

    if self._board2d then
        -- Flat board: pieces glide straight to their squares; captures happen on arrival.
        add(seq, { kind = "walk", actor = mover, path = { x0, z0, x1, z1 }, slide = true })
        if victim then add(seq, { kind = "poof", victim = victim }) end
        if rook then
            local rx0, rz0 = sq_xz(move.rook_from)
            local rx1, rz1 = sq_xz(move.rook_to)
            add(seq, { kind = "walk", actor = rook, path = { rx0, rz0, rx1, rz1 }, slide = true })
        end
        if move.promo then
            add(seq, { kind = "promote", actor = mover, to = move.promo:lower(), quick = true })
        end
        self._seq = seq
        self:_start_step()
        return
    end

    if victim then
        local vx, vz = victim.x, victim.z
        local dx, dz = vx - x0, vz - z0
        local dist = math_sqrt(dx * dx + dz * dz)
        local reach = Figures.ATTACK[kind].reach
        local sx, sz = x0, z0
        if not self._anims then reach = 0.45 end
        if dist > reach + 0.05 then
            sx, sz = vx - dx / dist * reach, vz - dz / dist * reach
        end
        add(seq, { kind = "turn", actor = mover, yaw = yaw_to(x0, z0, vx, vz) })
        if sx ~= x0 or sz ~= z0 then
            add(seq, { kind = "walk", actor = mover, path = { x0, z0, sx, sz }, hop = kind == "n" })
        end
        if self._anims then
            local style = Figures.death_style(kind, victim.kind)
            add(seq, { kind = "battle_cam", attacker = mover, victim = victim, dur = 0.85 })
            add(seq, { kind = "attack", attacker = mover, victim = victim, style = style })
        else
            add(seq, { kind = "poof", victim = victim })
        end
        add(seq, { kind = "cam_back" })
        if sx ~= x1 or sz ~= z1 then
            add(seq, { kind = "walk", actor = mover, path = { sx, sz, x1, z1 } })
        end
    elseif move.castle then
        add(seq, { kind = "turn", actor = mover, yaw = yaw_to(x0, z0, x1, z1) })
        add(seq, { kind = "walk", actor = mover, path = { x0, z0, x1, z1 } })
        add(seq, { kind = "turn", actor = mover, yaw = facing_yaw(mover.side) })
        if rook then
            local rx0, rz0 = sq_xz(move.rook_from)
            local rx1, rz1 = sq_xz(move.rook_to)
            local back = mover.side == "w" and -0.42 or 0.42
            add(seq, { kind = "turn", actor = rook, yaw = yaw_to(rx0, rz0, rx0, rz0 + back) })
            add(seq, { kind = "walk", actor = rook, path = { rx0, rz0, rx0, rz0 + back, rx1, rz1 + back, rx1, rz1 } })
            add(seq, { kind = "turn", actor = rook, yaw = facing_yaw(rook.side) })
        end
    else
        add(seq, { kind = "turn", actor = mover, yaw = yaw_to(x0, z0, x1, z1) })
        add(seq, { kind = "walk", actor = mover, path = { x0, z0, x1, z1 }, hop = kind == "n" })
    end

    if move.promo then
        add(seq, { kind = "promote", actor = mover, to = move.promo:lower() })
    end
    add(seq, { kind = "turn", actor = mover, yaw = facing_yaw(mover.side) })
    self._seq = seq
    self:_start_step()
end

function BattleChessGame:_start_step()
    local seq = self._seq
    local step = seq and seq[seq.i]
    if not step then return end
    seq.t = 0
    local kind = step.kind
    if kind == "turn" then
        local a = step.actor
        step.from = a.yaw
        step.delta = D3.angle_delta(a.yaw, step.yaw)
        step.dur = math_abs(step.delta) < 0.05 and 0 or 0.12 + math_abs(step.delta) * 0.12
        step.walk0 = a.walk
    elseif kind == "walk" then
        local a = step.actor
        local path = step.path
        local len = 0
        step.lens = {}
        for i = 1, #path / 2 - 1 do
            local dx, dz = path[i * 2 + 1] - path[i * 2 - 1], path[i * 2 + 2] - path[i * 2]
            local l = math_sqrt(dx * dx + dz * dz)
            step.lens[i] = l
            len = len + l
        end
        step.len = len
        if step.slide then
            step.dur = 0.12 + len * 0.035
        elseif step.hop then
            step.dur = 0.55 + len * 0.16
        else
            step.dur = len / WALK_SPEED[a.kind]
        end
        step.walk0 = a.walk
        step.stomps = 0
        a.anim = step.hop and "hop" or "walk"
        a.anim_t = 0
    elseif kind == "battle_cam" then
        local att, vic = step.attacker, step.victim
        self._battle = { attacker = att.kind, attacker_side = att.side, victim = vic.kind, victim_side = vic.side, t = 0,
            attacker_actor = att, victim_actor = vic }
        self:_set_battle_camera(att, vic)
        step.vyaw0 = vic.yaw
        step.vdelta = D3.angle_delta(vic.yaw, yaw_to(vic.x, vic.z, att.x, att.z))
        step.ayaw0 = att.yaw
        step.adelta = D3.angle_delta(att.yaw, yaw_to(att.x, att.z, vic.x, vic.z))
        self:_event("battle", 0, 0, 0, 0, 0, 0, att.kind .. vic.kind)
    elseif kind == "attack" then
        local spec = Figures.ATTACK[step.attacker.kind]
        step.hit = spec.hit
        step.cast = spec.cast
        step.dur = math_max(spec.dur, spec.hit + Figures.DEATH[step.style]) + 0.2
        step.attacker.anim, step.attacker.anim_t = "attack", 0
        step.hit_done, step.cast_done = false, false
    elseif kind == "cam_back" then
        self._cam_goal = nil
        self._cam_slow = 1.1
        self._battle = nil
        step.dur = 0
    elseif kind == "poof" then
        local v = step.victim
        self:_event("poof", v.x, 0.35, v.z, 0, 0, 0, v.side)
        v.alive = false
        step.dur = 0.18
    elseif kind == "promote" then
        step.dur = step.quick and 0.25 or 1.0
        step.swapped = false
        step.actor.anim, step.actor.anim_t = "promote", 0
        self:_event("promote_start", step.actor.x, 0.4, step.actor.z)
    elseif kind == "over" then
        step.dur = 1.9
    end
    step.dur = step.dur or 0
end

function BattleChessGame:_finish_step(step)
    local kind = step.kind
    if kind == "turn" then
        step.actor.yaw = step.yaw
        step.actor.anim = "idle"
    elseif kind == "walk" then
        local a = step.actor
        local path = step.path
        a.x, a.z = path[#path - 1], path[#path]
        a.y, a.hop = 0, 0
        a.anim, a.anim_t = "idle", 0
        if step.hop then self:_event("land", a.x, 0, a.z) end
    elseif kind == "attack" then
        step.attacker.anim, step.attacker.anim_t = "idle", 0
        step.victim.alive = false
        self:_remove_dead()
    elseif kind == "promote" then
        local a = step.actor
        a.kind = step.to
        a.anim, a.anim_t = "idle", 0
    elseif kind == "poof" then
        self:_remove_dead()
    end
end

function BattleChessGame:_remove_dead()
    local actors = self._actors
    for i = #actors, 1, -1 do
        if not actors[i].alive then table.remove(actors, i) end
    end
end

function BattleChessGame:_update_step(step, dt)
    local seq = self._seq
    local t = seq.t
    local kind = step.kind
    local k = step.dur > 0 and math_min(1, t / step.dur) or 1
    if kind == "turn" then
        local a = step.actor
        local e = D3.smooth(k)
        a.yaw = step.from + step.delta * e
        a.anim = "walk"
        a.walk_k = 0.55
        a.walk = step.walk0 + math_abs(step.delta) * e * 0.22
    elseif kind == "walk" then
        local a = step.actor
        local path = step.path
        local d = step.len * (step.hop and D3.smooth(k) or k)
        local i = 1
        while i < #step.lens and d > step.lens[i] do
            d = d - step.lens[i]
            i = i + 1
        end
        local l = step.lens[i]
        local u = l > 0 and d / l or 1
        local px, pz = path[i * 2 - 1], path[i * 2]
        local qx, qz = path[i * 2 + 1], path[i * 2 + 2]
        a.x, a.z = px + (qx - px) * u, pz + (qz - pz) * u
        if l > 0.01 then
            local target = yaw_to(px, pz, qx, qz)
            local diff = D3.angle_delta(a.yaw, target)
            local turn = math_min(1, dt * 14)
            a.yaw = a.yaw + diff * turn
        end
        if step.hop then
            a.hop = k
            a.y = 4 * 0.5 * k * (1 - k)
            a.anim = "hop"
        else
            a.walk = step.walk0 + step.len * k
            a.walk_k = 1
            a.anim = "walk"
            if a.kind == "r" then
                local stomps = math_floor(step.len * k / 0.31)
                if stomps > step.stomps then
                    step.stomps = stomps
                    self:_event("stomp", a.x, 0, a.z, 0.25)
                end
            end
        end
    elseif kind == "battle_cam" then
        local e = D3.smooth(k)
        local vic, att = step.victim, step.attacker
        vic.yaw = step.vyaw0 + step.vdelta * e
        att.yaw = step.ayaw0 + step.adelta * e
        vic.anim, vic.walk_k = "walk", 0.5
        vic.walk = (vic.walk or 0) + dt * 0.4 * (1 - e)
        if k >= 1 then vic.anim = "idle" end
        if self._battle then self._battle.t = self._battle.t + dt end
    elseif kind == "attack" then
        local att, vic = step.attacker, step.victim
        att.anim_t = t
        if self._battle then self._battle.t = self._battle.t + dt end
        if step.cast and not step.cast_done and t >= step.cast then
            step.cast_done = true
            local pose = self._scratch_pose
            Figures.animate(att, pose, self._time)
            local ox, oy, oz = Figures.part_point(att, pose, "weapon", 0, 0.57, 0)
            self:_event("bolt", ox, oy, oz, vic.x, 0.45, vic.z, att.side)
        end
        if t < step.hit and step.cast and att.kind == "q" and t > step.cast - 0.45 then
            if not step.charge then
                step.charge = true
                self:_event("charge", att.x, 0.9, att.z)
            end
        end
        if not step.hit_done and t >= step.hit then
            step.hit_done = true
            vic.anim, vic.anim_t, vic.style = "die", 0, step.style
            self:_event("hit", vic.x, 0.45, vic.z, att.x, 0, att.z, step.style .. ":" .. att.kind .. ":" .. vic.kind .. ":" .. att.side)
            self:_sound("move")
        end
        if step.hit_done then vic.anim_t = t - step.hit end
    elseif kind == "promote" then
        local a = step.actor
        a.anim_t = t
        if not step.swapped and t >= 0.5 then
            step.swapped = true
            a.kind = step.to
            self:_event("promote", a.x, 0.45, a.z, 0, 0, 0, a.side)
        end
    elseif kind == "over" then
        local king = step.king
        if king then king.anim_t = t end
        if step.cheer then
            for i = 1, #self._actors do
                local a = self._actors[i]
                if a.side ~= step.loser and a.alive then a.anim, a.anim_t = "cheer", t + a.id * 0.13 end
            end
        end
    end
end

function BattleChessGame:_run_sequence(dt)
    local seq = self._seq
    local guard = 0
    while seq and guard < 32 do
        guard = guard + 1
        local step = seq[seq.i]
        if not step then
            self:_sequence_done()
            return
        end
        seq.t = seq.t + dt
        self:_update_step(step, dt)
        if seq.t >= step.dur then
            local spill = seq.t - step.dur
            self:_finish_step(step)
            seq.i = seq.i + 1
            self:_start_step()
            dt = 0
            if spill <= 0 then return end
            dt = spill
            seq.t = 0
        else
            return
        end
    end
end

function BattleChessGame:_sequence_done()
    local was_over_seq = self._seq and self._seq.over_seq
    self._seq = nil
    self._battle = nil
    if self._cam_goal and not was_over_seq then
        self._cam_goal = nil
        self._cam_slow = 1.1
    end
    if was_over_seq then
        for i = 1, #self._actors do
            local a = self._actors[i]
            if a.anim == "cheer" then a.anim, a.anim_t = "idle", 0 end
        end
        self:_open_game_over()
        return
    end
    self:_sync_actors()
    if self._over and self._over.pending then
        self._over.pending = false
        self:_start_game_over()
    elseif self._two_players then
        self:_face_side_to_move()
    end
end

-- Hot seat: swing the camera round to the player whose turn it is, unless it was moved away
-- from a side view.
function BattleChessGame:_face_side_to_move()
    local u = self._user
    local want = facing_yaw(self._pos:turn())
    local other = facing_yaw(self._pos:turn() == "w" and "b" or "w")
    if math_abs(D3.angle_delta(u.yaw, other)) < 0.6 then
        u.yaw = want
        self._cam_slow = 1.3
    end
end

-- Any click or key during a sequence jumps to the end of it.
function BattleChessGame:skip()
    if not self._seq then return false end
    local over_seq = self._seq.over_seq
    self._seq = nil
    self._battle = nil
    self._cam_goal = nil
    self._cam_slow = 0.6
    self:_remove_dead()
    self:_sync_actors()
    self:_event("skip")
    if over_seq then
        self:_open_game_over()
    elseif self._two_players and not self._over then
        self:_face_side_to_move()
    elseif self._over and self._over.pending then
        self._over.pending = false
        self:_start_game_over()
        if self._seq then
            self._seq = nil
            self:_sync_actors()
            self:_open_game_over()
        end
    end
    return true
end

function BattleChessGame:_result_text()
    local over = self._over
    if not over then return "" end
    local st = over.status
    if st == "checkmate" then
        return "Checkmate! " .. SIDE_NAMES[over.loser == "w" and "b" or "w"] .. " wins."
    elseif st == "stalemate" then
        return "Stalemate. The game is a draw."
    elseif st == "fifty" then
        return "Draw by the fifty-move rule."
    elseif st == "repetition" then
        return "Draw by threefold repetition."
    end
    return "Draw: neither side can checkmate."
end

function BattleChessGame:_start_game_over()
    local over = self._over
    local st = over.status
    local pos = self._pos
    self:_cancel_think()
    self._result = self:_result_text()
    local human_won = false
    if st == "checkmate" then
        local winner = over.loser == "w" and "b" or "w"
        human_won = not self._two_players and winner == self:human_side()
        if human_won then
            self._wins = self._wins + 1
            self:_persist("battlechess_highscore", self._wins)
        end
        over.human_won = human_won
        local king = self._at[pos:king_square(over.loser)]
        local seq = { i = 1, t = 0, over_seq = true }
        if king then
            king.anim, king.anim_t = "topple", 0
            self:_set_focus_camera(king.x, king.z)
        end
        add(seq, { kind = "over", king = king, loser = over.loser, cheer = true })
        self._seq = seq
        self:_start_step()
        self:_event("mate", king and king.x or 0, 0, king and king.z or 0)
        if self._two_players then
            self:_sound("win")
        else
            self:_sound(human_won and "win" or "lose")
        end
    else
        self:_open_game_over()
    end
end

function BattleChessGame:_open_game_over()
    self._cam_goal = nil
    self._cam_slow = 1.2
    self._shell:open_dialog({
        kind = "over", title = "Battle Chess", w = 300, h = 150,
        buttons = { { id = "new", label = "New Game", w = 86 }, { id = "ok", label = "OK", default = true } },
        cancel_id = "ok",
    })
end

-- AI and update ------------------------------------------------------------------------------------------------

function BattleChessGame:update(dt)
    dt = math_min(dt or 0, 0.1)
    self._time = self._time + dt

    if self._job then
        local move = self._job:step(self._seq and NODES_WHILE_ANIMATING or NODES_PER_UPDATE)
        if move ~= nil then
            self._job = nil
            if move then self._ai_move = move end
        end
    end

    if self._seq and not self._shell:dialog() then
        self:_run_sequence(dt)
    end

    if self._ai_move and not self._seq and not self._over and not self._shell:dialog() then
        local move = self._ai_move
        self._ai_move = nil
        self:_play_move(move)
    end

    for i = 1, #self._actors do
        local a = self._actors[i]
        if a.anim == "idle" then a.anim_t = a.anim_t + dt end
    end
    if self._message_t then self._message_t = self._message_t - dt end

    self:_update_camera(dt)
end

-- Camera ---------------------------------------------------------------------------------------------------------

function BattleChessGame:_snap_camera()
    local cam, u = self._cam, self._user
    cam.yaw, cam.pitch, cam.dist = u.yaw, u.pitch, u.dist
    cam.tx, cam.ty, cam.tz = 0, -0.3, -0.25
    cam:update()
end

-- Close 3/4 view of the fighters from the side where no other figure blocks the view.
function BattleChessGame:_set_battle_camera(att, vic)
    local mx, mz = (att.x + vic.x) * 0.5, (att.z + vic.z) * 0.5
    local dx, dz = vic.x - att.x, vic.z - att.z
    local len = math_sqrt(dx * dx + dz * dz)
    if len < 0.01 then dx, dz, len = 0, 1, 1 end
    dx, dz = dx / len, dz / len
    local dist = 3.1 + len * 0.55
    local pitch = 0.3
    local reach = dist * math_cos(pitch)
    local best, best_score
    for sign = -1, 1, 2 do
        for k = 0, 5 do
            local lean = (k % 3) * 0.4 * (k < 3 and 1 or -1) + 0.25
            local px, pz = dz * sign, -dx * sign
            local c, s = math_cos(lean), math_sin(lean)
            local ox, oz = px * c + dx * s, pz * c + dz * s
            local ex, ez = mx + ox * reach, mz + oz * reach
            local blocked = 0
            for i = 1, #self._actors do
                local a = self._actors[i]
                if a ~= att and a ~= vic and a.alive then
                    local vx, vz = a.x - ex, a.z - ez
                    local sx, sz = mx - ex, mz - ez
                    local sl = sx * sx + sz * sz
                    local t = (vx * sx + vz * sz) / sl
                    if t > 0 and t < 0.9 then
                        local qx, qz = vx - sx * t, vz - sz * t
                        local d = math_sqrt(qx * qx + qz * qz)
                        if d < 0.75 then blocked = blocked + (0.75 - d) end
                    end
                end
            end
            -- how far apart the two fighters appear from there (they should not hide each other)
            local ax, az = att.x - ex, att.z - ez
            local bx, bz = vic.x - ex, vic.z - ez
            local la, lb = math_sqrt(ax * ax + az * az), math_sqrt(bx * bx + bz * bz)
            local apart = math_abs(ax * bz - az * bx) / (la * lb)
            local yaw = math_atan2(ox, -oz)
            local score = blocked * 4 + math_max(0, 0.32 - apart) * 12
                + math_abs(D3.angle_delta(self._cam.yaw, yaw)) * 0.35 + math_abs(lean - 0.25)
            if not best_score or score < best_score then best, best_score = yaw, score end
        end
    end
    self._cam_goal = { yaw = best, pitch = pitch, dist = dist, tx = mx, ty = 0.42, tz = mz }
end

function BattleChessGame:_set_focus_camera(x, z)
    local yaw = self._cam.yaw
    self._cam_goal = { yaw = yaw, pitch = 0.72, dist = 6, tx = x, ty = 0.2, tz = z }
end

function BattleChessGame:_update_camera(dt)
    local cam = self._cam
    local goal = self._cam_goal
    local yaw, pitch, dist, tx, ty, tz
    if goal then
        yaw, pitch, dist, tx, ty, tz = goal.yaw, goal.pitch, goal.dist, goal.tx, goal.ty, goal.tz
    else
        local u = self._user
        yaw, pitch, dist, tx, ty, tz = u.yaw, u.pitch, u.dist, math_sin(u.yaw) * 0.25, -0.3, -math_cos(u.yaw) * 0.25
    end
    self._cam_slow = math_max(0, self._cam_slow - dt)
    local rate = (goal or self._cam_slow > 0) and 3.4 or 11
    local k = 1 - math_exp(-rate * dt)
    cam.yaw = D3.wrap_angle(cam.yaw + D3.angle_delta(cam.yaw, yaw) * k)
    cam.pitch = cam.pitch + (pitch - cam.pitch) * k
    cam.dist = cam.dist + (dist - cam.dist) * k
    cam.tx = cam.tx + (tx - cam.tx) * k
    cam.ty = cam.ty + (ty - cam.ty) * k
    cam.tz = cam.tz + (tz - cam.tz) * k
    cam:update()
end

function BattleChessGame:rotate_camera(dyaw, dpitch)
    local u = self._user
    u.yaw = D3.wrap_angle(u.yaw + (dyaw or 0))
    u.pitch = clamp(u.pitch + (dpitch or 0), PITCH_MIN, PITCH_MAX)
end

function BattleChessGame:zoom_camera(factor)
    local u = self._user
    u.dist = clamp(u.dist * factor, DIST_MIN, DIST_MAX)
end

function BattleChessGame:set_camera_preset(id)
    for i = 1, #PRESETS do
        local p = PRESETS[i]
        if p.id == id then
            local u = self._user
            local yaw = p.yaw
            if (id == "cam_over" or id == "cam_side") and self._play_black then yaw = yaw + math_pi end
            u.yaw, u.pitch, u.dist = D3.wrap_angle(yaw), p.pitch, p.dist
            self._preset = i
            return true
        end
    end
    return false
end

function BattleChessGame:cycle_camera()
    local nxt = (self._preset or 1) % #PRESETS + 1
    self:set_camera_preset(PRESETS[nxt].id)
    self._message = PRESETS[nxt].label
    self._message_t = 1.4
end

function BattleChessGame:reset_camera()
    self:set_camera_preset(self._play_black and "cam_black" or "cam_white")
end

-- Picking ---------------------------------------------------------------------------------------------------------

-- Board square under a screen point (ray against the board plane), or nil.
function BattleChessGame:square_at(x, y)
    if self._board2d then
        local b = self._layout.board2d
        local col, row = math_floor((x - b.x) / b.sq), math_floor((y - b.y) / b.sq)
        if col < 0 or col > 7 or row < 0 or row > 7 then return nil end
        if self:board_flipped() then return row * 8 + (7 - col) end
        return (7 - row) * 8 + col
    end
    local wx, wz = self._cam:unproject_plane(x, y, 0)
    if not wx then return nil end
    local file, rank = math_floor(wx + 4), math_floor(wz + 4)
    if file < 0 or file > 7 or rank < 0 or rank > 7 then return nil end
    return rank * 8 + file
end

-- Front-most standing figure whose screen box contains the point.
function BattleChessGame:figure_at(x, y)
    if self._board2d then return nil end
    local cam = self._cam
    local best, best_z
    for i = 1, #self._actors do
        local a = self._actors[i]
        if a.alive and a.sq and a.anim ~= "die" then
            local fx, fy, fz = cam:project(a.x, 0, a.z)
            local hx, hy = cam:project(a.x, Figures.HEIGHT[a.kind], a.z)
            if fx and hx then
                local half = cam.F * 0.24 / fz
                local top, bottom = math_min(hy, fy), math_max(hy, fy) + half * 0.3
                if x >= fx - half and x <= fx + half and y >= top and y <= bottom then
                    if not best_z or fz < best_z then best, best_z = a, fz end
                end
            end
        end
    end
    return best
end

-- The square a click at (x, y) means: a legal target on the board wins, then a figure, then the board.
function BattleChessGame:pick(x, y)
    local sq = self:square_at(x, y)
    if sq and self._selected and self._targets[sq] then return sq end
    local fig = self:figure_at(x, y)
    if fig then return fig.sq end
    return sq
end

-- Selection and moves -------------------------------------------------------------------------------------------

function BattleChessGame:can_act()
    return not self._over and not self._seq and not self._shell:is_modal() and self:is_human_turn() and not self._ai_move
end

function BattleChessGame:select(sq)
    self._selected = nil
    self._target_count = 0
    local targets = self._targets
    for k in pairs(targets) do targets[k] = nil end
    if not sq then return false end
    local piece = self._pos:piece_at(sq)
    if not piece or side_of(piece) ~= self._pos:turn() then return false end
    local moves = self._pos:legal_moves_from(sq, self._scratch_moves)
    self._selected = sq
    for i = 1, #moves do
        local m = moves[i]
        if not targets[m.to] then
            targets[m.to] = m
            self._target_count = self._target_count + 1
        end
    end
    self:_event("select", sq)
    return true
end

-- Acts on a square: select an own piece, move the selected one, or deselect.
function BattleChessGame:activate(sq)
    if not self:can_act() or not sq then return false end
    local piece = self._pos:piece_at(sq)
    if self._selected then
        if sq == self._selected then
            self:select(nil)
            return true
        end
        local move = self._targets[sq]
        if move then
            if move.promo then
                self:_open_promotion(self._selected, sq)
            else
                self:_play_move(move)
            end
            return true
        end
    end
    if piece and side_of(piece) == self._pos:turn() then
        return self:select(sq)
    end
    return false
end

function BattleChessGame:try_move(from, to, promo)
    if not self:can_act() then return false end
    local piece = self._pos:piece_at(from)
    if not piece or side_of(piece) ~= self._pos:turn() then return false end
    local move = self._pos:find_move(from, to, promo)
    if not move then return false end
    return self:_play_move(move)
end

function BattleChessGame:_open_promotion(from, to)
    local controls = {
        { type = "group", label = "Promote to", x = 12, y = 30, w = 150, h = 118 },
    }
    local order = { "q", "r", "b", "n" }
    for i = 1, 4 do
        controls[#controls + 1] = { type = "radio", group = "piece", value = order[i], label = PROMO_NAMES[order[i]], x = 24, y = 48 + (i - 1) * 24, w = 120, h = 22 }
    end
    self._shell:open_dialog({
        kind = "promote", title = "Pawn Promotion", w = 300, h = 196, from = from, to = to,
        values = { piece = "q" }, controls = controls,
        buttons = { { id = "ok", label = "OK", default = true }, { id = "cancel", label = "Cancel" } },
    })
end

function BattleChessGame:can_undo()
    if self._over and self._over.pending then return false end
    local n = self._pos:history_size()
    if self._two_players then return n >= 1 end
    local need = self._pos:turn() == self:human_side() and 2 or 1
    return n >= need
end

function BattleChessGame:undo()
    if self._seq then self:skip() end
    if not self:can_undo() then return false end
    local dialog = self._shell:dialog()
    if dialog and dialog.kind == "over" then self._shell:close_dialog() end
    self:_cancel_think()
    local plies = 1
    if not self._two_players then plies = self._pos:turn() == self:human_side() and 2 or 1 end
    for _ = 1, plies do self._pos:undo() end
    self._over = nil
    self._result = nil
    self:select(nil)
    local last = self._pos:last_move()
    self._last = last and { from = last.from, to = last.to } or nil
    self._last_san = ""
    self:_sync_actors()
    self:_event("undo")
    self:_maybe_think()
    return true
end

-- Menus and dialogs --------------------------------------------------------------------------------------------

function BattleChessGame:_command(id)
    if id == "new" then
        self:new_game()
    elseif id == "undo" then
        self:undo()
    elseif id == "exit" then
        self._close_requested = true
    elseif id == "difficulty" then
        self:_open_difficulty()
    elseif id == "anims" then
        self._anims = not self._anims
        self:_persist("battlechess_anims", self._anims)
    elseif id == "black" then
        self._play_black = not self._play_black
        self:_persist("battlechess_black", self._play_black)
        self:new_game()
    elseif id == "two" then
        self._two_players = not self._two_players
        self:_persist("battlechess_two", self._two_players)
        if self._two_players then
            self:_cancel_think()
        else
            self:_maybe_think()
        end
    elseif id == "board2d" or id == "board3d" then
        self:set_board2d(id == "board2d")
    elseif id == "reset_camera" then
        self:reset_camera()
    elseif id == "cycle_view" then
        self:cycle_camera()
    elseif id == "zoom_in" then
        self:zoom_camera(0.85)
    elseif id == "zoom_out" then
        self:zoom_camera(1 / 0.85)
    elseif id == "rotate" then
        self:rotate_view()
    elseif id == "how_to" then
        self._shell:open_dialog({ kind = "how_to", title = "How to Play", w = 420, h = 340, buttons_align = "center" })
    elseif id == "about" then
        self._shell:open_dialog({ kind = "about", title = "About Battle Chess", w = 340, h = 180, buttons_align = "center" })
    elseif self:set_camera_preset(id) then
        return
    end
end

function BattleChessGame:_open_difficulty()
    local controls = {
        { type = "label", label = "How strong should the computer play?", x = 16, y = 30, w = 330, h = 18 },
    }
    for level = 1, 10 do
        local row = level <= 5 and 0 or 1
        controls[#controls + 1] = {
            type = "radio", group = "level", value = level, label = tostring(level),
            x = 22 + ((level - 1) % 5) * 64, y = 56 + row * 26, w = 56, h = 22,
        }
    end
    controls[#controls + 1] = { type = "label", label = "1-3: a beginner who blunders now and then.", x = 16, y = 112, w = 330, h = 18 }
    controls[#controls + 1] = { type = "label", label = "4-6: a club player.  7-10: thinks longer, plays hard.", x = 16, y = 130, w = 330, h = 18 }
    controls[#controls + 1] = { type = "label", label = "The computer only ever sees the board.", x = 16, y = 148, w = 330, h = 18 }
    self._shell:open_dialog({
        kind = "difficulty", title = "Difficulty", w = 348, h = 214,
        values = { level = self._level }, controls = controls,
        buttons = { { id = "ok", label = "OK", default = true }, { id = "cancel", label = "Cancel" } },
    })
end

function BattleChessGame:_dialog_button(dialog, id)
    if dialog.kind == "difficulty" and id == "ok" then
        self._level = clamp(math_floor(tonumber(dialog.values.level) or self._level), 1, 10)
        self:_persist("battlechess_level", self._level)
        if self._job then
            self._job = nil
            self:_maybe_think()
        end
    elseif dialog.kind == "promote" then
        if id == "ok" then
            local promo = dialog.values.piece or "q"
            local move = self._pos:find_move(dialog.from, dialog.to, promo)
            self._shell:close_dialog()
            if move then self:_play_move(move) end
        end
    elseif dialog.kind == "over" then
        if id == "new" then self:new_game() end
    end
    return false
end

-- Input ----------------------------------------------------------------------------------------------------------

local SHELL_KEYS = { left = true, right = true, up = true, down = true, confirm = true, menu = true }
local STEP_YAW, STEP_PITCH = math_pi / 12, 0.1

-- Moves the keyboard cursor relative to the camera, so "up" always goes away from the viewer.
function BattleChessGame:move_cursor(key)
    local yaw = self._cam.yaw
    if self._board2d then yaw = self:board_flipped() and math_pi or 0 end
    local fx, fz = -math_sin(yaw), math_cos(yaw)
    local rx, rz = math_cos(yaw), math_sin(yaw)
    local dx, dz
    if key == "up" then dx, dz = fx, fz
    elseif key == "down" then dx, dz = -fx, -fz
    elseif key == "right" then dx, dz = rx, rz
    else dx, dz = -rx, -rz end
    local df, dr = 0, 0
    if math_abs(dx) > math_abs(dz) then df = dx > 0 and 1 or -1 else dr = dz > 0 and 1 or -1 end
    if not self._cursor_visible then
        self._cursor_visible = true
        if self._selected then self._cursor = self._selected end
        return
    end
    local file = clamp(self._cursor % 8 + df, 0, 7)
    local rank = clamp(math_floor(self._cursor / 8) + dr, 0, 7)
    self._cursor = rank * 8 + file
end

function BattleChessGame:key_press(key, is_repeat)
    if SHELL_KEYS[key] and self._shell:key(key) then return end
    local dialog = self._shell:dialog()
    if key == "new" then
        if dialog and dialog.kind ~= "over" then return end
        self:new_game()
        return
    end
    if self._shell:is_modal() then return end

    if key == "left" or key == "right" or key == "up" or key == "down" then
        if self._held.fast and not self._board2d then
            if key == "left" then self:rotate_camera(STEP_YAW, 0)
            elseif key == "right" then self:rotate_camera(-STEP_YAW, 0)
            elseif key == "up" then self:rotate_camera(0, STEP_PITCH)
            else self:rotate_camera(0, -STEP_PITCH) end
        else
            self:move_cursor(key)
        end
    elseif key == "confirm" then
        if is_repeat then return end
        if self:skip() then return end
        if not self._cursor_visible then
            self._cursor_visible = true
            return
        end
        self:activate(self._cursor)
    elseif key == "alt" then
        if is_repeat then return end
        if self:skip() then return end
        if not self._board2d then self:cycle_camera() end
    elseif key == "undo" then
        if not is_repeat then self:undo() end
    elseif key == "1" then
        if not self._board2d then self:zoom_camera(0.85) end
    elseif key == "2" then
        if not self._board2d then self:zoom_camera(1 / 0.85) end
    elseif key == "3" then
        if not is_repeat then self:rotate_view() end
    elseif key == "4" then
        if not self._board2d then self:reset_camera() end
    end
end

function BattleChessGame:key_hold(key, held)
    self._held[key] = held and true or false
end

function BattleChessGame:pointer_input(x, y, input)
    local moved = math_abs(x - self._pointer_x) + math_abs(y - self._pointer_y) > 1.5
    local px, py = self._pointer_x, self._pointer_y
    self._pointer_x, self._pointer_y = x, y

    local drag = self._drag
    if drag then
        -- camera drag keeps going even when the pointer leaves the window
        if input.right or input.middle then
            local dx, dy = x - px, y - py
            drag.moved = drag.moved + math_abs(dx) + math_abs(dy)
            if drag.moved > 3 then
                self:rotate_camera(-dx * 0.011, dy * 0.008)
            end
            self._shell:pointer(x, y, input)
            return
        end
        self._shell:pointer(x, y, input)
        if drag.moved <= 3 and input.right_released then
            if not self:skip() then self:select(nil) end
        end
        self._drag = nil
        return
    end

    if self._shell:pointer(x, y, input) then
        self._hover = nil
        return
    end

    local client = self._layout.client
    if not Win95.inside(client, x, y) then
        self._hover = nil
        return
    end

    if moved then self._cursor_visible = false end
    self._hover = self:pick(x, y)

    if input.right_pressed or input.middle_pressed then
        self._drag = { moved = 0 }
        return
    end
    if input.left_pressed then
        if self:skip() then return end
        local sq = self._hover
        self._press_sq, self._press_x, self._press_y = nil, x, y
        if sq then
            self._cursor = sq
            local was = self._selected
            self:activate(sq)
            if self._board2d and self._selected == sq and was ~= sq then self._press_sq = sq end
        elseif self._selected then
            self:select(nil)
        end
    elseif self._press_sq then
        if input.left_released then
            -- Drag and drop: releasing over a legal square plays the move.
            local sq = self:square_at(x, y)
            local from = self._press_sq
            self._press_sq = nil
            if sq and sq ~= from and self._selected == from and self._targets[sq] then
                self._cursor = sq
                self:activate(sq)
            end
        elseif not input.left then
            self._press_sq = nil
        end
    end
end

-- The piece being dragged on the 2D board and the pointer position, or nil.
function BattleChessGame:drag_piece()
    local sq = self._press_sq
    if not sq or not self._board2d or self._selected ~= sq then return nil end
    if math_abs(self._pointer_x - self._press_x) + math_abs(self._pointer_y - self._press_y) < 4 then return nil end
    return sq, self._pointer_x, self._pointer_y
end

function BattleChessGame:set_board2d(on)
    on = on and true or false
    if on == self._board2d then return end
    self:skip()
    self._board2d = on
    self._press_sq = nil
    self:_persist("battlechess_2d", on)
    self:_event("board_mode", on and 1 or 0)
end

-- "Rotate Board": a quarter turn of the 3D camera, or flipping the 2D board.
function BattleChessGame:rotate_view()
    if self._board2d then
        self._flip2d = not self._flip2d
    else
        self:rotate_camera(math_pi * 0.5, 0)
    end
end

-- The 2D board shows Black at the bottom when the human plays Black (or it was flipped).
function BattleChessGame:board_flipped()
    local black = self._play_black and not self._two_players
    if self._flip2d then return not black end
    return black
end

function BattleChessGame:board2d() return self._board2d end
function BattleChessGame:last_san() return self._last_san end

function BattleChessGame:ui_back()
    if self._shell:ui_back() then return true end
    if self:skip() then return true end
    if self._selected then
        self:select(nil)
        return true
    end
    return false
end

function BattleChessGame:consume_close_request()
    local requested = self._shell:consume_close_request() or self._close_requested
    self._close_requested = false
    return requested
end

function BattleChessGame:is_game_over() return false end

function BattleChessGame:summary()
    local result = self._result or "in progress"
    return string.format("[Battle Chess] Moves: %d  Result: %s  Wins: %d", math_floor((self._pos:history_size() + 1) / 2), result, self._wins)
end

-- Queries for the renderer ----------------------------------------------------------------------------------------

function BattleChessGame:status_segments()
    local seg = self._segments
    local text
    if self._over and not self._over.pending then
        text = self._result or ""
    elseif self._battle then
        text = Figures.NAMES[self._battle.attacker] .. " takes " .. Figures.NAMES[self._battle.victim] .. "!"
    elseif self._job or (self._ai_move and not self._seq) then
        local dots = math_floor(self._time * 3) % 4
        text = "Thinking" .. string.rep(".", dots)
    elseif self._seq then
        text = SIDE_NAMES[self._pos:turn() == "w" and "b" or "w"] .. " moves..."
    else
        local turn = self._pos:turn()
        if self._two_players then
            text = SIDE_NAMES[turn] .. " to move"
        else
            text = "Your move (" .. SIDE_NAMES[turn] .. ")"
        end
        if self._pos:in_check() then text = "Check!  " .. text end
    end
    seg[1].text = text
    seg[2].text = self._last_san ~= "" and ("Last: " .. self._last_san) or "Last: -"
    seg[3].text = self._two_players and "Two Players" or ("Level " .. self._level .. "   Wins " .. self._wins)
    return seg
end

function BattleChessGame:shell() return self._shell end
function BattleChessGame:layout() return self._layout end
function BattleChessGame:camera() return self._cam end
function BattleChessGame:user_camera() return self._user end
function BattleChessGame:actors() return self._actors end
function BattleChessGame:actor_at(sq) return self._at[sq] end
function BattleChessGame:position() return self._pos end
function BattleChessGame:time() return self._time end
function BattleChessGame:selected() return self._selected end
function BattleChessGame:targets() return self._targets end
function BattleChessGame:target_count() return self._target_count end
function BattleChessGame:last_move() return self._last end
function BattleChessGame:hover() return self._hover end
function BattleChessGame:cursor() return self._cursor, self._cursor_visible end
function BattleChessGame:is_thinking() return self._job ~= nil end
function BattleChessGame:think_progress() return self._job and self._job:progress() or 0 end
function BattleChessGame:battle() return self._battle end
function BattleChessGame:in_sequence() return self._seq ~= nil end
function BattleChessGame:is_over() return self._over ~= nil and not self._over.pending end
function BattleChessGame:over_info() return self._over end
function BattleChessGame:result_text() return self._result or "" end
function BattleChessGame:level() return self._level end
function BattleChessGame:wins() return self._wins end
function BattleChessGame:animations() return self._anims end
function BattleChessGame:two_players() return self._two_players end
function BattleChessGame:play_black() return self._play_black end
function BattleChessGame:client_size() return CLIENT_W, CLIENT_H end
function BattleChessGame:dragging() return self._drag ~= nil end
function BattleChessGame:message()
    if self._message and self._message_t and self._message_t > 0 then return self._message, self._message_t end
    return nil
end

function BattleChessGame:check_square()
    if self._pos:in_check() then return self._pos:king_square(self._pos:turn()) end
    return nil
end

BattleChessGame.PRESETS = PRESETS
BattleChessGame.PITCH_MIN, BattleChessGame.PITCH_MAX = PITCH_MIN, PITCH_MAX
BattleChessGame.DIST_MIN, BattleChessGame.DIST_MAX = DIST_MIN, DIST_MAX

return BattleChessGame
