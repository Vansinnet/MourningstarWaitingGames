local mod = get_mod("MourningstarWaitingGames")

local cache = {}
mod._S = function(k)
    if cache[k] == nil then cache[k] = mod:get(k) end
    return cache[k]
end
mod._clear_cache = function()
    for k in pairs(cache) do cache[k] = nil end
end

local TetrisGame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Tetris_game")
if not TetrisGame then
    mod:error("MourningstarWaitingGames: failed to load Tetris_game")
    return
end

local SpaceInvadersGame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/SpaceInvaders_game")
if not SpaceInvadersGame then
    mod:error("MourningstarWaitingGames: failed to load SpaceInvaders_game")
    return
end

local QuizGame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Quiz_game")
if not QuizGame then
    mod:error("MourningstarWaitingGames: failed to load Quiz_game")
    return
end

local SnakeGame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Snake_game")
if not SnakeGame then
    mod:error("MourningstarWaitingGames: failed to load Snake_game")
    return
end

local PongGame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Pong_game")
if not PongGame then
    mod:error("MourningstarWaitingGames: failed to load Pong_game")
    return
end

local AsteroidsGame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Asteroids_game")
if not AsteroidsGame then
    mod:error("MourningstarWaitingGames: failed to load Asteroids_game")
    return
end

local RaycasterGame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Raycaster_game")
if not RaycasterGame then
    mod:error("MourningstarWaitingGames: failed to load Raycaster_game")
    return
end

local NoosphereBreachGame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/NoosphereBreach_game")
if not NoosphereBreachGame then
    mod:error("MourningstarWaitingGames: failed to load NoosphereBreach_game")
    return
end

local MinesweeperGame = mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Minesweeper_game")
if not MinesweeperGame then
    mod:error("MourningstarWaitingGames: failed to load Minesweeper_game")
    return
end

local DAS_DELAY = 0.17
local DAS_RATE = 0.05
local das = {}
local prev_input = {}
local game = nil
local view_open = false
local opening = false
local game_over_timer = nil
local cur_view = nil
local is_selector = false
local is_tetris = false
local is_quiz = false
local is_snake = false
local is_pong = false
local is_asteroids = false
local is_raycaster = false
local is_noosphere = false
local is_minesweeper = false
local look_input = 0
local look_input_y = 0
local look_pending = false
local look_is_controller = false
local snake_arrow_changed = false

local GAME_TYPES = { "tetris", "invaders", "quiz", "snake", "pong", "asteroids", "raycaster", "noosphere", "minesweeper" }
-- Five cards on the top row, four centred below.
local SELECTOR_LEFT = { 5, 1, 2, 3, 4, 9, 6, 7, 8 }
local SELECTOR_RIGHT = { 2, 3, 4, 5, 1, 7, 8, 9, 6 }
local SELECTOR_UP = { 6, 6, 7, 8, 9, 2, 3, 4, 5 }
local SELECTOR_DOWN = { 6, 6, 7, 8, 9, 2, 3, 4, 5 }
local SELECTOR_INPUT_ACTIONS = {
    { "Ingame", "move_left" },
    { "Ingame", "move_right" },
    { "Ingame", "move_forward" },
    { "Ingame", "move_backward" },
    { "View", "navigate_left_pressed" },
    { "View", "navigate_right_pressed" },
    { "View", "navigate_up_pressed" },
    { "View", "navigate_down_pressed" },
    { "Ingame", "jump" },
    { "Ingame", "action_one_pressed" },
    { "Ingame", "interact_pressed" },
    { "View", "confirm_pressed" },
    { "View", "left_pressed" },
}
local GAME_ARROW_INPUT_ACTIONS = {
    "navigate_left_raw",
    "navigate_right_raw",
    "navigate_up_raw",
    "navigate_down_raw",
}
local GAME_DIRECTION_ACTIONS = {
    navigate_left_raw = "move_left",
    navigate_right_raw = "move_right",
    navigate_up_raw = "move_forward",
    navigate_down_raw = "move_backward",
}
local selector_state = { selected = 1, initialized = false }

local LOOK_ACTIONS = {
    look = "mouse",
    look_ranged = "mouse",
    look_ranged_alternate_fire = "mouse",
    look_controller = "controller",
    look_controller_improved = "controller",
    look_controller_lunging = "controller",
    look_controller_ranged = "controller",
    look_controller_ranged_improved = "controller",
    look_controller_ranged_alternate_fire = "controller",
    look_controller_ranged_alternate_fire_improved = "controller",
    look_controller_melee = "controller",
    look_controller_melee_sticky = "controller",
}

local SUPPRESSED = {
	move_forward = 1, move_left = 1, move_backward = 1, move_right = 1,
	crouch = 1, crouching = 1, sprint = 1, sprinting = 1, dodge = 1,
	jump = 1, jump_held = 1,
	action_one_pressed = 1, action_one_release = 1, action_one_hold = 1,
	action_two_pressed = 1, action_two_release = 1, action_two_hold = 1,
	quick_wield = 1, wield_scroll_down = 1, wield_scroll_up = 1,
	wield_1 = 1, wield_2 = 1, wield_3 = 1, wield_3_gamepad = 1, wield_4 = 1, wield_5 = 1,
	weapon_reload_pressed = 1, weapon_reload_hold = 1,
	interact_pressed = 1, interact_hold = 1, interact_inspect_pressed = 1, interact_inspect_hold = 1,
	combat_ability_pressed = 1, combat_ability_release = 1, combat_ability_hold = 1,
	grenade_ability_pressed = 1, grenade_ability_release = 1, grenade_ability_hold = 1,
	weapon_extra_pressed = 1, weapon_extra_release = 1, weapon_extra_hold = 1,
	weapon_inspect_hold = 1, companion_attack = 1, action_three = 1,
	navigate_left_pressed = 1, navigate_right_pressed = 1, navigate_up_pressed = 1, navigate_down_pressed = 1,
	confirm_pressed = 1, left_pressed = 1,
}

