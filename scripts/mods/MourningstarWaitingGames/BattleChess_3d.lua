-- Tiny software 3D pipeline for Battle Chess: 3x4 matrices, a mesh builder, an orbit camera and a
-- painter's renderer that submits flat-shaded triangles to the canvas in back-to-front order.
-- Pure Lua (no engine globals) so the game logic can use the camera for picking.
local math_atan2 = math.atan2
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_sin = math.sin
local math_sqrt = math.sqrt
local math_tan = math.tan

local TAU = math_pi * 2

local D3 = {}

-- Matrices ------------------------------------------------------------------------------------
-- { xx, xy, xz, tx,  yx, yy, yz, ty,  zx, zy, zz, tz }: rows of a rotation/scale plus translation.

function D3.mat(out)
    out = out or {}
    out[1], out[2], out[3], out[4] = 1, 0, 0, 0
    out[5], out[6], out[7], out[8] = 0, 1, 0, 0
    out[9], out[10], out[11], out[12] = 0, 0, 1, 0
    return out
end

-- out = T(tx, ty, tz) * Ry(ry) * Rx(rx) * Rz(rz) * S(sx, sy, sz)
function D3.mat_set(out, tx, ty, tz, rx, ry, rz, sx, sy, sz)
    local cx, sx_ = math_cos(rx or 0), math_sin(rx or 0)
    local cy, sy_ = math_cos(ry or 0), math_sin(ry or 0)
    local cz, sz_ = math_cos(rz or 0), math_sin(rz or 0)
    sx = sx or 1
    sy = sy or sx
    sz = sz or sx
    out[1] = (cy * cz + sy_ * sx_ * sz_) * sx
    out[2] = (-cy * sz_ + sy_ * sx_ * cz) * sy
    out[3] = sy_ * cx * sz
    out[4] = tx or 0
    out[5] = cx * sz_ * sx
    out[6] = cx * cz * sy
    out[7] = -sx_ * sz
    out[8] = ty or 0
    out[9] = (-sy_ * cz + cy * sx_ * sz_) * sx
    out[10] = (sy_ * sz_ + cy * sx_ * cz) * sy
    out[11] = cy * cx * sz
    out[12] = tz or 0
    return out
end

-- out = a * b (apply b first). out may alias neither a nor b.
function D3.mat_mul(out, a, b)
    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 = a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12]
    local b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12 = b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12]
    out[1] = a1 * b1 + a2 * b5 + a3 * b9
    out[2] = a1 * b2 + a2 * b6 + a3 * b10
    out[3] = a1 * b3 + a2 * b7 + a3 * b11
    out[4] = a1 * b4 + a2 * b8 + a3 * b12 + a4
    out[5] = a5 * b1 + a6 * b5 + a7 * b9
    out[6] = a5 * b2 + a6 * b6 + a7 * b10
    out[7] = a5 * b3 + a6 * b7 + a7 * b11
    out[8] = a5 * b4 + a6 * b8 + a7 * b12 + a8
    out[9] = a9 * b1 + a10 * b5 + a11 * b9
    out[10] = a9 * b2 + a10 * b6 + a11 * b10
    out[11] = a9 * b3 + a10 * b7 + a11 * b11
    out[12] = a9 * b4 + a10 * b8 + a11 * b12 + a12
    return out
end

function D3.mat_point(m, x, y, z)
    return m[1] * x + m[2] * y + m[3] * z + m[4],
        m[5] * x + m[6] * y + m[7] * z + m[8],
        m[9] * x + m[10] * y + m[11] * z + m[12]
end

function D3.mat_dir(m, x, y, z)
    return m[1] * x + m[2] * y + m[3] * z, m[5] * x + m[6] * y + m[7] * z, m[9] * x + m[10] * y + m[11] * z
end

function D3.wrap_angle(a)
    a = (a + math_pi) % TAU
    return a - math_pi
end

-- Shortest signed difference b - a.
function D3.angle_delta(a, b)
    return D3.wrap_angle(b - a)
end

-- Mesh builder ----------------------------------------------------------------------------------
-- Faces carry a material index into the palette given at draw time. Closed primitives are oriented
-- from a hint direction so back-face culling works; flat pieces (capes, banners) are double sided.

local Mesh = {}
Mesh.__index = Mesh

