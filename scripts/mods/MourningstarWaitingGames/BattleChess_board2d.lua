-- Flat 2D board for Battle Chess (View > 2D Board): a green-and-cream board with outlined
-- Staunton pieces, in the style of popular online chess sites. Everything is drawn with triangles
-- and rects on the shared canvas; board coordinates come from the game's figures, so moves glide.
local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_random = math.random
local math_sin = math.sin
local math_sqrt = math.sqrt
local math_cos = math.cos

local Board2D = {}
Board2D.__index = Board2D

local C = {
    background = { 255, 48, 46, 43 },
    panel = { 255, 39, 37, 34 },
    panel_edge = { 255, 64, 61, 57 },
    light = { 255, 235, 236, 208 },
    dark = { 255, 115, 149, 82 },
    light_hi = { 255, 245, 246, 130 },
    dark_hi = { 255, 185, 202, 67 },
    marker = { 255, 0, 0, 0 },
    check = { 255, 235, 50, 40 },
    hover = { 255, 255, 255, 255 },
    cursor = { 255, 255, 214, 80 },
    coord_light = { 255, 115, 149, 82 },
    coord_dark = { 255, 235, 236, 208 },
    shadow = { 255, 0, 0, 0 },
    white_fill = { 255, 249, 249, 249 },
    white_shade = { 255, 214, 212, 208 },
    white_line = { 255, 62, 60, 58 },
    black_fill = { 255, 88, 85, 83 },
    black_shade = { 255, 60, 58, 56 },
    black_line = { 255, 30, 29, 28 },
    black_detail = { 255, 205, 203, 200 },
    text = { 255, 230, 228, 224 },
    text_dim = { 255, 160, 157, 152 },
    turn = { 255, 129, 182, 76 },
    spark = { 255, 255, 236, 170 },
}
Board2D.C = C

-- Piece shapes on a unit square (x right, y down). Parts are drawn twice: an outline pass
-- slightly enlarged, then the fill pass, so overlapping parts merge into one silhouette.
local BASE = {
    { "poly", { 0.20, 0.90, 0.80, 0.90, 0.78, 0.82, 0.22, 0.82 } },
    { "ellipse", 0.215, 0.86, 0.045, 0.04 },
    { "ellipse", 0.785, 0.86, 0.045, 0.04 },
    { "poly", { 0.29, 0.83, 0.71, 0.83, 0.67, 0.75, 0.33, 0.75 } },
}

local function with_base(parts)
    local out = {}
    for i = 1, #BASE do out[#out + 1] = BASE[i] end
    for i = 1, #parts do out[#out + 1] = parts[i] end
    return out
end