local LAND_SFX = "wwise/events/player/play_device_auspex_scanner_minigame_progress"
local CLEAR_SFX = "wwise/events/player/play_device_auspex_scanner_minigame_progress_last"
local QUIZ_WRONG_SFX = "wwise/events/player/play_device_auspex_scanner_minigame_fail"

local function _play_sfx(event)
	local world = Managers.world:world("level_world") or Managers.world:world("hub_world")
	if not world then return end
	local wwise_world = World.get_data(world, "wwise_world")
	if not wwise_world then return end
	WwiseWorld.trigger_resource_event(wwise_world, event)
end

local function _play_land_sfx() _play_sfx(LAND_SFX) end
local function _play_clear_sfx() _play_sfx(CLEAR_SFX) end
local function _play_correct_sfx() _play_sfx(LAND_SFX) end
local function _play_wrong_sfx() _play_sfx(QUIZ_WRONG_SFX) end
local function _play_purge_pickup(kind)
    _play_sfx(kind == "sigil" and CLEAR_SFX or LAND_SFX)
end

local function _is_allowed()
    local gm = Managers.state and Managers.state.game_mode
    if not gm then return false end
    local name = gm:game_mode_name()
    if name ~= "hub" and name ~= "prologue_hub" and name ~= "shooting_range" then return false end
    local ui = Managers.ui
    if ui and ui:has_active_view() then
        local top = ui:active_top_view()
        if top and top ~= "game_selector_view" and top ~= "tetris_view" and top ~= "invaders_view" and top ~= "quiz_view" and top ~= "snake_view" and top ~= "pong_view" and top ~= "asteroids_view" and top ~= "raycaster_view" and top ~= "noosphere_breach_view" and top ~= "minesweeper_view" then
            return false
        end
    end
    return true
end

local function _register_views()
	mod:add_require_path("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/GameSelector_view")
	mod:register_view({
		view_name = "game_selector_view", view_settings = {
			allow_hud = true, class = "GameSelectorView", close_on_hotkey_pressed = false,
			disable_game_world = false, init_view_function = function() return true end,
			load_always = true, load_in_hub = true,
			package = "packages/ui/views/scanner_display_view/scanner_display_view",
			path = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/GameSelector_view",
			state_bound = false, use_transition_ui = false,
		}, view_transitions = {},
		view_options = { close_all = false, close_previous = false },
	})
	mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/GameSelector_view")

	mod:add_require_path("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Tetris_view")
	mod:register_view({
		view_name = "tetris_view", view_settings = {
			allow_hud = true, class = "TetrisView", close_on_hotkey_pressed = false,
			disable_game_world = false, init_view_function = function() return true end,
			load_always = true, load_in_hub = true,
			package = "packages/ui/views/scanner_display_view/scanner_display_view",
			path = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Tetris_view",
			state_bound = false, use_transition_ui = false,
		}, view_transitions = {},
		view_options = { close_all = false, close_previous = false },
	})
	mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Tetris_view")

	mod:add_require_path("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/SpaceInvaders_view")
	mod:register_view({
		view_name = "invaders_view", view_settings = {
			allow_hud = true, class = "InvadersView", close_on_hotkey_pressed = false,
			disable_game_world = false, init_view_function = function() return true end,
			load_always = true, load_in_hub = true,
			package = "packages/ui/views/scanner_display_view/scanner_display_view",
			path = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/SpaceInvaders_view",
			state_bound = false, use_transition_ui = false,
		}, view_transitions = {},
		view_options = { close_all = false, close_previous = false },
	})
	mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/SpaceInvaders_view")

	mod:add_require_path("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Quiz_view")
	mod:register_view({
		view_name = "quiz_view", view_settings = {
			allow_hud = true, class = "QuizView", close_on_hotkey_pressed = false,
			disable_game_world = false, init_view_function = function() return true end,
			load_always = true, load_in_hub = true,
			package = "packages/ui/views/scanner_display_view/scanner_display_view",
			path = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Quiz_view",
			state_bound = false, use_transition_ui = false,
		}, view_transitions = {},
		view_options = { close_all = false, close_previous = false },
	})
	mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Quiz_view")

	mod:add_require_path("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Snake_view")
	mod:register_view({
		view_name = "snake_view", view_settings = {
			allow_hud = true, class = "SnakeView", close_on_hotkey_pressed = false,
			disable_game_world = false, init_view_function = function() return true end,
			load_always = true, load_in_hub = true,
			package = "packages/ui/views/scanner_display_view/scanner_display_view",
			path = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Snake_view",
			state_bound = false, use_transition_ui = false,
		}, view_transitions = {},
		view_options = { close_all = false, close_previous = false },
	})
	mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Snake_view")

	mod:add_require_path("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Pong_view")
	mod:register_view({
		view_name = "pong_view", view_settings = {
			allow_hud = true, class = "PongView", close_on_hotkey_pressed = false,
			disable_game_world = false, init_view_function = function() return true end,
			load_always = true, load_in_hub = true,
			package = "packages/ui/views/scanner_display_view/scanner_display_view",
			path = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Pong_view",
			state_bound = false, use_transition_ui = false,
		}, view_transitions = {},
		view_options = { close_all = false, close_previous = false },
	})
	mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Pong_view")

	mod:add_require_path("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Asteroids_view")
	mod:register_view({
		view_name = "asteroids_view", view_settings = {
			allow_hud = true, class = "AsteroidsView", close_on_hotkey_pressed = false,
			disable_game_world = false, init_view_function = function() return true end,
			load_always = true, load_in_hub = true,
			package = "packages/ui/views/scanner_display_view/scanner_display_view",
			path = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Asteroids_view",
			state_bound = false, use_transition_ui = false,
		}, view_transitions = {},
		view_options = { close_all = false, close_previous = false },
	})
	mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Asteroids_view")

	mod:add_require_path("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Raycaster_view")
	mod:register_view({
		view_name = "raycaster_view", view_settings = {
			allow_hud = true, class = "RaycasterView", close_on_hotkey_pressed = false,
			disable_game_world = false, init_view_function = function() return true end,
			load_always = true, load_in_hub = true,
			package = "packages/ui/views/scanner_display_view/scanner_display_view",
			path = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Raycaster_view",
			state_bound = false, use_transition_ui = false,
		}, view_transitions = {},
		view_options = { close_all = false, close_previous = false },
	})
	mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Raycaster_view")

	mod:add_require_path("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/NoosphereBreach_view")
	mod:register_view({
		view_name = "noosphere_breach_view", view_settings = {
			allow_hud = true, class = "NoosphereBreachView", close_on_hotkey_pressed = false,
			disable_game_world = false, init_view_function = function() return true end,
			load_always = true, load_in_hub = true,
			package = "packages/ui/views/scanner_display_view/scanner_display_view",
			path = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/NoosphereBreach_view",
			state_bound = false, use_transition_ui = false,
		}, view_transitions = {},
		view_options = { close_all = false, close_previous = false },
	})
	mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/NoosphereBreach_view")

	mod:add_require_path("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Minesweeper_view")
	mod:register_view({
		view_name = "minesweeper_view", view_settings = {
			allow_hud = true, class = "MinesweeperView", close_on_hotkey_pressed = false,
			disable_game_world = false, init_view_function = function() return true end,
			load_always = true, load_in_hub = true,
			package = "packages/ui/views/scanner_display_view/scanner_display_view",
			path = "MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Minesweeper_view",
			state_bound = false, use_transition_ui = false,
		}, view_transitions = {},
		view_options = { close_all = false, close_previous = false },
	})
	mod:io_dofile("MourningstarWaitingGames/scripts/mods/MourningstarWaitingGames/Minesweeper_view")
