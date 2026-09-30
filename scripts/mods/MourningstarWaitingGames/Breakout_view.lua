local mod = get_mod("MourningstarWaitingGames")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local AuspexFrame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_auspex_frame")
local Gfx = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_canvas")
local Win95 = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/MourningstarWaitingGames_win95")

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_sin = math.sin

local RENDER_SIZE = 600
local TEXT_POOL = 40
local TEXT_PREFIX = "bo_text_"
local TRAIL = 6

local C = {
    field = { 255, 0, 128, 128 },
    brick = { 255, 255, 0, 0 },
    brick_edge = { 255, 128, 0, 0 },
    tough = { 255, 176, 0, 0 },
    tough_edge = { 255, 90, 0, 0 },
    crack = { 255, 60, 0, 0 },
    white = { 255, 255, 255, 255 },
    paddle_edge = { 255, 128, 128, 128 },
    shard = { 255, 255, 40, 20 },
    spark = { 255, 255, 255, 210 },
    text_black = Win95.C.text_black,
    text_red = { 255, 200, 0, 0 },
    shadow = { 255, 0, 60, 60 },
    black = { 255, 0, 0, 0 },
}

local HINT = "Mouse / A D move   Click / Space launch   Right click / E pause   R new   Tab menu   Esc back"
local HOW_TO = {
    "Knock out every brick with the ball.",
    "Keep the ball in play with the paddle; where it",
    "hits the paddle decides the angle it bounces off.",
    "Dark bricks need two hits. The ball speeds up",
    "with every brick, and each level starts faster.",
    "You have three balls.",
    "Mouse: move to steer, click to launch.",
    "Keys: A/D or arrows move (Shift faster), Space",
    "launches, E pauses, R starts a new game.",
}
local CRT_OPTS = {
    tint = { 255, 225, 255, 250 }, scan_alpha = 12, sweep_alpha = 10, vignette_depth = 60, vignette_alpha = 110,
    noise_count = 6, noise_alpha = 25, flicker = false,
}

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

local BreakoutView = class("BreakoutView", "BaseView")

local function draw_icon(canvas, cx, cy, size, layer)
    local s = size / 14
    for row = 0, 1 do
        for col = 0, 2 do
            canvas:rect(cx - 7 * s + col * 5 * s, cy - 7 * s + row * 3 * s, 4 * s, 2 * s, layer, C.brick)
        end
    end
    canvas:rect(cx - 4 * s, cy + 5 * s, 8 * s, 2 * s, layer, C.white)
    canvas:rect(cx - 1 * s, cy + 1 * s, 2 * s, 2 * s, layer, C.white)
end

local DESKTOP_OPTS = { app = "Breakout", icon = draw_icon, clock = "" }
local WINDOW_OPTS = { title = "Breakout", icon = draw_icon }

function BreakoutView:init(settings, context)
    BreakoutView.super.init(self, definitions, settings, context)

    self._game = context.game
    self._no_cursor = false
    self._canvas = Gfx.Canvas.new(RENDER_SIZE, RENDER_SIZE, 14000)
    self._canvas:set_layer_scale(10)
    self._particles = Gfx.Particles.new(240)
    self._shaker = Gfx.Shaker.new()
    self._text = Win95.text_pool(self, TEXT_PREFIX, TEXT_POOL)
    self._time = 0
    self._trail = {}
    self._trail_head = 0
    self._paddle_flash = 0
    self._banner = nil
    self._banner_t = 0
    self._floats = {}
    self._dialog_cb = function(c, D, dialog, pool, tt) self:_dialog_content(c, D, dialog, pool, tt) end
end

function BreakoutView:dialogue_system() return nil end
function BreakoutView:is_using_input() return false end

function BreakoutView:update(dt, t, input_service)
    if self._game then self._game:update(dt) end
    return BreakoutView.super.update(self, dt, t, input_service)
end

-- Input -----------------------------------------------------------------------------------------

local function input_value(input_service, action)
    if not input_service or not input_service.get then return false end
    local ok, value = pcall(input_service.get, input_service, action)
    if not ok then return false end
    return value == true or (type(value) == "number" and value > 0)
end

function BreakoutView:_process_pointer(input_service, ui_renderer, base)
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

-- Events -------------------------------------------------------------------------------------------