local SHAPES = {
    p = with_base({
        { "poly", { 0.37, 0.76, 0.63, 0.76, 0.56, 0.52, 0.44, 0.52 } },
        { "ellipse", 0.5, 0.52, 0.155, 0.042 },
        { "ellipse", 0.5, 0.355, 0.13, 0.13 },
    }),
    r = with_base({
        { "poly", { 0.33, 0.76, 0.67, 0.76, 0.63, 0.39, 0.37, 0.39 } },
        { "poly", { 0.28, 0.41, 0.72, 0.41, 0.72, 0.34, 0.28, 0.34 } },
        { "poly", { 0.29, 0.35, 0.71, 0.35, 0.71, 0.25, 0.29, 0.25 } },
        { "poly", { 0.29, 0.26, 0.39, 0.26, 0.39, 0.16, 0.29, 0.16 } },
        { "poly", { 0.45, 0.26, 0.55, 0.26, 0.55, 0.16, 0.45, 0.16 } },
        { "poly", { 0.61, 0.26, 0.71, 0.26, 0.71, 0.16, 0.61, 0.16 } },
        { "line", 0.33, 0.39, 0.67, 0.39, 0.012 },
    }),
    b = with_base({
        { "poly", { 0.37, 0.76, 0.63, 0.76, 0.56, 0.55, 0.44, 0.55 } },
        { "ellipse", 0.5, 0.55, 0.17, 0.042 },
        { "ellipse", 0.5, 0.38, 0.14, 0.165 },
        { "poly", { 0.43, 0.28, 0.57, 0.28, 0.5, 0.185 } },
        { "ellipse", 0.5, 0.165, 0.042, 0.042 },
        { "line", 0.465, 0.415, 0.565, 0.315, 0.022 },
    }),
    q = with_base({
        { "poly", { 0.34, 0.76, 0.66, 0.76, 0.57, 0.48, 0.43, 0.48 } },
        { "ellipse", 0.5, 0.48, 0.19, 0.045 },
        { "poly", { 0.30, 0.45, 0.70, 0.45, 0.73, 0.36, 0.27, 0.36 } },
        { "poly", { 0.27, 0.385, 0.37, 0.365, 0.21, 0.205 } },
        { "poly", { 0.35, 0.37, 0.45, 0.365, 0.375, 0.16 } },
        { "poly", { 0.445, 0.37, 0.555, 0.37, 0.5, 0.13 } },
        { "poly", { 0.55, 0.365, 0.65, 0.37, 0.625, 0.16 } },
        { "poly", { 0.63, 0.365, 0.73, 0.385, 0.79, 0.205 } },
        { "ellipse", 0.21, 0.2, 0.035, 0.035 },
        { "ellipse", 0.375, 0.155, 0.035, 0.035 },
        { "ellipse", 0.5, 0.125, 0.038, 0.038 },
        { "ellipse", 0.625, 0.155, 0.035, 0.035 },
        { "ellipse", 0.79, 0.2, 0.035, 0.035 },
        { "line", 0.30, 0.43, 0.70, 0.43, 0.012 },
    }),
    k = with_base({
        { "poly", { 0.34, 0.76, 0.66, 0.76, 0.59, 0.49, 0.41, 0.49 } },
        { "ellipse", 0.5, 0.49, 0.18, 0.045 },
        { "poly", { 0.33, 0.47, 0.67, 0.47, 0.73, 0.32, 0.27, 0.32 } },
        { "ellipse", 0.5, 0.32, 0.23, 0.065 },
        { "poly", { 0.465, 0.28, 0.535, 0.28, 0.535, 0.09, 0.465, 0.09 } },
        { "poly", { 0.40, 0.21, 0.60, 0.21, 0.60, 0.145, 0.40, 0.145 } },
        { "line", 0.33, 0.44, 0.67, 0.44, 0.012 },
    }),
    n = with_base({
        { "poly", { 0.32, 0.76, 0.72, 0.76, 0.73, 0.47, 0.67, 0.25, 0.51, 0.20, 0.41, 0.42 } },
        { "poly", { 0.53, 0.22, 0.47, 0.44, 0.25, 0.535, 0.175, 0.455, 0.215, 0.345, 0.37, 0.215 } },
        { "poly", { 0.43, 0.25, 0.54, 0.235, 0.50, 0.095 } },
        { "dot", 0.375, 0.31, 0.024 },
        { "dot", 0.225, 0.46, 0.017 },
        { "line", 0.63, 0.27, 0.70, 0.47, 0.016 },
        { "line", 0.20, 0.495, 0.31, 0.50, 0.012 },
    }),
}
Board2D.SHAPES = SHAPES

local scratch = {}

-- Outward unit normal of edge a->b, pointing away from the centre (cx, cy).
local function edge_normal(ax, ay, bx, by, cx, cy)
    local ex, ey = bx - ax, by - ay
    local len = math_sqrt(ex * ex + ey * ey)
    if len < 1e-6 then return 0, 0 end
    local nx, ny = ey / len, -ex / len
    if nx * ((ax + bx) * 0.5 - cx) + ny * ((ay + by) * 0.5 - cy) < 0 then nx, ny = -nx, -ny end
    return nx, ny
