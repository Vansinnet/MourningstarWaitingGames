local UIWidget = require("scripts/managers/ui/ui_widget")

local FRAME_TEXTURE = "content/ui/materials/dividers/horizontal_frame_big_lower"

local AuspexFrame = {}

local function scanner_green(alpha)
    return { alpha, 0, 255, 110 }
end

local function rounded(value)
    return math.floor(value + 0.5)
end

function AuspexFrame.add(widget_definitions, settings)
    local render_size = settings.render_size or 600
    local outline_size = settings.outline_size or settings.size or { render_size, render_size }
    local center = settings.center or { 0, 0 }
    local width = outline_size[1]
    local height = outline_size[2]
    local frame_height = settings.frame_height or rounded(math.min(width, height) * 0.145)
    local frame_margin = settings.frame_margin or -rounded(frame_height * 0.65)
    local left = (render_size - width) * 0.5 + (center[1] or 0)
    local top = (render_size - height) * 0.5 + (center[2] or 0)
    local z = settings.z or 6
    local backdrop_z = settings.backdrop_z or -2
    local backdrop_alpha = settings.backdrop_alpha or 235
    local color_alpha = settings.alpha or 144
    -- The four frame pieces reach past the backdrop so their ends meet in shared corners.
    local extend = settings.frame_extend or rounded(frame_height * 0.4)
    local span_w = width + extend * 2
    local span_h = height + extend * 2

    widget_definitions.auspex_backdrop = UIWidget.create_definition({
        {
            pass_type = "texture",
            style_id = "background",
            value = "content/ui/materials/backgrounds/default_square",
            style = {
                color = { backdrop_alpha, 0, 0, 0 },
                offset = { left, top, backdrop_z },
            },
        },
    }, "scanner_base", nil, { width, height })

    widget_definitions.auspex_frame_top = UIWidget.create_definition({
        {
            pass_type = "rotated_texture",
            style_id = "frame",
            value = FRAME_TEXTURE,
            style = {
                angle = math.rad(180),
                color = scanner_green(color_alpha),
                offset = { left - extend, top + frame_margin, z + 1 },
                pivot = {},
            },
        },
    }, "scanner_base", nil, { span_w, frame_height })

    widget_definitions.auspex_frame_bottom = UIWidget.create_definition({
        {
            pass_type = "texture",
            style_id = "frame",
            value = FRAME_TEXTURE,
            style = {
                color = scanner_green(color_alpha),
                offset = { left - extend, top + height - frame_height - frame_margin, z + 1 },
            },
        },
    }, "scanner_base", nil, { span_w, frame_height })

    widget_definitions.auspex_frame_left = UIWidget.create_definition({
        {
            pass_type = "rotated_texture",
            style_id = "frame",
            value = FRAME_TEXTURE,
            style = {
                angle = math.rad(-90),
                color = scanner_green(color_alpha),
                offset = {
                    left + frame_margin + frame_height * 0.5 - span_h * 0.5,
                    top + (height - frame_height) * 0.5,
                    z + 1,
                },
                pivot = {},
            },
        },
    }, "scanner_base", nil, { span_h, frame_height })

    widget_definitions.auspex_frame_right = UIWidget.create_definition({
        {
            pass_type = "rotated_texture",
            style_id = "frame",
            value = FRAME_TEXTURE,
            style = {
                angle = math.rad(90),
                color = scanner_green(color_alpha),
                offset = {
                    left + width - frame_margin - frame_height * 0.5 - span_h * 0.5,
                    top + (height - frame_height) * 0.5,
                    z + 1,
                },
                pivot = {},
            },
        },
    }, "scanner_base", nil, { span_h, frame_height })
end

return AuspexFrame