end

local function _save_highscore(key, score)
    local hs = mod:get(key) or 0
    if score > hs then
        mod:set(key, score, false)
    end
end

local function _close_game(skip_ui_close)
    if not view_open then return end
    if opening then return end
    game_over_timer = nil

    if game and cur_view == "tetris_view" then
        mod:echo(string.format("[Tetris] Score: %d  Lines: %d  Level: %d",
            game:score(), game:lines(), game:level()))
        _save_highscore("tetris_highscore", game:score())
    elseif game and cur_view == "invaders_view" then
        mod:echo(string.format("[Invaders] Score: %d  Wave: %d",
            game:score(), game:wave()))
        _save_highscore("invaders_highscore", game:score())
    elseif game and cur_view == "quiz_view" then
        mod:echo(string.format("[Quiz] Score: %d / %d", game:score(), game:total()))
        _save_highscore("quiz_highscore", game:score())
    elseif game and cur_view == "snake_view" then
        mod:echo(string.format("[Snake] Score: %d", game:score()))
        _save_highscore("snake_highscore", game:score())
    elseif game and cur_view == "pong_view" then
        mod:echo(string.format("[Pong] %d - %d  Level: %d", game:score(), game:cpu_score(), game:level()))
        _save_highscore("pong_highscore", game:score())
    elseif game and cur_view == "asteroids_view" then
        mod:echo(string.format("[Asteroids] Score: %d  Wave: %d", game:score(), game:wave()))
        _save_highscore("asteroids_highscore", game:score())
    elseif game and cur_view == "raycaster_view" then
        mod:echo(string.format("[Penitent Purge] Score: %d  Sector: %d  Sigils: %d  Best chain: x%d",
            game:score(), game:level(), game:sigils(), game:best_multiplier()))
        _save_highscore("raycaster_highscore", game:score())
    elseif game and cur_view == "noosphere_breach_view" then
        mod:echo(string.format("[Noosphere Breach] Score: %d  Wave: %d  Best chain: x%d",
            game:score(), game:wave(), game:best_multiplier()))
        _save_highscore("noosphere_highscore", game:score())
    elseif game and cur_view == "minesweeper_view" then
        local best = game:best_time(game:level())
        mod:echo(string.format("[Minesweeper] %s  Best: %s", game:level_name(), best and (best .. "s") or "-"))
    end

    local ui = Managers.ui
    if ui and cur_view and not skip_ui_close then
        local active_ok, active = pcall(function() return ui:view_active(cur_view) end)
        local closing_ok, closing = pcall(function() return ui:is_view_closing(cur_view) end)

        if (active_ok and active) or (closing_ok and closing) then
            pcall(function() ui:close_view(cur_view, true) end)
        end
    end

    game = nil
    view_open = false
    cur_view = nil
    for k in pairs(das) do das[k] = nil end
    for k in pairs(prev_input) do prev_input[k] = nil end
    look_input = 0
    look_input_y = 0
    look_pending = false
    look_is_controller = false
    is_selector = false
end

local function _initialize_selector()
    if selector_state.initialized then return end

    local saved_game_type = mod:get("game_type")
    for i = 1, #GAME_TYPES do
        if GAME_TYPES[i] == saved_game_type then
            selector_state.selected = i
            break
        end
    end

    selector_state.initialized = true
end