end

-- Pushes every edge of a convex polygon outwards by d (mitred corners, capped at sharp tips)
-- and writes the result, scaled to s and moved to (x, y), into scratch.
local function offset_poly(pts, n, x, y, s, d)
    local cx, cy = 0, 0
    for k = 1, n do
        cx = cx + pts[k * 2 - 1]
        cy = cy + pts[k * 2]
    end
    cx, cy = cx / n * s, cy / n * s
    for k = 1, n do
        local pk = (k - 2) % n + 1
        local nk = k % n + 1
        local vx, vy = pts[k * 2 - 1] * s, pts[k * 2] * s
        local n1x, n1y = edge_normal(pts[pk * 2 - 1] * s, pts[pk * 2] * s, vx, vy, cx, cy)
        local n2x, n2y = edge_normal(vx, vy, pts[nk * 2 - 1] * s, pts[nk * 2] * s, cx, cy)
        local f = d / math_max(0.3, 1 + n1x * n2x + n1y * n2y)
        local ox, oy = (n1x + n2x) * f, (n1y + n2y) * f
        local olen = math_sqrt(ox * ox + oy * oy)
        if olen > d * 2.2 then
            ox, oy = ox / olen * d * 2.2, oy / olen * d * 2.2
        end
        scratch[k * 2 - 1] = x + vx + ox
        scratch[k * 2] = y + vy + oy
    end
end

local function centroid(pts)
    local n = #pts / 2
    local cx, cy = 0, 0
    for i = 1, n do
        cx = cx + pts[i * 2 - 1]
        cy = cy + pts[i * 2]
    end
    return cx / n, cy / n
end

