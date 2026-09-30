-- Battle Chess characters: low-poly rigs (spearman, mounted knight, cleric, stone golem, sorceress,
-- king), their palettes and every animation (idle, walk, hop, attacks, deaths, cheers). Pure Lua.
local mod = get_mod("MourningstarWaitingGames")
local D3 = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/BattleChess_3d")

local math_abs = math.abs
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_sin = math.sin

local PI = math_pi
local HALF_PI = math_pi * 0.5

local Figures = {}

-- All figures are drawn a little larger than modelled so they fill their squares.
local SCALE = 1.12
Figures.SCALE = SCALE

-- Materials ------------------------------------------------------------------------------------------

local BODY, METAL, ACCENT, TRIM, SKIN, WOOD, DARK, HAIR = 1, 2, 3, 4, 5, 6, 7, 8
local STONE, GLOW, LEATHER, FUR, HORSE, CLOTH2, BLADE, STONE_DARK = 9, 10, 11, 12, 13, 14, 15, 16

Figures.PALETTES = {
    w = {
        { 234, 224, 198, 0.05 }, { 178, 188, 206, 0.55 }, { 46, 88, 204, 0.12 }, { 240, 186, 60, 0.65 },
        { 238, 190, 150 }, { 146, 98, 56 }, { 28, 24, 30 }, { 222, 176, 96 },
        { 186, 192, 204, 0.08 }, { 150, 225, 255, 0, true }, { 132, 88, 52 }, { 248, 248, 240 },
        { 240, 234, 222, 0.05 }, { 196, 204, 228 }, { 226, 234, 246, 0.95 }, { 132, 140, 158 },
    },
    b = {
        { 74, 70, 80, 0.08 }, { 98, 100, 112, 0.5 }, { 196, 30, 36, 0.12 }, { 190, 138, 60, 0.55 },
        { 214, 176, 154 }, { 96, 64, 44 }, { 12, 10, 12 }, { 44, 40, 44 },
        { 96, 92, 102, 0.05 }, { 255, 90, 40, 0, true }, { 66, 48, 40 }, { 210, 206, 200 },
        { 62, 58, 62, 0.08 }, { 120, 40, 52 }, { 184, 190, 204, 0.85 }, { 64, 60, 70 },
    },
}

-- Mesh helpers ------------------------------------------------------------------------------------------

local function box(m, x0, y0, z0, x1, y1, z1, mat, skip_bottom, top_mat)
    m:box(x0, y0, z0, x1, y1, z1, mat, skip_bottom, top_mat)
end

-- Square prism along y (4-sided lathe), optional per-band materials.
local function limb(m, profile, mat, cap_bottom, mats, sx, sz)
    m:lathe(0, 0, profile, 4, mat, cap_bottom, false, PI * 0.25, sx, sz, mats)
end

local function flat(m, mat, ...)
    m:flat({ ... }, mat)
end

-- Ring of flat spikes (crown points).
local function crown(m, y0, r, h, n, mat, phase)
    for i = 0, n - 1 do
        local a = (phase or HALF_PI) + i / n * PI * 2
        local c, s = math_cos(a), math_sin(a)
        local w = 0.022
        m:flat({ c * r - s * w, y0, s * r + c * w, c * r + s * w, y0, s * r - c * w, c * r * 1.02, y0 + h, s * r * 1.02 }, mat)
    end
end

local function eyes(m, y, z, half_w, h)
    flat(m, DARK, -half_w, y, z, half_w, y, z, half_w, y + h, z, -half_w, y + h, z)
end

local function heater_shield(m, x, s)
    m:transform(x, 0, 0.02, 0, -0.45, 0, s)
    -- rim then face then emblem, each a little further out
    flat(m, TRIM, 0, 0.11, -0.095, 0, 0.11, 0.095, 0, -0.03, 0.095, 0, -0.14, 0, 0, -0.03, -0.095)
    flat(m, ACCENT, -0.006, 0.098, -0.082, -0.006, 0.098, 0.082, -0.006, -0.03, 0.082, -0.006, -0.125, 0, -0.006, -0.03, -0.082)
    flat(m, TRIM, -0.012, 0.075, -0.014, -0.012, 0.075, 0.014, -0.012, -0.09, 0.014, -0.012, -0.09, -0.014)
    flat(m, TRIM, -0.012, 0.0, -0.06, -0.012, 0.0, 0.06, -0.012, 0.026, 0.06, -0.012, 0.026, -0.06)
    m:transform()
end