function D3.mesh()
    return setmetatable({ nv = 0, x = {}, y = {}, z = {}, nf = 0, fa = {}, fb = {}, fc = {}, fm = {}, fd = {}, xf = nil }, Mesh)
end

-- Build transform applied to every vertex added afterwards; call with no arguments to reset.
function Mesh:transform(tx, ty, tz, rx, ry, rz, sx, sy, sz)
    if tx == nil then
        self.xf = nil
    else
        self.xf = D3.mat_set(self.xf or {}, tx, ty, tz, rx, ry, rz, sx, sy, sz)
    end
    return self
end

function Mesh:vert(x, y, z)
    local xf = self.xf
    if xf then x, y, z = D3.mat_point(xf, x, y, z) end
    local n = self.nv + 1
    self.nv = n
    self.x[n], self.y[n], self.z[n] = x, y, z
    return n
end

-- hx, hy, hz: rough outward direction in build space (before the build transform).
function Mesh:face(a, b, c, mat, hx, hy, hz, double)
    if not double and hx then
        local xf = self.xf
        if xf then hx, hy, hz = D3.mat_dir(xf, hx, hy, hz) end
        local X, Y, Z = self.x, self.y, self.z
        local e1x, e1y, e1z = X[b] - X[a], Y[b] - Y[a], Z[b] - Z[a]
        local e2x, e2y, e2z = X[c] - X[a], Y[c] - Y[a], Z[c] - Z[a]
        local nx = e1y * e2z - e1z * e2y
        local ny = e1z * e2x - e1x * e2z
        local nz = e1x * e2y - e1y * e2x
        if nx * hx + ny * hy + nz * hz < 0 then b, c = c, b end
    end
    local n = self.nf + 1
    self.nf = n
    self.fa[n], self.fb[n], self.fc[n], self.fm[n], self.fd[n] = a, b, c, mat, double and true or false
    return n
end

function Mesh:quad(a, b, c, d, mat, hx, hy, hz, double)
    self:face(a, b, c, mat, hx, hy, hz, double)
    self:face(a, c, d, mat, hx, hy, hz, double)
end

-- Tapered box: bottom w0 x d0 at y0 centred on (cx, cz), top w1 x d1 at y1 centred on (cx + ox, cz + oz).
function Mesh:frustum(cx, cz, y0, w0, d0, y1, w1, d1, mat, skip_bottom, ox, oz, top_mat)
    ox, oz = ox or 0, oz or 0
    local hw0, hd0, hw1, hd1 = w0 * 0.5, d0 * 0.5, w1 * 0.5, d1 * 0.5
    local b1 = self:vert(cx - hw0, y0, cz - hd0)
    local b2 = self:vert(cx + hw0, y0, cz - hd0)
    local b3 = self:vert(cx + hw0, y0, cz + hd0)
    local b4 = self:vert(cx - hw0, y0, cz + hd0)
    local tx, tz = cx + ox, cz + oz
    local t1 = self:vert(tx - hw1, y1, tz - hd1)
    local t2 = self:vert(tx + hw1, y1, tz - hd1)
    local t3 = self:vert(tx + hw1, y1, tz + hd1)
    local t4 = self:vert(tx - hw1, y1, tz + hd1)
    local up = y1 >= y0 and 1 or -1
    self:quad(b1, b2, t2, t1, mat, 0, 0, -1)
    self:quad(b2, b3, t3, t2, mat, 1, 0, 0)
    self:quad(b3, b4, t4, t3, mat, 0, 0, 1)
    self:quad(b4, b1, t1, t4, mat, -1, 0, 0)
    self:quad(t1, t2, t3, t4, top_mat or mat, 0, up, 0)
    if not skip_bottom then self:quad(b1, b2, b3, b4, mat, 0, -up, 0) end
end

function Mesh:box(x0, y0, z0, x1, y1, z1, mat, skip_bottom, top_mat)
    self:frustum((x0 + x1) * 0.5, (z0 + z1) * 0.5, y0, x1 - x0, z1 - z0, y1, x1 - x0, z1 - z0, mat, skip_bottom, 0, 0, top_mat)
end

