local UIWidget = require("scripts/managers/ui/ui_widget")

local FRAME_TEXTURE = "content/ui/materials/dividers/horizontal_frame_big_lower"
local OUTLINE_TEXTURE = "content/ui/materials/frames/frame_tile_2px"

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
    local outline_alpha = settings.outline_alpha or 70

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
                offset = { left, top + frame_margin, z + 1 },
                pivot = {},
            },
        },
    }, "scanner_base", nil, { width, frame_height })

    widget_definitions.auspex_frame_bottom = UIWidget.create_definition({
        {
            pass_type = "texture",
            style_id = "frame",
            value = FRAME_TEXTURE,
            style = {
                color = scanner_green(color_alpha),
                offset = { left, top + height - frame_height - frame_margin, z + 1 },
            },
        },
    }, "scanner_base", nil, { width, frame_height })

    widget_definitions.auspex_frame_left = UIWidget.create_definition({
        {
            pass_type = "rotated_texture",
            style_id = "frame",
            value = FRAME_TEXTURE,
            style = {
                angle = math.rad(-90),
                color = scanner_green(color_alpha),
                offset = {
                    left + frame_margin + frame_height * 0.5 - height * 0.5,
                    top + (height - frame_height) * 0.5,
                    z + 1,
                },
                pivot = {},
            },
        },
    }, "scanner_base", nil, { height, frame_height })

    widget_definitions.auspex_frame_right = UIWidget.create_definition({
        {
            pass_type = "rotated_texture",
            style_id = "frame",
            value = FRAME_TEXTURE,
            style = {
                angle = math.rad(90),
                color = scanner_green(color_alpha),
                offset = {
                    left + width - frame_margin - frame_height * 0.5 - height * 0.5,
                    top + (height - frame_height) * 0.5,
                    z + 1,
                },
                pivot = {},
            },
        },
    }, "scanner_base", nil, { height, frame_height })

    widget_definitions.auspex_outline = UIWidget.create_definition({
        {
            pass_type = "texture",
            style_id = "frame",
            value = OUTLINE_TEXTURE,
            style = {
                color = scanner_green(outline_alpha),
                scale_to_material = true,
                offset = { left, top, z },
            },
        },
    }, "scanner_base", nil, { width, height })
end

function AuspexFrame.add_inner_border(widget_definitions, settings)
    local render_size = settings.render_size or 600
    local size = settings.size or { render_size, render_size }
    local center = settings.center or { 0, 0 }
    local width = size[1]
    local height = size[2]
    local thickness = settings.thickness or 2
    local z = settings.z or 14
    local prefix = settings.prefix or "auspex_inner"
    local color = settings.color or scanner_green(settings.alpha or 115)
    local left = (render_size - width) * 0.5 + (center[1] or 0)
    local top = (render_size - height) * 0.5 + (center[2] or 0)

    widget_definitions[prefix .. "_top"] = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = color, offset = { left, top, z } },
        },
    }, "scanner_base", nil, { width, thickness })

    widget_definitions[prefix .. "_bottom"] = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = color, offset = { left, top + height - thickness, z } },
        },
    }, "scanner_base", nil, { width, thickness })

    widget_definitions[prefix .. "_left"] = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = color, offset = { left, top, z } },
        },
    }, "scanner_base", nil, { thickness, height })

    widget_definitions[prefix .. "_right"] = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = color, offset = { left + width - thickness, top, z } },
        },
    }, "scanner_base", nil, { thickness, height })
end

return AuspexFrame