function BreakoutView:_float(value, x, y)
    local floats = self._floats
    floats[#floats + 1] = { text = value, x = x, y = y, t = 0 }
    if #floats > 8 then table.remove(floats, 1) end
end

function BreakoutView:_handle_events(client)
    local ox, oy = client.x, client.y
    local particles = self._particles
    self._game:drain_events(function(kind, x, y, value)
        if kind == "new" then
            particles:clear()
            self._floats = {}
            self._banner, self._banner_t = "Level 1", 1.4
        elseif kind == "brick" then
            particles:burst(ox + x, oy + y, 14, 40, 190, 0.3, 0.7, 3.2, C.shard, "shard", 1.5, 420)
            particles:burst(ox + x, oy + y, 6, 30, 110, 0.15, 0.3, 1.4, C.spark, "spark", 3)
            self:_float("+" .. value, ox + x, oy + y)
            self._shaker:add(0.05)
        elseif kind == "crack" then
            particles:burst(ox + x, oy + y, 6, 30, 120, 0.2, 0.4, 2, C.shard, "shard", 1.5, 420)
        elseif kind == "paddle" then
            self._paddle_flash = 1
            particles:burst(ox + x, oy + y, 5, 20, 90, 0.15, 0.3, 1.2, C.white, "spark", 3)
        elseif kind == "wall" then
            particles:burst(ox + x, oy + y, 3, 10, 60, 0.1, 0.2, 1, C.white, "spark", 4)
        elseif kind == "lost" then
            self._shaker:add(0.6)
            particles:burst(ox + x, oy + y - 4, 18, 40, 200, 0.3, 0.8, 1.6, C.white, "spark", 2, 200, -math.pi * 0.5, 1.4)
            self._trail_head = 0
            if value > 0 then self._banner, self._banner_t = value == 1 and "Last ball!" or (value .. " balls left"), 1.1 end
        elseif kind == "cleared" then
            self._banner, self._banner_t = "Level cleared!", 1.6
            self._shaker:add(0.3)
        elseif kind == "level" then
            self._banner, self._banner_t = "Level " .. value, 1.3
        elseif kind == "launch" then
            self._trail_head = 0
        end
    end)
end

-- Drawing -------------------------------------------------------------------------------------------

function BreakoutView:_draw_field(canvas, client)
    canvas:rect(client.x, client.y, client.w, client.h, 3.05, C.field)
end

function BreakoutView:_draw_bricks(canvas, client)
    local ox, oy = client.x, client.y
    local bricks = self._game:bricks()
    for i = 1, #bricks do
        local b = bricks[i]
        if b.alive then
            local tough = b.max_hits > 1
            local x, y = ox + b.x, oy + b.y
            canvas:rect(x, y, b.w, b.h, 4, tough and C.tough_edge or C.brick_edge)
            canvas:rect(x + 1, y + 1, b.w - 2, b.h - 2, 4, tough and C.tough or C.brick)
            if tough and b.hits < b.max_hits then
                canvas:rect(x + b.w * 0.3, y + 2, 1, b.h * 0.5, 4, C.crack)
                canvas:rect(x + b.w * 0.3, y + b.h * 0.5, b.w * 0.25, 1, 4, C.crack)
                canvas:rect(x + b.w * 0.55, y + b.h * 0.5, 1, b.h * 0.4, 4, C.crack)
            end
        end
    end
end

function BreakoutView:_draw_paddle(canvas, client)
    local game = self._game
    local px, py, pw, ph = game:paddle()
    local x, y = client.x + px, client.y + py
    canvas:rect(x, y, pw, ph, 4.2, C.paddle_edge)
    canvas:rect(x + 1, y + 1, pw - 2, ph - 2, 4.2, C.white)
    if self._paddle_flash > 0 then
        canvas:soft_rect(x, y, pw, ph, 5, 4.25, C.white, 90 * self._paddle_flash, 3)
    end
end

function BreakoutView:_draw_ball(canvas, client)
    local game = self._game
    local bx, by, r = game:ball()
    local x, y = client.x + bx, client.y + by

    local trail = self._trail
    if game:state() == "play" and not game:is_paused() and not game:shell():is_modal() then
        self._trail_head = self._trail_head % TRAIL + 1
        local p = trail[self._trail_head] or {}
        trail[self._trail_head] = p
        p.x, p.y = x, y
    end
    if game:state() == "play" then
        for k = 1, TRAIL do
            local p = trail[k]
            if p then
                local age = (self._trail_head - k) % TRAIL
                canvas:circle(p.x, p.y, r * (1 - age / TRAIL * 0.6), 4.4, C.white, 40 * (1 - age / TRAIL), 1, 0, 12)
            end
        end
    end

    if game:state() == "lost" then return end
    canvas:circle(x + 1, y + 1.5, r, 4.45, C.shadow, 110, 1, 0, 14)
    canvas:circle(x, y, r, 4.5, C.white, 255, 1, 0, 16)
end

function BreakoutView:_draw_hud(canvas, client)
    local text = self._text
    local game = self._game
    local x, y, w = client.x + 14, client.y + 6, client.w - 28
    text:draw("Score: " .. game:score(), x, y, 200, 26, 17, C.white, "left", 5.5)
    text:draw("Lives: " .. game:lives(), x, y, w, 26, 17, C.white, "center", 5.5)
    text:draw("Level: " .. game:level(), x, y, w, 26, 17, C.white, "right", 5.5)

    for i = #self._floats, 1, -1 do
        local f = self._floats[i]
        if f.t > 0.8 then
            table.remove(self._floats, i)
        else
            text:draw(f.text, f.x - 30, f.y - 10 - f.t * 30, 60, 18, 12, C.white, "center", 5.6, nil, 255 * (1 - f.t / 0.8))
        end
    end

    local cx, cy = client.x, client.y + client.h * 0.55
    if self._banner and self._banner_t > 0 then
        local a = math_min(1, self._banner_t * 3)
        text:draw(self._banner, cx, cy - 20, client.w, 34, 24, C.white, "center", 5.7, nil, 255 * a)
    end
    local state = game:state()
    if game:is_paused() then
        canvas:rect(client.x, client.y, client.w, client.h, 5.8, C.black, 90)
        text:draw("Paused", cx, cy - 20, client.w, 34, 24, C.white, "center", 5.9)
        text:draw("Click, press Space or E to continue", cx, cy + 12, client.w, 20, 13, C.white, "center", 5.9)
    elseif state == "serve" and not (self._banner and self._banner_t > 0) then
        local pulse = 150 + math_sin(self._time * 4) * 80
        text:draw("Click or press Space to launch", cx, cy + 12, client.w, 20, 13, C.white, "center", 5.7, nil, pulse)
    end
end

function BreakoutView:_dialog_content(canvas, D, dialog, text, t)
    local box = D.box
    local game = self._game
    local x, y = box.x + 16, box.y + 34
    if dialog.kind == "how_to" then
        for i = 1, #HOW_TO do
            text:draw(HOW_TO[i], x, y + (i - 1) * 18, box.w - 32, 18, 12, C.text_black, "left", 10.5)
        end
    elseif dialog.kind == "about" then
        draw_icon(canvas, x + 14, y + 16, 28, 9.3)
        text:draw("Breakout", x + 46, y, 240, 24, 16, C.text_black, "left", 10.5)
        text:draw("Mourningstar Waiting Games edition", x + 46, y + 26, 260, 18, 12, C.text_black, "left", 10.5)
        text:draw("A tribute to the Windows 95 classic.", x + 46, y + 46, 260, 18, 12, C.text_black, "left", 10.5)
        text:draw("Best score: " .. game:best(), x + 46, y + 70, 260, 18, 12, C.text_black, "left", 10.5)
    elseif dialog.kind == "over" then
        draw_icon(canvas, x + 14, y + 18, 28, 9.3)
        text:draw("Game over!", x + 46, y, 220, 20, 14, C.text_black, "left", 10.5)
        text:draw("Score: " .. game:score() .. "    Level: " .. game:level(), x + 46, y + 24, 220, 18, 12, C.text_black, "left", 10.5)
        if game:new_best() then
            text:draw("New best score!", x + 46, y + 44, 220, 18, 12, C.text_red, "left", 10.5)
        else
            text:draw("Best: " .. game:best(), x + 46, y + 44, 220, 18, 12, C.text_black, "left", 10.5)
        end
    end
end

-- Main draw -------------------------------------------------------------------------------------------

function BreakoutView:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local game = self._game
    local text = self._text
    text:reset()

    if not game then
        BreakoutView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
        return
    end

    dt = math_min(dt or 0.016, 0.05)
    self._time = self._time + dt

    local base = self:_scenegraph_world_position("scanner_base")
    self:_process_pointer(input_service, ui_renderer, base)

    local shell = game:shell()
    local client = shell:layout().client
    self:_handle_events(client)

    local frozen = game:is_paused() or shell:is_modal()
    if not frozen then
        self._particles:update(dt)
        for i = 1, #self._floats do self._floats[i].t = self._floats[i].t + dt end
        self._banner_t = self._banner_t - dt
        self._paddle_flash = math_max(0, self._paddle_flash - dt * 5)
    end
    self._shaker:update(dt, 5)

    local canvas = self._canvas
    if canvas:begin(ui_renderer, base) then
        local time = self._time
        local seconds = math_floor(game:time())
        local blink = math_floor(time * 2) % 2 == 0 and ":" or " "
        DESKTOP_OPTS.clock = string.format("%02d%s%02d", math_floor(seconds / 60) % 100, blink, seconds % 60)
        Win95.draw_desktop(canvas, text, time, DESKTOP_OPTS)
        Win95.draw_window(canvas, text, shell, time, WINDOW_OPTS)

        canvas:set_clip(client.x, client.y, client.x + client.w, client.y + client.h)
        self:_draw_field(canvas, client)
        local sh = self._shaker
        canvas:set_shake(sh.x, sh.y)
        text:set_offset(sh.x, sh.y)
        self:_draw_bricks(canvas, client)
        self:_draw_paddle(canvas, client)
        self:_draw_ball(canvas, client)
        self._particles:draw(canvas, 5)
        canvas:set_shake(0, 0)
        text:set_offset(0, 0)
        self:_draw_hud(canvas, client)
        canvas:reset_clip()

        Win95.draw_menu(canvas, text, shell)
        Win95.draw_dialog(canvas, text, shell, time, self._dialog_cb)
        Win95.draw_hint(canvas, text, HINT)

        canvas:crt(0, 0, RENDER_SIZE, RENDER_SIZE, time, 11.5, CRT_OPTS)
        canvas:finish()
    end

    BreakoutView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

function BreakoutView:destroy()
    self._canvas = nil
    self._particles = nil
    BreakoutView.super.destroy(self)
end

return BreakoutView