local function _open_selector()
    if opening then return end
    if not _is_allowed() then
        mod:echo(mod:localize("tetris_not_allowed"))
        return
    end

    local ui = Managers.ui
    if not ui then return end

    _initialize_selector()
    cur_view = "game_selector_view"
    is_selector = true
    is_tetris = false
    is_quiz = false
    is_snake = false
    is_pong = false
    is_asteroids = false
    is_raycaster = false
    is_noosphere = false
    is_minesweeper = false
    game = nil

    if ui:view_active(cur_view) and not ui:is_view_closing(cur_view) then
        view_open = true
        return
    end

    opening = true
    ui:open_view(cur_view, nil, false, false, nil, { state = selector_state })
    view_open = true
    opening = false
end


local function _open_game(game_type)
    if opening then return end
    if not _is_allowed() then
        mod:echo(mod:localize("tetris_not_allowed"))
        return
    end

    local ui = Managers.ui
    if not ui then return end

    if game_type == "invaders" then
        cur_view = "invaders_view"
        is_tetris = false
        is_quiz = false
        is_snake = false
        is_pong = false
        is_asteroids = false
        is_raycaster = false
        is_noosphere = false
    elseif game_type == "quiz" then
        cur_view = "quiz_view"
        is_tetris = false
        is_quiz = true
        is_snake = false
        is_pong = false
        is_asteroids = false
        is_raycaster = false
        is_noosphere = false
    elseif game_type == "snake" then
        cur_view = "snake_view"
        is_tetris = false; is_quiz = false; is_snake = true; is_pong = false; is_asteroids = false; is_raycaster = false; is_noosphere = false
    elseif game_type == "pong" then
        cur_view = "pong_view"
        is_tetris = false; is_quiz = false; is_snake = false; is_pong = true; is_asteroids = false; is_raycaster = false; is_noosphere = false
    elseif game_type == "asteroids" then
        cur_view = "asteroids_view"
        is_tetris = false; is_quiz = false; is_snake = false; is_pong = false; is_asteroids = true; is_raycaster = false; is_noosphere = false
    elseif game_type == "raycaster" then
        cur_view = "raycaster_view"
        is_tetris = false; is_quiz = false; is_snake = false; is_pong = false; is_asteroids = false; is_raycaster = true; is_noosphere = false
    elseif game_type == "noosphere" then
        cur_view = "noosphere_breach_view"
        is_tetris = false; is_quiz = false; is_snake = false; is_pong = false; is_asteroids = false; is_raycaster = false; is_noosphere = true
    elseif game_type == "minesweeper" then
        cur_view = "minesweeper_view"
        is_tetris = false; is_quiz = false; is_snake = false; is_pong = false; is_asteroids = false; is_raycaster = false; is_noosphere = false
    else
        cur_view = "tetris_view"
        is_tetris = true; is_quiz = false; is_snake = false; is_pong = false; is_asteroids = false; is_raycaster = false; is_noosphere = false
    end

    is_minesweeper = game_type == "minesweeper"

    if ui:view_active(cur_view) or ui:is_view_closing(cur_view) then return end

    if is_tetris then
        game = TetrisGame:new()
        game:set_land_callback(_play_land_sfx)
        game:set_clear_callback(_play_clear_sfx)
        game:start()
    elseif is_quiz then
        game = QuizGame:new()
        game:set_correct_callback(_play_correct_sfx)
        game:set_wrong_callback(_play_wrong_sfx)
        game:start()
    elseif is_snake then
        game = SnakeGame:new()
        game:start()
    elseif is_pong then
        game = PongGame:new()
        game:start()
    elseif is_asteroids then
        game = AsteroidsGame:new()
        game:start()
    elseif is_raycaster then
        game = RaycasterGame:new()
        game:set_pickup_callback(_play_purge_pickup)
        game:set_purge_callback(_play_clear_sfx)
        game:set_sector_callback(_play_clear_sfx)
        game:start()
    elseif is_noosphere then
        game = NoosphereBreachGame:new()
        game:set_hit_callback(function() _play_sfx(QUIZ_WRONG_SFX) end)
        game:set_kill_callback(_play_land_sfx)
        game:set_wave_callback(_play_clear_sfx)
        game:start()
    elseif is_minesweeper then
        game = MinesweeperGame:new({
            get = function(key) return mod:get(key) end,
            set = function(key, value) mod:set(key, value, false) end,
            on_sound = function(kind)
                if kind == "win" then
                    _play_clear_sfx()
                elseif kind == "lose" then
                    _play_wrong_sfx()
                else
                    _play_land_sfx()
                end
            end,
        })
        game:start()
    else
        game = SpaceInvadersGame:new()
        game:start()
    end

    opening = true
    ui:open_view(cur_view, nil, false, false, nil, { game = game })
    view_open = true
    opening = false
end

local function _move_selector(direction)
    local selected = selector_state.selected

    if direction == "left" then
        selector_state.selected = SELECTOR_LEFT[selected]
    elseif direction == "right" then
        selector_state.selected = SELECTOR_RIGHT[selected]
    elseif direction == "up" then
        selector_state.selected = SELECTOR_UP[selected]
    else
        selector_state.selected = SELECTOR_DOWN[selected]
    end

    _play_land_sfx()
end

local function _launch_selected_game()
    local game_type = GAME_TYPES[selector_state.selected]
    if not game_type then return end

    mod:set("game_type", game_type, false)
    _close_game()
    _open_game(game_type)
    prev_input["jump"] = true
    prev_input["action_one_pressed"] = true
    prev_input["interact_pressed"] = true
    prev_input["confirm_pressed"] = true
    prev_input["left_pressed"] = true
end