-- Surface of revolution around the vertical axis through (cx, cz). profile = { r1, y1, r2, y2, ... }
-- traced bottom to top with the solid on the axis side; r = 0 makes an apex. sx / sz squash it.
function Mesh:lathe(cx, cz, profile, sides, mat, cap_bottom, cap_top, phase, sx, sz, mats)
    phase = phase or 0
    sx, sz = sx or 1, sz or 1
    local rings = {}
    local count = #profile / 2
    for i = 1, count do
        local r, y = profile[i * 2 - 1], profile[i * 2]
        local ring = {}
        if r <= 0 then
            ring.apex = self:vert(cx, y, cz)
        else
            for s = 1, sides do
                local a = phase + (s - 1) / sides * TAU
                ring[s] = self:vert(cx + math_cos(a) * r * sx, y, cz + math_sin(a) * r * sz)
            end
        end
        rings[i] = ring
    end
    for i = 1, count - 1 do
        local lo, hi = rings[i], rings[i + 1]
        local dr = profile[i * 2 + 1] - profile[i * 2 - 1]
        local dy = profile[i * 2 + 2] - profile[i * 2]
        local m = mats and mats[i] or mat
        for s = 1, sides do
            local s2 = s % sides + 1
            local a = phase + (s - 0.5) / sides * TAU
            local hx, hy, hz = math_cos(a) * dy, -dr, math_sin(a) * dy
            if lo.apex then
                self:face(lo.apex, hi[s2], hi[s], m, hx, hy, hz)
            elseif hi.apex then
                self:face(lo[s], lo[s2], hi.apex, m, hx, hy, hz)
            else
                self:quad(lo[s], lo[s2], hi[s2], hi[s], m, hx, hy, hz)
            end
        end
    end
    local first, last = rings[1], rings[count]
    if cap_bottom and not first.apex then
        for s = 2, sides - 1 do self:face(first[1], first[s], first[s + 1], mat, 0, -1, 0) end
    end
    if cap_top and not last.apex then
        for s = 2, sides - 1 do self:face(last[1], last[s], last[s + 1], cap_top == true and mat or cap_top, 0, 1, 0) end
    end
end

-- Flat double-sided polygon (convex fan) from { x1, y1, z1, x2, ... }.
function Mesh:flat(points, mat)
    local n = #points / 3
    local first = self:vert(points[1], points[2], points[3])
    local prev = self:vert(points[4], points[5], points[6])
    for i = 3, n do
        local v = self:vert(points[i * 3 - 2], points[i * 3 - 1], points[i * 3])
        self:face(first, prev, v, mat, nil, nil, nil, true)
        prev = v
    end
end

-- Closed pyramid over a triangle/quad base given as point list, apex at (ax, ay, az).
function Mesh:spike(base, ax, ay, az, mat, hx, hy, hz)
    local n = #base / 3
    local cxx, cyy, czz = 0, 0, 0
    local ids = {}
    for i = 1, n do
        ids[i] = self:vert(base[i * 3 - 2], base[i * 3 - 1], base[i * 3])
        cxx, cyy, czz = cxx + base[i * 3 - 2] / n, cyy + base[i * 3 - 1] / n, czz + base[i * 3] / n
    end
    local apex = self:vert(ax, ay, az)
    local ix, iy, iz = (cxx + ax) * 0.5, (cyy + ay) * 0.5, (czz + az) * 0.5
    for i = 1, n do
        local j = i % n + 1
        local fx = (base[i * 3 - 2] + base[j * 3 - 2] + ax) / 3
        local fy = (base[i * 3 - 1] + base[j * 3 - 1] + ay) / 3
        local fz = (base[i * 3] + base[j * 3] + az) / 3
        self:face(ids[i], ids[j], apex, mat, fx - ix, fy - iy, fz - iz)
    end
    for i = 2, n - 1 do self:face(ids[1], ids[i], ids[i + 1], mat, hx or (cxx - ax), hy or (cyy - ay), hz or (czz - az)) end
end

-- Double pyramid (gems, orbs, mace heads): radius r around (cx, cy, cz), half height h.
function Mesh:octa(cx, cy, cz, r, h, mat, sides)
    sides = sides or 4
    local top = self:vert(cx, cy + h, cz)
    local bottom = self:vert(cx, cy - h, cz)
    local ring = {}
    for s = 1, sides do
        local a = (s - 1) / sides * TAU
        ring[s] = self:vert(cx + math_cos(a) * r, cy, cz + math_sin(a) * r)
    end
    for s = 1, sides do
        local s2 = s % sides + 1
        local a = (s - 0.5) / sides * TAU
        local hx, hz = math_cos(a), math_sin(a)
        self:face(ring[s], ring[s2], top, mat, hx, 0.7, hz)
        self:face(ring[s], ring[s2], bottom, mat, hx, -0.7, hz)
    end