-- Rigs --------------------------------------------------------------------------------------------------
-- Each part: name, parent, pivot (in the parent's frame), mesh. Figures stand on y = 0 facing +z with
-- the right hand at +x. Parts are listed parent first.

local function part(list, name, parent, px, py, pz, mesh)
    list[#list + 1] = { name = name, parent = parent, px = px, py = py, pz = pz, mesh = mesh }
end

local function arm_mesh(mat, flare)
    local m = D3.mesh()
    limb(m, { flare or 0.04, -0.2, 0.045, 0.02 }, mat, true)
    return m
end

local builders = {}

builders.p = function()
    local parts = {}
    local body = D3.mesh()
    body:frustum(0, 0, -0.07, 0.22, 0.15, 0.07, 0.19, 0.13, ACCENT, true)
    part(parts, "body", "root", 0, 0.28, 0, body)

    local leg = D3.mesh()
    leg:frustum(0, 0.005, -0.21, 0.075, 0.09, 0.0, 0.07, 0.075, LEATHER, true)
    part(parts, "leg_r", "body", 0.055, -0.07, 0, leg)
    part(parts, "leg_l", "body", -0.055, -0.07, 0, leg)

    local torso = D3.mesh()
    torso:frustum(0, 0, 0, 0.19, 0.12, 0.19, 0.23, 0.13, BODY, true)
    flat(torso, ACCENT, -0.03, 0.0, 0.063, 0.03, 0.0, 0.063, 0.03, 0.18, 0.068, -0.03, 0.18, 0.068)
    flat(torso, ACCENT, -0.03, 0.0, -0.063, 0.03, 0.0, -0.063, 0.03, 0.18, -0.068, -0.03, 0.18, -0.068)
    part(parts, "torso", "body", 0, 0.07, 0, torso)

    local head = D3.mesh()
    box(head, -0.062, 0, -0.058, 0.062, 0.115, 0.062, SKIN, true)
    eyes(head, 0.06, 0.064, 0.042, 0.018)
    head:lathe(0, 0, { 0.145, 0.072, 0.074, 0.1, 0.0, 0.2 }, 6, METAL, false, false, PI / 6)
    flat(head, METAL, -0.012, 0.03, 0.066, 0.012, 0.03, 0.066, 0.012, 0.1, 0.07, -0.012, 0.1, 0.07)
    part(parts, "head", "torso", 0, 0.19, 0, head)

    part(parts, "arm_r", "torso", 0.135, 0.17, 0, arm_mesh(BODY))
    local spear = D3.mesh()
    limb(spear, { 0.014, -0.28, 0.014, 0.56 }, WOOD)
    spear:spike({ -0.024, 0.56, -0.024, 0.024, 0.56, -0.024, 0.024, 0.56, 0.024, -0.024, 0.56, 0.024 }, 0, 0.72, 0, BLADE)
    flat(spear, ACCENT, 0, 0.53, 0.012, 0, 0.44, 0.012, 0, 0.5, 0.14)
    part(parts, "weapon", "arm_r", 0, -0.2, 0.02, spear)

    part(parts, "arm_l", "torso", -0.135, 0.17, 0, arm_mesh(BODY))
    local shield = D3.mesh()
    heater_shield(shield, -0.055, 1)
    part(parts, "item", "arm_l", 0, -0.1, 0, shield)
    return parts
end

builders.n = function()
    local parts = {}
    local horse = D3.mesh()
    horse:frustum(0, -0.01, -0.08, 0.18, 0.46, 0.1, 0.19, 0.47, HORSE, true)
    horse:frustum(0, -0.03, -0.02, 0.23, 0.28, 0.1, 0.21, 0.26, ACCENT, true)
    horse:frustum(0, 0.17, 0.02, 0.11, 0.14, 0.29, 0.08, 0.1, HORSE, true, 0, 0.09)
    horse:transform(0, 0.31, 0.31, 1.0, 0, 0)
    box(horse, -0.047, -0.055, -0.1, 0.047, 0.055, 0.11, HORSE)
    box(horse, -0.05, -0.01, -0.03, 0.05, 0.06, 0.09, METAL, true)
    horse:transform()
    flat(horse, HORSE, -0.035, 0.36, 0.26, -0.02, 0.43, 0.24, -0.005, 0.36, 0.25)
    flat(horse, HORSE, 0.035, 0.36, 0.26, 0.02, 0.43, 0.24, 0.005, 0.36, 0.25)
    flat(horse, HAIR, 0, 0.38, 0.24, 0, 0.12, 0.12, 0, 0.1, 0.08, 0, 0.32, 0.2)
    horse:spike({ -0.03, 0.07, -0.23, 0.03, 0.07, -0.23, 0.03, 0.03, -0.23, -0.03, 0.03, -0.23 }, 0, -0.2, -0.33, HAIR)
    box(horse, -0.13, 0.08, -0.08, 0.13, 0.16, 0.07, METAL, true)
    part(parts, "body", "root", 0, 0.36, 0, horse)

    local leg = D3.mesh()
    limb(leg, { 0.03, -0.31, 0.036, 0.0 }, HORSE)
    part(parts, "leg_fr", "body", 0.06, -0.05, 0.17, leg)
    part(parts, "leg_fl", "body", -0.06, -0.05, 0.17, leg)
    part(parts, "leg_r", "body", 0.06, -0.05, -0.17, leg)
    part(parts, "leg_l", "body", -0.06, -0.05, -0.17, leg)

    local torso = D3.mesh()
    torso:frustum(0, 0, 0, 0.19, 0.12, 0.2, 0.23, 0.13, METAL, true)
    flat(torso, ACCENT, -0.045, 0.0, 0.064, 0.045, 0.0, 0.064, 0.04, 0.17, 0.068, -0.04, 0.17, 0.068)
    flat(torso, ACCENT, -0.045, 0.0, -0.064, 0.045, 0.0, -0.064, 0.04, 0.17, -0.068, -0.04, 0.17, -0.068)
    part(parts, "torso", "body", 0, 0.15, -0.02, torso)

    local head = D3.mesh()
    head:frustum(0, 0, 0, 0.13, 0.13, 0.15, 0.14, 0.14, METAL, true)
    flat(head, DARK, -0.055, 0.075, 0.072, 0.055, 0.075, 0.072, 0.055, 0.095, 0.072, -0.055, 0.095, 0.072)
    flat(head, TRIM, -0.008, 0.02, 0.073, 0.008, 0.02, 0.073, 0.008, 0.15, 0.073, -0.008, 0.15, 0.073)
    head:frustum(0, 0.0, 0.15, 0.035, 0.07, 0.34, 0.025, 0.16, ACCENT, true, 0, -0.09)
    part(parts, "head", "torso", 0, 0.2, 0, head)

    part(parts, "arm_r", "torso", 0.135, 0.17, 0, arm_mesh(METAL))
    local sword = D3.mesh()
    box(sword, -0.009, 0.02, -0.024, 0.009, 0.44, 0.024, BLADE, true)
    box(sword, -0.06, 0.0, -0.013, 0.06, 0.024, 0.013, TRIM, false)
    part(parts, "weapon", "arm_r", 0, -0.2, 0.02, sword)

    part(parts, "arm_l", "torso", -0.135, 0.17, 0, arm_mesh(METAL))
    local shield = D3.mesh()
    heater_shield(shield, -0.055, 0.9)
    part(parts, "item", "arm_l", 0, -0.1, 0, shield)
    return parts
end

builders.b = function()
    local parts = {}
    local robe = D3.mesh()
    robe:lathe(0, 0, { 0.175, -0.37, 0.168, -0.31, 0.118, 0.0 }, 6, BODY, false, false, 0, 1, 0.9, { TRIM, BODY })
    flat(robe, ACCENT, -0.038, -0.3, 0.132, 0.038, -0.3, 0.132, 0.03, -0.01, 0.098, -0.03, -0.01, 0.098)
    part(parts, "body", "root", 0, 0.37, 0, robe)

    local foot = D3.mesh()
    box(foot, -0.03, -0.07, -0.02, 0.03, 0.0, 0.1, LEATHER, true)
    part(parts, "leg_r", "body", 0.05, -0.3, 0.02, foot)
    part(parts, "leg_l", "body", -0.05, -0.3, 0.02, foot)

    local torso = D3.mesh()
    torso:frustum(0, 0, -0.01, 0.2, 0.13, 0.19, 0.22, 0.13, CLOTH2, true)
    torso:frustum(0, 0, 0.09, 0.28, 0.18, 0.2, 0.2, 0.14, ACCENT, false)
    part(parts, "torso", "body", 0, 0, 0, torso)

    local head = D3.mesh()
    box(head, -0.06, 0, -0.056, 0.06, 0.11, 0.06, SKIN, true)
    eyes(head, 0.06, 0.062, 0.04, 0.016)
    flat(head, FUR, -0.055, 0.042, 0.063, 0.055, 0.042, 0.063, 0.0, -0.06, 0.07)
    head:frustum(0, 0, 0.1, 0.13, 0.1, 0.33, 0.025, 0.065, BODY, true)
    flat(head, TRIM, -0.011, 0.12, 0.054, 0.011, 0.12, 0.054, 0.006, 0.28, 0.036, -0.006, 0.28, 0.036)
    flat(head, TRIM, -0.042, 0.19, 0.048, 0.042, 0.19, 0.048, 0.04, 0.215, 0.045, -0.04, 0.215, 0.045)
    part(parts, "head", "torso", 0, 0.19, 0, head)

    part(parts, "arm_r", "torso", 0.13, 0.17, 0, arm_mesh(CLOTH2, 0.062))
    local mace = D3.mesh()
    limb(mace, { 0.012, -0.06, 0.012, 0.23 }, WOOD)
    mace:octa(0, 0.28, 0, 0.06, 0.07, METAL, 5)
    part(parts, "weapon", "arm_r", 0, -0.2, 0.02, mace)

    part(parts, "arm_l", "torso", -0.13, 0.17, 0, arm_mesh(CLOTH2, 0.062))
    local crozier = D3.mesh()
    limb(crozier, { 0.012, -0.34, 0.012, 0.62 }, TRIM)
    -- crook: a flat hook curling outwards
    local hook = { 0, 0.6, -0.02, 0.73, -0.07, 0.78, -0.13, 0.75, -0.14, 0.68, -0.11, 0.64 }
    local t = 0.013
    for i = 1, #hook / 2 - 1 do
        local x1, y1, x2, y2 = hook[i * 2 - 1], hook[i * 2], hook[i * 2 + 1], hook[i * 2 + 2]
        flat(crozier, TRIM, x1 - t, y1, 0, x1 + t, y1 + t * 0.5, 0, x2 + t, y2 + t * 0.5, 0, x2 - t, y2, 0)
    end
    part(parts, "item", "arm_l", 0, -0.2, 0.02, crozier)
    return parts
end

builders.r = function()
    local parts = {}
    local hips = D3.mesh()
    box(hips, -0.15, -0.07, -0.1, 0.15, 0.08, 0.1, STONE, true)
    part(parts, "body", "root", 0, 0.25, 0, hips)

    local leg = D3.mesh()
    leg:frustum(0, 0, -0.21, 0.15, 0.17, 0.0, 0.12, 0.13, STONE_DARK, true)
    part(parts, "leg_r", "body", 0.09, -0.04, 0, leg)
    part(parts, "leg_l", "body", -0.09, -0.04, 0, leg)

    local torso = D3.mesh()
    torso:frustum(0, 0, 0, 0.34, 0.22, 0.3, 0.48, 0.28, STONE, true)
    flat(torso, GLOW, 0, 0.08, 0.128, 0.045, 0.15, 0.134, 0, 0.22, 0.14, -0.045, 0.15, 0.134)
    flat(torso, STONE_DARK, -0.2, 0.17, 0.139, -0.05, 0.12, 0.134, -0.05, 0.135, 0.135, -0.2, 0.19, 0.14)
    flat(torso, STONE_DARK, 0.06, 0.06, 0.13, 0.18, 0.09, 0.133, 0.18, 0.105, 0.134, 0.06, 0.075, 0.131)
    part(parts, "torso", "body", 0, 0.07, 0, torso)

    local head = D3.mesh()
    box(head, -0.125, 0, -0.115, 0.125, 0.13, 0.115, STONE, true)
    flat(head, GLOW, -0.08, 0.06, 0.117, -0.03, 0.06, 0.117, -0.03, 0.085, 0.117, -0.08, 0.085, 0.117)
    flat(head, GLOW, 0.03, 0.06, 0.117, 0.08, 0.06, 0.117, 0.08, 0.085, 0.117, 0.03, 0.085, 0.117)
    for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        local x, z = c[1] * 0.085, c[2] * 0.075
        box(head, x - 0.04, 0.13, z - 0.04, x + 0.04, 0.2, z + 0.04, STONE, true)
    end
    part(parts, "head", "torso", 0, 0.3, -0.01, head)

    local arm = D3.mesh()
    arm:frustum(0, 0, -0.25, 0.12, 0.13, 0.04, 0.15, 0.16, STONE, true)
    box(arm, -0.088, -0.4, -0.09, 0.088, -0.24, 0.09, STONE_DARK)
    part(parts, "arm_r", "torso", 0.265, 0.25, 0, arm)
    part(parts, "arm_l", "torso", -0.265, 0.25, 0, arm)
    return parts
end

builders.q = function()
    local parts = {}
    local gown = D3.mesh()
    gown:lathe(0, 0, { 0.21, -0.43, 0.18, -0.33, 0.098, 0.0 }, 7, BODY, false, false, PI / 14, 1, 1, { ACCENT, BODY })
    part(parts, "body", "root", 0, 0.43, 0, gown)

    local torso = D3.mesh()
    torso:frustum(0, 0, 0, 0.15, 0.1, 0.19, 0.2, 0.12, ACCENT, true)
    flat(torso, ACCENT, -0.07, 0.15, -0.055, 0.07, 0.15, -0.055, 0.12, 0.3, -0.075, 0.0, 0.33, -0.09, -0.12, 0.3, -0.075)
    part(parts, "torso", "body", 0, 0, 0, torso)

    local head = D3.mesh()
    box(head, -0.054, 0, -0.05, 0.054, 0.118, 0.056, SKIN, true)
    eyes(head, 0.062, 0.058, 0.038, 0.016)
    box(head, -0.066, -0.1, -0.078, 0.066, 0.132, -0.022, HAIR, true)
    box(head, -0.066, 0.1, -0.03, 0.066, 0.135, 0.04, HAIR, true)
    head:lathe(0, 0.0, { 0.066, 0.12, 0.072, 0.155 }, 6, TRIM, false, false, 0)
    crown(head, 0.15, 0.07, 0.085, 5, TRIM)
    part(parts, "head", "torso", 0, 0.19, 0, head)

    part(parts, "arm_r", "torso", 0.115, 0.17, 0, arm_mesh(BODY, 0.072))
    local staff = D3.mesh()
    limb(staff, { 0.012, -0.34, 0.012, 0.5 }, TRIM)
    staff:octa(0, 0.57, 0, 0.055, 0.065, GLOW, 5)
    flat(staff, TRIM, -0.05, 0.5, 0, 0.05, 0.5, 0, 0.0, 0.58, 0)
    part(parts, "weapon", "arm_r", 0, -0.2, 0.02, staff)

    part(parts, "arm_l", "torso", -0.115, 0.17, 0, arm_mesh(BODY, 0.072))
    return parts
end

builders.k = function()
    local parts = {}
    local robe = D3.mesh()
    robe:lathe(0, 0, { 0.195, -0.35, 0.185, -0.28, 0.13, 0.0 }, 6, ACCENT, false, false, 0, 1, 0.92, { FUR, ACCENT })
    flat(robe, TRIM, -0.02, -0.28, 0.15, 0.02, -0.28, 0.15, 0.02, -0.01, 0.107, -0.02, -0.01, 0.107)
    part(parts, "body", "root", 0, 0.35, 0, robe)

    local foot = D3.mesh()
    box(foot, -0.032, -0.07, -0.02, 0.032, 0.0, 0.1, LEATHER, true)
    part(parts, "leg_r", "body", 0.055, -0.29, 0.02, foot)
    part(parts, "leg_l", "body", -0.055, -0.29, 0.02, foot)

    local torso = D3.mesh()
    torso:frustum(0, 0, -0.01, 0.22, 0.14, 0.21, 0.25, 0.15, BODY, true)
    torso:frustum(0, 0, 0.14, 0.31, 0.2, 0.235, 0.2, 0.15, FUR, false)
    flat(torso, ACCENT, -0.15, 0.2, -0.085, 0.15, 0.2, -0.085, 0.22, -0.31, -0.2, -0.22, -0.31, -0.2)
    part(parts, "torso", "body", 0, 0, 0, torso)

    local head = D3.mesh()
    box(head, -0.058, 0, -0.054, 0.058, 0.118, 0.058, SKIN, true)
    eyes(head, 0.066, 0.06, 0.04, 0.016)
    box(head, -0.058, -0.055, 0.015, 0.058, 0.045, 0.074, HAIR, true)
    head:lathe(0, 0.0, { 0.072, 0.1, 0.08, 0.16 }, 6, TRIM, false, false, 0)
    crown(head, 0.155, 0.078, 0.07, 5, TRIM)
    head:octa(0, 0.24, 0, 0.022, 0.03, ACCENT, 4)
    part(parts, "head", "torso", 0, 0.235, 0, head)

    part(parts, "arm_r", "torso", 0.14, 0.18, 0, arm_mesh(BODY, 0.05))
    local sword = D3.mesh()
    box(sword, -0.01, 0.02, -0.026, 0.01, 0.48, 0.026, BLADE, true)
    box(sword, -0.07, 0.0, -0.014, 0.07, 0.026, 0.014, TRIM, false)
    part(parts, "weapon", "arm_r", 0, -0.2, 0.02, sword)

    part(parts, "arm_l", "torso", -0.14, 0.18, 0, arm_mesh(BODY, 0.05))
    local orb = D3.mesh()
    orb:octa(0, 0.0, 0.05, 0.045, 0.05, TRIM, 5)
    flat(orb, TRIM, -0.006, 0.04, 0.05, 0.006, 0.04, 0.05, 0.006, 0.1, 0.05, -0.006, 0.1, 0.05)
    part(parts, "item", "arm_l", 0, -0.21, 0.02, orb)
    return parts
end

local rigs = {}

local function build_rig(kind)
    local parts = builders[kind]()
    local index = { root = 0 }
    local tris = 0
    for i = 1, #parts do
        local p = parts[i]
        index[p.name] = i
        p.parent_index = index[p.parent]
        local parent = parts[p.parent_index]
        p.rest_x = (parent and parent.rest_x or 0) + p.px
        p.rest_y = (parent and parent.rest_y or 0) + p.py
        p.rest_z = (parent and parent.rest_z or 0) + p.pz
        tris = tris + p.mesh.nf
    end
    return { parts = parts, index = index, tris = tris, kind = kind }
end

function Figures.rig(kind)
    local rig = rigs[kind]
    if not rig then
        rig = build_rig(kind)
        rigs[kind] = rig
    end
    return rig
end

function Figures.triangles(kind)
    return Figures.rig(kind).tris
end

-- Battle timing: attack length, the moment the blow lands, and how close the attacker stands.
Figures.ATTACK = {
    p = { dur = 1.3, hit = 0.55, reach = 0.62 },
    n = { dur = 1.5, hit = 0.8, reach = 0.7 },
    b = { dur = 1.4, hit = 0.62, reach = 0.5 },
    r = { dur = 1.6, hit = 0.86, reach = 0.78 },
    q = { dur = 1.6, hit = 0.95, reach = 1.45, cast = 0.72 },
    k = { dur = 1.4, hit = 0.62, reach = 0.56 },
}

Figures.DEATH = { fall = 1.8, dizzy = 2.2, squash = 1.5, ash = 1.7, crumble = 1.9, sparkle = 1.4 }
Figures.HEIGHT = { p = 0.8 * SCALE, n = 1.05 * SCALE, b = 0.95 * SCALE, r = 0.9 * SCALE, q = 1.05 * SCALE, k = 1.12 * SCALE }
Figures.NAMES = { p = "Pawn", n = "Knight", b = "Bishop", r = "Rook", q = "Queen", k = "King" }

-- The victim's end: golems crumble, queens vanish in sparkles, the queen's bolt burns to ash,
-- a golem's smash squashes, a mace bonk makes them dizzy, anything else knocks them over.
function Figures.death_style(attacker, victim)
    if victim == "r" then return "crumble" end
    if victim == "q" then return "sparkle" end
    if attacker == "q" then return "ash" end
    if attacker == "r" then return "squash" end
    if attacker == "b" then return "dizzy" end
    return "fall"
end

-- Poses ---------------------------------------------------------------------------------------------------

local JOINTS = { "body", "torso", "head", "arm_r", "arm_l", "weapon", "item", "leg_r", "leg_l", "leg_fr", "leg_fl" }

function Figures.new_pose()
    local pose = { root = {}, alpha = 1, tint = { 255, 255, 255 }, tint_k = 0, scatter = 0 }
    for i = 1, #JOINTS do pose[JOINTS[i]] = {} end
    return pose
end

local function reset(pose)
    local r = pose.root
    r.rx, r.ry, r.rz, r.dx, r.dy, r.dz, r.sx, r.sy, r.sz = 0, 0, 0, 0, 0, 0, 1, 1, 1
    for i = 1, #JOINTS do
        local j = pose[JOINTS[i]]
        j.rx, j.ry, j.rz, j.dx, j.dy, j.dz, j.s = 0, 0, 0, 0, 0, 0, 1
    end
    pose.alpha, pose.tint_k, pose.scatter = 1, 0, 0
end

local smooth = D3.smooth

local function lerp(a, b, t) return a + (b - a) * t end

local function seg(t, t0, t1)
    if t <= t0 then return 0 end
    if t >= t1 then return 1 end
    return (t - t0) / (t1 - t0)
end

local function set_tint(pose, r, g, b, k)
    local c = pose.tint
    c[1], c[2], c[3] = r, g, b
    pose.tint_k = k
end

-- Keeps a held item pointing at `net` (rotation about x relative to the torso).
local function hold(pose, arm, item, net)
    pose[item].rx = net - pose[arm].rx
end

local REST = {
    p = function(p) p.arm_r.rx = -0.3; p.arm_r.rz = 0.08; hold(p, "arm_r", "weapon", 0.02); p.arm_l.rx = -0.25; p.arm_l.rz = -0.12 end,
    n = function(p) p.arm_r.rx = -0.45; p.arm_r.rz = 0.3; hold(p, "arm_r", "weapon", 0.1); p.weapon.rz = -0.2; p.arm_l.rx = -0.45; p.arm_l.rz = -0.15 end,
    b = function(p) p.arm_r.rx = -0.25; p.arm_r.rz = 0.12; hold(p, "arm_r", "weapon", 0.25); p.arm_l.rx = -0.35; p.arm_l.rz = -0.1; hold(p, "arm_l", "item", 0) end,
    r = function(p) p.arm_r.rz = 0.14; p.arm_l.rz = -0.14; p.arm_r.rx = -0.1; p.arm_l.rx = -0.1; p.head.dy = -0.02 end,
    q = function(p) p.arm_r.rx = -0.4; p.arm_r.rz = 0.12; hold(p, "arm_r", "weapon", 0); p.arm_l.rx = -0.2; p.arm_l.rz = -0.25 end,
    k = function(p) p.arm_r.rx = -0.35; p.arm_r.rz = 0.1; hold(p, "arm_r", "weapon", 0.35); p.arm_l.rx = -0.55; p.arm_l.rz = -0.1; hold(p, "arm_l", "item", 0.55) end,
}

local function idle(kind, pose, tt)
    local breathe = math_sin(tt * 1.9)
    pose.torso.rx = pose.torso.rx + breathe * 0.025
    pose.head.ry = math_sin(tt * 0.53) * 0.22 * math_max(0, math_sin(tt * 0.21))
    pose.arm_r.rx = pose.arm_r.rx + breathe * 0.03
    pose.arm_l.rx = pose.arm_l.rx - breathe * 0.03
    if kind == "q" then
        pose.root.dy = 0.012 + math_sin(tt * 1.3) * 0.01
    elseif kind == "r" then
        pose.torso.dy = breathe * 0.006
        pose.arm_r.rz = pose.arm_r.rz + breathe * 0.03
        pose.arm_l.rz = pose.arm_l.rz - breathe * 0.03
    elseif kind == "n" then
        pose.head.ry = pose.head.ry * 0.6
        pose.leg_fl.rx = math_max(0, math_sin(tt * 0.37)) ^ 8 * -0.5
    end
end

local STRIDE = { p = 0.5, n = 0.85, b = 0.42, r = 0.62, q = 0.5, k = 0.45 }

local function walk(kind, pose, dist, amount)
    local ph = dist / STRIDE[kind] * PI * 2
    local s, c = math_sin(ph), math_cos(ph)
    local k = amount or 1
    if kind == "n" then
        pose.leg_fr.rx, pose.leg_l.rx = s * 0.55 * k, s * 0.5 * k
        pose.leg_fl.rx, pose.leg_r.rx = -s * 0.55 * k, -s * 0.5 * k
        pose.body.dy = math_abs(c) * 0.025 * k
        pose.body.rx = c * 0.04 * k
        pose.torso.rx = pose.torso.rx - math_abs(c) * 0.05 * k
    elseif kind == "r" then
        pose.leg_r.rx, pose.leg_l.rx = s * 0.45 * k, -s * 0.45 * k
        pose.body.rz = s * 0.1 * k
        pose.body.dy = -math_abs(s) * 0.03 * k
        pose.torso.rz = -s * 0.05 * k
        pose.arm_r.rx = pose.arm_r.rx - s * 0.3 * k
        pose.arm_l.rx = pose.arm_l.rx + s * 0.3 * k
        pose.torso.rx = 0.12 * k
    else
        local legs = (kind == "p") and 0.6 or 0.45
        pose.leg_r.rx, pose.leg_l.rx = s * legs * k, -s * legs * k
        pose.body.dy = math_abs(c) * 0.018 * k
        pose.torso.ry = s * 0.08 * k
        local swing = (kind == "p" or kind == "k") and 0.28 or 0.4
        pose.arm_l.rx = pose.arm_l.rx + s * swing * k
        if kind ~= "p" then pose.arm_r.rx = pose.arm_r.rx - s * swing * 0.6 * k end
        if kind == "q" or kind == "b" or kind == "k" then
            pose.body.rz = s * 0.035 * k
            pose.body.rx = 0.03 * k
        end
    end
end

local function hop(pose, k)
    pose.leg_fr.rx, pose.leg_fl.rx = -1.1, -1.25
    pose.leg_r.rx, pose.leg_l.rx = 0.7, 0.8
    pose.root.rx = -0.35 * math_cos(k * PI)
    pose.torso.rx = 0.15
    pose.arm_r.rx = pose.arm_r.rx - 0.6
    pose.arm_l.rx = pose.arm_l.rx - 0.3
    local land = seg(k, 0.85, 1)
    if land > 0 then
        local f = 1 - land
        pose.leg_fr.rx, pose.leg_fl.rx = pose.leg_fr.rx * f, pose.leg_fl.rx * f
        pose.leg_r.rx, pose.leg_l.rx = pose.leg_r.rx * f, pose.leg_l.rx * f
    end
end

-- Attacks ------------------------------------------------------------------------------------------------

local attacks = {}

attacks.p = function(p, t)
    local k1 = smooth(seg(t, 0, 0.4))
    local k2 = seg(t, 0.4, 0.55)
    k2 = 1 - (1 - k2) * (1 - k2)
    local back = smooth(seg(t, 0.85, 1.3))
    local net = lerp(0.02, HALF_PI + 0.05, k1)
    local arm = lerp(-0.3, 0.45, k1)
    arm = lerp(arm, -1.35, k2)
    p.torso.ry = lerp(lerp(0, -0.4, k1), 0.3, k2)
    p.root.rx = lerp(-0.1 * k1, 0.14, k2)
    p.root.dz = 0.16 * k2
    p.leg_r.rx = -0.5 * k2
    p.leg_l.rx = 0.4 * k2
    p.arm_l.rx = lerp(-0.25, -0.9, k1)
    if back > 0 then
        arm = lerp(arm, -0.3, back)
        net = lerp(net, 0.02, back)
        p.torso.ry = lerp(p.torso.ry, 0, back)
        p.root.rx = lerp(p.root.rx, 0, back)
        p.root.dz = lerp(p.root.dz, 0, back)
        p.leg_r.rx, p.leg_l.rx = p.leg_r.rx * (1 - back), p.leg_l.rx * (1 - back)
        p.arm_l.rx = lerp(p.arm_l.rx, -0.25, back)
    end
    p.arm_r.rx = arm
    hold(p, "arm_r", "weapon", net)
end

attacks.n = function(p, t)
    local rear = math_sin(PI * seg(t, 0, 0.75))
    p.root.rx = -0.5 * rear + 0.1 * math_sin(PI * seg(t, 0.75, 1.0))
    p.root.dz = -0.06 * rear
    local kick = rear * (0.6 + 0.4 * math_sin(t * 22))
    p.leg_fr.rx = -1.2 * kick
    p.leg_fl.rx = -1.2 * rear * (0.6 + 0.4 * math_sin(t * 22 + 2))
    p.leg_r.rx, p.leg_l.rx = 0.25 * rear, 0.25 * rear
    local raise = smooth(seg(t, 0.05, 0.5))
    local slash = seg(t, 0.62, 0.8)
    slash = 1 - (1 - slash) * (1 - slash)
    local back = smooth(seg(t, 1.0, 1.5))
    local arm = lerp(lerp(-0.55, -2.9, raise), -0.5, slash)
    local net = lerp(lerp(0.7, -0.5, raise), 1.8, slash)
    p.torso.rx = lerp(-0.2 * raise, 0.3, slash)
    p.torso.ry = lerp(-0.25 * raise, 0.2, slash)
    arm = lerp(arm, -0.55, back)
    net = lerp(net, 0.7, back)
    p.torso.rx = lerp(p.torso.rx, 0, back)
    p.torso.ry = lerp(p.torso.ry, 0, back)
    p.arm_r.rx = arm
    hold(p, "arm_r", "weapon", net)
end

attacks.b = function(p, t)
    local raise = smooth(seg(t, 0, 0.45))
    local smash = seg(t, 0.47, 0.62)
    smash = smash * smash
    local back = smooth(seg(t, 0.95, 1.4))
    local arm = lerp(lerp(-0.25, -2.75, raise), -0.75, smash)
    local net = lerp(lerp(0.25, -0.75, raise), 1.75, smash)
    p.torso.rx = lerp(-0.22 * raise, 0.32, smash)
    p.root.dy = 0.05 * math_sin(PI * seg(t, 0.3, 0.62))
    p.arm_l.rx = lerp(-0.35, -0.8, raise)
    hold(p, "arm_l", "item", 0)
    arm = lerp(arm, -0.25, back)
    net = lerp(net, 0.25, back)
    p.torso.rx = lerp(p.torso.rx, 0, back)
    p.arm_r.rx = arm
    hold(p, "arm_r", "weapon", net)
end

attacks.r = function(p, t)
    local raise = smooth(seg(t, 0, 0.55))
    local slam = seg(t, 0.62, 0.86)
    slam = slam * slam
    local back = smooth(seg(t, 1.15, 1.6))
    local arm = lerp(lerp(-0.1, -2.95, raise), -0.45, slam)
    p.arm_r.rx, p.arm_l.rx = arm, arm
    p.arm_r.rz, p.arm_l.rz = lerp(0.14, 0.3, raise), lerp(-0.14, -0.3, raise)
    p.torso.rx = lerp(-0.28 * raise, 0.5, slam)
    p.root.dy = 0.14 * math_sin(PI * seg(t, 0.55, 0.86))
    p.root.dz = 0.22 * slam
    p.leg_r.rx, p.leg_l.rx = -0.3 * math_sin(PI * seg(t, 0.55, 0.86)), 0.3 * math_sin(PI * seg(t, 0.55, 0.86))
    if back > 0 then
        p.arm_r.rx = lerp(arm, -0.1, back)
        p.arm_l.rx = p.arm_r.rx
        p.arm_r.rz, p.arm_l.rz = lerp(p.arm_r.rz, 0.14, back), lerp(p.arm_l.rz, -0.14, back)
        p.torso.rx = lerp(p.torso.rx, 0, back)
        p.root.dz = lerp(p.root.dz, 0, back)
    end
end

attacks.q = function(p, t)
    local rise = smooth(seg(t, 0, 0.5))
    local cast = seg(t, 0.62, 0.78)
    local down = smooth(seg(t, 1.1, 1.6))
    local lift = rise * (1 - down)
    p.root.dy = 0.14 * lift + math_sin(t * 6) * 0.01 * lift
    p.arm_r.rx = lerp(lerp(-0.4, -2.2, rise), -1.45, cast)
    p.arm_l.rx = lerp(-0.2, -1.7, rise)
    p.arm_l.rz = lerp(-0.25, -0.7, rise)
    local net = lerp(lerp(0, 0.2, rise), 1.1, cast)
    p.torso.rx = lerp(-0.15 * rise, 0.18, cast)
    p.head.rx = -0.15 * rise
    if down > 0 then
        p.arm_r.rx = lerp(p.arm_r.rx, -0.4, down)
        p.arm_l.rx = lerp(p.arm_l.rx, -0.2, down)
        p.arm_l.rz = lerp(p.arm_l.rz, -0.25, down)
        net = lerp(net, 0, down)
        p.torso.rx = lerp(p.torso.rx, 0, down)
    end
    hold(p, "arm_r", "weapon", net)
end

attacks.k = function(p, t)
    local raise = smooth(seg(t, 0, 0.4))
    local strike = seg(t, 0.44, 0.62)
    strike = 1 - (1 - strike) * (1 - strike)
    local back = smooth(seg(t, 0.95, 1.4))
    local arm = lerp(lerp(-0.35, -2.9, raise), -0.55, strike)
    local net = lerp(lerp(0.35, -0.15, raise), 1.7, strike)
    p.arm_r.rz = lerp(0.1, 0.45, raise) * (1 - strike) + 0.05
    p.torso.ry = lerp(-0.35 * raise, 0.35, strike)
    p.root.dz = 0.12 * strike
    p.leg_r.rx = -0.4 * strike
    arm = lerp(arm, -0.35, back)
    net = lerp(net, 0.35, back)
    p.torso.ry = lerp(p.torso.ry, 0, back)
    p.root.dz = lerp(p.root.dz, 0, back)
    p.leg_r.rx = p.leg_r.rx * (1 - back)
    p.arm_r.rx = arm
    hold(p, "arm_r", "weapon", net)
end

-- Deaths ----------------------------------------------------------------------------------------------------

local function hash(i, salt)
    local v = math_sin(i * 12.9898 + salt * 78.233) * 43758.5453
    return v - math_floor(v)
end

local function fade(pose, t, t0, t1)
    pose.alpha = 1 - seg(t, t0, t1)
end

local function recoil(p, t)
    local k = math_sin(PI * seg(t, 0, 0.35))
    p.torso.rx = p.torso.rx - 0.35 * k
    p.head.rx = -0.3 * k
    p.arm_r.rx = p.arm_r.rx - 1.4 * k
    p.arm_l.rx = p.arm_l.rx - 1.4 * k
    p.arm_r.rz = p.arm_r.rz + 0.5 * k
    p.arm_l.rz = p.arm_l.rz - 0.5 * k
end

local deaths = {}

deaths.fall = function(p, t)
    recoil(p, t)
    local f = seg(t, 0.18, 0.72)
    f = f * f
    local bounce = math_sin(PI * seg(t, 0.72, 0.95)) * 0.12
    p.root.rx = -HALF_PI * f + bounce
    p.root.dz = -0.12 * f
    p.leg_r.rx, p.leg_l.rx = -0.4 * f, -0.2 * f
    fade(p, t, 1.2, 1.8)
end

deaths.dizzy = function(p, t)
    local w = 1 - seg(t, 0.2, 1.1)
    local spin = t * 9
    if t < 1.1 then
        p.root.rz = math_sin(spin) * 0.22 * w
        p.root.rx = math_cos(spin) * 0.16 * w
        p.head.ry = t * 14
        p.head.rz = math_sin(spin * 1.3) * 0.3
        p.arm_r.rx = p.arm_r.rx - 0.8 + math_sin(spin * 2) * 0.5
        p.arm_l.rx = p.arm_l.rx - 0.8 - math_sin(spin * 2) * 0.5
        p.arm_r.rz = p.arm_r.rz + 0.6
        p.arm_l.rz = p.arm_l.rz - 0.6
    end
    local f = seg(t, 1.1, 1.5)
    f = f * f
    p.root.rx = p.root.rx + HALF_PI * f - math_sin(PI * seg(t, 1.5, 1.7)) * 0.1
    p.arm_r.rx = p.arm_r.rx - 2 * f
    p.arm_l.rx = p.arm_l.rx - 2 * f
    fade(p, t, 1.7, 2.2)
end

deaths.squash = function(p, t)
    local k = seg(t, 0, 0.08)
    local wobble = math_sin(t * 30) * 0.06 * (1 - seg(t, 0.08, 0.6))
    local sy = lerp(1, 0.2, k) + wobble
    local sxz = lerp(1, 1.55, k) - wobble
    p.root.sy, p.root.sx, p.root.sz = sy, sxz, sxz
    p.arm_r.rz = p.arm_r.rz + 1.2 * k
    p.arm_l.rz = p.arm_l.rz - 1.2 * k
    fade(p, t, 0.95, 1.5)
end

deaths.ash = function(p, t)
    local zap = 1 - seg(t, 0.25, 0.9)
    local jitter = math_sin(t * 71) * 0.12 * zap
    p.root.rz = jitter
    p.arm_r.rz = p.arm_r.rz + 1.1 * zap + jitter
    p.arm_l.rz = p.arm_l.rz - 1.1 * zap + jitter
    p.head.rx = -0.4 * zap
    if t < 0.3 then
        set_tint(p, 255, 255, 230, 0.85)
    else
        set_tint(p, 30, 24, 22, math_min(1, 0.4 + seg(t, 0.3, 0.7)))
    end
    local crumble = seg(t, 0.9, 1.5)
    p.root.sy = 1 - 0.85 * crumble * crumble
    p.root.sx = 1 + 0.35 * crumble
    p.root.sz = p.root.sx
    fade(p, t, 1.15, 1.7)
end

deaths.crumble = function(p, t, rig)
    local jolt = math_sin(PI * seg(t, 0, 0.15)) * 0.1
    p.root.rz = jolt
    local tt = t - 0.15
    if tt > 0 then
        p.scatter = 1
        local parts = rig.parts
        for i = 1, #parts do
            local name = parts[i].name
            local j = p[name]
            if j then
                local vx = (hash(i, 1) - 0.5) * 0.9
                local vz = (hash(i, 2) - 0.5) * 0.9
                local vy = 0.3 + hash(i, 3) * 0.7
                local floor_y = -parts[i].rest_y + 0.06
                local land = (vy + (vy * vy + 2 * 4 * -floor_y) ^ 0.5) / 4
                local te = math_min(tt, land)
                j.dx = j.dx + vx * te
                j.dz = j.dz + vz * te
                j.dy = j.dy + vy * te - 2 * te * te
                j.rx = j.rx + (hash(i, 4) - 0.5) * 6 * te
                j.rz = j.rz + (hash(i, 5) - 0.5) * 6 * te
            end
        end
    end
    fade(p, t, 1.3, 1.9)
end

deaths.sparkle = function(p, t)
    local k = seg(t, 0.05, 1.2)
    p.root.ry = k * k * 18
    p.root.dy = 0.35 * k
    local s = 1 - smooth(seg(t, 0.35, 1.25))
    p.root.sx, p.root.sy, p.root.sz = s, s, s
    p.arm_r.rz = p.arm_r.rz + 1.2 * k
    p.arm_l.rz = p.arm_l.rz - 1.2 * k
    set_tint(p, 255, 240, 200, 0.7 * k)
    fade(p, t, 1.0, 1.4)
end

-- Other scripted moments --------------------------------------------------------------------------------

local function topple(p, t)
    local f = seg(t, 0.1, 1.0)
    f = f * f
    p.root.rz = HALF_PI * 0.96 * f - math_sin(PI * seg(t, 1.0, 1.25)) * 0.12
    p.arm_r.rz = p.arm_r.rz + 0.8 * f
    p.arm_l.rz = p.arm_l.rz - 0.8 * f
    p.head.rz = 0.3 * f
end

local function cheer(kind, p, t)
    local s = math_sin(t * 8)
    p.root.dy = math_abs(s) * 0.07
    if kind == "n" then
        p.root.rx = -0.25 * math_abs(s)
        p.leg_fr.rx, p.leg_fl.rx = -0.8 * math_abs(s), -0.8 * math_abs(math_sin(t * 8 + 0.6))
        p.arm_r.rx = -2.8
        hold(p, "arm_r", "weapon", -0.2)
        return
    end
    p.arm_r.rx = -2.6 + s * 0.3
    p.arm_l.rx = -2.6 - s * 0.3
    p.arm_r.rz = p.arm_r.rz + 0.35
    p.arm_l.rz = p.arm_l.rz - 0.35
    if p.weapon then hold(p, "arm_r", "weapon", -0.1) end
end

local function promote(p, t)
    local k = seg(t, 0, 1)
    p.root.ry = k * k * 16
    local s = t < 0.5 and lerp(1, 0.35, smooth(t / 0.5)) or lerp(0.35, 1, smooth((t - 0.5) / 0.5))
    p.root.sx, p.root.sy, p.root.sz = s, s, s
    p.root.dy = 0.25 * math_sin(PI * k)
    set_tint(p, 255, 235, 150, 0.8 * math_sin(PI * k))
end

-- actor: kind, anim, anim_t, walk, hop, style, id; time drives idle motion.
function Figures.animate(actor, pose, time)
    local kind = actor.kind
    reset(pose)
    REST[kind](pose)
    local anim = actor.anim or "idle"
    local t = actor.anim_t or 0
    local tt = (time or 0) + (actor.id or 0) * 1.37
    if anim == "idle" then
        idle(kind, pose, tt)
    elseif anim == "walk" then
        idle(kind, pose, tt)
        walk(kind, pose, actor.walk or 0, actor.walk_k or 1)
    elseif anim == "hop" then
        hop(pose, actor.hop or 0)
    elseif anim == "attack" then
        attacks[kind](pose, t)
    elseif anim == "die" then
        local fn = deaths[actor.style] or deaths.fall
        fn(pose, t, Figures.rig(kind))
    elseif anim == "topple" then
        topple(pose, t)
    elseif anim == "cheer" then
        cheer(kind, pose, t)
    elseif anim == "promote" then
        idle(kind, pose, tt)
        promote(pose, t)
    end
end

-- Drawing ---------------------------------------------------------------------------------------------------

local root_m = D3.mat()
local local_m = D3.mat()
local part_m = {}
for i = 1, 16 do part_m[i] = D3.mat() end

-- Draws the actor's rig. actor: x, y, z, yaw, side, alpha (0..1); pose from Figures.animate.
function Figures.draw(renderer, actor, pose, palette, alpha_mul)
    local rig = Figures.rig(actor.kind)
    local r = pose.root
    local yaw = actor.yaw or 0
    local cy, sy = math_cos(yaw), math_sin(yaw)
    local dx, dz = r.dx, r.dz
    D3.mat_set(root_m, actor.x + cy * dx + sy * dz, (actor.y or 0) + r.dy, actor.z - sy * dx + cy * dz,
        r.rx, yaw + r.ry, r.rz, r.sx * SCALE, r.sy * SCALE, r.sz * SCALE)

    local alpha = 255 * pose.alpha * (actor.alpha or 1) * (alpha_mul or 1)
    if alpha < 1 then return end
    palette = palette or Figures.PALETTES[actor.side] or Figures.PALETTES.w
    local tint = pose.tint_k > 0 and pose.tint or actor.tint
    local tint_k = pose.tint_k > 0 and pose.tint_k or (actor.tint_k or 0)
    local parts = rig.parts
    for i = 1, #parts do
        local p = parts[i]
        local j = pose[p.name]
        local parent = p.parent_index == 0 and root_m or part_m[p.parent_index]
        if pose.scatter > 0 and j then
            -- scattered pieces move independently of their parents
            parent = root_m
            D3.mat_set(local_m, p.rest_x + j.dx, p.rest_y + j.dy, p.rest_z + j.dz, j.rx, j.ry, j.rz, j.s, j.s, j.s)
        elseif j then
            D3.mat_set(local_m, p.px + j.dx, p.py + j.dy, p.pz + j.dz, j.rx, j.ry, j.rz, j.s, j.s, j.s)
        else
            D3.mat_set(local_m, p.px, p.py, p.pz, 0, 0, 0, 1, 1, 1)
        end
        local m = D3.mat_mul(part_m[i], parent, local_m)
        renderer:mesh(p.mesh, m, palette, alpha, 0, tint, tint_k)
    end
end

-- World position of a point in a part's frame for the current pose (e.g. the queen's orb).
function Figures.part_point(actor, pose, name, x, y, z)
    local rig = Figures.rig(actor.kind)
    local index = rig.index[name]
    if not index then return actor.x, (actor.y or 0) + 0.5, actor.z end
    local r = pose.root
    local yaw = actor.yaw or 0
    local cy, sy = math_cos(yaw), math_sin(yaw)
    D3.mat_set(root_m, actor.x + cy * r.dx + sy * r.dz, (actor.y or 0) + r.dy, actor.z - sy * r.dx + cy * r.dz,
        r.rx, yaw + r.ry, r.rz, r.sx * SCALE, r.sy * SCALE, r.sz * SCALE)
    local parts = rig.parts
    for i = 1, index do
        local p = parts[i]
        local j = pose[p.name]
        local parent = p.parent_index == 0 and root_m or part_m[p.parent_index]
        D3.mat_set(local_m, p.px + j.dx, p.py + j.dy, p.pz + j.dz, j.rx, j.ry, j.rz, j.s, j.s, j.s)
        D3.mat_mul(part_m[i], parent, local_m)
    end
    return D3.mat_point(part_m[index], x or 0, y or 0, z or 0)
end

Figures.MATERIALS = {
    BODY = BODY, METAL = METAL, ACCENT = ACCENT, TRIM = TRIM, SKIN = SKIN, WOOD = WOOD, DARK = DARK, HAIR = HAIR,
    STONE = STONE, GLOW = GLOW, LEATHER = LEATHER, FUR = FUR, HORSE = HORSE, CLOTH2 = CLOTH2, BLADE = BLADE,
    STONE_DARK = STONE_DARK,
}
Figures.lerp = lerp
Figures.seg = seg

return Figures