function mod.toggle_game()
    if not mod._S("enable_tetris") then return end

    if is_selector then
        _close_game()
    elseif game then
        _close_game()
        _open_selector()
    else
        _open_selector()
    end
end

local function _just(action, v)
    local p = (type(v) == "boolean" and v) or (type(v) == "number" and v > 0)
    local was = prev_input[action]
    prev_input[action] = p
    return p and not was
end

local function _input_strength(value)
    if type(value) == "number" then
        return math.max(0, math.min(1, value))
    end

    return value and 1 or 0
end

local function _input_active(value)
    return (type(value) == "boolean" and value) or (type(value) == "number" and value > 0)
end

local function _clear_game_input()
    for key in pairs(das) do das[key] = nil end
    for key in pairs(prev_input) do prev_input[key] = nil end
    look_input = 0
    look_input_y = 0
    look_pending = false
    look_is_controller = false
    snake_arrow_changed = false
end

local function _poll_input_action(service_name, action)
    local input_manager = Managers.input
    local input_service = input_manager and input_manager:get_input_service(service_name)

    if input_service and input_service.has and input_service:has(action) then
        input_service:get(action)
    end
end

local function _poll_selector_input()
    for i = 1, #SELECTOR_INPUT_ACTIONS do
        local input = SELECTOR_INPUT_ACTIONS[i]
        _poll_input_action(input[1], input[2])
        if not is_selector then return false end
    end

    return true
end

local function _process_game_arrow(action, value)
    local movement_action = GAME_DIRECTION_ACTIONS[action]
    if not movement_action then return value end

    if is_tetris then
        local pressed = _just(action, value)
        if movement_action == "move_left" then
            if pressed then
                game:move(-1, 0)
                das.arrow_left = DAS_DELAY
            elseif not _input_active(value) then
                das.arrow_left = nil
            end
        elseif movement_action == "move_right" then
            if pressed then
                game:move(1, 0)
                das.arrow_right = DAS_DELAY
            elseif not _input_active(value) then
                das.arrow_right = nil
            end
        elseif movement_action == "move_forward" then
            if pressed then
                game:hard_drop()
            end
        elseif pressed then
            game:soft_drop()
            das.arrow_down = DAS_DELAY / 2
        elseif not _input_active(value) then
            das.arrow_down = nil
        end
    elseif is_quiz then
        if _just(action, value) then
            if movement_action == "move_forward" then
                game:select_up()
            elseif movement_action == "move_backward" then
                game:select_down()
            end
        end
    elseif is_snake then
        local pressed = _just(action, value)
        if pressed and not snake_arrow_changed then
            if movement_action == "move_forward" then
                game:set_dir(0, -24)
            elseif movement_action == "move_backward" then
                game:set_dir(0, 24)
            elseif movement_action == "move_left" then
                game:set_dir(-24, 0)
            else
                game:set_dir(24, 0)
            end
            snake_arrow_changed = true
        end
    elseif is_pong or is_asteroids or is_raycaster or is_noosphere then
        prev_input[action] = _input_strength(value)
    elseif movement_action == "move_left" or movement_action == "move_right" then
        prev_input[action] = _input_active(value)
    end

    return 0
end

-- Minesweeper reads the mouse through the view's own cursor; only keys are routed here.
local MINESWEEPER_POINTER_ACTIONS = {
    cursor = true,
    left_pressed = true, left_released = true, left_hold = true,
    right_pressed = true, right_released = true, right_hold = true,
    middle_pressed = true, middle_released = true, middle_hold = true,
}
local MINESWEEPER_DIRECTIONS = {
    move_left = { -1, 0 }, move_right = { 1, 0 }, move_forward = { 0, -1 }, move_backward = { 0, 1 },
    navigate_left_raw = { -1, 0 }, navigate_right_raw = { 1, 0 }, navigate_up_raw = { 0, -1 }, navigate_down_raw = { 0, 1 },
}
local MINESWEEPER_LEVEL_KEYS = { wield_1 = "beginner", wield_2 = "intermediate", wield_3 = "expert" }
local MINESWEEPER_POLLED_ACTIONS = {
    "move_left", "move_right", "move_forward", "move_backward",
    "jump", "interact_pressed", "interact_inspect_pressed", "weapon_reload_pressed",
    "wield_1", "wield_2", "wield_3", "wield_4", "tactical_overlay_pressed",
}

local function _process_minesweeper_input(action, r)
    if action == "back" then
        if _just(action, r) and not game:ui_back() then _close_game() end
        return false
    end

    if MINESWEEPER_POINTER_ACTIONS[action] then return r end

    local direction = MINESWEEPER_DIRECTIONS[action]
    if direction then
        local active = r == true or (type(r) == "number" and r > 0.5)
        local was = prev_input[action]
        prev_input[action] = active
        if active and not was then
            game:move_cursor(direction[1], direction[2])
            das["ms_" .. action] = DAS_DELAY
        elseif not active then
            das["ms_" .. action] = nil
        end
        return 0
    end

    if action == "jump" then
        if _just(action, r) then game:key_reveal() end
        return false
    end
    if action == "interact_pressed" or action == "interact_inspect_pressed" then
        if _just(action, r) then game:key_flag() end
        return false
    end
    if action == "weapon_reload_pressed" then
        if _just(action, r) then game:key_new() end
        return false
    end
    if MINESWEEPER_LEVEL_KEYS[action] then
        if _just(action, r) then game:key_level(MINESWEEPER_LEVEL_KEYS[action]) end
        return false
    end
    if action == "wield_4" then
        if _just(action, r) then game:key_marks() end
        return false
    end
    if action == "tactical_overlay_pressed" then
        if _just(action, r) then game:toggle_menu() end
        return false
    end
    if action == "tactical_overlay_hold" then return false end

    if action == "move" or LOOK_ACTIONS[action] then return Vector3(0, 0, 0) end
    if SUPPRESSED[action] then return false end

    return r