-- Draws a piece with its top-left corner at (x, y) and size s. Uses three layers:
-- outline at layer, fill at layer + 0.1 and details at layer + 0.2.
function Board2D.draw_piece(canvas, kind, side, x, y, s, layer, alpha)
    -- Pieces sit slightly inside their square so the corner coordinates stay readable.
    x, y, s = x + s * 0.07, y + s * 0.04, s * 0.86
    local parts = SHAPES[kind]
    if not parts then return end
    local white = side == "w"
    local fill = white and C.white_fill or C.black_fill
    local shade = white and C.white_shade or C.black_shade
    local line = white and C.white_line or C.black_line
    local detail = white and C.white_line or C.black_detail
    local a = alpha or 255
    local t = math_max(1.1, s * 0.034)

    for pass = 1, 2 do
        local color = pass == 1 and line or fill
        local grow = pass == 1 and t or 0
        local lay = layer + (pass - 1) * 0.1
        for i = 1, #parts do
            local p = parts[i]
            local kind_p = p[1]
            if kind_p == "poly" then
                local pts = p[2]
                local n = #pts / 2
                if grow > 0 then
                    offset_poly(pts, n, x, y, s, grow)
                else
                    for k = 1, n do
                        scratch[k * 2 - 1] = x + pts[k * 2 - 1] * s
                        scratch[k * 2] = y + pts[k * 2] * s
                    end
                end
                canvas:poly(scratch, n, lay, color, a)
            elseif kind_p == "ellipse" then
                canvas:ellipse(x + p[2] * s, y + p[3] * s, p[4] * s + grow, p[5] * s + grow, lay, color, a, 1, 0, 14)
            end
        end
    end

    -- A soft shade along the right side gives the flat pieces some volume.
    local body = parts[#BASE + 1]
    if body and body[1] == "poly" then
        local pts = body[2]
        local n = #pts / 2
        local cx = centroid(pts)
        for k = 1, n do
            local px = pts[k * 2 - 1]
            scratch[k * 2 - 1] = x + (px > cx and px or cx + (px - cx) * 0.1) * s
            scratch[k * 2] = y + pts[k * 2] * s
        end
        canvas:poly(scratch, n, layer + 0.15, shade, a * 0.55)
    end

    for i = 1, #parts do
        local p = parts[i]
        if p[1] == "line" then
            canvas:line(x + p[2] * s, y + p[3] * s, x + p[4] * s, y + p[5] * s, math_max(1, p[6] * s), layer + 0.2, detail, a)
        elseif p[1] == "dot" then
            canvas:circle(x + p[2] * s, y + p[3] * s, math_max(0.8, p[4] * s), layer + 0.2, detail, a, 1, 0, 8)
        end
    end
end

-- State ------------------------------------------------------------------------------------------------------

function Board2D.new()
    return setmetatable({ _flashes = {}, _sparks = {} }, Board2D)
end

local function square_rect(b, sq, flipped)
    local file, rank = sq % 8, math_floor(sq / 8)
    local col, row
    if flipped then col, row = 7 - file, rank else col, row = file, 7 - rank end
    return b.x + col * b.sq, b.y + row * b.sq, col, row
end
Board2D.square_rect = square_rect

-- Board coordinates (-3.5..3.5) to the top-left corner of a piece box.
local function board_point(b, x, z, flipped)
    local file, rank = x + 3.5, z + 3.5
    local col, row
    if flipped then col, row = 7 - file, rank else col, row = file, 7 - rank end
    return b.x + col * b.sq, b.y + row * b.sq
end

function Board2D:event(ev, game)
    if ev.kind == "poof" then
        local b = game:layout().board2d
        local px, py = board_point(b, ev.a, ev.c, game:board_flipped())
        local cx, cy = px + b.sq * 0.5, py + b.sq * 0.5
        self._flashes[#self._flashes + 1] = { x = cx, y = cy, t = 0 }
        for _ = 1, 10 do
            local a = math_random() * math_pi * 2
            local v = 40 + math_random() * 90
            self._sparks[#self._sparks + 1] = { x = cx, y = cy, vx = math_cos(a) * v, vy = math_sin(a) * v - 20, t = 0, life = 0.35 + math_random() * 0.25 }
        end
    elseif ev.kind == "new" or ev.kind == "skip" or ev.kind == "board_mode" then
        self._flashes = {}
        self._sparks = {}
    end
end

function Board2D:update(dt)
    local f = self._flashes
    for i = #f, 1, -1 do
        f[i].t = f[i].t + dt
        if f[i].t > 0.4 then table.remove(f, i) end
    end
    local s = self._sparks
    for i = #s, 1, -1 do
        local p = s[i]
        p.t = p.t + dt
        if p.t > p.life then
            table.remove(s, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + 260 * dt
        end
    end
end

-- Drawing ----------------------------------------------------------------------------------------------------

local captured_w, captured_b = {}, {}
local START = { p = 8, n = 2, b = 2, r = 2, q = 1 }
local VALUE = { p = 1, n = 3, b = 3, r = 5, q = 9 }
local ORDER = { "q", "r", "b", "n", "p" }

-- Pieces each side has lost, from the figures on the board.
local function count_captured(game)
    local have = { w = { p = 0, n = 0, b = 0, r = 0, q = 0 }, b = { p = 0, n = 0, b = 0, r = 0, q = 0 } }
    local actors = game:actors()
    for i = 1, #actors do
        local a = actors[i]
        if a.alive and have[a.side][a.kind] then have[a.side][a.kind] = have[a.side][a.kind] + 1 end
    end
    local material = { w = 0, b = 0 }
    for side, list in pairs({ w = captured_w, b = captured_b }) do
        for k in pairs(list) do list[k] = nil end
        for i = 1, #ORDER do
            local kind = ORDER[i]
            local lost = math_max(0, START[kind] - have[side][kind])
            for _ = 1, lost do list[#list + 1] = kind end
            material[side] = material[side] + have[side][kind] * VALUE[kind]
        end
    end
    return material
end

function Board2D:draw(canvas, text, game, time, layer)
    local L = game:layout()
    local client = L.client
    local b = L.board2d
    local flipped = game:board_flipped()
    local S = b.sq

    canvas:rect(client.x, client.y, client.w, client.h, layer - 0.9, C.background)
    canvas:soft_rect(b.x, b.y + 3, b.size, b.size, 6, layer - 0.8, C.shadow, 110, 3)

    -- Squares with last-move and selection tints.
    local last = game:last_move()
    local selected = game:selected()
    for sq = 0, 63 do
        local x, y = square_rect(b, sq, flipped)
        local light = (sq % 8 + math_floor(sq / 8)) % 2 == 1
        local hi = sq == selected or (last and (sq == last.from or sq == last.to))
        local color
        if hi then color = light and C.light_hi or C.dark_hi else color = light and C.light or C.dark end
        canvas:rect(x, y, S, S, layer, color)
    end

    -- Coordinates inside the edge squares.
    for i = 0, 7 do
        local file_sq = flipped and (7 - i) or i
        local x = b.x + i * S
        local bottom_light = ((flipped and 7 or 0) + file_sq) % 2 == 1
        text:draw(string.char(97 + file_sq), x, b.y + b.size - 14, S - 3, 13, 11, bottom_light and C.coord_light or C.coord_dark, "right", layer + 0.05)
        local rank = flipped and i or 7 - i
        local left_light = ((flipped and 7 or 0) + rank) % 2 == 1
        text:draw(tostring(rank + 1), b.x + 3, b.y + i * S + 1, S, 13, 11, left_light and C.coord_light or C.coord_dark, "left", layer + 0.05)
    end

    -- King in check: a red glow under the piece.
    local check_sq = game:check_square()
    if check_sq then
        local x, y = square_rect(b, check_sq, flipped)
        canvas:glow(x + S * 0.5, y + S * 0.5, S * 0.62, layer + 0.1, C.check, 230, 5)
    end

    -- Legal destinations: a dot on empty squares, a ring on captures.
    if selected then
        local targets = game:targets()
        local pos = game:position()
        for sq in pairs(targets) do
            local x, y = square_rect(b, sq, flipped)
            if pos:piece_at(sq) then
                canvas:ring(x + S * 0.5, y + S * 0.5, S * 0.44, S * 0.1, layer + 0.1, C.marker, 36, 20)
            else
                canvas:circle(x + S * 0.5, y + S * 0.5, S * 0.16, layer + 0.1, C.marker, 36, 1, 0, 14)
            end
        end
    end

    -- Hover and keyboard cursor frames.
    local function frame(sq, color, alpha, w)
        local x, y = square_rect(b, sq, flipped)
        canvas:rect(x, y, S, w, layer + 0.12, color, alpha)
        canvas:rect(x, y + S - w, S, w, layer + 0.12, color, alpha)
        canvas:rect(x, y, w, S, layer + 0.12, color, alpha)
        canvas:rect(x + S - w, y, w, S, layer + 0.12, color, alpha)
    end
    local drag_sq, drag_x, drag_y = game:drag_piece()
    local hover = game:hover()
    if hover and (drag_sq or (selected and game:targets()[hover])) then frame(hover, C.hover, 190, 3) end
    local cursor, visible = game:cursor()
    if visible and cursor then frame(cursor, C.cursor, 230 + math_sin(time * 6) * 25, 3) end

    -- Pieces: resting ones first, then moving and dragged ones on top.
    local actors = game:actors()
    local moving = nil
    for i = 1, #actors do
        local a = actors[i]
        if a.alive and a.alpha > 0.01 then
            local px, py = board_point(b, a.x, a.z, flipped)
            local busy = a.anim ~= "idle" or math_abs(a.x - math_floor(a.x) - 0.5) > 0.01 or math_abs(a.z - math_floor(a.z) - 0.5) > 0.01
            if drag_sq and a.sq == drag_sq then
                Board2D.draw_piece(canvas, a.kind, a.side, px, py, S, layer + 0.2, 90)
            elseif busy then
                moving = moving or {}
                moving[#moving + 1] = a
            else
                Board2D.draw_piece(canvas, a.kind, a.side, px, py, S, layer + 0.2, 255 * a.alpha)
            end
        end
    end
    if moving then
        for i = 1, #moving do
            local a = moving[i]
            local px, py = board_point(b, a.x, a.z, flipped)
            Board2D.draw_piece(canvas, a.kind, a.side, px, py, S, layer + 0.5, 255 * a.alpha)
        end
    end
    if drag_sq then
        local a = game:actor_at(drag_sq)
        if a then
            Board2D.draw_piece(canvas, a.kind, a.side, drag_x - S * 0.55, drag_y - S * 0.6, S * 1.1, layer + 0.8, 255)
        end
    end

    -- Capture flashes.
    for i = 1, #self._flashes do
        local f = self._flashes[i]
        local k = f.t / 0.4
        canvas:ring(f.x, f.y, S * (0.2 + k * 0.5), S * 0.08 * (1 - k), layer + 1.1, C.spark, 220 * (1 - k), 20)
    end
    for i = 1, #self._sparks do
        local p = self._sparks[i]
        canvas:rect(p.x - 1.5, p.y - 1.5, 3, 3, layer + 1.2, C.spark, 255 * (1 - p.t / p.life))
    end

    self:_draw_panel(canvas, text, game, layer)
end

function Board2D:_draw_panel(canvas, text, game, layer)
    local P = game:layout().panel2d
    canvas:rect(P.x, P.y, P.w, P.h, layer - 0.5, C.panel)
    canvas:rect(P.x, P.y, P.w, 1, layer - 0.45, C.panel_edge)

    local material = count_captured(game)
    local bottom_side = game:board_flipped() and "b" or "w"
    local top_side = bottom_side == "w" and "b" or "w"
    local human = game:human_side()
    local turn = game:position():turn()

    local function name_of(side)
        if game:two_players() then return side == "w" and "White" or "Black" end
        if side == human then return "You" end
        return "Computer (Lv " .. game:level() .. ")"
    end

    local function plate(side, y)
        local x = P.x + 8
        if turn == side and not game:is_over() then
            canvas:rect(P.x + 2, y + 5, 3, 14, layer - 0.4, C.turn)
        end
        text:draw(name_of(side), x, y, P.w - 12, 24, 12, C.text, "left", layer - 0.3)
        -- this side's trophies are the opponent's lost pieces
        local list = side == "w" and captured_b or captured_w
        local s = 17
        local per_row = math_max(1, math_floor((P.w - 12) / (s * 0.62)))
        for i = 1, #list do
            local col = (i - 1) % per_row
            local row = math_floor((i - 1) / per_row)
            Board2D.draw_piece(canvas, list[i], side == "w" and "b" or "w", x + col * s * 0.62 - 2, y + 22 + row * (s + 1), s, layer - 0.2, 255)
        end
        local diff = material[side] - material[side == "w" and "b" or "w"]
        if diff > 0 then
            local rows = math_floor((math_max(1, #list) - 1) / per_row) + 1
            text:draw("+" .. diff, x, y + 24 + rows * (s + 1), P.w - 12, 16, 11, C.text_dim, "left", layer - 0.3)
        end
    end

    plate(top_side, P.y + 6)
    plate(bottom_side, P.y + P.h - 110)

    local last = game:last_san()
    if last and last ~= "" then
        text:draw("Last move", P.x + 8, P.y + P.h * 0.5 - 22, P.w - 12, 16, 11, C.text_dim, "left", layer - 0.3)
        text:draw(last, P.x + 8, P.y + P.h * 0.5 - 6, P.w - 12, 20, 14, C.text, "left", layer - 0.3)
    end
end

return Board2D