end

function Mesh:faces() return self.nf end

-- Camera ------------------------------------------------------------------------------------------

local Camera = {}
Camera.__index = Camera

function D3.camera()
    local cam = setmetatable({
        yaw = 0, pitch = 0.8, dist = 12, tx = 0, ty = 0, tz = 0, fov = 0.6,
        vx = 0, vy = 0, vw = 600, vh = 600, near = 0.08,
        view = D3.mat(),
    }, Camera)
    cam:update()
    return cam
end

function Camera:set_viewport(x, y, w, h)
    self.vx, self.vy, self.vw, self.vh = x, y, w, h
end

function Camera:copy_from(o)
    self.yaw, self.pitch, self.dist, self.tx, self.ty, self.tz, self.fov = o.yaw, o.pitch, o.dist, o.tx, o.ty, o.tz, o.fov
    self.vx, self.vy, self.vw, self.vh = o.vx, o.vy, o.vw, o.vh
    return self
end

-- Orbit: yaw 0 looks from -z towards +z (White's side), pitch lifts the camera above the target.
function Camera:update()
    local cy, sy = math_cos(self.yaw), math_sin(self.yaw)
    local cp, sp = math_cos(self.pitch), math_sin(self.pitch)
    local d = self.dist
    local ex = self.tx + sy * cp * d
    local ey = self.ty + sp * d
    local ez = self.tz - cy * cp * d
    self.ex, self.ey, self.ez = ex, ey, ez
    local fx, fy, fz = -sy * cp, -sp, cy * cp
    local rx, ry, rz = cy, 0, sy
    local ux = fy * rz - fz * ry
    local uy = fz * rx - fx * rz
    local uz = fx * ry - fy * rx
    local v = self.view
    v[1], v[2], v[3], v[4] = rx, ry, rz, -(rx * ex + ry * ey + rz * ez)
    v[5], v[6], v[7], v[8] = ux, uy, uz, -(ux * ex + uy * ey + uz * ez)
    v[9], v[10], v[11], v[12] = fx, fy, fz, -(fx * ex + fy * ey + fz * ez)
    self.F = self.vh * 0.5 / math_tan(self.fov * 0.5)
    self.cx = self.vx + self.vw * 0.5
    self.cy = self.vy + self.vh * 0.5
    return self
end

function Camera:to_view(x, y, z)
    local v = self.view
    return v[1] * x + v[2] * y + v[3] * z + v[4], v[5] * x + v[6] * y + v[7] * z + v[8], v[9] * x + v[10] * y + v[11] * z + v[12]
end

-- Returns screen x, y and view depth, or nil when behind the near plane.
function Camera:project(x, y, z)
    local xc, yc, zc = self:to_view(x, y, z)
    if zc <= self.near then return nil end
    return self.cx + self.F * xc / zc, self.cy - self.F * yc / zc, zc
end

-- Intersects the pointer ray with the horizontal plane y = h; returns world x, z or nil.
function Camera:unproject_plane(sx, sy, h)
    local xc = (sx - self.cx) / self.F
    local yc = -(sy - self.cy) / self.F
    local v = self.view
    -- ray direction in world space = R^T * (xc, yc, 1)
    local dx = v[1] * xc + v[5] * yc + v[9]
    local dy = v[2] * xc + v[6] * yc + v[10]
    local dz = v[3] * xc + v[7] * yc + v[11]
    if dy > -1e-6 and dy < 1e-6 then return nil end
    local t = ((h or 0) - self.ey) / dy
    if t <= 0 then return nil end
    return self.ex + dx * t, self.ez + dz * t
end

-- Point inside a convex quad given in either winding.
function D3.point_in_quad(px, py, x1, y1, x2, y2, x3, y3, x4, y4)
    local s1 = (x2 - x1) * (py - y1) - (y2 - y1) * (px - x1)
    local s2 = (x3 - x2) * (py - y2) - (y3 - y2) * (px - x2)
    local s3 = (x4 - x3) * (py - y3) - (y4 - y3) * (px - x3)
    local s4 = (x1 - x4) * (py - y4) - (y1 - y4) * (px - x4)
    return (s1 >= 0 and s2 >= 0 and s3 >= 0 and s4 >= 0) or (s1 <= 0 and s2 <= 0 and s3 <= 0 and s4 <= 0)
end

-- Renderer ------------------------------------------------------------------------------------------

local KEY_SPAN = 16384

local Renderer = {}
Renderer.__index = Renderer

function D3.renderer()
    local r = setmetatable({
        TX = {}, TY = {}, TZ = {}, SX = {}, SY = {},
        X1 = {}, Y1 = {}, X2 = {}, Y2 = {}, X3 = {}, Y3 = {},
        A = {}, R = {}, G = {}, B = {}, keys = {}, n = 0, keys_len = 0,
        submitted = 0, considered = 0,
        comb = D3.mat(),
        -- world-space direction towards the key light, its colour, a cool fill and ambient
        sun = { 0.42, 0.8, -0.43 }, sun_col = { 1.0, 0.86, 0.66 },
        fill = { -0.55, 0.35, 0.75 }, fill_col = { 0.22, 0.26, 0.38 },
        amb = { 0.34, 0.31, 0.33 },
        fog = { 28, 22, 22 }, fog_start = 14, fog_end = 40, fog_max = 0.85,
    }, Renderer)
    local s = r.sun
    local l = math_sqrt(s[1] * s[1] + s[2] * s[2] + s[3] * s[3])
    s[1], s[2], s[3] = s[1] / l, s[2] / l, s[3] / l
    s = r.fill
    l = math_sqrt(s[1] * s[1] + s[2] * s[2] + s[3] * s[3])
    s[1], s[2], s[3] = s[1] / l, s[2] / l, s[3] / l
    return r
end

function Renderer:begin(cam, clip_x0, clip_y0, clip_x1, clip_y1)
    self.cam = cam
    self.n = 0
    self.cx0 = clip_x0 or cam.vx
    self.cy0 = clip_y0 or cam.vy
    self.cx1 = clip_x1 or (cam.vx + cam.vw)
    self.cy1 = clip_y1 or (cam.vy + cam.vh)
    local v = cam.view
    local s, f = self.sun, self.fill
    self.lx, self.ly, self.lz = v[1] * s[1] + v[2] * s[2] + v[3] * s[3], v[5] * s[1] + v[6] * s[2] + v[7] * s[3], v[9] * s[1] + v[10] * s[2] + v[11] * s[3]
    self.fx, self.fy, self.fz = v[1] * f[1] + v[2] * f[2] + v[3] * f[3], v[5] * f[1] + v[6] * f[2] + v[7] * f[3], v[9] * f[1] + v[10] * f[2] + v[11] * f[3]
    self.fog_inv = 1 / math_max(0.001, self.fog_end - self.fog_start)
end

function Renderer:_push(x1, y1, x2, y2, x3, y3, depth, a, r, g, b)
    local n = self.n + 1
    if n >= KEY_SPAN then return end
    self.n = n
    self.X1[n], self.Y1[n], self.X2[n], self.Y2[n], self.X3[n], self.Y3[n] = x1, y1, x2, y2, x3, y3
    self.A[n], self.R[n], self.G[n], self.B[n] = a, r, g, b
    local d = 2000 - depth
    if d < 0 then d = 0 end
    self.keys[n] = math_floor(d * 256) * KEY_SPAN + n
end

-- palette[m] = { r, g, b, shine, emissive }. tint = { r, g, b } blended by tint_k; bias moves the
-- sort depth (negative = drawn later / in front).
function Renderer:mesh(mesh, M, palette, alpha, bias, tint, tint_k)
    local cam = self.cam
    local C = D3.mat_mul(self.comb, cam.view, M)
    local c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12 = C[1], C[2], C[3], C[4], C[5], C[6], C[7], C[8], C[9], C[10], C[11], C[12]
    local F, pcx, pcy, near = cam.F, cam.cx, cam.cy, cam.near
    local TX, TY, TZ, SX, SY = self.TX, self.TY, self.TZ, self.SX, self.SY
    local MX, MY, MZ = mesh.x, mesh.y, mesh.z

    for i = 1, mesh.nv do
        local x, y, z = MX[i], MY[i], MZ[i]
        local xc = c1 * x + c2 * y + c3 * z + c4
        local yc = c5 * x + c6 * y + c7 * z + c8
        local zc = c9 * x + c10 * y + c11 * z + c12
        TX[i], TY[i], TZ[i] = xc, yc, zc
        if zc > near then
            SX[i] = pcx + F * xc / zc
            SY[i] = pcy - F * yc / zc
        end
    end

    alpha = alpha or 255
    bias = bias or 0
    tint_k = tint_k or 0
    local tr, tg, tb = 0, 0, 0
    if tint and tint_k > 0 then tr, tg, tb = tint[1], tint[2], tint[3] else tint_k = 0 end
    local lx, ly, lz, fx, fy, fz = self.lx, self.ly, self.lz, self.fx, self.fy, self.fz
    local sun_col, fill_col, amb = self.sun_col, self.fill_col, self.amb
    local sr, sg, sb, flr, flg, flb, ar, ag, ab = sun_col[1], sun_col[2], sun_col[3], fill_col[1], fill_col[2], fill_col[3], amb[1], amb[2], amb[3]
    local fog, fog_start, fog_inv, fog_max = self.fog, self.fog_start, self.fog_inv, self.fog_max
    local cx0, cy0, cx1, cy1 = self.cx0, self.cy0, self.cx1, self.cy1
    local FA, FB, FC, FM, FD = mesh.fa, mesh.fb, mesh.fc, mesh.fm, mesh.fd
    local considered = self.considered

    for f = 1, mesh.nf do
        local a, b, c = FA[f], FB[f], FC[f]
        local za, zb, zc = TZ[a], TZ[b], TZ[c]
        if za > near and zb > near and zc > near then
            considered = considered + 1
            local ax, ay = TX[a], TY[a]
            local e1x, e1y, e1z = TX[b] - ax, TY[b] - ay, zb - za
            local e2x, e2y, e2z = TX[c] - ax, TY[c] - ay, zc - za
            local nx = e1y * e2z - e1z * e2y
            local ny = e1z * e2x - e1x * e2z
            local nz = e1x * e2y - e1y * e2x
            local visible = true
            if nx * ax + ny * ay + nz * za >= 0 then
                if FD[f] then nx, ny, nz = -nx, -ny, -nz else visible = false end
            end
            if visible then
                local x1, y1, x2, y2, x3, y3 = SX[a], SY[a], SX[b], SY[b], SX[c], SY[c]
                local minx, maxx, miny, maxy = x1, x1, y1, y1
                if x2 < minx then minx = x2 elseif x2 > maxx then maxx = x2 end
                if x3 < minx then minx = x3 elseif x3 > maxx then maxx = x3 end
                if y2 < miny then miny = y2 elseif y2 > maxy then maxy = y2 end
                if y3 < miny then miny = y3 elseif y3 > maxy then maxy = y3 end
                local area = (x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1)
                if maxx >= cx0 and minx <= cx1 and maxy >= cy0 and miny <= cy1 and (area > 0.25 or area < -0.25) then
                    local mat = palette[FM[f]]
                    local r, g, bb = mat[1], mat[2], mat[3]
                    if not mat[5] then
                        local inv = 1 / math_sqrt(nx * nx + ny * ny + nz * nz)
                        local d1 = (nx * lx + ny * ly + nz * lz) * inv
                        local d2 = (nx * fx + ny * fy + nz * fz) * inv
                        if d1 < 0 then d1 = 0 end
                        if d2 < 0 then d2 = 0 end
                        local spec = 0
                        local shine = mat[4]
                        if shine and d1 > 0.55 then
                            local k = (d1 - 0.55) * 2.2
                            spec = shine * k * k * 255
                        end
                        r = r * (ar + sr * d1 + flr * d2) + spec
                        g = g * (ag + sg * d1 + flg * d2) + spec
                        bb = bb * (ab + sb * d1 + flb * d2) + spec
                    end
                    if tint_k > 0 then
                        r = r + (tr - r) * tint_k
                        g = g + (tg - g) * tint_k
                        bb = bb + (tb - bb) * tint_k
                    end
                    local depth = (za + zb + zc) * 0.3333333
                    local fk = (depth - fog_start) * fog_inv
                    if fk > 0 then
                        if fk > fog_max then fk = fog_max end
                        r = r + (fog[1] - r) * fk
                        g = g + (fog[2] - g) * fk
                        bb = bb + (fog[3] - bb) * fk
                    end
                    self:_push(x1, y1, x2, y2, x3, y3, depth + bias, alpha, r, g, bb)
                end
            end
        end
    end
    self.considered = considered
end

-- Unlit world-space triangle (markers, shadows, beams). Skipped when any corner is behind the camera.
function Renderer:tri(x1, y1, z1, x2, y2, z2, x3, y3, z3, a, r, g, b, bias)
    local cam = self.cam
    local sx1, sy1, d1 = cam:project(x1, y1, z1)
    if not sx1 then return end
    local sx2, sy2, d2 = cam:project(x2, y2, z2)
    if not sx2 then return end
    local sx3, sy3, d3 = cam:project(x3, y3, z3)
    if not sx3 then return end
    self:_push(sx1, sy1, sx2, sy2, sx3, sy3, (d1 + d2 + d3) * 0.3333333 + (bias or 0), a, r, g, b)
end

function Renderer:quad(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4, a, r, g, b, bias)
    self:tri(x1, y1, z1, x2, y2, z2, x3, y3, z3, a, r, g, b, bias)
    self:tri(x1, y1, z1, x3, y3, z3, x4, y4, z4, a, r, g, b, bias)
end

-- Flat ellipse on the plane y = h (blob shadows, glows on the board).
function Renderer:disc(x, h, z, rx, rz, segments, a, r, g, b, bias)
    local cam = self.cam
    local cxs, cys, cd = cam:project(x, h, z)
    if not cxs then return end
    local px, py
    for i = 0, segments do
        local ang = i / segments * TAU
        local sx, sy = cam:project(x + math_cos(ang) * rx, h, z + math_sin(ang) * rz)
        if not sx then return end
        if px then self:_push(cxs, cys, px, py, sx, sy, cd + (bias or 0), a, r, g, b) end
        px, py = sx, sy
    end
end

-- Camera-facing soft glow (stacked translucent discs) sorted with the scene at its depth.
function Renderer:glow(x, y, z, radius, a, r, g, b, steps, segments, bias)
    local cam = self.cam
    local sx, sy, d = cam:project(x, y, z)
    if not sx then return end
    local rad = cam.F * radius / d
    if rad < 0.6 or sx + rad < self.cx0 or sx - rad > self.cx1 or sy + rad < self.cy0 or sy - rad > self.cy1 then return end
    steps = steps or 3
    segments = segments or 12
    local per = a / steps
    local depth = d + (bias or 0)
    for s = steps, 1, -1 do
        local rr = rad * (s / steps) ^ 1.3
        local px, py = sx + rr, sy
        for i = 1, segments do
            local ang = i / segments * TAU
            local qx, qy = sx + math_cos(ang) * rr, sy + math_sin(ang) * rr
            self:_push(sx, sy, px, py, qx, qy, depth, per, r, g, b)
            px, py = qx, qy
        end
    end
end

function Renderer:count() return self.n end

-- Sorts (back to front) and submits everything collected since the last flush.
function Renderer:flush(canvas, layer, unsorted)
    local n = self.n
    local keys = self.keys
    for i = n + 1, self.keys_len do keys[i] = nil end
    self.keys_len = n
    if not unsorted and n > 1 then table.sort(keys) end
    local X1, Y1, X2, Y2, X3, Y3, A, R, G, B = self.X1, self.Y1, self.X2, self.Y2, self.X3, self.Y3, self.A, self.R, self.G, self.B
    for k = 1, n do
        local i = unsorted and k or keys[k] % KEY_SPAN
        canvas:tri_raw(X1[i], Y1[i], X2[i], Y2[i], X3[i], Y3[i], layer, A[i], R[i], G[i], B[i])
    end
    self.submitted = self.submitted + n
    self.n = 0
    return n
end

-- Drops collected faces without drawing (used by tests and when the canvas is unavailable).
function Renderer:discard()
    self.n = 0
end

function Renderer:reset_stats()
    self.submitted = 0
    self.considered = 0
end

D3.TAU = TAU
D3.clamp = function(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
D3.lerp = function(a, b, t) return a + (b - a) * t end
D3.smooth = function(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return t * t * (3 - 2 * t)
end
D3.atan2 = math_atan2
D3.min, D3.max = math_min, math_max

return D3