end

local function process_input(self, action, r)
    if not view_open then return r end

    local ui = Managers.ui
    if not ui or ui:active_top_view() ~= cur_view then return r end

    if is_selector then
        if action == "back" and _just(action, r) then _close_game(); return false end
        if action == "action_two_pressed" and _just(action, r) then _close_game(); return false end
        if action == "move_left" then
            if _just(action, r) then _move_selector("left") end
            return 0
        end
        if action == "move_right" then
            if _just(action, r) then _move_selector("right") end
            return 0
        end
        if action == "move_forward" then
            if _just(action, r) then _move_selector("up") end
            return 0
        end
        if action == "move_backward" then
            if _just(action, r) then _move_selector("down") end
            return 0
        end
        if action == "navigate_left_pressed" and _just(action, r) then _move_selector("left"); return false end
        if action == "navigate_right_pressed" and _just(action, r) then _move_selector("right"); return false end
        if action == "navigate_up_pressed" and _just(action, r) then _move_selector("up"); return false end
        if action == "navigate_down_pressed" and _just(action, r) then _move_selector("down"); return false end
        if action == "jump" and _just(action, r) then _launch_selected_game(); return false end
        if action == "action_one_pressed" and _just(action, r) then _launch_selected_game(); return false end
        if action == "interact_pressed" and _just(action, r) then _launch_selected_game(); return false end
        if action == "confirm_pressed" and _just(action, r) then _launch_selected_game(); return false end
        if action == "left_pressed" and _just(action, r) then _launch_selected_game(); return false end
        if action == "move" or LOOK_ACTIONS[action] then return Vector3(0, 0, 0) end

        return (type(r) == "number" and 0) or (type(r) == "userdata" and Vector3(0, 0, 0)) or false
    end

    if not game then return r end

    if is_minesweeper then return _process_minesweeper_input(action, r) end

    if action == "back" and _just(action, r) then _close_game(); return false end
    if action == "action_two_pressed" and _just(action, r) then
        if is_raycaster then game:dash() else _close_game() end
        return false
    end
    if game:is_game_over() then
        if action == "move" or LOOK_ACTIONS[action] then return Vector3(0, 0, 0) end
        return (type(r) == "number" and 0) or (type(r) == "userdata" and Vector3(0, 0, 0)) or false
    end

    if GAME_DIRECTION_ACTIONS[action] then
        return _process_game_arrow(action, r)
    end

    if is_tetris then
        if action == "move_left" then
            local p = (type(r) == "boolean" and r) or (type(r) == "number" and r > 0)
            local was = prev_input[action]
            prev_input[action] = p
            if p and not was then
                game:move(-1, 0)
                das.left = DAS_DELAY
            elseif not p and was then
                das.left = nil
            end
            return 0
        end
        if action == "move_right" then
            local p = (type(r) == "boolean" and r) or (type(r) == "number" and r > 0)
            local was = prev_input[action]
            prev_input[action] = p
            if p and not was then
                game:move(1, 0)
                das.right = DAS_DELAY
            elseif not p and was then
                das.right = nil
            end
            return 0
        end
        if action == "move_backward" then
            local p = (type(r) == "boolean" and r) or (type(r) == "number" and r > 0)
            local was = prev_input[action]
            prev_input[action] = p
            if p and not was then
                game:soft_drop()
                das.down = DAS_DELAY / 2
            elseif not p and was then
                das.down = nil
            end
            return 0
        end
        if action == "move_forward" and _just(action, r) then game:hard_drop(); return 0 end
        if action == "jump" and _just(action, r) then game:hard_drop(); return false end
        if action == "interact_pressed" and _just(action, r) then game:rotate(1); return false end
        if action == "quick_wield" and _just(action, r) then game:rotate(-1); return false end
        if action == "weapon_reload_pressed" and _just(action, r) then game:hold(); return false end
    elseif is_quiz then
        if action == "move_left" or action == "move_right" then return 0 end
        if action == "move_forward" and _just(action, r) then game:select_up(); return false end
        if action == "move_backward" and _just(action, r) then game:select_down(); return false end
        if action == "jump" and _just(action, r) then game:confirm(); return false end
        if action == "action_one_pressed" and _just(action, r) then game:confirm(); return false end
        if action == "move" or action == "look" then return Vector3(0, 0, 0) end
    elseif is_snake then
        if action == "move_forward" then
            if _just(action, r) then game:set_dir(0, -24) end
            return false
        end
        if action == "move_backward" then
            if _just(action, r) then game:set_dir(0, 24) end
            return false
        end
        if action == "move_left" then
            if _just(action, r) then game:set_dir(-24, 0) end
            return false
        end
        if action == "move_right" then
            if _just(action, r) then game:set_dir(24, 0) end
            return false
        end
        if action == "move" or action == "look" then return Vector3(0, 0, 0) end
    elseif is_pong then
        if action == "back" and _just(action, r) then _close_game(); return false end
        if action == "action_two_pressed" and _just(action, r) then _close_game(); return false end
        if action == "move_forward" then
            prev_input[action] = (type(r) == "boolean" and r) or (type(r) == "number" and r > 0)
            return 0
        end
        if action == "move_backward" then
            prev_input[action] = (type(r) == "boolean" and r) or (type(r) == "number" and r > 0)
            return 0
        end
        if action == "move" or action == "look" then return Vector3(0, 0, 0) end
        if SUPPRESSED[action] then return false end
    elseif is_asteroids then
        if action == "back" and _just(action, r) then _close_game(); return false end
        if action == "action_two_pressed" and _just(action, r) then _close_game(); return false end
        if action == "move_left" then
            prev_input[action] = (type(r) == "boolean" and r) or (type(r) == "number" and r > 0)
            return 0
        end
        if action == "move_right" then
            prev_input[action] = (type(r) == "boolean" and r) or (type(r) == "number" and r > 0)
            return 0
        end
        if action == "move_forward" then
            prev_input[action] = (type(r) == "boolean" and r) or (type(r) == "number" and r > 0)
            return 0
        end
        if action == "move_backward" then
            prev_input[action] = (type(r) == "boolean" and r) or (type(r) == "number" and r > 0)
            return 0
        end
        if action == "jump" and _just(action, r) then game:fire(); return false end
        if action == "action_one_pressed" and _just(action, r) then game:fire(); return false end
        if action == "move" or action == "look" then return Vector3(0, 0, 0) end
        if SUPPRESSED[action] then return false end
    elseif is_raycaster then
        if action == "back" and _just(action, r) then _close_game(); return false end
        if action == "move_left" then
            prev_input[action] = _input_strength(r)
            return 0
        end
        if action == "move_right" then
            prev_input[action] = _input_strength(r)
            return 0
        end
        if action == "move_forward" then
            prev_input[action] = _input_strength(r)
            return 0
        end
        if action == "move_backward" then
            prev_input[action] = _input_strength(r)
            return 0
        end
        if LOOK_ACTIONS[action] then
            if type(r) == "userdata" then
                local x = Vector3.x(r)
                if not look_pending or math.abs(x) > math.abs(look_input) then
                    look_input = x
                    look_is_controller = LOOK_ACTIONS[action] == "controller"
                end
                look_pending = true
            end
            return Vector3(0, 0, 0)
        end
        if action == "interact_pressed" and _just(action, r) then game:dash(); return false end
        if action == "jump" and _just(action, r) then game:dash(); return false end
        if action == "action_one_pressed" and _just(action, r) then game:dash(); return false end
        if action == "sprint" and _just(action, r) then game:dash(); return false end
        if action == "move" then return Vector3(0, 0, 0) end
        if SUPPRESSED[action] then return false end
    elseif is_noosphere then
        if action == "back" and _just(action, r) then _close_game(); return false end
        if action == "move_left" or action == "move_right" or action == "move_forward" or action == "move_backward" then
            prev_input[action] = _input_strength(r)
            return 0
        end
        if LOOK_ACTIONS[action] then
            if type(r) == "userdata" then
                local x = Vector3.x(r)
                local y = Vector3.y(r)
                local magnitude = x * x + y * y
                local pending_magnitude = look_input * look_input + look_input_y * look_input_y

                if not look_pending or magnitude > pending_magnitude then
                    look_input = x
                    look_input_y = y
                    look_is_controller = LOOK_ACTIONS[action] == "controller"
                end
                look_pending = true
            end
            return Vector3(0, 0, 0)
        end
        if action == "action_one_hold" then
            prev_input[action] = _input_active(r)
            return false
        end
        if action == "action_one_pressed" then
            prev_input[action] = _input_active(r)
            return false
        end
        if action == "action_one_release" then
            if _input_active(r) then
                prev_input["action_one_hold"] = false
                prev_input["action_one_pressed"] = false
            end
            return false
        end
        if action == "interact_pressed" and _just(action, r) then game:dash(); return false end
        if action == "jump" and _just(action, r) then game:dash(); return false end
        if action == "sprint" and _just(action, r) then game:dash(); return false end
        if action == "move" then return Vector3(0, 0, 0) end
        if SUPPRESSED[action] then return false end
    else
        if action == "move_left" then
            prev_input[action] = (type(r) == "boolean" and r) or (type(r) == "number" and r > 0)
            return 0
        end
        if action == "move_right" then
            prev_input[action] = (type(r) == "boolean" and r) or (type(r) == "number" and r > 0)
            return 0
        end
        if action == "jump" and _just(action, r) then game:fire(); return false end
        if action == "action_one_pressed" and _just(action, r) then game:fire(); return false end
    end

    if SUPPRESSED[action] then return false end

    if action == "move" or action == "look" then return Vector3(0, 0, 0) end
    return r
end

local input_hook_depth = 0
local function input_hook(func, self, action)
    local process_result = input_hook_depth == 0
    input_hook_depth = input_hook_depth + 1
    local result = func(self, action)
    input_hook_depth = input_hook_depth - 1

    if not process_result then return result end

    return process_input(self, action, result)
end


mod:hook(CLASS.InputService, "_get", input_hook)
pcall(function() mod:hook(CLASS.InputService, "_get_simulate", input_hook) end)

mod.update = function(dt)
    if not mod:is_enabled() then return end
    if not view_open then return end

    local top_view = Managers.ui and Managers.ui:active_top_view()

    if is_selector then
        if top_view ~= cur_view then _clear_game_input() end

        if top_view == cur_view then
            _poll_input_action("View", "back")
            if not view_open then return end
            if not _poll_selector_input() then return end
        end

        local ui = Managers.ui
        local active = false
        if ui and cur_view then
            local ok, result = pcall(function() return ui:view_active(cur_view) end)
            active = ok and result or false
        end

        if not ui or not active then
            if opening then return end
            _close_game()
        end

        return
    end

    if not game then return end

    if top_view == cur_view then
        _poll_input_action("View", "back")
        if not view_open or not game then return end

        snake_arrow_changed = false
        for i = 1, #GAME_ARROW_INPUT_ACTIONS do
            _poll_input_action("View", GAME_ARROW_INPUT_ACTIONS[i])
            if not view_open or not game then return end
        end

        if is_tetris then
            _poll_input_action("Ingame", "weapon_reload_pressed")
        elseif is_minesweeper then
            for i = 1, #MINESWEEPER_POLLED_ACTIONS do
                _poll_input_action("Ingame", MINESWEEPER_POLLED_ACTIONS[i])
                if not view_open or not game then return end
            end
        elseif is_noosphere then
            _poll_input_action("Ingame", "move_left")
            _poll_input_action("Ingame", "move_right")
            _poll_input_action("Ingame", "move_forward")
            _poll_input_action("Ingame", "move_backward")
            _poll_input_action("Ingame", "action_one_hold")
            _poll_input_action("Ingame", "action_one_pressed")
        end
    else
        _clear_game_input()
        _close_game()
        return
    end

    if game:is_game_over() then
        if not game_over_timer then game_over_timer = 0 end
        game_over_timer = game_over_timer + dt
        local close_delay = (is_raycaster or is_noosphere) and 3 or 1.5
        if game_over_timer >= close_delay then _close_game() end
        return
    end
    game_over_timer = nil

    if is_minesweeper then
        for key, timer in pairs(das) do
            local direction = timer and MINESWEEPER_DIRECTIONS[string.sub(key, 4)]
            if direction then
                timer = timer - dt
                if timer <= 0 then
                    game:move_cursor(direction[1], direction[2])
                    das[key] = DAS_RATE * 2 + timer
                else
                    das[key] = timer
                end
            end
        end

        if game:consume_close_request() then
            _close_game()
            return
        end
    elseif is_tetris then
        for key, timer in pairs(das) do
            if timer then
                timer = timer - dt
                if timer <= 0 then
                    if key == "left" or key == "arrow_left" then
                        game:move(-1, 0)
                    elseif key == "right" or key == "arrow_right" then
                        game:move(1, 0)
                    elseif key == "down" or key == "arrow_down" then
                        game:soft_drop()
                    end
                    das[key] = DAS_RATE + timer
                else
                    das[key] = timer
                end
            end
        end
    elseif is_pong then
        if _input_active(prev_input["move_forward"]) or _input_active(prev_input["navigate_up_raw"]) then game:move_player(-1, dt) end
        if _input_active(prev_input["move_backward"]) or _input_active(prev_input["navigate_down_raw"]) then game:move_player(1, dt) end
    elseif is_asteroids then
        if _input_active(prev_input["move_left"]) or _input_active(prev_input["navigate_left_raw"]) then game:turn(-1, dt) end
        if _input_active(prev_input["move_right"]) or _input_active(prev_input["navigate_right_raw"]) then game:turn(1, dt) end
        if _input_active(prev_input["move_forward"]) or _input_active(prev_input["navigate_up_raw"]) then game:thrust(dt) end
        if _input_active(prev_input["move_backward"]) or _input_active(prev_input["navigate_down_raw"]) then game:brake(dt) end
    elseif is_raycaster then
        if look_pending then
            game:look(look_input, look_is_controller)
            look_input = 0
            look_pending = false
            look_is_controller = false
        end
        local forward = (prev_input["move_forward"] or 0) + (prev_input["navigate_up_raw"] or 0)
            - (prev_input["move_backward"] or 0) - (prev_input["navigate_down_raw"] or 0)
        local strafe = (prev_input["move_right"] or 0) + (prev_input["navigate_right_raw"] or 0)
            - (prev_input["move_left"] or 0) - (prev_input["navigate_left_raw"] or 0)

        if forward ~= 0 or strafe ~= 0 then
            game:move_axes(forward, strafe, math.min(dt, 0.05))
        end
    elseif is_noosphere then
        if look_pending then
            local screen_x = look_input
        local screen_y = look_is_controller and look_input_y or -look_input_y
        game:aim(screen_x, screen_y, look_is_controller)
            look_input = 0
            look_input_y = 0
            look_pending = false
            look_is_controller = false
        end

        local screen_y = (prev_input["move_backward"] or 0) + (prev_input["navigate_down_raw"] or 0)
            - (prev_input["move_forward"] or 0) - (prev_input["navigate_up_raw"] or 0)
        local screen_x = (prev_input["move_right"] or 0) + (prev_input["navigate_right_raw"] or 0)
            - (prev_input["move_left"] or 0) - (prev_input["navigate_left_raw"] or 0)
        game:set_move(screen_x, screen_y)
        game:set_firing(_input_active(prev_input["action_one_hold"]) or _input_active(prev_input["action_one_pressed"]))
    elseif not is_quiz and not is_snake and not is_pong and not is_asteroids and not is_raycaster and not is_noosphere then
        if _input_active(prev_input["move_left"]) or _input_active(prev_input["navigate_left_raw"]) then game:move_left(dt) end
        if _input_active(prev_input["move_right"]) or _input_active(prev_input["navigate_right_raw"]) then game:move_right(dt) end
        -- Invaders consumes this frame's input before advancing its fixed-step simulation.
        game:update(dt)
    end

    local ui = Managers.ui
    local active = false

    if ui and cur_view then
        local ok, result = pcall(function() return ui:view_active(cur_view) end)
        active = ok and result or false
    end

    if not ui or not active then
        if opening then return end
        _close_game()
    end
end

mod.on_setting_changed = function(id)
    mod._clear_cache()
end

mod.on_enabled = function()
    mod._clear_cache()
end

mod.on_disabled = function()
    _close_game()
end

mod.on_game_state_changed = function(st, name)
    if st == "exit" and name == "StateGameplay" then
        _close_game()
    end
end

mod.on_unload = function(exit_game)
    _close_game(true)
end

_register_views()
